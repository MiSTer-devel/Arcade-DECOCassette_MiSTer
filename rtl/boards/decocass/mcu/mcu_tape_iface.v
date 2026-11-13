//  Based on MAME decocass_m.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

`timescale 1 ps / 1 ps

module mcu_tape_iface (
    input  wire        clk_sys,
    input  wire        ce_hclk,
    input  wire        ce_hclk1,
    input  wire        ce_tape,
    input  wire        reset,

    output wire [7:0]  mcu_p1_in,
    input  wire [7:0]  mcu_p1_out,
    output wire [7:0]  mcu_p2_in,
    input  wire [7:0]  mcu_p2_out,
    output wire        mcu_t0,
    output wire        mcu_t1,

    output wire        mcu_cs_n,
    output wire        mcu_rd_n,
    output wire        mcu_wr_n,
    output wire        mcu_a0,
    output wire [7:0]  mcu_dout,

    output wire        tape_motor_on,
    output wire        tape_direction,
    output wire [1:0]  tape_speed_select,
    input  wire        tape_data,
    input  wire        tape_clock,
    input  wire        tape_bot,
    input  wire        tape_eot,

    input  wire        cpu_e5_re,
    input  wire        cpu_e5_we,
    input  wire [7:0]  cpu_addr_lo,
    input  wire [7:0]  cpu_dout,
    output wire [7:0]  cpu_din,

    input  wire [7:0]  mcu_host_dout,
    input  wire        mcu_host_dout_oe,

    output wire [7:0]  dongle_addr_lo,
    output wire        dongle_re,
    output wire        dongle_we,
    output wire [7:0]  dongle_dout,
    input  wire [3:0]  dongle_din_low4
);

    assign mcu_p1_in = 8'hFF;

    wire fast_active = ~mcu_p1_out[2];
    wire rew_active  = ~mcu_p1_out[4];
    wire fwd_active  = ~mcu_p1_out[5];

    assign tape_motor_on     = fwd_active | rew_active;
    assign tape_direction    = fwd_active;
    assign tape_speed_select = (!(fwd_active | rew_active)) ? 2'b00 :
                               fast_active                   ? 2'b10 :
                                                               2'b01;

    wire status_bot_eot = tape_bot | tape_eot;
    wire status_rclk    = tape_clock;
    wire status_rdata   = tape_data;

    assign mcu_p2_in[7] = status_rdata;
    assign mcu_p2_in[6] = status_rclk;
    assign mcu_p2_in[5] = status_bot_eot;
    assign mcu_p2_in[4] = 1'b1;
    assign mcu_p2_in[3:0] = 4'b1111;

    assign mcu_t0 = 1'b1;
    assign mcu_t1 = 1'b1;

    reg        ce_hclk1_r, ce_hclk1_rr;
    always @(posedge clk_sys) begin
        ce_hclk1_r  <= ce_hclk1;
        ce_hclk1_rr <= ce_hclk1_r;
    end
    wire       ce_hclk1_rising = ce_hclk1_r && !ce_hclk1_rr;

    reg        pend_we, pend_re;
    reg        strobe_is_we, strobe_is_re;
    reg [7:0]  cpu_addr_lo_lat, cpu_dout_lat;
    reg  [1:0] hclk_strobe_cnt;
    wire       hclk_strobe_active = (hclk_strobe_cnt != 2'd0);

    reg        ce_hclk_r, ce_hclk_rr;
    always @(posedge clk_sys) begin
        ce_hclk_r  <= ce_hclk;
        ce_hclk_rr <= ce_hclk_r;
    end
    wire       ce_hclk_rising = ce_hclk_r;

    wire e5_we_mcu = cpu_e5_we & ~cpu_addr_lo[1];
    wire e5_re_mcu = cpu_e5_re & ~cpu_addr_lo[1];

    always @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            pend_we <= 1'b0; pend_re <= 1'b0;
            strobe_is_we <= 1'b0; strobe_is_re <= 1'b0;
            hclk_strobe_cnt <= 2'd0;
            cpu_addr_lo_lat <= 8'd0; cpu_dout_lat <= 8'd0;
        end else begin
            if (e5_we_mcu) begin cpu_addr_lo_lat <= cpu_addr_lo; cpu_dout_lat <= cpu_dout; end
            else if (e5_re_mcu) cpu_addr_lo_lat <= cpu_addr_lo;

            if (!hclk_strobe_active && ce_hclk_rising &&
                (pend_we || e5_we_mcu || pend_re || e5_re_mcu)) begin
                hclk_strobe_cnt <= 2'd2;
                if (pend_we || e5_we_mcu) begin
                    strobe_is_we <= 1'b1; strobe_is_re <= 1'b0;
                    pend_we <= 1'b0;
                end else begin
                    strobe_is_we <= 1'b0; strobe_is_re <= 1'b1;
                    pend_re <= 1'b0;
                end
            end else begin
                if (e5_we_mcu) pend_we <= 1'b1;
                if (e5_re_mcu) pend_re <= 1'b1;
                if (hclk_strobe_active && ce_hclk_rising)
                    hclk_strobe_cnt <= hclk_strobe_cnt - 2'd1;
            end
        end
    end

    assign     mcu_cs_n  = ~hclk_strobe_active;
    assign     mcu_rd_n  = ~(hclk_strobe_active && strobe_is_re);
    assign     mcu_wr_n  = ~(hclk_strobe_active && strobe_is_we);
    assign     mcu_a0    = hclk_strobe_active ? cpu_addr_lo_lat[0] : cpu_addr_lo[0];
    assign     mcu_dout  = cpu_dout_lat;

    reg [7:0] mcu_dout_read;

    assign dongle_addr_lo = cpu_addr_lo;
    // $E5x2/$E5x3 are STATUS: they never reach the dongle (nor the 8041 as a command byte)
    assign dongle_re      = cpu_e5_re & ~cpu_addr_lo[1];
    assign dongle_we      = cpu_e5_we & ~cpu_addr_lo[1];
    assign dongle_dout    = cpu_dout;

    wire        cassette_present_n = 1'b0;
    wire        bot_eot            = tape_bot | tape_eot;

    wire [7:0]  e5xx_status_byte = {
        cassette_present_n,
        1'b1,
        1'b1,
        bot_eot,
        mcu_p2_out[2],
        mcu_p2_out[1],
        mcu_p2_out[0],
        mcu_p1_out[7]
    };

    wire        e5xx_is_status = (cpu_addr_lo[1] == 1'b1);

    assign cpu_din = e5xx_is_status ? e5xx_status_byte : mcu_host_dout;

endmodule
