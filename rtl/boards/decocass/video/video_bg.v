//  Based on MAME decocass_v.cpp, decocass.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module video_bg (
    input  wire        clk_sys,
    input  wire        ce_pix,

    input  wire [8:0]  hcnt,
    input  wire [8:0]  vcnt,

    input  wire [7:0]  back_h_shift,
    input  wire [7:0]  back_vl_shift,
    input  wire [7:0]  back_vr_shift,
    input  wire [7:0]  mode_set,

    input  wire [7:0]  color_center_bot,

    output wire [9:0]  tc_ra,
    input  wire [7:0]  q_tc,
    output wire [9:0]  plane_ra,
    input  wire [7:0]  q_p0,
    input  wire [7:0]  q_p12,

    output reg  [5:0]  bg_pen,
    output reg         bg_opaque
);

    wire        bank        = mode_set[2];
    wire [9:0]  scrolly_l   = {2'b0, back_vl_shift} + (bank ? 10'd256 : 10'd0);
    wire [9:0]  scrolly_r   = (10'd256 - {2'b0, back_vr_shift}) + (bank ? 10'd0 : 10'd256);
    // the L/R split is on native screen-Y (vcnt); rotation is handled downstream, do not re-axis it
    wire        half_bottom = (vcnt >= 9'd128);
    wire [9:0]  scrolly     = half_bottom ? scrolly_r : scrolly_l;
    wire [9:0]  srcline     = ({1'b0, vcnt} + scrolly) & 10'h1ff;

    wire [9:0]  scrollx = 10'd256 - {2'b0, back_h_shift};
    wire [9:0]  xsum    = {1'b0, hcnt} + scrollx;
    wire [9:0]  srccol  =
        (mode_set[1:0] == 2'b00) ? {2'b0, xsum[7:0]}             :
        (mode_set[1:0] == 2'b01) ? ((xsum + 10'h100) & 10'h1ff)  :
        (mode_set[1:0] == 2'b10) ? ({2'b0, xsum[7:0]} + 10'h100) :
                                   (xsum & 10'h1ff);

    wire [4:0]  tile_col = srccol[8:4];
    wire [4:0]  tile_row = srcline[8:4];
    wire [3:0]  pix_x    = srccol[3:0];
    wire [3:0]  pix_y    = srcline[3:0];

    wire [9:0] col_base = (tile_col[4] ? 10'h100 : 10'h000) + (10'h078 - {3'b0, tile_col[3:0], 3'b0});
    wire [9:0] row_off  = (tile_row[4] ? 10'h200 : 10'h000)
                        + (tile_row[3] ? (10'h08f - {6'b0, tile_row[3:0]}) : {6'b0, tile_row[3:0]});
    wire [9:0] tile_index = col_base + row_off;

    wire [7:0] tilecode_byte = q_tc;
    reg [9:0] tc_ra_h;
    always @(posedge clk_sys) if (ce_pix) tc_ra_h <= tile_index;
    assign tc_ra = tc_ra_h;

    wire [3:0] eff_pix_y  = half_bottom ? (4'd15 - pix_y) : pix_y;
    wire       blank_comb = tile_index[7] ^ half_bottom;

    reg [3:0] pixA_x, pixA_y;
    reg       blankA;
    always @(posedge clk_sys) begin
        if (ce_pix) begin
            pixA_x <= pix_x;
            pixA_y <= eff_pix_y;
            blankA <= blank_comb;
        end
    end

    reg [3:0] s1_tile_code;
    reg [3:0] s1_pix_x, s1_pix_y;
    reg       s1_blank;
    always @(posedge clk_sys) begin
        if (ce_pix) begin
            s1_tile_code <= tilecode_byte[7:4];
            s1_pix_x     <= pixA_x;
            s1_pix_y     <= pixA_y;
            s1_blank     <= blankA;
        end
    end

    wire [9:0] plane0_addr = {s1_tile_code[3:0], 6'b0} + {6'b0, s1_pix_y[3:0]} + {4'b0, (2'd3 - s1_pix_x[3:2]), 4'b0};
    wire [7:0] plane0_byte = q_p0;
    reg [9:0] plane_ra_h;
    always @(posedge clk_sys) if (ce_pix) plane_ra_h <= plane0_addr;
    assign plane_ra = plane_ra_h;

    wire [7:0] plane12_byte = q_p12;

    reg [1:0] s2_pix_x_lo;
    reg       s2_blank;
    always @(posedge clk_sys) begin
        if (ce_pix) begin
            s2_pix_x_lo <= s1_pix_x[1:0];
            s2_blank    <= s1_blank;
        end
    end

    wire [2:0] bg_xlo = {1'b0, s2_pix_x_lo};
    wire p0 = plane0_byte [3'd3 - bg_xlo];
    wire p1 = plane12_byte[3'd7 - bg_xlo];
    wire p2 = plane12_byte[3'd3 - bg_xlo];

    wire [2:0] pen = {p2, p1, p0};

    always @(posedge clk_sys) begin
        if (ce_pix) begin
            bg_pen    <= {(color_center_bot[7] ? 3'b101 : 3'b001), pen};
            bg_opaque <= (pen != 3'b000) & ~s2_blank;
        end
    end

endmodule
