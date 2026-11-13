//  Based on MAME decocass_v.cpp, decocass.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

`timescale 1 ps / 1 ps

module video_sprites (
    input  wire        clk_sys,
    input  wire        ce_pix,

    input  wire [8:0]  hcnt,
    input  wire [8:0]  vcnt,

    input  wire [7:0]  color_center_bot,

    output wire [9:0]  desc_ra,
    input  wire [7:0]  desc_q,
    output wire [12:0] gfx_ra,
    input  wire [7:0]  gfx_q0,
    input  wire [7:0]  gfx_q1,
    input  wire [7:0]  gfx_q2,

    output reg  [4:0]  spr_pen,
    output reg         spr_priority
);

    localparam [7:0] SPR_X_ADJ = 8'd0;
    localparam [7:0] SPR_Y_ADJ = 8'd0;

    reg  [9:0] dsc_addr;
    wire [7:0] dsc_q = desc_q;
    assign desc_ra = dsc_addr;

    reg        s_en  [0:7];
    reg        s_fx  [0:7];
    reg        s_fy  [0:7];
    reg  [7:0] s_code[0:7];
    reg  [7:0] s_sx  [0:7];
    reg  [7:0] s_sy  [0:7];

    reg  [4:0] scan, scan_d;
    wire [2:0] scan_spr  = scan[4:2];
    wire [1:0] scan_byte = scan[1:0];
    wire [9:0] scan_addr = 10'h380 - {scan_spr, 7'b0} + {scan_byte, 5'b0};

    always @(posedge clk_sys) begin
        if (ce_pix) begin
            case (scan_d[1:0])
                2'd0: begin
                    s_en[scan_d[4:2]] <= dsc_q[0];
                    s_fy[scan_d[4:2]] <= dsc_q[1];
                    s_fx[scan_d[4:2]] <= dsc_q[2];
                end
                2'd1: s_code[scan_d[4:2]] <= dsc_q;
                2'd2: s_sy[scan_d[4:2]]   <= 8'd240 - dsc_q + SPR_Y_ADJ;
                2'd3: s_sx[scan_d[4:2]]   <= 8'd240 - dsc_q + SPR_X_ADJ;
            endcase
            dsc_addr <= scan_addr;
            scan_d   <= scan;
            scan     <= scan + 1'b1;
        end
    end

    integer k;
    reg        win_valid;
    reg  [7:0] win_code;
    reg        win_fx, win_fy;
    reg  [3:0] win_col;
    reg  [3:0] win_row;
    reg  [7:0] dx, dy;
    always @(*) begin
        win_valid = 1'b0; win_code = 8'd0; win_fx = 1'b0; win_fy = 1'b0;
        win_col = 4'd0; win_row = 4'd0;
        for (k = 0; k < 8; k = k + 1) begin
            dx = hcnt[7:0] - s_sx[k];
            dy = vcnt[7:0] - s_sy[k];
            if (s_en[k] && (dx < 8'd16) && (dy < 8'd16)) begin
                win_valid = 1'b1;
                win_code  = s_code[k];
                win_fx    = s_fx[k];
                win_fy    = s_fy[k];
                win_col   = dx[3:0];
                win_row   = dy[3:0];
            end
        end
    end

    wire [3:0] gcol = win_fx ? (4'd15 - win_col) : win_col;
    wire [3:0] grow = win_fy ? (4'd15 - win_row) : win_row;

    wire [12:0] gfx_addr = {win_code, ~gcol[3], grow};

    wire [7:0] gp0 = gfx_q0, gp1 = gfx_q1, gp2 = gfx_q2;
    reg [12:0] gfx_ra_h;
    always @(posedge clk_sys) if (ce_pix) gfx_ra_h <= gfx_addr;
    assign gfx_ra = gfx_ra_h;

    reg  [2:0] bit_r;
    reg        valid_r;
    always @(posedge clk_sys) begin
        if (ce_pix) begin
            bit_r   <= 3'd7 - gcol[2:0];
            valid_r <= win_valid;
        end
    end

    wire [2:0] pen3 = { gp2[bit_r], gp1[bit_r], gp0[bit_r] };

    always @(posedge clk_sys) begin
        if (ce_pix) begin
            if (valid_r && (pen3 != 3'b000)) begin
                spr_pen      <= {1'b0, color_center_bot[1], pen3};
                spr_priority <= 1'b1;
            end else begin
                spr_pen      <= 5'b00000;
                spr_priority <= 1'b0;
            end
        end
    end

endmodule
