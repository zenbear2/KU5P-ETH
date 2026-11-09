# KU5P 1G GMII Ethernet Stress Test & Verification Plan

## 1. Overview & Hardware Topology

This document outlines the stress test and reliability verification plan for the **1G GMII Ethernet system** on the **AMD Kintex UltraScale+ (`xcku5p-ffvb676-2-i`)** platform. The objective is to verify line-rate operation (1000BASE-T), bidirectional traffic handling, soak endurance, burst traffic processing, packet integrity, DMA ring replenishment, and clock-domain crossing (CDC) stability. The reference hardware Block Design reconstruction script is provided in `bd/KU5P_SoC.tcl`.

### Hardware Topology
```text
+-----------------------------------------------------------------------------------+
|                        Kintex UltraScale+ FPGA (xcku5p)                           |
|                                                                                   |
|  +--------------------+      AXI4 (100MHz)      +------------------------------+  |
|  | MicroBlaze Core    | <=====================> | AXI Interconnect / XBar      |  |
|  | - Stress Test App  |                         +--------------+---------------+  |
|  +--------------------+                                        |                  |
|                                                                | AXI4             |
|  +--------------------+      AXI-Stream (100MHz)               v                  |
|  | DDR4 SDRAM (1GB)   | <---------------------------- +-----------------+         |
|  | - TX/RX BD Rings   |                               | Xilinx AXI DMA  |         |
|  | - TX/RX Buffers    | ----------------------------> | (Standard SG,   |         |
|  +--------------------+                               |  c_micro_dma=0) |         |
|                                                       +--------+--------+         |
|                                                                |                  |
|                                                       M_AXIS   |   S_AXIS         |
|                                                       (MM2S)   |   (S2MM)         |
|                                                                v   |              |
|                                                    +-----------+---+-----------+  |
|                                                    | taxi_eth_gmii_axi_wrapper |  |
|                                                    | - Base: 0x00020000        |  |
|                                                    | - TX FIFO: 4096 bytes     |  |
|                                                    | - RX FIFO: 4096 bytes     |  |
|                                                    | - GTX_CLK: 125 MHz (BUFG) |  |
|                                                    +-------------+-------------+  |
+------------------------------------------------------------------|----------------+
                                                                   | GMII 1G (8-bit @ 125MHz)
                                                                   v
                                                     +---------------------------+
                                                     | Realtek RTL8211EG PHY     |
                                                     +-------------+-------------+
                                                                   | RJ45 Cat5e/6
                                                                   v
                                                     +---------------------------+
                                                     | Host PC (192.168.1.x)     |
                                                     | Wireshark / Python Runner |
                                                     +---------------------------+
```

---

## 2. Test Matrix & Verification Cases

| ID | Test Case | Test Conditions & Methodology | Pass Criteria |
| :---: | :--- | :--- | :--- |
| **TC-01** | **TX High-Rate Burst Test** | MicroBlaze queues frames using a pipelined in-flight BD ring (depth 16), continuously transmitting **1,000 or 10,000 frames** (64–1514 bytes). | 1. 100% completion rate (zero DMA timeouts).<br>2. MAC `TX_GOOD` counter increment matches transmitted frame count.<br>3. `TX_UNDR` = 0, `TX_OVFL` = 0. |
| **TC-02** | **Bidirectional Soak Test** | 1. FPGA continuously transmits test frames while polling/responding to ARP, ICMP, and UDP packets.<br>2. Host PC generates concurrent traffic via `ping -t` or `host_stress_test.py`.<br>3. Run duration: **60 seconds or 300 seconds**. | 1. No deadlocks; `S2MM_SR` and `MM2S_SR` show no `Halted` or `Err` flags.<br>2. Host PC ICMP ping packet loss is **0.0%**.<br>3. FPGA MAC `RX_BAD_FCS` = 0, `RX_OVFL` = 0. |
| **TC-03** | **Data Pattern & Integrity Verification** | Transmit frames containing a 32-bit sequence number, dynamic PRBS payload, and 16-bit payload checksum (60–1514 bytes). Validate DDR4 cache coherency (`Xil_DCacheFlushRange` / `Xil_DCacheInvalidateRange`). | 1. Bitwise verification of PRBS payload and checksum succeeds (`verify_err` = 0).<br>2. MAC `TX_GOOD` matches committed frames. |
| **TC-04** | **RX Starvation & Backpressure Recovery** | Pause RX BD replenishment for 200 ms under inbound traffic to induce RX FIFO backpressure, then resume `poll_rx_packets()` and verify link traffic. | 1. RX DMA channel recovers and continues processing packets upon resuming replenishment.<br>2. No bus hang, lockup, or decode error (`DMADecErr` = 0). |
| **TC-05** | **DMA Reset Recovery Test** | Execute **50 consecutive** AXI DMA hardware resets (`XAxiDma_Reset`) and reinitialize TX/RX BD rings. Transmit 4 verification frames after each reset. | 1. All 50 reset cycles and 200 verification frames complete successfully.<br>2. Zero descriptor resource leak or DMA channel freeze. |
| **TC-06** | **Host Automated Benchmark** | Execute `scripts/host_stress_test.py` on host PC to measure ICMP RTT latency and UDP burst throughput. | 1. RTT latency, jitter, and packet loss are logged.<br>2. Summary benchmark report is output and verified. |

