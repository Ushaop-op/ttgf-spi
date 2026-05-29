/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 *
 * tt_um_spi_slave.v — Top-level wrapper (Tiny Tapeout standard ports)
 *
 * SPI bus is on the bidirectional pins (uio):
 *   uio_in[0]  = SCLK
 *   uio_in[1]  = MOSI
 *   uio_in[2]  = CS (active low)
 *   uio_out[3] = MISO
 *   uio_out[4] = BUSY (high while transaction in progress)
 *
 * uo_out[7:0] = live value of register 0 (visible on output pins)
 */

`default_nettype none

module tt_um_spi_slave (
    input  wire [7:0] ui_in,    // unused
    output wire [7:0] uo_out,   // reg[0] live output
    input  wire [7:0] uio_in,   // SPI SCLK/MOSI/CS
    output wire [7:0] uio_out,  // SPI MISO + BUSY
    output wire [7:0] uio_oe,   // direction: 1=output
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // ── Internal wires ────────────────────────────────────────
    wire [2:0] reg_addr;
    wire [7:0] reg_wdata;
    wire       reg_we;
    wire [7:0] reg_rdata;
    wire [7:0] reg0_out;
    wire       miso;
    wire       busy;

    // ── SPI slave ─────────────────────────────────────────────
    spi_slave u_spi (
        .clk       (clk),
        .rst_n     (rst_n),
        .sclk      (uio_in[0]),
        .mosi      (uio_in[1]),
        .cs_n      (uio_in[2]),
        .miso      (miso),
        .busy      (busy),
        .reg_addr  (reg_addr),
        .reg_wdata (reg_wdata),
        .reg_we    (reg_we),
        .reg_rdata (reg_rdata)
    );

    // ── Register file ─────────────────────────────────────────
    reg_file u_regs (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr     (reg_addr),
        .wdata    (reg_wdata),
        .we       (reg_we),
        .rdata    (reg_rdata),
        .reg0_out (reg0_out)
    );

    // ── Outputs ───────────────────────────────────────────────
    assign uo_out     = reg0_out;     // reg[0] visible on all 8 output pins

    assign uio_out    = 8'b0001_1000; // bit4=BUSY, bit3=MISO (others 0)
    assign uio_oe     = 8'b0001_1000; // bit4 and bit3 are outputs
    assign uio_out[3] = miso;
    assign uio_out[4] = busy;

endmodule
