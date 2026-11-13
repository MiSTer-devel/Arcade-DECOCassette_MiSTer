//  Based on MAME decocass.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module decocass (
    input  wire        clk_sys,
    input  wire        ce_main,
    input  wire        reset,

    output wire [15:0] cpu_addr,
    output wire [7:0]  cpu_dout,
    output wire        cpu_rw_n,          // 1=read, 0=write
    output wire        cpu_sync,

    output wire        cpu_we_ram,
    output wire        cpu_we_charram,
    output wire        cpu_we_fgvram,
    output wire        cpu_we_colram,
    output wire        cpu_we_tilram,
    output wire        cpu_we_objram,
    output wire        cpu_we_palram,

    output wire        cpu_we_e3xx,
    output wire        cpu_we_e4xx,
    output wire        cpu_we_e414,
    output wire        cpu_we_e5xx,
    output wire        cpu_re_e5xx,
    output wire        cpu_we_e6xx,
    output wire        cpu_we_e7xx,
    output wire        cpu_re_e700,
    output wire        cpu_re_e701,

    input  wire [7:0]  sound_data,
    input  wire [7:0]  sound_ack,
    input  wire [7:0]  e5xx_dongle_q,
    input  wire [7:0]  input_q,
    input  wire [7:0]  bios_q,
    input  wire [7:0]  dsw1,
    input  wire [7:0]  dsw2,
    input  wire        vblank,            // vblank status (active high in vblank) — DSW1[7]

    input  wire        coin_in,

    input  wire [7:0]  ram_q,
    input  wire [7:0]  charram_q,
    input  wire [7:0]  user3_q,
    input  wire [7:0]  fgvram_q,
    input  wire [7:0]  colram_q,
    input  wire [7:0]  tilram_q,
    input  wire [7:0]  objram_q,
    input  wire [7:0]  palram_q,

    output wire [14:0] ram_addr_w,
    output wire        ram_we_w,
    output wire [7:0]  ram_dw,

    output wire [14:0] charram_addr_w,
    output wire        charram_we_p0,
    output wire        charram_we_p1,
    output wire        charram_we_p2,
    output wire [7:0]  charram_dw,

    output wire [15:0] user3_addr_w,

    output wire [9:0]  fgvram_addr_w,
    output wire        fgvram_we_w,
    output wire [7:0]  fgvram_dw,

    output wire [9:0]  colram_addr_w,
    output wire        colram_we_w,
    output wire [7:0]  colram_dw,

    output wire [10:0] tilram_addr_w,
    output wire        tilram_we_w,
    output wire [7:0]  tilram_dw,

    output wire [9:0]  objram_addr_w,
    output wire        objram_we_w,
    output wire [7:0]  objram_dw,

    output wire [7:0]  palram_addr_w,
    output wire        palram_we_w,
    output wire [7:0]  palram_dw,

    output wire [11:0] bios_addr_w,
    output wire        bios_we_w,
    output wire [7:0]  bios_dw,

    output wire [7:0]  mode_set_reg,
    output wire [7:0]  color_missiles_reg,
    output wire [7:0]  back_h_shift_reg,
    output wire [7:0]  back_vl_shift_reg,
    output wire [7:0]  back_vr_shift_reg,
    output wire [7:0]  part_h_shift_reg,
    output wire [7:0]  part_v_shift_reg,
    output wire [7:0]  color_center_bot_reg,
    output wire [7:0]  center_h_shift_space_reg,
    output wire [7:0]  center_v_shift_reg,
    output wire [7:0]  coin_counter_reg,
    output wire [7:0]  nmi_reset_reg,

    input  wire        hs_access,
    input  wire [15:0] hs_addr,
    input  wire [7:0]  hs_din,
    input  wire        hs_we,
    output wire [7:0]  hs_dout,

    output wire        t65_res_n,
    output wire        t65_enable,
    output wire        t65_rdy,
    output wire        t65_irq_n,
    output wire        t65_nmi_n,
    output wire [7:0]  t65_di,
    input  wire [15:0] t65_a,
    input  wire [7:0]  t65_do,
    input  wire        t65_rw,
    input  wire        t65_sync
);

    wire [15:0] cpu_addr_core = t65_a;
    wire [7:0]  cpu_dout_core = t65_do;
    wire        cpu_rw_n_core = t65_rw;
    wire        cpu_sync_int  = t65_sync;
    reg cpu_nmi_req;
    wire [7:0]  cpu_din;

    assign t65_res_n  = ~reset;
    assign t65_enable = ce_main;
    assign t65_nmi_n  = ~cpu_nmi_req;
    assign t65_irq_n  = 1'b1;
    assign t65_rdy    = 1'b1;

    deco222 cpu (
        .sync    (t65_sync),
        .di      (cpu_din),
        .di_eff  (t65_di)
    );

    wire [15:0] cpu_addr_int = hs_access ? hs_addr : cpu_addr_core;
    wire [7:0]  cpu_dout_int = hs_access ? hs_din  : cpu_dout_core;
    wire        cpu_rw_n_int = hs_access ? ~hs_we  : cpu_rw_n_core;
    wire        ram_wr_ce    = hs_access ? hs_we   : ce_main;

    reg coin_d;
    reg vblank_d;

    always @(posedge clk_sys) begin
        if (reset) begin
            coin_d      <= 1'b0;
            cpu_nmi_req <= 1'b0;
            vblank_d    <= 1'b0;
        end else begin
            coin_d   <= coin_in;
            vblank_d <= vblank;
            if (coin_in && !coin_d)
                cpu_nmi_req <= 1'b1;
            else if (cpu_addr_int == 16'hE417 && !cpu_rw_n_int && ce_main)
                cpu_nmi_req <= 1'b0;
        end
    end

    assign cpu_addr  = cpu_addr_int;
    assign cpu_dout  = cpu_dout_int;
    assign cpu_rw_n  = cpu_rw_n_int;
    assign cpu_sync  = cpu_sync_int;

    wire sel_ram      = (cpu_addr_int <  16'h6000);
    wire sel_charram  = (cpu_addr_int >= 16'h6000) && (cpu_addr_int < 16'hC000);
    wire sel_fgvram   = (cpu_addr_int[15:10] == 6'b110000);
    wire sel_colram   = (cpu_addr_int[15:10] == 6'b110001);
    wire sel_fgvram_m = (cpu_addr_int[15:10] == 6'b110010);
    wire sel_colram_m = (cpu_addr_int[15:10] == 6'b110011);
    wire sel_tilram   = (cpu_addr_int[15:11] == 5'b11010);
    wire sel_objram   = (cpu_addr_int[15:10] == 6'b110110);
    wire sel_palram   = (cpu_addr_int[15:8]  == 8'hE0);
    wire sel_e3       = (cpu_addr_int[15:8]  == 8'hE3);
    wire sel_e4       = (cpu_addr_int[15:8]  == 8'hE4);
    wire sel_e5       = (cpu_addr_int[15:8]  == 8'hE5);
    wire sel_e6       = (cpu_addr_int[15:8]  == 8'hE6);
    wire sel_e7       = (cpu_addr_int[15:8]  == 8'hE7);
    wire sel_rom      = (cpu_addr_int[15:12] == 4'hF);

    function [9:0] swiz;
        input [9:0] a;
        swiz = { a[4:0], a[9:5] };
    endfunction

    assign ram_addr_w   = cpu_addr_int[14:0];
    assign ram_dw       = cpu_dout_int;
    assign ram_we_w     = (sel_ram && !cpu_rw_n_int && ram_wr_ce);

    wire   sel_charram_p0 = sel_charram && (cpu_addr_int[15:13] == 3'b011);
    wire   sel_charram_p1 = sel_charram && (cpu_addr_int[15:13] == 3'b100);
    wire   sel_charram_p2 = sel_charram && (cpu_addr_int[15:13] == 3'b101);

    assign charram_addr_w = cpu_addr_int - 16'h6000;
    assign charram_dw     = cpu_dout_int;
    assign charram_we_p0  = (sel_charram_p0 && !cpu_rw_n_int && ram_wr_ce);
    assign charram_we_p1  = (sel_charram_p1 && !cpu_rw_n_int && ram_wr_ce);
    assign charram_we_p2  = (sel_charram_p2 && !cpu_rw_n_int && ram_wr_ce);

    wire [9:0] fgvram_addr_eff = sel_fgvram_m ? swiz(cpu_addr_int[9:0]) : cpu_addr_int[9:0];
    assign fgvram_addr_w = fgvram_addr_eff;
    assign fgvram_dw     = cpu_dout_int;
    assign fgvram_we_w   = ((sel_fgvram || sel_fgvram_m) && !cpu_rw_n_int && ram_wr_ce);

    wire [9:0] colram_addr_eff = sel_colram_m ? swiz(cpu_addr_int[9:0]) : cpu_addr_int[9:0];
    assign colram_addr_w = colram_addr_eff;
    assign colram_dw     = cpu_dout_int;
    assign colram_we_w   = ((sel_colram || sel_colram_m) && !cpu_rw_n_int && ram_wr_ce);

    assign tilram_addr_w = cpu_addr_int[10:0];
    assign tilram_dw     = cpu_dout_int;
    assign tilram_we_w   = (sel_tilram && !cpu_rw_n_int && ram_wr_ce);

    assign objram_addr_w = cpu_addr_int[9:0];
    assign objram_dw     = cpu_dout_int;
    assign objram_we_w   = (sel_objram && !cpu_rw_n_int && ram_wr_ce);

    assign palram_addr_w = cpu_addr_int[7:0];
    assign palram_dw     = cpu_dout_int;
    assign palram_we_w   = (sel_palram && !cpu_rw_n_int && ram_wr_ce);

    assign bios_addr_w = cpu_addr_int[11:0];
    assign bios_dw     = cpu_dout_int;
    assign bios_we_w   = (sel_rom && !cpu_rw_n_int && ce_main);

    assign cpu_we_ram    = ram_we_w;
    assign cpu_we_charram = charram_we_p0 | charram_we_p1 | charram_we_p2;
    assign cpu_we_fgvram = fgvram_we_w;
    assign cpu_we_colram = colram_we_w;
    assign cpu_we_tilram = tilram_we_w;
    assign cpu_we_objram = objram_we_w;
    assign cpu_we_palram = palram_we_w;
    assign cpu_we_e3xx   = (sel_e3 && !cpu_rw_n_int && ce_main);
    assign cpu_we_e4xx   = (sel_e4 && !cpu_rw_n_int && ce_main);
    assign cpu_we_e414   = (cpu_addr_int == 16'hE414 && !cpu_rw_n_int && ce_main);
    assign cpu_we_e5xx   = (sel_e5 && !cpu_rw_n_int && ce_main);
    assign cpu_we_e6xx   = (sel_e6 && !cpu_rw_n_int && ce_main);
    assign cpu_we_e7xx   = (sel_e7 && !cpu_rw_n_int && ce_main);

    assign cpu_re_e5xx   = (sel_e5                       &&  cpu_rw_n_int && ce_main);
    assign cpu_re_e700   = (cpu_addr_int == 16'hE700     &&  cpu_rw_n_int && ce_main);
    assign cpu_re_e701   = (cpu_addr_int == 16'hE701     &&  cpu_rw_n_int && ce_main);

    reg [7:0] mode_set;
    reg [7:0] back_h_shift;
    reg [7:0] back_vl_shift;
    reg [7:0] back_vr_shift;
    reg [7:0] part_h_shift;
    reg [7:0] part_v_shift;
    reg [7:0] color_center_bot;
    reg [7:0] center_h_shift_space;
    reg [7:0] center_v_shift;
    reg [7:0] coin_counter;
    reg [7:0] nmi_reset;
    reg [7:0] color_missiles;
    reg [1:0] de0091_bank;

    always @(posedge clk_sys) begin
        if (reset) begin
            mode_set             <= 8'h00;
            back_h_shift         <= 8'h00;
            back_vl_shift        <= 8'h00;
            back_vr_shift        <= 8'h00;
            part_h_shift         <= 8'h00;
            part_v_shift         <= 8'h00;
            color_center_bot     <= 8'h00;
            center_h_shift_space <= 8'h00;
            center_v_shift       <= 8'h00;
            coin_counter         <= 8'h00;
            nmi_reset            <= 8'h00;
            color_missiles       <= 8'h00;
            de0091_bank          <= 2'd0;
        end else if (ce_main && !cpu_rw_n_int) begin
            if (cpu_addr_int == 16'hE302) color_missiles       <= cpu_dout_int & 8'h77;
            if (cpu_addr_int == 16'hE402) mode_set             <= cpu_dout_int;
            if (cpu_addr_int == 16'hE403) back_h_shift         <= cpu_dout_int;
            if (cpu_addr_int == 16'hE404) back_vl_shift        <= cpu_dout_int;
            if (cpu_addr_int == 16'hE405) back_vr_shift        <= cpu_dout_int;
            if (cpu_addr_int == 16'hE406) part_h_shift         <= cpu_dout_int;
            if (cpu_addr_int == 16'hE407) part_v_shift         <= cpu_dout_int;
            if (cpu_addr_int == 16'hE410) color_center_bot     <= cpu_dout_int;
            if (cpu_addr_int == 16'hE411) center_h_shift_space <= cpu_dout_int;
            if (cpu_addr_int == 16'hE412) center_v_shift       <= cpu_dout_int;
            if (cpu_addr_int == 16'hE413) coin_counter         <= cpu_dout_int;
            if (cpu_addr_int == 16'hE417) nmi_reset            <= cpu_dout_int;
            if (cpu_addr_int == 16'hE900 && cpu_dout_int[1:0] != 2'b11)
                de0091_bank <= cpu_dout_int[1:0];
        end
    end

    assign user3_addr_w = (cpu_addr_int - 16'h6000) + (de0091_bank == 2'd2 ? 16'h5000 : 16'h0000);

    assign mode_set_reg            = mode_set;
    assign back_h_shift_reg        = back_h_shift;
    assign back_vl_shift_reg       = back_vl_shift;
    assign back_vr_shift_reg       = back_vr_shift;
    assign part_h_shift_reg        = part_h_shift;
    assign part_v_shift_reg        = part_v_shift;
    assign color_center_bot_reg    = color_center_bot;
    assign color_missiles_reg      = color_missiles;
    assign center_h_shift_space_reg = center_h_shift_space;
    assign center_v_shift_reg      = center_v_shift;
    assign coin_counter_reg        = coin_counter;
    assign nmi_reset_reg           = nmi_reset;

    reg [7:0] cpu_din_mux;

    always @* begin
        casez (cpu_addr_int)
            16'b00??_????_????_????,
            16'b0100_????_????_????,
            16'b0101_????_????_????:        cpu_din_mux = ram_q;

            16'b011?_????_????_????,
            16'b1000_????_????_????,
            16'b1001_????_????_????,
            16'b1010_????_????_????:        cpu_din_mux = (de0091_bank != 2'd0) ? user3_q : charram_q;

            // $B000-$BFFF is never banked (the overlay ROM only covers $6000-$AFFF)
            16'b1011_????_????_????:        cpu_din_mux = charram_q;

            16'b1100_00??_????_????:        cpu_din_mux = fgvram_q;

            16'b1100_01??_????_????:        cpu_din_mux = colram_q;

            16'b1100_10??_????_????:        cpu_din_mux = fgvram_q;

            16'b1100_11??_????_????:        cpu_din_mux = colram_q;

            16'b1101_0???_????_????:        cpu_din_mux = tilram_q;

            16'b1101_10??_????_????:        cpu_din_mux = objram_q;

            16'b1110_0000_????_????:        cpu_din_mux = palram_q;

            16'hE300:                       cpu_din_mux = {vblank, dsw1[6:0]};

            16'hE301:                       cpu_din_mux = dsw2;

            16'hE414:                       cpu_din_mux = 8'hC0;

            16'hE700:                       cpu_din_mux = sound_data;

            16'hE701:                       cpu_din_mux = sound_ack;

            16'b1110_0101_????_????:        cpu_din_mux = e5xx_dongle_q;

            16'b1110_0110_????_????:        cpu_din_mux = input_q;

            16'b1111_????_????_????:        cpu_din_mux = bios_q;

            default:                        cpu_din_mux = 8'hFF;
        endcase
    end

    assign cpu_din = cpu_din_mux;
    reg [2:0] hs_sel_r;
    always @(posedge clk_sys) begin
        casez (hs_addr)
            16'b00??_????_????_????,
            16'b0100_????_????_????,
            16'b0101_????_????_????:        hs_sel_r <= 3'd0;
            16'b011?_????_????_????,
            16'b100?_????_????_????,
            16'b1010_????_????_????,
            16'b1011_????_????_????:        hs_sel_r <= 3'd1;
            16'b1100_?0??_????_????:        hs_sel_r <= 3'd2;
            16'b1100_?1??_????_????:        hs_sel_r <= 3'd3;
            16'b1101_0???_????_????:        hs_sel_r <= 3'd4;
            16'b1101_10??_????_????:        hs_sel_r <= 3'd5;
            16'b1110_0000_????_????:        hs_sel_r <= 3'd6;
            default:                        hs_sel_r <= 3'd7;
        endcase
    end
    assign hs_dout = (hs_sel_r == 3'd0) ? ram_q     :
                     (hs_sel_r == 3'd1) ? charram_q :
                     (hs_sel_r == 3'd2) ? fgvram_q  :
                     (hs_sel_r == 3'd3) ? colram_q  :
                     (hs_sel_r == 3'd4) ? tilram_q  :
                     (hs_sel_r == 3'd5) ? objram_q  :
                     (hs_sel_r == 3'd6) ? palram_q  : 8'hFF;

endmodule
