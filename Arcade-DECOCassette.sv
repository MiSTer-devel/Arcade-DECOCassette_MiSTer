//============================================================================
//  Arcade: DECO Cassette System (Data East, 1980-1985)
//
//  Targets: Lock'n'Chase, Burger Time, and the rest of the supported
//  cassette catalogue (~58 sets — see mra/).
//
//  Port to MiSTer
//  Copyright (C) 2026
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
// SDRAM pins are now driven by sdram_dongle (NeoGeo sdram.sv) — tie-off removed.
assign FB_FORCE_BLANK = '0;

assign VGA_F1 = '0;
assign VGA_SCALER = '0;
assign VGA_DISABLE = '0;
assign HDMI_FREEZE = '0;
assign HDMI_BLACKOUT = '0;
assign HDMI_BOB_DEINT = '0;

assign AUDIO_MIX = '0;

assign LED_DISK = '0;
assign LED_POWER = '0;
// DIAGNOSTIC: LED_USER blinks if game_id==5. Steady on if CRTC was written.
// assign LED_USER = dbg_crtc_hit ? 1'b1 : dbg_cpu_active;
assign BUTTONS = '0;

// Screen is ROT270 (vertical monitor). Aspect ratio from status[1:0]
// (0=3:4 original, 1=native)
wire aspect_wide = status[1];
assign VIDEO_ARX = aspect_wide ? 12'd4 : 12'd3;
assign VIDEO_ARY = aspect_wide ? 12'd3 : 12'd4;

`include "build_id.v"
localparam CONF_STR = {
	"DECOCassette;;",
	"O[1],Aspect ratio,3:4,Original;",
	"O[2],Orientation,Vertical,Horizontal;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Button 1,Button 2,Coin,Start 1P,Start 2P,Pause;",
	"jn,A,B,Select,Start,R,L;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////
//
// Single 96 MHz PLL output -> clk_sys. All DECO Cassette CEs are
// derived in clock_div (task 04).
//
// IMPORTANT: rtl/pll/pll_0002.v must be regenerated in the Quartus
// PLL Megafunction wizard so outclk_0 = 96.0 MHz (8 x 12 MHz master).
// Until that's done, the build compiles but timing is wrong.

wire clk_sys;
wire pll_locked;

pll pll
(
    .refclk   (CLK_50M),
    .rst      (1'b0),
    .outclk_0 (clk_sys),
    .locked   (pll_locked)
);

// MCU-CLK-REALCLK-2026-06-04: dedicated REAL 8 MHz clock for the 8041 MCU, copied from
// Arcade-JunoFirst's sound PLL (pll_sound: CLK_50M -> 8.000 MHz). The T48 core requires clk_i
// to be a real clock (xtal_en='1'); clk_sys+ce_hclk broke its multi-cycle ADD carry (the 8041
// range-rejected valid commands -> handshake never completed). The 8041 now runs in this domain.
wire clk_8041;
pll_sound pll_8041
(
    .refclk   (CLK_50M),
    .rst      (1'b0),
    .outclk_0 (clk_8041),
    .locked   ()
);

// Alias for legacy port names in screen_rotate / arcade_video below:
wire clk_vid = clk_sys;

// DECO Cassette clock-enable chain (task 04)
// PAUSE-2026-06-28: pause_cpu (from pause_inst, below) gates EVERY functional clock-enable so the main 6502, the
// audio 6502 + AYs, the 8041 MCU, and the cassette/tape loader all freeze TOGETHER — nothing drifts out of sync.
// ce_pix is the ONLY ungated clock so video keeps scanning the frozen frame (the pause module also dims it).
// pause_cpu is forced low only on a REAL reset (pause_reset — NOT ioctl_download, so you CAN pause during the cassette
// load); the SD->SDRAM write path isn't gated by pause anyway, so a pause can never stall the transfer.
// REVERT = drop the `& ~pause_cpu` (and the _raw rename).
wire pause_cpu;   // driven by pause_inst far below; declared here so the gates can use it
wire ce_hclk_raw, ce_hclk1_raw, ce_hclk2_raw, ce_hclk4_raw, ce_audio_raw, ce_tape_raw;

wire ce_hclk  = ce_hclk_raw  & ~pause_cpu;   //  6.000 MHz   (8041 MCU CE)
wire ce_hclk1 = ce_hclk1_raw & ~pause_cpu;   //  3.000 MHz
wire ce_hclk2 = ce_hclk2_raw & ~pause_cpu;   //  1.500 MHz   (AY-3-8910 x2)
wire ce_hclk4 = ce_hclk4_raw & ~pause_cpu;   //    750 kHz   (DECO-222 main CPU)
wire ce_audio = ce_audio_raw & ~pause_cpu;   //    500 kHz   (audio M6502)
wire ce_tape  = ce_tape_raw  & ~pause_cpu;   //    4.8 kHz   (cassette streamer / loader)
wire ce_pix;                                  //  alias of ce_hclk — NOT gated (video must keep running)

clock_div clock_div_inst (
    .clk_sys  (clk_sys),
    .reset    (~pll_locked),
    .ce_hclk  (ce_hclk_raw),
    .ce_hclk1 (ce_hclk1_raw),
    .ce_hclk2 (ce_hclk2_raw),
    .ce_hclk4 (ce_hclk4_raw),
    .ce_audio (ce_audio_raw),
    .ce_tape  (ce_tape_raw),
    .ce_pix   (ce_pix)
);

///////////////////////////////////////////////////
// Intermediate bus declarations for interconnect
///////////////////////////////////////////////////

// Graphics subsystem address/data buses (ports B from dual-port RAMs)
wire [9:0]  fgvram_addr_gfx, colram_addr_gfx;
wire [10:0] tilram_addr_gfx;
wire [9:0]  objram_addr_gfx;
wire [7:0]  fgvram_q_gfx, colram_q_gfx;
wire [7:0]  tilram_q_gfx, objram_q_gfx;

// E5xx dongle composite data
wire [7:0]  e5xx_dongle;
wire [7:0]  e5xx_to_cpu;   // DONGLE BYPASS FIX 2026-05-30 (assigned near dongle_mux below)

// BIOS ROM interface (CPU side)
wire [7:0]  bios_dout_cpu;
wire        bios_we_cpu_int;

// Video signals
wire        video_vblank, video_hsync, video_vsync, video_hblank;

// Video timing counters (fanout to all video layers)
wire [8:0]  hcnt, vcnt;

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        video_rotated;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire        ioctl_wait;   // throttles HPS ROM download while a DDR3 dongle write is in flight

wire [15:0] joystick_0, joystick_1;
wire [15:0] joystick_r_analog_0;   // right analog stick: [15:8]=Y signed, [7:0]=X signed
wire [10:0] ps2_key;

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),

	.buttons(buttons),
	.status(status),
	.status_menumask({direct_video}),

	.forced_scandoubler(forced_scandoubler),
	.video_rotated(video_rotated),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_r_analog_0(joystick_r_analog_0),
	.ps2_key(ps2_key)
);

assign ioctl_upload_req = 1'b0;
assign ioctl_din        = 8'd0;

// =========================================================================
// Phase 03: stubbed core. Every block below gets reworked in later phases.
//
//   clocks      -> task 04
//   reset/DIP   -> task 26
//   pause       -> already wired (kept)
//   video       -> tasks 07-11
//   audio       -> tasks 12-14
//   inputs      -> task 23
//   ROM/MRA     -> task 25
// =========================================================================

// =========================================================================
// INTEGRATED CORE — WAVE 6 INTEGRATION PASS
// =========================================================================

// Reset and DIP handling
wire reset = (RESET | status[0] | buttons[1] | ioctl_download);
// PAUSE-LOAD-2026-06-28: pause uses a reset WITHOUT ioctl_download so it can engage DURING the cassette load too
// (user wants the loader pausable — pause works post-load but the `| ioctl_download` above killed it during the load).
// Safe: the SD->SDRAM write path is NOT gated by pause_cpu, so the transfer still finishes; only the CPUs/8041/
// streamer freeze. Real resets (hard / OSD status[0] / hw button) still suppress pause.
wire pause_reset = (RESET | status[0] | buttons[1]);

// DSW-DEFAULTS-2026-06-06: DECO has BIOS-RESERVED DIP bits that MUST be set or the game
// mis-boots. The game's FIRST init instruction is `lda $e301` (DSW2) then `eor #$ff` and it
// table-branches on the result; a wrong DSW2 derails init → wrong (zero) decompress count at
// $4A7D → runaway copy tramples the stack → lockup. MAME factory defaults (decocass.cpp DSW1/DSW2):
//   sw[2]=DSW1=0x3F : Coin 1C/1C, "Type of Tape"=MD(Small)=0x30 (SW1:5,6, "Used by the bios"), Upright
//   sw[3]=DSW2=0xFF : option bits all-default + "Country Code"=A=0xe0 (SW2:6,7,8, "DON'T CHANGE")
// Powering up at $00 made Country Code=000 (not a valid code) → the lockup.
// HARDCODED until a proper OSD DSW section exists: power up to the factory defaults AND block
// ioctl_index 254 from touching DSW1/DSW2, so a zero DIP-download can't stomp the reserved bits.
// FUTURE OSD: drop the `sw_idx != 2/3` guard and ghost out the reserved bits in the menu.
// See vault note "DECO Cassette BIOS-reserved DIP switches".
reg [7:0] sw[8];
initial begin
	// BIT31-FIX-2026-06-29: DSW1/DSW2 byte order swapped so Country Code (DSW2[7:5]) lands on OSD-reachable
	// bits 21-23, not bit 31. The OSD drops bit 31, which made Country Code default to E and never reach A.
	// Now sw[2]=DSW2, sw[3]=DSW1. The 3 module instances below feed .dsw2 from sw[2] and .dsw1 from sw[3];
	// both MRAs use default "00,00,FF,3F" (DSW2 bits 16-23, DSW1 bits 24-31).
	// REVERT all BIT31-FIX: defaults sw[2]=3F/sw[3]=FF; feed .dsw1 from sw[2], .dsw2 from sw[3]; MRA "00,00,3F,FF".
	// sw[0] = 8'h00; sw[1] = 8'h00; sw[2] = 8'h3F; sw[3] = 8'hFF;   // ORIGINAL (DSW1=sw[2], DSW2=sw[3])
	sw[0] = 8'h00; sw[1] = 8'h00; sw[2] = 8'hFF; sw[3] = 8'h3F;
	sw[4] = 8'h00; sw[5] = 8'h00; sw[6] = 8'h00; sw[7] = 8'h00;
