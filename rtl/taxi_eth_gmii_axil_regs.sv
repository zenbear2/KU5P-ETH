// SPDX-License-Identifier: CERN-OHL-S-2.0
`resetall
`timescale 1ns / 1ps
`default_nettype none

// One outstanding read and write, with independent AW and W capture.
module taxi_eth_gmii_axil_regs (
    input wire logic clk,
    input wire logic rst,
    input wire logic [11:0] s_axi_awaddr,
    input wire logic s_axi_awvalid,
    output wire logic s_axi_awready,
    input wire logic [31:0] s_axi_wdata,
    input wire logic [3:0] s_axi_wstrb,
    input wire logic s_axi_wvalid,
    output wire logic s_axi_wready,
    output logic [1:0] s_axi_bresp = 0,
    output logic s_axi_bvalid = 0,
    input wire logic s_axi_bready,
    input wire logic [11:0] s_axi_araddr,
    input wire logic s_axi_arvalid,
    output wire logic s_axi_arready,
    output logic [31:0] s_axi_rdata = 0,
    output logic [1:0] s_axi_rresp = 0,
    output logic s_axi_rvalid = 0,
    input wire logic s_axi_rready,
    input wire logic cfg_busy,
    input wire logic [1:0] link_speed,
    input wire logic [9:0] events,
    output logic cfg_apply = 0,
    output wire logic [50:0] config_data,
    output wire logic irq
);

logic aw_pending = 0, w_pending = 0;
logic [11:0] awaddr = 0;
logic [31:0] wdata = 0;
logic [3:0] wstrb = 0;
logic [31:0] control_reg = 7;
logic [31:0] min_reg = 59, tx_max_reg = 1517, rx_max_reg = 1517, ifg_reg = 12;
logic [9:0] pending = 0, mask_reg = 0;
logic [31:0] counters [10];
wire commit = aw_pending && w_pending && !s_axi_bvalid;
wire [31:0] byte_mask = {{8{wstrb[3]}}, {8{wstrb[2]}}, {8{wstrb[1]}}, {8{wstrb[0]}}};
wire [9:0] clear_pending = commit && awaddr == 12'h024 ? wdata[9:0] & byte_mask[9:0] : 10'd0;
wire clear_counters = commit && awaddr == 12'h02c && wstrb[0] && wdata[0];

assign s_axi_awready = !rst && !aw_pending && !s_axi_bvalid;
assign s_axi_wready = !rst && !w_pending && !s_axi_bvalid;
assign s_axi_arready = !rst && (!s_axi_rvalid || s_axi_rready);
assign config_data = {ifg_reg[7:0], rx_max_reg[15:0], tx_max_reg[15:0], min_reg[7:0], control_reg[2:0]};
assign irq = |(pending & mask_reg);

function automatic logic [31:0] merge_bytes(input logic [31:0] old_value);
    return (old_value & ~byte_mask) | (wdata & byte_mask);
endfunction

always_ff @(posedge clk) begin
    if (rst) begin
        aw_pending <= 0;
        w_pending <= 0;
        s_axi_bvalid <= 0;
        s_axi_bresp <= 0;
        s_axi_rvalid <= 0;
        s_axi_rresp <= 0;
        s_axi_rdata <= 0;
        control_reg <= 7;
        min_reg <= 59;
        tx_max_reg <= 1517;
        rx_max_reg <= 1517;
        ifg_reg <= 12;
        cfg_apply <= 0;
        pending <= 0;
        mask_reg <= 0;
        for (int k = 0; k < 10; k++) counters[k] <= 0;
    end else begin
        cfg_apply <= 0;
        pending <= (pending & ~clear_pending) | events;
        for (int k = 0; k < 10; k++) begin
            if (clear_counters) counters[k] <= {31'd0, events[k]};
            else if (events[k] && counters[k] != 32'hffffffff) counters[k] <= counters[k] + 1'b1;
        end

        if (s_axi_awvalid && s_axi_awready) begin
            awaddr <= s_axi_awaddr;
            aw_pending <= 1;
        end
        if (s_axi_wvalid && s_axi_wready) begin
            wdata <= s_axi_wdata;
            wstrb <= s_axi_wstrb;
            w_pending <= 1;
        end
        if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 0;
        if (commit) begin
            aw_pending <= 0;
            w_pending <= 0;
            s_axi_bvalid <= 1;
            s_axi_bresp <= 0;
            case (awaddr)
                12'h00c: begin
                    if (wstrb[0] && wdata[0]) begin
                        if (cfg_busy) s_axi_bresp <= 2'b10;
                        else cfg_apply <= 1;
                    end
                end
                12'h010: control_reg <= merge_bytes(control_reg) & 32'h7;
                12'h014: min_reg <= merge_bytes(min_reg) & 32'hff;
                12'h018: tx_max_reg <= merge_bytes(tx_max_reg) & 32'hffff;
                12'h01c: rx_max_reg <= merge_bytes(rx_max_reg) & 32'hffff;
                12'h020: ifg_reg <= merge_bytes(ifg_reg) & 32'hff;
                12'h024: begin end
                12'h028: mask_reg <= 10'((32'(mask_reg) & ~byte_mask) | (wdata & byte_mask));
                12'h02c: begin end
                default: s_axi_bresp <= 2'b10;
            endcase
        end

        if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 0;
        if (s_axi_arvalid && s_axi_arready) begin
            s_axi_rvalid <= 1;
            s_axi_rresp <= 0;
            s_axi_rdata <= 0;
            case (s_axi_araddr)
                12'h000: s_axi_rdata <= 32'h54474d49;
                12'h004: s_axi_rdata <= 32'h00010000;
                12'h008: s_axi_rdata <= {23'd0, cfg_busy, 6'd0, link_speed};
                12'h00c: s_axi_rdata <= 0;
                12'h010: s_axi_rdata <= control_reg;
                12'h014: s_axi_rdata <= min_reg;
                12'h018: s_axi_rdata <= tx_max_reg;
                12'h01c: s_axi_rdata <= rx_max_reg;
                12'h020: s_axi_rdata <= ifg_reg;
                12'h024: s_axi_rdata <= {22'd0, pending};
                12'h028: s_axi_rdata <= {22'd0, mask_reg};
                default: begin
                    if (s_axi_araddr >= 12'h040 && s_axi_araddr <= 12'h064 && s_axi_araddr[1:0] == 0)
                        s_axi_rdata <= counters[4'((s_axi_araddr-12'h040) >> 2)];
                    else s_axi_rresp <= 2'b10;
                end
            endcase
        end
    end
end

endmodule
`resetall
