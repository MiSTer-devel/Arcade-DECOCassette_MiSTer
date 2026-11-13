
module video_crtflip (
    input  wire        clk_sys,
    input  wire        ce_pix,
    input  wire        en,
    input  wire        hblank,
    input  wire [11:0] rgb_in,
    output wire [11:0] rgb_out
);

reg  [11:0] mem [0:511];             // POOL-EXCEPTION: 12-bit line buffer, two 256-pixel lines (pool blocks are 8 bits)
reg  [7:0]  x = 8'd0;
reg         sel = 1'b0, hbl_r = 1'b1;
reg  [11:0] q;

always @(posedge clk_sys) begin
	if (ce_pix) begin
		hbl_r <= hblank;
		if (hblank) x <= 8'd0;
		else begin
			mem[{sel, x}] <= rgb_in;
			x <= x + 8'd1;
		end
		if (hblank && !hbl_r) sel <= ~sel;
	end
	q <= mem[{~sel, ~x}];
end

assign rgb_out = en ? q : rgb_in;

endmodule
