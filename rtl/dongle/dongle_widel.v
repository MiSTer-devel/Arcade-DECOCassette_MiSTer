/*============================================================================
  Widel Dongle — 20-bit Counter + 1 MB ROM (David Widel multigame kit)

  Implements the dongle used by decomult (DECO Cassette System ROM Multigame,
  David Widel bootleg) and required by games it hosts that need real per-game
  dongle data (e.g. Treasure Island), unlike the Darksoft kit.

  Reference: decocass_m.cpp:1068-1146 (decocass_widel_r/_w), decocass.h:445-464.

  MAME semantics (offset bit1 already resolved upstream — the wrapper only
  routes here when cpu_addr[1]==0, i.e. $E5x0/$E5x1; $E5x2/$E5x3 go to the
  shared STATUS byte path outside this module, same convention as type1-5):

  Read $E500 (even):
    - latched:      data = donglerom[ctrs]; ctrs += 1  (wraps mod 0x100000)
    - not latched:  data = mcu_dbb_dout (8041 DBBOUT passthrough)

  Read $E501 (odd):
    - data = mcu_dbb_sts ALWAYS (latched or not)
    - latched ONLY: ctrs += 0x100 as a READ side effect (wraps mod 0x100000)
      (the counter still advances even though the returned byte is MCU status,
      not PROM data — this is genuine MAME behaviour, not a modelling quirk)

  Write $E501 (odd):
    - latched:      ctrs <= 0  (BOTH halves cleared; the written value is
                     ignored — comment in MAME source: Treasure Island depends
                     on this clearing the lower bits too)
    - not latched, (data[7:4]==0xC): latch <= 1  (activation)
    - MCU host write forwarding (upi41_master_w) is handled unconditionally by
      mcu_tape_iface elsewhere in the wrapper for ALL dongle types (same as
      type4) — this module only tracks its own counter/latch state.

  Write $E500 (even):
    - latched:      ctrs[7:0] <= data   (LSB only; [19:8] unchanged)
    - not latched:  no local effect (MCU write handled elsewhere, as above)
============================================================================*/

`timescale 1 ps / 1 ps

module dongle_widel (
    input  wire        clk_sys,
    input  wire        ce_hclk4,
    input  wire        reset,

    input  wire        cpu_re,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_addr_lo,
    input  wire [7:0]  cpu_dout,
    output reg  [7:0]  cpu_din_full,

    input  wire [7:0]  mcu_dbb_dout,
    input  wire [7:0]  mcu_dbb_sts,

    output wire [19:0] prom_addr,
    input  wire [7:0]  prom_q
);

    reg [19:0] m_widel_ctrs;
    reg        m_widel_latch;

    assign prom_addr = m_widel_ctrs;

    always @(posedge clk_sys) begin
        if (reset) begin
            m_widel_ctrs  <= 20'd0;
            m_widel_latch <= 1'b0;
        end
        else if (ce_hclk4) begin
            if (cpu_we) begin
                if (cpu_addr_lo[0]) begin            // odd write ($E5x1)
                    if (m_widel_latch)
                        m_widel_ctrs <= 20'd0;        // any odd write resets ctrs while latched
                    else if (cpu_dout[7:4] == 4'hC)
                        m_widel_latch <= 1'b1;        // activation sequence
                end
                else begin                            // even write ($E5x0)
                    if (m_widel_latch)
                        m_widel_ctrs[7:0] <= cpu_dout; // LSB only
                end
            end

            if (cpu_re) begin
                if (cpu_addr_lo[0]) begin             // odd read ($E5x1): +0x100 side effect
                    if (m_widel_latch)
                        m_widel_ctrs <= m_widel_ctrs + 20'h00100;
                end
                else begin                            // even read ($E5x0): +1
                    if (m_widel_latch)
                        m_widel_ctrs <= m_widel_ctrs + 20'h00001;
                end
            end
        end
    end

    always @(*) begin
        if (cpu_addr_lo[0])
            cpu_din_full = mcu_dbb_sts;                        // $E501 always returns MCU status
        else
            cpu_din_full = m_widel_latch ? prom_q : mcu_dbb_dout;
    end

endmodule
