module bias_buffer #(
    parameter DATA_WIDTH = 16,
    parameter CHANNELS   = 16
)(
    input  wire                              clk,
    input  wire                              rst_n,

    input  wire                              i_valid,
    input  wire [CHANNELS*DATA_WIDTH-1:0]    i_data,

    output reg  [CHANNELS*DATA_WIDTH-1:0]    o_data
);

always @(posedge clk) begin
    if (!rst_n) begin
        o_data <= 0;
    end else if (i_valid) begin
        o_data <= i_data;
    end
end

endmodule