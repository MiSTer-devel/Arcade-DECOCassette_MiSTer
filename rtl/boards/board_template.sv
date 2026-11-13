//============================================================================
//  board_template.sv - DECO Cassette board template (NOT in files.qip, never compiled).
//  Copyright (C) 2026 Rodimus
//
//  Boards never instantiate a CPU, sound chip, ROM store or board RAM. Drive the pool ports. Copy this file to start a board.
//  Pools: rtl/decocassette_dispatcher.sv (chip_pool_pkg slots, Shared ROM blocks, Shared RAM pool rpool).
//  Boards go in rtl/boards/<board>/; replace the board's tie-off in the dispatcher.
//  Add one output chip_pool_pkg::<chip>_i_t <chip>_<n>_i / input chip_pool_pkg::<chip>_o_t <chip>_<n>_o pair per pool slot,
//  widen the rom<n> ports / pr_i / pr_o to the dispatcher's ROM blocks / RAM_BLOCKS.
//  CRT Flip is mandatory: crt_flip mirrors the picture 180 degrees inside the board (HDMI follows).
//============================================================================

module board_template
(
    input  logic        clk,
    input  logic        reset,
    input  logic        ce_pix,

    input  logic        crt_flip,

    output logic  [7:0] video_r,
    output logic  [7:0] video_g,
    output logic  [7:0] video_b,
    output logic        video_hs,
    output logic        video_vs,
    output logic        video_hblank,
    output logic        video_vblank,

    output logic signed [15:0] audio_l,
    output logic signed [15:0] audio_r,

    input  logic [15:0] hs_address,
    input  logic  [7:0] hs_data_in,
    output logic  [7:0] hs_data_out,
    input  logic        hs_write,

    output chip_pool_pkg::t65_i_t   t65_0_i,
    input  chip_pool_pkg::t65_o_t   t65_0_o,
    output chip_pool_pkg::t65_i_t   t65_1_i,
    input  chip_pool_pkg::t65_o_t   t65_1_o,
    output chip_pool_pkg::upi41_i_t upi41_0_i,
    input  chip_pool_pkg::upi41_o_t upi41_0_o,
    output chip_pool_pkg::jt49_i_t  jt49_0_i,
    input  chip_pool_pkg::jt49_o_t  jt49_0_o,
    output chip_pool_pkg::jt49_i_t  jt49_1_i,
    input  chip_pool_pkg::jt49_o_t  jt49_1_o,

    output logic [15:0] rom0_a,
    input  logic  [7:0] rom0_q,

    output ram_pool_pkg::pram_i_t [22:0] pr_i,
    input  ram_pool_pkg::pram_o_t [22:0] pr_o
);

assign video_r      = 8'd0;
assign video_g      = 8'd0;
assign video_b      = 8'd0;
assign video_hs     = 1'b0;
assign video_vs     = 1'b0;
assign video_hblank = 1'b1;
assign video_vblank = 1'b1;
assign audio_l      = 16'sd0;
assign audio_r      = 16'sd0;
assign hs_data_out  = 8'd0;
assign rom0_a       = '0;
assign t65_0_i      = '0;
assign t65_1_i      = '0;
assign upi41_0_i    = '0;
assign jt49_0_i     = '0;
assign jt49_1_i     = '0;
assign pr_i         = '0;

endmodule
