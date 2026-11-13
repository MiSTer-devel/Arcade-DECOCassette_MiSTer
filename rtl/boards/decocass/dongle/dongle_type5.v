//  Based on MAME decocass_m.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

`timescale 1 ps / 1 ps

module dongle_type5 (
    input  wire        clk_sys,
    input  wire        ce_hclk4,
    input  wire        reset,

    input  wire        cpu_re,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_addr_lo,
    input  wire [7:0]  cpu_dout,
    input  wire [7:0]  mcu_dbb_dout,
    input  wire [7:0]  mcu_dbb_sts,
    output reg  [7:0]  cpu_din_full
);

    reg m_type5_latch;

    always @(posedge clk_sys) begin
        if (reset) begin
            m_type5_latch <= 1'b0;
        end
        else if (ce_hclk4 && cpu_we) begin
            if (cpu_addr_lo[0] == 1'b1) begin
                if ((cpu_dout[7:4] == 4'hC)) begin
                    m_type5_latch <= 1'b1;
                end
            end
        end
    end

    always @(*) begin
        if (cpu_addr_lo[0] == 1'b1) begin
            cpu_din_full = mcu_dbb_sts;
        end else begin
            if (m_type5_latch) begin
                cpu_din_full = 8'h55;
            end else begin
                cpu_din_full = mcu_dbb_dout;
            end
        end
    end

endmodule
