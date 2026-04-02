module psum_adder_pw #(
    parameter DATA_WIDTH   = 16,
    parameter CHANNELS     = 16
)(
    input  wire                               clk,
    input  wire                               rst_n,

    input  wire                               i_valid,
    input  wire                               i_is_first,

    input  wire [CHANNELS*DATA_WIDTH-1:0]     i_data,
    input  wire [CHANNELS*DATA_WIDTH-1:0]     i_fifo_data,
    input  wire                               i_fifo_empty,

    output reg  [CHANNELS*DATA_WIDTH-1:0]     o_data
);

integer ch;

wire use_fifo = i_is_first || i_fifo_empty;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_data <= 0;
    end else if (i_valid) begin
        for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
            if (use_fifo) begin
                o_data[ch*DATA_WIDTH +: DATA_WIDTH] <=
                    $signed(i_data[ch*DATA_WIDTH +: DATA_WIDTH]);
            end else begin
                o_data[ch*DATA_WIDTH +: DATA_WIDTH] <=
                    $signed(i_data[ch*DATA_WIDTH +: DATA_WIDTH]) +
                    $signed(i_fifo_data[ch*DATA_WIDTH +: DATA_WIDTH]);
            end
        end
    end
end

endmodule