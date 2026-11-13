//  Based on MAME decocass.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module video_timing (
    input  wire        clk_sys,
    input  wire        ce_pix,
    input  wire        reset,

    output reg  [8:0]  hcnt,
    output reg  [8:0]  vcnt,

    output reg         hblank,
    output reg         vblank,

    output reg         hsync,
    output reg         vsync,

    output reg         vsync_pulse
);

    always @(posedge clk_sys) begin
        if (reset) begin
            hcnt <= 9'd0;
        end else if (ce_pix) begin
            if (hcnt == 9'd383) begin
                hcnt <= 9'd0;
            end else begin
                hcnt <= hcnt + 9'd1;
            end
        end
    end

    always @(posedge clk_sys) begin
        if (reset) begin
            vcnt <= 9'd0;
        end else if (ce_pix && hcnt == 9'd383) begin
            if (vcnt == 9'd271) begin
                vcnt <= 9'd0;
            end else begin
                vcnt <= vcnt + 9'd1;
            end
        end
    end

    always @(posedge clk_sys) begin
        if (ce_pix) begin
            hblank <= (hcnt > 9'd257) | (hcnt < 9'd2);
        end
    end

    always @(posedge clk_sys) begin
        if (ce_pix) begin
            vblank <= (vcnt < 9'd8) | (vcnt > 9'd247);
        end
    end

    always @(posedge clk_sys) begin
        if (ce_pix) begin
            hsync <= (hcnt >= 9'd280) & (hcnt < 9'd312);
        end
    end

    always @(posedge clk_sys) begin
        if (ce_pix) begin
            vsync <= (vcnt >= 9'd252) & (vcnt < 9'd256);
        end
    end

    always @(posedge clk_sys) begin
        if (reset) begin
            vsync_pulse <= 1'b0;
        end else if (ce_pix) begin
            vsync_pulse <= (vcnt == 9'd251) & (hcnt == 9'd383);
        end else begin
            vsync_pulse <= 1'b0;
        end
    end

endmodule
