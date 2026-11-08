# KU5P-ETH: Kintex UltraScale+ 1G GMII Ethernet MAC AXI 包裝模組

[English](README.md) | [繁體中文](README_zh.md)

**KU5P-ETH** 是一個自包含、高效能的 Gigabit Ethernet（1G GMII）MAC IP 倉庫，具備標準 AXI4-Stream 資料串流介面、AXI4-Lite 控制／狀態暫存器與多時脈域 CDC（跨時脈域同步處理），專門針對 **AMD / Xilinx Kintex UltraScale+ (`xcku5p-ffvb676-2-i`)** FPGA 系列（`FPGA_FAMILY = "kintexuplus"`）進行優化。

本設計封裝了源自 Taxi 專案經過充分驗證的 1G GMII MAC 核心與非同步 Frame FIFO 子系統，提供平面的標準匯流排介面，可直接用於 Vivado IP Integrator（Block Design）或自訂 SoC 整合。

---

## 核心特點

- **目標 FPGA 元件**：AMD / Xilinx Kintex UltraScale+（`xcku5p-ffvb676-2-i` 及所有 UltraScale+ 系列元件）。
- **頂層模組**：`taxi_eth_gmii_axi_wrapper`（並提供頂層別名模組 `taxi_eth_axi_wrapper`）。
- **資料路徑（AXI4-Stream）**：
  - `S_AXIS_TX`：發送封包串流（預設 32-bit TDATA、4-bit TKEEP、TVALID/TREADY、TLAST、TUSER 壞框中止旗標）。
  - `M_AXIS_RX`：接收封包串流（預設 32-bit TDATA、4-bit TKEEP、TVALID/TREADY、TLAST、TUSER 壞框／FCS 錯誤旗標）。
  - 可配置之 TX/RX 非同步 FIFO 深度（預設 `TX_FIFO_DEPTH = 4096`、`RX_FIFO_DEPTH = 4096`）。
  - 內建 Store-and-Forward Frame FIFO：過長、損毀或 FCS 錯誤之封包可在進入系統記憶體前直接丟棄。
- **控制與狀態（AXI4-Lite）**：
  - `S_AXI_CTRL`：標準 32-bit AXI4-Lite Slave 介面，具 4 KiB 位址空間。
  - 具備 Shadow 配置暫存器與同步硬體 `APPLY` 握手轉發機制。
  - 內建 10 組 32-bit 飽和計數器與高有效可遮罩中斷（`irq`）。
- **實體層介面（GMII）**：
  - 標準 8-bit GMII TX 與 RX 資料、致能、錯誤信號。
  - 125 MHz GTX 參考時脈輸入。
  - 透過硬體 ODDR 原語產生 Forwarded 傳送時脈至 PHY。
  - 專門針對 Kintex UltraScale+ 架構的時脈緩衝處理（BUFG）。
- **時脈域跨越（CDC）**：
  - `axis_aclk`、MAC `gtx_clk` 與 `gmii_rx_clk` 間具備強健的 Dual-Toggle 握手與同步器。
  - 隨附 Vivado 專屬時序約束腳本（`set_max_delay -datapath_only` 與 `set_bus_skew`）。

---

## 倉庫檔案結構

