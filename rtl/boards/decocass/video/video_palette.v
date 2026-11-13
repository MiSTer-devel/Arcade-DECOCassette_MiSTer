//  Based on MAME decocass_v.cpp, decocass.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module video_palette (
    input  wire        clk_sys,
    input  wire        ce_pix,

    output wire [7:0]  pal_ra,
    input  wire [7:0]  pal_q,

    input  wire [5:0]  pen,
    input  wire [4:0]  prom_index,

    output reg  [3:0]  red,
    output reg  [3:0]  grn,
    output reg  [3:0]  blu
);

    wire [7:0] palram_dout = pal_q;

    wire [4:0] pal_rd_idx = pen[5] ? {pen[4], pen[3], pen[1], pen[2], pen[0]} : pen[4:0];

    reg [7:0] pal_ra_h;
    always @(posedge clk_sys) if (ce_pix) pal_ra_h <= {3'b000, pal_rd_idx};
    assign pal_ra = pal_ra_h;

    wire [2:0] r_raw = palram_dout[2:0];
    wire [2:0] g_raw = palram_dout[5:3];
    wire [1:0] b_raw = palram_dout[7:6];

    always @(posedge clk_sys) begin
        if (ce_pix) begin
            red <= {r_raw, r_raw[2]};
            grn <= {g_raw, g_raw[2]};
            blu <= {b_raw, b_raw};
        end
    end

endmodule
