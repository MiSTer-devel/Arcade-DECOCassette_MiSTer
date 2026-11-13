//  Based on MAME decocass_m.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

`timescale 1 ps / 1 ps

module dongle_type2 (
    input  wire        clk_sys,
    input  wire        ce_hclk4,
    input  wire        reset,

    input  wire        cpu_re,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_addr_lo,
    input  wire [7:0]  cpu_dout,
    output reg  [7:0]  cpu_din_full,

    input  wire        mcu_status_d2,
    input  wire [7:0]  mcu_dbb_dout,
    input  wire [7:0]  mcu_dbb_sts,

    output wire [8:0]  prom_addr,
    input  wire [7:0]  prom_q
);

    reg [7:0] m_type2_promaddr;
    reg        m_type2_d2_latch;
    reg        m_type2_xx_latch;

    always @(posedge clk_sys) begin
        if (reset) begin
            m_type2_promaddr  <= 8'h00;
            m_type2_d2_latch  <= 1'b0;
            m_type2_xx_latch  <= 1'b0;
        end
        else if (ce_hclk4 && cpu_we) begin
            if (cpu_addr_lo[0] == 1'b1) begin
                if ((cpu_dout[7:4] == 4'hC)) begin
                    m_type2_xx_latch <= 1'b1;
                    m_type2_d2_latch <= (cpu_dout[2]) ? 1'b1 : 1'b0;
                end
            end
            else if (cpu_addr_lo[0] == 1'b0) begin
                if (m_type2_xx_latch == 1'b1) begin
                    m_type2_promaddr <= cpu_dout;
                end
            end
        end
    end

    assign prom_addr = {m_type2_d2_latch, m_type2_promaddr};

    always @(*) begin
        if (m_type2_xx_latch == 1'b1) begin
            if (cpu_addr_lo[0] == 1'b1) begin
                cpu_din_full = prom_q;
            end else begin
                cpu_din_full = 8'hFF;
            end
        end else begin
            cpu_din_full = cpu_addr_lo[0] ? mcu_dbb_sts : mcu_dbb_dout;
        end
    end

endmodule
