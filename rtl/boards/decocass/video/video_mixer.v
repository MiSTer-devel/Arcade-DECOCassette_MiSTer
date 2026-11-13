//  Based on MAME decocass_v.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module deco_video_mixer (
    input  wire        clk_sys,
    input  wire        ce_pix,

    input  wire [4:0]  fg_pen,   input  wire fg_opaque,
    input  wire [5:0]  bg_pen,   input  wire bg_opaque,
    input  wire [4:0]  spr_pen,  input  wire spr_opaque,
    input  wire [4:0]  mis_pen,  input  wire mis_opaque,

    input  wire [7:0]  mode_set,            // E402: bits [3], [5], [6], [7] used
    input  wire [7:0]  color_center_bot,
    input  wire [7:0]  color_missiles,

    input  wire [7:0]  back_h_shift,
    input  wire [7:0]  back_vl_shift,
    input  wire [7:0]  back_vr_shift,
    input  wire [7:0]  part_h_shift,
    input  wire [7:0]  part_v_shift,
    input  wire [7:0]  center_h_shift_space,
    input  wire [7:0]  center_v_shift,

    input  wire [8:0]  hcnt,
    input  wire [8:0]  vcnt,

    output reg  [5:0]  out_pen,
    output reg         out_pen_b4_modulate  // XOR pen[4] if headlight active
);

    wire bkg_ena = mode_set[3];
    wire cross_on = mode_set[5];
    wire tunnel_active = mode_set[6];
    wire part_h_enable = mode_set[7];

    localparam [5:0] BG_FILL = 6'd8;

    wire edge_valid = bg_opaque;
    wire center_valid = 1'b0;

    wire special_priority_active = 1'b0;
    wire headlight_pixel = 1'b0;
    wire headlight_b4_flip = 1'b0;

    reg [5:0] pen_next;
    reg b4_modulate_next;

    always @(*) begin
        pen_next = BG_FILL;
        b4_modulate_next = 1'b0;

        if (bkg_ena && edge_valid) begin
            pen_next = bg_pen;
            b4_modulate_next = 1'b0;
        end

        if (center_valid) begin
            pen_next = {2'b00, color_center_bot[2:0]};
            b4_modulate_next = 1'b0;
        end else if (!cross_on && bkg_ena && edge_valid) begin
            pen_next = bg_pen;
            b4_modulate_next = 1'b0;
        end

        if (fg_opaque && (fg_pen != 5'b00000)) begin
            pen_next = {1'b0, fg_pen};
            b4_modulate_next = 1'b0;
        end

        if (spr_opaque && (spr_pen != 5'b00000)) begin
            pen_next = {1'b0, spr_pen};
            b4_modulate_next = 1'b0;
        end

        if (mis_opaque && (mis_pen != 5'b00000)) begin
            pen_next = {1'b0, mis_pen};
            b4_modulate_next = 1'b0;
        end

        if (special_priority_active && headlight_pixel) begin
            b4_modulate_next = headlight_b4_flip;
        end
    end

    always @(posedge clk_sys) begin
        if (ce_pix) begin
            out_pen <= pen_next;
            out_pen_b4_modulate <= b4_modulate_next;
        end
    end

endmodule
