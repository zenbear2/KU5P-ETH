// SPDX-License-Identifier: CERN-OHL-S-2.0

`resetall
`timescale 1ns / 1ps
`default_nettype none

// Top-level alias module for taxi_eth_gmii_axi_wrapper targeted to Xilinx KU5P
module taxi_eth_axi_wrapper #(
    parameter logic SIM = 1'b0,
    parameter string FPGA_FAMILY = "kintexuplus",
    parameter AXIS_DATA_WIDTH = 32,
    parameter TX_FIFO_DEPTH = 4096,
    parameter RX_FIFO_DEPTH = 4096
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_aclk CLK",
       X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXIS_TX:M_AXIS_RX:S_AXI_CTRL, ASSOCIATED_RESET axis_aresetn" *)
    input  wire logic                         axis_aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 axis_aresetn RST",
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire logic                         axis_aresetn,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 gtx_clk CLK",
       X_INTERFACE_PARAMETER = "FREQ_HZ 125000000, ASSOCIATED_RESET gtx_reset" *)
    input  wire logic                         gtx_clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 gtx_reset RST",
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    input  wire logic                         gtx_reset,

    // Control and streams share axis_aclk and axis_aresetn.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL AWADDR" *)
    (* X_INTERFACE_PARAMETER = "PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 12" *)
    input  wire logic [11:0]     s_axi_ctrl_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL AWPROT" *)
    input  wire logic [2:0]      s_axi_ctrl_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL AWVALID" *)
    input  wire logic            s_axi_ctrl_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL AWREADY" *)
    output wire logic            s_axi_ctrl_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL WDATA" *)
    input  wire logic [31:0]     s_axi_ctrl_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL WSTRB" *)
    input  wire logic [3:0]      s_axi_ctrl_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL WVALID" *)
    input  wire logic            s_axi_ctrl_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL WREADY" *)
    output wire logic            s_axi_ctrl_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL BRESP" *)
    output wire logic [1:0]      s_axi_ctrl_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL BVALID" *)
    output wire logic            s_axi_ctrl_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL BREADY" *)
    input  wire logic            s_axi_ctrl_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL ARADDR" *)
    input  wire logic [11:0]     s_axi_ctrl_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL ARPROT" *)
    input  wire logic [2:0]      s_axi_ctrl_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL ARVALID" *)
    input  wire logic            s_axi_ctrl_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL ARREADY" *)
    output wire logic            s_axi_ctrl_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL RDATA" *)
    output wire logic [31:0]     s_axi_ctrl_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL RRESP" *)
    output wire logic [1:0]      s_axi_ctrl_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL RVALID" *)
    output wire logic            s_axi_ctrl_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_CTRL RREADY" *)
    input  wire logic            s_axi_ctrl_rready,
    (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 irq INTERRUPT",
       X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
    output wire logic            irq,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_TX TDATA" *)
    input  wire logic [AXIS_DATA_WIDTH-1:0]     s_axis_tx_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_TX TKEEP" *)
    input  wire logic [AXIS_DATA_WIDTH/8-1:0]   s_axis_tx_tkeep,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_TX TVALID" *)
    input  wire logic                           s_axis_tx_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_TX TREADY" *)
    output wire logic                           s_axis_tx_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_TX TLAST" *)
    input  wire logic                           s_axis_tx_tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_TX TUSER" *)
    input  wire logic                           s_axis_tx_tuser,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RX TDATA" *)
    output wire logic [AXIS_DATA_WIDTH-1:0]     m_axis_rx_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RX TKEEP" *)
    output wire logic [AXIS_DATA_WIDTH/8-1:0]   m_axis_rx_tkeep,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RX TVALID" *)
    output wire logic                           m_axis_rx_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RX TREADY" *)
    input  wire logic                           m_axis_rx_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RX TLAST" *)
    output wire logic                           m_axis_rx_tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RX TUSER" *)
    output wire logic                           m_axis_rx_tuser,

    input  wire logic                           gmii_rx_clk,
    input  wire logic [7:0]                     gmii_rxd,
    input  wire logic                           gmii_rx_dv,
    input  wire logic                           gmii_rx_er,
    input  wire logic                           mii_tx_clk,
    output wire logic                           gmii_tx_clk,
    output wire logic [7:0]                     gmii_txd,
    output wire logic                           gmii_tx_en,
    output wire logic                           gmii_tx_er,

    // Status events in axis_aclk domain
    output wire logic                           tx_error_underflow,
    output wire logic                           tx_fifo_overflow,
    output wire logic                           tx_fifo_bad_frame,
    output wire logic                           tx_fifo_good_frame,
    output wire logic                           rx_error_bad_frame,
    output wire logic                           rx_error_bad_fcs,
    output wire logic                           rx_fifo_overflow,
    output wire logic                           rx_fifo_bad_frame,
    output wire logic                           rx_fifo_good_frame,
    output wire logic [1:0]                     link_speed
);

    // Direct instantiation of core wrapper
    taxi_eth_gmii_axi_wrapper #(
        .SIM(SIM),
        .FPGA_FAMILY(FPGA_FAMILY),
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
        .RX_FIFO_DEPTH(RX_FIFO_DEPTH)
    ) wrapper_inst (
        .axis_aclk(axis_aclk),
        .axis_aresetn(axis_aresetn),
        .gtx_clk(gtx_clk),
        .gtx_reset(gtx_reset),
        .s_axi_ctrl_awaddr(s_axi_ctrl_awaddr),
        .s_axi_ctrl_awprot(s_axi_ctrl_awprot),
        .s_axi_ctrl_awvalid(s_axi_ctrl_awvalid),
        .s_axi_ctrl_awready(s_axi_ctrl_awready),
        .s_axi_ctrl_wdata(s_axi_ctrl_wdata),
        .s_axi_ctrl_wstrb(s_axi_ctrl_wstrb),
        .s_axi_ctrl_wvalid(s_axi_ctrl_wvalid),
        .s_axi_ctrl_wready(s_axi_ctrl_wready),
        .s_axi_ctrl_bresp(s_axi_ctrl_bresp),
        .s_axi_ctrl_bvalid(s_axi_ctrl_bvalid),
        .s_axi_ctrl_bready(s_axi_ctrl_bready),
        .s_axi_ctrl_araddr(s_axi_ctrl_araddr),
        .s_axi_ctrl_arprot(s_axi_ctrl_arprot),
        .s_axi_ctrl_arvalid(s_axi_ctrl_arvalid),
        .s_axi_ctrl_arready(s_axi_ctrl_arready),
        .s_axi_ctrl_rdata(s_axi_ctrl_rdata),
        .s_axi_ctrl_rresp(s_axi_ctrl_rresp),
        .s_axi_ctrl_rvalid(s_axi_ctrl_rvalid),
        .s_axi_ctrl_rready(s_axi_ctrl_rready),
        .irq(irq),
        .s_axis_tx_tdata(s_axis_tx_tdata),
        .s_axis_tx_tkeep(s_axis_tx_tkeep),
        .s_axis_tx_tvalid(s_axis_tx_tvalid),
        .s_axis_tx_tready(s_axis_tx_tready),
        .s_axis_tx_tlast(s_axis_tx_tlast),
        .s_axis_tx_tuser(s_axis_tx_tuser),
        .m_axis_rx_tdata(m_axis_rx_tdata),
        .m_axis_rx_tkeep(m_axis_rx_tkeep),
        .m_axis_rx_tvalid(m_axis_rx_tvalid),
        .m_axis_rx_tready(m_axis_rx_tready),
        .m_axis_rx_tlast(m_axis_rx_tlast),
        .m_axis_rx_tuser(m_axis_rx_tuser),
        .gmii_rx_clk(gmii_rx_clk),
        .gmii_rxd(gmii_rxd),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er),
        .mii_tx_clk(mii_tx_clk),
        .gmii_tx_clk(gmii_tx_clk),
        .gmii_txd(gmii_txd),
        .gmii_tx_en(gmii_tx_en),
        .gmii_tx_er(gmii_tx_er),
        .tx_error_underflow(tx_error_underflow),
        .tx_fifo_overflow(tx_fifo_overflow),
        .tx_fifo_bad_frame(tx_fifo_bad_frame),
        .tx_fifo_good_frame(tx_fifo_good_frame),
        .rx_error_bad_frame(rx_error_bad_frame),
        .rx_error_bad_fcs(rx_error_bad_fcs),
        .rx_fifo_overflow(rx_fifo_overflow),
        .rx_fifo_bad_frame(rx_fifo_bad_frame),
        .rx_fifo_good_frame(rx_fifo_good_frame),
        .link_speed(link_speed)
    );

endmodule

`resetall
