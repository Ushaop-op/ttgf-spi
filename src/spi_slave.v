`default_nettype none

module spi_slave (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       sclk,
    input  wire       mosi,
    output reg        miso,
    input  wire       cs_n,
    output reg  [2:0] reg_addr,
    output reg  [7:0] reg_wdata,
    output reg        reg_we,
    input  wire [7:0] reg_rdata
);

    // Synchronizers for SPI inputs to prevent metastability
    reg [2:0] sclk_sync;
    reg [2:0] cs_n_sync;
    reg [1:0] mosi_sync;

    always @(posedby clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync <= 3'b000;
            cs_n_sync <= 3'b111;
            mosi_sync <= 2'b00;
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            cs_n_sync <= {cs_n_sync[1:0], cs_n};
            mosi_sync <= {mosi_sync[0], mosi};
        end
    end

    wire sclk_rising  = (sclk_sync[1:0] == 2'b01);
    wire sclk_falling = (sclk_sync[1:0] == 2'b10);
    wire cs_active    = ~cs_n_sync[1];

    // FSM States
    localparam STATE_IDLE = 2'b00;
    localparam STATE_ADDR = 2'b01;
    localparam STATE_DATA = 2'b10;

    reg [1:0] state;
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg;
    reg       is_read;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= STATE_IDLE;
            bit_cnt   <= 3'd0;
            shift_reg <= 8'h00;
            reg_addr  <= 3'b000;
            reg_wdata <= 8'h00;
            reg_we    <= 1'b0;
            is_read   <= 1'b0;
            miso      <= 1'b0;
        end else if (!cs_active) begin
            state     <= STATE_IDLE;
            bit_cnt   <= 3'd0;
            reg_we    <= 1'b0;
            miso      <= 1'b0;
        end else begin
            reg_we <= 1'b0; // Default pulse line

            case (state)
                STATE_IDLE: begin
                    bit_cnt   <= 3'd0;
                    state     <= STATE_ADDR;
                    shift_reg <= 8'h00;
                end

                STATE_ADDR: begin
                    if (sclk_rising) begin
                        shift_reg <= {shift_reg[6:0], mosi_sync[1]};
                        bit_cnt   <= bit_cnt + 1'b1;
                        if (bit_cnt == 3'd7) begin
                            state    <= STATE_DATA;
                            bit_cnt  <= 3'd0;
                            is_read  <= shift_reg[6]; // Bit 7 acts as Read/Write flag
                            reg_addr <= {shift_reg[5:0], mosi_sync[1]}[2:0];
                        end
                    end
                end

                STATE_DATA: begin
                    if (is_read) begin
                        // Read Transaction: Put data onto MISO on falling edges
                        if (bit_cnt == 3'd0) begin
                            shift_reg <= reg_rdata;
                            miso      <= reg_rdata[7];
                            bit_cnt   <= 3'd1;
                        end else if (sclk_falling) begin
                            miso    <= shift_reg[7 - bit_cnt];
                            bit_cnt <= bit_cnt + 1'b1;
                            if (bit_cnt == 3'd7) begin
                                state <= STATE_IDLE;
                            end
                        end
                    end else begin
                        // Write Transaction: Sample MOSI on rising edges
                        if (sclk_rising) begin
                            shift_reg <= {shift_reg[6:0], mosi_sync[1]};
                            bit_cnt   <= bit_cnt + 1'b1;
                            if (bit_cnt == 3'd7) begin
                                reg_wdata <= {shift_reg[6:0], mosi_sync[1]};
                                reg_we    <= 1'b1;
                                state     <= STATE_IDLE;
                            end
                        end
                    end
                end
            endcase
        end
    end
endmodule
