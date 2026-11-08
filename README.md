# KU5P-ETH: Kintex UltraScale+ 1G GMII Ethernet MAC AXI Wrapper

[English](README.md) | [繁體中文](README_zh.md)

**KU5P-ETH** is a self-contained, high-performance Gigabit Ethernet (1G GMII) MAC IP repository with AXI4-Stream data interfaces, AXI4-Lite control/status registers, and multi-domain CDC (Clock Domain Crossing), optimized specifically for the **AMD / Xilinx Kintex UltraScale+ (`xcku5p-ffvb676-2-i`)** FPGA family (`FPGA_FAMILY = "kintexuplus"`).

The core wraps the proven 1G GMII MAC and asynchronous frame FIFO subsystem from the Taxi project, providing standard flat bus interfaces ready for Vivado IP Integrator (Block Design) and custom SoC integration.

---

## Key Features

- **Target Device**: AMD / Xilinx Kintex UltraScale+ (`xcku5p-ffvb676-2-i` and all UltraScale+ family devices).
- **Core Wrapper**: `taxi_eth_gmii_axi_wrapper` (with top-level alias `taxi_eth_axi_wrapper`).
- **Data Path (AXI4-Stream)**:
  - `S_AXIS_TX`: Transmit packet stream (default 32-bit TDATA, TKEEP, TVALID/TREADY, TLAST, TUSER for bad-frame abort).
  - `M_AXIS_RX`: Receive packet stream (default 32-bit TDATA, TKEEP, TVALID/TREADY, TLAST, TUSER for bad FCS / bad frame indicator).
  - Configurable FIFO depths (`TX_FIFO_DEPTH = 4096`, `RX_FIFO_DEPTH = 4096`).
  - Automatic frame FIFO store-and-forward mode: bad frames and undersized/oversized frames can be filtered or dropped before entering memory.
- **Control & Status (AXI4-Lite)**:
  - `S_AXI_CTRL`: Standard 32-bit AXI4-Lite slave interface with 4 KiB address space.
  - Shadow configuration registers with synchronized hardware `APPLY` toggle handshake.
  - Dedicated event counters (saturated 32-bit) and level-sensitive maskable interrupt (`irq`).
- **Physical Interface (GMII)**:
  - Standard 8-bit GMII TX and RX data, enable, error flags.
  - 125 MHz GTX reference clock input.
  - Forwarded transmit clock generated via hardware ODDR flip-flop primitive.
  - Dedicated clock buffer handling (`BUFG` for Kintex UltraScale+ architecture).
- **Clock Domain Crossing (CDC)**:
  - Robust dual-toggle handshake across `axis_aclk`, MAC `gtx_clk`, and `gmii_rx_clk`.
  - Accompanied by specialized Vivado timing constraint scripts (`set_max_delay -datapath_only` and `set_bus_skew`).

---

## Repository Directory Layout

