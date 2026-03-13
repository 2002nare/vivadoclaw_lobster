`timescale 1ns/1ps

module spi_slave_core_tb_stage0_3;
  timeunit 1ns;
  timeprecision 1ps;

  // ---------------------------------------------------------------------------
  // Stage 0~3 directed bring-up TB for spi_slave_core
  //
  // Implemented from the strengthened verification plan:
  //   - Stage 0: testbench infrastructure sanity
  //   - Stage 1: reset and idle behavior
  //   - Stage 2: minimum legal transaction frame
  //   - Stage 3: clk-domain report contract
  //
  // Intent:
  //   - Keep the bench plain SystemVerilog and debug-first.
  //   - Stay conservative on legal-start timing to avoid unspecified windows.
  //   - Check external black-box behavior strongly.
  //   - Support an optional internal report-event probe for exact latency checks.
  //
  // Optional exact-latency hook:
  //   The spec's exact clk-domain reporting latency is defined relative to the
  //   internal/report-side completion event, not directly to the serial edge.
  //   A pure black-box TB cannot always infer that event cycle exactly.
  //
  //   If the implementation exposes a suitable clk-domain report event, replace
  //   the assignment of tb_report_event_probe below with a DUT-specific signal
  //   (pulse or toggle normalized to one observable event per reported byte).
  // ---------------------------------------------------------------------------

  localparam time CLK_PERIOD         = 10ns;
  localparam time SCLK_HALF_PERIOD   = 20ns;
  localparam time LEGAL_CS_LEAD_TIME = 30ns;
  localparam int  RESET_HOLD_CLKS    = 4;
  localparam int  POST_RESET_CLKS    = 6;
  localparam int  RX_WAIT_TIMEOUT    = 24;
  localparam logic [7:0] DEFAULT_TX_BYTE = 8'h00;

  logic       clk;
  logic       rst_n;
  logic       sclk;
  logic       cs_n;
  logic       mosi;
  logic [7:0] tx_data;
  logic       tx_valid;
  logic [7:0] rx_data;
  logic       rx_valid;
  logic       miso_o;
  logic       miso_oe;

  int unsigned g_errors;
  int unsigned g_tests_run;
  int unsigned g_tests_passed;
  int unsigned g_tests_skipped;
  int          g_clk_cycle;

  int g_last_report_event_cycle;
  logic tb_report_event_probe;
  logic tb_report_event_probe_q;
  bit   tb_report_probe_available;

  spi_slave_core dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .sclk    (sclk),
    .cs_n    (cs_n),
    .mosi    (mosi),
    .miso_o  (miso_o),
    .miso_oe (miso_oe),
    .tx_data (tx_data),
    .tx_valid(tx_valid),
    .rx_data (rx_data),
    .rx_valid(rx_valid)
  );

  // Default: no internal report-event probe wired yet.
  // Replace with an implementation-specific signal when available.
  assign tb_report_event_probe = 1'b0;

  initial begin
    tb_report_probe_available = 1'b0;
  end

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  initial begin
    sclk = 1'b0;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      g_clk_cycle               <= 0;
      g_last_report_event_cycle <= -1;
      tb_report_event_probe_q   <= tb_report_event_probe;
    end
    else begin
      g_clk_cycle <= g_clk_cycle + 1;
      if (tb_report_probe_available && (tb_report_event_probe !== tb_report_event_probe_q)) begin
        g_last_report_event_cycle <= g_clk_cycle;
      end
      tb_report_event_probe_q <= tb_report_event_probe;
    end
  end

  // ---------------------------------------------------------------------------
  // Utility helpers
  // ---------------------------------------------------------------------------
  task automatic fail(input string msg);
    begin
      g_errors = g_errors + 1;
      $error("[FAIL] %s", msg);
    end
  endtask

  task automatic note(input string msg);
    begin
      $display("[NOTE] %s", msg);
    end
  endtask

  task automatic skip_current_test(input string name, input string reason);
    begin
      g_tests_skipped = g_tests_skipped + 1;
      $display("[TEST-SKIP] %s -- %s", name, reason);
    end
  endtask

  task automatic check_bit(input string name, input logic actual, input logic expected);
    begin
      if (actual !== expected) begin
        fail($sformatf("%s expected=%0b actual=%0b", name, expected, actual));
      end
    end
  endtask

  task automatic check_byte(input string name, input logic [7:0] actual, input logic [7:0] expected);
    begin
      if (actual !== expected) begin
        fail($sformatf("%s expected=0x%02h actual=0x%02h", name, expected, actual));
      end
    end
  endtask

  task automatic check_known_bit(input string name, input logic actual);
    begin
      if ((actual !== 1'b0) && (actual !== 1'b1)) begin
        fail($sformatf("%s is not 0/1 (actual=%b)", name, actual));
      end
    end
  endtask

  task automatic check_known_byte(input string name, input logic [7:0] actual);
    begin
      if (^actual === 1'bx) begin
        fail($sformatf("%s contains X/Z (actual=%h)", name, actual));
      end
    end
  endtask

  task automatic begin_test(input string name);
    begin
      g_tests_run = g_tests_run + 1;
      $display("\n[TEST-START] %s", name);
    end
  endtask

  task automatic end_test(input string name, input int unsigned errs_before);
    begin
      if (g_errors == errs_before) begin
        g_tests_passed = g_tests_passed + 1;
        $display("[TEST-PASS ] %s", name);
      end
      else begin
        $display("[TEST-FAIL ] %s", name);
      end
    end
  endtask

  task automatic init_drives;
    begin
      rst_n    = 1'b1;
      cs_n     = 1'b1;
      sclk     = 1'b0;
      mosi     = 1'b0;
      tx_data  = '0;
      tx_valid = 1'b0;
    end
  endtask

  task automatic wait_clk_cycles(input int n);
    begin
      repeat (n) @(posedge clk);
    end
  endtask

  task automatic wait_post_reset_settle;
    begin
      wait_clk_cycles(POST_RESET_CLKS);
      #1ns;
    end
  endtask

  task automatic apply_reset;
    begin
      rst_n = 1'b0;
      cs_n  = 1'b1;
      sclk  = 1'b0;
      wait_clk_cycles(RESET_HOLD_CLKS);
      rst_n = 1'b1;
      wait_post_reset_settle();
    end
  endtask

  task automatic expect_idle_outputs;
    begin
      check_bit("idle rx_valid", rx_valid, 1'b0);
      check_bit("idle miso_oe", miso_oe, 1'b0);
      check_known_bit("idle miso_o known", miso_o);
      check_known_byte("idle rx_data known", rx_data);
    end
  endtask

  task automatic preload_tx_byte(input logic [7:0] tx_preload_byte);
    begin
      tx_data  = tx_preload_byte;
      tx_valid = 1'b1;
      wait_clk_cycles(3);
    end
  endtask

  task automatic clear_tx_preload;
    begin
      tx_data  = '0;
      tx_valid = 1'b0;
      wait_clk_cycles(2);
    end
  endtask

  task automatic start_legal_frame;
    begin
      cs_n = 1'b1;
      sclk = 1'b0;
      #(SCLK_HALF_PERIOD);
      cs_n = 1'b0;
      #(LEGAL_CS_LEAD_TIME);
    end
  endtask

  task automatic end_frame;
    begin
      cs_n = 1'b1;
      sclk = 1'b0;
      #(SCLK_HALF_PERIOD);
    end
  endtask

  task automatic drive_sclk_rise(input logic mosi_value);
    begin
      mosi = mosi_value;
      #(SCLK_HALF_PERIOD);
      sclk = 1'b1;
      #(SCLK_HALF_PERIOD);
    end
  endtask

  task automatic drive_sclk_fall;
    begin
      sclk = 1'b0;
      #(SCLK_HALF_PERIOD);
    end
  endtask

  task automatic send_spi_byte_and_capture_miso(
    input  logic [7:0] mosi_byte,
    output logic [7:0] miso_bits_seen,
    input  bit         check_first_bit_before_first_rise,
    input  logic       expected_first_bit
  );
    int i;
    begin
      miso_bits_seen = '0;

      if (check_first_bit_before_first_rise) begin
        check_bit("miso_oe asserted before first rise", miso_oe, 1'b1);
        check_bit("miso bit7 present before first rise", miso_o, expected_first_bit);
      end

      for (i = 7; i >= 0; i--) begin
        miso_bits_seen[i] = miso_o;
        drive_sclk_rise(mosi_byte[i]);
        if (i > 0) begin
          drive_sclk_fall();
        end
      end
    end
  endtask

  task automatic run_single_legal_frame(
    input  logic [7:0] tx_byte,
    input  logic       use_preload,
    input  logic [7:0] rx_byte,
    input  bit         check_first_bit,
    output logic [7:0] miso_seen
  );
    begin
      init_drives();
      apply_reset();
      if (use_preload) begin
        preload_tx_byte(tx_byte);
      end
      else begin
        clear_tx_preload();
      end
      start_legal_frame();
      send_spi_byte_and_capture_miso(
        rx_byte,
        miso_seen,
        check_first_bit,
        use_preload ? tx_byte[7] : DEFAULT_TX_BYTE[7]
      );
      end_frame();
    end
  endtask

  task automatic wait_for_rx_valid_rise(
    output int valid_cycle,
    output bit timed_out,
    input  string wait_context
  );
    int waited;
    begin
      timed_out  = 1'b0;
      valid_cycle = -1;
      waited = 0;
      while ((rx_valid !== 1'b1) && (waited < RX_WAIT_TIMEOUT)) begin
        @(posedge clk);
        waited++;
      end
      if (rx_valid === 1'b1) begin
        valid_cycle = g_clk_cycle;
      end
      else begin
        timed_out = 1'b1;
        fail($sformatf("Timed out waiting for rx_valid during %s", wait_context));
      end
    end
  endtask

  task automatic check_rx_valid_single_cycle_and_data(
    input logic [7:0] expected_rx_data,
    input string      check_context,
    output int        valid_cycle,
    output bit        saw_pulse
  );
    bit timed_out;
    begin
      saw_pulse = 1'b0;
      valid_cycle = -1;
      wait_for_rx_valid_rise(valid_cycle, timed_out, check_context);
      if (!timed_out) begin
        saw_pulse = 1'b1;
        check_byte({check_context, " rx_data during valid"}, rx_data, expected_rx_data);
        @(posedge clk);
        check_bit({check_context, " rx_valid single-cycle"}, rx_valid, 1'b0);
      end
    end
  endtask

  task automatic check_rx_data_stable_during_valid(
    input logic [7:0] expected_rx_data,
    input string      stable_context
  );
    logic [7:0] sample0;
    begin
      check_byte({stable_context, " rx_data@valid_start"}, rx_data, expected_rx_data);
      sample0 = rx_data;
      #(CLK_PERIOD/4);
      check_byte({stable_context, " rx_data quarter-cycle stable"}, rx_data, sample0);
      #(CLK_PERIOD/4);
      check_byte({stable_context, " rx_data half-cycle stable"}, rx_data, sample0);
      #(CLK_PERIOD/4);
      check_byte({stable_context, " rx_data three-quarter-cycle stable"}, rx_data, sample0);
    end
  endtask

  task automatic expect_no_rx_valid_for_cycles(input int n, input string expect_context);
    int i;
    begin
      for (i = 0; i < n; i++) begin
        @(posedge clk);
        if (rx_valid === 1'b1) begin
          fail($sformatf("Unexpected rx_valid during %s at cycle offset %0d", expect_context, i));
        end
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  // Assertions useful in early bring-up
  // ---------------------------------------------------------------------------
  property p_rx_valid_single_cycle;
    @(posedge clk) disable iff (!rst_n)
      rx_valid |=> !rx_valid;
  endproperty

  property p_no_rx_valid_during_reset;
    @(posedge clk)
      !rst_n |-> !rx_valid;
  endproperty

  property p_miso_oe_inactive_when_cs_high;
    @(posedge clk) disable iff (!rst_n)
      cs_n |-> !miso_oe;
  endproperty

  assert property (p_rx_valid_single_cycle)
    else fail("Assertion failed: rx_valid must be a single-cycle pulse");

  assert property (p_no_rx_valid_during_reset)
    else fail("Assertion failed: rx_valid must remain low during reset");

  assert property (p_miso_oe_inactive_when_cs_high)
    else fail("Assertion failed: miso_oe must be inactive when cs_n is high");

  // ---------------------------------------------------------------------------
  // Stage 0 tests
  // ---------------------------------------------------------------------------
  task automatic test_tb_clk_reset_smoke;
    int unsigned errs_before;
    begin
      errs_before = g_errors;
      begin_test("TB_CLK_RESET_SMOKE");

      init_drives();
      rst_n = 1'b0;
      wait_clk_cycles(3);
      check_bit ("reset miso_oe", miso_oe, 1'b0);
      check_bit ("reset miso_o",  miso_o,  1'b0);
      check_bit ("reset rx_valid", rx_valid, 1'b0);
      check_byte("reset rx_data",  rx_data, 8'h00);

      rst_n = 1'b1;
      wait_post_reset_settle();
      check_known_bit ("post-reset miso_o known", miso_o);
      check_known_byte("post-reset rx_data known", rx_data);

      end_test("TB_CLK_RESET_SMOKE", errs_before);
    end
  endtask

  task automatic test_tb_output_connectivity_smoke;
    int unsigned errs_before;
    begin
      errs_before = g_errors;
      begin_test("TB_OUTPUT_CONNECTIVITY_SMOKE");

      init_drives();
      apply_reset();
      expect_idle_outputs();
      expect_no_rx_valid_for_cycles(4, "idle connectivity smoke");

      end_test("TB_OUTPUT_CONNECTIVITY_SMOKE", errs_before);
    end
  endtask

  // ---------------------------------------------------------------------------
  // Stage 1 tests
  // ---------------------------------------------------------------------------
  task automatic test_reset_idle_baseline;
    int unsigned errs_before;
    begin
      errs_before = g_errors;
      begin_test("RESET_IDLE_BASELINE");

      init_drives();
      rst_n = 1'b0;
      wait_clk_cycles(4);
      check_bit ("reset baseline miso_oe", miso_oe, 1'b0);
      check_bit ("reset baseline miso_o",  miso_o,  1'b0);
      check_bit ("reset baseline rx_valid", rx_valid, 1'b0);
      check_byte("reset baseline rx_data",  rx_data, 8'h00);

      rst_n = 1'b1;
      wait_post_reset_settle();
      expect_idle_outputs();

      end_test("RESET_IDLE_BASELINE", errs_before);
    end
  endtask

  task automatic test_ignore_spi_activity_during_reset;
    int unsigned errs_before;
    int i;
    begin
      errs_before = g_errors;
      begin_test("IGNORE_SPI_ACTIVITY_DURING_RESET");

      init_drives();
      rst_n = 1'b0;
      cs_n  = 1'b0;
      for (i = 0; i < 6; i++) begin
        mosi = i[0];
        #7ns  sclk = ~sclk;
        #11ns sclk = ~sclk;
      end
      cs_n = 1'b1;
      check_bit("miso_oe remains low during reset activity", miso_oe, 1'b0);
      check_bit("rx_valid remains low during reset activity", rx_valid, 1'b0);

      rst_n = 1'b1;
      wait_post_reset_settle();
      expect_idle_outputs();
      expect_no_rx_valid_for_cycles(6, "post-reset after reset-period SPI activity");

      end_test("IGNORE_SPI_ACTIVITY_DURING_RESET", errs_before);
    end
  endtask

  task automatic test_idle_with_cs_high;
    int unsigned errs_before;
    int i;
    begin
      errs_before = g_errors;
      begin_test("IDLE_WITH_CS_HIGH");

      init_drives();
      apply_reset();
      cs_n = 1'b1;
      for (i = 0; i < 5; i++) begin
        mosi = ~mosi;
        #(SCLK_HALF_PERIOD) sclk = 1'b1;
        #(SCLK_HALF_PERIOD) sclk = 1'b0;
      end
      expect_idle_outputs();
      expect_no_rx_valid_for_cycles(4, "cs_n high activity");

      end_test("IDLE_WITH_CS_HIGH", errs_before);
    end
  endtask

  // ---------------------------------------------------------------------------
  // Stage 2 tests
  // ---------------------------------------------------------------------------
  task automatic test_single_legal_frame_preloaded_tx_min;
    int unsigned errs_before;
    logic [7:0] miso_seen;
    int valid_cycle;
    bit saw_pulse;
    begin
      errs_before = g_errors;
      begin_test("SINGLE_LEGAL_FRAME_PRELOADED_TX_MIN");

      run_single_legal_frame(8'hA5, 1'b1, 8'h3C, 1'b1, miso_seen);
      check_byte("captured MISO sequence", miso_seen, 8'hA5);
      check_rx_valid_single_cycle_and_data(8'h3C, "single_legal_frame", valid_cycle, saw_pulse);
      clear_tx_preload();

      end_test("SINGLE_LEGAL_FRAME_PRELOADED_TX_MIN", errs_before);
    end
  endtask

  task automatic test_first_bit_present_before_first_rise;
    int unsigned errs_before;
    logic [7:0] dummy_seen;
    begin
      errs_before = g_errors;
      begin_test("FIRST_BIT_PRESENT_BEFORE_FIRST_RISE");

      init_drives();
      apply_reset();
      preload_tx_byte(8'h80);

      start_legal_frame();
      check_bit("pre-first-rise miso_oe", miso_oe, 1'b1);
      check_bit("pre-first-rise miso_o",  miso_o, 1'b1);
      send_spi_byte_and_capture_miso(8'h00, dummy_seen, 1'b0, 1'b0);
      end_frame();

      begin
        int valid_cycle;
        bit saw_pulse;
        check_rx_valid_single_cycle_and_data(8'h00, "first_bit_present", valid_cycle, saw_pulse);
      end

      clear_tx_preload();
      end_test("FIRST_BIT_PRESENT_BEFORE_FIRST_RISE", errs_before);
    end
  endtask

  // ---------------------------------------------------------------------------
  // Stage 3 tests
  // ---------------------------------------------------------------------------
  task automatic test_rx_valid_single_cycle_and_latency_exact;
    int unsigned errs_before;
    logic [7:0] miso_seen;
    int valid_cycle;
    bit saw_pulse;
    begin
      errs_before = g_errors;
      begin_test("RX_VALID_SINGLE_CYCLE_AND_LATENCY_EXACT");

      run_single_legal_frame(8'h96, 1'b1, 8'h3A, 1'b1, miso_seen);
      check_byte("latency test MISO sequence", miso_seen, 8'h96);
      check_rx_valid_single_cycle_and_data(8'h3A, "latency_exact", valid_cycle, saw_pulse);

      if (saw_pulse && tb_report_probe_available) begin
        if (g_last_report_event_cycle < 0) begin
          fail("Exact latency check requested but no internal report event was observed");
        end
        else if (valid_cycle != (g_last_report_event_cycle + 1)) begin
          fail($sformatf(
            "rx_valid exact latency mismatch: report_event_cycle=%0d valid_cycle=%0d expected=%0d",
            g_last_report_event_cycle,
            valid_cycle,
            g_last_report_event_cycle + 1
          ));
        end
      end
      else begin
        skip_current_test(
          "RX_VALID_SINGLE_CYCLE_AND_LATENCY_EXACT/exact-subcheck",
          "internal report-event probe is not wired; external single-cycle reporting was still checked"
        );
      end

      clear_tx_preload();
      end_test("RX_VALID_SINGLE_CYCLE_AND_LATENCY_EXACT", errs_before);
    end
  endtask

  task automatic test_rx_data_stable_during_valid;
    int unsigned errs_before;
    logic [7:0] miso_seen;
    bit timed_out;
    int valid_cycle;
    begin
      errs_before = g_errors;
      begin_test("RX_DATA_STABLE_DURING_VALID");

      run_single_legal_frame(8'h81, 1'b1, 8'h96, 1'b1, miso_seen);
      check_byte("stable-data MISO sequence", miso_seen, 8'h81);

      wait_for_rx_valid_rise(valid_cycle, timed_out, "stable_during_valid");
      if (!timed_out) begin
        check_rx_data_stable_during_valid(8'h96, "stable_during_valid");
        @(posedge clk);
        check_bit("stable_during_valid single-cycle", rx_valid, 1'b0);
      end

      clear_tx_preload();
      end_test("RX_DATA_STABLE_DURING_VALID", errs_before);
    end
  endtask

  task automatic test_single_completion_no_double_pulse;
    int unsigned errs_before;
    logic [7:0] miso_seen;
    int valid_cycle;
    bit saw_pulse;
    begin
      errs_before = g_errors;
      begin_test("SINGLE_COMPLETION_NO_DOUBLE_PULSE");

      run_single_legal_frame(8'h5A, 1'b1, 8'hC3, 1'b1, miso_seen);
      check_byte("single-completion MISO sequence", miso_seen, 8'h5A);
      check_rx_valid_single_cycle_and_data(8'hC3, "single_completion", valid_cycle, saw_pulse);
      expect_no_rx_valid_for_cycles(10, "single completion duplicate-pulse window");

      clear_tx_preload();
      end_test("SINGLE_COMPLETION_NO_DOUBLE_PULSE", errs_before);
    end
  endtask

  // ---------------------------------------------------------------------------
  // Main sequence
  // ---------------------------------------------------------------------------
  initial begin
    g_errors            = 0;
    g_tests_run         = 0;
    g_tests_passed      = 0;
    g_tests_skipped     = 0;
    g_clk_cycle         = 0;
    g_last_report_event_cycle = -1;

    init_drives();
    wait_clk_cycles(2);

    // Stage 0
    test_tb_clk_reset_smoke();
    test_tb_output_connectivity_smoke();

    // Stage 1
    test_reset_idle_baseline();
    test_ignore_spi_activity_during_reset();
    test_idle_with_cs_high();

    // Stage 2
    test_single_legal_frame_preloaded_tx_min();
    test_first_bit_present_before_first_rise();

    // Stage 3
    test_rx_valid_single_cycle_and_latency_exact();
    test_rx_data_stable_during_valid();
    test_single_completion_no_double_pulse();

    $display("\n============================================================");
    $display("TB SUMMARY: passed %0d / %0d tests, skipped=%0d, errors=%0d",
             g_tests_passed, g_tests_run, g_tests_skipped, g_errors);
    $display("============================================================");

    if (g_errors != 0) begin
      $fatal(1, "spi_slave_core_tb_stage0_3 FAILED");
    end
    else begin
      $finish;
    end
  end

endmodule
