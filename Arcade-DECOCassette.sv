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
    `include "sys/emu_ports.vh"
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
	"P1,Video Options;",
	"P1O[1],Aspect Ratio,3:4,Original;",
	"P1O[2],Orientation,Vertical,Horizontal;",
	"P1O[11],HDMI Flip,Off,On;",
	"P1O[17:15],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"P2,Pause Options;",
	"P2O[25],Pause when OSD is open,On,Off;",
	"P2O[26],Dim video after 10s,On,Off;",
	"-;",
	"O[29:27],Fast Load,Off,2x,4x,8x,16x;",
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
wire [15:0] joystick_r_analog_1;   // P2 right analog stick (cocktail)
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
	.joystick_r_analog_1(joystick_r_analog_1),
	.ps2_key(ps2_key)
);

// Keyboard coin/start (MAME defaults): 1 = 1P Start, 2 = 2P Start, 5 = Coin 1, 6 = Coin 2.
reg kb_start1 = 0, kb_start2 = 0, kb_coin1 = 0, kb_coin2 = 0;
reg kb_old_toggle = 0;
always @(posedge clk_sys) begin
	kb_old_toggle <= ps2_key[10];
	if (kb_old_toggle != ps2_key[10] && !ps2_key[8]) begin
		case (ps2_key[7:0])
			8'h16: kb_start1 <= ps2_key[9];
			8'h1E: kb_start2 <= ps2_key[9];
			8'h2E: kb_coin1  <= ps2_key[9];
			8'h36: kb_coin2  <= ps2_key[9];
			default: ;
		endcase
	end
end

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
// RESET-EXTEND-DARKSOFT-2026-08-24: TRIED + RULED OUT (HW 2026-08-24). Theory was a boot-time race
// between the CPU coming out of reset and the SDRAM read-prefetch servicing dongle address 0. HW: still
// requires a soft reset/reload — a few extra clk_sys cycles of reset extension made no difference.
// Reverted to the original purely-combinational form.
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
// MEMORY: decocrom overlay-PCB ROM (MAME "user3" region) — ctisland/ctisland2/
// ctisland3/cexplore only. Banked over charram $6000-$AFFF via $E900
// (decocass_e900_w -> m_rombank, decocass.cpp:2095-2105/130-135). Up to 40 KB
// (cexplore fully populates both 20 KB banks; ctisland uses only 16 KB of
// bank 1). Loaded on its OWN ioctl index = 2 — small enough (<=40 KB) for a
// plain on-chip BRAM, no SDRAM needed (unlike the 1 MB Darksoft/Widel dongle
// ROMs on index 1).
// =========================================================================
wire        user3_we_rom = ioctl_download && ioctl_wr && (ioctl_index == 8'd2);
wire [15:0] user3_addr;              // from decocass.v (bank-selected offset)
wire [7:0]  user3_q;
wire [15:0] user3_addr_bram = user3_we_rom ? ioctl_addr[15:0] : user3_addr;

spram #(.address_width(16), .data_width(8)) user3_rom (
	.clock     (clk_sys),
	.enable    (1'b1),
	.address   (user3_addr_bram),
	.data      (ioctl_dout),
	.wren      (user3_we_rom),
	.q         (user3_q)
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
	.user3_q           (user3_q),
	.user3_addr_w      (user3_addr),
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
	.coin_in           (joystick_0[6] | joystick_1[6] | kb_coin1 | kb_coin2),  // P1/P2 coin → main-CPU NMI
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

// Fast Load (OSD): while the tape motor runs, the 8041 and the tape streamer both run 2x-16x faster; nothing else changes.
// 8041 enable: clk_sys/16 (6 MHz) -> /8, /4, /2, /1.  Tape enable: clk_sys/20000 (4.8 kHz) -> /10000 ... /1250.
wire [2:0] fl_sel    = (status[29:27] > 3'd4) ? 3'd4 : status[29:27];   // 0=Off 1=2x 2=4x 3=8x 4=16x
wire       fast_load = (fl_sel != 3'd0) & tape_motor_on;
reg  [2:0] fl_hcnt = 3'd0;
reg [13:0] fl_tdiv = 14'd0;
wire [13:0] fl_tlim = (fl_sel == 3'd1) ? 14'd9999 : (fl_sel == 3'd2) ? 14'd4999 :
                      (fl_sel == 3'd3) ? 14'd2499 : 14'd1249;
wire       fl_hce   = (fl_sel == 3'd1) ? (fl_hcnt == 3'd7) : (fl_sel == 3'd2) ? (fl_hcnt[1:0] == 2'd3) :
                      (fl_sel == 3'd3) ? fl_hcnt[0] : 1'b1;
wire       fl_tce   = (fl_tdiv >= fl_tlim);
always @(posedge clk_sys) begin
	fl_hcnt <= fl_hcnt + 3'd1;
	fl_tdiv <= fl_tce ? 14'd0 : fl_tdiv + 14'd1;
end
wire ce_hclk_mcu = (fast_load ? fl_hce : ce_hclk_raw) & ~pause_cpu;
wire ce_tape_mcu = (fast_load ? fl_tce : ce_tape_raw) & ~pause_cpu;
wire [1:0]  tape_speed_select;
wire        tape_data, tape_clock, tape_bot, tape_eot;

// i8041 MCU + program memory
i8041_top i8041_inst (
	.clk_sys         (clk_sys),
	.ce_hclk         (ce_hclk_mcu),
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
	.rom_data_w      (mcurom_dout)
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
	.ce_hclk              (ce_hclk_mcu),
	.ce_hclk1             (ce_hclk1),
	.ce_tape              (ce_tape_mcu),
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
	.ce_tape           (ce_tape_mcu),
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
// SDRAM-POR-PLL-GATE-2026-08-24: TRIED + RULED OUT (HW 2026-08-24). Theory was that this ~15-cycle
// countdown (ungated, running on possibly-pre-lock clk_sys) could race pll_locked and leave the SDRAM
// controller/prefetch-FSM state (sd_last_addr etc.) wrong after a cold FPGA config. DISPROVEN: user
// confirmed reselecting the SAME stuck Darksoft MRA from the OSD (no FPGA reprogram, ioctl_download only
// — sdram_ld_reset does NOT refire on this path at all) ALSO unwedges it. Since the SDRAM POR/init domain
// is never touched by that path, it structurally cannot be the fix — reverted to the original ungated form.
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

// WRITE-DROP-FIX-2026-08-25: HW+Verilator-confirmed root cause of Darksoft v15/v16/v17's cold-boot
// yellow screen. The write trigger below only checked the LIVE `ioctl_wr && dongle_ld` strobe inside
// the `!sd_busy` branch — if that single-cycle pulse landed on a cycle where sd_busy was already 1 for
// ANY other reason (e.g. the tail of a refresh cycle), the byte was silently dropped forever; nothing
// latched it. Sim with a real SDRAM behavioral model proved exactly this: dongle offset 0 ('D'=0x44)
// was NEVER written (SDRAM read back the untouched 0x00 erase value) while offset 1 ('E'=0x45, the
// very next byte) landed correctly — a single dropped write, not a read-side timing race. This affects
// every dongle type on ioctl_index==1, not just Darksoft; Darksoft/Widel's 1MB streams just make byte 0
// the first thing that matters (game_id/checksum), so they're the ones that show it.
// Fix: latch every dongle write request the instant it arrives, unconditionally, and drain it once the
// FSM is free — makes a dropped byte structurally impossible regardless of the exact collision window.
reg         wr_req_pend;
reg  [20:0] wr_req_addr;
reg  [7:0]  wr_req_data;

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
		wr_req_pend <= 1'b0;
	end else begin
		sd_refresh_cnt <= sd_refresh_cnt + 1'b1;
		sd_old_ready   <= sd_ready;

		// WRITE-DROP-FIX-2026-08-25: latch every dongle write request unconditionally, the instant it
		// arrives — independent of sd_busy — so a strobe landing on a busy cycle is queued, not lost.
		// ioctl_wait (assign above) already includes `ioctl_wr && dongle_ld`, so HPS is already being
		// held off for this exact cycle regardless; this just makes sure the byte itself is captured.
		if (ioctl_wr && dongle_ld) begin
			wr_req_pend <= 1'b1;
			wr_req_addr <= dongle_ld_addr[20:0];
			wr_req_data <= ioctl_dout;
		end

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
			if (wr_req_pend) begin                                 // LOAD: latched byte -> 16-bit SDRAM
				sd_addr     <= wr_req_addr[20:1];
				sd_din      <= {wr_req_data, wr_req_data};
				sd_bs       <= wr_req_addr[0] ? 2'b10 : 2'b01;     // high/low byte lane
				sd_wr       <= 1; sd_busy <= 1; sd_was_rd <= 0;
				wr_req_pend <= 1'b0;
				sd_last_addr <= 20'hFFFFF;                         // write invalidates the read cache -> re-fetch after load
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
// The Tower (release 8) has twin 4-way sticks: IN bits[3:0] = right stick R/L/U/D, bits[7:4] = left stick R/L/U/D.
wire ctower_mode = (dongle_type == 4'd1) && (game_id == 8'd8);
wire signed [7:0] rx0 = joystick_r_analog_0[7:0], ry0 = joystick_r_analog_0[15:8];
wire signed [7:0] rx1 = joystick_r_analog_1[7:0], ry1 = joystick_r_analog_1[15:8];
wire [3:0] rstick0 = {ry0 > 8'sd48, ry0 < -8'sd48, rx0 < -8'sd48, rx0 > 8'sd48};  // {D,U,L,R}
wire [3:0] rstick1 = {ry1 > 8'sd48, ry1 < -8'sd48, rx1 < -8'sd48, rx1 > 8'sd48};
// DS Telejan (release 14): $E600/$E601 read the keyboard mahjong panel row selected by $E413 bits 3:2 (P2 mirrors P1).
wire cdsteljn_mode = (dongle_type == 4'd1) && (game_id == 8'd14);
wire [7:0] mahjong_row;
mahjong_panel mahjong_panel_inst (
	.clk_sys (clk_sys),
	.reset   (reset),
	.ps2_key (ps2_key),
	.mux     (coin_counter_reg[3:2]),
	.row     (mahjong_row)
);
assign in0 = cdsteljn_mode ? mahjong_row
           : ctower_mode   ? {joystick_0[2], joystick_0[3], joystick_0[1:0], rstick0}
                           : {2'b00, joystick_0[5:4], joystick_0[2], joystick_0[3], joystick_0[1:0]};  // P1 R/L/U/D/B1/B2 active-high, U/D fixed
assign in1 = cdsteljn_mode ? mahjong_row
           : ctower_mode   ? {joystick_1[2], joystick_1[3], joystick_1[1:0], rstick1}
                           : {2'b00, joystick_1[5:4], joystick_1[2], joystick_1[3], joystick_1[1:0]};  // P2 R/L/U/D/B1/B2 active-high, U/D fixed
assign in2 = {~(joystick_0[6] | kb_coin1), ~(joystick_1[6] | kb_coin2), 1'b0,
              joystick_0[8]|joystick_1[8]|kb_start2, joystick_0[7]|joystick_1[7]|kb_start1, 3'b000}; // Coins, starts

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
	.audio_nmi_master_enable(audio_nmi_enable_reg)
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
	.sound_out    ({ay_right, ay_left})
);


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
	.options       (~status[26:25]),  // [0]=pause when OSD open; [1]=dim video after 10s
	.r             (core_r),
	.g             (core_g),
	.b             (core_b),
	.pause_cpu     (pause_cpu),
	.rgb_out       (rgb_pause)
);

// =========================================================================
// VIDEO OUTPUT
// =========================================================================
wire no_rotate  = status[2] | direct_video;
wire rotate_ccw = 1'b1;  // ROT270 = CCW for portrait DECO Cassette
wire flip       = status[11];

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
	.fx        (status[17:15])
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
