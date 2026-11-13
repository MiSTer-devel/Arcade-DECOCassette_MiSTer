//  Copyright (C) 2026 Rodimus

module decocassette_dispatcher
(
    input  wire                 clk_sys,
    input  wire                 reset,
    input  wire                 pause_cpu,
    input  wire                 ce_hclk_raw,
    input  wire                 ce_hclk1_raw,
    input  wire                 ce_hclk2_raw,
    input  wire                 ce_hclk4_raw,
    input  wire                 ce_audio_raw,
    input  wire                 ce_tape_raw,
    input  wire                 ce_pix,
    input  wire                 hs_pause,
    input  wire [15:0]          hs_address,
    input  wire [7:0]           hs_data_in,
    input  wire                 hs_write_enable,
    output wire [7:0]           hs_data_out,
    output wire                 hs_game_run,
    output wire                 pl_restart,
    input  wire                 ioctl_download,
    input  wire                 ioctl_wr,
    input  wire [24:0]          ioctl_addr,
    input  wire [7:0]           ioctl_dout,
    input  wire [7:0]           ioctl_index,
    input  wire [2:0]           fl_status,
    input  wire                 crt_flip,
    input  wire [15:0]          joystick_0,
    input  wire [15:0]          joystick_1,
    input  wire [15:0]          joystick_r_analog_0,
    input  wire [15:0]          joystick_r_analog_1,
    input  wire [10:0]          ps2_key,
    input  wire                 kb_coin1,
    input  wire                 kb_coin2,
    input  wire                 kb_start1,
    input  wire                 kb_start2,
    input  wire [7:0]           sw2,
    input  wire [7:0]           sw3,
    input  wire [7:0]           dprom_q,
    output wire [19:0]          dprom_addr,
    output wire                 tape_motor_on,
    output wire signed [15:0]   ay_left,
    output wire signed [15:0]   ay_right,
    output wire [23:0]          rgb_core,
    output wire                 video_hblank_d,
    output wire                 video_vblank_d,
    output wire                 video_hsync_d,
    output wire                 video_vsync_d
);

/////////////////////////////  Shared CPU / sound chip pool  /////////////////////////////

//   t65_0   main 6502 (DECO-222 decrypt in the board): DECO Cassette
//   t65_1   audio 6502: DECO Cassette
//   upi41_0 8041 cassette MCU: DECO Cassette
//   jt49_0  AY-3-8910 1: DECO Cassette
//   jt49_1  AY-3-8910 2: DECO Cassette
chip_pool_pkg::t65_i_t   t65_0_i, t65_1_i;
chip_pool_pkg::t65_o_t   t65_0_o, t65_1_o;
chip_pool_pkg::upi41_i_t upi41_0_i;
chip_pool_pkg::upi41_o_t upi41_0_o;
chip_pool_pkg::jt49_i_t  jt49_0_i, jt49_1_i;
chip_pool_pkg::jt49_o_t  jt49_0_o, jt49_1_o;

wire [23:0] t65_0_a24, t65_1_a24;
wire        t65_0_rw, t65_0_sync, t65_1_rw, t65_1_sync;
wire  [7:0] t65_0_dout, t65_1_dout;

