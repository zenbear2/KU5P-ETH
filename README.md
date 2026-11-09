# KU5P-ETH: Kintex UltraScale+ 1G GMII Ethernet MAC AXI Wrapper

[English](README.md) | [繁體中文](README_zh.md)

**KU5P-ETH** is based on the open-source [Taxi](https://github.com/fpganinja/taxi) 1G GMII Ethernet MAC and asynchronous frame FIFO subsystem, adding bus flattening, AXI4-Lite control/status registers, clock-domain crossing (CDC) synchronization, and SoC integration for the **AMD / Xilinx Kintex UltraScale+ (`xcku5p-ffvb676-2-i`, `FPGA_FAMILY = "kintexuplus"`)** platform.

This repository converts the SystemVerilog-interface-based MAC core into standard flat AXI4-Stream and AXI4-Lite interfaces suitable for Vivado IP Integrator (Block Design) and Xilinx AXI DMA integration.

---

## Modifications and Extensions on Top of Taxi

This project retains the upstream `taxi` 1G GMII MAC datapath, CRC32 engine, PAUSE flow control, and AXI-Stream asynchronous FIFOs, and adds the following five components:

### 1. Vivado Block Design Interface Flattening & IP Packaging
- **Flat Top-Level Wrapper (`rtl/taxi_eth_gmii_axi_wrapper.sv`, `rtl/taxi_eth_axi_wrapper.sv`)**: Maps `taxi`'s `taxi_axis_if` SystemVerilog interfaces to flat port signals (`s_axis_tx_*`, `m_axis_rx_*`, `s_axi_ctrl_*`) annotated with Vivado `X_INTERFACE_INFO` and `X_INTERFACE_PARAMETER` attributes for automatic bus inference in Vivado IP Integrator.
- **Reset Synchronization & Stream Gating**: Integrates `taxi_sync_reset` at the top level and gates `s_axis_tx` and `m_axis_rx` handshakes during reset.
- **IP Catalog Packaging & Scoped Constraints (`scripts/package_ip.tcl`, `constrs/*.tcl`)**: Packages the module into a Vivado IP with `SCOPED_TO_REF` timing constraints configured as `USED_IN_implementation` to avoid false clock warnings during out-of-context synthesis.

### 2. AXI4-Lite CSR & Saturating Event Counters (`rtl/taxi_eth_gmii_axil_regs.sv`)
Upstream `taxi` exposes raw configuration wires and single-cycle status pulses. This project adds a 32-bit AXI4-Lite slave module (4 KiB address space, `0x000`–`0x064`):
- **Identification & Status**: Provides `IP_ID` (`0x54474D49`, `"TGMI"`), `VERSION` (`0x00010000`), estimated link speed, and the `CFG_BUSY` status flag.
- **Shadow Registers & Commit Protection**: Provides `CONTROL` (TX/RX/Pad enable), `TX_MIN_LEN`, `TX_MAX_LEN`, `RX_MAX_LEN`, and `TX_IFG` registers. Writing `1` to `APPLY` triggers the CDC handshake; writes to `APPLY` while `CFG_BUSY == 1` return AXI `SLVERR` (`2'b10`).
- **10 Saturating 32-bit Counters & Interrupt Controller**: Captures single-cycle MAC/FIFO pulses into ten 32-bit saturating counters (`EVENT_CNT_0`–`EVENT_CNT_9`, with `COUNTER_CLEAR` support) and provides sticky status (`IRQ_PENDING`, W1C) and mask (`IRQ_MASK`) registers driving `irq`.

### 3. Frame-Boundary-Safe Configuration CDC (`rtl/taxi_eth_gmii_cfg_cdc.sv`)
- Modifies `rtl/taxi_eth_mac_1g_gmii.sv` and `rtl/taxi_eth_mac_1g_gmii_fifo.sv` to export internal `mac_tx_clk`, `mac_rx_clk`, and `mac_rx_dv` signals.
- Adds `taxi_eth_gmii_cfg_cdc` using a dual-toggle handshake to synchronize the 51-bit configuration bundle from `axis_aclk` into both `tx_clk` and `rx_clk` domains.
- Gates configuration updates in the destination domains with `!tx_active` and `!rx_active` so changes take effect only during inter-frame gaps.

### 4. Kintex UltraScale+ 1G GMII Clock Path Fix (`rtl/taxi_gmii_phy_if.sv`)
- Upstream `taxi` instantiates a `BUFGMUX` in the `FPGA_FAMILY == "kintexuplus"` branch to switch between `gtx_clk` (1G) and `mii_tx_clk` (10/100M). In 1G-only GMII designs where `mii_tx_clk` is tied to `1'b0`, `BUFGMUX` can lock up when its initial select state points to the static `0` input, halting `mac_gmii_tx_clk` and synchronous reset release.
- Replaces the `BUFGMUX` in the `kintexuplus` branch with a direct clock assignment (`assign mac_gmii_tx_clk = gtx_clk;`).

### 5. SoC Integration & Stress Test Suite
- Integrates MicroBlaze, Xilinx AXI DMA (Standard Scatter-Gather mode, `c_micro_dma = 0`), DDR4 SDRAM, `taxi_eth_gmii_axi_wrapper`, and an external Realtek RTL8211EG PHY.
- Provides the reference Block Design reconstruction script (`bd/KU5P_SoC.tcl`, Vivado 2022.2) containing MicroBlaze, DDR4 controller, AXI DMA (Standard SG), UARTLite, and this MAC wrapper (mapped at `0x00020000`).
- Includes bare-metal verification firmware (ARP/ICMP responder, pipelined multi-BD TX burst test, bidirectional soak test, PRBS pattern check, RX starvation test, and DMA reset recovery test) and a host-side Python benchmark script (`scripts/host_stress_test.py`). See [STRESS_TEST_PLAN.md](STRESS_TEST_PLAN.md) for details.

---

## Specifications

- **Target Device**: AMD / Xilinx Kintex UltraScale+ (`xcku5p-ffvb676-2-i`).
- **Top-Level Module**: `taxi_eth_gmii_axi_wrapper` (alias: `taxi_eth_axi_wrapper`).
- **Data Path (AXI4-Stream)**:
  - `S_AXIS_TX`: Transmit packet stream (default 32-bit `TDATA`, 4-bit `TKEEP`, `TVALID`/`TREADY`, `TLAST`, `TUSER` bad-frame abort flag).
  - `M_AXIS_RX`: Receive packet stream (default 32-bit `TDATA`, 4-bit `TKEEP`, `TVALID`/`TREADY`, `TLAST`, `TUSER` bad FCS / frame error flag).
  - Default FIFO depths: `TX_FIFO_DEPTH = 4096`, `RX_FIFO_DEPTH = 4096` (store-and-forward frame FIFO mode).
- **Control & Status (AXI4-Lite)**:
  - `S_AXI_CTRL`: 32-bit AXI4-Lite slave interface with 4 KiB address space.
  - Shadow configuration registers with `APPLY` toggle handshake.
  - 10 saturating 32-bit event counters and level-sensitive maskable interrupt (`irq`).
- **Physical Interface (GMII)**:
  - 8-bit GMII TX and RX data, enable, and error signals.
  - 125 MHz `gtx_clk` reference clock input, forwarding `gmii_tx_clk` to the PHY via an ODDR primitive.

---

## Repository Directory Layout

```text
KU5P-ETH/
├── bd/                                 # Reference Block Design scripts & hardware export
│   ├── KU5P_SoC.tcl                    # Vivado 2022.2 MicroBlaze + AXI DMA + DDR4 + KU5P-ETH example Block Design
│   └── KU5P_SoC_wrapper.xsa            # Exported Vivado hardware platform archive (XSA)
├── rtl/                                # SystemVerilog RTL sources
│   ├── taxi_eth_gmii_axi_wrapper.sv    # [Added] Top-level flat AXI/GMII wrapper
│   ├── taxi_eth_axi_wrapper.sv         # [Added] Alias top-level wrapper
│   ├── taxi_eth_gmii_axil_regs.sv      # [Added] AXI4-Lite control & status registers
│   ├── taxi_eth_gmii_cfg_cdc.sv        # [Added] Configuration CDC mailbox (dual-toggle)
│   ├── taxi_eth_mac_1g_gmii_fifo.sv    # [Modified] 1G GMII MAC + async FIFOs (exports MAC clocks/status)
│   ├── taxi_eth_mac_1g_gmii.sv         # [Modified] 1G GMII MAC core (exports MAC clocks/status)
│   ├── taxi_gmii_phy_if.sv             # [Modified] GMII PHY I/O interface (KU+ 1G clock path fix)
│   ├── taxi_eth_mac_1g.sv              # [Taxi] 1G Ethernet MAC engine
│   ├── taxi_axis_gmii_rx.sv            # [Taxi] GMII RX to AXI-Stream converter
│   ├── taxi_axis_gmii_tx.sv            # [Taxi] AXI-Stream to GMII TX converter
│   ├── taxi_mac_ctrl_tx.sv             # [Taxi] MAC TX controller
│   ├── taxi_mac_ctrl_rx.sv             # [Taxi] MAC RX controller
│   ├── taxi_mac_pause_ctrl_tx.sv       # [Taxi] Flow control (PAUSE) TX
│   ├── taxi_mac_pause_ctrl_rx.sv       # [Taxi] Flow control (PAUSE) RX
│   ├── taxi_ssio_sdr_in.sv             # [Taxi] Source-synchronous SDR input (BUFG for KU+)
│   ├── taxi_ssio_sdr_out.sv            # [Taxi] Source-synchronous SDR output
│   ├── taxi_oddr.sv                    # [Taxi] Xilinx ODDR primitive wrapper
│   ├── taxi_axis_if.sv                 # [Taxi] SystemVerilog interface for AXI-Stream
│   ├── taxi_axis_async_fifo_adapter.sv # [Taxi] AXI-Stream async FIFO + width adapter
│   ├── taxi_axis_async_fifo.sv         # [Taxi] AXI-Stream async FIFO (CDC)
│   ├── taxi_axis_adapter.sv            # [Taxi] AXI-Stream width converter
│   ├── taxi_axis_arb_mux.sv            # [Taxi] AXI-Stream arbiter multiplexer
│   ├── taxi_axis_pad.sv                # [Taxi] Frame padding module (minimum 60 bytes)
│   ├── taxi_axis_null_src.sv           # [Taxi] AXI-Stream null source tie-off
│   ├── taxi_axis_tie.sv                # [Taxi] AXI-Stream bus tie-off helper
│   ├── taxi_sync_reset.sv              # [Taxi] Multi-stage async assert / sync deassert reset
│   ├── taxi_sync_signal.sv             # [Taxi] Multi-stage CDC synchronizer
│   ├── taxi_arbiter.sv                 # [Taxi] Priority / Round-robin arbiter
│   ├── taxi_penc.sv                    # [Taxi] Priority encoder
│   ├── taxi_lfsr.sv                    # [Taxi] CRC32 generator
│   ├── taxi_eth_mac_stats.sv           # [Taxi] MAC statistics stream generator
│   ├── taxi_stats_collect.sv           # [Taxi] Statistics event counter
│   └── taxi_eth_gmii_axi_wrapper.f     # Topologically sorted filelist
├── constrs/                            # Timing and CDC constraint scripts
│   ├── ku5p_eth_timing.xdc             # KU5P board timing & clocks constraint
│   ├── taxi_eth_gmii_cfg_cdc.tcl       # Config mailbox max-delay & skew constraints
│   ├── taxi_eth_mac_fifo.tcl           # MAC FIFO CDC synchronizer constraints
│   ├── taxi_axis_async_fifo.tcl        # AXI-Stream async FIFO pointer CDC constraints
│   ├── taxi_sync_reset.tcl             # Reset synchronizer false-path constraints
│   └── taxi_sync_signal.tcl            # Signal synchronizer false-path constraints
├── tb/                                 # Verification & Simulation
│   ├── test_taxi_eth_gmii_axi_wrapper.sv # SystemVerilog testbench
│   ├── Makefile                        # Verilator simulation Makefile
│   ├── run_sim_xsim.bat                # Vivado xsim batch run script (Windows)
│   └── run_sim_xsim.tcl                # Vivado xsim execution TCL script
├── sw/                                 # Modular bare-metal test suite sources
│   ├── helloworld.c / main.c           # System initialization & interactive test menu entry
│   ├── eth_mac.h / eth_mac.c           # MAC CSR access and event counter driver
│   ├── eth_dma.h / eth_dma.c           # AXI DMA Scatter-Gather ring setup & packet polling
│   ├── packet_builder.h / .c           # Packet construction & auto ARP / ICMP reply handlers
│   ├── stress_tests.h / .c             # Stress test cases (TX burst, soak, PRBS, DMA recovery)
│   ├── platform.h / platform.c         # Vitis platform cache & UART initialization
│   ├── platform_config.h               # Platform hardware configuration header
│   └── lscript.ld                      # MicroBlaze DDR4 linker script
├── scripts/                            # Automation and test scripts
│   ├── create_project.tcl              # Create KU5P-ETH project in Vivado
│   ├── run_synth.tcl                   # Out-of-Context & Full Synthesis script
│   ├── package_ip.tcl                  # Package core into Vivado IP Catalog
│   └── host_stress_test.py             # Host-side Python UDP/ICMP stress test script
├── reports/                            # Synthesis utilization and timing reports
├── STRESS_TEST_PLAN.md                 # Hardware stress test plan and verification guide
└── .gitignore                          # Git ignore rules
```

---

## Module Interfaces & Signal Map

### Top-Level Port Summary (`taxi_eth_gmii_axi_wrapper` / `taxi_eth_axi_wrapper`)

| Group | Signal | Direction | Width | Description |
| :--- | :--- | :---: | :---: | :--- |
| **Clocks & Resets** | `axis_aclk` | In | 1 | Clock for AXI4-Lite, AXI4-Stream TX/RX, and CSR logic (100–125 MHz). |
| | `axis_aresetn` | In | 1 | Asynchronous active-low reset for AXI domain (internally synchronized). |
| | `gtx_clk` | In | 1 | 125.0 MHz reference clock for 1G GMII transmit path. |
| | `gtx_reset` | In | 1 | Asynchronous active-high reset for GMII MAC core. |
| **AXI4-Lite CSR** | `s_axi_ctrl_awaddr` | In | 12 | Write address (32-bit aligned). |
| | `s_axi_ctrl_awvalid`/`ready` | In/Out | 1 | Write address handshake. |
| | `s_axi_ctrl_wdata` | In | 32 | Write data. |
| | `s_axi_ctrl_wstrb` | In | 4 | Write strobe byte-enables. |
| | `s_axi_ctrl_wvalid`/`ready` | In/Out | 1 | Write data handshake (AW and W can arrive independently). |
| | `s_axi_ctrl_bresp` | Out | 2 | Write response (`2'b00` OKAY, `2'b10` SLVERR). |
| | `s_axi_ctrl_bvalid`/`ready` | Out/In | 1 | Write response handshake. |
| | `s_axi_ctrl_araddr` | In | 12 | Read address. |
| | `s_axi_ctrl_arvalid`/`ready` | In/Out | 1 | Read address handshake. |
| | `s_axi_ctrl_rdata` | Out | 32 | Read data. |
| | `s_axi_ctrl_rresp` | Out | 2 | Read response. |
| | `s_axi_ctrl_rvalid`/`ready` | Out/In | 1 | Read data handshake. |
| | `irq` | Out | 1 | Level-high interrupt output (`|(IRQ_PENDING & IRQ_MASK)`). |
| **AXI4-Stream TX** | `s_axis_tx_tdata` | In | 32 | Transmit packet data stream. |
| | `s_axis_tx_tkeep` | In | 4 | Byte keep mask. |
| | `s_axis_tx_tvalid`/`ready` | In/Out | 1 | Transmit stream handshake. |
| | `s_axis_tx_tlast` | In | 1 | End-of-frame indicator. |
| | `s_axis_tx_tuser` | In | 1 | Bad-frame abort request flag. |
| **AXI4-Stream RX** | `m_axis_rx_tdata` | Out | 32 | Receive packet data stream. |
| | `m_axis_rx_tkeep` | Out | 4 | Byte keep mask. |
| | `m_axis_rx_tvalid`/`ready` | Out/In | 1 | Receive stream handshake. |
| | `m_axis_rx_tlast` | Out | 1 | End-of-frame indicator. |
| | `m_axis_rx_tuser` | Out | 1 | Frame error indicator (bad FCS / oversized frame). |
| **GMII PHY** | `gmii_rx_clk` | In | 1 | 125 MHz receive clock from external Ethernet PHY. |
| | `gmii_rxd` | In | 8 | Receive data bus. |
| | `gmii_rx_dv` | In | 1 | Receive data valid. |
| | `gmii_rx_er` | In | 1 | Receive error. |
| | `mii_tx_clk` | In | 1 | 10/100M MII transmit clock (tie to `0` in 1G GMII mode). |
| | `gmii_tx_clk` | Out | 1 | Forwarded transmit clock to PHY (ODDR generated). |
| | `gmii_txd` | Out | 8 | Transmit data bus. |
| | `gmii_tx_en` | Out | 1 | Transmit enable. |
| | `gmii_tx_er` | Out | 1 | Transmit error. |
| **Status Monitors** | `tx_error_underflow` | Out | 1 | TX FIFO underflow event (`axis_aclk` domain). |
| | `tx_fifo_overflow` | Out | 1 | TX FIFO overflow event. |
| | `tx_fifo_bad_frame` | Out | 1 | TX bad frame event. |
| | `tx_fifo_good_frame` | Out | 1 | TX good frame committed event. |
| | `rx_error_bad_frame` | Out | 1 | RX bad frame event. |
| | `rx_error_bad_fcs` | Out | 1 | RX FCS mismatch event. |
| | `rx_fifo_overflow` | Out | 1 | RX FIFO overflow drop event. |
| | `rx_fifo_bad_frame` | Out | 1 | RX bad frame drop event. |
| | `rx_fifo_good_frame` | Out | 1 | RX good frame accepted event. |
| | `link_speed` | Out | 2 | Estimated link speed (`2'd2`: 1 Gbps, `2'd1`: 100 Mbps, `2'd0`: 10 Mbps). |

---

## AXI4-Lite Register Map (CSR)

All offsets are byte offsets and 32-bit aligned. Accessing undefined addresses or issuing invalid write strobes returns `SLVERR` (`2'b10`).

| Byte Offset | Register Name | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :--- |
| `0x000` | **IP_ID** | RO | `0x54474D49` | ASCII identifier: `"TGMI"` (Taxi GMII). |
| `0x004` | **VERSION** | RO | `0x00010000` | IP Core version `1.0.0`. |
| `0x008` | **STATUS** | RO | `0x00000002` | `bit[1:0]`: Link speed estimate (`2'd2` = 1G).<br>`bit[8]`: `CFG_BUSY` (1 = CDC sync in progress). |
| `0x00C` | **APPLY** | WO | `0x00000000` | Write `1` to commit shadow registers to hardware.<br>Returns `SLVERR` if `CFG_BUSY == 1`. Reads return 0. |
| `0x010` | **CONTROL** | RW | `0x00000007` | `bit[0]`: TX Enable (`1` = active).<br>`bit[1]`: RX Enable (`1` = active).<br>`bit[2]`: TX Automatic Padding Enable (`1` = pad to min len). |
| `0x014` | **TX_MIN_LEN** | RW | `0x0000003B` | Minimum TX frame length minus 1 (Default: `59` = 60 bytes, excluding FCS). |
| `0x018` | **TX_MAX_LEN** | RW | `0x000005ED` | Maximum TX frame length minus 1 (Default: `1517` = 1518 bytes, including FCS). |
| `0x01C` | **RX_MAX_LEN** | RW | `0x000005ED` | Maximum RX frame length minus 1 (Default: `1517` = 1518 bytes, including FCS). |
| `0x020` | **TX_IFG** | RW | `0x0000000C` | Transmit Inter-Frame Gap (Default: `12` bytes). |
| `0x024` | **IRQ_PENDING** | RO/W1C| `0x00000000` | Sticky event status (`bit[9:0]`). Write `1` to clear (W1C). |
| `0x028` | **IRQ_MASK** | RW | `0x00000000` | Interrupt enable mask (`bit[9:0]`). Set `1` to assert `irq`. |
| `0x02C` | **COUNTER_CLEAR**| WO | `0x00000000` | Write `1` to clear all 10 event counters. Reading returns `SLVERR`. |
| `0x040` | **EVENT_CNT_0** | RO | `0x00000000` | TX underflow event counter (32-bit saturating). |
| `0x044` | **EVENT_CNT_1** | RO | `0x00000000` | TX FIFO overflow counter. |
| `0x048` | **EVENT_CNT_2** | RO | `0x00000000` | TX FIFO bad frame counter. |
| `0x04C` | **EVENT_CNT_3** | RO | `0x00000000` | TX FIFO good frame counter. |
| `0x050` | **EVENT_CNT_4** | RO | `0x00000000` | RX bad frame error counter. |
| `0x054` | **EVENT_CNT_5** | RO | `0x00000000` | RX bad FCS error counter. |
| `0x058` | **EVENT_CNT_6** | RO | `0x00000000` | RX FIFO overflow counter. |
| `0x05C` | **EVENT_CNT_7** | RO | `0x00000000` | RX FIFO bad frame counter. |
| `0x060` | **EVENT_CNT_8** | RO | `0x00000000` | RX FIFO good frame counter. |
| `0x064` | **EVENT_CNT_9** | RO | `0x00000000` | TX start-event counter. |

---

## Configuration Update Procedure (CDC Handshake)

To update MAC parameters at runtime:

1. **Quiesce Traffic**: Stop queuing new TX DMA descriptors and allow in-flight transmissions to complete.
2. **Poll BUSY**: Read `STATUS` (`0x008`) and verify `bit[8]` (`CFG_BUSY`) is `0`.
3. **Write Shadows**: Update `CONTROL`, `TX_MIN_LEN`, `TX_MAX_LEN`, `RX_MAX_LEN`, or `TX_IFG`.
4. **Trigger Apply**: Write `1` to `APPLY` (`0x00C`).
5. **Wait Acknowledgment**: Poll `STATUS` (`0x008`) until `CFG_BUSY` returns to `0`.
6. **Resume Traffic**: Re-enable DMA traffic.

```c
/* Example C Driver Snippet */
#define ETH_BASE            0x00020000U
#define REG_STATUS          (ETH_BASE + 0x008U)
#define REG_APPLY           (ETH_BASE + 0x00CU)
#define REG_CONTROL         (ETH_BASE + 0x010U)

void eth_configure(uint32_t ctrl_flags) {
    while (Xil_In32(REG_STATUS) & 0x100U);
    Xil_Out32(REG_CONTROL, ctrl_flags);
    Xil_Out32(REG_APPLY, 0x1U);
    while (Xil_In32(REG_STATUS) & 0x100U);
}
```

---

## Xilinx AXI DMA Integration Notes

When connecting this IP to Xilinx AXI DMA (`axi_dma_v7_1`), observe the following requirements:

1. **Disable Micro DMA Mode (`CONFIG.c_micro_dma = 0`)**:
   - In Xilinx `axi_dma_v7_1`, setting `c_micro_dma = 1` forces `C_S2MM_SUPPORT_INDET_BTT = 0` inside the VHDL wrapper. Because received Ethernet frames have variable lengths (60 to 1514 bytes) and assert `tlast` before the full buffer length is reached, `axi_datamover` raises `sig_tlast_error_under` and deasserts `s_axis_s2mm_tready`, halting the RX channel and causing `RX_FIFO_OVERFLOW`.
   - Configure the AXI DMA instance in Standard Scatter-Gather mode (`c_micro_dma = 0`).
2. **RX BD Ring Sizing & Deterministic Buffer Mapping**:
   - Match `RX_BD_SPACE_HIGH - RX_BD_SPACE_BASE + 1` to `RX_BUFFERS_NUM * XAXIDMA_BD_MINIMUM_ALIGNMENT`, or compute the DDR4 buffer address directly from the descriptor index during RX BD replenishment so uninitialized BDs (with buffer address `0x00000000`) are never submitted to hardware (`DMADecErr` / `S2MM_SR = 0x00015049`).
3. **Driver `MaxTransferLen` Mask Fix**:
   - Some Vitis BSP versions of `XAxiDma_CfgInitialize` set `MaxTransferLen = 1U << SgLengthWidth`, causing the bitmask inside `XAxiDma_BdSetLength` to evaluate to `0`. Override `MaxTransferLen` to `(1U << cfg->SgLengthWidth) - 1U` after initialization.

---

## Vivado Project Setup & IP Packaging

### 1. Project Creation

Run the TCL script in Vivado to create `KU5P-ETH.xpr` targeting `xcku5p-ffvb676-2-i`:

```cmd
vivado -mode batch -source scripts/create_project.tcl
```

### 2. Vivado IP Packaging

Package the core for Vivado IP Catalog / Block Design:

```cmd
vivado -mode batch -source scripts/package_ip.tcl
```

The packaged IP is generated in `ip_repo/taxi_eth_gmii_axi_wrapper/`.

### 3. Recreate Example Block Design (KU5P_SoC)

The repository provides the validated example Block Design script (`bd/KU5P_SoC.tcl`) integrating MicroBlaze, DDR4 controller, AXI DMA in Standard SG mode (`c_micro_dma = 0`), UARTLite, and this MAC IP (`0x00020000`). After packaging the IP, reconstruct the complete Block Design in Vivado:

```cmd
vivado -mode batch -source bd/KU5P_SoC.tcl
```

### 4. Synthesis

Run Out-Of-Context synthesis and generate utilization and timing reports:

```cmd
vivado -mode batch -source scripts/run_synth.tcl
```

Reports are written to `reports/utilization_summary.rpt` and `reports/timing_summary.rpt`.

---

## Simulation & Verification

The repository includes a SystemVerilog testbench (`tb/test_taxi_eth_gmii_axi_wrapper.sv`) covering:
- AXI4-Lite read/write handshakes, byte strobes (`WSTRB`), and backpressure.
- Shadow register updates and dual-toggle CDC synchronization.
- Inter-frame gap (IFG) configuration.
- Sticky interrupt handling (`IRQ_PENDING`, `IRQ_MASK`, W1C).
- 32-bit saturating event counters and `COUNTER_CLEAR`.
- PHY RX clock loss and recovery.
- 73 loopback Ethernet frames across undersized, standard, and oversized lengths with FCS checking.

### Running with Verilator:
```bash
cd tb
make test
```

### Running with Vivado xsim:
```cmd
cd tb
run_sim_xsim.bat
```

---

## License

Licensed under the **CERN Open Hardware Licence Version 2 - Strongly Reciprocal (CERN-OHL-S-2.0)**.
Original MAC and FIFO modules copyright (c) 2016-2025 FPGA Ninja, LLC (Alex Forencich).
Wrapper and KU5P modifications copyright (c) 2026.