```text
KU5P-ETH/
├── rtl/                                # 完整自包含之 SystemVerilog RTL 原始碼
│   ├── taxi_eth_gmii_axi_wrapper.sv    # 頂層平面 AXI/GMII Wrapper
│   ├── taxi_eth_axi_wrapper.sv         # 專屬別名頂層 Wrapper（相容 KU5P 命名）
│   ├── taxi_eth_gmii_axil_regs.sv      # AXI4-Lite 控制與狀態暫存器
│   ├── taxi_eth_gmii_cfg_cdc.sv        # 配置 CDC Mailbox（Dual-Toggle 同步）
│   ├── taxi_eth_mac_1g_gmii_fifo.sv    # 1G GMII MAC + 非同步 TX/RX FIFO
│   ├── taxi_eth_mac_1g_gmii.sv         # 1G GMII MAC 核心
│   ├── taxi_eth_mac_1g.sv              # 1G 乙太網路 MAC 引擎
│   ├── taxi_axis_gmii_rx.sv            # GMII RX 轉 AXI-Stream
│   ├── taxi_axis_gmii_tx.sv            # AXI-Stream 轉 GMII TX
│   ├── taxi_mac_ctrl_tx.sv             # MAC 發送控制模組
│   ├── taxi_mac_ctrl_rx.sv             # MAC 接收控制模組
│   ├── taxi_mac_pause_ctrl_tx.sv       # 流量控制（PAUSE）發送模組
│   ├── taxi_mac_pause_ctrl_rx.sv       # 流量控制（PAUSE）接收模組
│   ├── taxi_gmii_phy_if.sv             # GMII PHY I/O 介面
│   ├── taxi_ssio_sdr_in.sv             # 源同步 SDR 輸入（KU+ 採用 BUFG）
│   ├── taxi_ssio_sdr_out.sv            # 源同步 SDR 輸出
│   ├── taxi_oddr.sv                    # 通用／Xilinx ODDR 原語包裝
│   ├── taxi_axis_if.sv                 # AXI-Stream SystemVerilog Interface 定義
│   ├── taxi_axis_async_fifo_adapter.sv # 非同步 FIFO 寬度轉換介面
│   ├── taxi_axis_async_fifo.sv         # AXI-Stream 非同步 FIFO（CDC 指針同步）
│   ├── taxi_axis_adapter.sv            # AXI-Stream 寬度轉換核心
│   ├── taxi_axis_arb_mux.sv            # AXI-Stream 仲裁多工器
│   ├── taxi_axis_pad.sv                # 封包自動補零填補模組（最小 60 位元組）
│   ├── taxi_axis_null_src.sv           # AXI-Stream 空來源 Tie-off
│   ├── taxi_axis_tie.sv                # AXI-Stream 匯流排 Tie-off 輔助
│   ├── taxi_sync_reset.sv              # 非同步觸發／同步釋放 Reset 同步器
│   ├── taxi_sync_signal.sv             # 多級信號 CDC 同步器
│   ├── taxi_arbiter.sv                 # 優先權／輪轉仲裁器
│   ├── taxi_penc.sv                    # 優先權編碼器
│   ├── taxi_lfsr.sv                    # CRC32 計算模組
│   ├── taxi_eth_mac_stats.sv           # MAC 統計串流產生器
│   ├── taxi_stats_collect.sv           # 統計事件計數收集器
│   └── taxi_eth_gmii_axi_wrapper.f     # 拓撲編譯順序原始碼清單
├── constrs/                            # 時序與 CDC 約束腳本
│   ├── ku5p_eth_timing.xdc             # KU5P 板級時鐘與 I/O 時序約束
│   ├── taxi_eth_gmii_cfg_cdc.tcl       # 配置 Mailbox Datapath Max-Delay 約束
│   ├── taxi_eth_mac_fifo.tcl           # MAC FIFO CDC 同步器約束
│   ├── taxi_axis_async_fifo.tcl        # AXI-Stream 非同步 FIFO 指針約束
│   ├── taxi_sync_reset.tcl             # Reset 同步器 False-Path 約束
│   └── taxi_sync_signal.tcl            # 信號同步器 False-Path 約束
├── tb/                                 # 驗證與模擬檔案
│   ├── test_taxi_eth_gmii_axi_wrapper.sv # SystemVerilog 自我校驗測試平台
│   ├── Makefile                        # Verilator 模擬 Makefile
│   ├── run_sim_xsim.bat                # Vivado xsim 批次執行腳本（Windows）
│   └── run_sim_xsim.tcl                # Vivado xsim 執行控制 TCL 腳本
├── scripts/                            # Vivado 自動化腳本
│   ├── create_project.tcl              # 建立 KU5P-ETH Vivado 專案
│   ├── run_synth.tcl                   # 綜合與產生利用率／時序報告腳本
│   └── package_ip.tcl                  # 打包為 Vivado IP Catalog 元件腳本
├── reports/                            # 綜合產出之利用率與時序報告目錄
└── .gitignore                          # Git 忽略規則
```

---

## 介面與信號說明

### 頂層埠清單（`taxi_eth_gmii_axi_wrapper` / `taxi_eth_axi_wrapper`）

