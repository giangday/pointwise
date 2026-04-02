module pw_mac #(
    parameter DATA_WIDTH   = 16,
    parameter IN_CHANNELS  = 16,
    parameter OUT_CHANNELS = 16,
    parameter PSUM_WIDTH   = (DATA_WIDTH * 2) + $clog2(IN_CHANNELS),
    parameter NUM_LEVELS   = $clog2(IN_CHANNELS) + 1,
    parameter SHIFT_BITS   = 10
)(
    input  wire                                      clk,
    input  wire                                      rst_n,
    input  wire                                      i_valid,
    input  wire [NUM_LEVELS-1:0]                     i_valid_pipe,
    input  wire [IN_CHANNELS*DATA_WIDTH-1:0]         i_data_feature,
    input  wire [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight,
    input  wire [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_bias,
    output reg  [OUT_CHANNELS*DATA_WIDTH-1:0]        o_data
);

localparam MULT_WIDTH = DATA_WIDTH * 2;
localparam L1 = IN_CHANNELS / 2;
localparam L2 = IN_CHANNELS / 4;
localparam L3 = IN_CHANNELS / 8;

integer oc, ic, p;

function signed [DATA_WIDTH-1:0] quantize_lane;
    input signed [PSUM_WIDTH-1:0] in_val;
    reg   signed [PSUM_WIDTH-1:0] rounded_val;
    reg   signed [PSUM_WIDTH-1:0] shifted_val;
begin
    if (in_val >= 0)
        rounded_val = in_val + ({{(PSUM_WIDTH-1){1'b0}}, 1'b1} <<< (SHIFT_BITS-1));
    else
        rounded_val = in_val - ({{(PSUM_WIDTH-1){1'b0}}, 1'b1} <<< (SHIFT_BITS-1));

    shifted_val = rounded_val >>> SHIFT_BITS;

    if (shifted_val > $signed(16'sh7FFF))
        quantize_lane = 16'sh7FFF;
    else if (shifted_val < $signed(16'sh8000))
        quantize_lane = 16'sh8000;
    else
        quantize_lane = shifted_val[DATA_WIDTH-1:0];
end
endfunction

(* use_dsp = "yes" *)
reg signed [MULT_WIDTH-1:0] mult_reg [0:OUT_CHANNELS-1][0:IN_CHANNELS-1];

reg signed [PSUM_WIDTH-1:0] tree_lvl1 [0:OUT_CHANNELS-1][0:L1-1];
reg signed [PSUM_WIDTH-1:0] tree_lvl2 [0:OUT_CHANNELS-1][0:L2-1];
reg signed [PSUM_WIDTH-1:0] tree_lvl3 [0:OUT_CHANNELS-1][0:L3-1];
reg signed [PSUM_WIDTH-1:0] tree_final [0:OUT_CHANNELS-1];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                mult_reg[oc][ic] <= 0;
            end
        end
    end else if (i_valid) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                mult_reg[oc][ic] <=
                    $signed(i_data_feature[ic*DATA_WIDTH +: DATA_WIDTH])
                    * $signed(i_data_weight[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH]) 
                    + $signed(i_data_bias[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH]);
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            for (p = 0; p < L1; p = p + 1) begin
                tree_lvl1[oc][p] <= 0;
            end
        end
    end else if (i_valid_pipe[0]) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            for (p = 0; p < L1; p = p + 1) begin
                tree_lvl1[oc][p] <=
                    $signed(mult_reg[oc][2*p]) + $signed(mult_reg[oc][2*p+1]);
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            for (p = 0; p < L2; p = p + 1) begin
                tree_lvl2[oc][p] <= 0;
            end
        end
    end else if (i_valid_pipe[1]) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            for (p = 0; p < L2; p = p + 1) begin
                tree_lvl2[oc][p] <=
                    $signed(tree_lvl1[oc][2*p]) + $signed(tree_lvl1[oc][2*p+1]);
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            for (p = 0; p < L3; p = p + 1) begin
                tree_lvl3[oc][p] <= 0;
            end
        end
    end else if (i_valid_pipe[2]) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            for (p = 0; p < L3; p = p + 1) begin
                tree_lvl3[oc][p] <=
                    $signed(tree_lvl2[oc][2*p]) + $signed(tree_lvl2[oc][2*p+1]);
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            tree_final[oc] <= 0;
        end
    end else if (i_valid_pipe[3]) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            tree_final[oc] <= $signed(tree_lvl3[oc][0]) + $signed(tree_lvl3[oc][1]);
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_data <= 0;
    end else if (i_valid_pipe[4]) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            o_data[oc*DATA_WIDTH +: DATA_WIDTH] <= quantize_lane(tree_final[oc]);
        end
    end
end

endmodule
