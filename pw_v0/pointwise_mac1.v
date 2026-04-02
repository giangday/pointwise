module pointwise_mac1 #(
    parameter DATA_WIDTH   = 16,
    parameter IN_CHANNELS  = 16,
    parameter OUT_CHANNELS = 16,
    parameter PSUM_WIDTH   = (DATA_WIDTH * 2) + $clog2(IN_CHANNELS)
)(
    input  wire                                  clk,
    input  wire                                  rst_n,
    input  wire                                  i_valid,
    input  wire [IN_CHANNELS*DATA_WIDTH-1:0]     i_data_feature,
    input  wire [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight,
    output reg  [OUT_CHANNELS*PSUM_WIDTH-1:0]    o_data_psum,
    output reg                                   o_valid
);

localparam MULT_WIDTH = DATA_WIDTH * 2;
localparam L1 = IN_CHANNELS / 2;
localparam L2 = IN_CHANNELS / 4;
localparam L3 = IN_CHANNELS / 8;
localparam NUM_LEVELS = $clog2(IN_CHANNELS) + 1;
localparam PIPE_STAGES = NUM_LEVELS - 1;

integer oc, ic, p;
reg [PIPE_STAGES:0] valid_pipe;

(* use_dsp = "yes" *) reg signed [MULT_WIDTH-1:0] mult_reg [0:OUT_CHANNELS-1][0:IN_CHANNELS-1];
reg signed [PSUM_WIDTH-1:0] tree_lvl1 [0:OUT_CHANNELS-1][0:L1-1];
reg signed [PSUM_WIDTH-1:0] tree_lvl2 [0:OUT_CHANNELS-1][0:L2-1];
reg signed [PSUM_WIDTH-1:0] tree_lvl3 [0:OUT_CHANNELS-1][0:L3-1];
reg signed [PSUM_WIDTH-1:0] tree_final [0:OUT_CHANNELS-1];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_pipe <= '0;
    end else begin 
        valid_pipe <= {valid_pipe[PIPE_STAGES-1:0], i_valid};
    end
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                mult_reg[oc][ic] <= 1'b0;
            end
        end
    end else if (i_valid) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                mult_reg[oc][ic] <=
                    $signed(i_data_feature[ic*DATA_WIDTH +: DATA_WIDTH]) *
                    $signed(i_data_weight[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH]);
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            for (p = 0; p < L1; p = p + 1) begin
                tree_lvl1[oc][p] <= 1'b0;
            end
        end
    end else if (valid_pipe[0]) begin
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
                tree_lvl2[oc][p] <= 1'b0;
            end
        end
    end else if (valid_pipe[1]) begin
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
                tree_lvl3[oc][p] <= 1'b0;
            end
        end
    end else if (valid_pipe[2]) begin
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
            tree_final[oc] <= 1'b0;
        end
    end else if (valid_pipe[3]) begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            tree_final[oc] <= $signed(tree_lvl3[oc][0]) + $signed(tree_lvl3[oc][1]);
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_data_psum <= 1'b0;
        o_valid     <= 1'b0;
    end else begin
        o_valid <= valid_pipe[4];
        if (valid_pipe[4]) begin
            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                o_data_psum[oc*PSUM_WIDTH +: PSUM_WIDTH] <= tree_final[oc];
            end
        end
    end
end

endmodule
