module pointwise_top #(
    parameter DATA_WIDTH   = 16,
    parameter IN_CHANNELS  = 16,
    parameter OUT_CHANNELS = 16,
    parameter PSUM_WIDTH   = (DATA_WIDTH * 2) + $clog2(IN_CHANNELS),
    parameter OUTPUT_WIDTH = 16,
    parameter FIFO_MAX_PTR = 64*64,
    parameter SHIFT_BITS   = 10
)(
    input  wire                                      clk,
    input  wire                                      rst_n,
    input  wire                                      i_valid,
    input  wire                                      i_mode,
    input  wire                                      i_is_last,
    input  wire                                      i_is_first,
    input  wire [1:0]                                i_fifo_mode,
    input  wire [IN_CHANNELS*DATA_WIDTH-1:0]         i_data_feature,
    input  wire [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight_pw0,
    input  wire [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight_pw1,
    output wire [OUT_CHANNELS*OUTPUT_WIDTH-1:0]      o_data,
    output wire                                      o_valid,
    output wire [OUT_CHANNELS*OUTPUT_WIDTH-1:0]      o_data_pw1,
    output wire                                      o_valid_pw1
);

wire [9:0] valid_pipe;
wire [9:0] mode_pipe;
wire [9:0] is_last_pipe;
wire [9:0] is_first_pipe;
wire       pw_en;
wire       fifo_rd_en;
wire       stage7_mode;
wire       stage8_pw0_en;
wire       stage8_pw1_en;
wire       stage8_pw0_is_first;
wire       stage8_pw1_is_first;
wire       fifo0_wr_en;
wire       fifo1_wr_en;
wire       quant0_valid_unused;
wire       quant1_valid_unused;
wire       relu_en_unused;
wire       controller_o_valid_unused;

wire [IN_CHANNELS*DATA_WIDTH-1:0] feature_reg;
wire [OUT_CHANNELS*PSUM_WIDTH-1:0] pw0_out_raw;
wire [OUT_CHANNELS*PSUM_WIDTH-1:0] pw1_out_raw;
(* keep = "true" *) wire [OUT_CHANNELS*OUTPUT_WIDTH-1:0] pw0_out;
(* keep = "true" *) wire [OUT_CHANNELS*OUTPUT_WIDTH-1:0] pw1_out;
wire [OUT_CHANNELS*OUTPUT_WIDTH-1:0] stage7_out;
wire [OUT_CHANNELS*OUTPUT_WIDTH-1:0] fifo0_out;
wire [OUT_CHANNELS*OUTPUT_WIDTH-1:0] fifo1_out;
wire                                 fifo0_full;
wire                                 fifo0_empty;
wire                                 fifo1_full;
wire                                 fifo1_empty;

reg  [OUT_CHANNELS*OUTPUT_WIDTH-1:0] pw1_hold;
reg  [OUT_CHANNELS*OUTPUT_WIDTH-1:0] fifo0_delay [0:6];
reg  [OUT_CHANNELS*OUTPUT_WIDTH-1:0] fifo1_delay [0:6];
reg                                  fifo0_empty_pipe [0:6];
reg                                  fifo1_empty_pipe [0:6];
reg  [OUT_CHANNELS*OUTPUT_WIDTH-1:0] stage8_out_pw0;
reg  [OUT_CHANNELS*OUTPUT_WIDTH-1:0] stage8_out_pw1;
reg  [OUT_CHANNELS*OUTPUT_WIDTH-1:0] o_data_reg;
reg  [OUT_CHANNELS*OUTPUT_WIDTH-1:0] o_data_pw1_reg;

integer s;
integer oc;

genvar ch;

function signed [OUTPUT_WIDTH-1:0] quantize_lane_no_relu;
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
        quantize_lane_no_relu = 16'sh7FFF;
    else if (shifted_val < $signed(16'sh8000))
        quantize_lane_no_relu = 16'sh8000;
    else
        quantize_lane_no_relu = shifted_val[OUTPUT_WIDTH-1:0];
end
endfunction

generate
    for (ch = 0; ch < OUT_CHANNELS; ch = ch + 1) begin : GEN_POST_MAC_QUANT
        assign pw0_out[ch*OUTPUT_WIDTH +: OUTPUT_WIDTH] =
            quantize_lane_no_relu($signed(pw0_out_raw[ch*PSUM_WIDTH +: PSUM_WIDTH]));
        assign pw1_out[ch*OUTPUT_WIDTH +: OUTPUT_WIDTH] =
            quantize_lane_no_relu($signed(pw1_out_raw[ch*PSUM_WIDTH +: PSUM_WIDTH]));
    end
endgenerate

controller_pointwise u_controller (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(i_valid),
    .i_mode(i_mode),
    .i_is_last(i_is_last),
    .i_is_first(i_is_first),
    .valid_pipe(valid_pipe),
    .mode_pipe(mode_pipe),
    .is_last_pipe(is_last_pipe),
    .is_first_pipe(is_first_pipe),
    .pw_en(pw_en),
    .fifo_rd_en(fifo_rd_en),
    .stage7_mode(stage7_mode),
    .stage8_pw0_en(stage8_pw0_en),
    .stage8_pw1_en(stage8_pw1_en),
    .stage8_pw0_is_first(stage8_pw0_is_first),
    .stage8_pw1_is_first(stage8_pw1_is_first),
    .fifo0_wr_en(fifo0_wr_en),
    .fifo1_wr_en(fifo1_wr_en),
    .quant0_valid(quant0_valid_unused),
    .quant1_valid(quant1_valid_unused),
    .relu_en(relu_en_unused),
    .o_valid(controller_o_valid_unused)
);

input_register #(
    .DATA_WIDTH(DATA_WIDTH),
    .IN_CHANNELS(IN_CHANNELS)
) u_input_register (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(i_valid),
    .i_data_feature(i_data_feature),
    .feature_reg(feature_reg),
    .o_valid()
);

(* dont_touch = "true" *) pointwise_mac1 #(
    .DATA_WIDTH(DATA_WIDTH),
    .IN_CHANNELS(IN_CHANNELS),
    .OUT_CHANNELS(OUT_CHANNELS),
    .PSUM_WIDTH(PSUM_WIDTH)
) u_pw0 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(pw_en),
    .i_data_feature(feature_reg),
    .i_data_weight(i_data_weight_pw0),
    .o_data_psum(pw0_out_raw),
    .o_valid()
);

(* dont_touch = "true" *) pointwise_mac1 #(
    .DATA_WIDTH(DATA_WIDTH),
    .IN_CHANNELS(IN_CHANNELS),
    .OUT_CHANNELS(OUT_CHANNELS),
    .PSUM_WIDTH(PSUM_WIDTH)
) u_pw1 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(pw_en),
    .i_data_feature(feature_reg),
    .i_data_weight(i_data_weight_pw1),
    .o_data_psum(pw1_out_raw),
    .o_valid()
);

