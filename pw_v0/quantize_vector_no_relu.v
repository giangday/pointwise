module quantize_vector_no_relu #(
    parameter IN_WIDTH   = 36,
    parameter OUT_WIDTH  = 16,
    parameter CHANNELS   = 16,
    parameter SHIFT_BITS = 10
)(
    input  wire [CHANNELS*IN_WIDTH-1:0]  i_data,
    output wire [CHANNELS*OUT_WIDTH-1:0] o_data
);

    function signed [OUT_WIDTH-1:0] quantize_lane_no_relu;
        input signed [IN_WIDTH-1:0] in_val;
        reg   signed [IN_WIDTH-1:0] rounded_val;
        reg   signed [IN_WIDTH-1:0] shifted_val;
    begin
        if (in_val >= 0)
            rounded_val = in_val + ({{(IN_WIDTH-1){1'b0}}, 1'b1} <<< (SHIFT_BITS-1));
        else
            rounded_val = in_val - ({{(IN_WIDTH-1){1'b0}}, 1'b1} <<< (SHIFT_BITS-1));

        shifted_val = rounded_val >>> SHIFT_BITS;

        if (shifted_val > $signed(16'sh7FFF))
            quantize_lane_no_relu = 16'sh7FFF;
        else if (shifted_val < $signed(16'sh8000))
            quantize_lane_no_relu = 16'sh8000;
        else
            quantize_lane_no_relu = shifted_val[OUT_WIDTH-1:0];
    end
    endfunction

    genvar ch;
    generate
        for (ch = 0; ch < CHANNELS; ch = ch + 1) begin : GEN_QUANT
            assign o_data[ch*OUT_WIDTH +: OUT_WIDTH] =
                quantize_lane_no_relu($signed(i_data[ch*IN_WIDTH +: IN_WIDTH]));
        end
    endgenerate

endmodule