| 群組 | 信號名稱 | 方向 | 位元寬 | 說明 |
| :--- | :--- | :---: | :---: | :--- |
| **時鐘與重設** | `axis_aclk` | 輸入 | 1 | AXI4-Lite、AXI4-Stream TX/RX 及暫存器時鐘（100–125 MHz）。 |
| | `axis_aresetn` | 輸入 | 1 | AXI 域非同步低有效重設（內部同步釋放）。 |
| | `gtx_clk` | 輸入 | 1 | 125.0 MHz 參考時鐘（用於 1G GMII 發送路徑）。 |
| | `gtx_reset` | 輸入 | 1 | GMII MAC 核心非同步高有效重設。 |
| **AXI4-Lite 控制** | `s_axi_ctrl_awaddr` | 輸入 | 12 | 寫入位址（32-bit 對齊）。 |
| | `s_axi_ctrl_awvalid`/`ready` | 入/出 | 1 | 寫入位址握手信號。 |
| | `s_axi_ctrl_wdata` | 輸入 | 32 | 寫入資料。 |
| | `s_axi_ctrl_wstrb` | 輸入 | 4 | 寫入位元組遮罩。 |
| | `s_axi_ctrl_wvalid`/`ready` | 入/出 | 1 | 寫入資料握手（AW 與 W 允許獨立非同步到達）。 |
| | `s_axi_ctrl_bresp` | 輸出 | 2 | 寫入回應（`2'b00` OKAY，`2'b10` SLVERR）。 |
| | `s_axi_ctrl_bvalid`/`ready` | 出/入 | 1 | 寫入回應握手（支援 Master 反壓）。 |
| | `s_axi_ctrl_araddr` | 輸入 | 12 | 讀取位址。 |
| | `s_axi_ctrl_arvalid`/`ready` | 入/出 | 1 | 讀取位址握手。 |
| | `s_axi_ctrl_rdata` | 輸出 | 32 | 讀取資料。 |
| | `s_axi_ctrl_rresp` | 輸出 | 2 | 讀取回應。 |
| | `s_axi_ctrl_rvalid`/`ready` | 出/入 | 1 | 讀取資料握手（支援 Master 反壓）。 |
| | `irq` | 輸出 | 1 | 高有效中斷輸出（`IRQ_PENDING & IRQ_MASK`）。 |
| **AXI4-Stream TX** | `s_axis_tx_tdata` | 輸入 | 32 | 發送封包資料串流。 |
| | `s_axis_tx_tkeep` | 輸入 | 4 | 位元組有效遮罩。 |
| | `s_axis_tx_tvalid`/`ready` | 入/出 | 1 | 發送串流握手。 |
| | `s_axis_tx_tlast` | 輸入 | 1 | 封包結尾標誌。 |
| | `s_axis_tx_tuser` | 輸入 | 1 | 壞框中止旗標（置 1 標記此封包作廢）。 |
| **AXI4-Stream RX** | `m_axis_rx_tdata` | 輸出 | 32 | 接收封包資料串流。 |
| | `m_axis_rx_tkeep` | 輸出 | 4 | 位元組有效遮罩。 |
| | `m_axis_rx_tvalid`/`ready` | 出/入 | 1 | 接收串流握手。 |
| | `m_axis_rx_tlast` | 輸出 | 1 | 封包結尾標誌。 |
| | `m_axis_rx_tuser` | 輸出 | 1 | 接收錯誤旗標（FCS 錯誤或超長封包）。 |
| **GMII PHY** | `gmii_rx_clk` | 輸入 | 1 | 來自外部 Ethernet PHY 的 125 MHz 接收時鐘。 |
| | `gmii_rxd` | 輸入 | 8 | 接收資料匯流排。 |
| | `gmii_rx_dv` | 輸入 | 1 | 接收資料有效。 |
| | `gmii_rx_er` | 輸入 | 1 | 接收錯誤。 |
| | `mii_tx_clk` | 輸入 | 1 | 10/100M MII 發送時鐘（1G 模式下接 0）。 |
| | `gmii_tx_clk` | 輸出 | 1 | 轉發至 PHY 之發送時鐘（ODDR 產生）。 |
| | `gmii_txd` | 輸出 | 8 | 發送資料匯流排。 |
| | `gmii_tx_en` | 輸出 | 1 | 發送致能。 |
| | `gmii_tx_er` | 輸出 | 1 | 發送錯誤。 |
| **狀態監控** | `tx_error_underflow` | 輸出 | 1 | TX FIFO Underflow 錯誤（位於 axis_aclk 域）。 |
| | `tx_fifo_overflow` | 輸出 | 1 | TX FIFO Overflow 錯誤。 |
| | `tx_fifo_bad_frame` | 輸出 | 1 | TX 壞框事件。 |
| | `tx_fifo_good_frame` | 輸出 | 1 | TX 正常封包提交。 |
| | `rx_error_bad_frame` | 輸出 | 1 | RX 壞框事件。 |
| | `rx_error_bad_fcs` | 輸出 | 1 | RX FCS 檢驗錯誤事件。 |
| | `rx_fifo_overflow` | 輸出 | 1 | RX FIFO 滿載丟包。 |
| | `rx_fifo_bad_frame` | 輸出 | 1 | RX 壞框丟棄。 |
| | `rx_fifo_good_frame` | 輸出 | 1 | RX 正常封包接收。 |
| | `link_speed` | 輸出 | 2 | 估計連線速率（`2'd2`: 1 Gbps、`2'd1`: 100 Mbps、`2'd0`: 10 Mbps）。 |

