//  Based on MAME decocass_m.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module sound_latches (
    input  wire        clk_sys,
    input  wire        reset,

    input  wire        ce_main,
    input  wire        main_we_e414,
    input  wire        main_re_e700,
    input  wire        main_re_e701,
    input  wire [7:0]  main_dout,
    output reg  [7:0]  main_din_e700,
    output reg  [7:0]  main_din_e701,

    input  wire        ce_audio,
    input  wire        audio_we_c000,
    input  wire        audio_re_a000,
    input  wire [7:0]  audio_dout,
    output reg  [7:0]  audio_din_a000,

    output reg         audio_irq
);

    reg [7:0] soundlatch;
    reg [7:0] soundlatch2;
    reg [7:0] sound_ack;

    always @* begin
        main_din_e700 = soundlatch2;

        main_din_e701 = sound_ack;

        audio_din_a000 = soundlatch;
    end

    always @(posedge clk_sys) begin
        if (reset) begin
            soundlatch    <= 8'h00;
            soundlatch2   <= 8'h00;
            sound_ack     <= 8'h00;
            audio_irq     <= 1'b0;
        end else begin
            if (main_we_e414) begin
                soundlatch  <= main_dout;
                sound_ack   <= (sound_ack | 8'h80) & 8'hBF;
                audio_irq   <= 1'b1;
            end

            if (audio_re_a000) begin
                audio_irq <= 1'b0;
                sound_ack <= sound_ack & 8'h7F;
            end

            if (audio_we_c000) begin
                soundlatch2 <= audio_dout;
                sound_ack   <= sound_ack | 8'h40;
            end
        end
    end

endmodule
