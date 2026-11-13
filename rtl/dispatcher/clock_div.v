//  Based on MAME decocass.cpp, decocass_tape.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module clock_div (
    input  wire clk_sys,
    input  wire reset,
    output wire ce_hclk,
    output wire ce_hclk1,
    output wire ce_hclk2,
    output wire ce_hclk4,
    output wire ce_audio,
    output wire ce_tape,
    output wire ce_pix
);

    reg [6:0] hcnt;
    always @(posedge clk_sys) begin
        if (reset) hcnt <= 7'd0;
        else       hcnt <= hcnt + 7'd1;
    end

    assign ce_hclk  = (hcnt[3:0] == 4'b1111);
    assign ce_hclk1 = (hcnt[4:0] == 5'b11111);
    assign ce_hclk2 = (hcnt[5:0] == 6'b111111);
    assign ce_hclk4 = (hcnt[6:0] == 7'b1111111);

    reg [3:0] adiv;
    always @(posedge clk_sys) begin
        if (reset)
            adiv <= 4'd0;
        else if (ce_hclk)
            adiv <= (adiv == 4'd11) ? 4'd0 : (adiv + 4'd1);
    end
    assign ce_audio = ce_hclk & (adiv == 4'd11);

    reg [14:0] tdiv;
    always @(posedge clk_sys) begin
        if (reset)
            tdiv <= 15'd0;
        else
            tdiv <= (tdiv == 15'd19999) ? 15'd0 : (tdiv + 15'd1);
    end
    assign ce_tape = (tdiv == 15'd19999);

    assign ce_pix = ce_hclk;

endmodule
