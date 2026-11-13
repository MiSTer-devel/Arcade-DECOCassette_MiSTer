//  Based on MAME decocass_m.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

`timescale 1 ps / 1 ps

module dongle_nodong (
    input  wire [7:0]  mcu_dbb_dout,
    input  wire [7:0]  mcu_dbb_sts,
    input  wire [7:0]  cpu_addr_lo,
    output wire [7:0]  cpu_din_full
);
    assign cpu_din_full = cpu_addr_lo[0] ? mcu_dbb_sts : mcu_dbb_dout;
endmodule
