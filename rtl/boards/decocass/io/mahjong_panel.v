
module mahjong_panel (
    input  wire        clk_sys,
    input  wire        reset,
    input  wire [10:0] ps2_key,
    input  wire [1:0]  mux,
    output reg  [7:0]  row
);
    reg        old_toggle;
    reg [13:0] tile;
    reg  [4:0] call;

    wire       pressed = ps2_key[9];
    wire       ext     = ps2_key[8];
    wire [7:0] code    = ps2_key[7:0];

    always @(posedge clk_sys) begin
        old_toggle <= ps2_key[10];
        if (reset) begin
            tile <= 14'd0;
            call <= 5'd0;
        end else if (old_toggle != ps2_key[10]) begin
            case (code)
                8'h1C: if (!ext) tile[0]  <= pressed;
                8'h32: if (!ext) tile[1]  <= pressed;
                8'h21: if (!ext) tile[2]  <= pressed;
                8'h23: if (!ext) tile[3]  <= pressed;
                8'h24: if (!ext) tile[4]  <= pressed;
                8'h2B: if (!ext) tile[5]  <= pressed;
                8'h34: if (!ext) tile[6]  <= pressed;
                8'h33: if (!ext) tile[7]  <= pressed;
                8'h43: if (!ext) tile[8]  <= pressed;
                8'h3B: if (!ext) tile[9]  <= pressed;
                8'h42: if (!ext) tile[10] <= pressed;
                8'h4B: if (!ext) tile[11] <= pressed;
                8'h3A: if (!ext) tile[12] <= pressed;
                8'h31: if (!ext) tile[13] <= pressed;
                8'h29: if (!ext) call[0]  <= pressed;
                8'h11:           call[1]  <= pressed;
                8'h14:           call[2]  <= pressed;
                8'h12: if (!ext) call[3]  <= pressed;
                8'h1A: if (!ext) call[4]  <= pressed;
                default: ;
            endcase
        end
    end

    always @(*) begin
        case (mux)
            2'd1:    row = {1'b0, tile[6:0]};
            2'd2:    row = {1'b0, tile[13:7]};
            2'd3:    row = {3'b000, call};
            default: row = 8'h00;
        endcase
    end

    initial begin
        old_toggle = 1'b0;
        tile       = 14'd0;
        call       = 5'd0;
    end

endmodule
