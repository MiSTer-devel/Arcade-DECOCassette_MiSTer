//  Based on MAME deco222.cpp (David Haywood, BSD-3-Clause)

module deco222 (
    input  wire        sync,
    input  wire [7:0]  di,
    output wire [7:0]  di_eff
);

    assign di_eff = sync
        ? { di[7], di[5], di[6], di[4:0] }
        : di;

endmodule
