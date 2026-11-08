// SPDX-License-Identifier: CERN-OHL-S-2.0

`timescale 1ns / 1ps
`default_nettype none

// Exercise the flat ports through the real MAC and FIFO implementation.
module test_taxi_eth_gmii_axi_wrapper;

logic axis_aclk = 0;
logic gtx_clk = 0;
always #5 axis_aclk = ~axis_aclk;
always #4 gtx_clk = ~gtx_clk;

logic axis_aresetn = 0;
logic gtx_reset = 1;
logic [31:0] s_axis_tx_tdata = 0;
logic [3:0] s_axis_tx_tkeep = 0;
logic s_axis_tx_tvalid = 0;
wire s_axis_tx_tready;
logic s_axis_tx_tlast = 0;
wire [31:0] m_axis_rx_tdata;
wire [3:0] m_axis_rx_tkeep;
wire m_axis_rx_tvalid;
logic m_axis_rx_tready = 0;
wire m_axis_rx_tlast;
wire m_axis_rx_tuser;
wire gmii_tx_clk;
wire [7:0] gmii_txd;
wire gmii_tx_en;
wire gmii_tx_er;
wire tx_error_underflow;
wire tx_fifo_overflow;
wire rx_error_bad_frame;
wire rx_error_bad_fcs;
wire rx_fifo_overflow;

logic [11:0] axil_awaddr = 0;
logic  axil_awvalid = 0;
wire  axil_awready;
logic [31:0] axil_wdata = 0;
logic [3:0] axil_wstrb = 0;
logic  axil_wvalid = 0;
wire  axil_wready;
wire [1:0] axil_bresp;
wire  axil_bvalid;
logic  axil_bready = 0;
logic [11:0] axil_araddr = 0;
logic  axil_arvalid = 0;
wire  axil_arready;
wire [31:0] axil_rdata;
wire [1:0] axil_rresp;
wire  axil_rvalid;
logic  axil_rready = 0;
wire irq;
logic rx_clock_enable = 1;

