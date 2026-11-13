//  Based on MAME decocass_tape.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

`timescale 1 ps / 1 ps

module cassette_loader (
    input  wire        clk_sys,
    input  wire        ioctl_download,
    input  wire        ioctl_wr,
    input  wire [24:0] ioctl_addr,
    input  wire [7:0]  ioctl_dout,
    input  wire [7:0]  ioctl_index,

    output reg  [15:0] bram_addr,
    output reg  [7:0]  bram_dout,
    output reg         bram_we,

    output reg  [7:0]  crc_table_addr,
    output reg  [15:0] crc_table_data,
    output reg         crc_table_we,

    output reg  [17:0] image_size_bytes
);

    wire [24:0] addr = ioctl_addr;
    wire [7:0]  data = ioctl_dout;

    wire sel_cassette = (ioctl_index == 8'd0) && (addr >= 25'h03000) && (addr <= 25'h3FFFF);
    wire [24:0] cassette_addr_rel = addr - 25'h03000;
    wire is_first_byte = sel_cassette && (cassette_addr_rel == 25'd0);

    function [15:0] tape_crc16_byte;
        input [15:0] crc;
        input [7:0]  d;
        integer i;
        reg [15:0] r;
        reg [7:0]  dd;
        begin
            r  = crc;
            dd = d;
            for (i = 0; i < 8; i = i + 1) begin
                r = {r[0], r[15:1]};
                r = r ^ (dd[0] ? 16'h0080 : 16'h0000);
                if (r[7])
                    r = r ^ 16'h0120;
                dd = dd >> 1;
            end
            tape_crc16_byte = r;
        end
    endfunction

    reg [15:0] crc_acc;
    reg [7:0]  byte_in_block;
    reg [7:0]  current_block;

    always @(posedge clk_sys) begin
        bram_we      <= 1'b0;
        crc_table_we <= 1'b0;

        if (ioctl_download && ioctl_wr && sel_cassette) begin
            bram_we    <= 1'b1;
            bram_addr  <= cassette_addr_rel[15:0];
            bram_dout  <= data;

            if (is_first_byte) begin
                image_size_bytes <= (data != 8'h00) ? 18'd1 : 18'd0;
                crc_acc          <= tape_crc16_byte(16'h0000, data);
                byte_in_block    <= 8'd1;
                current_block    <= 8'd0;
            end else begin
                // trailing zero bytes must not extend the tape length / EOT position
                if (data != 8'h00) image_size_bytes <= cassette_addr_rel[17:0] + 18'd1;
                if (byte_in_block == 8'd255) begin
                    crc_table_we   <= 1'b1;
                    crc_table_addr <= current_block;
                    crc_table_data <= tape_crc16_byte(crc_acc, data);
                    crc_acc        <= 16'h0000;
                    byte_in_block  <= 8'd0;
                    current_block  <= current_block + 8'd1;
                end else begin
                    crc_acc        <= tape_crc16_byte(crc_acc, data);
                    byte_in_block  <= byte_in_block + 8'd1;
                end
            end
        end
    end

    initial begin
        bram_we          = 1'b0;
        bram_addr        = 16'd0;
        bram_dout        = 8'd0;
        image_size_bytes = 18'd0;
        crc_table_we     = 1'b0;
        crc_table_addr   = 8'd0;
        crc_table_data   = 16'd0;
        crc_acc          = 16'h0000;
        byte_in_block    = 8'd0;
        current_block    = 8'd0;
    end

endmodule