---

## 3. Software & DMA Architecture

### 3.1 Software Module Decomposition
The test firmware is modularized into distinct drivers and test modules (located in `sw/` and `vitis/KU5P-ETH/src/`):
- **`main.c` / `helloworld.c`**: Application entry point, system initialization sequence, and non-blocking UART command dispatcher.
- **`eth_mac.h` / `eth_mac.c`**: Low-level MAC CSR driver, mailbox configuration CDC synchronization, speed detection, and hardware counter operations.
- **`eth_dma.h` / `eth_dma.c`**: AXI DMA Scatter-Gather controller, BD ring lifecycle, transmission execution, and S2MM buffer replenishment.
- **`packet_builder.h` / `packet_builder.c`**: Frame construction (broadcast, ARP query, PRBS pattern) and automatic ARP reply / ICMP Echo reply handlers.
- **`stress_tests.h` / `stress_tests.c`**: Implementation of stress test cases TC-01 through TC-05.

### 3.2 Standard Scatter-Gather DMA & Queue Pipelining
1. **Standard SG Mode (`c_micro_dma = 0`)**:
   The Xilinx AXI DMA must have Micro DMA disabled (`CONFIG.c_micro_dma = 0`) to enable `C_S2MM_SUPPORT_INDET_BTT = 1`. This allows the S2MM channel to handle variable-length Ethernet frames terminated early by `m_axis_rx_tlast`.
2. **Pipelined TX Queue**:
   Blocking on single-frame completions degrades throughput. The test suite uses pipelined multi-BD scheduling (up to 16 in-flight BDs):
```text
[Free BD Ring] ---> [Allocate N BDs (up to 16)] ---> [Set Buffers & SOF/EOF] ---> [Commit to HW]
                                                                                        |
                                                                                        v
[Reap Loop] <------ [XAxiDma_BdRingFromHw] <------------------------------------+ [DMA MM2S Transfer]
```
3. **Deterministic RX BD Buffer Mapping**:
   The RX BD ring size is fixed to 32 descriptors (`RX_BD_SPACE_HIGH - RX_BD_SPACE_BASE + 1 = 32 * 64` bytes). During replenishment in `poll_rx_packets()`, the buffer address is computed directly from the descriptor index: `RX_BUFFER_BASE + (bd_idx * RX_BUF_SIZE)`. This prevents assigning uninitialized buffer addresses (`0x00000000`) that cause `DMADecErr` (`S2MM_SR = 0x00015049`).

### 3.3 Stress Test Frame Format
```text
Byte 0..5   : Destination MAC (FF:FF:FF:FF:FF:FF or target MAC)
Byte 6..11  : Source MAC (00:0A:35:01:02:03)
Byte 12..13 : EtherType (0x88B5 - IEEE 802 Local Experimental)
Byte 14..17 : 32-bit Sequence Number (Big-Endian, strictly incrementing)
Byte 18..21 : Magic Tag ("KU5P" = 0x4B 0x55 0x35 0x50)
Byte 22..25 : Payload Length / PRBS Seed
Byte 26..N-3: PRBS Payload Pattern (Pk = (Pk-1 * 1103515245 + 12345) & 0xFF)
Byte N-2..N-1: 16-bit Payload Checksum
```

---

## 4. Execution & Operation Guide

### 4.1 FPGA UART Command Menu
Connect to the UART console (115200 bps, 8N1) and press the corresponding key to execute:
* **`[1]`**: Send single broadcast frame (64 bytes)
* **`[2]`**: Send 10 burst frames
* **`[3]`**: **[TC-01]** Run 1,000-frame pipelined TX burst test (64–1514 bytes variable)
* **`[4]`**: **[TC-01]** Run 10,000-frame pipelined TX burst test (64 bytes)
* **`[5]`**: **[TC-02]** Start 60-second bidirectional soak test (prints throughput and `S2MM_SR` per second)
* **`[6]`**: **[TC-02]** Start 300-second bidirectional soak test
* **`[7]`**: **[TC-03]** Run PRBS data integrity and cache coherency test (500 frames)
* **`[8]`**: **[TC-05]** Run DMA reset and recovery test (50 iterations)
* **`[9]`**: **[TC-04]** Run RX queue starvation and backpressure recovery test
* **`[c]`**: Clear MAC hardware event counters
* **`[s]`**: Dump MAC 10 event counters and interrupt status
* **`[d]`**: Dump AXI DMA MM2S and S2MM control and status registers

### 4.2 Host PC Verification Commands
Open a terminal on the host PC connected to the FPGA via Ethernet:
1. **Continuous ICMP Ping**:
   ```cmd
   ping -t -l 18 192.168.1.175
   ```
2. **Run Host Benchmark Script**:
   ```cmd
   python scripts/host_stress_test.py --target 192.168.1.175 --mode all --count 2000 --duration 30
   ```
