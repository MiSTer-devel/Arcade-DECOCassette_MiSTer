/*============================================================================
  tb_dongle_type4.v — self-checking testbench for dongle_type4

  What it exercises:
    1. Pre-activation passthrough : even-read returns MCU data, not PROM.
    2. Activation on bit 7        : uses 0x80 (top nibble 0x8, NOT 0xC) — this
                                    is exactly the byte the old nibble==C test
                                    failed on, so this TB fails against the
                                    buggy module and passes against the fix.
    3. Counter seeding            : MSB via odd write, LSB via even write.
    4. PROM streaming + auto-inc  : successive even reads return PROM[seed],
                                    PROM[seed+1], ... (post-increment).
    5. Odd read returns MCU status.
    6. Checksum                   : 8-bit sum of the streamed bytes matches the
                                    sum computed directly over the PROM image.

  ce_hclk4 is held high and each bus op occupies exactly one clk cycle with
  cpu_re/cpu_we pulsed for a single cycle (single-tick strobe) so the counter
  never double-increments.
============================================================================*/

`timescale 1 ps / 1 ps

module tb_dongle_type4;

    // ---- clock ----
    reg clk = 1'b0;
    always #5000 clk = ~clk;          // 10 ns period (ps units)

    // ---- DUT I/O ----
    reg        reset;
    reg        cpu_re, cpu_we;
    reg  [7:0] cpu_addr_lo, cpu_dout;
    wire [7:0] cpu_din_full;

    reg  [7:0] mcu_dbb_dout = 8'h5A;  // sentinel: "this is MCU data"
    reg  [7:0] mcu_dbb_sts  = 8'hA5;  // sentinel: "this is MCU status"

    wire [14:0] prom_addr;
    reg  [7:0]  prom_q;

    // ce_hclk4 held high; ops are single-cycle strobes
    wire ce_hclk4 = 1'b1;

    dongle_type4 dut (
        .clk_sys      (clk),
        .ce_hclk4     (ce_hclk4),
        .reset        (reset),
        .cpu_re       (cpu_re),
        .cpu_we       (cpu_we),
        .cpu_addr_lo  (cpu_addr_lo),
        .cpu_dout     (cpu_dout),
        .cpu_din_full (cpu_din_full),
        .mcu_dbb_dout (mcu_dbb_dout),
        .mcu_dbb_sts  (mcu_dbb_sts),
        .prom_addr    (prom_addr),
        .prom_q       (prom_q)
    );

    // ---- behavioral 32KB PROM (combinational, matches the module's timing) ----
    reg [7:0] prom_mem [0:32767];
    integer   i;
    initial begin
        for (i = 0; i < 32768; i = i + 1)
            prom_mem[i] = (i * 197 + 23) & 8'hFF;   // arbitrary, reproducible
    end
    always @(*) prom_q = prom_mem[prom_addr];

    // ---- bus tasks ----
    task bus_write(input a0, input [7:0] data);
    begin
        @(negedge clk);
        cpu_addr_lo = {7'b0, a0};
        cpu_dout    = data;
        cpu_we      = 1'b1;
        cpu_re      = 1'b0;
        @(posedge clk);          // DUT captures the write here
        @(negedge clk);
        cpu_we      = 1'b0;
    end
    endtask

    // Even/odd read. Samples cpu_din_full while cpu_re is asserted, BEFORE the
    // posedge that post-increments the counter.
    task bus_read(input a0, output [7:0] data);
    begin
        @(negedge clk);
        cpu_addr_lo = {7'b0, a0};
        cpu_re      = 1'b1;
        cpu_we      = 1'b0;
        #1000 data  = cpu_din_full;   // comb output = PROM[current ctr]
        @(posedge clk);               // counter increments here (even + latched)
        @(negedge clk);
        cpu_re      = 1'b0;
    end
    endtask

    // ---- test sequence ----
    localparam [14:0] SEED = 15'h0140;   // ctr high = 0x01, ctr low = 0x40
    localparam integer N   = 16;

    integer      k;
    reg  [7:0]   d;
    reg  [7:0]   sum_stream, sum_expect;
    integer      errors;

    initial begin
        errors      = 0;
        cpu_re      = 0;
        cpu_we      = 0;
        cpu_addr_lo = 0;
        cpu_dout    = 0;
        reset       = 1;
        repeat (3) @(posedge clk);
        @(negedge clk) reset = 0;

        // 1) Pre-activation: even read must return MCU data (passthrough).
        bus_read(1'b0, d);
        if (d !== mcu_dbb_dout) begin
            $display("FAIL: pre-activation even read = %02x, expected MCU data %02x", d, mcu_dbb_dout);
            errors = errors + 1;
        end else
            $display("PASS: pre-activation even read passes through to MCU data (%02x)", d);

        // 2) Activate the latch with 0x80 (top nibble 0x8, not 0xC).
        bus_write(1'b1, 8'h80);

        // 3) Seed the counter: MSB (odd, bit7 clear) then LSB (even).
        bus_write(1'b1, {1'b0, SEED[14:8]});   // ctr[14:8] = 0x01
        bus_write(1'b0, SEED[7:0]);            // ctr[7:0]  = 0x40

        // 4) Confirm latch engaged: even read now returns PROM, not 0x5A.
        //    (Peek without disturbing the stream: check the mux value equals
        //     PROM[SEED] on the first streamed read below.)

        // 5) Stream N bytes and checksum them.
        sum_stream = 8'h00;
        sum_expect = 8'h00;
        for (k = 0; k < N; k = k + 1) begin
            bus_read(1'b0, d);
            sum_stream = sum_stream + d;
            sum_expect = sum_expect + prom_mem[(SEED + k) & 15'h7FFF];
            if (d !== prom_mem[(SEED + k) & 15'h7FFF]) begin
                $display("FAIL: stream[%0d] = %02x, expected PROM[%04x] = %02x",
                          k, d, (SEED + k) & 15'h7FFF, prom_mem[(SEED + k) & 15'h7FFF]);
                errors = errors + 1;
            end
        end
        if (sum_stream === sum_expect)
            $display("PASS: streamed %0d bytes from PROM[%04x], checksum = %02x (matches)",
                      N, SEED, sum_stream);
        else begin
            $display("FAIL: checksum mismatch: stream %02x vs expect %02x", sum_stream, sum_expect);
            errors = errors + 1;
        end

        // 6) Odd read returns MCU status, and must NOT advance the counter.
        begin : odd_check
            reg [14:0] ctr_before, ctr_after;
            ctr_before = dut.m_type4_ctrs;
            bus_read(1'b1, d);
            ctr_after  = dut.m_type4_ctrs;
            if (d !== mcu_dbb_sts) begin
                $display("FAIL: odd read = %02x, expected MCU status %02x", d, mcu_dbb_sts);
                errors = errors + 1;
            end else
                $display("PASS: odd read returns MCU status (%02x)", d);
            if (ctr_after !== ctr_before) begin
                $display("FAIL: odd read moved the counter %04x -> %04x", ctr_before, ctr_after);
                errors = errors + 1;
            end else
                $display("PASS: odd read left the counter at %04x", ctr_after);
        end

        // ---- summary ----
        $display("--------------------------------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d FAILURE(S)", errors);
        $display("--------------------------------------------------");
        $finish;
    end

    // safety timeout
    initial begin
        #5000000;
        $display("FAIL: timeout");
        $finish;
    end

endmodule
