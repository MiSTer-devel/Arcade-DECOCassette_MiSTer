//  Based on MAME decocass_tape.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module tape_streamer (
    input  wire        clk_sys,
    input  wire        ce_tape,
    input  wire        reset,

    output wire [17:0] image_addr,
    input  wire [7:0]  image_q,

    input  wire [17:0] image_size_bytes,

    input  wire        motor_on,
    input  wire        direction,        // 1 = forward, 0 = rewind
    input  wire [1:0]  speed_select,

    output wire [7:0]  crc_addr,
    input  wire [15:0] crc_q,

    output wire        tape_data,
    output wire        tape_clock,
    output wire        tape_bot,
    output wire        tape_eot
);

    localparam TAPE_CLOCKRATE       = 4800;
    localparam CLOCKS_PER_BIT       = 2;
    localparam CLOCKS_PER_BYTE      = 16;

    localparam LEADER_CLOCKS        = 4800;
    localparam LEADER_GAP_CLOCKS    = 7200;
    localparam BOT_CLOCKS           = 12;
    localparam BOT_GAP_CLOCKS       = 1440;

    localparam REGION_LEADER_END    = LEADER_CLOCKS;
    localparam REGION_LEADER_GAP_END = REGION_LEADER_END + LEADER_GAP_CLOCKS;
    localparam REGION_BOT_END       = REGION_LEADER_GAP_END + BOT_CLOCKS;
    localparam REGION_BOT_GAP_END   = REGION_BOT_END + BOT_GAP_CLOCKS;

    localparam BYTES_PER_BLOCK      = 331;
    localparam CLOCKS_PER_BLOCK     = BYTES_PER_BLOCK * CLOCKS_PER_BYTE;

    localparam BYTE_PRE_GAP_START   = 0;
    localparam BYTE_PRE_GAP_END     = 33;
    localparam BYTE_LEADIN          = 34;
    localparam BYTE_HEADER          = 35;
    localparam BYTE_DATA_START      = 36;
    localparam BYTE_DATA_END        = 291;
    localparam BYTE_CRC_MSB         = 292;
    localparam BYTE_CRC_LSB         = 293;
    localparam BYTE_TRAILER         = 294;
    localparam BYTE_LEADOUT         = 295;
    localparam BYTE_LONGCLOCK       = 296;
    localparam BYTE_POSTGAP_START   = 297;
    localparam BYTE_POSTGAP_END     = 330;

    reg [31:0] clockpos;
    reg [31:0] total_clocks;
    reg [31:0] num_blocks;

    wire [31:0] data_region_clocks;
    wire [31:0] dataclock;
    wire [8:0]  byte_offset;
    wire [2:0]  bit_offset;
    reg  [7:0]  block_num;
    reg  [31:0] block_base;

    wire [7:0]  current_byte;

    assign crc_addr = block_num;

    always @(posedge clk_sys) begin
        if (reset) begin
            num_blocks <= (image_size_bytes + 255) >> 8;

            total_clocks <= REGION_BOT_GAP_END +
                           ((image_size_bytes + 255) >> 8) * CLOCKS_PER_BLOCK +
                           REGION_BOT_GAP_END;
        end
    end

    wire [31:0] step = (speed_select == 2'b10) ? 32'd7 : 32'd1;

    always @(posedge clk_sys) begin
        if (reset) begin
            clockpos <= 0;
        end else if (ce_tape && motor_on) begin
            if (direction) begin
                clockpos <= (clockpos + step < total_clocks) ? (clockpos + step)
                                                             : (total_clocks - 1);
            end else begin
                clockpos <= (clockpos > step) ? (clockpos - step) : 32'd0;
            end
        end
    end

    wire [31:0] clockpos_next = !(ce_tape && motor_on) ? clockpos :
                                direction ? ((clockpos + step < total_clocks) ? (clockpos + step) : (total_clocks - 1))
                                          : ((clockpos > step) ? (clockpos - step) : 32'd0);

    always @(posedge clk_sys) begin
        if (reset) begin
            block_num  <= 8'd0;
            block_base <= REGION_BOT_GAP_END;
        end else if (ce_tape && motor_on) begin
            if (clockpos_next >= block_base + CLOCKS_PER_BLOCK) begin
                block_num  <= block_num + 8'd1;
                block_base <= block_base + CLOCKS_PER_BLOCK;
            end else if (clockpos_next < block_base && block_num != 8'd0) begin
                block_num  <= block_num - 8'd1;
                block_base <= block_base - CLOCKS_PER_BLOCK;
            end
        end
    end

    assign data_region_clocks = (clockpos >= REGION_BOT_GAP_END) ?
                                (clockpos - REGION_BOT_GAP_END) : 32'h0;

    assign dataclock   = (clockpos >= block_base) ? (clockpos - block_base) : 32'h0;
    wire [31:0] dataclock_out = dataclock + 32'd1;
    assign byte_offset = dataclock_out / CLOCKS_PER_BYTE;
    assign bit_offset  = (dataclock_out / CLOCKS_PER_BIT) & 3'h7;

    reg [31:0] eot_gap_start, eot_start, trailer_gap_start, trailer_start;
    always @(posedge clk_sys) begin
        eot_gap_start     <= total_clocks - REGION_BOT_GAP_END;
        eot_start         <= total_clocks - REGION_BOT_END;
        trailer_gap_start <= total_clocks - REGION_LEADER_GAP_END;
        trailer_start     <= total_clocks - REGION_LEADER_END;
    end

    wire in_leader     = (clockpos < REGION_LEADER_END);
    wire in_leader_gap = (clockpos >= REGION_LEADER_END &&
                         clockpos < REGION_LEADER_GAP_END);
    wire in_bot        = (clockpos >= REGION_LEADER_GAP_END &&
                         clockpos < REGION_BOT_END);
    wire in_bot_gap    = (clockpos >= REGION_BOT_END &&
                         clockpos < REGION_BOT_GAP_END);

    wire in_eot_gap     = (clockpos >= eot_gap_start     && clockpos < eot_start);
    wire in_eot         = (clockpos >= eot_start         && clockpos < trailer_gap_start);
    wire in_trailer_gap = (clockpos >= trailer_gap_start && clockpos < trailer_start);
    wire in_trailer     = (clockpos >= trailer_start);

    wire in_data        = !in_leader && !in_leader_gap && !in_bot && !in_bot_gap &&
                         !in_trailer && !in_trailer_gap && !in_eot_gap && !in_eot;

    assign image_addr = (in_data && byte_offset >= BYTE_DATA_START &&
                        byte_offset <= BYTE_DATA_END) ?
                        ({block_num, 8'h00} + (byte_offset - BYTE_DATA_START)) :
                        18'h0;

    assign current_byte =
        in_leader || in_leader_gap || in_bot_gap ||
        in_eot_gap || in_trailer || in_eot ? 8'h00 :
        in_bot || in_eot ? 8'h00 :
        (byte_offset >= BYTE_PRE_GAP_START && byte_offset <= BYTE_PRE_GAP_END) ? 8'h00 :
        (byte_offset == BYTE_LEADIN) ? 8'h00 :
        (byte_offset == BYTE_HEADER) ? 8'hAA :
        (byte_offset >= BYTE_DATA_START && byte_offset <= BYTE_DATA_END) ? image_q :
        (byte_offset == BYTE_CRC_MSB) ? crc_q[15:8] :
        (byte_offset == BYTE_CRC_LSB) ? crc_q[7:0] :
        (byte_offset == BYTE_TRAILER) ? 8'hAA :
        (byte_offset == BYTE_LEADOUT) ? 8'h00 :
        (byte_offset == BYTE_LONGCLOCK) ? 8'h00 :
        (byte_offset >= BYTE_POSTGAP_START && byte_offset <= BYTE_POSTGAP_END) ? 8'h00 :
        8'h00;

    assign tape_data = current_byte[bit_offset];

    wire clk_region_active = (in_data &&
                             byte_offset >= BYTE_LEADIN &&
                             byte_offset <= BYTE_LONGCLOCK);

    wire clk_bit = (data_region_clocks & 32'h1) ? 1'b0 : 1'b1;

    assign tape_clock = (byte_offset == BYTE_LONGCLOCK) ? 1'b1 :
                       (clk_region_active) ? clk_bit :
                       1'b0;

    assign tape_bot = in_leader || in_bot;
    assign tape_eot = in_eot    || in_trailer;

endmodule
