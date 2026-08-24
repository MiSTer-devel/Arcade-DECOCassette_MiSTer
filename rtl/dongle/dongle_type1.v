/*============================================================================
  Type 1 Dongle (DE-0061) -bit permutation + 32-byte PROM lookup

  Faithful to MAME decocass_type1_r (decocass_m.cpp:266-339), the per-game
  machine_resets (1457-1561), and the flags tables (357-460). Reads the 8041
  host data byte, uses the T1PROM-flagged bits to address a 32-byte PROM, and
  rebuilds the output byte via per-game in/out bit-permutation maps + flags.

  2026-05-30 RE-KEY: game_id is now the DECO RELEASE NUMBER (8-bit), matching
  MAME's numbering (decocass.cpp per-game release-number comments). Map VALUES from
  MAME via /tmp/gen_type1.py. (The old nibble-style 24'h0_76_54_32_10 literals
  were wrong -4-bit-nibble encoding truncated to 24 bits = garbage under the
  3-bit t1map_get.) inmap/outmap are now correct 3-bit MAKE_MAP packings:
  MAKE_MAP = m0 | m1<<3 | ... | m7<<21 ;  T1MAP(i,map) = (map >> i*3) & 7.
============================================================================*/

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

    input  wire [7:0]  game_id,         // 2026-05-30: DECO release number (8-bit)
    input  wire [7:0]  mcu_dbb_dout,
    input  wire [7:0]  mcu_dbb_sts,

    output wire [7:0]  prom_addr,
    input  wire [7:0]  prom_q
);

    // Swap source = the 8041 host DATA byte (DBBOUT), per MAME decocass_type1_r.
    wire [7:0] mcu_status_low = mcu_dbb_dout;

    localparam T1PROM     = 4'h1;   // bit feeds PROM address
    localparam T1DIRECT   = 4'h2;   // bit passes directly
    localparam T1LATCH    = 4'h4;   // bit from latched input
    localparam T1LATCHINV = 4'h8;   // bit from inverted latched input

    // Per-game config: inmap/outmap (3-bit MAKE_MAP) + 8-bit flags array.
    // game_id = DECO release number. Regenerated from MAME (see header).
    reg [23:0] inmap, outmap;
    reg  [3:0] type1_map [0:7];

    always @(*) begin
        case (game_id)
            8'd0: begin  // ctsttape (DECO release 0) -pass_136
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1DIRECT; type1_map[2]=T1PROM; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1DIRECT; type1_map[7]=T1PROM;
            end
            8'd1: begin  // chwy (DECO release 1) -latch_27_pass_3_inv_2
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1PROM; type1_map[7]=T1LATCH;
            end
            8'd3: begin  // cmanhat (DECO release 3) -latch_xab_pass_x54
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1DIRECT; type1_map[3]=T1PROM; type1_map[4]=T1DIRECT; type1_map[5]=T1PROM; type1_map[6]=T1DIRECT; type1_map[7]=T1PROM;
            end
            8'd4: begin  // cterrani (DECO release 4) -latch_26_pass_3_inv_2
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd6: begin  // cnebula (DECO release 6) -nebula
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1DIRECT; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1DIRECT; type1_map[6]=T1PROM; type1_map[7]=T1PROM;
            end
            8'd7: begin  // castfant (DECO release 7) -latch_16_pass_3_inv_1
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1LATCHINV; type1_map[2]=T1PROM; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd8: begin  // ctower (DECO release 8) -map1120 (cfboy0a1 cfg)
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1LATCH; type1_map[6]=T1PROM; type1_map[7]=T1PROM;
            end
            8'd9: begin  // csuperas (DECO release 9) -latch_26_pass_3_inv_2 flip4-5
                inmap = 24'hFA5688; outmap = 24'hFA5688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd10: begin  // cocean1a (DECO release 10) -map1100
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1PROM; type1_map[4]=T1DIRECT; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd11: begin  // clocknch (DECO release 11) -latch_26_pass_3_inv_2 flip2-3
                inmap = 24'hFAC4C8; outmap = 24'hFAC4C8;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd12: begin  // cfboy0a1 (DECO release 12) -map1120
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1LATCH; type1_map[6]=T1PROM; type1_map[7]=T1PROM;
            end
            8'd13: begin  // cprogolf (DECO release 13) -latch_26_pass_3_inv_2 flip0-1
                inmap = 24'hFAC681; outmap = 24'hFAC681;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd14: begin  // cdsteljn (DECO release 14) -latch_27_pass_3_inv_2
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1PROM; type1_map[7]=T1LATCH;
            end
            8'd15: begin  // cluckypo (DECO release 15) -latch_26_pass_3_inv_2 flip1-3
                inmap = 24'hFAC298; outmap = 24'hFAC298;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd16: begin  // ctisland (DECO release 16) -latch_26_pass_3_inv_2 flip0-2
                inmap = 24'hFAC60A; outmap = 24'hFAC60A;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd17: begin  // ctisland3 (handcrafted dongle PROM; MAME comment: "correct for
                          // handcrafted prom" -> identity in/out maps, decocass_m.cpp:1563-1570)
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1LATCHINV; type1_map[1]=T1PROM; type1_map[2]=T1PROM; type1_map[3]=T1DIRECT; type1_map[4]=T1PROM; type1_map[5]=T1PROM; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            8'd18: begin  // cexplore (DECO release 18) -latch_26_pass_5_inv_2
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=T1PROM; type1_map[1]=T1PROM; type1_map[2]=T1LATCHINV; type1_map[3]=T1PROM; type1_map[4]=T1PROM; type1_map[5]=T1DIRECT; type1_map[6]=T1LATCH; type1_map[7]=T1PROM;
            end
            default: begin  // unknown game_id -> inert (no PROM/latch/direct bits)
                inmap = 24'hFAC688; outmap = 24'hFAC688;
                type1_map[0]=4'h0; type1_map[1]=4'h0; type1_map[2]=4'h0; type1_map[3]=4'h0;
                type1_map[4]=4'h0; type1_map[5]=4'h0; type1_map[6]=4'h0; type1_map[7]=4'h0;
            end
        endcase
    end

    // Latched MCU data byte (previous A0==0 read), per decocass_m.cpp:336.
    reg [7:0] latch1;

    // T1MAP(i,map) = (map >> i*3) & 7  (decocass_m.cpp:32-35)
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
        // Phase 1: collect PROM address bits from the T1PROM-flagged input bits.
        for (i = 0; i < 8; i = i + 1) begin
            if (type1_map[i] == T1PROM) begin
                prom_addr_int[prom_shift] = mcu_status_low[t1map_get(i, inmap)];
                prom_shift = prom_shift + 1;
            end
        end
        // Phase 2: build output (PROM / direct / latch / latch-inv) per outmap.
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

    // Output: A0==0 (data) -> permuted byte; A0==1 (status) -> 0x7C | {IBF,OBF}.
    always @(*) begin
        if (cpu_addr_lo[0] == 1'b0)
            cpu_din_full = permuted;
        else
            cpu_din_full = 8'h7C | {6'b0, mcu_dbb_sts[1:0]};
    end

    // Latch the unmodified data byte on each A0==0 read (for next cycle's LATCH bits).
    always @(posedge clk_sys) begin
        if (reset)
            latch1 <= 8'h00;
        else if (ce_hclk4 && cpu_re && (cpu_addr_lo[0] == 1'b0))
            latch1 <= mcu_status_low;
    end

    assign prom_addr = {3'b000, prom_addr_int};

endmodule
