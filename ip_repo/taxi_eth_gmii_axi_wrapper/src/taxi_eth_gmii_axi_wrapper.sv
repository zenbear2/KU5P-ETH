// SPDX-License-Identifier: CERN-OHL-S-2.0

`resetall
`timescale 1ns / 1ps
`default_nettype none

// Flat AXI4-Stream and GMII ports for Vivado IP integration.
// AXI4-Lite registers provide shadow configuration, APPLY, status and IRQ.
module taxi_eth_gmii_axi_wrapper #(
    parameter logic SIM = 1'b0,
    parameter string FPGA_FAMILY = "kintexuplus",
    parameter AXIS_DATA_WIDTH = 32,
    parameter TX_FIFO_DEPTH = 4096,
    parameter RX_FIFO_DEPTH = 4096
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_aclk CLK",
       X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXIS_TX:M_AXIS_RX:S_AXI_CTRL, ASSOCIATED_RESET axis_aresetn" *)
    input  wire                         axis_aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 axis_aresetn RST",
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire                         axis_aresetn,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 gtx_clk CLK",
       X_INTERFACE_PARAMETER = "FREQ_HZ 125000000, ASSOCIATED_RESET gtx_reset" *)
    input  wire                         gtx_clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 gtx_reset RST",
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    input  wire                         gtx_reset,

    // Control and streams share axis_aclk and axis_aresetn.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL AWADDR" *)
    (* X_INTERFACE_PARAMETER = "PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 12" *)
    input  wire [11:0]     s_axi_ctrl_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL AWPROT" *)
    input  wire [2:0]      s_axi_ctrl_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL AWVALID" *)
    input  wire            s_axi_ctrl_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL AWREADY" *)
    output wire            s_axi_ctrl_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL WDATA" *)
    input  wire [31:0]     s_axi_ctrl_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL WSTRB" *)
    input  wire [3:0]      s_axi_ctrl_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL WVALID" *)
    input  wire            s_axi_ctrl_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL WREADY" *)
    output wire            s_axi_ctrl_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL BRESP" *)
    output wire [1:0]      s_axi_ctrl_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL BVALID" *)
    output wire            s_axi_ctrl_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL BREADY" *)
    input  wire            s_axi_ctrl_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL ARADDR" *)
    input  wire [11:0]     s_axi_ctrl_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL ARPROT" *)
    input  wire [2:0]      s_axi_ctrl_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL ARVALID" *)
    input  wire            s_axi_ctrl_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL ARREADY" *)
    output wire            s_axi_ctrl_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL RDATA" *)
    output wire [31:0]     s_axi_ctrl_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL RRESP" *)
    output wire [1:0]      s_axi_ctrl_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL RVALID" *)
    output wire            s_axi_ctrl_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL RREADY" *)
    input  wire            s_axi_ctrl_rready,
    (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 irq INTERRUPT",
       X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
    output wire irq,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_TX TDATA" *)
    input  wire [AXIS_DATA_WIDTH-1:0]     s_axis_tx_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_TX TKEEP" *)
    input  wire [AXIS_DATA_WIDTH/8-1:0]   s_axis_tx_tkeep,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_TX TVALID" *)
    input  wire                         s_axis_tx_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_TX TREADY" *)
    output wire                         s_axis_tx_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_TX TLAST" *)
    input  wire                         s_axis_tx_tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_TX TUSER" *)
    input  wire                         s_axis_tx_tuser,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RX TDATA" *)
    output wire [AXIS_DATA_WIDTH-1:0]     m_axis_rx_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RX TKEEP" *)
    output wire [AXIS_DATA_WIDTH/8-1:0]   m_axis_rx_tkeep,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RX TVALID" *)
    output wire                         m_axis_rx_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RX TREADY" *)
    input  wire                         m_axis_rx_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RX TLAST" *)
    output wire                         m_axis_rx_tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RX TUSER" *)
    output wire                         m_axis_rx_tuser,

    input  wire                         gmii_rx_clk,
    input  wire [7:0]                   gmii_rxd,
    input  wire                         gmii_rx_dv,
    input  wire                         gmii_rx_er,
    input  wire                         mii_tx_clk,
    output wire                         gmii_tx_clk,
    output wire [7:0]                   gmii_txd,
    output wire                         gmii_tx_en,
    output wire                         gmii_tx_er,

    // Status events are in the axis_aclk domain and are not sticky.
    output wire                         tx_error_underflow,
    output wire                         tx_fifo_overflow,
    output wire                         tx_fifo_bad_frame,
    output wire                         tx_fifo_good_frame,
    output wire                         rx_error_bad_frame,
    output wire                         rx_error_bad_fcs,
    output wire                         rx_fifo_overflow,
    output wire                         rx_fifo_bad_frame,
    output wire                         rx_fifo_good_frame,
    // This is an estimated speed, not PHY link-up status.
    output wire [1:0]                   link_speed
);

initial begin
    if (AXIS_DATA_WIDTH < 8 || AXIS_DATA_WIDTH % 8 != 0 ||
            (AXIS_DATA_WIDTH & (AXIS_DATA_WIDTH-1)) != 0) begin
        $fatal(1, "AXIS_DATA_WIDTH must be a power of two and at least 8");
    end
end

// Assert asynchronously and release synchronously in the stream domain.
wire logic_rst;
taxi_sync_reset #(.N(4)) logic_reset_inst (
    .clk(axis_aclk),
    .rst(!axis_aresetn),
    .out(logic_rst)
);

taxi_axis_if #(
    .DATA_W(AXIS_DATA_WIDTH), .KEEP_EN(1'b1),
    .USER_EN(1'b1), .USER_W(1), .ID_EN(1'b1), .ID_W(1)
) axis_tx();

taxi_axis_if #(
    .DATA_W(AXIS_DATA_WIDTH), .KEEP_EN(1'b1),
    .USER_EN(1'b1), .USER_W(1)
) axis_rx();

// The core uses a 96-bit timestamp field even when PTP is disabled.
taxi_axis_if #(
    .DATA_W(96), .KEEP_W(1), .ID_EN(1'b1), .ID_W(1)
) axis_tx_cpl();

taxi_axis_if #(
    .DATA_W(16), .KEEP_W(1), .KEEP_EN(1'b0), .LAST_EN(1'b0),
    .USER_EN(1'b1), .USER_W(1), .ID_EN(1'b1), .ID_W(8)
) axis_stat();

// Gate the external handshake while the internal reset is active.
assign axis_tx.tdata = s_axis_tx_tdata;
assign axis_tx.tkeep = s_axis_tx_tkeep;
assign axis_tx.tstrb = s_axis_tx_tkeep;
assign axis_tx.tvalid = s_axis_tx_tvalid && !logic_rst;
assign axis_tx.tlast = s_axis_tx_tlast;
assign axis_tx.tuser = s_axis_tx_tuser;
assign axis_tx.tid = '0;
assign axis_tx.tdest = '0;
assign s_axis_tx_tready = axis_tx.tready && !logic_rst;

assign m_axis_rx_tdata = axis_rx.tdata;
assign m_axis_rx_tkeep = axis_rx.tkeep;
assign m_axis_rx_tvalid = axis_rx.tvalid && !logic_rst;
assign m_axis_rx_tlast = axis_rx.tlast;
assign m_axis_rx_tuser = axis_rx.tuser;
assign axis_rx.tready = m_axis_rx_tready && !logic_rst;

// Drain unused start/timestamp events and the disabled statistics stream.
assign axis_tx_cpl.tready = 1'b1;
assign axis_stat.tready = 1'b1;

// Reset both mailbox destinations together to preserve toggle coherence.
wire cfg_reset = logic_rst || gtx_reset;
wire mac_tx_clk, mac_tx_rst, mac_rx_clk, mac_rx_rst;
wire cfg_apply, cfg_busy;
wire [50:0] config_data, tx_config, rx_config;
localparam logic [50:0] DEFAULT_CONFIG = {8'd12, 16'd1517, 16'd1517, 8'd59, 3'b111};
wire [9:0] events = {axis_tx_cpl.tvalid, rx_fifo_good_frame,
    rx_fifo_bad_frame, rx_fifo_overflow, rx_error_bad_fcs, rx_error_bad_frame,
    tx_fifo_good_frame, tx_fifo_bad_frame, tx_fifo_overflow, tx_error_underflow};

taxi_eth_gmii_axil_regs regs_inst (
    .clk(axis_aclk), .rst(logic_rst),
    .s_axi_awaddr(s_axi_ctrl_awaddr),
    .s_axi_awvalid(s_axi_ctrl_awvalid),
    .s_axi_awready(s_axi_ctrl_awready),
    .s_axi_wdata(s_axi_ctrl_wdata),
    .s_axi_wstrb(s_axi_ctrl_wstrb),
    .s_axi_wvalid(s_axi_ctrl_wvalid),
    .s_axi_wready(s_axi_ctrl_wready),
    .s_axi_bresp(s_axi_ctrl_bresp),
    .s_axi_bvalid(s_axi_ctrl_bvalid),
    .s_axi_bready(s_axi_ctrl_bready),
    .s_axi_araddr(s_axi_ctrl_araddr),
    .s_axi_arvalid(s_axi_ctrl_arvalid),
    .s_axi_arready(s_axi_ctrl_arready),
    .s_axi_rdata(s_axi_ctrl_rdata),
    .s_axi_rresp(s_axi_ctrl_rresp),
    .s_axi_rvalid(s_axi_ctrl_rvalid),
    .s_axi_rready(s_axi_ctrl_rready),
    // Include the launch cycle so a read immediately after BVALID cannot
    // observe an idle mailbox before the request toggle has advanced.
    .cfg_busy(cfg_busy || cfg_apply), .link_speed(link_speed), .events(events),
    .cfg_apply(cfg_apply), .config_data(config_data), .irq(irq)
);

// Protection attributes are accepted; this IP has no access-control policy.
taxi_eth_gmii_cfg_cdc #(.WIDTH(51), .RESET_VALUE(DEFAULT_CONFIG)) config_cdc_inst (
    .src_clk(axis_aclk), .rst(cfg_reset), .apply(cfg_apply),
    .config_data(config_data), .busy(cfg_busy),
    .tx_clk(mac_tx_clk), .tx_active(gmii_tx_en), .tx_config(tx_config),
    .rx_clk(mac_rx_clk), .rx_active(gmii_rx_dv), .rx_config(rx_config)
);

taxi_eth_mac_1g_gmii_fifo #(
    .SIM(SIM),
    .VENDOR("XILINX"),
    .FAMILY(FPGA_FAMILY),
    .STAT_EN(1'b0),
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .TX_FRAME_FIFO(1'b1),
    .TX_DROP_OVERSIZE_FRAME(1'b1),
    .TX_DROP_BAD_FRAME(1'b1),
    .TX_DROP_WHEN_FULL(1'b0),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
    .RX_FRAME_FIFO(1'b1),
    .RX_DROP_OVERSIZE_FRAME(1'b1),
    .RX_DROP_BAD_FRAME(1'b1),
    .RX_DROP_WHEN_FULL(1'b1)
) mac_inst (
    .gtx_clk(gtx_clk),
    .gtx_rst(gtx_reset),
    .logic_clk(axis_aclk),
    .logic_rst(logic_rst),
    .s_axis_tx(axis_tx),
    .m_axis_tx_cpl(axis_tx_cpl),
    .m_axis_rx(axis_rx),
    .gmii_rx_clk(gmii_rx_clk),
    .gmii_rxd(gmii_rxd),
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rx_er(gmii_rx_er),
    .mii_tx_clk(mii_tx_clk),
    .gmii_tx_clk(gmii_tx_clk),
    .gmii_txd(gmii_txd),
    .gmii_tx_en(gmii_tx_en),
    .gmii_tx_er(gmii_tx_er),
    .stat_clk(axis_aclk),
    .stat_rst(logic_rst),
    .m_axis_stat(axis_stat),
    .tx_error_underflow(tx_error_underflow),
    .tx_fifo_overflow(tx_fifo_overflow),
    .tx_fifo_bad_frame(tx_fifo_bad_frame),
    .tx_fifo_good_frame(tx_fifo_good_frame),
    .rx_error_bad_frame(rx_error_bad_frame),
    .rx_error_bad_fcs(rx_error_bad_fcs),
    .rx_fifo_overflow(rx_fifo_overflow),
    .rx_fifo_bad_frame(rx_fifo_bad_frame),
    .rx_fifo_good_frame(rx_fifo_good_frame),
    .link_speed(link_speed),
    .mac_tx_clk(mac_tx_clk), .mac_tx_rst(mac_tx_rst),
    .mac_rx_clk(mac_rx_clk), .mac_rx_rst(mac_rx_rst),
    // Length fields use the core's length-minus-one encoding.
    .cfg_tx_pad_en(tx_config[2]),
    .cfg_tx_min_pkt_len(tx_config[10:3]),
    .cfg_tx_max_pkt_len(tx_config[26:11]),
    .cfg_tx_ifg(tx_config[50:43]),
    .cfg_tx_enable(tx_config[0]),
    .cfg_rx_max_pkt_len(rx_config[42:27]),
    .cfg_rx_enable(rx_config[1])
);

endmodule

`resetall
