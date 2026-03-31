module input_register #(
    parameter DATA_WIDTH  = 16,
    parameter IN_CHANNELS = 16
)(
    input  wire                             clk,
    input  wire                             rst_n,
    input  wire                             i_valid,
    input  wire [IN_CHANNELS*DATA_WIDTH-1:0] i_data_feature,
    output reg  [IN_CHANNELS*DATA_WIDTH-1:0] feature_reg,
    output reg                              o_valid
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        feature_reg <= 1'b0;
        o_valid     <= 1'b0;
    end else begin
        o_valid <= i_valid;
        if (i_valid)
            feature_reg <= i_data_feature;
    end
end

endmodule
