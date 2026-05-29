`default_nettype none

module reg_file (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [2:0] addr,
    input  wire [7:0] wdata,
    input  wire       we,
    output reg  [7:0] rdata,
    output wire [7:0] reg0_out
);

    reg [7:0] storage [0:7];
    integer i;

    assign reg0_out = storage[0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                storage[i] <= 8'h00;
            end
        end else if (we) begin
            storage[addr] <= wdata;
        end
    end

    always @(*) begin
        rdata = storage[addr];
    end
endmodule
