/*
 * reg_file.v — 8 × 8-bit synchronous register file
 *
 * Written by spi_slave on reg_we pulse.
 * Read data is combinatorial — used by spi_slave to preload MISO shift reg.
 * reg0_out provides a live parallel view of register 0 on uo_out.
 */

`default_nettype none

module reg_file (
    input  wire       clk,
    input  wire       rst_n,

    input  wire [2:0] addr,    // register select (0–7)
    input  wire [7:0] wdata,   // data to write
    input  wire       we,      // write enable (1-cycle pulse)

    output wire [7:0] rdata,   // combinatorial read
    output wire [7:0] reg0_out // live output of reg[0]
);

    reg [7:0] mem [0:7];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1)
                mem[i] <= 8'h00;
        end else if (we) begin
            mem[addr] <= wdata;
        end
    end

    assign rdata    = mem[addr];
    assign reg0_out = mem[0];

endmodule
