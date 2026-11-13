//  Based on MAME decocass_v.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

`timescale 1 ps / 1 ps

module video_missiles (
    input  wire        clk_sys,
    input  wire        ce_pix,

    input  wire [8:0]  hcnt,
    input  wire [8:0]  vcnt,

    input  wire [7:0]  color_missiles,

    output wire [9:0]  desc_ra,
    input  wire [7:0]  desc_q,

    output reg  [4:0]  mis_pen,
    output reg         mis_priority
);

    localparam [7:0] MIS_X_ADJ = 8'd0;
    localparam [7:0] MIS_Y_ADJ = 8'd0;

    reg  [9:0] dsc_addr;
    wire [7:0] dsc_q = desc_q;
    assign desc_ra = dsc_addr;

    reg  [7:0] sx_lo [0:7];
    reg  [7:0] sy_lo [0:7];
    reg  [7:0] sx_up [0:7];
    reg  [7:0] sy_up [0:7];

    reg  [4:0] scan, scan_d;
    wire [2:0] scan_pair = scan[4:2];
    wire [1:0] scan_byte = scan[1:0];
    wire [9:0] scan_addr = {scan_pair, scan_byte, 5'b00000};

    always @(posedge clk_sys) begin
        if (ce_pix) begin
            case (scan_d[1:0])
                2'd0: sy_lo[scan_d[4:2]] <= 8'd254 - dsc_q + MIS_Y_ADJ;
                2'd1: sy_up[scan_d[4:2]] <= 8'd254 - dsc_q + MIS_Y_ADJ;
                2'd2: sx_lo[scan_d[4:2]] <= 8'd255 - dsc_q + MIS_X_ADJ;
                2'd3: sx_up[scan_d[4:2]] <= 8'd255 - dsc_q + MIS_X_ADJ;
            endcase
            dsc_addr <= scan_addr;
            scan_d   <= scan;
            scan     <= scan + 1'b1;
        end
    end

    integer k;
    reg       hit_lo, hit_up;
    reg [7:0] dxl, dyl, dxu, dyu;
    always @(*) begin
        hit_lo = 1'b0; hit_up = 1'b0;
        for (k = 0; k < 8; k = k + 1) begin
            dxl = hcnt[7:0] - sx_lo[k];  dyl = vcnt[7:0] - sy_lo[k];
            if ((dxl < 8'd4) && (dyl == 8'd0)) hit_lo = 1'b1;
            dxu = hcnt[7:0] - sx_up[k];  dyu = vcnt[7:0] - sy_up[k];
            if ((dxu < 8'd4) && (dyu == 8'd0)) hit_up = 1'b1;
        end
    end

    wire [4:0] pen_lo = {2'b01, color_missiles[2:0]};
    wire [4:0] pen_up = {2'b01, color_missiles[6:4]};

    reg hit_lo_1, hit_up_1;
    always @(posedge clk_sys) begin
        if (ce_pix) begin
            hit_lo_1 <= hit_lo;
            hit_up_1 <= hit_up;
            if (hit_up_1) begin
                mis_pen      <= pen_up;
                mis_priority <= 1'b1;
            end else if (hit_lo_1) begin
                mis_pen      <= pen_lo;
                mis_priority <= 1'b1;
            end else begin
                mis_pen      <= 5'b00000;
                mis_priority <= 1'b0;
            end
        end
    end

endmodule