taxi_eth_gmii_axi_wrapper #(.SIM(1'b1)) dut (
    .irq(irq), .s_axi_ctrl_awprot(3'd0), .s_axi_ctrl_arprot(3'd0),
    .s_axi_ctrl_awaddr(axil_awaddr),
    .s_axi_ctrl_awvalid(axil_awvalid),
    .s_axi_ctrl_awready(axil_awready),
    .s_axi_ctrl_wdata(axil_wdata),
    .s_axi_ctrl_wstrb(axil_wstrb),
    .s_axi_ctrl_wvalid(axil_wvalid),
    .s_axi_ctrl_wready(axil_wready),
    .s_axi_ctrl_bresp(axil_bresp),
    .s_axi_ctrl_bvalid(axil_bvalid),
    .s_axi_ctrl_bready(axil_bready),
    .s_axi_ctrl_araddr(axil_araddr),
    .s_axi_ctrl_arvalid(axil_arvalid),
    .s_axi_ctrl_arready(axil_arready),
    .s_axi_ctrl_rdata(axil_rdata),
    .s_axi_ctrl_rresp(axil_rresp),
    .s_axi_ctrl_rvalid(axil_rvalid),
    .s_axi_ctrl_rready(axil_rready),
    .axis_aclk(axis_aclk), .axis_aresetn(axis_aresetn),
    .gtx_clk(gtx_clk), .gtx_reset(gtx_reset),
    .s_axis_tx_tdata(s_axis_tx_tdata), .s_axis_tx_tkeep(s_axis_tx_tkeep),
    .s_axis_tx_tvalid(s_axis_tx_tvalid), .s_axis_tx_tready(s_axis_tx_tready),
    .s_axis_tx_tlast(s_axis_tx_tlast), .s_axis_tx_tuser(1'b0),
    .m_axis_rx_tdata(m_axis_rx_tdata), .m_axis_rx_tkeep(m_axis_rx_tkeep),
    .m_axis_rx_tvalid(m_axis_rx_tvalid), .m_axis_rx_tready(m_axis_rx_tready),
    .m_axis_rx_tlast(m_axis_rx_tlast), .m_axis_rx_tuser(m_axis_rx_tuser),
    // Loop back the forwarded clock and complete wire-format frame.
    .gmii_rx_clk(gmii_tx_clk && rx_clock_enable), .gmii_rxd(gmii_txd),
    .gmii_rx_dv(gmii_tx_en), .gmii_rx_er(gmii_tx_er), .mii_tx_clk(1'b0),
    .gmii_tx_clk(gmii_tx_clk), .gmii_txd(gmii_txd),
    .gmii_tx_en(gmii_tx_en), .gmii_tx_er(gmii_tx_er),
    .tx_error_underflow(tx_error_underflow), .tx_fifo_overflow(tx_fifo_overflow),
    .tx_fifo_bad_frame(), .tx_fifo_good_frame(),
    .rx_error_bad_frame(rx_error_bad_frame), .rx_error_bad_fcs(rx_error_bad_fcs),
    .rx_fifo_overflow(rx_fifo_overflow), .rx_fifo_bad_frame(), .rx_fifo_good_frame(),
    .link_speed()
);

localparam FRAME_COUNT = 73;
int received = 0;
int byte_index = 0;
int cycles = 0;
int frame_size;
logic [7:0] expected_byte;

function automatic int frame_length(input int index);
    case (index)
        0: return 34;
        1: return 61;
        2: return 1514;
        default: return 60;
    endcase
endfunction

// Exercise independent AW/W arrival and hold responses under backpressure.
task automatic write_reg(input logic [11:0] addr, input logic [31:0] data,
        input logic [3:0] strb = 4'hf, input bit data_first = 0,
        input logic [1:0] expected_resp = 0);
    @(negedge axis_aclk);
    axil_bready = 0;
    if (data_first) begin
        axil_wdata = data; axil_wstrb = strb; axil_wvalid = 1;
        do @(posedge axis_aclk); while (!axil_wready);
        @(negedge axis_aclk); axil_wvalid = 0;
        repeat (3) @(negedge axis_aclk);
        axil_awaddr = addr; axil_awvalid = 1;
        do @(posedge axis_aclk); while (!axil_awready);
        @(negedge axis_aclk); axil_awvalid = 0;
    end else begin
        axil_awaddr = addr; axil_awvalid = 1;
        do @(posedge axis_aclk); while (!axil_awready);
        @(negedge axis_aclk); axil_awvalid = 0;
        repeat (3) @(negedge axis_aclk);
        axil_wdata = data; axil_wstrb = strb; axil_wvalid = 1;
        do @(posedge axis_aclk); while (!axil_wready);
        @(negedge axis_aclk); axil_wvalid = 0;
    end
    do @(negedge axis_aclk); while (!axil_bvalid);
    repeat (3) begin
        @(negedge axis_aclk);
        if (!axil_bvalid || axil_bresp != expected_resp) $fatal(1, "AXI write response mismatch");
    end
    axil_bready = 1;
    @(negedge axis_aclk); axil_bready = 0;
endtask

task automatic read_reg(input logic [11:0] addr, output logic [31:0] data,
        input logic [1:0] expected_resp = 0);
    @(negedge axis_aclk);
    axil_araddr = addr; axil_arvalid = 1; axil_rready = 0;
    do @(posedge axis_aclk); while (!axil_arready);
    @(negedge axis_aclk); axil_arvalid = 0;
    do @(negedge axis_aclk); while (!axil_rvalid);
    data = axil_rdata;
    repeat (3) begin
        @(negedge axis_aclk);
        if (!axil_rvalid || axil_rdata != data || axil_rresp != expected_resp)
            $fatal(1, "AXI read response mismatch");
    end
    axil_rready = 1;
    @(negedge axis_aclk); axil_rready = 0;
endtask

task automatic wait_config;
    logic [31:0] status;
    for (int k = 0; k < 100; k++) begin
        read_reg(12'h008, status);
        if (!status[8]) return;
    end
    $fatal(1, "Configuration acknowledgment timeout");
endtask

logic [31:0] read_value;

// Insert repeatable downstream backpressure without changing the source data.
always @(negedge axis_aclk) begin
    cycles = cycles + 1;
    m_axis_rx_tready = axis_aresetn && cycles % 7 >= 3;
end

always @(posedge axis_aclk) begin
    if (axis_aresetn) begin
        if (tx_error_underflow || tx_fifo_overflow || rx_error_bad_frame ||
                rx_error_bad_fcs || rx_fifo_overflow) begin
            $fatal(1, "Unexpected MAC or FIFO error");
        end
        if (m_axis_rx_tvalid && m_axis_rx_tready) begin
            if (received >= FRAME_COUNT || m_axis_rx_tuser) begin
                $fatal(1, "Unexpected or bad received frame");
            end
            frame_size = frame_length(received);
            for (int lane = 0; lane < 4; lane++) begin
                if (m_axis_rx_tkeep[lane]) begin
                    expected_byte = byte_index < frame_size ? 8'(byte_index + received) : 8'd0;
                    if (m_axis_rx_tdata[lane*8 +: 8] !== expected_byte) begin
                        $fatal(1, "Frame %0d byte %0d mismatch", received, byte_index);
                    end
                    byte_index++;
                end
            end
            if (m_axis_rx_tlast) begin
                if (byte_index != (frame_size < 60 ? 60 : frame_size)) begin
                    $fatal(1, "Incorrect received length: %0d", byte_index);
                end
                received++;
                byte_index = 0;
            end
        end
    end
end

initial begin
    repeat (10) @(negedge axis_aclk);
    axis_aresetn = 1;
    @(negedge gtx_clk);
    gtx_reset = 0;
    repeat (300) @(negedge axis_aclk);

    read_reg(12'h000, read_value);
    if (read_value != 32'h54474d49) $fatal(1, "IP ID mismatch");
    read_reg(12'h001, read_value, 2'b10);
    write_reg(12'h000, 0, 4'hf, 0, 2'b10);
    write_reg(12'h018, 32'h00001234, 4'h1, 1);
    read_reg(12'h018, read_value);
    if (read_value != 32'h534) $fatal(1, "WSTRB merge mismatch");
    write_reg(12'h018, 1517);
    write_reg(12'h010, 4, 4'hf, 1);
    // Shadow writes must not change live configuration before APPLY.
    if (dut.tx_config[2:0] != 7) $fatal(1, "Shadow configuration leaked");
    write_reg(12'h00c, 1);
    wait_config();
    if (dut.tx_config[2:0] != 4 || dut.rx_config[2:0] != 4)
        $fatal(1, "Configuration CDC mismatch");
    write_reg(12'h010, 7);
    write_reg(12'h020, 16);
    write_reg(12'h00c, 1);
    wait_config();
    if (dut.tx_config[50:43] != 16) $fatal(1, "IFG configuration mismatch");

    for (int frame = 0; frame < FRAME_COUNT; frame++) begin
        for (int offset = 0; offset < frame_length(frame); offset += 4) begin
            @(negedge axis_aclk);
            s_axis_tx_tdata = 0;
            s_axis_tx_tkeep = 0;
            for (int lane = 0; lane < 4; lane++) begin
                if (offset + lane < frame_length(frame)) begin
                    s_axis_tx_tdata[lane*8 +: 8] = 8'(offset + lane + frame);
                    s_axis_tx_tkeep[lane] = 1;
                end
            end
            s_axis_tx_tvalid = 1;
            s_axis_tx_tlast = offset + 4 >= frame_length(frame);
            do @(posedge axis_aclk); while (!s_axis_tx_tready);
        end
        @(negedge axis_aclk);
        s_axis_tx_tvalid = 0;
        s_axis_tx_tlast = 0;
    end

    wait (received == FRAME_COUNT);
    repeat (100) @(posedge axis_aclk);
    read_reg(12'h064, read_value);
    if (read_value != FRAME_COUNT) $fatal(1, "TX start counter mismatch");
    write_reg(12'h028, 32'h200);
    if (!irq) $fatal(1, "Missing sticky event IRQ");
    write_reg(12'h024, 32'h3ff);
    if (irq) $fatal(1, "W1C did not clear IRQ");
    write_reg(12'h02c, 1);
    read_reg(12'h064, read_value);
    if (read_value != 0) $fatal(1, "Counter clear failed");

    // An absent PHY clock must keep BUSY asserted, not falsely acknowledge.
    @(negedge gmii_tx_clk); rx_clock_enable = 0;
    write_reg(12'h020, 12);
    write_reg(12'h00c, 1);
    read_reg(12'h008, read_value);
    if (!read_value[8]) $fatal(1, "Missing BUSY with stopped RX clock");
    write_reg(12'h00c, 1, 4'hf, 1, 2'b10);
    @(negedge gmii_tx_clk); rx_clock_enable = 1;
    wait_config();
    if (dut.tx_config[50:43] != 12) $fatal(1, "Clock recovery failed");
    $display("PASS: AXI-Lite, configuration CDC, IRQ, counters and %0d loopback frames", received);
    $finish;
end

initial begin
    #500000;
    $fatal(1, "Timeout: received %0d frames", received);
end

endmodule

`resetall
