//  Copyright (C) 2026 Rodimus

module decocass_board
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
    output wire                 video_vsync_d,

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

    output wire [11:0]          rom0_a,
    output wire [7:0]           rom0_d,
    output wire                 rom0_we,
    input  wire [7:0]           rom0_q,
    output wire [10:0]          rom1_a,
    input  wire [7:0]           rom1_q,
    output wire [9:0]           rom2_a,
    input  wire [7:0]           rom2_q,
    output wire [15:0]          rom3_a,
    input  wire [7:0]           rom3_q,
    output wire [15:0]          rom4_a,
    input  wire [7:0]           rom4_q,

    input  wire [7:0]           dongle_type_byte,
    input  wire [7:0]           game_id_byte,
    input  wire [7:0]           swap_mode_byte,
    input  wire [17:0]          image_size_bytes,
    input  wire                 crc_table_we,
    input  wire [7:0]           crc_table_addr,
    input  wire [15:0]          crc_table_data,

    output ram_pool_pkg::pram_i_t [22:0] pr_i,
    input  ram_pool_pkg::pram_o_t [22:0] pr_o
);

localparam B_WORK = 0, B_CHAR = 1, B_FGV = 2, B_COL = 3, B_TIL = 4, B_OBJ = 5, B_PAL = 6, B_ARAM = 7, B_DMEM = 8;
localparam B_V_FGV = 9, B_V_COL = 10, B_V_CH0 = 11, B_V_CH1 = 12, B_V_CH2 = 13, B_V_SDESC = 14, B_V_SG0 = 15,
           B_V_SG1 = 16, B_V_SG2 = 17, B_V_PAL = 18, B_V_MIS = 19, B_V_BGT = 20, B_V_BG0 = 21, B_V_BG12 = 22;

wire ce_hclk  = ce_hclk_raw  & ~pause_cpu;
wire ce_hclk1 = ce_hclk1_raw & ~pause_cpu;
wire ce_hclk2 = ce_hclk2_raw & ~pause_cpu;
reg  [1:0] hs_pause_d = 2'b00;
always @(posedge clk_sys) hs_pause_d <= {hs_pause_d[0], hs_pause};
wire hs_hold = hs_pause | (|hs_pause_d);
wire pl_active, pl_ce_main, pl_ce_audio;
wire [15:0] pl_cas_addr;
wire  [7:0] pl_dbb_dout, pl_dbb_sts, pl_e502;
wire ce_hclk4 = (pl_active ? pl_ce_main : ce_hclk4_raw) & ~pause_cpu & ~hs_hold;
wire ce_audio = (pl_active ? pl_ce_audio : ce_audio_raw) & ~pause_cpu;
wire ce_tape  = ce_tape_raw  & ~pause_cpu;

wire [7:0]  sound_data, sound_ack;
wire [7:0]  input_q;
wire [7:0]  e5xx_dongle;
wire [7:0]  e5xx_to_cpu;

wire [7:0]  bios_dout_cpu;
wire        bios_we_cpu_int;

wire        video_vblank, video_hsync, video_vsync, video_hblank;

wire [8:0]  hcnt, vcnt;

wire [7:0] game_id   = game_id_byte;
wire [3:0] swap_mode = swap_mode_byte[3:0];
wire [3:0] dongle_type = dongle_type_byte[3:0];

wire [11:0] bios_addr_cpu_dec;
wire [7:0]  bios_q = rom0_q;

assign rom0_a  = bios_addr_cpu_dec;
assign rom0_we = bios_we_cpu_int & ce_hclk4;
assign rom0_d  = bios_dout_cpu;

wire [14:0] ram_addr_cpu;
wire        ram_we_cpu;
wire [7:0]  ram_dw_cpu, ram_q;

assign pr_i[B_WORK] = '{a_addr: {1'b0, ram_addr_cpu}, a_d: ram_dw_cpu, a_we: ram_we_cpu, b_addr: 16'd0, b_d: 8'd0, b_we: 1'b0};
assign ram_q        = pr_o[B_WORK].a_q;

wire [14:0] charram_addr_cpu;
wire        charram_we_p0, charram_we_p1, charram_we_p2;
wire        charram_we_any = charram_we_p0 | charram_we_p1 | charram_we_p2;
wire [7:0]  charram_dw_cpu, charram_q;

assign pr_i[B_CHAR] = '{a_addr: {1'b0, charram_addr_cpu}, a_d: charram_dw_cpu, a_we: charram_we_any, b_addr: 16'd0, b_d: 8'd0, b_we: 1'b0};
assign charram_q    = pr_o[B_CHAR].a_q;

wire [15:0] user3_addr;
wire [7:0]  user3_q = rom3_q;
assign rom3_a = user3_addr;

wire [9:0]  fgvram_addr_cpu;
wire        fgvram_we_cpu;
wire [7:0]  fgvram_dw_cpu, fgvram_q;

assign pr_i[B_FGV] = '{a_addr: {6'd0, fgvram_addr_cpu}, a_d: fgvram_dw_cpu, a_we: fgvram_we_cpu, b_addr: 16'd0, b_d: 8'd0, b_we: 1'b0};
assign fgvram_q     = pr_o[B_FGV].a_q;

wire [9:0]  colram_addr_cpu;
wire        colram_we_cpu;
wire [7:0]  colram_dw_cpu, colram_q;

assign pr_i[B_COL] = '{a_addr: {6'd0, colram_addr_cpu}, a_d: colram_dw_cpu, a_we: colram_we_cpu, b_addr: 16'd0, b_d: 8'd0, b_we: 1'b0};
assign colram_q     = pr_o[B_COL].a_q;

