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
wire [31:0] status;
wire aspect_wide = status[1];
assign VIDEO_ARX = aspect_wide ? 12'd4 : 12'd3;
assign VIDEO_ARY = aspect_wide ? 12'd3 : 12'd4;

`include "build_id.v"
localparam CONF_STR = {
	"DECOCassette;;",
	"P1,Video Options;",
	"P1O[1],Aspect Ratio,3:4,Original;",
	"P1O[2],Orientation,Vertical,Horizontal;",
	"P1O[12],Flip Screen,Off,On;",
	"P1O[17:15],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"P2,Pause Options;",
	"P2O[25],Pause when OSD is open,On,Off;",
	"P2O[26],Dim video after 10s,On,Off;",
	"-;",
	"O[24],Autosave Hiscores,Off,On;",
	// "O[29:27],Fast Load,Off,2x,4x,8x,16x;",   (pre-PLAID-2026-10-25)
	"O[29:27],Fast Load,Off,2x,4x,8x,16x,PLAID;",
	"O[21:18],SDRAM Clk Phase,Auto,0.0ns,0.7ns,1.3ns,2.0ns,2.6ns,3.3ns,3.9ns,4.6ns,5.2ns,5.9ns,6.5ns,7.2ns,7.8ns,8.5ns,9.1ns;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Button 1,Button 2,Coin,Start 1P,Start 2P,Pause,R Right,R Left,R Down,R Up;",
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

wire        CLK_SDRAM;          // 96 MHz, same as clk_sys at phase position 0
wire [63:0] reconfig_to_pll, reconfig_from_pll;

pll pll
(
    .refclk   (CLK_50M),
    .rst      (1'b0),
    .outclk_0 (clk_sys),
    .outclk_1 (CLK_SDRAM),
    .locked   (pll_locked),
    .reconfig_to_pll   (reconfig_to_pll),
    .reconfig_from_pll (reconfig_from_pll)
);

// SDRAM clock phase. One DPS step = VCO/8 = 163 ps
// (768 MHz VCO), 64 per 96 MHz period; manual OSD entries are 4 steps. Auto: the dongle
// SDRAM path below sweeps all 64 after a dongle load and parks mid-window.
wire        cfg_waitrequest, cfg_write;
wire  [5:0] cfg_address;
wire [31:0] cfg_data;

pll_cfg pll_cfg
(
    .mgmt_clk(CLK_50M),
    .mgmt_reset(1'b0),
    .mgmt_waitrequest(cfg_waitrequest),
    .mgmt_read(1'b0),
    .mgmt_readdata(),
    .mgmt_write(cfg_write),
    .mgmt_address(cfg_address),
    .mgmt_writedata(cfg_data),
    .reconfig_to_pll(reconfig_to_pll),
    .reconfig_from_pll(reconfig_from_pll)
);

wire  [6:0] cal_ph;
wire        cal_tgl, cal_hold, ph_ack_tgl;

sdram_phase_ctl #(.CNT_SEL(5'd1), .MAN_STEP(7'd4)) phase_ctl
(
    .clk(CLK_50M),
    .sel(status[21:18]),
    .cal_val(cal_ph),
    .cal_tgl(cal_tgl),
    .ack_tgl(ph_ack_tgl),
    .cfg_waitrequest(cfg_waitrequest),
    .cfg_write(cfg_write),
    .cfg_address(cfg_address),
    .cfg_data(cfg_data)
);

// Phase moved: ack the calibrator and drop the prefetched byte.
reg  [2:0] ph_ack_s = 3'd0;
always @(posedge clk_sys) ph_ack_s <= {ph_ack_s[1:0], ph_ack_tgl};
wire       sd_recal = ph_ack_s[2] ^ ph_ack_s[1];

// Alias for legacy port names in screen_rotate / arcade_video below:
wire clk_vid = clk_sys;


wire pause_cpu;   // driven by pause_inst far below
wire ce_hclk_raw, ce_hclk1_raw, ce_hclk2_raw, ce_hclk4_raw, ce_audio_raw, ce_tape_raw;
wire hs_pause;    // driven by the hiscore instance far below
wire [15:0] hs_address;
wire  [7:0] hs_data_in, hs_data_out;
wire        hs_write_enable;
wire pl_restart;
wire ce_pix;

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
// CTL-2026-10-25: original keyboard block, replaced by ctl_keyboard below
// reg kb_start1 = 0, kb_start2 = 0, kb_coin1 = 0, kb_coin2 = 0;
// reg kb_old_toggle = 0;
// always @(posedge clk_sys) begin
// 	kb_old_toggle <= ps2_key[10];
// 	if (kb_old_toggle != ps2_key[10] && !ps2_key[8]) begin
// 		case (ps2_key[7:0])
// 			8'h16: kb_start1 <= ps2_key[9];
// 			8'h1E: kb_start2 <= ps2_key[9];
// 			8'h2E: kb_coin1  <= ps2_key[9];
// 			8'h36: kb_coin2  <= ps2_key[9];
// 			default: ;
// 		endcase
// 	end
// end
// CTL-2026-10-25: keyboard -> controllers.sv ctl_keyboard. STD_EXT 1 = these keys need the non-extended code, exactly the
// old `!ps2_key[8]` gate. kb[6] 1, kb[7] 2, kb[8] 5, kb[9] 6. No toggle keys, so pause changes nothing.
wire [12:0] kb;
/* verilator lint_off PINCONNECTEMPTY */
ctl_keyboard #(.STD_EXT(1)) keyboard(.clk(clk_sys), .ps2_key(ps2_key), .pause(pause_cpu), .kb(kb), .kbx());
/* verilator lint_on PINCONNECTEMPTY */
wire kb_start1 = kb[6];
wire kb_start2 = kb[7];
wire kb_coin1  = kb[8];
wire kb_coin2  = kb[9];

// HISCORE-2026-10-25: upload request + din now come from the hiscore instance (dump = ioctl index 4). Stubs were:
// assign ioctl_upload_req = 1'b0;
// assign ioctl_din        = 8'd0;

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
// cal_hold keeps the game in reset through the phase sweep
// wire reset = (RESET | status[0] | buttons[1] | ioctl_download | cal_hold);   (pre-PLAID-2026-10-25)
wire reset = (RESET | status[0] | buttons[1] | ioctl_download | cal_hold | pl_restart);   // pl_restart: PLAID toggled mid-load
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


// ============================================================================
// DDR3 dongle storage (Stage 2) — full 1 MB multigame dongle ROM via Sorgelig ddram.sv (rtl/mem/ddram.sv).
// Runs on clk_sys (= DDRAM_CLK) -> no clock-domain crossing. DDR byte address = dongle offset (base 0).
//  LOAD: ioctl index 1 streamed to DDR3, HPS throttled by ioctl_wait while each write is in flight.
//  READ: prefetch the byte at dprom_addr whenever it changes; the 6502 reads far slower than DDR latency.
// ============================================================================
reg  [7:0]  dprom_q_ddr;     // latched dongle byte (read result) -> board dprom_q
wire [19:0] dprom_addr;      // 20-bit (1 MB) for the Darksoft multigame; legacy types use low bits
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

// ---- SDRAM clock phase calibration ----
// Reference = the dongle region (index 1, SDRAM word 0 up), checksummed as it downloads.
// This path always reads at completion (Normal), so only Normal may win the sweep.
wire        cal_busy, cal_rd_go;
wire [14:0] cal_rd_word;
reg         sd_cal = 1'b0;
reg   [7:0] dl_prev = 8'd0;
reg  [15:0] sd_dout_d1;
always @(posedge clk_sys) sd_dout_d1 <= sd_dout;
always @(posedge clk_sys) if (ioctl_wr && dongle_ld) dl_prev <= ioctl_dout;
// Refresh fires only on the idle all-ones count: keep the bus free for its last 32 cycles.
wire        cal_take = !sd_busy && !wr_req_pend && cal_rd_go && (sd_refresh_cnt[9:5] != 5'h1F);
wire        cal_cpl  = sd_busy && sd_ready && !sd_rd && !sd_wr && sd_was_rd && sd_cal;

sdram_phase_cal #(.POS(7'd64), .LATCH_MASK(4'b0010), .QUIET_BITS(22)) phase_cal
(
    .clk(clk_sys), .por_reset(sdram_ld_reset),
    .ref_clr(ioctl_wr && dongle_ld && (ioctl_addr == 25'd0)),
    .ref_wd(ioctl_wr && dongle_ld && ioctl_addr[0]),
    .ref_w({ioctl_dout, dl_prev}),
    .ph_auto(status[21:18] == 4'd0), .ld_busy(ioctl_download | status[0]), .dl_active(ioctl_download),
    .blocked(1'b0),
    .ph_req_val(cal_ph), .ph_req_tgl(cal_tgl), .ph_ack(sd_recal),
    .rd_go(cal_rd_go), .rd_word(cal_rd_word), .rd_take(cal_take), .rd_cpl(cal_cpl),
    .sd_dout(sd_dout), .sd_dout_d1(sd_dout_d1),
    .busy(cal_busy), .hold(cal_hold)
);


// Throttle the HPS while a dongle write is requested/in-flight (combinational so it lands in time).
// cal_busy holds the HPS while an aborted sweep restores the phase
assign ioctl_wait = sd_busy || (ioctl_wr && dongle_ld) || cal_busy;

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
		sd_cal <= 1'b0;
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
				// a calibration read must not land in dprom_q_ddr
				if (sd_was_rd && !sd_cal) dprom_q_ddr <= sd_last_addr[0] ? sd_dout[15:8] : sd_dout[7:0];
				sd_cal <= 1'b0;
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
			end else if (!ioctl_download && !cal_busy && dprom_addr[19:0] != sd_last_addr) begin   // READ: prefetch
				sd_last_addr <= dprom_addr[19:0];
				sd_addr  <= {7'd0, dprom_addr[19:1]};
				sd_rd    <= 1; sd_busy <= 1; sd_was_rd <= 1;
			end else if (&sd_refresh_cnt) begin                    // periodic AUTO_REFRESH: one-edge toggle
				sd_refresh <= ~sd_refresh;
			end else if (cal_take) begin
				sd_addr <= {11'd0, cal_rd_word};
				sd_rd   <= 1; sd_busy <= 1; sd_was_rd <= 1; sd_cal <= 1;
			end
		end
		// a phase move invalidates the prefetched byte
		if (sd_recal) sd_last_addr <= 20'hFFFFF;
	end
end

sdram sdram_dongle (
	.init       (sdram_ld_reset),   // SDRAM-LOAD-RESET-2026-06-10: init early, stay ready through ioctl_download
	.clk        (clk_sys),
	.SDRAM_DQ   (SDRAM_DQ),   .SDRAM_A    (SDRAM_A),    .SDRAM_DQML (SDRAM_DQML), .SDRAM_DQMH (SDRAM_DQMH),
	.SDRAM_BA   (SDRAM_BA),   .SDRAM_nCS  (SDRAM_nCS),  .SDRAM_nWE  (SDRAM_nWE),  .SDRAM_nRAS (SDRAM_nRAS),
	// SDRAM_CLK is driven from CLK_SDRAM below
	.SDRAM_nCAS (SDRAM_nCAS), .SDRAM_CKE  (SDRAM_CKE),  .SDRAM_CLK  (),  .SDRAM_EN   (1'b1),
	.sel        (1'b1),
	.addr       (sd_addr),    .dout (sd_dout), .din (sd_din),
	.wr         (sd_wr),      .bs   (sd_bs),   .rd  (sd_rd),  .ready (sd_ready), .refresh (sd_refresh),
	.cpsel (1'b0), .cpaddr (26'd0), .cpdin (16'd0), .cprd (), .cpreq (1'b0), .cpbusy ()
);

// SDRAM_CLK: same inverted DDR output as sdram.sv's, on the phase-steppable CLK_SDRAM.
altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone V"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)
sdramclk_ddr
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(CLK_SDRAM),
	.dataout(SDRAM_CLK),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(1'b1),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
);

// =========================================================================
// DISPATCHER: shared pools + the DECO Cassette board
// =========================================================================
wire        tape_motor_on, hs_game_run;
wire signed [15:0] ay_left, ay_right;
wire [23:0] rgb_core;
wire        video_hblank_d, video_vblank_d, video_hsync_d, video_vsync_d;
wire [7:0]  core_r = rgb_core[23:16];
wire [7:0]  core_g = rgb_core[15:8];
wire [7:0]  core_b = rgb_core[7:0];

decocassette_dispatcher dispatcher
(
    .clk_sys               (clk_sys),
    .reset                 (reset),
    .pause_cpu             (pause_cpu),
    .ce_hclk_raw           (ce_hclk_raw),
    .ce_hclk1_raw          (ce_hclk1_raw),
    .ce_hclk2_raw          (ce_hclk2_raw),
    .ce_hclk4_raw          (ce_hclk4_raw),
    .ce_audio_raw          (ce_audio_raw),
    .ce_tape_raw           (ce_tape_raw),
    .ce_pix                (ce_pix),
    .hs_pause              (hs_pause),
    .hs_address            (hs_address),
    .hs_data_in            (hs_data_in),
    .hs_write_enable       (hs_write_enable),
    .hs_data_out           (hs_data_out),
    .hs_game_run           (hs_game_run),
    .pl_restart            (pl_restart),
    .ioctl_download        (ioctl_download),
    .ioctl_wr              (ioctl_wr),
    .ioctl_addr            (ioctl_addr),
    .ioctl_dout            (ioctl_dout),
    .ioctl_index           (ioctl_index),
    .fl_status             (status[29:27]),
    .crt_flip              (status[12]),
    .joystick_0            (joystick_0),
    .joystick_1            (joystick_1),
    .joystick_r_analog_0   (joystick_r_analog_0),
    .joystick_r_analog_1   (joystick_r_analog_1),
    .ps2_key               (ps2_key),
    .kb_coin1              (kb_coin1),
    .kb_coin2              (kb_coin2),
    .kb_start1             (kb_start1),
    .kb_start2             (kb_start2),
    .sw2                   (sw[2]),
    .sw3                   (sw[3]),
    .dprom_q               (dprom_q_ddr),
    .dprom_addr            (dprom_addr),
    .tape_motor_on         (tape_motor_on),
    .ay_left               (ay_left),
    .ay_right              (ay_right),
    .rgb_core              (rgb_core),
    .video_hblank_d        (video_hblank_d),
    .video_vblank_d        (video_vblank_d),
    .video_hsync_d         (video_hsync_d),
    .video_vsync_d         (video_vsync_d)
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
	// .pause_request (1'b0),   (pre-HISCORE-2026-10-25)
	.pause_request (hs_pause),
	.options       (~status[26:25]),  // [0]=pause when OSD open; [1]=dim video after 10s
	.r             (core_r),
	.g             (core_g),
	.b             (core_b),
	.pause_cpu     (pause_cpu),
	.rgb_out       (rgb_pause)
);

// =========================================================================
// HISCORE-2026-10-25: config = MRA index 3, dump = index 4; RAM through the CPU bus (decocass.v hs_*).
// The cassette load writes RAM $0000-$5FFF, so a restore before the game runs gets overwritten (user 2026-10-25).
// hiscore.v arms its restore on the falling edge of its reset, so hold that reset until the BIOS hands over to
// the game: the first opcode fetch below $F000 (cflyball trace: JMP $F146 -> $0503 after the load + rewind).
// =========================================================================
wire hs_reset = reset | ~hs_game_run;
// HISCORE-OSD-2026-10-25: hiscore.v extracts on every OSD open, even while held in reset. During the (minutes-long)
// load that copied mid-load RAM over the downloaded scores and autosaved it (HW: restore = garbage; sim: 27/36 bytes).
// So the OSD only reaches it once the game runs, 2 clocks late so its reset release (restore pending) comes first.
reg [1:0] hs_game_run_d = 2'b00;
always @(posedge clk_sys) hs_game_run_d <= {hs_game_run_d[0], hs_game_run};

hiscore #(
	.HS_ADDRESSWIDTH(16),
	.CFG_ADDRESSWIDTH(4),
	.CFG_LENGTHWIDTH(2)
) hi (
	.clk              (clk_sys),
	.paused           (pause_cpu),
	.reset            (hs_reset),
	.autosave         (status[24]),
	.ioctl_upload     (ioctl_upload),
	.ioctl_upload_req (ioctl_upload_req),
	.ioctl_download   (ioctl_download),
	.ioctl_wr         (ioctl_wr),
	.ioctl_addr       (ioctl_addr),
	.ioctl_index      (ioctl_index),
	// .OSD_STATUS       (OSD_STATUS),   (pre-HISCORE-OSD-2026-10-25)
	.OSD_STATUS       (OSD_STATUS & hs_game_run_d[1]),
	.data_from_hps    (ioctl_dout),
	.data_from_ram    (hs_data_out),
	.ram_address      (hs_address),
	.data_to_hps      (ioctl_din),
	.data_to_ram      (hs_data_in),
	.ram_write        (hs_write_enable),
	.ram_intent_read  (),
	.ram_intent_write (),
	.pause_cpu        (hs_pause),
	.configured       ()
);

// =========================================================================
// VIDEO OUTPUT
// =========================================================================
wire no_rotate  = status[2] | direct_video;
wire rotate_ccw = 1'b1;  // ROT270 = CCW for portrait DECO Cassette
wire flip       = 1'b0;      // HDMI flip removed: Flip Screen (status[12]) is the board's CRT Flip

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