---

## AXI4-Lite 暫存器配置表（CSR）

所有偏移量為位元組偏移（Byte Offset），採 32-bit 對齊。存取未定義位址或無效 WSTRB 時回覆 `SLVERR`（`2'b10`）。

| 位元組偏移 | 暫存器名稱 | 屬性 | 重設值 | 功能說明 |
| :---: | :--- | :---: | :---: | :--- |
| `0x000` | **IP_ID** | RO | `0x54474D49` | ASCII 標誌碼：`"TGMI"`（Taxi GMII）。 |
| `0x004` | **VERSION** | RO | `0x00010000` | IP 版本號：`1.0.0`。 |
| `0x008` | **STATUS** | RO | `0x00000002` | `bit[1:0]`：估計連線速率（`2'd2` = 1G）。<br>`bit[8]`：`CFG_BUSY`（1 代表 CDC 更新中）。 |
| `0x00C` | **APPLY** | WO | `0x00000000` | 寫入 `1` 將 Shadow 暫存器配置提交至硬體。<br>若 `CFG_BUSY == 1` 則回覆 `SLVERR`。讀取回傳 0。 |
| `0x010` | **CONTROL** | RW | `0x00000007` | `bit[0]`：發送致能（TX Enable）。<br>`bit[1]`：接收致能（RX Enable）。<br>`bit[2]`：自動補零致能（Pad Enable）。 |
| `0x014` | **TX_MIN_LEN** | RW | `0x0000003B` | 最小發送封包長度減一（預設 `59` = 60 位元組，不含 FCS）。 |
| `0x018` | **TX_MAX_LEN** | RW | `0x000005ED` | 最大發送封包長度減一（預設 `1517` = 1518 位元組，含 FCS）。 |
| `0x01C` | **RX_MAX_LEN** | RW | `0x000005ED` | 最大接收封包長度減一（預設 `1517` = 1518 位元組，含 FCS）。 |
| `0x020` | **TX_IFG** | RW | `0x0000000C` | 發送 Inter-Frame Gap（預設 `12` 位元組）。 |
| `0x024` | **IRQ_PENDING** | RO/W1C| `0x00000000` | 黏滯事件狀態（`bit[9:0]`）。寫 1 清除（W1C）。 |
| `0x028` | **IRQ_MASK** | RW | `0x00000000` | 中斷致能遮罩（`bit[9:0]`）。寫 1 致能對應事件觸發 `irq`。 |
| `0x02C` | **COUNTER_CLEAR**| WO | `0x00000000` | 寫入 `1` 清除全部 10 組計數器。讀取回覆 `SLVERR`。 |
| `0x040` | **EVENT_CNT_0** | RO | `0x00000000` | TX underflow 錯誤計數器（32 位元飽和計數）。 |
| `0x044` | **EVENT_CNT_1** | RO | `0x00000000` | TX FIFO overflow 錯誤計數器。 |
| `0x048` | **EVENT_CNT_2** | RO | `0x00000000` | TX FIFO 壞框計數器。 |
| `0x04C` | **EVENT_CNT_3** | RO | `0x00000000` | TX FIFO 正常封包計數器。 |
| `0x050` | **EVENT_CNT_4** | RO | `0x00000000` | RX 壞框計數器。 |
| `0x054` | **EVENT_CNT_5** | RO | `0x00000000` | RX FCS 錯誤計數器。 |
| `0x058` | **EVENT_CNT_6** | RO | `0x00000000` | RX FIFO overflow 滿載丟包計數器。 |
| `0x05C` | **EVENT_CNT_7** | RO | `0x00000000` | RX FIFO 壞框丟棄計數器。 |
| `0x060` | **EVENT_CNT_8** | RO | `0x00000000` | RX FIFO 正常封包計數器。 |
| `0x064` | **EVENT_CNT_9** | RO | `0x00000000` | TX 封包開始發送事件計數器。 |

