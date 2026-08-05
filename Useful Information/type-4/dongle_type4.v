/*============================================================================
  Type 4 Dongle — 15-bit Counter + 32KB PROM (Task 21)

  Implements the Type 4 dongle used in games like Scrum Try and Oozumou
  (The Grand Sumo).

  The Type 4 dongle performs:
  1. A 15-bit counter (m_type4_ctrs, range 0x0000–0x7FFF)
  2. A 32KB PROM (32K = 0x8000 bytes) indexed by the counter
  3. Auto-increment of the counter on each even-address PROM read
  4. An enable latch (m_type4_latch) that gates PROM vs. MCU passthrough

  Reference: MAME src/mame/dataeast/decocass_m.cpp, decocass_type4_state
             (decocass_type4_r / decocass_type4_w)

  State variables (mirroring MAME):
    - m_type4_ctrs   : 15-bit counter (0–0x7FFF, wraps at 0x8000)
    - m_type4_latch  : Enable latch. Bit 7 of an odd-address write is the
                       latch/mode-select bit; the low 7 bits are counter
                       payload. That is why the MSB load masks with 0x7f:
                       bit 7 is reserved for the latch, never for data.

  Write behavior (decocass_type4_w):
    - Odd address ($E5x1):
        * If latch == 1 : load counter MSB, ctr[14:8] = cpu_dout[6:0]
                          (== (data & 0x7f) << 8). Checked FIRST, and does
                          NOT re-test bit 7 — once latched, odd writes are
                          always MSB loads.
        * else if cpu_dout[7] : set latch = 1   (MAME: if (data & 0x80))
        * else : forward to MCU (passthrough handled outside this module)
    - Even address ($E5x0):
        * If latch == 1 : load counter LSB, ctr[7:0] = cpu_dout
        * else : forward to MCU

  Read behavior (decocass_type4_r):
    - Odd address ($E5x1): return MCU status (always)
    - Even address ($E5x0):
        * If latch == 1 : return PROM[ctr], then ctr = (ctr + 1) & 0x7FFF
                          (post-increment)
        * else : return MCU data
    - PROM address = ctr[14:0]

  NOTE ON THE FIX: the latch used to activate on (cpu_dout[7:4] == 4'hC),
  i.e. an exact top-nibble of 1100. Real hardware only requires bit 7 set.
  With the nibble test, any activation byte whose top nibble wasn't exactly
  C (e.g. 0x80) left the latch clear, so every even read fell through to the
  8041 (tape-loader) data port instead of the PROM — the checksum failed
  every time. Activation is bit 7 only.
============================================================================*/

`timescale 1 ps / 1 ps

module dongle_type4 (
    input  wire        clk_sys,
    input  wire        ce_hclk4,
    input  wire        reset,

    input  wire        cpu_re,
    input  wire        cpu_we,
    input  wire [7:0]  cpu_addr_lo,
    input  wire [7:0]  cpu_dout,
    output reg  [7:0]  cpu_din_full,        // 8-bit per MAME

    input  wire [7:0]  mcu_dbb_dout,
    input  wire [7:0]  mcu_dbb_sts,

    output wire [14:0] prom_addr,
    input  wire [7:0]  prom_q
);

    //------------------------------------------------------------------------
    // Internal state (synchronous updates)
    //------------------------------------------------------------------------
    reg [14:0] m_type4_ctrs;     // 15-bit counter (range 0–0x7FFF)
    reg        m_type4_latch;    // Enable latch (gates PROM vs. MCU passthrough)

    //------------------------------------------------------------------------
    // Synchronous state updates (decocass_type4_w + read auto-increment)
    //------------------------------------------------------------------------
    always @(posedge clk_sys) begin
        if (reset) begin
            m_type4_ctrs   <= 15'h0000;
            m_type4_latch  <= 1'b0;
        end
        else if (ce_hclk4) begin
            // ---- Write handler ------------------------------------------------
            if (cpu_we) begin
                if (cpu_addr_lo[0] == 1'b1) begin        // Odd address write ($E5x1)
                    if (m_type4_latch == 1'b1) begin
                        // Latch already set: load counter MSB.
                        // ctr[14:8] = cpu_dout[6:0]  ==  (data & 0x7f) << 8
                        // bit 7 is ignored here (reserved as the latch bit).
                        m_type4_ctrs[14:8] <= cpu_dout[6:0];
                    end
                    else if (cpu_dout[7] == 1'b1) begin
                        // Activation: latch on bit 7 (MAME: if (data & 0x80)).
                        m_type4_latch <= 1'b1;
                    end
                    // else: forward to MCU (passthrough handled externally)
                end
                else begin                               // Even address write ($E5x0)
                    if (m_type4_latch == 1'b1) begin
                        // Load counter LSB: ctr[7:0] = cpu_dout
                        m_type4_ctrs[7:0] <= cpu_dout;
                    end
                    // else: forward to MCU (passthrough handled externally)
                end
            end

            // ---- Read auto-increment -----------------------------------------
            // Even-address read while latched post-increments the counter,
            // wrapping at 0x8000 (15-bit).
            if (cpu_re && (cpu_addr_lo[0] == 1'b0) && (m_type4_latch == 1'b1)) begin
                m_type4_ctrs <= (m_type4_ctrs + 15'h0001) & 15'h7FFF;
            end
        end
    end

    //------------------------------------------------------------------------
    // PROM address = 15-bit counter
    //------------------------------------------------------------------------
    assign prom_addr = m_type4_ctrs;

    //------------------------------------------------------------------------
    // Output data mux: PROM vs. MCU passthrough
    //   odd  address -> MCU status (always)
    //   even address -> PROM byte if latched, else MCU data
    //------------------------------------------------------------------------
    always @(*) begin
        if (cpu_addr_lo[0] == 1'b1)
            cpu_din_full = mcu_dbb_sts;
        else
            cpu_din_full = m_type4_latch ? prom_q : mcu_dbb_dout;
    end

endmodule
