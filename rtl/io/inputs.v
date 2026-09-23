//============================================================================
//  DECO Cassette System - Input Mux at $E6xx
//
//  This module implements the input data multiplexer at address $E6xx,
//  exposing the raw input bus and providing decoded read response per
//  address offset and MCU mux control.
//
//  Based on MAME src/mame/deco/decocass_m.cpp:
//    - decocass_input_r (lines 182-199): dispatches by offset[2:0]
//
//  Input Layout (active-low for joysticks/buttons; active-low for coins):
//    - IN0: P1 joystick + buttons (R/L/U/D, B1, B2) — bits[5:0]
//    - IN1: P2 cocktail joystick + buttons (R/L/U/D, B1, B2) — bits[5:0]
//    - IN2: START1/START2, COIN1/COIN2 — bits[7:0]
//    - DSW1: DIP switches (Coin A, Coin B, Tape Type, Cabinet, VBLANK) — bits[7:0]
//    - DSW2: DIP switches (per-game) — bits[7:0]
//
//============================================================================

module inputs (
    input  wire        clk_sys,
    input  wire        ce_hclk1,
    input  wire        reset,

    // CPU address/read strobes
    input  wire [7:0]  cpu_addr_lo,         // cpu_addr[7:0] from decocass.v
    input  wire        cpu_we_e6xx,         // strobe on $E6xx access (read or write)
    input  wire        cpu_rw_n,            // 1=read, 0=write

    // Raw input bus (from MiSTer hps_io via Arcade-DECOCassette.sv, task 26)
    // Active-low for joysticks, buttons, coins per MAME INPUT_PORTS_START
    input  wire [7:0]  in0,                 // P1: R/L/U/D, B1, B2, unused[7:6]
    input  wire [7:0]  in1,                 // P2 cocktail: R/L/U/D, B1, B2, unused[7:6]
    input  wire [7:0]  in2,                 // bit[3]=START1, bit[4]=START2, bit[6]=COIN2, bit[7]=COIN1
    input  wire [7:0]  dsw1,                // bit[7]=VBLANK, bit[6]=CABINET, bits[5:0]=DIP switches
    input  wire [7:0]  dsw2,                // game-specific DIP switches
    input  wire        vblank,              // live vblank signal from video_timing

    // MCU mux control (from i8041 P2[3:0], task 15)
    input  wire [3:0]  mcu_p2_low4,         // TODO(verify-with-mame): MCU controls input mux for cdsteljn mahjong

    // Output: read data for input mux at $E6xx
    output reg  [7:0]  input_q
);

    //------------------------------------------------------------------------
    // Address decode for $E6xx (combinational read mux)
    // Reference: decocass_m.cpp line 182-199, decocass_input_r(offset)
    //------------------------------------------------------------------------

    wire [2:0] offset = cpu_addr_lo[2:0];

    // Read-only combinational mux; latch outputs for synchronization
    always @* begin
        // Combinational priority-mux based on offset
        case (offset)
            3'b000:  input_q = in0;      // $E600: IN0 (P1 joystick + buttons)
            3'b001:  input_q = in1;      // $E601: IN1 (P2 cocktail joystick + buttons)
            3'b010:  input_q = in2;      // $E602: IN2 (START, COIN bits)
            3'b011:  input_q = 8'hFF;    // $E603: unused (cdsteljn's mahjong panel is on in0/in1, see mahjong_panel.v)
            3'b100,
            3'b101,
            3'b110:  input_q = 8'h00;    // $E604-$E606: quadrature decoder
                                          // TODO(verify-with-mame): handled by separate module
            3'b111:  input_q = 8'h00;    // $E607: ADC converter (quadrature #4)
            default: input_q = 8'hFF;
        endcase
    end

    //------------------------------------------------------------------------
    // DSW1[7] = VBLANK (sampled live on read)
    //
    // Note: decocass.cpp line 214 defines DSW1[7] as:
    //    PORT_BIT( 0x80, IP_ACTIVE_HIGH, IPT_CUSTOM)
    //    PORT_READ_LINE_DEVICE_MEMBER("screen", FUNC(screen_device::vblank))
    //
    // This means DSW1[7] always reflects the current vblank signal and is
    // read combinationally on $E300 read (in decocass.v cpu_din_mux).
    //
    // The top-level module should insert vblank into DSW1[7] on $E300 read.
    // This module exposes mcu_p2_low4 for potential future use in cdsteljn
    // mahjong input matrix decoding.
    //------------------------------------------------------------------------

    // Unused signals (for reference/documentation)
    // - dsw1[6] = CABINET (cocktail mode DIP) — consumed by watchdog.v for flip_screen
    // - dsw2[*] = game-specific DIP switches
    // - mcu_p2_low4[3:0] = MCU P2 lower 4 bits (gates mahjong matrix column)

endmodule
