//  Based on MAME decocass_m.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

`timescale 1 ps / 1 ps

module dongle_darksoft (
    input  wire        clk_sys,
    input  wire        ce_hclk4,
    input  wire        reset,

    input  wire        cpu_re,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_addr_lo,
    input  wire [7:0]  cpu_dout,
    output reg  [7:0]  cpu_din_full,

    output wire [19:0] prom_addr,
    input  wire [7:0]  prom_q,

    input  wire [7:0]  mcu_dbb_dout,
    input  wire [7:0]  mcu_dbb_sts
);

    reg [19:0] address;
    assign prom_addr = address;

    wire off0 = (cpu_addr_lo == 8'h00);
    wire off1 = (cpu_addr_lo == 8'h01);

    always @(*) begin
        if (off0 || off1) cpu_din_full = prom_q;
        else              cpu_din_full = 8'hFF;
    end

    always @(posedge clk_sys) begin
        if (reset) begin
            address <= 20'd0;
        end else if (ce_hclk4) begin
            if (cpu_we && (off0 || off1))
                address <= {12'd0, cpu_dout};
            else if (cpu_re && off0)
                address <= address + 20'd1;
            else if (cpu_re && off1)
                address <= address + 20'h00100;
        end
    end

endmodule