wire [10:0] tilram_addr_cpu;
wire        tilram_we_cpu;
wire [7:0]  tilram_dw_cpu, tilram_q;

assign pr_i[B_TIL] = '{a_addr: {5'd0, tilram_addr_cpu}, a_d: tilram_dw_cpu, a_we: tilram_we_cpu, b_addr: 16'd0, b_d: 8'd0, b_we: 1'b0};
assign tilram_q     = pr_o[B_TIL].a_q;

wire [9:0]  objram_addr_cpu;
wire        objram_we_cpu;
wire [7:0]  objram_dw_cpu, objram_q;

assign pr_i[B_OBJ] = '{a_addr: {6'd0, objram_addr_cpu}, a_d: objram_dw_cpu, a_we: objram_we_cpu, b_addr: 16'd0, b_d: 8'd0, b_we: 1'b0};
assign objram_q     = pr_o[B_OBJ].a_q;

wire [7:0]  palram_addr_cpu;
wire        palram_we_cpu;
wire [7:0]  palram_dw_cpu, palram_q;

assign pr_i[B_PAL] = '{a_addr: {8'd0, palram_addr_cpu}, a_d: palram_dw_cpu, a_we: palram_we_cpu, b_addr: 16'd0, b_d: 8'd0, b_we: 1'b0};
assign palram_q     = pr_o[B_PAL].a_q;

wire [15:0] cpu_addr;
wire [7:0]  cpu_dout;
wire        cpu_rw_n, cpu_sync;

wire cpu_we_ram, cpu_we_charram, cpu_we_fgvram, cpu_we_colram;
wire cpu_we_tilram, cpu_we_objram, cpu_we_palram;
wire cpu_we_e3xx, cpu_we_e4xx, cpu_we_e414, cpu_we_e5xx, cpu_re_e5xx;
wire cpu_we_e6xx, cpu_we_e7xx, cpu_re_e700, cpu_re_e701;

wire [7:0] mode_set_reg, back_h_shift_reg, back_vl_shift_reg, back_vr_shift_reg;
wire [7:0] part_h_shift_reg, part_v_shift_reg, color_center_bot_reg;
wire [7:0] color_missiles_reg;
wire [7:0] center_h_shift_space_reg, center_v_shift_reg, coin_counter_reg, nmi_reset_reg;

wire        m65_res_n, m65_enable, m65_rdy, m65_irq_n, m65_nmi_n;
wire [7:0]  m65_di;

