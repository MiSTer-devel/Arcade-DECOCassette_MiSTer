//  Based on MAME decocass_tape.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module plaid_load (
    input  wire        clk_sys,
    input  wire        reset,
    input  wire        sel,
    input  wire        game_run,
    output reg         restart = 1'b0,
    output wire        active,

    output wire        ce_main_fast,
    output wire        ce_audio_fast,

    input  wire        cpu_re,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_addr_lo,
    input  wire [7:0]  cpu_dout,

    output wire [15:0] cas_addr,
    input  wire [7:0]  cas_q,

    output reg  [7:0]  dbb_dout = 8'h00,
    output wire [7:0]  dbb_sts,
    output wire [7:0]  e502
);

localparam [15:0] CMD_DLY    = 16'd16384;
localparam [15:0] PARAM_DLY  = 16'd64;
localparam [15:0] SETTLE_DLY = 16'd128;
localparam [15:0] BLKEND_DLY = 16'd1024;

localparam [2:0] S_IDLE = 3'd0, S_CMD = 3'd1, S_WAITPARAM = 3'd2, S_PARAM = 3'd3,
                 S_FETCH = 3'd4, S_SETTLE = 3'd5, S_READY = 3'd6, S_BLKEND = 3'd7;

reg        mode = 1'b0;
reg [15:0] restart_cnt = 16'd0;
always @(posedge clk_sys) begin
	if (reset) mode <= sel;
	if (restart_cnt != 16'd0) begin
		restart_cnt <= restart_cnt - 16'd1;
		restart     <= (restart_cnt != 16'd1);
	end else if (!reset && !game_run && sel != mode) begin
		restart_cnt <= 16'hFFFF;
		restart     <= 1'b1;
	end
end
assign active = mode & ~game_run;

reg [2:0] div8  = 3'd0;
reg [3:0] div12 = 4'd0;
always @(posedge clk_sys) begin
	div8  <= div8 + 3'd1;
	div12 <= (div12 == 4'd11) ? 4'd0 : div12 + 4'd1;
end
assign ce_main_fast  = (div8 == 3'd7);
assign ce_audio_fast = (div12 == 4'd11);

reg  [2:0]  st = S_IDLE;
reg  [7:0]  cmd = 8'h00;
reg  [7:0]  blk = 8'h00;
reg  [8:0]  k = 9'd0;
reg  [15:0] dly = 16'd0;
reg         obf = 1'b0, ibf = 1'b0, f0 = 1'b0, busy = 1'b0, req_n = 1'b1, at_bot = 1'b1;

wire wr_cmd  = cpu_we && !cpu_addr_lo[1] &&  cpu_addr_lo[0];
wire wr_data = cpu_we && !cpu_addr_lo[1] && !cpu_addr_lo[0];
wire rd_data = cpu_re && !cpu_addr_lo[1] && !cpu_addr_lo[0];

assign cas_addr = {blk, k[7:0]};
assign dbb_sts  = {4'b0000, 1'b0, f0, ibf, obf};
assign e502     = {1'b0, 1'b1, 1'b1, at_bot, 1'b1, 1'b1, busy, req_n};

always @(posedge clk_sys) begin
	if (reset) begin
		st <= S_IDLE; blk <= 8'h00; k <= 9'd0; dly <= 16'd0; dbb_dout <= 8'h00;
		obf <= 1'b0; ibf <= 1'b0; f0 <= 1'b0; busy <= 1'b0; req_n <= 1'b1; at_bot <= 1'b1;
	end else begin
		if (dly != 16'd0) dly <= dly - 16'd1;

		if (wr_cmd) begin
			cmd <= cpu_dout; ibf <= 1'b1; busy <= 1'b1; obf <= 1'b0; dly <= CMD_DLY; st <= S_CMD;
		end else begin
			case (st)
			S_CMD: if (dly == 16'd0) begin
				ibf <= 1'b0;
				case (cmd)
				8'h28:   begin f0 <= 1'b1; req_n <= 1'b0; st <= S_WAITPARAM; end
				8'h29:   begin blk <= 8'h00; at_bot <= 1'b1; busy <= 1'b0; st <= S_IDLE; end
				8'h2F:   begin at_bot <= 1'b0; busy <= 1'b0; st <= S_IDLE; end
				default: begin busy <= 1'b0; st <= S_IDLE; end
				endcase
			end
			S_WAITPARAM: if (wr_data) begin ibf <= 1'b1; dly <= PARAM_DLY; st <= S_PARAM; end
			S_PARAM: if (dly == 16'd0) begin
				ibf <= 1'b0; req_n <= 1'b1; at_bot <= 1'b0; k <= 9'd0; dly <= 16'd3; st <= S_FETCH;
			end
			S_FETCH: if (dly == 16'd0) begin
				dbb_dout <= cas_q; dly <= SETTLE_DLY; st <= S_SETTLE;
			end
			S_SETTLE: if (dly == 16'd0) begin obf <= 1'b1; st <= S_READY; end
			S_READY: if (rd_data) begin
				obf <= 1'b0;
				if (k == 9'd255) begin dly <= BLKEND_DLY; st <= S_BLKEND; end
				else begin k <= k + 9'd1; dly <= 16'd3; st <= S_FETCH; end
			end
			S_BLKEND: if (dly == 16'd0) begin
				f0 <= 1'b0; busy <= 1'b0; blk <= blk + 8'h01; k <= 9'd0; st <= S_IDLE;
			end
			default: ;
			endcase
		end
	end
end

endmodule
