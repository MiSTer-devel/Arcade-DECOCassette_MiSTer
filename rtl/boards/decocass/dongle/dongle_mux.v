`timescale 1 ps / 1 ps

module dongle_mux (
    input  wire        clk_sys,
    input  wire        ce_hclk4,
    input  wire        reset,

    input  wire [3:0]  dongle_type,   // widened: 7 = Darksoft multigame, 8 = Widel multigame
    input  wire [7:0]  game_id,
    input  wire [3:0]  swap_mode,

    input  wire        cpu_re,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_addr_lo,
    input  wire [7:0]  cpu_dout,
    output reg  [7:0]  cpu_din_full,

    output reg  [19:0] dprom_addr,
    input  wire [7:0]  dprom_q,

    input  wire [7:0]  mcu_dbb_dout,
    input  wire [7:0]  mcu_dbb_sts,

    input  wire        mcu_status_d2,
    input  wire        mcu_status_d0
);

    wire [7:0] type1_prom_addr;
    wire [7:0] type1_q;
    dongle_type1 type1_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .cpu_din_full (type1_q),
        .game_id (game_id),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts),
        .prom_addr (type1_prom_addr), .prom_q (dprom_q)
    );

    wire [8:0] type2_prom_addr;
    wire [7:0] type2_q;
    dongle_type2 type2_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .cpu_din_full (type2_q),
        .mcu_status_d2 (mcu_status_d2),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts),
        .prom_addr (type2_prom_addr), .prom_q (dprom_q)
    );

    wire [11:0] type3_prom_addr;
    wire [7:0]  type3_q;
    dongle_type3 type3_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .cpu_din_full (type3_q),
        .swap_mode (swap_mode), .mcu_status_d0 (mcu_status_d0),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts),
        .prom_addr (type3_prom_addr), .prom_q (dprom_q)
    );

    wire [14:0] type4_prom_addr;
    wire [7:0]  type4_q;
    dongle_type4 type4_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .cpu_din_full (type4_q),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts),
        .prom_addr (type4_prom_addr), .prom_q (dprom_q)
    );

    wire [7:0] type5_q;
    dongle_type5 type5_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts),
        .cpu_din_full (type5_q)
    );

    wire [7:0] nodong_q;
    dongle_nodong nodong_inst (
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts),
        .cpu_addr_lo (cpu_addr_lo),
        .cpu_din_full (nodong_q)
    );

    wire [19:0] darksoft_prom_addr;
    wire [7:0]  darksoft_q;
    dongle_darksoft darksoft_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .cpu_din_full (darksoft_q),
        .prom_addr (darksoft_prom_addr), .prom_q (dprom_q),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts)
    );

    wire [19:0] widel_prom_addr;
    wire [7:0]  widel_q;
    dongle_widel widel_inst (
        .clk_sys (clk_sys), .ce_hclk4 (ce_hclk4), .reset (reset),
        .cpu_re (cpu_re), .cpu_we (cpu_we),
        .cpu_addr_lo (cpu_addr_lo), .cpu_dout (cpu_dout),
        .cpu_din_full (widel_q),
        .prom_addr (widel_prom_addr), .prom_q (dprom_q),
        .mcu_dbb_dout (mcu_dbb_dout), .mcu_dbb_sts (mcu_dbb_sts)
    );

    always @(*) begin
        case (dongle_type)
            4'd1:    cpu_din_full = type1_q;
            4'd2:    cpu_din_full = type2_q;
            4'd3:    cpu_din_full = type3_q;
            4'd4:    cpu_din_full = type4_q;
            4'd5:    cpu_din_full = type5_q;
            4'd6:    cpu_din_full = nodong_q;
            4'd7:    cpu_din_full = darksoft_q;
            4'd8:    cpu_din_full = widel_q;
            default: cpu_din_full = 8'hFF;
        endcase
    end

    always @(*) begin
        case (dongle_type)
            4'd1:    dprom_addr = {12'd0, type1_prom_addr};
            4'd2:    dprom_addr = {11'd0, type2_prom_addr};
            4'd3:    dprom_addr = {8'd0,  type3_prom_addr};
            4'd4:    dprom_addr = {5'd0,  type4_prom_addr};
            4'd7:    dprom_addr = darksoft_prom_addr;
            4'd8:    dprom_addr = widel_prom_addr;
            default: dprom_addr = 20'd0;
        endcase
    end

endmodule
