// SPDX-License-Identifier: CERN-OHL-S-2.0
`resetall
`timescale 1ns / 1ps
`default_nettype none

// A bundled-data mailbox. The source holds the payload until both
// destinations acknowledge it. Software must quiesce traffic before APPLY.
module taxi_eth_gmii_cfg_cdc #(
    parameter WIDTH = 51,
    parameter logic [WIDTH-1:0] RESET_VALUE = '0
)(
    input wire logic src_clk,
    input wire logic rst,
    input wire logic apply,
    input wire logic [WIDTH-1:0] config_data,
    output wire logic busy,
    input wire logic tx_clk,
    input wire logic tx_active,
    output logic [WIDTH-1:0] tx_config = RESET_VALUE,
    input wire logic rx_clk,
    input wire logic rx_active,
    output logic [WIDTH-1:0] rx_config = RESET_VALUE
);

logic [WIDTH-1:0] payload = RESET_VALUE;
logic request = 0;
logic tx_ack = 0, rx_ack = 0;
(* ASYNC_REG = "TRUE" *) logic [1:0] tx_req_sync = 0, rx_req_sync = 0;
(* ASYNC_REG = "TRUE" *) logic [1:0] tx_ack_sync = 0, rx_ack_sync = 0;
logic [3:0] tx_idle_count = 0, rx_idle_count = 0;
wire src_rst, tx_rst, rx_rst;

taxi_sync_reset #(.N(4)) src_reset (.clk(src_clk), .rst(rst), .out(src_rst));
taxi_sync_reset #(.N(4)) tx_reset (.clk(tx_clk), .rst(rst), .out(tx_rst));
taxi_sync_reset #(.N(4)) rx_reset (.clk(rx_clk), .rst(rst), .out(rx_rst));

assign busy = src_rst || (tx_ack_sync[1] != request) || (rx_ack_sync[1] != request);

always_ff @(posedge src_clk or posedge src_rst) begin
    if (src_rst) begin
        payload <= RESET_VALUE;
        request <= 0;
        tx_ack_sync <= 0;
        rx_ack_sync <= 0;
    end else begin
        tx_ack_sync <= {tx_ack_sync[0], tx_ack};
        rx_ack_sync <= {rx_ack_sync[0], rx_ack};
        if (apply && !busy) begin
            payload <= config_data;
            request <= ~request;
        end
    end
end

// Wait for eight idle clocks to let the frame pipelines finish. New RX
// traffic can postpone an update indefinitely; BUSY remains asserted.
always_ff @(posedge tx_clk or posedge tx_rst) begin
    if (tx_rst) begin
        tx_req_sync <= 0;
        tx_ack <= 0;
        tx_idle_count <= 0;
        tx_config <= RESET_VALUE;
    end else begin
        tx_req_sync <= {tx_req_sync[0], request};
        if (tx_active) tx_idle_count <= 0;
        else if (!tx_idle_count[3]) tx_idle_count <= tx_idle_count + 1'b1;
        if (tx_req_sync[1] != tx_ack && tx_idle_count[3] && !tx_active) begin
            tx_config <= payload;
            tx_ack <= tx_req_sync[1];
        end
    end
end

always_ff @(posedge rx_clk or posedge rx_rst) begin
    if (rx_rst) begin
        rx_req_sync <= 0;
        rx_ack <= 0;
        rx_idle_count <= 0;
        rx_config <= RESET_VALUE;
    end else begin
        rx_req_sync <= {rx_req_sync[0], request};
        if (rx_active) rx_idle_count <= 0;
        else if (!rx_idle_count[3]) rx_idle_count <= rx_idle_count + 1'b1;
        if (rx_req_sync[1] != rx_ack && rx_idle_count[3] && !rx_active) begin
            rx_config <= payload;
            rx_ack <= rx_req_sync[1];
        end
    end
end

endmodule
`resetall
