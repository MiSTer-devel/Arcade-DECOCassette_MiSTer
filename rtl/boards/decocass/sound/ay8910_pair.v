//  Based on MAME decocass.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module ay8910_pair (
    input  wire        clk_sys,
    input  wire        ce_hclk2,
    input  wire        ce_audio,
    input  wire        reset,

    input  wire        ay1_data_we,
    input  wire        ay1_addr_we,
    input  wire        ay2_data_we,
    input  wire        ay2_addr_we,
    input  wire [7:0]  audio_dout,

    output wire [15:0] sound_out,
    output wire        dbg_ay_pulse,

    output wire        ay1_rst_n,
    output wire        ay1_ce,
    output wire [3:0]  ay1_addr,
    output wire        ay1_cs_n,
    output wire        ay1_wr_n,
    output wire [7:0]  ay1_din,
    input  wire [9:0]  ay1_sound,
    output wire        ay2_rst_n,
    output wire        ay2_ce,
    output wire [3:0]  ay2_addr,
    output wire        ay2_cs_n,
    output wire        ay2_wr_n,
    output wire [7:0]  ay2_din,
    input  wire [9:0]  ay2_sound
);

    reg [3:0] ay1_addr_latch;

    always @(posedge clk_sys) begin
        if (reset) begin
            ay1_addr_latch <= 4'h0;
        end else if (ce_audio && ay1_addr_we) begin
            ay1_addr_latch <= audio_dout[3:0];
        end
    end

    reg [3:0] ay2_addr_latch;

    always @(posedge clk_sys) begin
        if (reset) begin
            ay2_addr_latch <= 4'h0;
        end else if (ce_audio && ay2_addr_we) begin
            ay2_addr_latch <= audio_dout[3:0];
        end
    end

    reg ay1_data_we_r, ay2_data_we_r;
    reg ay1_pulse, ay2_pulse;

    always @(posedge clk_sys) begin
        if (reset) begin
            ay1_data_we_r <= 1'b0;
            ay2_data_we_r <= 1'b0;
            ay1_pulse <= 1'b0;
            ay2_pulse <= 1'b0;
        end else begin
            ay1_data_we_r <= ay1_data_we;
            ay2_data_we_r <= ay2_data_we;

            if (ay1_data_we && ~ay1_data_we_r) begin
                ay1_pulse <= 1'b1;
            end else if (ce_hclk2) begin
                ay1_pulse <= 1'b0;
            end

            if (ay2_data_we && ~ay2_data_we_r) begin
                ay2_pulse <= 1'b1;
            end else if (ce_hclk2) begin
                ay2_pulse <= 1'b0;
            end
        end
    end

    assign dbg_ay_pulse = ay1_pulse | ay2_pulse;

    assign ay1_rst_n = ~reset;
    assign ay1_ce    = ce_hclk2;
    assign ay1_addr  = ay1_addr_latch;
    assign ay1_cs_n  = ~ay1_pulse;
    assign ay1_wr_n  = ~ay1_pulse;
    assign ay1_din   = audio_dout;

    assign ay2_rst_n = ~reset;
    assign ay2_ce    = ce_hclk2;
    assign ay2_addr  = ay2_addr_latch;
    assign ay2_cs_n  = ~ay2_pulse;
    assign ay2_wr_n  = ~ay2_pulse;
    assign ay2_din   = audio_dout;

    wire [10:0] ay_sum = {1'b0, ay1_sound} + {1'b0, ay2_sound};
    wire [10:0] ay_centered = ay_sum - 11'd1024;
    wire signed [15:0] sound_mixed = {ay_centered, 5'b0};

    tp_lpf_light lpf (
        .clk   (clk_sys),
        .reset (reset),
        .in    (sound_mixed),
        .out   (sound_out)
    );

endmodule
