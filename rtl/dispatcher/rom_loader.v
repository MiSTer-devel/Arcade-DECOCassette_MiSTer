
`timescale 1 ps / 1 ps

module rom_loader (
    input  wire        clk_sys,
    input  wire        ioctl_download,
    input  wire        ioctl_wr,
    input  wire [24:0] ioctl_addr,
    input  wire [7:0]  ioctl_dout,
    input  wire [7:0]  ioctl_index,

    output reg         bios_we,
    output reg  [11:0] bios_addr,
    output reg  [7:0]  bios_dout,

    output reg         abios_we,
    output reg  [10:0] abios_addr,
    output reg  [7:0]  abios_dout,

    output reg         mcurom_we,
    output reg  [9:0]  mcurom_addr,
    output reg  [7:0]  mcurom_dout,

    output reg         palprom_we,
    output reg  [7:0]  palprom_addr,
    output reg  [7:0]  palprom_dout,

    output reg         dongleprom_we,
    output reg  [17:0] dongleprom_addr,
    output reg  [7:0]  dongleprom_dout,

    output reg  [7:0]  metadata_dongle_type,
    output reg  [7:0]  metadata_game_id,
    output reg  [7:0]  metadata_swap_mode
);

    wire [24:0] addr = ioctl_addr;
    wire [7:0]  data = ioctl_dout;

    wire sel_bios     = (addr >= 25'h00000) && (addr <= 25'h00FFF);
    wire sel_abios    = (addr >= 25'h01000) && (addr <= 25'h017FF);
    wire sel_mcurom   = (addr >= 25'h01800) && (addr <= 25'h01BFF);
    wire sel_palprom  = (addr >= 25'h01C00) && (addr <= 25'h01CFF);
    wire sel_dongprom = (addr >= 25'h01D00) && (addr <= 25'h02CFF);
    wire sel_spare    = (addr >= 25'h02D00) && (addr <= 25'h02DFF);
    wire sel_metadata = (addr >= 25'h02E00) && (addr <= 25'h02EFF);

    wire [11:0] bios_addr_rel     = addr[11:0];
    wire [10:0] abios_addr_rel    = addr[10:0];
    wire [9:0]  mcurom_addr_rel   = addr[9:0];
    wire [7:0]  prom_addr_rel     = addr[7:0];
    wire [11:0] dongprom_addr_rel = addr - 25'h01D00;
    wire [7:0]  metadata_addr_rel = addr[7:0];

    always @(posedge clk_sys) begin
        bios_we       <= 1'b0;
        abios_we      <= 1'b0;
        mcurom_we     <= 1'b0;
        palprom_we    <= 1'b0;
        dongleprom_we <= 1'b0;

        if (ioctl_download && ioctl_wr && ioctl_index == 8'd0) begin
            if (sel_bios) begin
                bios_we    <= 1'b1;
                bios_addr  <= bios_addr_rel;
                bios_dout  <= data;
            end
            else if (sel_abios) begin
                abios_we   <= 1'b1;
                abios_addr <= abios_addr_rel;
                abios_dout <= data;
            end
            else if (sel_mcurom) begin
                mcurom_we   <= 1'b1;
                mcurom_addr <= mcurom_addr_rel;
                mcurom_dout <= data;
            end
            else if (sel_palprom) begin
                palprom_we   <= 1'b1;
                palprom_addr <= prom_addr_rel;
                palprom_dout <= data;
            end
            else if (sel_dongprom) begin
                dongleprom_we   <= 1'b1;
                dongleprom_addr <= {6'd0, dongprom_addr_rel};
                dongleprom_dout <= data;
            end
            else if (sel_metadata) begin
                case (metadata_addr_rel)
                    8'h00: metadata_dongle_type <= data;
                    8'h01: metadata_game_id     <= data;
                    8'h02: metadata_swap_mode   <= data;
                    default: ;
                endcase
            end
        end
        else if (ioctl_download && ioctl_wr && ioctl_index == 8'd1 && !ioctl_addr[24:18]) begin
            dongleprom_we   <= 1'b1;
            dongleprom_addr <= ioctl_addr[17:0];
            dongleprom_dout <= data;
        end
    end

endmodule