t65sv_T65 t65_0
(
    .Mode(2'b00), .Res_n(t65_0_i.res_n), .Enable(t65_0_i.enable), .Clk(clk_sys), .Rdy(t65_0_i.rdy), .Abort_n(1'b1),
    .IRQ_n(t65_0_i.irq_n), .NMI_n(t65_0_i.nmi_n), .SO_n(1'b1),
    .R_W_n(t65_0_rw), .Sync(t65_0_sync), .EF(), .MF(), .XF(), .ML_n(), .VP_n(), .VDA(), .VPA(),
    .A(t65_0_a24), .DI(t65_0_i.di), .DO(t65_0_dout), .Regs(), .DEBUG(), .NMI_ack()
);
assign t65_0_o.a    = t65_0_a24[15:0];
assign t65_0_o.dout = t65_0_dout;
assign t65_0_o.rw   = t65_0_rw;
assign t65_0_o.sync = t65_0_sync;

t65sv_T65 t65_1
(
    .Mode(2'b00), .Res_n(t65_1_i.res_n), .Enable(t65_1_i.enable), .Clk(clk_sys), .Rdy(t65_1_i.rdy), .Abort_n(1'b1),
    .IRQ_n(t65_1_i.irq_n), .NMI_n(t65_1_i.nmi_n), .SO_n(1'b1),
    .R_W_n(t65_1_rw), .Sync(t65_1_sync), .EF(), .MF(), .XF(), .ML_n(), .VP_n(), .VDA(), .VPA(),
    .A(t65_1_a24), .DI(t65_1_i.di), .DO(t65_1_dout), .Regs(), .DEBUG(), .NMI_ack()
);
assign t65_1_o.a    = t65_1_a24[15:0];
assign t65_1_o.dout = t65_1_dout;
assign t65_1_o.rw   = t65_1_rw;
assign t65_1_o.sync = t65_1_sync;

wire        u41_sync, u41_db_dir, u41_p1_low_imp, u41_p2l_low_imp, u41_p2h_low_imp, u41_prog_n, u41_xtal3, u41_dmem_we;
wire  [7:0] u41_db, u41_sts, u41_p1, u41_p2, u41_dmem_a, u41_dmem_d;
wire [10:0] u41_pmem_a;

t48sv_upi41_core upi41_0
(
    .xtal_i(clk_sys), .xtal_en_i(upi41_0_i.xtal_en), .reset_i(upi41_0_i.reset_n),
    .cs_n_i(upi41_0_i.cs_n), .rd_n_i(upi41_0_i.rd_n), .wr_n_i(upi41_0_i.wr_n), .a0_i(upi41_0_i.a0),
    .db_i(upi41_0_i.db), .db_o(u41_db), .sts_o(u41_sts), .db_dir_o(u41_db_dir), .sync_o(u41_sync),
    .t0_i(upi41_0_i.t0), .t1_i(upi41_0_i.t1),
    .p1_i(upi41_0_i.p1_in), .p1_o(u41_p1), .p1_low_imp_o(u41_p1_low_imp),
    .p2_i(upi41_0_i.p2_in), .p2_o(u41_p2), .p2l_low_imp_o(u41_p2l_low_imp), .p2h_low_imp_o(u41_p2h_low_imp),
    .prog_n_o(u41_prog_n),
    .clk_i(clk_sys), .en_clk_i(upi41_0_i.en_clk), .xtal3_o(u41_xtal3),
    .pmem_addr_o(u41_pmem_a), .pmem_data_i(upi41_0_i.pmem_d),
    .dmem_addr_o(u41_dmem_a), .dmem_we_o(u41_dmem_we), .dmem_data_i(upi41_0_i.dmem_d), .dmem_data_o(u41_dmem_d)
);
assign upi41_0_o.sync        = u41_sync;
assign upi41_0_o.db          = u41_db;
assign upi41_0_o.sts         = u41_sts;
assign upi41_0_o.db_dir      = u41_db_dir;
assign upi41_0_o.p1          = u41_p1;
assign upi41_0_o.p2          = u41_p2;
assign upi41_0_o.p1_low_imp  = u41_p1_low_imp;
assign upi41_0_o.p2l_low_imp = u41_p2l_low_imp;
assign upi41_0_o.p2h_low_imp = u41_p2h_low_imp;
assign upi41_0_o.prog_n      = u41_prog_n;
assign upi41_0_o.xtal3       = u41_xtal3;
assign upi41_0_o.dmem_a      = u41_dmem_a;
assign upi41_0_o.dmem_we     = u41_dmem_we;
assign upi41_0_o.dmem_d      = u41_dmem_d;
assign upi41_0_o.pmem_a      = u41_pmem_a;

wire  [9:0] jt49_0_snd, jt49_1_snd;
wire  [7:0] jt49_0_a, jt49_0_b, jt49_0_c, jt49_1_a, jt49_1_b, jt49_1_c;

jt49 #(.COMP(3'b000), .CLKDIV(3)) jt49_0
(
    .rst_n(jt49_0_i.rst_n), .clk(clk_sys), .clk_en(jt49_0_i.ce), .addr(jt49_0_i.addr), .cs_n(jt49_0_i.cs_n),
    .wr_n(jt49_0_i.wr_n), .din(jt49_0_i.din), .sel(1'b1), .dout(), .sound(jt49_0_snd),
    .A(jt49_0_a), .B(jt49_0_b), .C(jt49_0_c), .sample(), .IOA_in(8'h00), .IOA_out(), .IOB_in(8'h00), .IOB_out()
);
assign jt49_0_o.sound = jt49_0_snd;
assign jt49_0_o.a     = jt49_0_a;
assign jt49_0_o.b     = jt49_0_b;
assign jt49_0_o.c     = jt49_0_c;

jt49 #(.COMP(3'b000), .CLKDIV(3)) jt49_1
(
    .rst_n(jt49_1_i.rst_n), .clk(clk_sys), .clk_en(jt49_1_i.ce), .addr(jt49_1_i.addr), .cs_n(jt49_1_i.cs_n),
    .wr_n(jt49_1_i.wr_n), .din(jt49_1_i.din), .sel(1'b1), .dout(), .sound(jt49_1_snd),
    .A(jt49_1_a), .B(jt49_1_b), .C(jt49_1_c), .sample(), .IOA_in(8'h00), .IOA_out(), .IOB_in(8'h00), .IOB_out()
);
assign jt49_1_o.sound = jt49_1_snd;
assign jt49_1_o.a     = jt49_1_a;
assign jt49_1_o.b     = jt49_1_b;
assign jt49_1_o.c     = jt49_1_c;

/////////////////////////////  Shared ROM blocks  /////////////////////////////

//   rom0  main BIOS 4K ($F000, written by the CPU too)   rom1  audio BIOS 2K        rom2  8041 program 1K
//   rom3  decocrom overlay 64K (ioctl index 2)           rom4  cassette image 64K
wire        bios_we_rom, abios_we_rom, mcurom_we;
wire [11:0] bios_addr_rom;
wire [10:0] abios_addr_rom;
wire  [9:0] mcurom_addr;
wire  [7:0] bios_dout_rom, abios_dout_rom, mcurom_dout;
wire  [7:0] dongle_type_byte, game_id_byte, swap_mode_byte;

rom_loader rom_loader_inst (
    .clk_sys               (clk_sys),
    .ioctl_download        (ioctl_download),
    .ioctl_wr              (ioctl_wr),
    .ioctl_addr            (ioctl_addr),
    .ioctl_dout            (ioctl_dout),
    .ioctl_index           (ioctl_index),
    .bios_we               (bios_we_rom),
    .bios_addr             (bios_addr_rom),
    .bios_dout             (bios_dout_rom),
    .abios_we              (abios_we_rom),
    .abios_addr            (abios_addr_rom),
    .abios_dout            (abios_dout_rom),
    .mcurom_we             (mcurom_we),
    .mcurom_addr           (mcurom_addr),
    .mcurom_dout           (mcurom_dout),
    .palprom_we            (),
    .palprom_addr          (),
    .palprom_dout          (),
    .dongleprom_we         (),
    .dongleprom_addr       (),
    .dongleprom_dout       (),
    .metadata_dongle_type  (dongle_type_byte),
    .metadata_game_id      (game_id_byte),
    .metadata_swap_mode    (swap_mode_byte)
);

wire [15:0] cass_load_addr;
wire  [7:0] cass_load_dout;
wire        cass_load_we;
wire [17:0] image_size_bytes;
wire  [7:0] crc_table_addr;
wire [15:0] crc_table_data;
wire        crc_table_we;

cassette_loader cassette_loader_inst (
    .clk_sys          (clk_sys),
    .ioctl_download   (ioctl_download),
    .ioctl_wr         (ioctl_wr),
    .ioctl_addr       (ioctl_addr),
    .ioctl_dout       (ioctl_dout),
    .ioctl_index      (ioctl_index),
    .bram_addr        (cass_load_addr),
    .bram_dout        (cass_load_dout),
    .bram_we          (cass_load_we),
    .crc_table_addr   (crc_table_addr),
    .crc_table_data   (crc_table_data),
    .crc_table_we     (crc_table_we),
    .image_size_bytes (image_size_bytes)
);

wire        user3_we_rom = ioctl_download && ioctl_wr && (ioctl_index == 8'd2);

wire [11:0] rom0_a;
wire  [7:0] rom0_d, rom0_q;
wire        rom0_we;
wire [10:0] rom1_a;
wire  [7:0] rom1_q;
wire  [9:0] rom2_a;
wire  [7:0] rom2_q;
wire [15:0] rom3_a;
wire  [7:0] rom3_q;
wire [15:0] rom4_a;
wire  [7:0] rom4_q;

dpram_dc #(.widthad_a(12)) rom0
(
    .clock_a(clk_sys), .address_a(bios_addr_rom), .data_a(bios_dout_rom), .wren_a(bios_we_rom), .q_a(),
    .clock_b(clk_sys), .address_b(rom0_a), .data_b(rom0_d), .wren_b(rom0_we), .q_b(rom0_q)
);

dpram_dc #(.widthad_a(11)) rom1
(
    .clock_a(clk_sys), .address_a(abios_addr_rom), .data_a(abios_dout_rom), .wren_a(abios_we_rom), .q_a(),
    .clock_b(clk_sys), .address_b(rom1_a), .data_b(8'd0), .wren_b(1'b0), .q_b(rom1_q)
);

dpram_dc #(.widthad_a(10)) rom2
(
    .clock_a(clk_sys), .address_a(mcurom_addr), .data_a(mcurom_dout), .wren_a(mcurom_we), .q_a(),
    .clock_b(clk_sys), .address_b(rom2_a), .data_b(8'd0), .wren_b(1'b0), .q_b(rom2_q)
);

dpram_dc #(.widthad_a(16)) rom3
(
    .clock_a(clk_sys), .address_a(ioctl_addr[15:0]), .data_a(ioctl_dout), .wren_a(user3_we_rom), .q_a(),
    .clock_b(clk_sys), .address_b(rom3_a), .data_b(8'd0), .wren_b(1'b0), .q_b(rom3_q)
);

dpram_dc #(.widthad_a(16)) rom4
(
    .clock_a(clk_sys), .address_a(cass_load_addr), .data_a(cass_load_dout), .wren_a(cass_load_we), .q_a(),
    .clock_b(clk_sys), .address_b(rom4_a), .data_b(8'd0), .wren_b(1'b0), .q_b(rom4_q)
);

/////////////////////////////  Shared RAM pool  /////////////////////////////

//   block  RAM                                 depth   user
//   0      main work RAM                       32K     DECO Cassette
//   1      charram CPU readback                32K
//   2      fgvideoram CPU copy                 1K
//   3      colorram CPU copy                   1K
//   4      tileram                             2K
//   5      objectram                           1K
//   6      paletteram CPU copy                 256
//   7      audio CPU work RAM                  4K
//   8      8041 data RAM                       128
//   9      fg tile codes (render copy)         1K
//   10     fg attributes (render copy)         1K
//   11-13  fg char planes 0-2                  8K
//   14     sprite descriptors                  1K
//   15-17  sprite graphics planes 0-2          8K
//   18     palette (render copy)               256
//   19     missile descriptors                 1K
//   20     bg tile codes                       1K
//   21     bg plane 0                          1K
//   22     bg planes 1+2                       1K
localparam int RAM_BLOCKS = 23;

ram_pool_pkg::pram_i_t [RAM_BLOCKS-1:0] deco_pr_i, pool_i;
ram_pool_pkg::pram_o_t [RAM_BLOCKS-1:0] pool_o;

assign pool_i = deco_pr_i;

function automatic int ram_aw(input int n);
    case (n)
        0, 1:                 ram_aw = 15;
        2, 3, 5, 14, 19, 20, 21, 22: ram_aw = 10;
        4:                    ram_aw = 11;
        6, 18:                ram_aw = 8;
        7:                    ram_aw = 12;
        8:                    ram_aw = 7;
        default:              ram_aw = 13;
    endcase
endfunction

genvar pn;
generate
    for (pn = 0; pn < RAM_BLOCKS; pn = pn + 1) begin : rpool
        localparam int AW = ram_aw(pn);
        dpram_dc #(.widthad_a(AW)) ram
        (
            .clock_a(clk_sys), .address_a(pool_i[pn].a_addr[AW-1:0]), .data_a(pool_i[pn].a_d), .wren_a(pool_i[pn].a_we),
            .q_a(pool_o[pn].a_q),
            .clock_b(clk_sys), .address_b(pool_i[pn].b_addr[AW-1:0]), .data_b(pool_i[pn].b_d), .wren_b(pool_i[pn].b_we),
            .q_b(pool_o[pn].b_q)
        );
    end
endgenerate

/////////////////////////////  Boards  /////////////////////////////

decocass_board board
(
    .clk_sys              (clk_sys),
    .reset                (reset),
    .pause_cpu            (pause_cpu),
    .ce_hclk_raw          (ce_hclk_raw),
    .ce_hclk1_raw         (ce_hclk1_raw),
    .ce_hclk2_raw         (ce_hclk2_raw),
    .ce_hclk4_raw         (ce_hclk4_raw),
    .ce_audio_raw         (ce_audio_raw),
    .ce_tape_raw          (ce_tape_raw),
    .ce_pix               (ce_pix),
    .hs_pause             (hs_pause),
    .hs_address           (hs_address),
    .hs_data_in           (hs_data_in),
    .hs_write_enable      (hs_write_enable),
    .hs_data_out          (hs_data_out),
    .hs_game_run          (hs_game_run),
    .pl_restart           (pl_restart),
    .fl_status            (fl_status),
    .crt_flip             (crt_flip),
    .joystick_0           (joystick_0),
    .joystick_1           (joystick_1),
    .joystick_r_analog_0  (joystick_r_analog_0),
    .joystick_r_analog_1  (joystick_r_analog_1),
    .ps2_key              (ps2_key),
    .kb_coin1             (kb_coin1),
    .kb_coin2             (kb_coin2),
    .kb_start1            (kb_start1),
    .kb_start2            (kb_start2),
    .sw2                  (sw2),
    .sw3                  (sw3),
    .dprom_q              (dprom_q),
    .dprom_addr           (dprom_addr),
    .tape_motor_on        (tape_motor_on),
    .ay_left              (ay_left),
    .ay_right             (ay_right),
    .rgb_core             (rgb_core),
    .video_hblank_d       (video_hblank_d),
    .video_vblank_d       (video_vblank_d),
    .video_hsync_d        (video_hsync_d),
    .video_vsync_d        (video_vsync_d),
    .t65_0_i              (t65_0_i),
    .t65_0_o              (t65_0_o),
    .t65_1_i              (t65_1_i),
    .t65_1_o              (t65_1_o),
    .upi41_0_i            (upi41_0_i),
    .upi41_0_o            (upi41_0_o),
    .jt49_0_i             (jt49_0_i),
    .jt49_0_o             (jt49_0_o),
    .jt49_1_i             (jt49_1_i),
    .jt49_1_o             (jt49_1_o),
    .rom0_a               (rom0_a),
    .rom0_d               (rom0_d),
    .rom0_we              (rom0_we),
    .rom0_q               (rom0_q),
    .rom1_a               (rom1_a),
    .rom1_q               (rom1_q),
    .rom2_a               (rom2_a),
    .rom2_q               (rom2_q),
    .rom3_a               (rom3_a),
    .rom3_q               (rom3_q),
    .rom4_a               (rom4_a),
    .rom4_q               (rom4_q),
    .dongle_type_byte     (dongle_type_byte),
    .game_id_byte         (game_id_byte),
    .swap_mode_byte       (swap_mode_byte),
    .image_size_bytes     (image_size_bytes),
    .crc_table_we         (crc_table_we),
    .crc_table_addr       (crc_table_addr),
    .crc_table_data       (crc_table_data),
    .pr_i                 (deco_pr_i),
    .pr_o                 (pool_o)
);

endmodule