```text
KU5P-ETH/
├── rtl/                                # Self-contained SystemVerilog RTL sources
│   ├── taxi_eth_gmii_axi_wrapper.sv    # Top-level flat AXI/GMII wrapper
│   ├── taxi_eth_axi_wrapper.sv         # Alias top-level wrapper for KU5P
│   ├── taxi_eth_gmii_axil_regs.sv      # AXI4-Lite control & status registers
│   ├── taxi_eth_gmii_cfg_cdc.sv        # Configuration CDC mailbox (dual toggle)
│   ├── taxi_eth_mac_1g_gmii_fifo.sv    # 1G GMII MAC + TX/RX async FIFO integration
│   ├── taxi_eth_mac_1g_gmii.sv         # 1G GMII MAC core
│   ├── taxi_eth_mac_1g.sv              # 1G Ethernet MAC engine
│   ├── taxi_axis_gmii_rx.sv            # GMII RX to AXI-Stream converter
│   ├── taxi_axis_gmii_tx.sv            # AXI-Stream to GMII TX converter
│   ├── taxi_mac_ctrl_tx.sv             # MAC TX controller
│   ├── taxi_mac_ctrl_rx.sv             # MAC RX controller
│   ├── taxi_mac_pause_ctrl_tx.sv       # Flow control (PAUSE) TX
│   ├── taxi_mac_pause_ctrl_rx.sv       # Flow control (PAUSE) RX
│   ├── taxi_gmii_phy_if.sv             # GMII PHY I/O interface
│   ├── taxi_ssio_sdr_in.sv             # Source-synchronous SDR input (BUFG for KU+)
│   ├── taxi_ssio_sdr_out.sv            # Source-synchronous SDR output
│   ├── taxi_oddr.sv                    # Generic / Xilinx ODDR primitive wrapper
│   ├── taxi_axis_if.sv                 # SystemVerilog interface for AXI-Stream
│   ├── taxi_axis_async_fifo_adapter.sv # AXI-Stream async FIFO + width adapter
│   ├── taxi_axis_async_fifo.sv         # AXI-Stream async FIFO (CDC)
│   ├── taxi_axis_adapter.sv            # AXI-Stream width converter
│   ├── taxi_axis_arb_mux.sv            # AXI-Stream arbiter multiplexer
│   ├── taxi_axis_pad.sv                # Frame padding logic (minimum 60 bytes)
│   ├── taxi_axis_null_src.sv           # AXI-Stream null source tie-off
│   ├── taxi_axis_tie.sv                # AXI-Stream bus tie-off helper
│   ├── taxi_sync_reset.sv              # Multi-stage asynchronous assert / synchronous deassert
│   ├── taxi_sync_signal.sv             # Multi-stage CDC synchronizer
│   ├── taxi_arbiter.sv                 # Priority / Round-robin arbiter
│   ├── taxi_penc.sv                    # Priority encoder
│   ├── taxi_lfsr.sv                    # CRC32 calculation generator
│   ├── taxi_eth_mac_stats.sv           # MAC statistics stream generator
│   ├── taxi_stats_collect.sv           # Statistics event counter
│   └── taxi_eth_gmii_axi_wrapper.f     # Topologically sorted filelist
├── constrs/                            # Timing and CDC constraint scripts
│   ├── ku5p_eth_timing.xdc             # KU5P board timing & clocks constraint
│   ├── taxi_eth_gmii_cfg_cdc.tcl       # Config mailbox max-delay & skew constraints
│   ├── taxi_eth_mac_fifo.tcl           # MAC FIFO CDC synchronizer constraints
│   ├── taxi_axis_async_fifo.tcl        # AXI-Stream async FIFO pointer CDC constraints
│   ├── taxi_sync_reset.tcl             # Reset synchronizer false-path constraints
│   └── taxi_sync_signal.tcl            # Signal synchronizer false-path constraints
├── tb/                                 # Verification & Simulation
│   ├── test_taxi_eth_gmii_axi_wrapper.sv # SystemVerilog self-checking testbench
│   ├── Makefile                        # Verilator simulation Makefile
│   ├── run_sim_xsim.bat                # Vivado xsim batch run script (Windows)
│   └── run_sim_xsim.tcl                # Vivado xsim execution TCL script
├── scripts/                            # Vivado automation scripts
│   ├── create_project.tcl              # Create KU5P-ETH project in Vivado
│   ├── run_synth.tcl                   # Out-of-Context & Full Synthesis script
│   └── package_ip.tcl                  # Package core into Vivado IP Catalog
├── reports/                            # Synthesis utilization and timing reports
└── .gitignore                          # Git ignore rules for Vivado and build files
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
| | `s_axi_ctrl_bvalid`/`ready` | Out/In | 1 | Write response handshake with backpressure support. |
| | `s_axi_ctrl_araddr` | In | 12 | Read address. |
| | `s_axi_ctrl_arvalid`/`ready` | In/Out | 1 | Read address handshake. |
| | `s_axi_ctrl_rdata` | Out | 32 | Read data. |
| | `s_axi_ctrl_rresp` | Out | 2 | Read response. |
| | `s_axi_ctrl_rvalid`/`ready` | Out/In | 1 | Read data handshake with backpressure support. |
| | `irq` | Out | 1 | Level-high interrupt output (`IRQ_PENDING & IRQ_MASK`). |
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
| | `mii_tx_clk` | In | 1 | 10/100M MII transmit clock (tie to `0` when in 1G GMII mode). |
| | `gmii_tx_clk` | Out | 1 | Forwarded transmit clock to PHY (ODDR generated). |
| | `gmii_txd` | Out | 8 | Transmit data bus. |
| | `gmii_tx_en` | Out | 1 | Transmit enable. |
| | `gmii_tx_er` | Out | 1 | Transmit error. |
| **Status Monitors** | `tx_error_underflow` | Out | 1 | TX FIFO underflow error (axis_aclk domain). |
| | `tx_fifo_overflow` | Out | 1 | TX FIFO overflow error. |
| | `tx_fifo_bad_frame` | Out | 1 | TX bad frame event. |
| | `tx_fifo_good_frame` | Out | 1 | TX good frame committed. |
| | `rx_error_bad_frame` | Out | 1 | RX bad frame event. |
| | `rx_error_bad_fcs` | Out | 1 | RX FCS mismatch event. |
| | `rx_fifo_overflow` | Out | 1 | RX FIFO overflow drop. |
| | `rx_fifo_bad_frame` | Out | 1 | RX bad frame drop. |
| | `rx_fifo_good_frame` | Out | 1 | RX good frame accepted. |
| | `link_speed` | Out | 2 | Estimated link speed (`2'd2`: 1 Gbps, `2'd1`: 100 Mbps, `2'd0`: 10 Mbps). |

