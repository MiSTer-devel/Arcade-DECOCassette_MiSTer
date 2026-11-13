//  Based on MAME decocass_m.cpp, decocass.h (Juergen Buchmueller, David Haywood, GPL-2.0+)

`timescale 1 ps / 1 ps

module dongle_type3 (
    input  wire        clk_sys,
    input  wire        ce_hclk4,
    input  wire        reset,

    input  wire        cpu_re,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_addr_lo,
    input  wire [7:0]  cpu_dout,
    output reg  [7:0]  cpu_din_full,

    input  wire [3:0]  swap_mode,
    input  wire        mcu_status_d0,
    input  wire [7:0]  mcu_dbb_dout,
    input  wire [7:0]  mcu_dbb_sts,

    output reg  [11:0] prom_addr,
    input  wire [7:0]  prom_q
);

    reg [11:0] m_type3_ctrs;
    reg        m_type3_d0_latch;
    reg        m_type3_pal_19;

    always @(posedge clk_sys) begin
        if (reset) begin
            m_type3_ctrs      <= 12'h000;
            m_type3_d0_latch  <= 1'b0;
            m_type3_pal_19    <= 1'b0;
        end
        else if (ce_hclk4) begin
            if (cpu_we) begin
                if (cpu_addr_lo[0] == 1'b1) begin
                    if (m_type3_pal_19 == 1'b1) begin
                        m_type3_ctrs <= {cpu_dout[7:0], 4'h0};
                    end
                    else if ((cpu_dout[7:4] == 4'hC)) begin
                        m_type3_pal_19 <= 1'b1;
                    end
                end
            end

            if (cpu_re) begin
                if (cpu_addr_lo[0] == 1'b1) begin
                    if (m_type3_pal_19 == 1'b1) begin
                        if (m_type3_ctrs == 12'hFFF) begin
                            m_type3_ctrs <= 12'h000;
                        end
                        else begin
                            m_type3_ctrs <= m_type3_ctrs + 12'h001;
                        end
                    end
                end
                else begin
                    if (m_type3_pal_19 == 1'b0)
                        m_type3_d0_latch <= mcu_dbb_dout[0];
                end
            end
        end
    end

    always @(*) begin
        prom_addr = m_type3_ctrs;
    end

    always @(*) begin
        reg [7:0] prom_data;
        reg [7:0] data_out;

        if (m_type3_pal_19 == 1'b1) begin
            prom_data = prom_q;
            data_out = prom_q;
        end
        else begin
            prom_data = mcu_dbb_dout;

            case (swap_mode[3:0])
                4'd0: begin
                    data_out[0] = prom_data[1];
                    data_out[1] = m_type3_d0_latch;
                    data_out[2] = prom_data[2];
                    data_out[3] = prom_data[3];
                    data_out[4] = prom_data[4];
                    data_out[5] = prom_data[5];
                    data_out[6] = prom_data[6];
                    data_out[7] = prom_data[7];
                end

                4'd1: begin
                    data_out[0] = m_type3_d0_latch;
                    data_out[1] = prom_data[2];
                    data_out[2] = prom_data[1];
                    data_out[3] = prom_data[3];
                    data_out[4] = prom_data[4];
                    data_out[5] = prom_data[5];
                    data_out[6] = prom_data[6];
                    data_out[7] = prom_data[7];
                end

                4'd2: begin
                    data_out[0] = m_type3_d0_latch;
                    data_out[1] = prom_data[3];
                    data_out[2] = prom_data[2];
                    data_out[3] = prom_data[1];
                    data_out[4] = prom_data[4];
                    data_out[5] = prom_data[5];
                    data_out[6] = prom_data[6];
                    data_out[7] = prom_data[7];
                end

                4'd3: begin
                    data_out[0] = m_type3_d0_latch;
                    data_out[1] = prom_data[1];
                    data_out[2] = prom_data[4];
                    data_out[3] = prom_data[3];
                    data_out[4] = prom_data[2];
                    data_out[5] = prom_data[5];
                    data_out[6] = prom_data[6];
                    data_out[7] = prom_data[7];
                end

                4'd4: begin
                    data_out[0] = m_type3_d0_latch;
                    data_out[1] = prom_data[1];
                    data_out[2] = prom_data[5];
                    data_out[3] = prom_data[3];
                    data_out[4] = prom_data[4];
                    data_out[5] = prom_data[2];
                    data_out[6] = prom_data[6];
                    data_out[7] = prom_data[7];
                end

                4'd5: begin
                    data_out[0] = m_type3_d0_latch;
                    data_out[1] = prom_data[1];
                    data_out[2] = prom_data[2];
                    data_out[3] = prom_data[4];
                    data_out[4] = prom_data[3];
                    data_out[5] = prom_data[5];
                    data_out[6] = prom_data[6];
                    data_out[7] = prom_data[7];
                end

                4'd6: begin
                    data_out[0] = prom_data[7];
                    data_out[1] = prom_data[1];
                    data_out[2] = prom_data[2];
                    data_out[3] = prom_data[4];
                    data_out[4] = prom_data[3];
                    data_out[5] = prom_data[5];
                    data_out[6] = prom_data[6];
                    data_out[7] = m_type3_d0_latch;
                end

                4'd7: begin
                    data_out[0] = m_type3_d0_latch;
                    data_out[1] = prom_data[1];
                    data_out[2] = prom_data[2];
                    data_out[3] = prom_data[3];
                    data_out[4] = prom_data[5];
                    data_out[5] = prom_data[4];
                    data_out[6] = prom_data[6];
                    data_out[7] = prom_data[7];
                end

                4'd8: begin
                    data_out[0] = m_type3_d0_latch;
                    data_out[1] = prom_data[1];
                    data_out[2] = prom_data[3];
                    data_out[3] = prom_data[2];
                    data_out[4] = prom_data[4];
                    data_out[5] = prom_data[6];
                    data_out[6] = prom_data[5];
                    data_out[7] = prom_data[7];
                end

                4'd9: begin
                    data_out[0] = m_type3_d0_latch;
                    data_out[1] = prom_data[1];
                    data_out[2] = prom_data[2];
                    data_out[3] = prom_data[3];
                    data_out[4] = prom_data[4];
                    data_out[5] = prom_data[6];
                    data_out[6] = prom_data[5];
                    data_out[7] = prom_data[7];
                end

                4'd10: begin
                    data_out[0] = m_type3_d0_latch;
                    data_out[1] = prom_data[1];
                    data_out[2] = prom_data[2];
                    data_out[3] = prom_data[3];
                    data_out[4] = prom_data[4];
                    data_out[5] = prom_data[5];
                    data_out[6] = prom_data[7];
                    data_out[7] = prom_data[6];
                end

                default: begin
                    data_out[0] = m_type3_d0_latch;
                    data_out[1] = prom_data[1];
                    data_out[2] = prom_data[2];
                    data_out[3] = prom_data[3];
                    data_out[4] = prom_data[4];
                    data_out[5] = prom_data[5];
                    data_out[6] = prom_data[6];
                    data_out[7] = prom_data[7];
                end
            endcase
        end

        if (cpu_addr_lo[0] == 1'b1) begin
            cpu_din_full = m_type3_pal_19 ? data_out : mcu_dbb_sts;
        end else begin
            cpu_din_full = m_type3_pal_19 ? 8'hFF : data_out;
        end
    end

endmodule