decocass decocass_inst (
	.clk_sys           (clk_sys),
	.ce_main           (ce_hclk4),
	.reset             (reset),
	.cpu_addr          (cpu_addr),
	.cpu_dout          (cpu_dout),
	.cpu_rw_n          (cpu_rw_n),
	.cpu_sync          (cpu_sync),
	.cpu_we_ram        (cpu_we_ram),
	.cpu_we_charram    (cpu_we_charram),
	.cpu_we_fgvram     (cpu_we_fgvram),
	.cpu_we_colram     (cpu_we_colram),
	.cpu_we_tilram     (cpu_we_tilram),
	.cpu_we_objram     (cpu_we_objram),
	.cpu_we_palram     (cpu_we_palram),
	.cpu_we_e3xx       (cpu_we_e3xx),
	.cpu_we_e4xx       (cpu_we_e4xx),
	.cpu_we_e414       (cpu_we_e414),
	.cpu_we_e5xx       (cpu_we_e5xx),
	.cpu_re_e5xx       (cpu_re_e5xx),
	.cpu_we_e6xx       (cpu_we_e6xx),
	.cpu_we_e7xx       (cpu_we_e7xx),
	.cpu_re_e700       (cpu_re_e700),
	.cpu_re_e701       (cpu_re_e701),
	.sound_data        (sound_data),
	.sound_ack         (sound_ack),
	.e5xx_dongle_q     (e5xx_to_cpu),
	.input_q           (input_q),
	.bios_q            (bios_q),
	.ram_q             (ram_q),
	.charram_q         (charram_q),
	.user3_q           (user3_q),
	.user3_addr_w      (user3_addr),
	.fgvram_q          (fgvram_q),
	.colram_q          (colram_q),
	.tilram_q          (tilram_q),
	.objram_q          (objram_q),
	.palram_q          (palram_q),
	.dsw1              (sw3 | 8'h30),
	.dsw2              (sw2),
	.vblank            (video_vblank),
	.coin_in           (joystick_0[6] | joystick_1[6] | kb_coin1 | kb_coin2),
	.ram_addr_w        (ram_addr_cpu),
	.ram_we_w          (ram_we_cpu),
	.ram_dw            (ram_dw_cpu),
	.charram_addr_w    (charram_addr_cpu),
	.charram_we_p0     (charram_we_p0),
	.charram_we_p1     (charram_we_p1),
	.charram_we_p2     (charram_we_p2),
	.charram_dw        (charram_dw_cpu),
	.fgvram_addr_w     (fgvram_addr_cpu),
	.fgvram_we_w       (fgvram_we_cpu),
	.fgvram_dw         (fgvram_dw_cpu),
	.colram_addr_w     (colram_addr_cpu),
	.colram_we_w       (colram_we_cpu),
	.colram_dw         (colram_dw_cpu),
	.tilram_addr_w     (tilram_addr_cpu),
	.tilram_we_w       (tilram_we_cpu),
	.tilram_dw         (tilram_dw_cpu),
	.objram_addr_w     (objram_addr_cpu),
	.objram_we_w       (objram_we_cpu),
	.objram_dw         (objram_dw_cpu),
	.palram_addr_w     (palram_addr_cpu),
	.palram_we_w       (palram_we_cpu),
	.palram_dw         (palram_dw_cpu),
	.bios_addr_w       (bios_addr_cpu_dec),
	.bios_we_w         (bios_we_cpu_int),
	.bios_dw           (bios_dout_cpu),
	.mode_set_reg      (mode_set_reg),
	.back_h_shift_reg  (back_h_shift_reg),
	.back_vl_shift_reg (back_vl_shift_reg),
	.back_vr_shift_reg (back_vr_shift_reg),
	.part_h_shift_reg  (part_h_shift_reg),
	.part_v_shift_reg  (part_v_shift_reg),
	.color_center_bot_reg (color_center_bot_reg),
	.color_missiles_reg (color_missiles_reg),
	.center_h_shift_space_reg (center_h_shift_space_reg),
	.center_v_shift_reg    (center_v_shift_reg),
	.coin_counter_reg      (coin_counter_reg),
	.nmi_reset_reg         (nmi_reset_reg),
	.hs_access             (hs_pause),
	.hs_addr               (hs_address),
	.hs_din                (hs_data_in),
	.hs_we                 (hs_write_enable),
	.hs_dout               (hs_data_out),
	.t65_res_n             (m65_res_n),
	.t65_enable            (m65_enable),
	.t65_rdy               (m65_rdy),
	.t65_irq_n             (m65_irq_n),
	.t65_nmi_n             (m65_nmi_n),
	.t65_di                (m65_di),
	.t65_a                 (t65_0_o.a),
	.t65_do                (t65_0_o.dout),
	.t65_rw                (t65_0_o.rw),
	.t65_sync              (t65_0_o.sync)
);
assign t65_0_i.res_n  = m65_res_n;
assign t65_0_i.enable = m65_enable;
assign t65_0_i.rdy    = m65_rdy;
assign t65_0_i.irq_n  = m65_irq_n;
assign t65_0_i.nmi_n  = m65_nmi_n;
assign t65_0_i.di     = m65_di;

wire        mcu_cs_n, mcu_rd_n, mcu_wr_n, mcu_a0;
wire [7:0]  mcu_host_din;
wire [7:0]  mcu_p1_out, mcu_p2_out, mcu_p1_in, mcu_p2_in;
wire        mcu_t0, mcu_t1;
wire [7:0]  mcu_host_dout;
wire [7:0]  mcu_host_sts;
wire        mcu_host_dout_oe;
wire        tape_direction;

wire [2:0] fl_sel    = (fl_status > 3'd4) ? 3'd4 : fl_status;
wire       fast_load = (fl_sel != 3'd0) & tape_motor_on;
reg  [2:0] fl_hcnt = 3'd0;
reg [13:0] fl_tdiv = 14'd0;
wire [13:0] fl_tlim = (fl_sel == 3'd1) ? 14'd9999 : (fl_sel == 3'd2) ? 14'd4999 :
                      (fl_sel == 3'd3) ? 14'd2499 : 14'd1249;
wire       fl_hce   = (fl_sel == 3'd1) ? (fl_hcnt == 3'd7) : (fl_sel == 3'd2) ? (fl_hcnt[1:0] == 2'd3) :
                      (fl_sel == 3'd3) ? fl_hcnt[0] : 1'b1;
wire       fl_tce   = (fl_tdiv >= fl_tlim);
always @(posedge clk_sys) begin
	fl_hcnt <= fl_hcnt + 3'd1;
	fl_tdiv <= fl_tce ? 14'd0 : fl_tdiv + 14'd1;
end
wire ce_hclk_mcu = (fast_load ? fl_hce : ce_hclk_raw) & ~pause_cpu;
wire ce_tape_mcu = (fast_load ? fl_tce : ce_tape_raw) & ~pause_cpu;
wire [1:0]  tape_speed_select;
wire        tape_data, tape_clock, tape_bot, tape_eot;

wire [10:0] pmem_addr;
wire [7:0]  pmem_data;
wire [7:0]  dmem_addr;
wire [7:0]  dmem_din;
wire [7:0]  dmem_dout;
wire        dmem_we;

assign rom2_a    = pmem_addr[9:0];
assign pmem_data = rom2_q;
assign pr_i[B_DMEM] = '{a_addr: {9'd0, dmem_addr[6:0]}, a_d: dmem_din, a_we: dmem_we, b_addr: 16'd0, b_d: 8'd0, b_we: 1'b0};
assign dmem_dout    = pr_o[B_DMEM].a_q;

assign upi41_0_i.reset_n = ~reset;
assign upi41_0_i.xtal_en = ce_hclk_mcu;
assign upi41_0_i.en_clk  = upi41_0_o.xtal3;
assign upi41_0_i.cs_n    = mcu_cs_n | pl_active;
assign upi41_0_i.rd_n    = mcu_rd_n;
assign upi41_0_i.wr_n    = mcu_wr_n;
assign upi41_0_i.a0      = mcu_a0;
assign upi41_0_i.db      = mcu_host_din;
assign upi41_0_i.t0      = mcu_t0;
assign upi41_0_i.t1      = mcu_t1;
assign upi41_0_i.p1_in   = mcu_p1_in;
assign upi41_0_i.p2_in   = mcu_p2_in;
assign upi41_0_i.dmem_d  = dmem_dout;
assign upi41_0_i.pmem_d  = pmem_data;
assign mcu_host_dout     = upi41_0_o.db;
assign mcu_host_sts      = upi41_0_o.sts;
assign mcu_host_dout_oe  = upi41_0_o.db_dir;
assign mcu_p1_out        = upi41_0_o.p1;
assign mcu_p2_out        = upi41_0_o.p2;
assign pmem_addr         = upi41_0_o.pmem_a;
assign dmem_addr         = upi41_0_o.dmem_a;
assign dmem_we           = upi41_0_o.dmem_we;
assign dmem_din          = upi41_0_o.dmem_d;

wire [7:0]  dongle_addr_lo;
wire        dongle_re, dongle_we;
wire [7:0]  dongle_dout;
wire [3:0]  dongle_din_low4;
wire [7:0]  dongle_din_full;

mcu_tape_iface mcu_tape_iface_inst (
	.clk_sys              (clk_sys),
	.ce_hclk              (ce_hclk_mcu),
	.ce_hclk1             (ce_hclk1),
	.ce_tape              (ce_tape_mcu),
	.reset                (reset),
	.mcu_p1_in            (mcu_p1_in),
	.mcu_p1_out           (mcu_p1_out),
	.mcu_p2_in            (mcu_p2_in),
	.mcu_p2_out           (mcu_p2_out),
	.mcu_t0               (mcu_t0),
	.mcu_t1               (mcu_t1),
	.mcu_cs_n             (mcu_cs_n),
	.mcu_rd_n             (mcu_rd_n),
	.mcu_wr_n             (mcu_wr_n),
	.mcu_a0               (mcu_a0),
	.mcu_dout             (mcu_host_din),
	.tape_motor_on        (tape_motor_on),
	.tape_direction       (tape_direction),
	.tape_speed_select    (tape_speed_select),
	.tape_data            (tape_data),
	.tape_clock           (tape_clock),
	.tape_bot             (tape_bot),
	.tape_eot             (tape_eot),
	.cpu_e5_re            (cpu_re_e5xx),
	.cpu_e5_we            (cpu_we_e5xx),
	.cpu_addr_lo          (cpu_addr[7:0]),
	.cpu_dout             (cpu_dout),
	.cpu_din              (e5xx_dongle),
	.mcu_host_dout        (mcu_host_dout),
	.mcu_host_dout_oe     (mcu_host_dout_oe),
	.dongle_addr_lo       (dongle_addr_lo),
	.dongle_re            (dongle_re),
	.dongle_we            (dongle_we),
	.dongle_dout          (dongle_dout),
	.dongle_din_low4      (dongle_din_low4)
);

wire [17:0] tape_image_size = image_size_bytes;

wire [7:0]  crc_table_q_addr;
wire [15:0] crc_table_q;
dpram #(.address_width(8), .data_width(16)) crc16_table_bram (   // POOL-EXCEPTION: 16-bit CRC table (pool blocks are 8 bits)
    .clock_a  (clk_sys),
    .enable_a (1'b1),
    .wren_a   (crc_table_we),
    .address_a(crc_table_addr),
    .data_a   (crc_table_data),
    .q_a      (),
    .clock_b  (clk_sys),
    .enable_b (1'b1),
    .wren_b   (1'b0),
    .address_b(crc_table_q_addr),
    .data_b   (16'h0000),
    .q_b      (crc_table_q)
);

wire [17:0] tape_image_addr;
wire [7:0]  tape_image_q = rom4_q;

assign rom4_a = pl_active ? pl_cas_addr : tape_image_addr[15:0];

tape_streamer tape_streamer_inst (
	.clk_sys           (clk_sys),
	.ce_tape           (ce_tape_mcu),
	.reset             (reset),
	.image_addr        (tape_image_addr),
	.image_q           (tape_image_q),
	.image_size_bytes  (tape_image_size),
	.motor_on          (tape_motor_on),
	.direction         (tape_direction),
	.speed_select      (tape_speed_select),
	.crc_addr          (crc_table_q_addr),
	.crc_q             (crc_table_q),
	.tape_data         (tape_data),
	.tape_clock        (tape_clock),
	.tape_bot          (tape_bot),
	.tape_eot          (tape_eot)
);

dongle_mux dongle_mux_inst (
	.clk_sys           (clk_sys),
	.ce_hclk4          (ce_hclk4),
	.reset             (reset),
	.dongle_type       (dongle_type),
	.game_id           (game_id),
	.swap_mode         (swap_mode),
	.cpu_re            (dongle_re),
	.cpu_we            (dongle_we),
	.cpu_addr_lo       (dongle_addr_lo),
	.cpu_dout          (dongle_dout),
	.cpu_din_full      (dongle_din_full),
	.dprom_addr        (dprom_addr),
	.dprom_q           (dprom_q),
	.mcu_dbb_dout      (pl_active ? pl_dbb_dout : mcu_host_dout),
	.mcu_dbb_sts       (pl_active ? pl_dbb_sts : mcu_host_sts),
	.mcu_status_d2     (mcu_p2_out[2]),
	.mcu_status_d0     (mcu_p2_out[0])
);

assign dongle_din_low4 = dongle_din_full[3:0];

assign e5xx_to_cpu = cpu_addr[1] ? (pl_active ? pl_e502 : e5xx_dongle)
                   : dongle_din_full;

wire [7:0] in0, in1, in2;
wire ctower_mode = (dongle_type == 4'd1) && (game_id == 8'd8);
wire [3:0] rsd0, rsd1;
ctl_stick_dirs #(.MODE(0), .THRESH(7'd48)) rstick_p1(.stick(joystick_r_analog_0), .dir(rsd0));
ctl_stick_dirs #(.MODE(0), .THRESH(7'd48)) rstick_p2(.stick(joystick_r_analog_1), .dir(rsd1));
wire [3:0] rstick0 = {rsd0[2] | joystick_0[12], rsd0[3] | joystick_0[13], rsd0[1] | joystick_0[11], rsd0[0] | joystick_0[10]};
wire [3:0] rstick1 = {rsd1[2] | joystick_1[12], rsd1[3] | joystick_1[13], rsd1[1] | joystick_1[11], rsd1[0] | joystick_1[10]};
wire cdsteljn_mode = (dongle_type == 4'd1) && (game_id == 8'd14);
wire [7:0] mahjong_row;
mahjong_panel mahjong_panel_inst (
	.clk_sys (clk_sys),
	.reset   (reset),
	.ps2_key (ps2_key),
	.mux     (coin_counter_reg[3:2]),
	.row     (mahjong_row)
);
assign in0 = cdsteljn_mode ? mahjong_row
           : ctower_mode   ? {joystick_0[2], joystick_0[3], joystick_0[1:0], rstick0}
                           : {2'b00, joystick_0[5:4], joystick_0[2], joystick_0[3], joystick_0[1:0]};
assign in1 = cdsteljn_mode ? mahjong_row
           : ctower_mode   ? {joystick_1[2], joystick_1[3], joystick_1[1:0], rstick1}
                           : {2'b00, joystick_1[5:4], joystick_1[2], joystick_1[3], joystick_1[1:0]};
assign in2 = {~(joystick_0[6] | kb_coin1), ~(joystick_1[6] | kb_coin2), 1'b0,
              joystick_0[8]|joystick_1[8]|joystick_1[7]|kb_start2, joystick_0[7]|kb_start1, 3'b000};

inputs inputs_inst (
	.clk_sys          (clk_sys),
	.ce_hclk1         (ce_hclk1),
	.reset            (reset),
	.cpu_addr_lo      (cpu_addr[7:0]),
	.cpu_we_e6xx      (cpu_we_e6xx),
	.cpu_rw_n         (cpu_rw_n),
	.in0              (in0),
	.in1              (in1),
	.in2              (in2),
	.dsw1             (sw3),
	.dsw2             (sw2),
	.vblank           (video_vblank),
	.mcu_p2_low4      (mcu_p2_out[3:0]),
	.input_q          (input_q)
);

watchdog watchdog_inst (
	.clk_sys          (clk_sys),
	.ce_hclk1         (ce_hclk1),
	.reset            (reset),
	.vblank_pulse     (~video_vblank),
	.wd_count_w       (cpu_we_e3xx && cpu_addr[0] == 1'b0),
	.wd_flip_w        (cpu_we_e3xx && cpu_addr[0] == 1'b1),
	.cpu_dout         (cpu_dout),
	.dsw1             (sw3),
	.wd_reset         (),
	.flip_screen      ()
);

wire [7:0]  audio_cpu_addr, audio_cpu_dout, audio_cpu_din;
wire        audio_cpu_rw_n;
wire        ay1_data_we, ay1_addr_we, ay2_data_we, ay2_addr_we;
wire [7:0]  ay_data_out;

wire        audio_to_main_we;
wire        audio_from_main_re;
wire [7:0]  audio_to_main_data;
wire [7:0]  main_to_audio_data;
wire        audio_irq;
reg         audio_nmi_enable_reg;

wire        a65_res_n, a65_enable, a65_rdy, a65_irq_n, a65_nmi_n;
wire [7:0]  a65_di;
wire [11:0] aram_a;
wire  [7:0] aram_d;
wire        aram_we;
assign pr_i[B_ARAM] = '{a_addr: {4'd0, aram_a}, a_d: aram_d, a_we: aram_we, b_addr: 16'd0, b_d: 8'd0, b_we: 1'b0};

audio_cpu audio_cpu_inst (
	.clk_sys      (clk_sys),
	.ce_audio     (ce_audio),
	.reset        (reset),
	.ce_pix       (ce_pix),
	.audio_irq_set(audio_irq),
	.hcounter_eq_0(hcnt == 9'h000),
	.vcounter     (vcnt),
	.ram_a        (aram_a),
	.ram_d        (aram_d),
	.ram_we       (aram_we),
	.ram_q        (pr_o[B_ARAM].a_q),
	.rom_a        (rom1_a),
	.rom_q        (rom1_q),
	.ay1_data_we  (ay1_data_we),
	.ay1_addr_we  (ay1_addr_we),
	.ay2_data_we  (ay2_data_we),
	.ay2_addr_we  (ay2_addr_we),
	.ay_data_out  (ay_data_out),
	.sound_to_main_we(audio_to_main_we),
	.sound_from_main_re(audio_from_main_re),
	.sound_to_main(audio_to_main_data),
	.sound_from_main(main_to_audio_data),
	.audio_nmi_master_enable(audio_nmi_enable_reg),
	.t65_res_n    (a65_res_n),
	.t65_enable   (a65_enable),
	.t65_rdy      (a65_rdy),
	.t65_irq_n    (a65_irq_n),
	.t65_nmi_n    (a65_nmi_n),
	.t65_di       (a65_di),
	.t65_a        (t65_1_o.a),
	.t65_do       (t65_1_o.dout),
	.t65_rw       (t65_1_o.rw),
	.t65_sync     (t65_1_o.sync)
);
assign t65_1_i.res_n  = a65_res_n;
assign t65_1_i.enable = a65_enable;
assign t65_1_i.rdy    = a65_rdy;
assign t65_1_i.irq_n  = a65_irq_n;
assign t65_1_i.nmi_n  = a65_nmi_n;
assign t65_1_i.di     = a65_di;

wire cpu_we_e416 = (cpu_addr == 16'hE416 && !cpu_rw_n && ce_hclk4);

always @(posedge clk_sys) begin
	if (reset)
		audio_nmi_enable_reg <= 1'b0;
	else if (cpu_we_e416)
		audio_nmi_enable_reg <= cpu_dout[0];
end

sound_latches sound_latches_inst (
	.clk_sys       (clk_sys),
	.reset         (reset),
	.ce_main       (ce_hclk1),
	.main_we_e414  (cpu_we_e414),
	.main_re_e700  (cpu_re_e700),
	.main_re_e701  (cpu_re_e701),
	.main_dout     (cpu_dout),
	.main_din_e700 (sound_data),
	.main_din_e701 (sound_ack),
	.ce_audio      (ce_audio),
	.audio_we_c000 (audio_to_main_we),
	.audio_re_a000 (audio_from_main_re),
	.audio_dout    (audio_to_main_data),
	.audio_din_a000(main_to_audio_data),
	.audio_irq     (audio_irq)
);

wire        ay1_rst_n, ay1_ce, ay1_cs_n, ay1_wr_n, ay2_rst_n, ay2_ce, ay2_cs_n, ay2_wr_n;
wire  [3:0] ay1_addr, ay2_addr;
wire  [7:0] ay1_din, ay2_din;

ay8910_pair ay8910_pair_inst (
	.clk_sys      (clk_sys),
	.ce_hclk2     (ce_hclk2),
	.ce_audio     (ce_audio),
	.reset        (reset),
	.ay1_data_we  (ay1_data_we),
	.ay1_addr_we  (ay1_addr_we),
	.ay2_data_we  (ay2_data_we),
	.ay2_addr_we  (ay2_addr_we),
	.audio_dout   (ay_data_out),
	.sound_out    ({ay_right, ay_left}),
	.ay1_rst_n    (ay1_rst_n),
	.ay1_ce       (ay1_ce),
	.ay1_addr     (ay1_addr),
	.ay1_cs_n     (ay1_cs_n),
	.ay1_wr_n     (ay1_wr_n),
	.ay1_din      (ay1_din),
	.ay1_sound    (jt49_0_o.sound),
	.ay2_rst_n    (ay2_rst_n),
	.ay2_ce       (ay2_ce),
	.ay2_addr     (ay2_addr),
	.ay2_cs_n     (ay2_cs_n),
	.ay2_wr_n     (ay2_wr_n),
	.ay2_din      (ay2_din),
	.ay2_sound    (jt49_1_o.sound)
);
assign jt49_0_i.rst_n = ay1_rst_n;
assign jt49_0_i.ce    = ay1_ce;
assign jt49_0_i.addr  = ay1_addr;
assign jt49_0_i.cs_n  = ay1_cs_n;
assign jt49_0_i.wr_n  = ay1_wr_n;
assign jt49_0_i.din   = ay1_din;
assign jt49_1_i.rst_n = ay2_rst_n;
assign jt49_1_i.ce    = ay2_ce;
assign jt49_1_i.addr  = ay2_addr;
assign jt49_1_i.cs_n  = ay2_cs_n;
assign jt49_1_i.wr_n  = ay2_wr_n;
assign jt49_1_i.din   = ay2_din;

wire [4:0]  fg_pen, spr_pen, mis_pen;
wire [5:0]  bg_pen;
wire        fg_opaque, bg_opaque, spr_opaque, mis_opaque;

video_timing video_timing_inst (
	.clk_sys      (clk_sys),
	.ce_pix       (ce_pix),
	.reset        (reset),
	.hsync        (video_hsync),
	.vsync        (video_vsync),
	.hblank       (video_hblank),
	.vblank       (video_vblank),
	.hcnt         (hcnt),
	.vcnt         (vcnt),
	.vsync_pulse  ()
);

wire [8:0] vcnt_v   = crt_flip ? (9'd254 - vcnt) : vcnt;

wire [9:0]  fg_wr_addr = cpu_addr[11] ? {cpu_addr[4:0], cpu_addr[9:5]} : cpu_addr[9:0];
wire [9:0]  fg_tile_ra;
wire [12:0] fg_char_ra;
video_fg video_fg_inst (
	.clk_sys           (clk_sys),
	.ce_pix            (ce_pix),
	.hcnt              (hcnt),
	.vcnt              (vcnt_v),
	.tile_ra           (fg_tile_ra),
	.q_fg              (pr_o[B_V_FGV].b_q),
	.q_col             (pr_o[B_V_COL].b_q),
	.char_ra           (fg_char_ra),
	.q_ch0             (pr_o[B_V_CH0].b_q),
	.q_ch1             (pr_o[B_V_CH1].b_q),
	.q_ch2             (pr_o[B_V_CH2].b_q),
	.color_center_bot  (color_center_bot_reg),
	.fg_pen            (fg_pen),
	.fg_opaque         (fg_opaque)
);
assign pr_i[B_V_FGV] = '{a_addr: {6'd0, fg_wr_addr}, a_d: cpu_dout, a_we: cpu_we_fgvram, b_addr: {6'd0, fg_tile_ra}, b_d: 8'd0, b_we: 1'b0};
assign pr_i[B_V_COL] = '{a_addr: {6'd0, fg_wr_addr}, a_d: cpu_dout, a_we: cpu_we_colram, b_addr: {6'd0, fg_tile_ra}, b_d: 8'd0, b_we: 1'b0};
assign pr_i[B_V_CH0] = '{a_addr: {3'd0, cpu_addr[12:0]}, a_d: cpu_dout, a_we: charram_we_p0, b_addr: {3'd0, fg_char_ra}, b_d: 8'd0, b_we: 1'b0};
assign pr_i[B_V_CH1] = '{a_addr: {3'd0, cpu_addr[12:0]}, a_d: cpu_dout, a_we: charram_we_p1, b_addr: {3'd0, fg_char_ra}, b_d: 8'd0, b_we: 1'b0};
assign pr_i[B_V_CH2] = '{a_addr: {3'd0, cpu_addr[12:0]}, a_d: cpu_dout, a_we: charram_we_p2, b_addr: {3'd0, fg_char_ra}, b_d: 8'd0, b_we: 1'b0};

wire [9:0] bg_tc_ra, bg_plane_ra;
wire       bg_we_lo = cpu_we_tilram && (cpu_addr[10:0] < 11'h400);
wire       bg_we_hi = cpu_we_tilram && (cpu_addr[10:0] >= 11'h400);
video_bg video_bg_inst (
	.clk_sys           (clk_sys),
	.ce_pix            (ce_pix),
	.hcnt              (hcnt),
	.vcnt              (vcnt_v),
	.back_h_shift      (back_h_shift_reg),
	.back_vl_shift     (back_vl_shift_reg),
	.back_vr_shift     (back_vr_shift_reg),
	.mode_set          (mode_set_reg),
	.color_center_bot  (color_center_bot_reg),
	.tc_ra             (bg_tc_ra),
	.q_tc              (pr_o[B_V_BGT].b_q),
	.plane_ra          (bg_plane_ra),
	.q_p0              (pr_o[B_V_BG0].b_q),
	.q_p12             (pr_o[B_V_BG12].b_q),
	.bg_pen            (bg_pen),
	.bg_opaque         (bg_opaque)
);
assign pr_i[B_V_BGT]  = '{a_addr: {6'd0, cpu_addr[9:0]}, a_d: cpu_dout, a_we: bg_we_lo, b_addr: {6'd0, bg_tc_ra}, b_d: 8'd0, b_we: 1'b0};
assign pr_i[B_V_BG0]  = '{a_addr: {6'd0, cpu_addr[9:0]}, a_d: cpu_dout, a_we: bg_we_lo, b_addr: {6'd0, bg_plane_ra}, b_d: 8'd0, b_we: 1'b0};
assign pr_i[B_V_BG12] = '{a_addr: {6'd0, cpu_addr[9:0]}, a_d: cpu_dout, a_we: bg_we_hi, b_addr: {6'd0, bg_plane_ra}, b_d: 8'd0, b_we: 1'b0};

// the descriptor mirrors must be true copies of fgvideoram / colorram: same mirror swizzle on the write address
wire [9:0] spr_desc_wr_addr = cpu_addr[11] ? {cpu_addr[4:0], cpu_addr[9:5]} : cpu_addr[9:0];
wire [9:0]  spr_desc_ra;
wire [12:0] spr_gfx_ra;
video_sprites video_sprites_inst (
	.clk_sys           (clk_sys),
	.ce_pix            (ce_pix),
	.hcnt              (hcnt),
	.vcnt              (vcnt_v),
	.color_center_bot  (color_center_bot_reg),
	.desc_ra           (spr_desc_ra),
	.desc_q            (pr_o[B_V_SDESC].b_q),
	.gfx_ra            (spr_gfx_ra),
	.gfx_q0            (pr_o[B_V_SG0].b_q),
	.gfx_q1            (pr_o[B_V_SG1].b_q),
	.gfx_q2            (pr_o[B_V_SG2].b_q),
	.spr_pen           (spr_pen),
	.spr_priority      (spr_opaque)
);
assign pr_i[B_V_SDESC] = '{a_addr: {6'd0, spr_desc_wr_addr}, a_d: cpu_dout, a_we: cpu_we_fgvram, b_addr: {6'd0, spr_desc_ra}, b_d: 8'd0, b_we: 1'b0};
assign pr_i[B_V_SG0] = '{a_addr: {3'd0, cpu_addr[12:0]}, a_d: cpu_dout, a_we: charram_we_p0, b_addr: {3'd0, spr_gfx_ra}, b_d: 8'd0, b_we: 1'b0};
assign pr_i[B_V_SG1] = '{a_addr: {3'd0, cpu_addr[12:0]}, a_d: cpu_dout, a_we: charram_we_p1, b_addr: {3'd0, spr_gfx_ra}, b_d: 8'd0, b_we: 1'b0};
assign pr_i[B_V_SG2] = '{a_addr: {3'd0, cpu_addr[12:0]}, a_d: cpu_dout, a_we: charram_we_p2, b_addr: {3'd0, spr_gfx_ra}, b_d: 8'd0, b_we: 1'b0};

wire [9:0] mis_desc_wr_addr = cpu_addr[11] ? {cpu_addr[4:0], cpu_addr[9:5]} : cpu_addr[9:0];
wire [9:0] mis_desc_ra;
video_missiles video_missiles_inst (
	.clk_sys           (clk_sys),
	.ce_pix            (ce_pix),
	.hcnt              (hcnt),
	.vcnt              (vcnt_v),
	.color_missiles    (color_missiles_reg),
	.desc_ra           (mis_desc_ra),
	.desc_q            (pr_o[B_V_MIS].b_q),
	.mis_pen           (mis_pen),
	.mis_priority      (mis_opaque)
);
assign pr_i[B_V_MIS] = '{a_addr: {6'd0, mis_desc_wr_addr}, a_d: cpu_dout, a_we: cpu_we_colram, b_addr: {6'd0, mis_desc_ra}, b_d: 8'd0, b_we: 1'b0};

wire [3:0] core_r_hi, core_g_hi, core_b_hi;
wire [5:0] mixer_pen;
wire       mixer_modulate;
wire [3:0] crt_r, crt_g, crt_b;
wire [7:0] core_r = {crt_r, crt_r};
wire [7:0] core_g = {crt_g, crt_g};
wire [7:0] core_b = {crt_b, crt_b};

wire [7:0] pal_ra;
video_palette video_palette_inst (
	.clk_sys      (clk_sys),
	.ce_pix       (ce_pix),
	.pal_ra       (pal_ra),
	.pal_q        (pr_o[B_V_PAL].b_q),
	.pen          (mixer_pen),
	.prom_index   (5'h00),
	.red          (core_r_hi),
	.grn          (core_g_hi),
	.blu          (core_b_hi)
);
assign pr_i[B_V_PAL] = '{a_addr: {8'd0, 3'b000, cpu_addr[4:0] ^ 5'b10000}, a_d: ~cpu_dout, a_we: cpu_we_palram, b_addr: {8'd0, pal_ra}, b_d: 8'd0, b_we: 1'b0};

deco_video_mixer deco_video_mixer_inst (
	.clk_sys                (clk_sys),
	.ce_pix                 (ce_pix),
	.fg_pen                 (fg_pen),
	.fg_opaque              (fg_opaque),
	.bg_pen                 (bg_pen),
	.bg_opaque              (bg_opaque),
	.spr_pen                (spr_pen),
	.spr_opaque             (spr_opaque),
	.mis_pen                (mis_pen),
	.mis_opaque             (mis_opaque),
	.mode_set               (mode_set_reg),
	.color_center_bot       (color_center_bot_reg),
	.color_missiles         (color_missiles_reg),
	.back_h_shift           (back_h_shift_reg),
	.back_vl_shift          (back_vl_shift_reg),
	.back_vr_shift          (back_vr_shift_reg),
	.part_h_shift           (part_h_shift_reg),
	.part_v_shift           (part_v_shift_reg),
	.center_h_shift_space   (center_h_shift_space_reg),
	.center_v_shift         (center_v_shift_reg),
	.hcnt                   (hcnt),
	.vcnt                   (vcnt_v),
	.out_pen                (mixer_pen),
	.out_pen_b4_modulate    (mixer_modulate)
);

reg hs_game_run_r = 1'b0;
always @(posedge clk_sys) begin
	if (reset)                                                hs_game_run_r <= 1'b0;
	else if (cpu_sync && ce_hclk4 && cpu_addr < 16'hF000)     hs_game_run_r <= 1'b1;
end
assign hs_game_run = hs_game_run_r;

plaid_load plaid_load_inst (
	.clk_sys       (clk_sys),
	.reset         (reset),
	.sel           ((fl_status == 3'd5) && (dongle_type != 4'd7) && (dongle_type != 4'd8)),
	.game_run      (hs_game_run_r),
	.restart       (pl_restart),
	.active        (pl_active),
	.ce_main_fast  (pl_ce_main),
	.ce_audio_fast (pl_ce_audio),
	.cpu_re        (cpu_re_e5xx),
	.cpu_we        (cpu_we_e5xx),
	.cpu_addr_lo   (cpu_addr[7:0]),
	.cpu_dout      (cpu_dout),
	.cas_addr      (pl_cas_addr),
	.cas_q         (tape_image_q),
	.dbb_dout      (pl_dbb_dout),
	.dbb_sts       (pl_dbb_sts),
	.e502          (pl_e502)
);

localparam [4:0] VID_HV_DELAY = 5'd4;

reg [15:0] hbl_sr, vbl_sr, hs_sr, vs_sr;
always @(posedge clk_sys) if (ce_pix) begin
	hbl_sr <= {hbl_sr[14:0], video_hblank};
	vbl_sr <= {vbl_sr[14:0], video_vblank};
	hs_sr  <= {hs_sr[14:0],  video_hsync};
	vs_sr  <= {vs_sr[14:0],  video_vsync};
end
assign video_hblank_d = hbl_sr[VID_HV_DELAY-1];
assign video_vblank_d = vbl_sr[VID_HV_DELAY-1];
assign video_hsync_d = hs_sr[VID_HV_DELAY-1];
assign video_vsync_d = vs_sr[VID_HV_DELAY-1];

video_crtflip video_crtflip_inst (
	.clk_sys (clk_sys),
	.ce_pix  (ce_pix),
	.en      (crt_flip),
	.hblank  (video_hblank_d),
	.rgb_in  ({core_r_hi, core_g_hi, core_b_hi}),
	.rgb_out ({crt_r, crt_g, crt_b})
);

assign rgb_core = {core_r, core_g, core_b};

endmodule
