module controller_pointwise #(
    parameter PIPELINE_DEPTH = 10
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      i_valid,
    input  wire                      i_mode,
    input  wire                      i_is_last,
    input  wire                      i_is_first,
    output reg  [PIPELINE_DEPTH-1:0] valid_pipe,
    output reg  [PIPELINE_DEPTH-1:0] mode_pipe,
    output reg  [PIPELINE_DEPTH-1:0] is_last_pipe,
    output reg  [PIPELINE_DEPTH-1:0] is_first_pipe,
    output wire                      pw_en,
    output wire                      fifo_rd_en,
    output wire                      stage7_mode,
    output wire                      stage8_pw0_en,
    output wire                      stage8_pw1_en,
    output wire                      stage8_pw0_is_first,
    output wire                      stage8_pw1_is_first,
    output wire                      fifo0_wr_en,
    output wire                      fifo1_wr_en,
    output wire                      quant0_valid,
    output wire                      quant1_valid,
    output wire                      relu_en,
    output wire                      o_valid
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_pipe    <= {PIPELINE_DEPTH{1'b0}};
        mode_pipe     <= {PIPELINE_DEPTH{1'b0}};
        is_last_pipe  <= {PIPELINE_DEPTH{1'b0}};
        is_first_pipe <= {PIPELINE_DEPTH{1'b0}};
    end else begin
        valid_pipe    <= {valid_pipe[PIPELINE_DEPTH-2:0], i_valid};
        mode_pipe     <= {mode_pipe[PIPELINE_DEPTH-2:0], i_mode};
        is_last_pipe  <= {is_last_pipe[PIPELINE_DEPTH-2:0], i_is_last};
        is_first_pipe <= {is_first_pipe[PIPELINE_DEPTH-2:0], i_is_first};
    end
end

assign fifo_rd_en          = i_valid & ~i_is_first;
assign pw_en               = valid_pipe[0];
assign stage7_mode         = mode_pipe[6];
assign stage8_pw0_en       = valid_pipe[7];
assign stage8_pw1_en       = valid_pipe[7] & ~mode_pipe[7];
assign stage8_pw0_is_first = is_first_pipe[7];
assign stage8_pw1_is_first = is_first_pipe[7] & ~mode_pipe[7];
assign fifo0_wr_en         = valid_pipe[8] & ~is_last_pipe[8];
assign fifo1_wr_en         = valid_pipe[8] & ~mode_pipe[8] & ~is_last_pipe[8];
assign quant0_valid        = valid_pipe[8] & is_last_pipe[8];
assign quant1_valid        = valid_pipe[8] & ~mode_pipe[8] & is_last_pipe[8];
assign relu_en             = is_last_pipe[8];
assign o_valid             = valid_pipe[9];

endmodule
