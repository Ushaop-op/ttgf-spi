/*
 * spi_slave.v — SPI Mode 0 (CPOL=0, CPHA=0) slave
 *
 * Transaction format — 16 SCLK clocks total:
 *
 *   First 8 clocks  → address byte (MSB first)
 *     bit[7]   = R/W flag  (0 = write, 1 = read)
 *     bit[2:0] = register address 0–7
 *
 *   Second 8 clocks → data byte (MSB first)
 *     WRITE : master sends data on MOSI → stored in reg_file[addr]
 *     READ  : slave shifts reg_file[addr] out on MISO
 *
 * FSM: IDLE → ADDR → DATA → DONE → IDLE
 */

`default_nettype none

module spi_slave (
    input  wire       clk,
    input  wire       rst_n,

    // SPI bus
    input  wire       sclk,
    input  wire       mosi,
    output reg        miso,
    input  wire       cs_n,       // chip select, active low
    output wire       busy,       // high while transaction active

    // Register file interface
    output reg  [2:0] reg_addr,
    output reg  [7:0] reg_wdata,
    output reg        reg_we,
    input  wire [7:0] reg_rdata
);

    // ── State encoding ────────────────────────────────────────
    localparam IDLE = 2'd0,
               ADDR = 2'd1,
               DATA = 2'd2,
               DONE = 2'd3;

    reg [1:0] state;

    assign busy = (state != IDLE);

    // ── Double-flop synchronisers (clock-domain crossing) ─────
    reg sclk_s0, sclk_s1, sclk_s2;
    reg cs_s0,   cs_s1,   cs_s2;

    wire sclk_rise = ( sclk_s1 & ~sclk_s2); // rising  edge of SCLK
    wire sclk_fall = (~sclk_s1 &  sclk_s2); // falling edge of SCLK
    wire cs_fall   = (~cs_s1   &  cs_s2);   // CS going low  = start
    wire cs_rise   = ( cs_s1   & ~cs_s2);   // CS going high = end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {sclk_s0, sclk_s1, sclk_s2} <= 3'b000;
            {cs_s0,   cs_s1,   cs_s2}   <= 3'b111;
        end else begin
            sclk_s0 <= sclk; sclk_s1 <= sclk_s0; sclk_s2 <= sclk_s1;
            cs_s0   <= cs_n; cs_s1   <= cs_s0;   cs_s2   <= cs_s1;
        end
    end

    // ── Shift registers and bit counter ───────────────────────
    reg [7:0] shift_rx;   // shift in from MOSI
    reg [7:0] shift_tx;   // shift out to  MISO
    reg [2:0] bit_cnt;    // counts 7 down to 0
    reg       rw_flag;    // latched from address byte

    // ── Main FSM ──────────────────────────────────────────────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            bit_cnt   <= 3'd7;
            shift_rx  <= 8'h00;
            shift_tx  <= 8'h00;
            rw_flag   <= 1'b0;
            reg_addr  <= 3'd0;
            reg_wdata <= 8'h00;
            reg_we    <= 1'b0;
            miso      <= 1'b0;
        end else begin
            reg_we <= 1'b0; // default: no write pulse

            case (state)

                // ─── Wait for CS to assert ───────────────────
                IDLE: begin
                    bit_cnt  <= 3'd7;
                    shift_rx <= 8'h00;
                    miso     <= 1'b0;
                    if (cs_fall)
                        state <= ADDR;
                end

                // ─── Receive 8-bit address byte ──────────────
                ADDR: begin
                    if (cs_rise) begin
                        state <= IDLE; // aborted
                    end else if (sclk_rise) begin
                        // Sample MOSI on rising SCLK
                        shift_rx <= {shift_rx[6:0], mosi};

                        if (bit_cnt == 3'd0) begin
                            // Full address byte received
                            rw_flag  <= shift_rx[7];       // MSB = R/W
                            reg_addr <= shift_rx[2:0];     // addr bits
                            // Preload TX shift reg for read
                            shift_tx <= reg_rdata;
                            bit_cnt  <= 3'd7;
                            state    <= DATA;
                        end else begin
                            bit_cnt <= bit_cnt - 3'd1;
                        end
                    end
                end

                // ─── Transfer 8-bit data byte ─────────────────
                DATA: begin
                    if (cs_rise) begin
                        state <= IDLE;
                    end else begin
                        // Drive MISO on falling SCLK (setup time before next rise)
                        if (sclk_fall) begin
                            miso     <= shift_tx[7];
                            shift_tx <= {shift_tx[6:0], 1'b0};
                        end

                        // Sample MOSI on rising SCLK
                        if (sclk_rise) begin
                            shift_rx <= {shift_rx[6:0], mosi};

                            if (bit_cnt == 3'd0) begin
                                // Full data byte received
                                if (!rw_flag) begin
                                    // WRITE: store into register file
                                    reg_wdata <= {shift_rx[6:0], mosi};
                                    reg_we    <= 1'b1;
                                end
                                state <= DONE;
                            end else begin
                                bit_cnt <= bit_cnt - 3'd1;
                            end
                        end
                    end
                end

                // ─── Wait for CS to deassert ──────────────────
                DONE: begin
                    if (cs_rise)
                        state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
