//  Based on MAME decocass_m.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

`timescale 1 ps / 1 ps

module dongle_type4 (
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

    output wire [14:0] prom_addr,
    input  wire [7:0]  prom_q
);

    reg [14:0] m_type4_ctrs;
    reg        m_type4_latch;

    always @(posedge clk_sys) begin
        if (reset) begin
            m_type4_ctrs   <= 15'h0000;
            m_type4_latch  <= 1'b0;
        end
        else if (ce_hclk4) begin
            if (cpu_we) begin
                if (cpu_addr_lo[0] == 1'b1) begin
                    if (m_type4_latch == 1'b1) begin
                        m_type4_ctrs[14:8] <= {cpu_dout[6:0]};
                    end
                    else if ((cpu_dout[7:4] == 4'hC)) begin
                        m_type4_latch <= 1'b1;
                    end
                end
                else if (cpu_addr_lo[0] == 1'b0) begin
                    if (m_type4_latch == 1'b1) begin
                        m_type4_ctrs[7:0] <= cpu_dout;
                    end
                end
            end

            if (cpu_re) begin
                if (cpu_addr_lo[0] == 1'b0) begin
                    if (m_type4_latch == 1'b1) begin
                        m_type4_ctrs <= (m_type4_ctrs + 15'h0001) & 15'h7FFF;
                    end
                end
            end
        end
    end

    assign prom_addr = m_type4_ctrs;

    always @(*) begin
        if (cpu_addr_lo[0] == 1'b1) begin
            cpu_din_full = mcu_dbb_sts;
        end else begin
            cpu_din_full = m_type4_latch ? prom_q : mcu_dbb_dout;
        end
    end

endmodule
