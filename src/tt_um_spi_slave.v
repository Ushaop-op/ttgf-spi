`default_nettype none

module tt_um_spi_slave (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (1 = out, 0 = in)
    input  wire       ena,      // design enable
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Map inputs from Bidirectional Pins
    wire sclk = uio_in[0];
    wire mosi = uio_in[1];
    wire cs_n = uio_in[2];
    wire miso;

    // Output driver configuration for Bidirectional control line maps
    assign uio_out[0] = 1'b0;
    assign uio_out[1] = 1'b0;
    assign uio_out[2] = 1'b0;
    assign uio_out[3] = miso; // MISO driven out
    assign uio_out[7:4] = 4'b0000;

    // Define direction rules: pin 3 is output, others are input
    assign uio_oe = 8'b00001000; 

    // Internal routing nets
    wire [2:0] reg_addr;
    wire [7:0] reg_wdata;
    wire       reg_we;
    wire [7:0] reg_rdata;

    // Unused input wires handled cleanly
    wire [7:0] unused_inputs = ui_in;

    spi_slave spi_core (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_we(reg_we),
        .reg_rdata(reg_rdata)
    );

    reg_file storage_core (
        .clk(clk),
        .rst_n(rst_n),
        .addr(reg_addr),
        .wdata(reg_wdata),
        .we(reg_we),
        .rdata(reg_rdata),
        .reg0_out(uo_out) // Outputs Register 0 states to local dedicated LEDs
    );

endmodule