---

## AXI4-Lite Register Map (CSR)

All offsets are byte offsets and 32-bit aligned. Accessing undefined addresses or issuing invalid write strobes returns `SLVERR` (`2'b10`).

| Byte Offset | Register Name | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :--- |
| `0x000` | **IP_ID** | RO | `0x54474D49` | Magic ASCII identifier: `"TGMI"` (Taxi GMII). |
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

To prevent frame corruption or FIFO mismatch, configuration changes must follow this safe sequence:

1. **Quiesce Traffic**: Stop queuing new TX DMA descriptors and allow TX FIFO / line transmissions to complete.
2. **Poll BUSY**: Read `STATUS` (`0x008`) and ensure `bit[8]` (`CFG_BUSY`) is `0`.
3. **Write Shadows**: Update desired registers (`CONTROL`, `TX_MIN_LEN`, `TX_MAX_LEN`, `RX_MAX_LEN`, `TX_IFG`).
4. **Trigger Apply**: Write `1` to `APPLY` (`0x00C`).
5. **Wait Acknowledgment**: Poll `STATUS` (`0x008`) with a timeout until `CFG_BUSY` returns to `0`.
6. **Resume Traffic**: Re-enable DMA traffic.

```c
/* Example C Driver Snippet */
#define ETH_BASE            0x80000000
#define REG_STATUS          (ETH_BASE + 0x008)
#define REG_APPLY           (ETH_BASE + 0x00C)
#define REG_CONTROL         (ETH_BASE + 0x010)

void eth_configure(uint32_t ctrl_flags) {
    /* Step 1: Wait until not busy */
    while (Xil_In32(REG_STATUS) & 0x100);

    /* Step 2: Write shadow control */
    Xil_Out32(REG_CONTROL, ctrl_flags);

    /* Step 3: Commit */
    Xil_Out32(REG_APPLY, 0x1);

    /* Step 4: Wait for both clock domains to acknowledge */
    while (Xil_In32(REG_STATUS) & 0x100);
}
```

---

## Vivado Project Setup & IP Packaging

### 1. Automated Project Creation

Run the automated TCL script in Vivado to create `KU5P-ETH.xpr` targeting `xcku5p-ffvb676-2-i`:

```cmd
vivado -mode batch -source scripts/create_project.tcl
```

### 2. Vivado IP Packaging

To package the core for Vivado IP Catalog / Block Design:

```cmd
vivado -mode batch -source scripts/package_ip.tcl
```

The packaged IP will be generated in `ip_repo/taxi_eth_gmii_axi_wrapper/` with AXI interfaces pre-associated.

### 3. Synthesis Automation

To run Out-Of-Context synthesis and generate utilization/timing reports:

```cmd
vivado -mode batch -source scripts/run_synth.tcl
```

Reports will be written to `reports/utilization_summary.rpt` and `reports/timing_summary.rpt`.

---

## Simulation & Verification

The repository includes a comprehensive self-checking testbench (`tb/test_taxi_eth_gmii_axi_wrapper.sv`) covering:
- AXI4-Lite read/write handshake, byte strobes (`WSTRB`), backpressure.
- Shadow register updates and dual-toggle CDC verification.
- Inter-frame gap (IFG) configuration.
- Sticky interrupt handling (`IRQ_PENDING`, `IRQ_MASK`, W1C).
- 32-bit saturating event counters and reset clearing.
- Line clock loss / recovery resilience.
- 73 loopback Ethernet frames spanning undersized, normal, jumbo packets, padding, and FCS.

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
Wrapper and KU5P adaptations copyright (c) 2026.
