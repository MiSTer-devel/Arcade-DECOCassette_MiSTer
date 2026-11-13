//  Based on MAME decocass_m.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module inputs (
    input  wire        clk_sys,
    input  wire        ce_hclk1,
    input  wire        reset,

    input  wire [7:0]  cpu_addr_lo,         // cpu_addr[7:0] from decocass.v
    input  wire        cpu_we_e6xx,
    input  wire        cpu_rw_n,            // 1=read, 0=write

    input  wire [7:0]  in0,                 // P1: R/L/U/D, B1, B2, unused[7:6]
    input  wire [7:0]  in1,                 // P2 cocktail: R/L/U/D, B1, B2, unused[7:6]
    input  wire [7:0]  in2,                 // bit[3]=START1, bit[4]=START2, bit[6]=COIN2, bit[7]=COIN1
    input  wire [7:0]  dsw1,                // bit[7]=VBLANK, bit[6]=CABINET, bits[5:0]=DIP switches
    input  wire [7:0]  dsw2,
    input  wire        vblank,

    input  wire [3:0]  mcu_p2_low4,

    output reg  [7:0]  input_q
);

    wire [2:0] offset = cpu_addr_lo[2:0];

    always @* begin
        case (offset)
            3'b000:  input_q = in0;
            3'b001:  input_q = in1;
            3'b010:  input_q = in2;
            3'b011:  input_q = 8'hFF;
            3'b100,
            3'b101,
            3'b110:  input_q = 8'h00;
            3'b111:  input_q = 8'h00;
            default: input_q = 8'hFF;
        endcase
    end

endmodule
