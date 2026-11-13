//  Based on MAME decocass_m.cpp, decocass.h (Juergen Buchmueller, David Haywood, GPL-2.0+)

`timescale 1 ps / 1 ps

module dongle_widel (
    input  wire        clk_sys,
    input  wire        ce_hclk4,
    input  wire        reset,

    input  wire        cpu_re,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_addr_lo,
    input  wire [7:0]  cpu_dout,
    output reg  [7:0]  cpu_din_full,

    input  wire [7:0]  mcu_dbb_dout,
    input  wire [7:0]  mcu_dbb_sts,

    output wire [19:0] prom_addr,
    input  wire [7:0]  prom_q
);

    reg [19:0] m_widel_ctrs;
    reg        m_widel_latch;

    assign prom_addr = m_widel_ctrs;

    always @(posedge clk_sys) begin
        if (reset) begin
            m_widel_ctrs  <= 20'd0;
            m_widel_latch <= 1'b0;
        end
        else if (ce_hclk4) begin
            if (cpu_we) begin
                if (cpu_addr_lo[0]) begin
                    if (m_widel_latch)
                        m_widel_ctrs <= 20'd0;
                    else if (cpu_dout[7:4] == 4'hC)
                        m_widel_latch <= 1'b1;
                end
                else begin
                    if (m_widel_latch)
                        m_widel_ctrs[7:0] <= cpu_dout;
                end
            end

            if (cpu_re) begin
                if (cpu_addr_lo[0]) begin
                    if (m_widel_latch)
                        m_widel_ctrs <= m_widel_ctrs + 20'h00100;
                end
                else begin
                    if (m_widel_latch)
                        m_widel_ctrs <= m_widel_ctrs + 20'h00001;
                end
            end
        end
    end

    always @(*) begin
        if (cpu_addr_lo[0])
            cpu_din_full = mcu_dbb_sts;
        else
            cpu_din_full = m_widel_latch ? prom_q : mcu_dbb_dout;
    end

endmodule