pw0_pw1_adder #(
    .DATA_WIDTH(OUTPUT_WIDTH),
    .CHANNELS(OUT_CHANNELS)
) u_stage7_adder (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(valid_pipe[6]),
    .i_mode(stage7_mode),
    .i_data_pw0(pw0_out),
    .i_data_pw1(pw1_out),
    .o_data_sum(stage7_out),
    .o_valid()
);

psum_single_fifo #(
    .MAX_PTR(FIFO_MAX_PTR),
    .DATA_WIDTH(OUTPUT_WIDTH),
    .OC(OUT_CHANNELS)
) u_psum_fifo0 (
    .clk(clk),
    .rst_n(rst_n),
    .mode(i_fifo_mode),
    .i_data(stage8_out_pw0),
    .wr_en(fifo0_wr_en),
    .rd_en(fifo_rd_en),
    .o_data(fifo0_out),
    .full(fifo0_full),
    .empty(fifo0_empty)
);

psum_single_fifo #(
    .MAX_PTR(FIFO_MAX_PTR),
    .DATA_WIDTH(OUTPUT_WIDTH),
    .OC(OUT_CHANNELS)
) u_psum_fifo1 (
    .clk(clk),
    .rst_n(rst_n),
    .mode(i_fifo_mode),
    .i_data(stage8_out_pw1),
    .wr_en(fifo1_wr_en),
    .rd_en(fifo_rd_en),
    .o_data(fifo1_out),
    .full(fifo1_full),
    .empty(fifo1_empty)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pw1_hold <= '0;
        for (s = 0; s < 7; s = s + 1) begin
            fifo0_delay[s] <= '0;
            fifo1_delay[s] <= '0;
            fifo0_empty_pipe[s] <= 1'b1;
            fifo1_empty_pipe[s] <= 1'b1;
        end
    end else begin
        if (valid_pipe[6] && !mode_pipe[6]) begin
            pw1_hold <= pw1_out;
        end

        fifo0_delay[0] <= fifo0_out;
        fifo1_delay[0] <= fifo1_out;
        fifo0_empty_pipe[0] <= fifo0_empty;
        fifo1_empty_pipe[0] <= fifo1_empty;

        for (s = 1; s < 7; s = s + 1) begin
            fifo0_delay[s] <= fifo0_delay[s-1];
            fifo1_delay[s] <= fifo1_delay[s-1];
            fifo0_empty_pipe[s] <= fifo0_empty_pipe[s-1];
            fifo1_empty_pipe[s] <= fifo1_empty_pipe[s-1];
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        stage8_out_pw0 <= '0;
        stage8_out_pw1 <= '0;
    end else begin
        if (stage8_pw0_en) begin
            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                if (stage8_pw0_is_first || fifo0_empty_pipe[6]) begin
                    stage8_out_pw0[oc*OUTPUT_WIDTH +: OUTPUT_WIDTH] <=
                        $signed(stage7_out[oc*OUTPUT_WIDTH +: OUTPUT_WIDTH]);
                end else begin
                    stage8_out_pw0[oc*OUTPUT_WIDTH +: OUTPUT_WIDTH] <=
                        $signed(stage7_out[oc*OUTPUT_WIDTH +: OUTPUT_WIDTH]) +
                        $signed(fifo0_delay[6][oc*OUTPUT_WIDTH +: OUTPUT_WIDTH]);
                end
            end
        end

        if (stage8_pw1_en) begin
            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                if (stage8_pw1_is_first || fifo1_empty_pipe[6]) begin
                    stage8_out_pw1[oc*OUTPUT_WIDTH +: OUTPUT_WIDTH] <=
                        $signed(pw1_hold[oc*OUTPUT_WIDTH +: OUTPUT_WIDTH]);
                end else begin
                    stage8_out_pw1[oc*OUTPUT_WIDTH +: OUTPUT_WIDTH] <=
                        $signed(pw1_hold[oc*OUTPUT_WIDTH +: OUTPUT_WIDTH]) +
                        $signed(fifo1_delay[6][oc*OUTPUT_WIDTH +: OUTPUT_WIDTH]);
                end
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_data_reg     <= '0;
        o_data_pw1_reg <= '0;
    end else begin
        if (valid_pipe[8] && is_last_pipe[8]) begin
            o_data_reg <= stage8_out_pw0;
        end

        if (valid_pipe[8] && is_last_pipe[8] && !mode_pipe[8]) begin
            o_data_pw1_reg <= stage8_out_pw1;
        end
    end
end

assign o_data     = o_data_reg;
assign o_data_pw1 = o_data_pw1_reg;
assign o_valid    = valid_pipe[9] & is_last_pipe[9];
assign o_valid_pw1 = valid_pipe[9] & is_last_pipe[9] & ~mode_pipe[9];

endmodule
