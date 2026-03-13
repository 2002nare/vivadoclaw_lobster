module basys3_spi_slave_top #(
  parameter logic [7:0] DEFAULT_TX_BYTE = 8'h00
) (
  input  logic        clk,
  input  logic [15:0] sw,
  output logic [15:0] led,
  input  logic        sclk,
  input  logic        cs_n,
  input  logic        mosi,
  inout  wire         miso
);

  logic [7:0] tx_data;
  logic       tx_valid;
  logic [7:0] rx_data;
  logic       rx_valid;
  logic       miso_o;
  logic       miso_oe;
  logic [7:0] rx_latched;

  // Basys3 board mapping
  // - sw[15] : rst_n (1 = run, 0 = reset)
  // - sw[8]  : tx_valid
  // - sw[7:0]: tx_data byte to be shifted out on each selected frame
  // - led[7:0]  : last received SPI byte
  // - led[8]    : current tx_valid level
  // - led[9]    : current miso_oe level
  // - led[15:10]: unused, held low

  assign tx_data  = sw[7:0];
  assign tx_valid = sw[8];

  // Top-level tri-state only: allowed in the board wrapper.
  assign miso = miso_oe ? miso_o : 1'bz;

  spi_slave_core #(
    .DEFAULT_TX_BYTE(DEFAULT_TX_BYTE)
  ) u_core (
    .clk     (clk),
    .rst_n   (sw[15]),
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

  always_ff @(posedge clk or negedge sw[15]) begin
    if (!sw[15]) begin
      rx_latched <= 8'h00;
    end
    else if (rx_valid) begin
      rx_latched <= rx_data;
    end
  end

  always_comb begin
    led        = '0;
    led[7:0]   = rx_latched;
    led[8]     = tx_valid;
    led[9]     = miso_oe;
  end

endmodule