end
wire [2:0] sw_idx = ioctl_addr[2:0];
always @(posedge clk_sys)
	// DIAG-REVERT-2026-06-29: DIP validation (chamburger). The guard below blocked the MRA <switches>
	// defaults from ever reaching DSW1(sw[2])/DSW2(sw[3]) — per-game DIPs couldn't load and the OSD DIP
	// menu was inert. Ungated so Hamburger's <switches> (incl. Country Code) load + are OSD-flippable.
	// `initial` 3F/FF defaults still protect any MRA lacking a <switches> block.
	// REVERT: restore the guarded `if` (commented below), delete the ungated one.
	// if (ioctl_wr && (ioctl_index==8'd254) && !ioctl_addr[24:3]
	//     && sw_idx != 3'd2 && sw_idx != 3'd3)   // protect hardcoded DSW1/DSW2
	// 	sw[sw_idx] <= ioctl_dout;
	if (ioctl_wr && (ioctl_index==8'd254) && !ioctl_addr[24:3])   // DSW1/DSW2 ungated (DIP validation)
		sw[sw_idx] <= ioctl_dout;

// Extract metadata from ROM loader
wire [7:0] dongle_type_byte;
wire [7:0] game_id_byte;
wire [7:0] swap_mode_byte;
wire [7:0] game_id   = game_id_byte;         // 2026-05-30: full 8-bit = DECO release number (was [3:0])
wire [3:0] swap_mode = swap_mode_byte[3:0];  // From metadata $02E02 (was sw[1])
wire [3:0] dongle_type = dongle_type_byte[3:0];   // 7 = Darksoft multigame (widened from [2:0])

// =========================================================================
// ROM LOADER (task 25)
// =========================================================================
wire        bios_we_rom, abios_we_rom, mcurom_we;
wire [11:0] bios_addr_rom;
wire [10:0] abios_addr_rom;
wire [9:0]  mcurom_addr;
wire [7:0]  bios_dout_rom, abios_dout_rom, mcurom_dout;
wire        palprom_we;
wire [7:0]  palprom_addr, palprom_dout;
wire        dongleprom_we;
wire [17:0] dongleprom_addr;   // widened for the 256 KB multigame dongle (loaded via ioctl index 1)
wire [7:0]  dongleprom_dout;

rom_loader rom_loader_inst (
	.clk_sys               (clk_sys),
	.ioctl_download        (ioctl_download),
	.ioctl_wr              (ioctl_wr),
	.ioctl_addr            (ioctl_addr),
	.ioctl_dout            (ioctl_dout),
	.ioctl_index           (ioctl_index),
	.bios_we               (bios_we_rom),
	.bios_addr             (bios_addr_rom),
	.bios_dout             (bios_dout_rom),
	.abios_we              (abios_we_rom),
	.abios_addr            (abios_addr_rom),
	.abios_dout            (abios_dout_rom),
	.mcurom_we             (mcurom_we),
	.mcurom_addr           (mcurom_addr),
	.mcurom_dout           (mcurom_dout),
	.palprom_we            (palprom_we),
	.palprom_addr          (palprom_addr),
	.palprom_dout          (palprom_dout),
	.dongleprom_we         (dongleprom_we),
	.dongleprom_addr       (dongleprom_addr),
	.dongleprom_dout       (dongleprom_dout),
	.metadata_dongle_type  (dongle_type_byte),
	.metadata_game_id      (game_id_byte),
	.metadata_swap_mode    (swap_mode_byte)
);

// =========================================================================
// MEMORY: BIOS ROM (main CPU $F000-$FFFF, 4 KB)
// =========================================================================
wire [11:0] bios_addr_cpu;
wire [11:0] bios_addr_cpu_dec;     // address from decocass (CPU-side)
wire        bios_we_cpu;
wire [7:0]  bios_dw_cpu, bios_q;

spram #(.address_width(12), .data_width(8)) bios_rom (
	.clock     (clk_sys),
	.enable    (1'b1),
	.address   (bios_addr_cpu),
	.data      (bios_dw_cpu),
	.wren      (bios_we_cpu),
	.q         (bios_q)
);

// ROM loader and CPU write arbitration for BIOS
assign bios_addr_cpu = bios_we_rom ? bios_addr_rom : bios_addr_cpu_dec;
assign bios_we_cpu   = bios_we_rom | (bios_we_cpu_int & ce_hclk4);
assign bios_dw_cpu   = bios_we_rom ? bios_dout_rom : bios_dout_cpu;

// =========================================================================
// MEMORY: Audio CPU BIOS ROM ($F800-$FFFF, 2 KB)
// =========================================================================
wire [10:0] abios_addr_audio;
wire [7:0]  abios_q;

spram #(.address_width(11), .data_width(8)) abios_rom (
	.clock     (clk_sys),
	.enable    (1'b1),
	.address   (abios_addr_audio),
	.data      (abios_dout_rom),
	.wren      (abios_we_rom),
	.q         (abios_q)
);

// =========================================================================
// MEMORY: Work RAM (main CPU $0000-$5FFF, 24 KB = 15-bit address)
// =========================================================================
wire [14:0] ram_addr_cpu;
wire        ram_we_cpu;
wire [7:0]  ram_dw_cpu, ram_q;

spram #(.address_width(15), .data_width(8)) work_ram (
	.clock     (clk_sys),
	.enable    (1'b1),
	.address   (ram_addr_cpu),
	.data      (ram_dw_cpu),
	.wren      (ram_we_cpu),
	.q         (ram_q)
);

// =========================================================================
// MEMORY: Charram CPU-readback path ($6000-$BFFF, 24 KB total — 3 planes × 8 KB)
// =========================================================================
// 2026-05-17 — Render-side charram lives in video_fg.v as 3 separate planes
// (per MAME `charlayout` 3bpp). This SPRAM is the *CPU readback* copy for
// when the CPU reads from $6000-$BFFF.
// CHARRAM-CPU-RW-FIX-2026-06-07: WAS 8 KB aliasing all 3 planes (assumed "BIOS doesn't read charram
// back" — FALSE: the loaded GAME's $4A7D RLE decompressor reads its source from charram ($79B4),
// so the 8 KB alias corrupted that read -> runaway copy -> stack trample -> $0000 jam -> white screen).
// Now a LINEAR 24 KB window (addr = cpu_addr-$6000 from decocass.v) so writes/reads round-trip exactly.
// (32 KB BRAM; uses $0000-$5FFF. Render side in video_fg.v is independent and unchanged.)
// DIAG-REVERT: original 13-bit (8 KB) form below.
// wire [12:0] charram_addr_cpu;
wire [14:0] charram_addr_cpu;
wire        charram_we_p0, charram_we_p1, charram_we_p2;
wire        charram_we_any = charram_we_p0 | charram_we_p1 | charram_we_p2;
wire [7:0]  charram_dw_cpu, charram_q;

// spram #(.address_width(13), .data_width(8)) charram (   // DIAG-REVERT: original 8 KB
spram #(.address_width(15), .data_width(8)) charram (
	.clock     (clk_sys),
	.enable    (1'b1),
	.address   (charram_addr_cpu),
	.data      (charram_dw_cpu),
	.wren      (charram_we_any),
	.q         (charram_q)
);

// =========================================================================
// MEMORY: FG Video RAM ($C000-$C3FF + mirror $C800-$CBFF, 1 KB = 10-bit)
// =========================================================================
wire [9:0]  fgvram_addr_cpu;
wire        fgvram_we_cpu;
wire [7:0]  fgvram_dw_cpu, fgvram_q;

dpram #(.address_width(10), .data_width(8)) fgvram (
	.clock_a   (clk_sys),
	.enable_a  (1'b1),
	.address_a (fgvram_addr_cpu),
	.data_a    (fgvram_dw_cpu),
	.wren_a    (fgvram_we_cpu),
	.q_a       (fgvram_q),
	.clock_b   (clk_sys),
	.enable_b  (1'b1),
	.address_b (fgvram_addr_gfx),
	.data_b    (8'h00),
	.wren_b    (1'b0),
	.q_b       (fgvram_q_gfx)
);

// =========================================================================
// MEMORY: Color RAM ($C400-$C7FF + mirror $CC00-$CFFF, 1 KB = 10-bit)
// =========================================================================
wire [9:0]  colram_addr_cpu;
wire        colram_we_cpu;
wire [7:0]  colram_dw_cpu, colram_q;

dpram #(.address_width(10), .data_width(8)) colram (
	.clock_a   (clk_sys),
	.enable_a  (1'b1),
	.address_a (colram_addr_cpu),
	.data_a    (colram_dw_cpu),
	.wren_a    (colram_we_cpu),
	.q_a       (colram_q),
	.clock_b   (clk_sys),
	.enable_b  (1'b1),
	.address_b (colram_addr_gfx),
	.data_b    (8'h00),
	.wren_b    (1'b0),
	.q_b       (colram_q_gfx)
);

// =========================================================================
// MEMORY: Tileram ($D000-$D7FF, 2 KB = 11-bit)
// =========================================================================
wire [10:0] tilram_addr_cpu;
wire        tilram_we_cpu;
wire [7:0]  tilram_dw_cpu, tilram_q;

dpram #(.address_width(11), .data_width(8)) tilram (
	.clock_a   (clk_sys),
	.enable_a  (1'b1),
	.address_a (tilram_addr_cpu),
	.data_a    (tilram_dw_cpu),
	.wren_a    (tilram_we_cpu),
	.q_a       (tilram_q),
	.clock_b   (clk_sys),
	.enable_b  (1'b1),
	.address_b (tilram_addr_gfx),
	.data_b    (8'h00),
	.wren_b    (1'b0),
	.q_b       (tilram_q_gfx)
);

// =========================================================================
// MEMORY: Objectram ($D800-$DBFF, 1 KB = 10-bit)
// =========================================================================
wire [9:0]  objram_addr_cpu;
wire        objram_we_cpu;
wire [7:0]  objram_dw_cpu, objram_q;

dpram #(.address_width(10), .data_width(8)) objram (
	.clock_a   (clk_sys),
	.enable_a  (1'b1),
	.address_a (objram_addr_cpu),
	.data_a    (objram_dw_cpu),
	.wren_a    (objram_we_cpu),
	.q_a       (objram_q),
	.clock_b   (clk_sys),
	.enable_b  (1'b1),
	.address_b (objram_addr_gfx),
	.data_b    (8'h00),
	.wren_b    (1'b0),
	.q_b       (objram_q_gfx)
);

// =========================================================================
// MEMORY: Palette RAM ($E000-$E0FF, 256 bytes = 8-bit)
// =========================================================================
wire [7:0]  palram_addr_cpu;
wire        palram_we_cpu;
wire [7:0]  palram_dw_cpu, palram_q;
wire [7:0]  palram_addr_video;
wire [7:0]  palram_q_video;

dpram #(.address_width(8), .data_width(8)) palram (
	.clock_a   (clk_sys),
	.enable_a  (1'b1),
	.address_a (palram_addr_cpu),
	.data_a    (palram_dw_cpu),
	.wren_a    (palram_we_cpu),
	.q_a       (palram_q),
	.clock_b   (clk_sys),
	.enable_b  (1'b1),
	.address_b (palram_addr_video),
	.data_b    (8'h00),
	.wren_b    (1'b0),
	.q_b       (palram_q_video)
);

// =========================================================================
// MAIN CPU: DECO-222 @ 750 kHz (ce_hclk4 = HCLK4, per MAME decocass.cpp:1018)
// =========================================================================
wire [15:0] cpu_addr;
wire [7:0]  cpu_dout;
wire        cpu_rw_n, cpu_sync;

// Write strobes from decocass
wire cpu_we_ram, cpu_we_charram, cpu_we_fgvram, cpu_we_colram;
wire cpu_we_tilram, cpu_we_objram, cpu_we_palram;
wire cpu_we_e3xx, cpu_we_e4xx, cpu_we_e414, cpu_we_e5xx, cpu_re_e5xx;
wire cpu_we_e6xx, cpu_we_e7xx, cpu_re_e700, cpu_re_e701;

// Control register outputs
wire [7:0] mode_set_reg, back_h_shift_reg, back_vl_shift_reg, back_vr_shift_reg;
wire [7:0] part_h_shift_reg, part_v_shift_reg, color_center_bot_reg;
wire [7:0] color_missiles_reg;   // MISSILES-IMPL-2026-06-28: $E302 missile color latch
wire [7:0] center_h_shift_space_reg, center_v_shift_reg, coin_counter_reg, nmi_reset_reg;

// Main CPU memmap decoder
decocass decocass_inst (
	.clk_sys           (clk_sys),
	.ce_main           (ce_hclk4),        // 750 kHz CPU clock (HCLK4 per MAME decocass.cpp:1018)
	.reset             (reset),
	.cpu_addr          (cpu_addr),
	.cpu_dout          (cpu_dout),
	.cpu_rw_n          (cpu_rw_n),
	.cpu_sync          (cpu_sync),
	.cpu_we_ram        (cpu_we_ram),
	.cpu_we_charram    (cpu_we_charram),
	.cpu_we_fgvram     (cpu_we_fgvram),
	.cpu_we_colram     (cpu_we_colram),
	.cpu_we_tilram     (cpu_we_tilram),
	.cpu_we_objram     (cpu_we_objram),
	.cpu_we_palram     (cpu_we_palram),
	.cpu_we_e3xx       (cpu_we_e3xx),
	.cpu_we_e4xx       (cpu_we_e4xx),
	.cpu_we_e414       (cpu_we_e414),
	.cpu_we_e5xx       (cpu_we_e5xx),
	.cpu_re_e5xx       (cpu_re_e5xx),
	.cpu_we_e6xx       (cpu_we_e6xx),
	.cpu_we_e7xx       (cpu_we_e7xx),
	.cpu_re_e700       (cpu_re_e700),
	.cpu_re_e701       (cpu_re_e701),
	.sound_data        (sound_data),
	.sound_ack         (sound_ack),
	.e5xx_dongle_q     (e5xx_to_cpu),
	.input_q           (input_q),
	.bios_q            (bios_q),
	.ram_q             (ram_q),
	.charram_q         (charram_q),
	.fgvram_q          (fgvram_q),
	.colram_q          (colram_q),
	.tilram_q          (tilram_q),
	.objram_q          (objram_q),
	.palram_q          (palram_q),
	// DIPDEFAULT-FORCE-2026-06-03: the MRA <switches> default isn't auto-loading sw[2], so
	// force "Type of Tape" = MD(Small) (DSW1 bits 5,4 = 11) -> BIOS takes the priming path
	// without an OSD set every boot. Only MD-Small boots; revert once the MRA default is fixed.
	// BIT31-FIX-2026-06-29: DSW1/DSW2 byte-swapped (Country Code off bit 31; see sw[] note above). REVERT: uncomment.
	// .dsw1              (sw[2] | 8'h30),
	// .dsw2              (sw[3]),
	.dsw1              (sw[3] | 8'h30),
	.dsw2              (sw[2]),
	.vblank            (video_vblank),
	// CONTROLS-FIX-2026-06-08: coin moved to joy[6] to match new CONF_STR (Coin=bit6).
	// NOTE: coin_in feeds the MAIN-CPU NMI — the ONLY joystick line with a path to the loader.
	// If the loader regresses on this build, flip back to the commented line below (joy[14]) to
	// isolate — no rebuild-from-memory needed:
	// .coin_in           (joystick_0[14] | joystick_1[14]),  // P1 or P2 coin → main-CPU NMI (MAME decocass_m.cpp:155-159)
	.coin_in           (joystick_0[6] | joystick_1[6]),  // P1/P2 coin → main-CPU NMI
	.ram_addr_w        (ram_addr_cpu),
	.ram_we_w          (ram_we_cpu),
	.ram_dw            (ram_dw_cpu),
	.charram_addr_w    (charram_addr_cpu),
	.charram_we_p0     (charram_we_p0),
	.charram_we_p1     (charram_we_p1),
	.charram_we_p2     (charram_we_p2),
	.charram_dw        (charram_dw_cpu),
	.fgvram_addr_w     (fgvram_addr_cpu),
	.fgvram_we_w       (fgvram_we_cpu),
	.fgvram_dw         (fgvram_dw_cpu),
	.colram_addr_w     (colram_addr_cpu),
	.colram_we_w       (colram_we_cpu),
	.colram_dw         (colram_dw_cpu),
	.tilram_addr_w     (tilram_addr_cpu),
	.tilram_we_w       (tilram_we_cpu),
	.tilram_dw         (tilram_dw_cpu),
	.objram_addr_w     (objram_addr_cpu),
	.objram_we_w       (objram_we_cpu),
	.objram_dw         (objram_dw_cpu),
	.palram_addr_w     (palram_addr_cpu),
	.palram_we_w       (palram_we_cpu),
	.palram_dw         (palram_dw_cpu),
	.bios_addr_w       (bios_addr_cpu_dec),
	.bios_we_w         (bios_we_cpu_int),
	.bios_dw           (bios_dout_cpu),
	.mode_set_reg      (mode_set_reg),
	.back_h_shift_reg  (back_h_shift_reg),
	.back_vl_shift_reg (back_vl_shift_reg),
	.back_vr_shift_reg (back_vr_shift_reg),
	.part_h_shift_reg  (part_h_shift_reg),
	.part_v_shift_reg  (part_v_shift_reg),
	.color_center_bot_reg (color_center_bot_reg),
	.color_missiles_reg (color_missiles_reg),
	.center_h_shift_space_reg (center_h_shift_space_reg),
	.center_v_shift_reg    (center_v_shift_reg),
	.coin_counter_reg      (coin_counter_reg),
	.nmi_reset_reg         (nmi_reset_reg)
);

// =========================================================================
// MCU: i8041 + Program Memory + Tape Interface (tasks 15-17)
// =========================================================================
wire [7:0]  mcu_p1_out, mcu_p2_out, mcu_p1_in, mcu_p2_in;
wire        mcu_t0, mcu_t1;
wire [7:0]  mcu_host_dout;
wire [7:0]  mcu_host_sts;       // DBBSTS exposure 2026-05-30: real STATUS reg from the i8041 core
wire        mcu_host_dout_oe;
wire        tape_motor_on, tape_direction;
wire [1:0]  tape_speed_select;
wire        tape_data, tape_clock, tape_bot, tape_eot;

// i8041 MCU + program memory
wire [10:0] mcu_pmem_addr;   // DIAG-2026-06-03: 8041 program counter for the handshake probe
wire [7:0]  mcu_dmem_r3, mcu_dmem_r5, mcu_dmem_r1;  // DIAG-REVERT-2026-06-05: rb0 r3/r5/r1 taps for the $317 probe
i8041_top i8041_inst (
	.clk_sys         (clk_sys),
	.ce_hclk         (ce_hclk),
	.clk_8041        (clk_8041),
	.reset_n         (~reset),
	.cs_n            (mcu_cs_n),
	.rd_n            (mcu_rd_n),
	.wr_n            (mcu_wr_n),
	.a0              (mcu_a0),
	.host_din        (mcu_host_din),
	.host_dout       (mcu_host_dout),
	.host_sts        (mcu_host_sts),       // DBBSTS exposure 2026-05-30
	.host_dout_oe    (mcu_host_dout_oe),
	.sync_o          (),
	.t0_i            (mcu_t0),
	.t1_i            (mcu_t1),
	.p1_i            (mcu_p1_in),
	.p1_o            (mcu_p1_out),
	.p1_low_imp      (),
	.p2_i            (mcu_p2_in),
	.p2_o            (mcu_p2_out),
	.p2l_low_imp     (),
	.p2h_low_imp     (),
	.prog_n          (),
	.rom_we          (mcurom_we),
	.rom_addr_w      (mcurom_addr),
	.rom_data_w      (mcurom_dout),
	.pmem_addr_o     (mcu_pmem_addr),
	// DIAG-REVERT-2026-06-05: rb0 r3/r5/r1 taps for the $317 byte-assembly probe
	.dmem_r3_o       (mcu_dmem_r3),
	.dmem_r5_o       (mcu_dmem_r5),
	.dmem_r1_o       (mcu_dmem_r1)
);

// MCU ↔ Tape ↔ Main CPU interface
wire [7:0]  dongle_addr_lo;
wire        dongle_re, dongle_we;
wire [7:0]  dongle_dout;
wire [3:0]  dongle_din_low4;    // legacy 4-bit nibble (mcu_tape_iface still uses it)
wire [7:0]  dongle_din_full;    // 2026-05-18 — full 8-bit dongle output (per MAME)
wire        mcu_cs_n, mcu_rd_n, mcu_wr_n, mcu_a0;
wire [7:0]  mcu_host_din;  // CPU dout, latched by iface, presented to i8041

mcu_tape_iface mcu_tape_iface_inst (
	.clk_sys              (clk_sys),
	.ce_hclk              (ce_hclk),
	.ce_hclk1             (ce_hclk1),
	.ce_tape              (ce_tape),
	.reset                (reset),
	.mcu_p1_in            (mcu_p1_in),
	.mcu_p1_out           (mcu_p1_out),
	.mcu_p2_in            (mcu_p2_in),
	.mcu_p2_out           (mcu_p2_out),
	.mcu_t0               (mcu_t0),
	.mcu_t1               (mcu_t1),
	.mcu_cs_n             (mcu_cs_n),
	.mcu_rd_n             (mcu_rd_n),
	.mcu_wr_n             (mcu_wr_n),
	.mcu_a0               (mcu_a0),
	.mcu_dout             (mcu_host_din),
	.tape_motor_on        (tape_motor_on),
	.tape_direction       (tape_direction),
	.tape_speed_select    (tape_speed_select),
	.tape_data            (tape_data),
	.tape_clock           (tape_clock),
	.tape_bot             (tape_bot),
	.tape_eot             (tape_eot),
	.cpu_e5_re            (cpu_re_e5xx),
	.cpu_e5_we            (cpu_we_e5xx),
	.cpu_addr_lo          (cpu_addr[7:0]),
	.cpu_dout             (cpu_dout),
	.cpu_din              (e5xx_dongle),
	.mcu_host_dout        (mcu_host_dout),
	.mcu_host_dout_oe     (mcu_host_dout_oe),
	.dongle_addr_lo       (dongle_addr_lo),
	.dongle_re            (dongle_re),
	.dongle_we            (dongle_we),
	.dongle_dout          (dongle_dout),
	.dongle_din_low4      (dongle_din_low4)
);

// E5xx dongle response is automatically composed in mcu_tape_iface
// as {mcu_p2_out[7:4], dongle_din_low4}

// =========================================================================
// CASSETTE BRAM (64 KB) + cassette_loader (task 25 / phase 16)
// =========================================================================
// 64 KB covers all known DECO cassettes (largest is 0x10000 = 64 KB; most
// are 0x8000 = 32 KB). cassette_loader writes from hps_io on port A;
// tape_streamer reads on port B during playback.
wire [15:0] cass_load_addr;
wire [7:0]  cass_load_dout;
wire        cass_load_we;
wire [17:0] tape_image_size;

// 2026-05-18 — CRC16 table wires (computed by cassette_loader, read by tape_streamer)
wire [7:0]  crc_table_addr_w;
wire [15:0] crc_table_data_w;
wire        crc_table_we_w;

cassette_loader cassette_loader_inst (
    .clk_sys          (clk_sys),
    .ioctl_download   (ioctl_download),
    .ioctl_wr         (ioctl_wr),
    .ioctl_addr       (ioctl_addr),
    .ioctl_dout       (ioctl_dout),
    .ioctl_index      (ioctl_index),        // CASSETTE-IOCTL-INDEX-FIX-2026-08-04
    .bram_addr        (cass_load_addr),
    .bram_dout        (cass_load_dout),
    .bram_we          (cass_load_we),
    .crc_table_addr   (crc_table_addr_w),
    .crc_table_data   (crc_table_data_w),
    .crc_table_we     (crc_table_we_w),
    .image_size_bytes (tape_image_size)
);

// CRC16 lookup table — 256 blocks × 16 bits.
// Port A: written by cassette_loader as bytes stream in.
// Port B: read by tape_streamer when streaming CRC bytes.
wire [7:0]  crc_table_q_addr;
wire [15:0] crc_table_q;
dpram #(.address_width(8), .data_width(16)) crc16_table_bram (
    .clock_a  (clk_sys),
    .enable_a (1'b1),
    .wren_a   (crc_table_we_w),
    .address_a(crc_table_addr_w),
    .data_a   (crc_table_data_w),
    .q_a      (),
    .clock_b  (clk_sys),
    .enable_b (1'b1),
    .wren_b   (1'b0),
    .address_b(crc_table_q_addr),
    .data_b   (16'h0000),
    .q_b      (crc_table_q)
);

// Tape Streamer (task 16)
wire [17:0] tape_image_addr;
wire [7:0]  tape_image_q;

dpram #(.address_width(16), .data_width(8)) cassette_bram (
    .clock_a   (clk_sys),
    .enable_a  (1'b1),
    .address_a (cass_load_addr),
    .data_a    (cass_load_dout),
    .wren_a    (cass_load_we),
    .q_a       (),

    .clock_b   (clk_sys),
    .enable_b  (1'b1),
    .address_b (tape_image_addr[15:0]),
    .data_b    (8'h00),
    .wren_b    (1'b0),
    .q_b       (tape_image_q)
);

tape_streamer tape_streamer_inst (
	.clk_sys           (clk_sys),
	.ce_tape           (ce_tape),
	.reset             (reset),
	.image_addr        (tape_image_addr),
	.image_q           (tape_image_q),
	.image_size_bytes  (tape_image_size),
	.motor_on          (tape_motor_on),
	.direction         (tape_direction),
	.speed_select      (tape_speed_select),
	.crc_addr          (crc_table_q_addr),
	.crc_q             (crc_table_q),
	.tape_data         (tape_data),
	.tape_clock        (tape_clock),
	.tape_bot          (tape_bot),
	.tape_eot          (tape_eot)
);

// =========================================================================
// DONGLES (task 18 — mux; tasks 19-22 — type implementations)
// =========================================================================
wire [19:0] dprom_addr;       // 20-bit (1 MB) for the Darksoft multigame; legacy types use low bits
wire [7:0]  dprom_q;

dongle_mux dongle_mux_inst (
	.clk_sys           (clk_sys),
	.ce_hclk4          (ce_hclk4),
	.reset             (reset),
	.dongle_type       (dongle_type),
	.game_id           (game_id),
	.swap_mode         (swap_mode),
	.cpu_re            (dongle_re),
	.cpu_we            (dongle_we),
	.cpu_addr_lo       (dongle_addr_lo),
	.cpu_dout          (dongle_dout),
	.cpu_din_full      (dongle_din_full),       // 2026-05-18: 8-bit per MAME
	.dprom_addr        (dprom_addr),
	.dprom_q           (dprom_q),
	// 2026-05-18 — dongle reads MCU host-bus registers per MAME
	// `upi41_master_r(0)/(1)`. mcu_dbb_sts faked as OBF=mcu_host_dout_oe.
	.mcu_dbb_dout      (mcu_host_dout),
	// DBBSTS exposure 2026-05-30: real STATUS reg (sts/f1/f0/IBF/OBF) from the i8041 core —
	// was faked as {6'b0,IBF=0,OBF=host_dout_oe}. Needed for the BIOS<->MCU tape handshake.
	.mcu_dbb_sts       (mcu_host_sts),
	.mcu_status_d2     (mcu_p2_out[2]),
	.mcu_status_d0     (mcu_p2_out[0])
);

// Tie legacy `dongle_din_low4` to the low nibble of the 8-bit output
// (mcu_tape_iface still uses dongle_din_low4 for its cpu_din formula).
assign dongle_din_low4 = dongle_din_full[3:0];

// DONGLE BYPASS FIX 2026-05-30: the $E5xx read must go through the dongle on the DATA path.
// MAME decocass_e5xx_r: (offset & E5XX_MASK)==2 -> composite STATUS byte; else -> m_dongle_r(offset).
// e5xx_dongle (from mcu_tape_iface) already returns the correct STATUS byte for cpu_addr[1]==1, so
// keep it there; route cpu_addr[1]==0 (DATA) through dongle_mux's dongle_din_full (nodong/type1/
// type3 each handle their A0 split internally). Was: decocass.v fed raw e5xx_dongle, dongle ignored.
// OBF-GATE-2026-06-08: PROPER reset fix (replaces the E500-ZERO-TEST viability hack). PROVEN this session:
// the post-load $0582 check (lda $e500/cmp#0/bne→jmp$F000) reads $E500=$0E, and $0E == mcu_host_sts (the
// 8041 STATUS reg) with OBF=0 — i.e. the read is handing back STATUS, not a fresh DBBOUT byte, because the
// 8041 is IDLE (no output pending). MAME reads 0 there. FIX: $E500 (the MCU DATA reg, cpu_addr[1]==0) is
// only valid when the 8041 has actually pushed a fresh byte out => OBF (mcu_host_sts[0]) = 1; when OBF=0
// (idle, incl. the $0582 check) read 0. Block-load bytes are UNAFFECTED — each is read with OBF=1 (the
// 8041 OUT-DBB's then handshakes via REQ). This drops the rt_seen05E2 game-PC dependency and matches MAME's
// idle $E500=0. ⚠️ CONFIDENCE: MODERATE — assumes OBF still reads 1 when the 6502 samples cpu_din (OBF
// clears on the read's trailing edge). If the LOAD regresses (blocks read as 0), revert to E500-ZERO-TEST
// (proven to boot). DIAG-REVERT-2026-06-08: prior versions below, uncomment one to restore.
// assign e5xx_to_cpu = cpu_addr[1] ? e5xx_dongle : dongle_din_full;                       // pre-fix (raw)
// assign e5xx_to_cpu = (rt_seen05E2 && cpu_addr[1:0] == 2'b00) ? 8'h00                     // E500-ZERO-TEST (proven boot)
//                    : (cpu_addr[1] ? e5xx_dongle : dongle_din_full);
// E5XX-STATUS-ROUTING-FIX-2026-06-10: MAME decocass_e5xx_r returns the 8041/tape STATUS for $E5x2/3 on ALL dongle
// types incl. Darksoft (darksoft_r is the ELSE branch = offset 0/1 only; decocass_m.cpp:1200,1229). The "darksoft
// owns ALL $E5xx" bypass returned 0xFF for $E5x2/3 — boots the menu but STARVES the game LOAD (which polls $E5x2/3
// for REQ/EOT/ERR). Route STATUS to ALL types; dongle only on $E5x0/1. Half-fix/half-experiment: if the MENU
// regresses, that pins the real bug on our 8041 Darksoft STATUS — the SAME status path as the cassette block-15 freeze.
// DIAG-REVERT-2026-06-10: bypass below, uncomment to restore the menu-booting state:
// assign e5xx_to_cpu = (dongle_type == 4'd7) ? dongle_din_full
//                    : cpu_addr[1] ? e5xx_dongle
//                    : (mcu_host_sts[0] ? dongle_din_full : 8'h00);
// DONGLE-DATA-UNGATE-2026-06-27: MAME decocass_e5xx_r (decocass_m.cpp:1227-1232) returns m_dongle_r(offset)
// for $E5x0/1 on ALL dongle types — NO OBF / 8041-status gate. The OBF gate below forced $E5x0/1 to 0x00
// whenever OBF=0, which holds throughout type3 PROM-mode reads (data = m_donglerom[ctr], decocass_m.cpp:630,
// independent of the 8041) → BurgerTime's decrypt stream read back as 0x00 = garbage. Ungated now, matching
// the darksoft path and MAME. RISK: the $0582 idle check wants $E500==0 at idle; if it reboot-loops, the next
// bug is the 8041 idle DBBOUT value (oracle = Useful Information/cbtime-e500.hex / clocknch-e500.hex), NOT this gate.
// DIAG-REVERT-2026-06-27: original OBF-gated assign commented below — restore by uncommenting it + deleting the new one.
// assign e5xx_to_cpu = cpu_addr[1] ? e5xx_dongle                           // $E5x2/3 = STATUS byte, ALL types (MAME)
//                    : (dongle_type == 4'd7) ? dongle_din_full             // $E5x0/1 = Darksoft dongle (raw)
//                    : (mcu_host_sts[0] ? dongle_din_full : 8'h00);        // $E5x0/1 = legacy OBF-gated 8041 data
assign e5xx_to_cpu = cpu_addr[1] ? e5xx_dongle                           // $E5x2/3 = STATUS byte, ALL types (MAME)
                   : dongle_din_full;                                    // $E5x0/1 = dongle data, ALL types UNGATED (MAME m_dongle_r)

// UNIFIED dongle storage: ALL dongle types read from DDR3 (below). The legacy 4 KB BRAM is gone.
assign dprom_q = dprom_q_ddr;

// ============================================================================
// DDR3 dongle storage (Stage 2) — full 1 MB multigame dongle ROM via Sorgelig ddram.sv (rtl/mem/ddram.sv).
// Runs on clk_sys (= DDRAM_CLK) -> no clock-domain crossing. DDR byte address = dongle offset (base 0).
//  LOAD: ioctl index 1 streamed to DDR3, HPS throttled by ioctl_wait while each write is in flight.
//  READ: prefetch the byte at dprom_addr whenever it changes; the 6502 reads far slower than DDR latency.
// ============================================================================
assign DDRAM_CLK = clk_sys;
wire ddr_loading = ioctl_download;

// SDRAM-POR-2026-06-10: the dongle load FSM, the SDRAM controller's .init, AND the swatch capture flags must
// reset ONLY at FPGA config — NOT on status[0]/RESET/ioctl_download. PROOF they must: Row B b0 ("ioctl_download
// seen") read 0 while b6 ("dongle_type==7") read 1 — impossible unless a reset WIPED the sticky flags AFTER the
// download. That reset (RESET|status0|buttons1, asserted during/after the load per MiSTer "reset on ROM load")
// was holding the load FSM in reset through the WHOLE download (no writes landed) AND re-initing the SDRAM after.
// A one-time power-on reset fixes both: the load path runs through the load, SDRAM retains data across a game
// reset (no re-download), and the swatch captures download-time events without being wiped.
// (Earlier SDRAM-LOAD-RESET only dropped ioctl_download from this reset — not enough; status[0]/RESET also hit it.)
reg [3:0] sdram_por_cnt = 4'd0;
wire      sdram_ld_reset = ~&sdram_por_cnt;   // high ~15 clk_sys cycles after config, then low FOREVER
always @(posedge clk_sys) if (sdram_ld_reset) sdram_por_cnt <= sdram_por_cnt + 1'b1;

// DONGLE-INDEX1-REVERT-2026-06-10: dongle ROM back on its OWN ioctl_index==1 (matches rom_loader.v:164 + the
// MRA's original layout). The "index-0 @ $3000" experiment was a wrong turn taken off a MASKED c5 gauge — user
// confirms index 1 was never the problem. Stream is 0-based, so the dongle offset = ioctl_addr directly.
wire        dongle_ld      = (ioctl_index == 8'd1);
wire [27:0] dongle_ld_addr = {3'd0, ioctl_addr};

reg  [26:1] sd_addr;
reg  [15:0] sd_din;
reg  [1:0]  sd_bs;
reg         sd_rd, sd_wr, sd_refresh, sd_busy, sd_was_rd;
reg         sd_old_ready;   // SDRAM-HS-FIX-2026-06-10: track ready edges for the accept/complete handshake
reg  [9:0]  sd_refresh_cnt;
reg  [19:0] sd_last_addr;
reg  [7:0]  dprom_q_ddr;     // latched dongle byte (read result) — feeds dprom_q above
wire        sd_ready;
wire [15:0] sd_dout;

// Throttle the HPS while a dongle write is requested/in-flight (combinational so it lands in time).
assign ioctl_wait = sd_busy || (ioctl_wr && dongle_ld);

// SDRAM-HS-FIX-2026-06-10: proper ready-EDGE handshake — mirrors NeoGeo sdram_mux.sv, which drives this
// byte-identical Sorgelig controller. The OLD `else if (sd_ready)` sampled the controller's IDLE ready=1 the
// cycle AFTER issuing — before the op was even accepted — so reads latched STALE sd_dout (always FF, swatch
// c7=0) and writes freed sd_busy early (HPS throttle released too soon -> bytes dropped). Correct sequence:
// HOLD rd/wr until the controller accepts (ready 1->0), then COMPLETE (latch read data / free busy) when ready
// returns HIGH with the strobe already cleared. Refresh = a one-edge TOGGLE (fire-and-forget, no busy wait).
always @(posedge clk_sys) begin
	if (sdram_ld_reset) begin   // SDRAM-LOAD-RESET-2026-06-10: NOT `reset` — must run during ioctl_download
		sd_rd <= 0; sd_wr <= 0; sd_refresh <= 0; sd_busy <= 0; sd_was_rd <= 0;
		sd_last_addr <= 20'hFFFFF; sd_refresh_cnt <= 0; sd_old_ready <= 1'b1;
	end else begin
		sd_refresh_cnt <= sd_refresh_cnt + 1'b1;
		sd_old_ready   <= sd_ready;

		// Controller accepted the request (ready fell 1->0): drop the strobe so the op runs exactly once.
		if (sd_old_ready && !sd_ready) begin
			sd_rd <= 0;
			sd_wr <= 0;
		end

		if (sd_busy) begin
			// rd/wr COMPLETE = ready back HIGH with the strobe already cleared (it fell, then rose).
			if (sd_ready && !sd_rd && !sd_wr) begin
				if (sd_was_rd) dprom_q_ddr <= sd_last_addr[0] ? sd_dout[15:8] : sd_dout[7:0];
				sd_busy <= 0;
			end
		end else begin
			if (ioctl_wr && dongle_ld) begin                       // LOAD: byte -> 16-bit SDRAM
				sd_addr  <= dongle_ld_addr[20:1];
				sd_din   <= {ioctl_dout, ioctl_dout};
				sd_bs    <= dongle_ld_addr[0] ? 2'b10 : 2'b01;     // high/low byte lane
				sd_wr    <= 1; sd_busy <= 1; sd_was_rd <= 0;
			end else if (!ioctl_download && dprom_addr[19:0] != sd_last_addr) begin   // READ: prefetch
				sd_last_addr <= dprom_addr[19:0];
				sd_addr  <= {7'd0, dprom_addr[19:1]};
				sd_rd    <= 1; sd_busy <= 1; sd_was_rd <= 1;
			end else if (&sd_refresh_cnt) begin                    // periodic AUTO_REFRESH: one-edge toggle
				sd_refresh <= ~sd_refresh;
			end
		end
	end
end

sdram sdram_dongle (
	.init       (sdram_ld_reset),   // SDRAM-LOAD-RESET-2026-06-10: init early, stay ready through ioctl_download
	.clk        (clk_sys),
	.SDRAM_DQ   (SDRAM_DQ),   .SDRAM_A    (SDRAM_A),    .SDRAM_DQML (SDRAM_DQML), .SDRAM_DQMH (SDRAM_DQMH),
	.SDRAM_BA   (SDRAM_BA),   .SDRAM_nCS  (SDRAM_nCS),  .SDRAM_nWE  (SDRAM_nWE),  .SDRAM_nRAS (SDRAM_nRAS),
	.SDRAM_nCAS (SDRAM_nCAS), .SDRAM_CKE  (SDRAM_CKE),  .SDRAM_CLK  (SDRAM_CLK),  .SDRAM_EN   (1'b1),
	.sel        (1'b1),
	.addr       (sd_addr),    .dout (sd_dout), .din (sd_din),
	.wr         (sd_wr),      .bs   (sd_bs),   .rd  (sd_rd),  .ready (sd_ready), .refresh (sd_refresh),
	.cpsel (1'b0), .cpaddr (26'd0), .cpdin (16'd0), .cprd (), .cpreq (1'b0), .cpbusy ()
);

// =========================================================================
// INPUT MUX (task 23)
// =========================================================================
wire [7:0]  input_q;

// Prepare input signals from joysticks/buttons (inverted per MAME)
wire [7:0] in0, in1, in2;
// CONTROLS-ACTIVEHIGH-FIX-2026-06-10: MAME decocass IN0/IN1 are ACTIVE-HIGH (decocass.cpp:154-159, IP_ACTIVE_HIGH;
// bit0=R 1=L 2=U 3=D 4=B1 5=B2, bits6-7 UNUSED). Ours was ~joystick = active-low, so IDLE read as "all pressed" ->
// menu inputs felt "stuck on" / wouldn't settle (user symptom: moves the right direction but won't stick). Directions
// already map 1:1 (user-confirmed correct), so ONLY the polarity (+ unused [7:6] -> 0) changes. in2 left as-is.
// ORIGINAL (active-low = stuck-on), uncomment to restore:
// assign in0 = {2'b11, ~joystick_0[5:0]};
// assign in1 = {2'b11, ~joystick_1[5:0]};
// CONTROLS-UD-SWAP-2026-06-10: MiSTer joystick [3]=Up/[2]=Down, MAME IN0 bit2=Up/bit3=Down (decocass.cpp:156-157)
// -> swap joystick bits 2,3 into in0[2]/[3]. (User after the active-high fix: "up is down, down is up".)
// Pre-swap: assign in0 = {2'b00, joystick_0[5:0]};  /  assign in1 = {2'b00, joystick_1[5:0]};
assign in0 = {2'b00, joystick_0[5:4], joystick_0[2], joystick_0[3], joystick_0[1:0]};  // P1 R/L/U/D/B1/B2 active-high, U/D fixed
assign in1 = {2'b00, joystick_1[5:4], joystick_1[2], joystick_1[3], joystick_1[1:0]};  // P2 R/L/U/D/B1/B2 active-high, U/D fixed
assign in2 = {~joystick_0[6], ~joystick_1[6], 1'b0,
              joystick_0[8]|joystick_1[8], joystick_0[7]|joystick_1[7], 3'b000}; // Coins, starts (stray '-' from HEAD removed)

inputs inputs_inst (
	.clk_sys          (clk_sys),
	.ce_hclk1         (ce_hclk1),
	.reset            (reset),
	.cpu_addr_lo      (cpu_addr[7:0]),
	.cpu_we_e6xx      (cpu_we_e6xx),
	.cpu_rw_n         (cpu_rw_n),
	.in0              (in0),
	.in1              (in1),
	.in2              (in2),
	// BIT31-FIX-2026-06-29: DSW1/DSW2 byte-swapped. REVERT: uncomment originals.
	// .dsw1             (sw[2]),
	// .dsw2             (sw[3]),
	.dsw1             (sw[3]),
	.dsw2             (sw[2]),
	.vblank           (video_vblank),
	.mcu_p2_low4      (mcu_p2_out[3:0]),
	.input_q          (input_q)
);

// =========================================================================
// WATCHDOG (task 23)
// =========================================================================
watchdog watchdog_inst (
	.clk_sys          (clk_sys),
	.ce_hclk1         (ce_hclk1),
	.reset            (reset),
	.vblank_pulse     (~video_vblank),
	.wd_count_w       (cpu_we_e3xx && cpu_addr[0] == 1'b0),
	.wd_flip_w        (cpu_we_e3xx && cpu_addr[0] == 1'b1),
	.cpu_dout         (cpu_dout),
	// BIT31-FIX-2026-06-29: DSW1 byte-swapped to sw[3]. REVERT: uncomment original.
	// .dsw1             (sw[2]),
	.dsw1             (sw[3]),
	.wd_reset         (),
	.flip_screen      ()
);

// =========================================================================
// AUDIO CPU (task 12)
// =========================================================================
wire [7:0]  audio_cpu_addr, audio_cpu_dout, audio_cpu_din;
wire        audio_cpu_rw_n;
wire        ay1_data_we, ay1_addr_we, ay2_data_we, ay2_addr_we;
wire [7:0]  ay_data_out;

// Sound latch ↔ audio CPU glue wires
wire        audio_to_main_we;
wire        audio_from_main_re;
wire [7:0]  audio_to_main_data;
wire [7:0]  main_to_audio_data;
wire        audio_irq;
reg         audio_nmi_enable_reg;   // $E416 bit 0 — main CPU's master enable for audio NMI

// AUDIO-ALIVE-PROBE-2026-06-11: liveness taps from audio_cpu + ay8910_pair (revert: delete this, the
// .dbg_* port connections, the sticky-flag block after ay8910_pair, and the swatch re-point near L1740).
wire [15:0] aud_pc;
wire        aud_sync, aud_nmi_n, aud_nmi_en, aud_ay_pulse;

audio_cpu audio_cpu_inst (
	.clk_sys      (clk_sys),
	.ce_audio     (ce_audio),
	.reset        (reset),
	.ce_pix       (ce_pix),
	.audio_irq_set(audio_irq),
	.hcounter_eq_0(hcnt == 9'h000),
	.vcounter     (vcnt),
	.rom_we       (abios_we_rom),
	.rom_addr_w   (abios_addr_rom),
	.rom_data_w   (abios_dout_rom),
	.ay1_data_we  (ay1_data_we),
	.ay1_addr_we  (ay1_addr_we),
	.ay2_data_we  (ay2_data_we),
	.ay2_addr_we  (ay2_addr_we),
	.ay_data_out  (ay_data_out),
	.sound_to_main_we(audio_to_main_we),
	.sound_from_main_re(audio_from_main_re),
	.sound_to_main(audio_to_main_data),
	.sound_from_main(main_to_audio_data),
	.audio_nmi_master_enable(audio_nmi_enable_reg),
	// AUDIO-ALIVE-PROBE-2026-06-11
	.dbg_pc      (aud_pc),
	.dbg_sync    (aud_sync),
	.dbg_nmi_n   (aud_nmi_n),
	.dbg_nmi_en  (aud_nmi_en)
);

// =========================================================================
// AUDIO NMI ENABLE GATE (from main CPU $E416 write)
// =========================================================================
// Per MAME decocass.cpp, audio NMI enable is set by main CPU writes to $E416.
// This implements a simple register that latches the NMI enable gate per bit 0 of the write.
wire cpu_we_e416 = (cpu_addr == 16'hE416 && !cpu_rw_n && ce_hclk4);

always @(posedge clk_sys) begin
	if (reset)
		audio_nmi_enable_reg <= 1'b0;
	else if (cpu_we_e416)
		audio_nmi_enable_reg <= cpu_dout[0];
end

// =========================================================================
// SOUND LATCHES (task 14) — $E414, $E700, $E701
// =========================================================================
wire [7:0]  sound_data, sound_ack;

sound_latches sound_latches_inst (
	.clk_sys       (clk_sys),
	.reset         (reset),
	.ce_main       (ce_hclk1),
	.main_we_e414  (cpu_we_e414),
	.main_re_e700  (cpu_re_e700),
	.main_re_e701  (cpu_re_e701),
	.main_dout     (cpu_dout),
	.main_din_e700 (sound_data),
	.main_din_e701 (sound_ack),
	.ce_audio      (ce_audio),
	.audio_we_c000 (audio_to_main_we),
	.audio_re_a000 (audio_from_main_re),
	.audio_dout    (audio_to_main_data),
	.audio_din_a000(main_to_audio_data),
	.audio_irq     (audio_irq)
);

// =========================================================================
// AY-3-8910 PAIR (task 13)
// =========================================================================
wire signed [15:0] ay_left, ay_right;

ay8910_pair ay8910_pair_inst (
	.clk_sys      (clk_sys),
	.ce_hclk2     (ce_hclk2),
	.ce_audio     (ce_audio),
	.reset        (reset),
	.ay1_data_we  (ay1_data_we),
	.ay1_addr_we  (ay1_addr_we),
	.ay2_data_we  (ay2_data_we),
	.ay2_addr_we  (ay2_addr_we),
	.audio_dout   (ay_data_out),
	.sound_out    ({ay_right, ay_left}),
	.dbg_ay_pulse (aud_ay_pulse)   // AUDIO-ALIVE-PROBE-2026-06-11
);

// AUDIO-ALIVE-PROBE-2026-06-11: sticky-from-reset liveness flags + per-frame PC snapshot for the swatch.
// Revert: delete this whole block (and the swatch re-point near L1740, the dbg_* ports/wires).
//  aud_flags bits (swatch Row A, cell0=bit0=LSB, white=set):
//   c0 ranBIOS($Fxxx) c1 ranRAM($0xxx) c2 nmiEN c3 nmiFIRED c4 mainIRQ c5 $A000read c6 AYwrite c7 AYpulse
reg al_ranrom, al_ranram, al_nmien, al_nmifired, al_irq, al_a000, al_aywr, al_aypulse;
reg [15:0] aud_pc_live, aud_pc_snap;
always @(posedge clk_sys) begin
	if (reset) begin
		al_ranrom<=1'b0; al_ranram<=1'b0; al_nmien<=1'b0; al_nmifired<=1'b0;
		al_irq<=1'b0; al_a000<=1'b0; al_aywr<=1'b0; al_aypulse<=1'b0;
	end else begin
		if (aud_pc[15:11]==5'h1F)                            al_ranrom   <= 1'b1;  // fetched audio BIOS $F800+
		if (aud_pc[15:12]==4'h0)                             al_ranram   <= 1'b1;  // touched work RAM $0xxx
		if (aud_nmi_en)                                      al_nmien    <= 1'b1;  // BIOS armed NMI ($1000-17FF)
		if (~aud_nmi_n)                                      al_nmifired <= 1'b1;  // NMI line asserted
		if (audio_irq)                                       al_irq      <= 1'b1;  // main sent a sound cmd
		if (audio_from_main_re)                              al_a000     <= 1'b1;  // audio read $A000 (handshake)
		if (ay1_data_we|ay1_addr_we|ay2_data_we|ay2_addr_we) al_aywr     <= 1'b1;  // AY register write decoded
		if (aud_ay_pulse)                                    al_aypulse  <= 1'b1;  // jt49 saw the write pulse
	end
	if (aud_sync)                  aud_pc_live <= aud_pc;       // track live opcode-fetch PC
	if (hcnt==9'd0 && vcnt==9'd8)  aud_pc_snap <= aud_pc_live;  // freeze once per frame (stable display)
end
wire [7:0] aud_flags = {al_aypulse, al_aywr, al_a000, al_irq, al_nmifired, al_nmien, al_ranram, al_ranrom};

// =========================================================================
// VIDEO SUBSYSTEM (tasks 07-11)
// =========================================================================
wire [4:0]  fg_pen, spr_pen, mis_pen;
wire [5:0]  bg_pen;   // PALETTE-BG-COLORSET-2026-06-28: 6-bit (BG color-set 5 reaches pens 40-47, the upper/bitswapped half)
wire        fg_opaque, bg_opaque, spr_opaque, mis_opaque;

// Video timing
video_timing video_timing_inst (
	.clk_sys      (clk_sys),
	.ce_pix       (ce_pix),
	.reset        (reset),
	.hsync        (video_hsync),
	.vsync        (video_vsync),
	.hblank       (video_hblank),
	.vblank       (video_vblank),
	.hcnt         (hcnt),
	.vcnt         (vcnt),
	.vsync_pulse  ()
);

// FG tilemap (task 08)
video_fg video_fg_inst (
	.clk_sys           (clk_sys),
	.ce_pix            (ce_pix),
	.hcnt              (hcnt),
	.vcnt              (vcnt),
	.cpu_we_fg         (cpu_we_fgvram),
	.cpu_we_col        (cpu_we_colram),
	.cpu_we_char_p0    (charram_we_p0),
	.cpu_we_char_p1    (charram_we_p1),
	.cpu_we_char_p2    (charram_we_p2),
	.cpu_addr          (cpu_addr[12:0]),       // 13-bit (covers 8 KB plane + 1 KB fg/col)
	.cpu_dout          (cpu_dout),
	.color_center_bot  (color_center_bot_reg), // $E410 — bit 0 → FG color
	.fg_pen            (fg_pen),
	.fg_opaque         (fg_opaque)
);

// BG tilemaps (task 09)
video_bg video_bg_inst (
	.clk_sys           (clk_sys),
	.ce_pix            (ce_pix),
	.hcnt              (hcnt),
	.vcnt              (vcnt),
	.back_h_shift      (back_h_shift_reg),
	.back_vl_shift     (back_vl_shift_reg),
	.back_vr_shift     (back_vr_shift_reg),
	.mode_set          (mode_set_reg),
	.color_center_bot  (color_center_bot_reg),
	.cpu_we_tile       (cpu_we_tilram),
	.cpu_addr_tile     (cpu_addr[10:0]),
	.cpu_dout          (cpu_dout),
	.bg_pen            (bg_pen),
	.bg_opaque         (bg_opaque)
);

// Sprites (task 10)
// SPRITE-DESC-SWIZZLE-FIX-2026-06-11: the sprite descriptor mirror must be a TRUE copy of fgvideoram, which
// applies the $C800-$CBFF mirror-swizzle (video_fg.v:71-74 / MAME mirrorvideoram_w: swap upper-5/lower-5 bits).
// Feeding the RAW cpu_addr[9:0] left the descriptor BRAM un-swizzled → mirror-region descriptor writes landed at
// the wrong address → garbage descriptors → garbage sprites (the top-right "numbers"). No-op for direct writes.
wire [9:0] spr_desc_wr_addr = cpu_addr[11] ? {cpu_addr[4:0], cpu_addr[9:5]} : cpu_addr[9:0];
video_sprites video_sprites_inst (
	.clk_sys           (clk_sys),
	.ce_pix            (ce_pix),
	.hcnt              (hcnt),
	.vcnt              (vcnt),
	.color_center_bot  (color_center_bot_reg),
	.cpu_we_spr        (cpu_we_fgvram),
	// SPRITE-DESC-SWIZZLE-FIX-2026-06-11: was `.cpu_spr_addr(cpu_addr[9:0])` (raw). DIAG-REVERT: restore raw.
	.cpu_spr_addr      (spr_desc_wr_addr),
	.cpu_spr_dout      (cpu_dout),
	.cpu_we_char_p0    (charram_we_p0),    // SPRITE-REWRITE-2026-06-10: charram gfx mirror (sprites share charram w/ FG)
	.cpu_we_char_p1    (charram_we_p1),
	.cpu_we_char_p2    (charram_we_p2),
	.cpu_char_addr     (cpu_addr[12:0]),
	.cpu_char_dout     (cpu_dout),
	.spr_pen           (spr_pen),
	.spr_priority      (spr_opaque)
);

// Missiles (task 10)
// MISSILES-DESC-SWIZZLE-FIX-2026-06-28: missile descriptors live in COLORRAM, which applies the same $C800
// mirror-swizzle as fgvideoram (video_fg.v write_addr_eff). The mirror was fed RAW cpu_addr[9:0] → mirror-region
// descriptor writes landed at the wrong address → garbage/off-screen missile positions → missiles invisible.
// SAME root + fix as the sprite descriptor mirror (SPRITE-DESC-SWIZZLE-FIX). No-op for direct $C4xx writes.
wire [9:0] mis_desc_wr_addr = cpu_addr[11] ? {cpu_addr[4:0], cpu_addr[9:5]} : cpu_addr[9:0];
video_missiles video_missiles_inst (
	.clk_sys           (clk_sys),
	.ce_pix            (ce_pix),
	.hcnt              (hcnt),
	.vcnt              (vcnt),
	.color_missiles    (color_missiles_reg),   // MISSILES-IMPL-2026-06-28: was 8'h00 (stubbed)
	.cpu_we_mis        (cpu_we_colram),
	// MISSILES-DESC-SWIZZLE-FIX-2026-06-28: was `.cpu_mis_addr(cpu_addr[9:0])` (raw). DIAG-REVERT: restore raw.
	.cpu_mis_addr      (mis_desc_wr_addr),
	.cpu_mis_dout      (cpu_dout),
	.mis_pen           (mis_pen),
	.mis_priority      (mis_opaque)
);

// Internal core RGB (8-bit each) — palette upper nibble + replicated lower
wire [3:0] core_r_hi, core_g_hi, core_b_hi;
wire [5:0] mixer_pen;
wire       mixer_modulate;
wire [7:0] core_r = {core_r_hi, core_r_hi};
wire [7:0] core_g = {core_g_hi, core_g_hi};
wire [7:0] core_b = {core_b_hi, core_b_hi};

// ===== DIAG-REVERT-2026-06-03e: 8041-PC + HANDSHAKE PROBE (delete this block + restore the
//       pause .r/.g/.b ports below, AND the i8041_top pmem_addr_o port, to revert). PAST 59;
//       the 8041 RECEIVES the cmd (cmd_seen+ibf) but never answers (obf/req dark). This shows
//       the 8041's OWN program counter + execution milestones to split "MCU not running" vs
//       "MCU running but mis-handling the command". mcu_pmem_addr = the 8041 pmem fetch addr.
// THREE rows, 8 cells, 16px, leftmost cell = MSB / first milestone. white=1.
//   ROW 1 (vcnt 16-31): LIVE $E502 status byte the BIOS polls (D7 left -> D0 right):
//        cell0 present(0=yes) 1=(1) 2=(1) 3 bot_eot 4 ERR/ 5 EOT/ 6 FNO/ 7 REQ/
//        ACTIVE-LOW "/" bits: 0 = ASSERTED. BIOS waits for FNO/=0 (cmd ack), then REQ/=0 (data ready).
//   ROW 2 (vcnt 40-55): TAPE-DATA-PATH activity, cell0..7 (sticky; white=seen-at-least-once):
//        0 $022(8041 reading cmds=alive) 1 $0FB(8041 dispatching) 2 motor_on(P1 motor commanded)
//        3 tape_clock TOGGLED(streamer advancing) 4 tape_data TOGGLED(bits present)
//        5 OUT-DBB($2C8|$3EF=8041 sent a byte) 6 OBF(byte avail to 6502) 7 6502 read $E502
//   READ (counter-never-appears = no chunks loading): the first DARK cell localizes the break --
//     cell2 motor DARK       => 8041 never commands the motor on a read (firmware/P1 decode).
//     cell2 lit, cell3/4 DARK => motor on but streamer NOT advancing (tape_streamer/ce_tape/EOT).
//     cell3/4 lit, cell5 DARK => tape bits flow but 8041 never OUT-DBBs (8041 tape-read assembly).
//     cell5 lit, cell6/7 DARK => 8041 sends bytes but 6502 never sees them (DBB/status path).
//   ROW 3 (vcnt 64-79): FIRST command byte the 8041 received. MSB(bit7) leftmost. $33 = priming.
// READ: ROW1 flickering = MCU running. ROW2 is the tape pipeline L->R; first dark cell = the break.
reg [10:0] diag_mcupc;
reg [7:0]  diag_cmdval;   // byte the 8041 received on the last command write ($33 expected)
reg diag_m022, diag_m0ed, diag_m0fb, diag_m170, diag_m0f3, diag_m003;
reg diag_we501, diag_cmd_seen, diag_ibf, diag_obf, diag_req, diag_motor, diag_we500, diag_re502;
// TAPE-ACTIVITY-PROBE-2026-06-04: tape data-path view (motor / clock-toggle / data-toggle / OUT-DBB)
reg diag_outdbb, diag_clk_hi, diag_clk_lo, diag_dat_hi, diag_dat_lo;
// READ-PIPELINE-PROBE-2026-06-04: trace WHERE the tape read dies + capture block-0 bytes.
//   ROW1 milestones, ROW2=$0300[0] (expect 'H'=$48), ROW3=$033C ($0300+60, expect $8E=142).
reg diag_m2e8, diag_m1a7, diag_m007, diag_rd_e500, diag_wr_0300;
reg [7:0] diag_b0, diag_b60;
// READ-PIPELINE-PROBE rev2 2026-06-04: is the tape ACTUALLY in the data region when the 8041 reads?
// tape_clock only toggles in the DATA region (static in leader/bot/gap). Track its LIVE activity and
// latch it at the 8041's data-sample ($0B4). clklive@read DARK = RCLK static while reading = tape NOT
// in data = it reads nothing real => constant byte. LIT = tape IS streaming => bug is deeper.
reg        tape_clk_prev;
reg [16:0] tape_clk_idle;                 // clk_sys cycles since last tape_clock edge
reg        diag_clklive_rd, diag_bot_rd;  // latched AT the $0B4 sample
wire       tape_clk_live = (tape_clk_idle < 17'd100000);  // edge within ~1ms => RCLK toggling => in data
// READ-PIPELINE-PROBE rev3 2026-06-04: does the 8041 get PAST the 0xAA header sync, or stuck in it?
//   $272 = header-sync loop entered, $282 = header FOUND (sync exit), $304 = data-read loop,
//   $2C8 = data byte OUT-DBB'd. If $282/$304/$2C8 DARK => 8041 never matches our 0xAA => stuck in
//   sync, $05 is a STALE byte (bug = our header/data stream). If LIT => it IS reading data bytes.
reg diag_m272, diag_m282, diag_m304, diag_m2c8;
// READ-PIPELINE-PROBE rev4 2026-06-04: WHERE in the data loop does it die before $2C8?
//   $317 = loop EXIT (8 bits done), $2C7 = the send path, $329/$33E = the WRONG branches at $317.
//   $317 DARK => loop hangs mid-byte (never completes 8 bits). $317 LIT + $329/$33E LIT => it
//   finished the byte but branched AWAY from the send (bank/flag wrong at $317).
reg diag_m317, diag_m2c7, diag_m329, diag_m33e;
reg diag_m1cc, diag_m242;  // DIAG-REVERT-2026-06-05: interrupt-corruptor milestones ($1CC writes rb0.r1=#$1B; $242 = IBF handler)
// DIAG-REVERT-2026-06-05: latched 8041 rb0 r3/r5/r1 at PC==$317 (one-shot, held for readout).
// r3 = the 8041's assembled tape byte (THE A-vs-B splitter); r5/r1 = the nonzero CRC flags that
// divert $318/$31B to the error branches ($33E/$329) instead of the send ($2C8).
reg [7:0] diag_r3_317, diag_r5_317, diag_r1_317;
reg       diag_b317_cap;
// DIAG-REVERT-2026-06-06: sticky-OR of mode_set ($E402). Any bit ever set => the GAME wrote the video
// mode register => game code is EXECUTING. ROW2 all-dark after load => game never ran (DECO-222/hand-off).
// ROW2 nonzero => game runs & configures video => bug is our BG-layer render. See
// Claude/decocass_video_mode_mechanism_2026-06-06.md.
reg [7:0] diag_modeset_seen;
// DIAG-REVERT-2026-06-06: 6502-PC init-bisect milestones (sticky). PC = cpu_addr when cpu_sync=1.
// Localizes the early-init hang via entered-sub vs returned-from-sub pairs across $24CA/$2606/$4A7D.
// (Prior F131/F146/0503 all proved lit; collapsed to $05D4 = "init reached".)
reg diag_pc05D4, diag_pc24CA, diag_pc05DC, diag_pc2606, diag_pc05DF, diag_pc4A7D, diag_pc05E2;
// DIAG-REVERT-2026-06-06: LIVE 6502 PC bar = latest opcode-fetch addr. ROW2=hi byte (expect $4A while in
// $4A7D), ROW3=lo byte (loop position). Multiple screenshots show the PC spread = where it spins.
reg [15:0] diag_pc_live;
// DIAG-REVERT-2026-06-06: lowest stack-page ($01xx) write addr. Normal jsr pushes stay HIGH ($01Fx down);
// a $4A7D copy trampling the stack drives this LOW => corrupts saved rts return => $0000 jam.
reg [7:0] diag_sp_min;
always @(posedge clk_sys or posedge reset) begin
    if (reset) begin
        diag_mcupc <= 11'h000; diag_cmdval <= 8'h00;
        diag_m022<=1'b0; diag_m0ed<=1'b0; diag_m0fb<=1'b0; diag_m170<=1'b0; diag_m0f3<=1'b0; diag_m003<=1'b0;
        diag_we501<=1'b0; diag_cmd_seen<=1'b0; diag_ibf<=1'b0; diag_obf<=1'b0;
        diag_req<=1'b0; diag_motor<=1'b0; diag_we500<=1'b0; diag_re502<=1'b0;
        diag_outdbb<=1'b0; diag_clk_hi<=1'b0; diag_clk_lo<=1'b0; diag_dat_hi<=1'b0; diag_dat_lo<=1'b0;
        diag_m2e8<=1'b0; diag_m1a7<=1'b0; diag_m007<=1'b0; diag_rd_e500<=1'b0; diag_wr_0300<=1'b0;
        diag_b0<=8'h00; diag_b60<=8'h00;
        tape_clk_prev<=1'b0; tape_clk_idle<=17'd0; diag_clklive_rd<=1'b0; diag_bot_rd<=1'b0;
        diag_m272<=1'b0; diag_m282<=1'b0; diag_m304<=1'b0; diag_m2c8<=1'b0;
        diag_m317<=1'b0; diag_m2c7<=1'b0; diag_m329<=1'b0; diag_m33e<=1'b0;
        diag_r3_317<=8'h00; diag_r5_317<=8'h00; diag_r1_317<=8'h00; diag_b317_cap<=1'b0;  // DIAG-REVERT-2026-06-05
        diag_m1cc<=1'b0; diag_m242<=1'b0;  // DIAG-REVERT-2026-06-05
        diag_modeset_seen <= 8'h00;  // DIAG-REVERT-2026-06-06
        diag_pc05D4<=1'b0; diag_pc24CA<=1'b0; diag_pc05DC<=1'b0; diag_pc2606<=1'b0; diag_pc05DF<=1'b0; diag_pc4A7D<=1'b0; diag_pc05E2<=1'b0;  // DIAG-REVERT-2026-06-06
        diag_pc_live <= 16'h0000;  // DIAG-REVERT-2026-06-06
        diag_sp_min <= 8'hFF;  // DIAG-REVERT-2026-06-06
    end else begin
        diag_mcupc <= mcu_pmem_addr;                  // live 8041 PC
        diag_modeset_seen <= diag_modeset_seen | mode_set_reg;  // DIAG-REVERT-2026-06-06: accumulate any mode_set bit ever written
        // DIAG-REVERT-2026-06-06: bisect early-init hang ($05D9 jsr$24CA -> $05DC jsr$2606 -> $05DF jsr$4A7D -> $05E2)
        if (cpu_sync) begin
            diag_pc_live <= cpu_addr;  // DIAG-REVERT-2026-06-06: live PC bar
            if (cpu_addr == 16'h05D4) diag_pc05D4 <= 1'b1;
            if (cpu_addr == 16'h24CA) diag_pc24CA <= 1'b1;
            if (cpu_addr == 16'h05DC) diag_pc05DC <= 1'b1;
            if (cpu_addr == 16'h2606) diag_pc2606 <= 1'b1;
            if (cpu_addr == 16'h05DF) diag_pc05DF <= 1'b1;
            if (cpu_addr == 16'h4A7D) diag_pc4A7D <= 1'b1;
            if (cpu_addr == 16'h05E2) diag_pc05E2 <= 1'b1;
        end
        // DIAG-REVERT-2026-06-06: stack-trample detector (lowest $01xx write addr; write = !cpu_rw_n)
        if (!cpu_rw_n && cpu_addr[15:8] == 8'h01 && cpu_addr[7:0] < diag_sp_min)
            diag_sp_min <= cpu_addr[7:0];
        // DIAG-REVERT-2026-06-05: one-shot capture of the 8041's assembled byte + CRC flags at PC==$317.
        // dmem_mem[3]/[5]/[1] (rb0 r3/r5/r1) are settled by the time the fetch addr reaches $317.
        if (mcu_pmem_addr == 11'h317 && !diag_b317_cap) begin
            diag_r3_317   <= mcu_dmem_r3;   // assembled tape byte
            diag_r5_317   <= mcu_dmem_r5;   // CRC flag (checked first)
            diag_r1_317   <= mcu_dmem_r1;   // CRC flag (checked second)
            diag_b317_cap <= 1'b1;
        end
        case (mcu_pmem_addr)                          // sticky MCU milestones
            11'h022: diag_m022 <= 1'b1;
            11'h0ED: diag_m0ed <= 1'b1;
            11'h0FB: diag_m0fb <= 1'b1;
            11'h0F3: diag_m0f3 <= 1'b1;   // reached the jnc@$0F3 (so the add executed; no interrupt-divert before it)
            11'h0F5: diag_m170 <= 1'b1;   // reached $0F5 = jnc did NOT branch => carry was 1 after add $DB
            11'h003: diag_m003 <= 1'b1;   // IBF interrupt vector => the EN-I@$0ED interrupt DIVERTED the dispatch
            11'h2C8: diag_outdbb <= 1'b1; // OUT DBB,A (r3 response) — 8041 sent a byte to the 6502
            11'h3EF: diag_outdbb <= 1'b1; // OUT DBB,A (mem[$3F] response)
            // READ-PIPELINE-PROBE-2026-06-04 milestones:
            11'h2E8: diag_m2e8 <= 1'b1;   // read_block_b actually DISPATCHED
            11'h1A7: diag_m1a7 <= 1'b1;   // reached the RCLK edge-sync SAMPLE loop (dark => not read)
            11'h007: diag_m007 <= 1'b1;   // timer ISR fired (read may be timer-driven)
            11'h1CC: diag_m1cc <= 1'b1;   // DIAG-REVERT-2026-06-05: the rb0.r1=#$1B corruptor ran (interrupt mis-dispatch)
            11'h242: diag_m242 <= 1'b1;   // DIAG-REVERT-2026-06-05: IBF interrupt handler ran (should be DARK on a read)
            // rev3 header-sync milestones:
            11'h272: diag_m272 <= 1'b1;   // entered the 0xAA header sync loop
            11'h282: diag_m282 <= 1'b1;   // FOUND the 0xAA header (sync exit) ★
            11'h304: diag_m304 <= 1'b1;   // reached the data-read byte loop ★
            11'h2C8: diag_m2c8 <= 1'b1;   // OUT-DBB'd a data byte ★
            // rev4 loop-completion milestones:
            11'h317: diag_m317 <= 1'b1;   // loop EXIT (8 bits done) ★
            11'h2C7: diag_m2c7 <= 1'b1;   // the send path (-> $2C8)
            11'h329: diag_m329 <= 1'b1;   // WRONG branch (r1!=0)
            11'h33E: diag_m33e <= 1'b1;   // WRONG branch (r5!=0)
            default: ;
        endcase
        // 6502 / handshake side
        if (cpu_we_e5xx && cpu_addr[7:0]==8'h01) diag_we501    <= 1'b1;
        if (cpu_we_e5xx && cpu_addr[7:0]==8'h00) diag_we500    <= 1'b1;
        if (cpu_re_e5xx && cpu_addr[7:0]==8'h02) diag_re502    <= 1'b1;
        // READ-PIPELINE-PROBE-2026-06-04: 6502 pulling a tape byte + buffering it at $0300/$033C
        if (cpu_re_e5xx && cpu_addr[7:0]==8'h00)      diag_rd_e500 <= 1'b1;            // read DBBOUT
        if (!cpu_rw_n && ce_hclk4 && cpu_addr==16'h0300) begin diag_wr_0300<=1'b1; diag_b0 <=cpu_dout; end
        if (!cpu_rw_n && ce_hclk4 && cpu_addr==16'h033C) begin diag_wr_0300<=1'b1; diag_b60<=cpu_dout; end
        // READ-PIPELINE-PROBE rev2: tape_clock live-activity (resets on each edge; climbs if static)
        tape_clk_prev <= tape_clock;
        if (tape_clock != tape_clk_prev)        tape_clk_idle <= 17'd0;
        else if (tape_clk_idle != 17'h1FFFF)    tape_clk_idle <= tape_clk_idle + 17'd1;
        if (mcu_pmem_addr == 11'h0B4) begin     // latch tape state AT the 8041 data-sample
            diag_clklive_rd <= tape_clk_live;
            diag_bot_rd     <= tape_bot;
        end
        if (mcu_a0 && !mcu_wr_n) begin
            diag_cmd_seen <= 1'b1;
            diag_cmdval <= mcu_host_din;  // LATEST command (was FIRST-only): does the BIOS ever send a tape-READ cmd?
        end
        if (mcu_host_sts[1])                     diag_ibf      <= 1'b1;
        if (mcu_host_sts[0])                     diag_obf      <= 1'b1;
        if (~mcu_p1_out[7])                      diag_req      <= 1'b1;   // REQ/ asserted (active-low)
        if (tape_motor_on)                       diag_motor    <= 1'b1;
        // TAPE-ACTIVITY-PROBE-2026-06-04: did the streamer clock/data ever take BOTH values?
        // (hi & lo => it toggled => tape advancing; static at idle => only one ever sets)
        if (tape_clock) diag_clk_hi <= 1'b1; else diag_clk_lo <= 1'b1;
        if (tape_data)  diag_dat_hi <= 1'b1; else diag_dat_lo <= 1'b1;
    end
end

// E500-ERR-CAPTURE-2026-06-08: capture the POST-LOAD $E500 status byte = the value the BIOS checks at
// $0582 (lda $e500 / cmp #0 / bne -> jmp $F000), i.e. the exact byte E500-ZERO-TEST forces to 0. Gated on
// rt_seen05E2 (the SAME condition as the override) so we catch the post-decompressor STATUS read, not an
// early dongle/data read. `dongle_din_full` is the PRE-override value the 6502 actually sees at $E500 (the
// override zeroes e5xx_to_cpu, which is DOWNSTREAM of this wire), so we read the TRUE byte even while the
// CPU is fed 0. cflyball = NODONG => this byte == raw 8041 DBBOUT == mem[$3F]. Now known from build 2:
// $08 (bit3) = the transport-timeout from $0E9 (see TRANSPORT-PROBE). One-shot: hold the FIRST post-$05E2
// $E500 read (= the $0582 check). Shown as swatch Row C. Revert: delete this block + Row C below.
reg [7:0] diag_e500_err;
reg       diag_e500_err_cap;
always @(posedge clk_sys) begin
	if (reset) begin
		diag_e500_err     <= 8'h00;
		diag_e500_err_cap <= 1'b0;
	end else if (rt_seen05E2 && cpu_re_e5xx && cpu_addr == 16'hE500 && !diag_e500_err_cap) begin
		diag_e500_err     <= dongle_din_full;
		diag_e500_err_cap <= 1'b1;
	end
end

// WRITE-PATH-PROBE-2026-06-10 (rev2, index-aware): Row B = does the dongle reach the SDRAM writer, and on which
// ioctl_index (sticky, cleared on sdram_ld_reset so it captures DURING the download). cell0=bit0=LSB, white=set:
//  b0 ioctl_download | b1 ioctl_wr | b2 ioctl_wr & index==0 | b3 ioctl_wr & index==1 | b4 ioctl_wr & index>=2 |
//  b5 ioctl_addr>=$80000 (download reached 512 KB+) | b6 dongle_type==7 | b7 ioctl_wr & dongle_ld (= the sd_wr trigger)
// Decode (dongle now expected on index 1): b1=0 -> FSM never sees ioctl_wr (domain/wiring); b3=1 -> dongle DOES
// arrive as index 1 (so if c5 still 0, the FSM/handshake is the bug, not the index); b3=0 & b4=1 -> dongle comes in
// at a DIFFERENT index (read its bucket); b3=0 & b4=0 -> dongle ROM not downloaded at all (file missing/zip);
// b5=0 -> download truncated before 512 KB; b7 should track c5.
reg wp0,wp1,wp2,wp3,wp4,wp5,wp6,wp7;
always @(posedge clk_sys) begin
	if (sdram_ld_reset) {wp7,wp6,wp5,wp4,wp3,wp2,wp1,wp0} <= 8'd0;
	else begin
		if (ioctl_download)                       wp0 <= 1'b1;
		if (ioctl_wr)                             wp1 <= 1'b1;
		if (ioctl_wr && ioctl_index==8'd0)        wp2 <= 1'b1;
		if (ioctl_wr && ioctl_index==8'd1)        wp3 <= 1'b1;
		if (ioctl_wr && ioctl_index>=8'd2)        wp4 <= 1'b1;
		if (ioctl_wr && ioctl_addr>=25'h80000)    wp5 <= 1'b1;
		if (dongle_type==4'd7)                    wp6 <= 1'b1;
		if (ioctl_wr && dongle_ld)                wp7 <= 1'b1;
	end
end
wire [7:0] write_path_flags = {wp7,wp6,wp5,wp4,wp3,wp2,wp1,wp0};

// DONGLE-BYTE0-PROBE-2026-06-10: Row B = the dongle byte the 6502 actually reads at offset 0 (the "DECO" signature
// byte at donglerom[0]). EXPECT 0x44 ('D') if SDRAM load + read delivery are correct. 0x45/0x43/0x4F = off-by-one
// shift; 0x00 = stale/prefetch-race (read beat the SDRAM fetch); 0xFF = open bus. Fires ONCE, on the first $E500
// read while the dongle counter (dprom_addr) is still 0; latch inits 0x00 (all-dark Row B = never fired = BIOS
// didn't read offset 0 via $E500). Captures dprom_q_ddr = exactly what the 6502 sees at $E500 (off0 -> prom_q).
reg [7:0] diag_d0byte;
reg       diag_d0byte_cap;
always @(posedge clk_sys) begin
	if (sdram_ld_reset) begin
		diag_d0byte     <= 8'h00;
		diag_d0byte_cap <= 1'b0;
	end else if (!diag_d0byte_cap && cpu_re_e5xx && cpu_addr == 16'hE500 && dprom_addr == 20'd0) begin
		diag_d0byte     <= dprom_q_ddr;
		diag_d0byte_cap <= 1'b1;
	end
end

// TRANSPORT-PROBE-2026-06-08 (rev2 — LIVE signals; the milestone-flag version was UNRELIABLE and is removed).
// The reset's SLOWDOWN = the 8041's $0BC hole-seek retry loop: it drives the tape FORWARD and waits for a
// P2.5 (=tape_bot|tape_eot) edge inside a timer window, retries 200x2, then logs $08. EOT geometry matches
// MAME statically, so this localizes the ASYNC failure. READ Row A *LIVE, DURING the slowdown* (it lasts
// seconds) to see where the tape actually is and what P2.5 is doing while the MCU hangs. cell0=bit0:
//   c0 seen05E2 | c1 tape_bot | c2 tape_eot | c3 motor_on | c4 direction(1=fwd) | c5 fast | c6 clk_tog | c7 data_tog
// clk_tog/data_tog = tape clock/data toggled within ~1ms => streamer is in the DATA region (clock/data
// alternate there; static in leader/BOT/gap/EOT/trailer). DECODE during the hang:
//   c2(eot)=1 & c6(clk_tog)=0 => tape parked AT an end hole (the $0BC wait-for-FALL can hang if clamped).
//   c2=0 & c6=0               => tape in the GAP between data and EOT — waiting for a rise that hasn't come.
//   c3(motor)=0               => tape NOT advancing (problem is motor/direction, not the hole).
//   c6=1                      => still in DATA — not near EOT at all.
// Revert: delete this block + the swatch rows below.
reg        tape_clk_p, tape_dat_p;
reg [16:0] tape_clk_age, tape_dat_age;   // clk_sys cycles since last edge (FFFF.. = static)
always @(posedge clk_sys) begin
	if (reset) begin
		tape_clk_p<=1'b0; tape_dat_p<=1'b0; tape_clk_age<=17'h1FFFF; tape_dat_age<=17'h1FFFF;
	end else begin
		tape_clk_p <= tape_clock; tape_dat_p <= tape_data;
		if (tape_clock != tape_clk_p)       tape_clk_age <= 17'd0;
		else if (tape_clk_age != 17'h1FFFF) tape_clk_age <= tape_clk_age + 17'd1;
		if (tape_data  != tape_dat_p)       tape_dat_age <= 17'd0;
		else if (tape_dat_age != 17'h1FFFF) tape_dat_age <= tape_dat_age + 17'd1;
	end
end
wire tape_clk_tog = (tape_clk_age < 17'd96000);   // edge within ~1ms @96MHz => toggling => DATA region
wire tape_dat_tog = (tape_dat_age < 17'd96000);
wire [7:0] eot_flags = {tape_dat_tog, tape_clk_tog, tape_speed_select[1], tape_direction,
                        tape_motor_on, tape_eot, tape_bot, rt_seen05E2};

// RESET-TRACE-2026-06-07: cflyball now LOADS + DECOMPRESSES correctly (seeds proven == MAME), but after a
// screen flash it RESETS to the BIOS loader. HW reset + IRQ are wired out (reset = RESET|status0|buttons1|
// ioctl_download ; deco222 .irq_n=1'b1), so the 6502 must reach BIOS in SOFTWARE. Catch HOW: once the game
// runs past the decompressor (PC reaches $05E2), freeze the FIRST restart-class BIOS entry the 6502 fetches
// + the game PC just before it, + sticky landmark flags. Decode:
//   rt_entry = $F003/$F670 => coin-NMI fired mid-game ; $F000/$F053 => COLD restart (jmp/jam to reset path).
//   rt_pre   = the exact PC right before the jump -> disassemble FlyingBall-Loaded.hex there to see what it
//              was doing (poll a register? consume decompressed data?). PC = cpu_addr when cpu_sync=1.
// Revert: delete this block + restore the WHITE-SCREEN-PROBE seed rows below.
reg        rt_seen05E2, rt_cap;
reg        rt_f000, rt_f003, rt_f053, rt_f670, rt_f32d;   // sticky: BIOS landmark fetched AFTER $05E2
reg [15:0] rt_prevpc;                                     // rolling last opcode-fetch PC before the entry
reg [15:0] rt_entry, rt_pre;                              // frozen: BIOS-entry PC + the PC before it
always @(posedge clk_sys) begin
	if (reset) begin
		rt_seen05E2<=1'b0; rt_cap<=1'b0;
		rt_f000<=1'b0; rt_f003<=1'b0; rt_f053<=1'b0; rt_f670<=1'b0; rt_f32d<=1'b0;
		rt_prevpc<=16'h0000; rt_entry<=16'h0000; rt_pre<=16'h0000;
	end else if (cpu_sync) begin
		if (cpu_addr == 16'h05E2) rt_seen05E2 <= 1'b1;        // decompressor returned = game running deep
		if (rt_seen05E2) begin
			if (cpu_addr == 16'hF000) rt_f000 <= 1'b1;        // cold reset vector (JMP table)
			if (cpu_addr == 16'hF003) rt_f003 <= 1'b1;        // NMI vector  (JMP $F670)
			if (cpu_addr == 16'hF053) rt_f053 <= 1'b1;        // cold init body
			if (cpu_addr == 16'hF670) rt_f670 <= 1'b1;        // NMI/coin handler
			if (cpu_addr == 16'hF32D) rt_f32d <= 1'b1;        // BIOS main init re-ran => full restart
			if (!rt_cap) begin
				if (cpu_addr==16'hF000 || cpu_addr==16'hF003 ||
				    cpu_addr==16'hF053 || cpu_addr==16'hF670) begin
					rt_entry <= cpu_addr;   // the restart-class BIOS entry it jumped to
					rt_pre   <= rt_prevpc;  // the instruction right before the jump
					rt_cap   <= 1'b1;
				end else begin
					rt_prevpc <= cpu_addr;  // track latest PC (incl. normal BIOS service calls)
				end
			end
		end
	end
end

// READ-PIPELINE-PROBE-2026-06-04 row mapping (cell0 = LEFTMOST = bit0; read bit0->bit7 L->R):
wire diag_clk_tog = diag_clk_hi & diag_clk_lo;   // tape clock toggled => streamer advancing
wire diag_dat_tog = diag_dat_hi & diag_dat_lo;   // tape data toggled  => bits present
// ROW1 = read pipeline.  L->R cells: $2E8(read dispatched) $1A7(SAMPLE loop) $007(timer ISR)
//        OUT-DBB | 6502-rd-$E500 | 6502-wr-$0300 | clk-toggled | data-toggled
//        ** $1A7 (cell1) DARK => the 8041 never runs the read sample loop = "not being read" **
// ROW1 rev4: L->R = $304(loop) | $317(EXIT★) | $2C7(send-path) | $329(wrong-br) | $33E(wrong-br) |
//            $2C8(SENT) | $1A7(edge-sync) | clk-live@read
//   ★ cell1 ($317) DARK => loop HANGS mid-byte. cell1 LIT + $329/$33E LIT => finished byte, branched
//     AWAY from the send. cell2 ($2C7) LIT + cell5 ($2C8) DARK => stalls between send-path and send.
// DIAG-REVERT-2026-06-05 ROW1 cells L->R (cell0=bit0): $003(IBF vec) $007(timer vec) $1CC(r1=#1B) $242(IBFhdlr) $329 $33E $317 $2C8
// ORIGINAL (read-pipeline view):
// wire [7:0] diag_hi  = {diag_clklive_rd, diag_m1a7, diag_m2c8, diag_m33e,
//                        diag_m329, diag_m2c7, diag_m317, diag_m304};
// DONGLE-PROBE-2026-06-07: ROW1 = 1st $E500 dongle byte (orig 8041-milestone bits commented below)
// wire [7:0] diag_hi  = {diag_outdbb, diag_m317, diag_m33e, diag_m329,   // DIAG-2026-06-05: cell7 = OUTDBB (RELIABLE send flag; diag_m2c8 was DEAD via dup 11'h2C8 case)
//                        diag_m242, diag_m1cc, diag_m007, diag_m003};
// WHITE-SCREEN-PROBE-2026-06-07: overlay repointed to the 6 zero-page seeds (seed01..seed06); the
// diag_d500 capture block above is left intact but its 3 row assignments are commented out here.
// wire [7:0] diag_hi  = diag_d500_0;
// DIAG-REVERT-2026-06-05: ROW2/ROW3 repointed from the STALE 6502-stored bytes (diag_b0/b60, both
// read $05 = useless: the 8041 never sends, so the 6502 re-reads a dead DBBOUT) to the 8041's OWN
// assembled byte r3 + the failing CRC flag r5, latched at PC==$317. r3 == correct data byte =>
// sampling is fine => bug is the $11E CRC execution (B); r3 == garbage => sampling/phase (A).
// To revert: restore the two diag_b0/diag_b60 lines and comment the diag_r3_317/diag_r5_317 lines.
// ROW2 = $0300 byte 0   (STALE $05 — was useless)
// wire [7:0] diag_lo  = diag_b0;
// ROW3 = $033C byte 60  (STALE $05 — was useless)
// wire [7:0] diag_chk = diag_b60;
// ROW2 = 8041 assembled byte r3 @ $317  (THE A-vs-B readout; compare to block-0 byte0)
// DIAG-REVERT-2026-06-06: original below, uncomment to restore the $317 byte readout
// wire [7:0] diag_lo  = diag_r3_317;
// ROW2 now = sticky-OR of mode_set ($E402). All-dark after load => game never wrote video mode => game
// not executing (DECO-222/hand-off). Nonzero (esp. bit3 bkg_ena) => game runs => bug is our BG render.
// DIAG-REVERT-2026-06-06: ROW2 was mode_set; now = live 6502 PC HIGH byte (expect $4A while spinning)
// wire [7:0] diag_lo  = diag_modeset_seen;
// DIAG-REVERT-2026-06-06: ROW2 now = lowest $01xx stack write (low = trample). // diag_pc_live[15:8]
// wire [7:0] diag_lo  = diag_sp_min;   // DIAG-REVERT-2026-06-06
// WHITE-SCREEN-PROBE-2026-06-07: commented out (was DONGLE-PROBE ROW2 = 2nd $E500 dongle byte)
// wire [7:0] diag_lo  = diag_d500_1;
// ROW3 = diag_b0 = the byte the 6502 RECEIVED & stored at $0300 (DIAG-2026-06-05). r5=r1=$00 => byte PASSES => 8041 sends.
//        $20 here = read+delivery OK; $05/other = host-bus DBBOUT delivery bug.
// DIAG-REVERT-2026-06-06: original below, uncomment to restore the 6502-received-byte readout
// wire [7:0] diag_chk = diag_b0;
// ROW3 = 6502-PC init bisect L->R: c0=$05D4 c1=$24CA c2=$05DC c3=$2606 c4=$05DF c5=$4A7D c6=$05E2 (c7 unused)
// DIAG-REVERT-2026-06-06: ROW3 was PC milestones; now = live 6502 PC LOW byte (loop position)
// wire [7:0] diag_chk = {1'b0, diag_pc05E2, diag_pc4A7D, diag_pc05DF, diag_pc2606, diag_pc05DC, diag_pc24CA, diag_pc05D4};
// wire [7:0] diag_chk = diag_pc_live[7:0];   // DIAG-REVERT-2026-06-06
// WHITE-SCREEN-PROBE-2026-06-07: commented out (was DONGLE-PROBE ROW3 = 3rd $E500 dongle byte)
// wire [7:0] diag_chk = diag_d500_2;

wire [8:0] diag_x    = hcnt - 9'd8;
wire       diag_in   = (hcnt >= 9'd8) && (hcnt < 9'd136);   // 8 cells * 16px
wire [2:0] diag_cell = diag_x[6:4];
wire       diag_gap  = (diag_x[3:0] >= 4'd14);              // 2px gap between cells
// TRANSPORT-PROBE-2026-06-08 swatch — 2 rows, top->bottom (cell0=LEFT=bit0, white=1; read each as a hex byte):
//   Row A (eot_flags, LIVE — read DURING the slowdown): c0 seen05E2 | c1 tape_bot | c2 tape_eot |
//          c3 motor_on | c4 direction(1=fwd) | c5 fast | c6 clk_tog(in DATA) | c7 data_tog
//   Row B ($E500 byte): the value the BIOS trips on at $0582 (proven = STATUS reg, not error/data).
//   RESET-TRACE rt_* and the milestone block remain as plumbing (rt_seen05E2 gates E500-ZERO-TEST).
wire       diag_rowA = (vcnt >= 9'd16) && (vcnt < 9'd32);    // DARKSOFT-PC-PROBE: 6502 PC[15:8] (high byte)
wire       diag_rowB = (vcnt >= 9'd40) && (vcnt < 9'd56);    // DARKSOFT-PC-PROBE: 6502 PC[7:0] (low byte = loop position)
// SWATCH-DARKSOFT: Row A = sticky darksoft boot flags (cell0=bit0=LSB, white=set):
//  c0 6502 fetched BIOS ($Fxxx) | c1 6502 hit $E5xx | c2 dongle read | c3 dongle write |
//  c4 SDRAM ready | c5 SDRAM written | c6 dongle byte!=00 | c7 dongle byte!=FF
reg dk0,dk1,dk2,dk3,dk4,dk5,dk6,dk7;
always @(posedge clk_sys) begin
	// SWATCH-C5-UNMASK-2026-06-10: clear on sdram_ld_reset (NOT `reset`) — `reset` includes ioctl_download,
	// which zeroed these EVERY cycle of the download, so c5 (sd_wr, fires ONLY during the load) could never latch.
	if (sdram_ld_reset) {dk7,dk6,dk5,dk4,dk3,dk2,dk1,dk0} <= 8'd0;
	else begin
		if (cpu_addr[15:12]==4'hF) dk0 <= 1'b1;
		if (cpu_addr[15:8]==8'hE5) dk1 <= 1'b1;
		if (dongle_re)             dk2 <= 1'b1;
		if (dongle_we)             dk3 <= 1'b1;
		if (sd_ready)              dk4 <= 1'b1;
		if (sd_wr)                 dk5 <= 1'b1;
		if (dprom_q_ddr != 8'h00)  dk6 <= 1'b1;
		if (dprom_q_ddr != 8'hFF)  dk7 <= 1'b1;
	end
end
wire [7:0] dark_flags = {dk7,dk6,dk5,dk4,dk3,dk2,dk1,dk0};
// DARKSOFT-PC-PROBE-2026-06-10: Row A = 6502 PC[15:8], Row B = PC[7:0] (live opcode-fetch PC, latched on cpu_sync
// via diag_pc_live @~L1440). At the "Loading..." lock the PC settles into the hang loop -> read both bytes, map to
// decodark.dasm. cell0=LEFT=bit0. Row A ~ $Fx = still in BIOS loader; $0x/$1x/$5x high byte = game ran + hung in RAM.
wire [7:0] diag_pc_hi = diag_pc_live[15:8];
wire [7:0] diag_pc_lo = diag_pc_live[7:0];
wire       diag_lit  = (diag_rowA && diag_pc_hi[diag_cell]) |
                       (diag_rowB && diag_pc_lo[diag_cell]);
wire       diag_show = (diag_rowA | diag_rowB) && diag_in && !diag_gap;
// AUDIO-ALIVE-PROBE-2026-06-11: audio liveness rows (revert: delete this block + restore the pass-through
// diag_r/g/b below). Row A (vcnt16-32)=aud_flags; Row B (40-56)=audio PC low; Row C (64-80)=audio PC high.
wire       aud_rowC = (vcnt >= 9'd64) && (vcnt < 9'd80);
wire       aud_lit  = (diag_rowA && aud_flags[diag_cell])      |
                      (diag_rowB && aud_pc_snap[diag_cell])    |
                      (aud_rowC  && aud_pc_snap[8 + diag_cell]);
wire       aud_show = (diag_rowA | diag_rowB | aud_rowC) && diag_in && !diag_gap;
wire [7:0] aud_diag_r = aud_show ? (aud_lit ? 8'hFF : 8'h20) : core_r;
wire [7:0] aud_diag_g = aud_show ? (aud_lit ? 8'hFF : 8'h20) : core_g;
wire [7:0] aud_diag_b = aud_show ? (aud_lit ? 8'hFF : 8'h20) : core_b;
// Overlay ON (bands over the running game; E500-ZERO-TEST keeps it booting). To hide for clean shots, swap
// to pass-through: comment the 3 diag_show lines, uncomment the 3 core_* lines.
// wire [7:0] diag_r = core_r;
// wire [7:0] diag_g = core_g;
// wire [7:0] diag_b = core_b;
// SWATCH-OFF-2026-06-10: overlay flipped to PASS-THROUGH for clean reference screenshots. All probe logic
// (diag_pc_live, dark_flags, etc.) stays intact and latching — only the on-screen bands are hidden.
// DIAG-REVERT-2026-06-10: restore overlay = re-enable the 3 diag_show lines, comment the 3 core_* lines.
// wire [7:0] diag_r = diag_show ? (diag_lit ? 8'hFF : 8'h20) : core_r;
// wire [7:0] diag_g = diag_show ? (diag_lit ? 8'hFF : 8'h20) : core_g;
// wire [7:0] diag_b = diag_show ? (diag_lit ? 8'hFF : 8'h20) : core_b;
// SWATCH-OFF-2026-06-11: overlay back to PASS-THROUGH (clean screen for graphics work). The audio probe
// scaffolding (dbg taps, al_* flags, aud_diag_*) STAYS in the tree per "leave the diagnostics" — only the
// on-screen bands are hidden. Re-show: restore the 3 aud_diag_* lines, comment the 3 core_* lines.
// wire [7:0] diag_r = aud_diag_r;
// wire [7:0] diag_g = aud_diag_g;
// wire [7:0] diag_b = aud_diag_b;
wire [7:0] diag_r = core_r;
wire [7:0] diag_g = core_g;
wire [7:0] diag_b = core_b;
// ===== end DIAG-REVERT-2026-06-03c =====

// Palette lookup (task 11)
//
// 2026-05-16: WHITE-SCREEN ROOT CAUSE.
// Per MAME decocass_v.cpp:323-333 (`decocass_paletteram_w`):
//     offset = (offset & 31) ^ 16;
//     m_palette->set_indirect_color(offset, ...);
// The hardware XORs bit 4 (and mod-32s) the CPU's write offset before
// committing it to the indirect-color table that drives video output.
// Without this XOR, BIOS writes meant for pen-N color land at palette
// index N — including the critical pen-8 color (`BG_FILL` in
// video_mixer.v), which BIOS writes to $E000+24 expecting it to map
// to palette[8] via the XOR. Without the XOR, palette[8] stays at 0,
// `clut_index = palram_dout[4:0] = 0`, CLUT[0] = 12'hFFF = PURE WHITE.
// Symptom: hours of "white screen, can't get past it." The audio-hijack
// rounds proved BIOS was writing real non-zero data; the writes just
// went to the wrong addresses. Now applying the XOR on the address that
// reaches the video palette read-side dpram.
video_palette video_palette_inst (
	.clk_sys      (clk_sys),
	.ce_pix       (ce_pix),
	.cpu_we       (cpu_we_palram),
	.cpu_addr     ({3'b000, cpu_addr[4:0] ^ 5'b10000}),
	.cpu_dout     (cpu_dout),
	.pen          (mixer_pen),
	.prom_index   (5'h00),
	.red          (core_r_hi),
	.grn          (core_g_hi),
	.blu          (core_b_hi)
);

// Mixer: priority encoding + layer blending (task 11)

deco_video_mixer deco_video_mixer_inst (
	.clk_sys                (clk_sys),
	.ce_pix                 (ce_pix),
	.fg_pen                 (fg_pen),
	.fg_opaque              (fg_opaque),
	.bg_pen                 (bg_pen),
	.bg_opaque              (bg_opaque),
	.spr_pen                (spr_pen),
	.spr_opaque             (spr_opaque),
	.mis_pen                (mis_pen),
	.mis_opaque             (mis_opaque),
	.mode_set               (mode_set_reg),
	.color_center_bot       (color_center_bot_reg),
	.color_missiles         (color_missiles_reg),   // MISSILES-IMPL-2026-06-28: was 8'h00 (stubbed)
	.back_h_shift           (back_h_shift_reg),
	.back_vl_shift          (back_vl_shift_reg),
	.back_vr_shift          (back_vr_shift_reg),
	.part_h_shift           (part_h_shift_reg),
	.part_v_shift           (part_v_shift_reg),
	.center_h_shift_space   (center_h_shift_space_reg),
	.center_v_shift         (center_v_shift_reg),
	.hcnt                   (hcnt),
	.vcnt                   (vcnt),
	.out_pen                (mixer_pen),
	.out_pen_b4_modulate    (mixer_modulate)
);

// =========================================================================
// PAUSE + OUTPUT
// =========================================================================
// pause_cpu declared up at the clock-enable gating (PAUSE-2026-06-28); driven here by pause_inst.
wire [23:0] rgb_pause;
wire        m_pause = joystick_0[9] | joystick_1[9];   // PAUSE-2026-06-28: dedicated Pause button (conf_str J1 bit 9)

pause #(8,8,8,24) pause_inst (
	.clk_sys       (clk_sys),
	.reset         (pause_reset),   // PAUSE-LOAD-2026-06-28: excl. ioctl_download → pause works during the cassette load
	.OSD_STATUS    (OSD_STATUS),
	.user_button   (m_pause),
	.pause_request (1'b0),
	.options       (2'b01),       // PAUSE-2026-06-28: [0]=pause when OSD open; [1]=dim-video (off)
	// DIAG-REVERT-2026-06-03: feed MCU-progress overlay (restore core_* to revert)
	// .r             (core_r),
	// .g             (core_g),
	// .b             (core_b),
	.r             (diag_r),
	.g             (diag_g),
	.b             (diag_b),
	.pause_cpu     (pause_cpu),
	.rgb_out       (rgb_pause)
);

// =========================================================================
// VIDEO OUTPUT
// =========================================================================
wire no_rotate  = status[2] | direct_video;
wire rotate_ccw = 1'b1;  // ROT270 = CCW for portrait DECO Cassette
wire flip       = 1'b0;

// ===== VIDEO-ALIGN-2026-06-06: pixel-pipeline vs blank/sync alignment =====
// The RGB content path lags hcnt by ~12 px (USER-MEASURED on screen, 1.5 tiles):
//   - video_fg is NOT prefetched: tile/char BRAM reads (2 cy) aren't ready when
//     the shift-reg loads at the tile boundary, so the SR loads tile N's data at
//     the START of tile N+1's window => a full 8-px (1 tile) defer, same root as
//     Common-Pitfalls/"Tile rows off-by-one at startup" but uniform here because
//     the FG text layer is static.
//   - plus the register chain: fg_pen, mixer out_pen, palette BRAM, palette RGB
//     reg (~4 px).
//   = ~12 px total, vs video_timing's hblank/hsync/vblank/vsync at 1 stage.
// Net ~12-px skew => content arrives ~12 px AFTER the active window opens. Because
// the display is ROT270 (screen_rotate CCW), this raster-HORIZONTAL skew shows
// up ON SCREEN as a VERTICAL shift (content pushed UP, top rows clipped, equal
// overflow at the bottom). Fix = delay blank+sync to match the content pipeline
// so the active window lands on the actual pixels. The hblank/vblank windows
// themselves already match MAME set_raw(384,0,256,272,8,248), so ONLY this
// alignment delay is needed -- nothing in vcnt/vblank.
// WHY HORIZONTAL FOR A VERTICAL SYMPTOM: see Common-Pitfalls/"Counter wrap mid-
// line breaks offset math" -- Tutankham lost a week treating this exact rotated-
// axis symptom as a vertical bug. Confirmed CCW mapping in sys/arcade_video.v
// screen_rotate (raster hcnt -> display vertical).
// TUNING: if a residual shift remains after the build, nudge VID_HV_DELAY by
// +/-1..2 (raise = push content DOWN on screen, lower = push UP).
// VIDEO-ALIGN-FIX-2026-06-28: was 12. The 06-06 value = 8px FG tile-defer + ~4px register chain. BUT FG-HSHIFT
// (video_fg.v hcnt_fg=hcnt+8, added 06-11) ALREADY compensates the FG's 8px tile-defer, and the rebuilt BG is
// per-pixel (no tile-defer at all). ⇒ the 8px was DOUBLE-COUNTED → composite over-delayed by 8 → the fixed ~8px
// garbage band at the display top/bottom (global FG+BG; unmovable by a BG content shift; visible once BG rendered).
// Drop to the register-chain-only ~4. (Per the tuning note: nudge +/-1..2 if a small residual remains.)
// localparam [4:0] VID_HV_DELAY = 5'd12;   // ORIGINAL — over-counts the FG tile-defer that FG-HSHIFT already fixed
localparam [4:0] VID_HV_DELAY = 5'd4;    // register chain only; FG tile-defer handled by FG-HSHIFT, BG is per-pixel

reg [15:0] hbl_sr, vbl_sr, hs_sr, vs_sr;
always @(posedge clk_sys) if (ce_pix) begin
	hbl_sr <= {hbl_sr[14:0], video_hblank};
	vbl_sr <= {vbl_sr[14:0], video_vblank};
	hs_sr  <= {hs_sr[14:0],  video_hsync};
	vs_sr  <= {vs_sr[14:0],  video_vsync};
end
wire video_hblank_d = hbl_sr[VID_HV_DELAY-1];
wire video_vblank_d = vbl_sr[VID_HV_DELAY-1];
wire video_hsync_d  = hs_sr[VID_HV_DELAY-1];
wire video_vsync_d  = vs_sr[VID_HV_DELAY-1];
// ===== end VIDEO-ALIGN-2026-06-06 =====

screen_rotate screen_rotate (.*);

arcade_video #(256,24,1) arcade_video (
	.*,
	.clk_video (clk_vid),
	.RGB_in    (rgb_pause),
	.ce_pix    (ce_pix),
	// VIDEO-ALIGN-2026-06-06: feed pipeline-delayed blank/sync (originals below)
	// .HBlank    (video_hblank),
	// .VBlank    (video_vblank),
	// .HSync     (video_hsync),
	// .VSync     (video_vsync),
	.HBlank    (video_hblank_d),
	.VBlank    (video_vblank_d),
	.HSync     (video_hsync_d),
	.VSync     (video_vsync_d),
	.fx        (3'b000)
);

assign CLK_VIDEO = clk_vid;

// =========================================================================
// AUDIO OUTPUT
// =========================================================================
assign AUDIO_L = ay_left;
assign AUDIO_R = ay_right;
assign AUDIO_S = 1'b1;

// =========================================================================
// LED STATUS
// =========================================================================
// 2026-05-18 — LED_USER as tape-motor activity indicator. tape_motor_on is
// asserted whenever MCU commands FWD or REW. Visible signal of whether the
// MCU/tape interface is alive without staring at the screen.
assign LED_USER  = tape_motor_on;

endmodule
