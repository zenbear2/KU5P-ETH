# KU5P-ETH: Kintex UltraScale+ 1G GMII Ethernet MAC AXI Wrapper

[English](README.md) | [繁體中文](README_zh.md)

**KU5P-ETH** 以開源 [Taxi](https://github.com/fpganinja/taxi) 專案之 1G GMII Ethernet MAC 與非同步 Frame FIFO 為基礎，針對 **AMD / Xilinx Kintex UltraScale+ (`xcku5p-ffvb676-2-i`, `FPGA_FAMILY = "kintexuplus"`)** 平台進行介面封裝、暫存器擴充、跨時鐘域同步與 SoC 軟硬體整合。

本專案將原本使用 SystemVerilog Interface 的 MAC 子系統轉換為平面（Flat）AXI4-Stream 與 AXI4-Lite 介面，可直接加入 Vivado IP Integrator（Block Design）並搭配 Xilinx AXI DMA 運作。

---

## 基於 Taxi 之專案修改與擴充

本倉庫保留 `taxi` 原有的 1G GMII MAC 資料路徑、CRC32 檢驗、PAUSE 流控與 AXI-Stream 非同步 FIFO，並在其上完成以下五個部分的實作與修正：

### 1. Vivado Block Design 介面轉換與 IP 封裝
- **平面化頂層包裝（`rtl/taxi_eth_gmii_axi_wrapper.sv`、`rtl/taxi_eth_axi_wrapper.sv`）**：將 `taxi` 原生的 `taxi_axis_if` SystemVerilog Interface 拆解並映射為標準平面信號（`s_axis_tx_*`、`m_axis_rx_*`、`s_axi_ctrl_*`），加上 Vivado `X_INTERFACE_INFO` 與 `X_INTERFACE_PARAMETER` 屬性，使 Vivado Block Design 能自動識別匯流排與關聯時鐘。
- **重設同步與串流閘控**：於頂層整合 `taxi_sync_reset`，並在重設期間閘控 `s_axis_tx` 與 `m_axis_rx` 的握手信號。
- **IP Catalog 封裝與約束（`scripts/package_ip.tcl`、`constrs/*.tcl`）**：提供 IP 打包腳本與針對非同步 FIFO、CDC 路徑的 `SCOPED_TO_REF` 時序約束，設定為 `USED_IN_implementation` 以避免 Out-of-Context 單獨綜合階段因頂層時鐘尚未建立而產生假警告。

### 2. AXI4-Lite 控制／狀態暫存器與事件計數器（`rtl/taxi_eth_gmii_axil_regs.sv`）
`taxi` 原始 MAC 僅提供裸線設定埠與單拍狀態脈衝，本專案新增 32-bit AXI4-Lite Slave 模組（4 KiB 位址空間，`0x000`–`0x064`）：
- **硬體識別與狀態**：提供 `IP_ID`（`0x54474D49`，`"TGMI"`）、`VERSION`（`0x00010000`）、連線速率顯示與 `CFG_BUSY` 狀態位元。
- **Shadow 暫存器與提交保護**：提供 `CONTROL`（TX/RX/Pad 致能）、`TX_MIN_LEN`、`TX_MAX_LEN`、`RX_MAX_LEN`、`TX_IFG` 暫存器；透過 `APPLY` 暫存器觸發跨時鐘域更新，若前次同步尚未完成（`CFG_BUSY == 1`）則回應 AXI `SLVERR`（`2'b10`）。
- **10 組 32-bit 飽和計數器與中斷控制**：將 MAC 與 FIFO 的單拍事件脈衝轉換為 10 組 32-bit 飽和計數器（`EVENT_CNT_0`–`EVENT_CNT_9`，支援 `COUNTER_CLEAR` 一鍵清零），並實作黏滯狀態（`IRQ_PENDING`，W1C）與中斷遮罩（`IRQ_MASK`）以輸出 `irq`。

### 3. 訊框邊界安全的跨時鐘域配置同步器（`rtl/taxi_eth_gmii_cfg_cdc.sv`）
- 修改 `rtl/taxi_eth_mac_1g_gmii.sv` 與 `rtl/taxi_eth_mac_1g_gmii_fifo.sv`，向外導出內部 `mac_tx_clk`、`mac_rx_clk` 與 `mac_rx_dv` 狀態。
- 新增 `taxi_eth_gmii_cfg_cdc` 模組，採用 Dual-Toggle 握手協定將 51-bit 配置從 `axis_aclk` 同步至 `tx_clk` 與 `rx_clk` 域。
- 在目標時鐘域加入訊框活動保護（`!tx_active` 與 `!rx_active`），確保配置僅在訊框間隙（Inter-Frame Gap）載入生效，防止傳輸中更改長度或致能位元導致破包。

### 4. Kintex UltraScale+ 1G GMII 時鐘路徑修正（`rtl/taxi_gmii_phy_if.sv`）
- `taxi` 原版在 `FPGA_FAMILY == "kintexuplus"` 分支使用 `BUFGMUX` 切換 `gtx_clk`（1G）與 `mii_tx_clk`（10/100M）。在純 1G GMII 應用中，`mii_tx_clk` 腳位固定接地（`1'b0`），當 `speed` 尚未切換前 `BUFGMUX` 選中靜態 `0` 輸入，會導致 `mac_gmii_tx_clk` 停振並使依賴該時鐘的邏輯與同步重設死鎖。
- 本專案將 `kintexuplus` 分支改為直接連接 125 MHz 參考時鐘（`assign mac_gmii_tx_clk = gtx_clk;`），消除時鐘切換死鎖。

### 5. SoC 軟硬體整合與壓力測試工具
- 完成 MicroBlaze + Xilinx AXI DMA（Standard Scatter-Gather 模式，`c_micro_dma = 0`）+ DDR4 SDRAM + `taxi_eth_gmii_axi_wrapper` + Realtek RTL8211EG PHY 的系統整合。
- 提供範例 Block Design 重建腳本（`bd/KU5P_SoC.tcl`，Vivado 2022.2），內含 MicroBlaze、DDR4 控制器、AXI DMA（Standard SG）、UARTLite 及本 MAC 包裝模組（位址配置於 `0x00020000`）。
- 提供 Vitis 裸機韌體（ARP / ICMP Ping 應答、管線化多描述符 TX 突發測試、雙向浸泡測試、PRBS 資料校驗、RX 佇列耗盡背壓測試、DMA 重置測試）與 PC 端 Python 測試腳本（`scripts/host_stress_test.py`），詳見 [STRESS_TEST_PLAN.md](STRESS_TEST_PLAN.md)。

---

## 規格摘要

- **目標元件**：AMD / Xilinx Kintex UltraScale+（`xcku5p-ffvb676-2-i`）。
- **頂層模組**：`taxi_eth_gmii_axi_wrapper`（別名模組：`taxi_eth_axi_wrapper`）。
- **資料路徑（AXI4-Stream）**：
  - `S_AXIS_TX`：發送封包串流（預設 32-bit `TDATA`、4-bit `TKEEP`、`TVALID`/`TREADY`、`TLAST`、`TUSER` 壞框中止旗標）。
  - `M_AXIS_RX`：接收封包串流（預設 32-bit `TDATA`、4-bit `TKEEP`、`TVALID`/`TREADY`、`TLAST`、`TUSER` 壞框／FCS 錯誤旗標）。
  - 預設 TX/RX 非同步 FIFO 深度：`TX_FIFO_DEPTH = 4096`、`RX_FIFO_DEPTH = 4096`（Store-and-Forward Frame FIFO 模式，自動丟棄壞框與溢位框）。
- **控制與狀態（AXI4-Lite）**：
  - `S_AXI_CTRL`：32-bit AXI4-Lite Slave 介面，4 KiB 位址空間。
  - Shadow 配置暫存器與 `APPLY` 握手轉發機制。
  - 10 組 32-bit 飽和計數器與可遮罩中斷輸出（`irq`）。
- **實體層介面（GMII）**：
  - 8-bit GMII TX / RX 資料、致能、錯誤信號。
  - 125 MHz `gtx_clk` 參考時鐘輸入，透過硬體 ODDR 原語產生 `gmii_tx_clk` 至外部 PHY。

---

## 倉庫檔案結構

```text
KU5P-ETH/
├── bd/                                 # 範例 Block Design 重建腳本與硬體定義檔
│   ├── KU5P_SoC.tcl                    # Vivado 2022.2 MicroBlaze + AXI DMA + DDR4 + KU5P-ETH 範例 Block Design
│   └── KU5P_SoC_wrapper.xsa            # Vivado 導出之硬體定義檔（XSA）
├── rtl/                                # SystemVerilog RTL 原始碼
│   ├── taxi_eth_gmii_axi_wrapper.sv    # [新增] 頂層平面 AXI/GMII Wrapper
│   ├── taxi_eth_axi_wrapper.sv         # [新增] 頂層別名 Wrapper
│   ├── taxi_eth_gmii_axil_regs.sv      # [新增] AXI4-Lite 控制與狀態暫存器
│   ├── taxi_eth_gmii_cfg_cdc.sv        # [新增] 配置 CDC Mailbox（Dual-Toggle 同步）
│   ├── taxi_eth_mac_1g_gmii_fifo.sv    # [修改] 1G GMII MAC + 非同步 TX/RX FIFO（導出 MAC 時鐘/狀態）
│   ├── taxi_eth_mac_1g_gmii.sv         # [修改] 1G GMII MAC 核心（導出 MAC 時鐘/狀態）
│   ├── taxi_gmii_phy_if.sv             # [修改] GMII PHY I/O 介面（修正 KU+ 1G 時鐘路徑）
│   ├── taxi_eth_mac_1g.sv              # [Taxi] 1G 乙太網路 MAC 引擎
│   ├── taxi_axis_gmii_rx.sv            # [Taxi] GMII RX 轉 AXI-Stream
│   ├── taxi_axis_gmii_tx.sv            # [Taxi] AXI-Stream 轉 GMII TX
│   ├── taxi_mac_ctrl_tx.sv             # [Taxi] MAC 發送控制模組
│   ├── taxi_mac_ctrl_rx.sv             # [Taxi] MAC 接收控制模組
│   ├── taxi_mac_pause_ctrl_tx.sv       # [Taxi] 流量控制（PAUSE）發送模組
│   ├── taxi_mac_pause_ctrl_rx.sv       # [Taxi] 流量控制（PAUSE）接收模組
│   ├── taxi_ssio_sdr_in.sv             # [Taxi] 源同步 SDR 輸入（KU+ 採用 BUFG）
│   ├── taxi_ssio_sdr_out.sv            # [Taxi] 源同步 SDR 輸出
│   ├── taxi_oddr.sv                    # [Taxi] Xilinx ODDR 原語包裝
│   ├── taxi_axis_if.sv                 # [Taxi] AXI-Stream SystemVerilog Interface 定義
│   ├── taxi_axis_async_fifo_adapter.sv # [Taxi] 非同步 FIFO 寬度轉換介面
│   ├── taxi_axis_async_fifo.sv         # [Taxi] AXI-Stream 非同步 FIFO（CDC 指針同步）
│   ├── taxi_axis_adapter.sv            # [Taxi] AXI-Stream 寬度轉換核心
│   ├── taxi_axis_arb_mux.sv            # [Taxi] AXI-Stream 仲裁多工器
│   ├── taxi_axis_pad.sv                # [Taxi] 封包自動補零模組（最小 60 位元組）
│   ├── taxi_axis_null_src.sv           # [Taxi] AXI-Stream 空來源 Tie-off
│   ├── taxi_axis_tie.sv                # [Taxi] AXI-Stream 匯流排 Tie-off 輔助
│   ├── taxi_sync_reset.sv              # [Taxi] 非同步觸發／同步釋放 Reset 同步器
│   ├── taxi_sync_signal.sv             # [Taxi] 多級信號 CDC 同步器
│   ├── taxi_arbiter.sv                 # [Taxi] 優先權／輪轉仲裁器
│   ├── taxi_penc.sv                    # [Taxi] 優先權編碼器
│   ├── taxi_lfsr.sv                    # [Taxi] CRC32 計算模組
│   ├── taxi_eth_mac_stats.sv           # [Taxi] MAC 統計串流產生器
│   ├── taxi_stats_collect.sv           # [Taxi] 統計事件計數收集器
│   └── taxi_eth_gmii_axi_wrapper.f     # 拓撲編譯順序原始碼清單
├── constrs/                            # 時序與 CDC 約束腳本
│   ├── ku5p_eth_timing.xdc             # KU5P 板級時鐘與 I/O 時序約束
│   ├── taxi_eth_gmii_cfg_cdc.tcl       # 配置 Mailbox Datapath Max-Delay 約束
│   ├── taxi_eth_mac_fifo.tcl           # MAC FIFO CDC 同步器約束
│   ├── taxi_axis_async_fifo.tcl        # AXI-Stream 非同步 FIFO 指針約束
│   ├── taxi_sync_reset.tcl             # Reset 同步器 False-Path 約束
│   └── taxi_sync_signal.tcl            # 信號同步器 False-Path 約束
├── tb/                                 # 驗證與模擬檔案
│   ├── test_taxi_eth_gmii_axi_wrapper.sv # SystemVerilog 測試平台
│   ├── Makefile                        # Verilator 模擬 Makefile
│   ├── run_sim_xsim.bat                # Vivado xsim 批次執行腳本（Windows）
│   └── run_sim_xsim.tcl                # Vivado xsim 執行控制 TCL 腳本
├── sw/                                 # MicroBlaze 模組化裸機測試軟體原始碼
│   ├── helloworld.c / main.c           # 系統初始化與互動式測試命令選單入口
│   ├── eth_mac.h / eth_mac.c           # MAC 控制／狀態暫存器讀寫與計數器驅動
│   ├── eth_dma.h / eth_dma.c           # AXI DMA Scatter-Gather 環配置與收發驅動
│   ├── packet_builder.h / .c           # 測試訊框封裝與 ARP / ICMP 自動應答處理
│   ├── stress_tests.h / .c             # 壓力測試模組（TX 突發、雙向浸泡、PRBS、DMA 重置）
│   ├── platform.h / platform.c         # Vitis 平台快取與 UART 初始化
│   ├── platform_config.h               # 平台硬體配置頭文件
│   └── lscript.ld                      # MicroBlaze DDR4 記憶體配置 Linker Script
├── scripts/                            # 自動化與測試腳本
│   ├── create_project.tcl              # 建立 KU5P-ETH Vivado 專案
│   ├── run_synth.tcl                   # 綜合與產生利用率／時序報告腳本
│   ├── package_ip.tcl                  # 打包為 Vivado IP Catalog 元件腳本
│   └── host_stress_test.py             # PC 端 UDP/ICMP 壓力測試與吞吐量量測腳本
├── reports/                            # 綜合產出之利用率與時序報告目錄
├── STRESS_TEST_PLAN.md                 # 硬體壓力測試設計與驗證規劃文件
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
| | `s_axi_ctrl_wvalid`/`ready` | 入/出 | 1 | 寫入資料握手（AW 與 W 可獨立到達）。 |
| | `s_axi_ctrl_bresp` | 輸出 | 2 | 寫入回應（`2'b00` OKAY，`2'b10` SLVERR）。 |
| | `s_axi_ctrl_bvalid`/`ready` | 出/入 | 1 | 寫入回應握手。 |
| | `s_axi_ctrl_araddr` | 輸入 | 12 | 讀取位址。 |
| | `s_axi_ctrl_arvalid`/`ready` | 入/出 | 1 | 讀取位址握手。 |
| | `s_axi_ctrl_rdata` | 輸出 | 32 | 讀取資料。 |
| | `s_axi_ctrl_rresp` | 輸出 | 2 | 讀取回應。 |
| | `s_axi_ctrl_rvalid`/`ready` | 出/入 | 1 | 讀取資料握手。 |
| | `irq` | 輸出 | 1 | 高有效中斷輸出（`|(IRQ_PENDING & IRQ_MASK)`）。 |
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
| **狀態監控** | `tx_error_underflow` | 輸出 | 1 | TX FIFO Underflow 事件（`axis_aclk` 域）。 |
| | `tx_fifo_overflow` | 輸出 | 1 | TX FIFO Overflow 事件。 |
| | `tx_fifo_bad_frame` | 輸出 | 1 | TX 壞框事件。 |
| | `tx_fifo_good_frame` | 輸出 | 1 | TX 正常封包提交事件。 |
| | `rx_error_bad_frame` | 輸出 | 1 | RX 壞框事件。 |
| | `rx_error_bad_fcs` | 輸出 | 1 | RX FCS 檢驗錯誤事件。 |
| | `rx_fifo_overflow` | 輸出 | 1 | RX FIFO 滿載丟包事件。 |
| | `rx_fifo_bad_frame` | 輸出 | 1 | RX 壞框丟棄事件。 |
| | `rx_fifo_good_frame` | 輸出 | 1 | RX 正常封包接收事件。 |
| | `link_speed` | 輸出 | 2 | 估計連線速率（`2'd2`: 1 Gbps、`2'd1`: 100 Mbps、`2'd0`: 10 Mbps）。 |

---

## AXI4-Lite 暫存器配置表（CSR）

所有偏移量為位元組偏移（Byte Offset），採 32-bit 對齊。存取未定義位址或無效 `WSTRB` 時回覆 `SLVERR`（`2'b10`）。

| 位元組偏移 | 暫存器名稱 | 屬性 | 重設值 | 功能說明 |
| :---: | :--- | :---: | :---: | :--- |
| `0x000` | **IP_ID** | RO | `0x54474D49` | ASCII 標誌碼：`"TGMI"`（Taxi GMII）。 |
| `0x004` | **VERSION** | RO | `0x00010000` | IP 版本號：`1.0.0`。 |
| `0x008` | **STATUS** | RO | `0x00000002` | `bit[1:0]`：估計連線速率（`2'd2` = 1G）。<br>`bit[8]`：`CFG_BUSY`（1 代表 CDC 更新中）。 |
| `0x00C` | **APPLY** | WO | `0x00000000` | 寫入 `1` 將 Shadow 暫存器提交至硬體。<br>若 `CFG_BUSY == 1` 則回覆 `SLVERR`。讀取回傳 0。 |
| `0x010` | **CONTROL** | RW | `0x00000007` | `bit[0]`：發送致能（TX Enable）。<br>`bit[1]`：接收致能（RX Enable）。<br>`bit[2]`：自動補零致能（Pad Enable）。 |
| `0x014` | **TX_MIN_LEN** | RW | `0x0000003B` | 最小發送封包長度減一（預設 `59` = 60 位元組，不含 FCS）。 |
| `0x018` | **TX_MAX_LEN** | RW | `0x000005ED` | 最大發送封包長度減一（預設 `1517` = 1518 位元組，含 FCS）。 |
| `0x01C` | **RX_MAX_LEN** | RW | `0x000005ED` | 最大接收封包長度減一（預設 `1517` = 1518 位元組，含 FCS）。 |
| `0x020` | **TX_IFG** | RW | `0x0000000C` | 發送 Inter-Frame Gap（預設 `12` 位元組）。 |
| `0x024` | **IRQ_PENDING** | RO/W1C| `0x00000000` | 黏滯事件狀態（`bit[9:0]`）。寫 1 清除（W1C）。 |
| `0x028` | **IRQ_MASK** | RW | `0x00000000` | 中斷致能遮罩（`bit[9:0]`）。寫 1 致能對應事件觸發 `irq`。 |
| `0x02C` | **COUNTER_CLEAR**| WO | `0x00000000` | 寫入 `1` 清除全部 10 組計數器。讀取回覆 `SLVERR`。 |
| `0x040` | **EVENT_CNT_0** | RO | `0x00000000` | TX underflow 錯誤計數器（32-bit 飽和計數）。 |
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

## 設定更新與跨時鐘域同步步驟（CDC Handshake）

動態修改配置時，軟體驅動應遵循以下步驟：

1. **停止流量**：停止派送新的 TX DMA 描述符，等待內部 TX FIFO 與線路封包傳送完畢。
2. **確認非忙碌**：讀取 `STATUS`（`0x008`），確認 `bit[8]`（`CFG_BUSY`）為 `0`。
3. **寫入 Shadow 暫存器**：設定所需的 `CONTROL`、`TX_MIN_LEN`、`TX_MAX_LEN`、`RX_MAX_LEN`、`TX_IFG`。
4. **提交生效**：對 `APPLY`（`0x00C`）寫入 `1`。
5. **等待確認**：輪詢 `STATUS`（`0x008`），直到 `CFG_BUSY` 歸零。
6. **恢復流量**：重新開啟 DMA 與收發流量。

---

## Xilinx AXI DMA 整合注意事項

將本 IP 與 Xilinx AXI DMA（`axi_dma_v7_1`）串接時，需注意以下硬體與軟體設定：

1. **關閉 Micro DMA 模式（`CONFIG.c_micro_dma = 0`）**：
   - 在 Xilinx `axi_dma_v7_1` RTL 中，當 `c_micro_dma = 1` 時，內部 `C_S2MM_SUPPORT_INDET_BTT` 會被強制設為 `0`（關閉未知長度傳輸支援）。當接收變長乙太網路封包（如 60-byte ARP 或 1514-byte 訊框）且 `tlast` 提早到達時，`axi_datamover` 會觸發 `sig_tlast_error_under` 並停止 `s_axis_s2mm_tready`，導致接收通道鎖死與 `RX_FIFO_OVERFLOW`。
   - 因此 Block Design 中的 AXI DMA 必須設為標準 Scatter-Gather 模式（`c_micro_dma = 0`）。
2. **BD 環空間對齊與緩衝區位址計算**：
   - 建立 RX BD Ring 時，記憶體範圍 `RX_BD_SPACE_HIGH - RX_BD_SPACE_BASE + 1` 應與初始化之 `RX_BUFFERS_NUM * XAXIDMA_BD_MINIMUM_ALIGNMENT` 數量一致，或在補充（Replenish）RX BD 時直接根據描述符索引計算對應的 DDR4 緩衝區位址，避免分配到未設定 Buffer Address（`0x00000000`）的 BD 而引發 `DMADecErr`（`S2MM_SR = 0x00015049`）。
3. **驅動層 `MaxTransferLen` 遮罩修正**：
   - 部分 Vitis BSP 版本的 `XAxiDma_CfgInitialize` 將 `MaxTransferLen` 設為 `1U << SgLengthWidth`，導致 `XAxiDma_BdSetLength` 內部的位元遮罩為 `0` 而無法寫入傳輸長度。初始化後建議手動修正為 `(1U << cfg->SgLengthWidth) - 1U`。

---

## Vivado 專案建立與 IP 打包

### 1. 建立 Vivado 專案

執行 TCL 腳本以建立針對 `xcku5p-ffvb676-2-i` 的 Vivado 專案：

```cmd
vivado -mode batch -source scripts/create_project.tcl
```

### 2. Vivado IP 打包

將本模組打包為 Vivado IP Catalog / Block Design 可調用之 IP：

```cmd
vivado -mode batch -source scripts/package_ip.tcl
```

打包完成後之 IP 產出於 `ip_repo/taxi_eth_gmii_axi_wrapper/`。

### 3. 重建範例 Block Design（KU5P_SoC）

本專案於 `bd/` 目錄提供完整驗證通過的範例 Block Design 腳本（`bd/KU5P_SoC.tcl`），包含 MicroBlaze、DDR4 控制器、Standard SG 模式之 AXI DMA（`c_micro_dma = 0`）、UARTLite 與本 MAC IP（`0x00020000`）。在執行 IP 打包後，可直接透過 Vivado 執行該腳本以生成 Block Design：

```cmd
vivado -mode batch -source bd/KU5P_SoC.tcl
```

### 4. 綜合驗證

執行 Out-Of-Context 綜合並產生利用率與時序報告：

```cmd
vivado -mode batch -source scripts/run_synth.tcl
```

報告儲存於 `reports/utilization_summary.rpt` 與 `reports/timing_summary.rpt`。

---

## 模擬與驗證

本專案提供 SystemVerilog 測試平台（`tb/test_taxi_eth_gmii_axi_wrapper.sv`），涵蓋項目包括：
- AXI4-Lite 讀寫握手、`WSTRB` 遮罩、Master 反壓。
- Shadow 暫存器提交與跨時鐘域 CDC Dual-Toggle 握手。
- IFG 訊框間隔設定。
- 黏滯中斷旗標（`IRQ_PENDING`、`IRQ_MASK`、W1C 清除）。
- 32-bit 飽和計數器統計與清除功能。
- 模擬 PHY RX 時鐘停止與恢復情境。
- 73 封包之 GMII 線路回送測試（最小長度補零、最大框、FCS 驗證等）。

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
Wrapper 與 KU5P 整合修改版權所有 (c) 2026。
