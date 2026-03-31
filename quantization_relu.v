module quantization_relu #(
    parameter IN_WIDTH  = 36,
    parameter OUT_WIDTH = 16,
    parameter CHANNELS  = 16,
    parameter SHIFT_BITS = 10
)(
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire                           i_valid,
    input  wire                           i_relu_en,
    input  wire [CHANNELS*IN_WIDTH-1:0]   i_data,
    output reg  [CHANNELS*OUT_WIDTH-1:0]  o_data,
    output reg                            o_valid
);

localparam signed [OUT_WIDTH-1:0] MAX_FIXED = 16'sh7FFF;
localparam signed [OUT_WIDTH-1:0] MIN_FIXED = 16'sh8000;
localparam signed [OUT_WIDTH-1:0] ZERO_FIXED = 16'sh0000;

function signed [OUT_WIDTH-1:0] quantize_lane;
    input signed [IN_WIDTH-1:0] in_val;
    input                       relu_en;
    reg   signed [IN_WIDTH-1:0] rounded_val;
    reg   signed [IN_WIDTH-1:0] shifted_val;
begin
    if (relu_en && (in_val < 0)) begin
        quantize_lane = ZERO_FIXED;
    end else begin
        if (in_val >= 0)
            rounded_val = in_val + ({{(IN_WIDTH-1){1'b0}}, 1'b1} <<< (SHIFT_BITS-1));
        else
            rounded_val = in_val - ({{(IN_WIDTH-1){1'b0}}, 1'b1} <<< (SHIFT_BITS-1));

        shifted_val = rounded_val >>> SHIFT_BITS;

        if (shifted_val > $signed(MAX_FIXED))
            quantize_lane = MAX_FIXED;
        else if (shifted_val < $signed(MIN_FIXED))
            quantize_lane = MIN_FIXED;
        else
            quantize_lane = shifted_val[OUT_WIDTH-1:0];
    end
end
endfunction

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_data  <= 1'b0;
        o_valid <= 1'b0;
    end else begin
        o_valid <= i_valid;
        if (i_valid) begin
            for (i = 0; i < CHANNELS; i = i + 1) begin
                o_data[i*OUT_WIDTH +: OUT_WIDTH] <=
                    quantize_lane($signed(i_data[i*IN_WIDTH +: IN_WIDTH]), i_relu_en);
            end
        end
    end
end

endmodule
