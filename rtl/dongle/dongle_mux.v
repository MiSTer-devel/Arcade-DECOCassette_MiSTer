/*============================================================================
  Dongle Multiplexer — Task 18

  Routes $E5xx read cycles to the appropriate dongle type based on the
  3-bit dongle_type input (set per-game by MRA metadata byte).

  2026-05-18 — REWORKED interface to match MAME:
    - Each dongle returns 8-bit `cpu_din_full` (was 4-bit `cpu_din_low4`).
    - Data input is `mcu_dbb_dout` (host DBBOUT, 8-bit) and `mcu_dbb_sts`
      (host DBBSTS, 8-bit), per MAME `upi41_master_r(0)/(1)`.

  Note: the wrapper currently uses `mcu_tape_iface`'s `latched_host_dout`
  path for the cpu_din going to BIOS, BYPASSING this dongle output. That's
  fine for the boot-logo phase. To restore dongle transforms for cassette
  game loading later, change the wrapper's cpu_din source from
  `mcu_tape_iface.cpu_din` to use `dongle_din_full` instead.
============================================================================*/

`timescale 1 ps / 1 ps

module dongle_mux (
    input  wire        clk_sys,
    input  wire        ce_hclk4,
    input  wire        reset,

    input  wire [3:0]  dongle_type,   // widened: 7 = Darksoft multigame, 8 = Widel multigame
    input  wire [7:0]  game_id,    // 2026-05-30: 8-bit = DECO release number (type1 case key)
    input  wire [3:0]  swap_mode,

    input  wire        cpu_re,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_addr_lo,
    input  wire [7:0]  cpu_dout,
    output reg  [7:0]  cpu_din_full,

    output reg  [19:0] dprom_addr,   // widened to 20-bit (1 MB) for the multigame dongle ROM
    input  wire [7:0]  dprom_q,

    // MCU host-bus registers (DBBOUT/DBBSTS) per MAME `upi41_master_r(0/1)`
    input  wire [7:0]  mcu_dbb_dout,
    input  wire [7:0]  mcu_dbb_sts,

    // Type 2 uses P2[2], Type 3 uses P2[0] for game-specific encryption bits
    input  wire        mcu_status_d2,
    input  wire        mcu_status_d0
);

    wire [7:0] type1_prom_addr;
    wire [7:0] type1_q;
    dongle_type1 type1_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .cpu_din_full (type1_q),
        .game_id (game_id),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts),
        .prom_addr (type1_prom_addr), .prom_q (dprom_q)
    );

    wire [8:0] type2_prom_addr;
    wire [7:0] type2_q;
    dongle_type2 type2_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .cpu_din_full (type2_q),
        .mcu_status_d2 (mcu_status_d2),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts),
        .prom_addr (type2_prom_addr), .prom_q (dprom_q)
    );

    wire [11:0] type3_prom_addr;
    wire [7:0]  type3_q;
    dongle_type3 type3_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .cpu_din_full (type3_q),
        .swap_mode (swap_mode), .mcu_status_d0 (mcu_status_d0),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts),
        .prom_addr (type3_prom_addr), .prom_q (dprom_q)
    );

    wire [14:0] type4_prom_addr;
    wire [7:0]  type4_q;
    dongle_type4 type4_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .cpu_din_full (type4_q),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts),
        .prom_addr (type4_prom_addr), .prom_q (dprom_q)
    );

    wire [7:0] type5_q;
    dongle_type5 type5_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts),
        .cpu_din_full (type5_q)
    );

    wire [7:0] nodong_q;
    dongle_nodong nodong_inst (
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts),
        .cpu_addr_lo (cpu_addr_lo),
        .cpu_din_full (nodong_q)
    );

    // Darksoft multigame dongle — 20-bit counter into a 1 MB ROM (MAME decocass_darksoft_state)
    wire [19:0] darksoft_prom_addr;
    wire [7:0]  darksoft_q;
    dongle_darksoft darksoft_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .cpu_din_full (darksoft_q),
        .prom_addr (darksoft_prom_addr), .prom_q (dprom_q),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts)
    );

    // Widel multigame dongle — 20-bit counter/latch into a 1 MB ROM (MAME decocass_widel_state)
    wire [19:0] widel_prom_addr;
    wire [7:0]  widel_q;
    dongle_widel widel_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .cpu_din_full (widel_q),
        .prom_addr (widel_prom_addr), .prom_q (dprom_q),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts)
    );

    always @(*) begin
        case (dongle_type)
            4'd1:    cpu_din_full = type1_q;
            4'd2:    cpu_din_full = type2_q;
            4'd3:    cpu_din_full = type3_q;
            4'd4:    cpu_din_full = type4_q;
            4'd5:    cpu_din_full = type5_q;
            4'd6:    cpu_din_full = nodong_q;
            4'd7:    cpu_din_full = darksoft_q;          // Darksoft multigame (1 MB)
            4'd8:    cpu_din_full = widel_q;              // Widel multigame (1 MB)
            default: cpu_din_full = 8'hFF;
        endcase
    end

    always @(*) begin
        case (dongle_type)
            4'd1:    dprom_addr = {12'd0, type1_prom_addr};            // 8-bit
            4'd2:    dprom_addr = {11'd0, type2_prom_addr};            // 9-bit
            4'd3:    dprom_addr = {8'd0,  type3_prom_addr};            // 12-bit
            // DONGLE-TYPE4-ADDR-FIX-2026-06-27: type4 (Scrum Try/Oozumou) PROM is 32 KB and the counter is
            // 15-bit (decocass_m.cpp:887/891). The old 12-bit truncation only reached 4 KB → garbage decode
            // above $0FFF. Use the full 15-bit address. DIAG-REVERT-2026-06-27: original truncated line below.
            // 4'd4:    dprom_addr = {8'd0,  type4_prom_addr[11:0]};      // 12-bit (preserve original truncation)
            4'd4:    dprom_addr = {5'd0,  type4_prom_addr};            // 15-bit (full 32 KB type4 PROM)
            4'd7:    dprom_addr = darksoft_prom_addr;                  // 20-bit (Darksoft 1 MB)
            4'd8:    dprom_addr = widel_prom_addr;                    // 20-bit (Widel 1 MB)
            default: dprom_addr = 20'd0;
        endcase
    end

endmodule
