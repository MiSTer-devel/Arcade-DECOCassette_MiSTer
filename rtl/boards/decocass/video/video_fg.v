//  Based on MAME decocass.cpp, decocass_v.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module video_fg (
    input  wire        clk_sys,
    input  wire        ce_pix,

    input  wire [8:0]  hcnt,
    input  wire [8:0]  vcnt,

    output wire [9:0]  tile_ra,
    input  wire [7:0]  q_fg,
    input  wire [7:0]  q_col,
    output wire [12:0] char_ra,
    input  wire [7:0]  q_ch0,
    input  wire [7:0]  q_ch1,
    input  wire [7:0]  q_ch2,

    input  wire [7:0]  color_center_bot,

    output reg  [4:0]  fg_pen,
    output wire        fg_opaque
);

    wire [8:0] hcnt_fg = hcnt + 9'd8;
    wire [4:0] htile = hcnt_fg[7:3];
    wire [4:0] vtile = vcnt[7:3];
    wire [2:0] vline = vcnt[2:0];

    reg offmap_r1, offmap_r2;
    always @(posedge clk_sys) if (ce_pix) begin
        offmap_r1 <= hcnt_fg[8];
        offmap_r2 <= offmap_r1;
    end

    reg [9:0] tile_ra_h;
    always @(posedge clk_sys) if (ce_pix) tile_ra_h <= {~htile, vtile};
    assign tile_ra = tile_ra_h;

    wire [7:0] tile_code8 = q_fg;

    wire [7:0] attr = q_col;

    wire [9:0] tile_code = {attr[1:0], tile_code8};

    wire [7:0] char_p0 = q_ch0, char_p1 = q_ch1, char_p2 = q_ch2;
    wire [12:0] char_read_addr = {tile_code, vline};

    reg [12:0] char_ra_h;
    always @(posedge clk_sys) if (ce_pix) char_ra_h <= char_read_addr;
    assign char_ra = char_ra_h;

    reg [7:0] pat_p0_sr, pat_p1_sr, pat_p2_sr;
    wire [2:0] pen;
    assign pen = { pat_p2_sr[7], pat_p1_sr[7], pat_p0_sr[7] };

    always @(posedge clk_sys) begin
        if (ce_pix) begin
            if (hcnt[2:0] == 3'b000) begin
                pat_p0_sr <= offmap_r2 ? 8'h00 : char_p0;
                pat_p1_sr <= offmap_r2 ? 8'h00 : char_p1;
                pat_p2_sr <= offmap_r2 ? 8'h00 : char_p2;
            end else begin
                pat_p0_sr <= {pat_p0_sr[6:0], 1'b0};
                pat_p1_sr <= {pat_p1_sr[6:0], 1'b0};
                pat_p2_sr <= {pat_p2_sr[6:0], 1'b0};
            end
        end
    end

    reg [4:0] fg_pen_s0, fg_pen_s1;
    always @(posedge clk_sys) begin
        if (ce_pix) begin
            fg_pen_s0 <= { 1'b0, color_center_bot[0], pen };
            fg_pen_s1 <= fg_pen_s0;
            fg_pen    <= fg_pen_s1;
        end
    end

    assign fg_opaque = (fg_pen[2:0] != 3'b000);

endmodule
