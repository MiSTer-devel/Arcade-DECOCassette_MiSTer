//  Based on MAME decocass_v.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module watchdog (
    input  wire        clk_sys,
    input  wire        ce_hclk1,
    input  wire        reset,

    input  wire        vblank_pulse,
    input  wire        wd_count_w,
    input  wire        wd_flip_w,
    input  wire [7:0]  cpu_dout,

    input  wire [7:0]  dsw1,                // bit[6] = CABINET (cocktail mode DIP)

    output reg         wd_reset,
    output reg         flip_screen
);

    reg [3:0] wd_counter;
    wire [3:0] wd_reload_val = (cpu_dout[3:0] & 4'hF) + 4'h1;

    always @(posedge clk_sys) begin
        if (reset) begin
            wd_counter <= 4'hF;
            wd_reset   <= 1'b0;
        end else if (ce_hclk1) begin
            if (wd_count_w) begin
                wd_counter <= wd_reload_val;
                wd_reset   <= 1'b0;
            end else if (vblank_pulse) begin
                if (wd_counter == 4'h0) begin
                    wd_reset <= 1'b1;
                end else begin
                    wd_counter <= wd_counter - 4'h1;
                end
            end
        end
    end

    reg [7:0] flip_register;

    always @(posedge clk_sys) begin
        if (reset) begin
            flip_register <= 8'h00;
        end else if (ce_hclk1 && wd_flip_w) begin
            flip_register <= cpu_dout;
        end
    end

    wire cabinet_mode = dsw1[6];

    always @* begin
        flip_screen = flip_register[0] & cabinet_mode;
    end

endmodule
