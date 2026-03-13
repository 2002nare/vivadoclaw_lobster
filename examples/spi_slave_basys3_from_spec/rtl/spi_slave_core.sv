module spi_slave_core #(
  parameter logic [7:0] DEFAULT_TX_BYTE = 8'h00
) (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       sclk,
  input  logic       cs_n,
  input  logic       mosi,
  output logic       miso_o,
  output logic       miso_oe,
  input  logic [7:0] tx_data,
  input  logic       tx_valid,
  output logic [7:0] rx_data,
  output logic       rx_valid
);

  // --------------------------------------------------------------------------
  // Basic synthesizable SPI Mode-0 slave core
  //
  // Notes
  // - Fixed 8-bit frames, MSB-first.
  // - MOSI is sampled on rising sclk edges.
  // - MISO is updated on falling sclk edges by deriving the visible bit from
  //   the selected frame byte, the accepted-bit count, and the current sclk
  //   level. This keeps the edge semantics explicit without simulation-only
  //   constructs.
  // - tx_data/tx_valid are first staged in the clk domain and then used as the
  //   pending-frame source. This is a pragmatic bring-up implementation meant
  //   to preserve the external contract for early directed verification.
  // - Completed RX bytes cross into clk via a toggle-based event mailbox with
  //   one-cycle-later rx_valid pulse generation.
  // --------------------------------------------------------------------------

  logic [7:0] tx_hold_data_clk;
  logic       tx_hold_valid_clk;

  logic [7:0] tx_frame_byte_sclk;
  logic [7:0] rx_shift_reg_sclk;
  logic [7:0] rx_hold_sclk;
  logic [3:0] bit_count_sclk;
  logic       frame_active_sclk;
  logic       frame_complete_sclk;
  logic       frame_rearmed_sclk;
  logic       rx_event_tgl_sclk;

  logic       rx_event_sync1_clk;
  logic       rx_event_sync2_clk;
  logic       rx_event_seen_clk;
  logic       rx_valid_pending_clk;

  logic [7:0] tx_preselect_byte;
  logic       pending_frame_window;
  logic [2:0] active_miso_index;

  assign tx_preselect_byte   = tx_hold_valid_clk ? tx_hold_data_clk : DEFAULT_TX_BYTE;
  assign pending_frame_window = (!cs_n) && frame_rearmed_sclk && !frame_active_sclk && !frame_complete_sclk;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_hold_data_clk   <= 8'h00;
      tx_hold_valid_clk  <= 1'b0;
    end
    else begin
      tx_hold_data_clk   <= tx_data;
      tx_hold_valid_clk  <= tx_valid;
    end
  end

  always_ff @(posedge sclk or posedge cs_n or negedge rst_n) begin : sclk_protocol
    logic [7:0] next_rx_shift;

    if (!rst_n) begin
      tx_frame_byte_sclk  <= DEFAULT_TX_BYTE;
      rx_shift_reg_sclk   <= 8'h00;
      rx_hold_sclk        <= 8'h00;
      bit_count_sclk      <= 4'd0;
      frame_active_sclk   <= 1'b0;
      frame_complete_sclk <= 1'b0;
      frame_rearmed_sclk  <= 1'b1;
      rx_event_tgl_sclk   <= 1'b0;
    end
    else if (cs_n) begin
      rx_shift_reg_sclk   <= 8'h00;
      bit_count_sclk      <= 4'd0;
      frame_active_sclk   <= 1'b0;
      frame_complete_sclk <= 1'b0;
      frame_rearmed_sclk  <= 1'b1;
    end
    else begin
      next_rx_shift = {rx_shift_reg_sclk[6:0], mosi};

      if (frame_complete_sclk) begin
        // Ignore extra clocks until cs_n returns high.
      end
      else if (!frame_active_sclk) begin
        if (frame_rearmed_sclk) begin
          // Legal/pending frame becomes active on the first counted rising edge.
          tx_frame_byte_sclk  <= tx_preselect_byte;
          rx_shift_reg_sclk   <= next_rx_shift;
          bit_count_sclk      <= 4'd1;
          frame_active_sclk   <= 1'b1;
          frame_rearmed_sclk  <= 1'b0;
        end
        // Else: ignored attempt while not re-armed.
      end
      else begin
        rx_shift_reg_sclk <= next_rx_shift;

        if (bit_count_sclk == 4'd7) begin
          // 8th accepted rising edge completes the frame.
          bit_count_sclk      <= 4'd8;
          frame_active_sclk   <= 1'b0;
          frame_complete_sclk <= 1'b1;
          rx_hold_sclk        <= next_rx_shift;
          rx_event_tgl_sclk   <= ~rx_event_tgl_sclk;
        end
        else begin
          bit_count_sclk <= bit_count_sclk + 4'd1;
        end
      end
    end
  end

  always_comb begin
    miso_oe = 1'b0;
    miso_o  = 1'b0;

    if (!rst_n) begin
      miso_oe = 1'b0;
      miso_o  = 1'b0;
    end
    else if (pending_frame_window) begin
      miso_oe = 1'b1;
      miso_o  = tx_preselect_byte[7];
    end
    else if ((!cs_n) && frame_active_sclk && !frame_complete_sclk) begin
      miso_oe = 1'b1;

      // While sclk is high, hold the bit that was just sampled by the master.
      // While sclk is low, present the next bit that will be sampled on the
      // upcoming rising edge.
      if (sclk) begin
        active_miso_index = 3'(8 - bit_count_sclk);
      end
      else begin
        active_miso_index = 3'(7 - bit_count_sclk);
      end

      miso_o = tx_frame_byte_sclk[active_miso_index];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_event_sync1_clk   <= 1'b0;
      rx_event_sync2_clk   <= 1'b0;
      rx_event_seen_clk    <= 1'b0;
      rx_valid_pending_clk <= 1'b0;
      rx_data              <= 8'h00;
      rx_valid             <= 1'b0;
    end
    else begin
      rx_valid <= rx_valid_pending_clk;
      rx_valid_pending_clk <= 1'b0;

      rx_event_sync1_clk <= rx_event_tgl_sclk;
      rx_event_sync2_clk <= rx_event_sync1_clk;

      if (rx_event_sync2_clk != rx_event_seen_clk) begin
        rx_event_seen_clk    <= rx_event_sync2_clk;
        rx_data              <= rx_hold_sclk;
        rx_valid_pending_clk <= 1'b1;
      end
    end
  end

endmodule
