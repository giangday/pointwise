module relu_vector #(
    parameter DATA_WIDTH = 16,
    parameter CHANNELS   = 16
)(
    input  wire [CHANNELS*DATA_WIDTH-1:0] i_data,
    input  wire                           i_enable,
    output wire [CHANNELS*DATA_WIDTH-1:0] o_data
);

genvar ch;
generate
    for (ch = 0; ch < CHANNELS; ch = ch + 1) begin : GEN_RELU
        wire signed [DATA_WIDTH-1:0] lane_in;
        assign lane_in = i_data[ch*DATA_WIDTH +: DATA_WIDTH];
        assign o_data[ch*DATA_WIDTH +: DATA_WIDTH] =
            (i_enable && lane_in[DATA_WIDTH-1]) ? {DATA_WIDTH{1'b0}} : lane_in;
    end
endgenerate

endmodule