---

## 設定更新與跨時脈域同步步驟（CDC Handshake）

為防止在封包傳輸期間動態更改配置造成 FIFO 錯亂或破包，軟體驅動必須遵循以下安全流程：

1. **停止流量**：停止派送新的 TX DMA 描述符，並等待內部 TX FIFO 與線路封包傳送完畢。
2. **確認非忙碌**：讀取 `STATUS`（`0x008`），確認 `bit[8]`（`CFG_BUSY`）為 `0`。
3. **寫入 Shadow 暫存器**：設定所需的 `CONTROL`、`TX_MIN_LEN`、`TX_MAX_LEN`、`RX_MAX_LEN`、`TX_IFG`。
4. **提交生效**：對 `APPLY`（`0x00C`）寫入 `1`。
5. **等待確認**：以有限超時輪詢 `STATUS`（`0x008`），直到 `CFG_BUSY` 歸零。
6. **恢復流量**：重新開啟 DMA 與收發流量。

---

## Vivado 專案建立與 IP 打包

### 1. 自動化專案建立

執行隨附之 TCL 腳本以建立針對 `xcku5p-ffvb676-2-i` 的 Vivado 專案：

```cmd
vivado -mode batch -source scripts/create_project.tcl
```

### 2. Vivado IP 打包

若需將本模組打包為 Vivado IP Catalog / Block Design 可調用之 IP：

```cmd
vivado -mode batch -source scripts/package_ip.tcl
```

打包完成後之 IP 將產出於 `ip_repo/taxi_eth_gmii_axi_wrapper/`。

### 3. 綜合驗證

若需執行 Out-Of-Context 綜合並產生利用率與時序報告：

```cmd
vivado -mode batch -source scripts/run_synth.tcl
```

報告將儲存於 `reports/utilization_summary.rpt` 與 `reports/timing_summary.rpt`。

---

## 模擬與驗證

本專案提供自我校驗之 SystemVerilog 測試平台（`tb/test_taxi_eth_gmii_axi_wrapper.sv`），驗證內容包括：
- AXI4-Lite 讀寫握手、WSTRB 遮罩、Master 反壓。
- Shadow 暫存器提交與跨時脈域 CDC Dual-Toggle 握手。
- IFG 訊框間隔設定。
- 黏滯中斷旗標（`IRQ_PENDING`、`IRQ_MASK`、W1C 清除）。
- 32-bit 飽和計數器統計與清除功能。
- 模擬 PHY RX 時鐘停止與恢復情境。
- 73 封包之完整 GMII 線路回送測試（包含最小長度補零、最大框、FCS 驗證等）。

### 使用 Verilator 執行：
```bash
cd tb
make test
```

### 使用 Vivado xsim 執行：
```cmd
cd tb
run_sim_xsim.bat
```

---

## 授權條款

採用 **CERN Open Hardware Licence Version 2 - Strongly Reciprocal (CERN-OHL-S-2.0)** 授權。
原始 MAC 與 FIFO 模組版權所有 (c) 2016-2025 FPGA Ninja, LLC (Alex Forencich)。
Wrapper 與 KU5P 整合調試版權所有 (c) 2026。
