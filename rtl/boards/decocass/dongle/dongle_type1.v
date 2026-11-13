//  Based on MAME decocass_m.cpp, decocass.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

`timescale 1 ps / 1 ps

module dongle_type1 (
    input  wire        clk_sys,
    input  wire        ce_hclk4,
    input  wire        reset,

    input  wire        cpu_re,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_addr_lo,
    input  wire [7:0]  cpu_dout,
    output reg  [7:0]  cpu_din_full,

    input  wire [7:0]  game_id,
    input  wire [7:0]  mcu_dbb_dout,
    input  wire [7:0]  mcu_dbb_sts,

    output wire [7:0]  prom_addr,
    input  wire [7:0]  prom_q
);

    wire [7:0] mcu_status_low = mcu_dbb_dout;

    localparam T1PROM     = 4'h1;
    localparam T1DIRECT   = 4'h2;
    localparam T1LATCH    = 4'h4;
    localparam T1LATCHINV = 4'h8;

    reg [23:0] inmap, outmap;
    reg  [3:0] type1_map [0:7];

    always @(*) begin
        case (game_id)
            8'd0: begin
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1DIRECT; type1_map[2]=T1PROM; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1DIRECT; type1_map[7]=T1PROM;
            end
            8'd1: begin
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1PROM; type1_map[7]=T1LATCH;
            end
            8'd3: begin
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1DIRECT; type1_map[3]=T1PROM; type1_map[4]=T1DIRECT; type1_map[5]=T1PROM; type1_map[6]=T1DIRECT; type1_map[7]=T1PROM;
            end
            8'd4: begin
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd6: begin
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1DIRECT; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1DIRECT; type1_map[6]=T1PROM; type1_map[7]=T1PROM;
            end
            8'd7: begin
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1LATCHINV; type1_map[2]=T1PROM; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd8: begin
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1LATCH; type1_map[6]=T1PROM; type1_map[7]=T1PROM;
            end
            8'd9: begin
                inmap = 24'hFA5688; outmap = 24'hFA5688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd10: begin
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1PROM; type1_map[4]=T1DIRECT; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd11: begin
                inmap = 24'hFAC4C8; outmap = 24'hFAC4C8;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd12: begin
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1LATCH; type1_map[6]=T1PROM; type1_map[7]=T1PROM;
            end
            8'd13: begin
                inmap = 24'hFAC681; outmap = 24'hFAC681;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd14: begin
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1PROM; type1_map[7]=T1LATCH;
            end
            8'd15: begin
                inmap = 24'hFAC298; outmap = 24'hFAC298;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd16: begin
                inmap = 24'hFAC60A; outmap = 24'hFAC60A;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd17: begin
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1LATCHINV; type1_map[1]=T1PROM; type1_map[2]=T1PROM; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd18: begin
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1PROM; type1_map[4]=T1PROM; type1_map[5]=T1DIRECT; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            default: begin
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=4'h0; type1_map[1]=4'h0; type1_map[2]=4'h0; type1_map[3]=4'h0;
                type1_map[4]=4'h0; type1_map[5]=4'h0; type1_map[6]=4'h0; type1_map[7]=4'h0;
            end
        endcase
    end

    reg [7:0] latch1;

    function [2:0] t1map_get;
        input integer i;
        input [23:0] map;
        begin
            t1map_get = (map >> (i * 3)) & 3'h7;
        end
    endfunction

    reg [7:0] permuted;
    reg [4:0] prom_addr_int;
    integer i;
    integer prom_shift;

    always @(*) begin
        permuted = 8'h00;
        prom_addr_int = 5'h00;
        prom_shift = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (type1_map[i] == T1PROM) begin
                prom_addr_int[prom_shift] = mcu_status_low[t1map_get(i, inmap)];
                prom_shift = prom_shift + 1;
            end
        end
        prom_shift = 0;
        for (i = 0; i < 8; i = i + 1) begin
            case (type1_map[i])
                T1PROM: begin
                    permuted[t1map_get(i, outmap)] = prom_q[prom_shift];
                    prom_shift = prom_shift + 1;
                end
                T1DIRECT:    permuted[t1map_get(i, outmap)] = mcu_status_low[t1map_get(i, inmap)];
                T1LATCH:     permuted[t1map_get(i, outmap)] = latch1[t1map_get(i, inmap)];
                T1LATCHINV:  permuted[t1map_get(i, outmap)] = ~latch1[t1map_get(i, inmap)];
            endcase
        end
    end

    always @(*) begin
        if (cpu_addr_lo[0] == 1'b0)
            cpu_din_full = permuted;
        else
            cpu_din_full = 8'h7C | {6'b0, mcu_dbb_sts[1:0]};
    end

    always @(posedge clk_sys) begin
        if (reset)
            latch1 <= 8'h00;
        else if (ce_hclk4 && cpu_re && (cpu_addr_lo[0] == 1'b0))
            latch1 <= mcu_status_low;
    end

    assign prom_addr = {3'b000, prom_addr_int};

endmodule
