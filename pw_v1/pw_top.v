module pw_top #(
    parameter DATA_WIDTH   = 16,
    parameter IN_CHANNELS  = 16,
    parameter OUT_CHANNELS = 16,
    parameter FIFO_MAX_PTR = 64*64,
    parameter PIPE_DEPTH   = 8
)(
    input  wire                                      clk,
    input  wire                                      rst_n,
    input  wire                                      i_valid,
    input  wire                                      i_mode,
    input  wire                                      i_is_first,
    input  wire                                      i_is_last,
    input  wire [1:0]                                i_fifo_mode,
    input  wire [IN_CHANNELS*DATA_WIDTH-1:0]         i_data_feature,
    input  wire [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight_pw0,
    input  wire [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight_pw1,
    input  wire [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_bias_pw0,
    input  wire [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_bias_pw1,

    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_data_pw0,
    output wire                                      o_valid_pw0,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_data_pw1,
    output wire                                      o_valid_pw1,
//---------------------------------------------------------------------------------
    output wire [PIPE_DEPTH-1:0]                     o_valid_pipe_dbg,
    output wire [PIPE_DEPTH-1:0]                     o_mode_pipe_dbg,
    output wire [PIPE_DEPTH-1:0]                     o_first_pipe_dbg,
    output wire [PIPE_DEPTH-1:0]                     o_last_pipe_dbg,

    output wire                                      o_fifo0_rd_en_dbg,
    output wire                                      o_fifo1_rd_en_dbg,
    output wire                                      o_relu0_fifo_wr_en_dbg,
    output wire                                      o_relu1_fifo_wr_en_dbg,

    output wire                                      o_fifo0_full_dbg,
    output wire                                      o_fifo0_empty_dbg,
    output wire                                      o_fifo1_full_dbg,
    output wire                                      o_fifo1_empty_dbg,

    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_pw0_mac_out_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_pw1_mac_out_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_pw0_adder_out_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_pw1_adder_out_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_fifo0_out_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_fifo1_out_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_fifo0_delay0_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_fifo0_delay1_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_fifo1_delay0_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_fifo1_delay1_dbg,
    output wire                                      o_fifo0_empty_pipe0_dbg,
    output wire                                      o_fifo0_empty_pipe1_dbg,
    output wire                                      o_fifo1_empty_pipe0_dbg,
    output wire                                      o_fifo1_empty_pipe1_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_pw0_psum_out_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_pw1_psum_out_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_relu0_out_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_relu1_out_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_relu0_fifo_data_dbg,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_relu1_fifo_data_dbg
);

localparam NUM_LEVELS = $clog2(IN_CHANNELS) + 1;
localparam FIFO_DELAY = 1;

reg  [PIPE_DEPTH-1:0] valid_pipe;
reg  [PIPE_DEPTH-1:0] mode_pipe;
reg  [PIPE_DEPTH-1:0] first_pipe;
reg  [PIPE_DEPTH-1:0] last_pipe;

wire [OUT_CHANNELS*DATA_WIDTH-1:0] pw0_mac_out;
wire [OUT_CHANNELS*DATA_WIDTH-1:0] pw1_mac_out;
wire [OUT_CHANNELS*DATA_WIDTH-1:0] pw0_adder_out;
wire [OUT_CHANNELS*DATA_WIDTH-1:0] pw1_adder_out;
wire [OUT_CHANNELS*DATA_WIDTH-1:0] fifo0_out;
wire [OUT_CHANNELS*DATA_WIDTH-1:0] fifo1_out;
wire [OUT_CHANNELS*DATA_WIDTH-1:0] pw0_psum_out;
wire [OUT_CHANNELS*DATA_WIDTH-1:0] pw1_psum_out;
wire [OUT_CHANNELS*DATA_WIDTH-1:0] relu0_out;
wire [OUT_CHANNELS*DATA_WIDTH-1:0] relu1_out;
wire [OUT_CHANNELS*DATA_WIDTH-1:0] relu0_fifo_data;
wire [OUT_CHANNELS*DATA_WIDTH-1:0] relu1_fifo_data;

wire fifo0_full;
wire fifo0_empty;
wire fifo1_full;
wire fifo1_empty;
wire fifo0_rd_en;
wire fifo1_rd_en;
wire relu0_fifo_wr_en;
wire relu1_fifo_wr_en;
wire relu0_valid;
wire relu1_valid;

reg [OUT_CHANNELS*DATA_WIDTH-1:0] fifo0_delay [0:FIFO_DELAY-1];
reg [OUT_CHANNELS*DATA_WIDTH-1:0] fifo1_delay [0:FIFO_DELAY-1];
reg                               fifo0_empty_pipe [0:FIFO_DELAY-1];
reg                               fifo1_empty_pipe [0:FIFO_DELAY-1];

integer s;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_pipe <= 0;
        mode_pipe  <= 0;
        first_pipe <= 0;
        last_pipe  <= 0;
    end else begin
        valid_pipe <= {valid_pipe[PIPE_DEPTH-2:0], i_valid};
        mode_pipe  <= {mode_pipe[PIPE_DEPTH-2:0], i_mode};
        first_pipe <= {first_pipe[PIPE_DEPTH-2:0], i_is_first};
        last_pipe  <= {last_pipe[PIPE_DEPTH-2:0], i_is_last};
    end
end

assign fifo0_rd_en = valid_pipe[4] & ~first_pipe[4];
assign fifo1_rd_en = valid_pipe[4] & ~first_pipe[4] & ~mode_pipe[4];

pw_mac #(
    .DATA_WIDTH(DATA_WIDTH),
    .IN_CHANNELS(IN_CHANNELS),
    .OUT_CHANNELS(OUT_CHANNELS)
) u_pw_mac0 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(i_valid),
    .i_valid_pipe(valid_pipe[4:0]),
    .i_data_feature(i_data_feature),
    .i_data_weight(i_data_weight_pw0),
    .i_data_bias(i_data_bias_pw0),
    .o_data(pw0_mac_out)
);

pw_mac #(
    .DATA_WIDTH(DATA_WIDTH),
    .IN_CHANNELS(IN_CHANNELS),
    .OUT_CHANNELS(OUT_CHANNELS)
) u_pw_mac1 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(i_valid),
    .i_valid_pipe(valid_pipe[4:0]),
    .i_data_feature(i_data_feature),
    .i_data_weight(i_data_weight_pw1),
    .i_data_bias(i_data_bias_pw1),
    .o_data(pw1_mac_out)
);

pw0_pw1_adder #(
    .DATA_WIDTH(DATA_WIDTH),
    .CHANNELS(OUT_CHANNELS)
) u_pw0_pw1_adder (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(valid_pipe[5]),
    .i_mode(mode_pipe[5]),
    .i_data_pw0(pw0_mac_out),
    .i_data_pw1(pw1_mac_out),
    .o_data_pw0(pw0_adder_out),
    .o_data_pw1(pw1_adder_out)
);

psum_fifo #(
    .MAX_PTR(FIFO_MAX_PTR),
    .DATA_WIDTH(DATA_WIDTH),
    .OC(OUT_CHANNELS)
) u_psum_fifo0 (
    .clk(clk),
    .rst_n(rst_n),
    .i_mode(i_fifo_mode),
    .i_data(relu0_fifo_data),
    .wr_en(relu0_fifo_wr_en),
    .rd_en(fifo0_rd_en),
    .o_data(fifo0_out),
    .full(fifo0_full),
    .empty(fifo0_empty)
);

psum_fifo #(
    .MAX_PTR(FIFO_MAX_PTR),
    .DATA_WIDTH(DATA_WIDTH),
    .OC(OUT_CHANNELS)
) u_psum_fifo1 (
    .clk(clk),
    .rst_n(rst_n),
    .i_mode(i_fifo_mode),
    .i_data(relu1_fifo_data),
    .wr_en(relu1_fifo_wr_en),
    .rd_en(fifo1_rd_en),
    .o_data(fifo1_out),
    .full(fifo1_full),
    .empty(fifo1_empty)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (s = 0; s < FIFO_DELAY; s = s + 1) begin
            fifo0_delay[s] <= 0;
            fifo1_delay[s] <= 0;
            fifo0_empty_pipe[s] <= 1'b1;
            fifo1_empty_pipe[s] <= 1'b1;
        end
    end else begin
        fifo0_delay[0] <= fifo0_out;
        fifo1_delay[0] <= fifo1_out;
        fifo0_empty_pipe[0] <= fifo0_empty;
        fifo1_empty_pipe[0] <= fifo1_empty;

        for (s = 1; s < FIFO_DELAY; s = s + 1) begin
            fifo0_delay[s] <= fifo0_delay[s-1];
            fifo1_delay[s] <= fifo1_delay[s-1];
            fifo0_empty_pipe[s] <= fifo0_empty_pipe[s-1];
            fifo1_empty_pipe[s] <= fifo1_empty_pipe[s-1];
        end
    end
end

psum_adder_pw #(
    .DATA_WIDTH(DATA_WIDTH),
    .CHANNELS(OUT_CHANNELS)
) u_psum_adder0 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(valid_pipe[6]),
    .i_is_first(first_pipe[6]),
    .i_data(pw0_adder_out),
    .i_fifo_data(fifo0_delay[FIFO_DELAY-1]),
    .i_fifo_empty(fifo0_empty_pipe[FIFO_DELAY]),
    .o_data(pw0_psum_out)
);

psum_adder_pw #(
    .DATA_WIDTH(DATA_WIDTH),
    .CHANNELS(OUT_CHANNELS)
) u_psum_adder1 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(valid_pipe[6] & ~mode_pipe[6]),
    .i_is_first(first_pipe[6]),
    .i_data(pw1_adder_out),
    .i_fifo_data(fifo1_delay[FIFO_DELAY-1]),
    .i_fifo_empty(fifo1_empty_pipe[FIFO_DELAY]),
    .o_data(pw1_psum_out)
);

relu_output #(
    .DATA_WIDTH(DATA_WIDTH),
    .CHANNELS(OUT_CHANNELS)
) u_relu_output0 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(valid_pipe[7]),
    .i_is_last(last_pipe[7]),
    .i_data(pw0_psum_out),
    .o_fifo_wr_en(relu0_fifo_wr_en),
    .o_fifo_data(relu0_fifo_data),
    .o_data(relu0_out),
    .o_valid(relu0_valid)
);

relu_output #(
    .DATA_WIDTH(DATA_WIDTH),
    .CHANNELS(OUT_CHANNELS)
) u_relu_output1 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(valid_pipe[7] & ~mode_pipe[7]),
    .i_is_last(last_pipe[7]),
    .i_data(pw1_psum_out),
    .o_fifo_wr_en(relu1_fifo_wr_en),
    .o_fifo_data(relu1_fifo_data),
    .o_data(relu1_out),
    .o_valid(relu1_valid)
);

assign o_data_pw0  = relu0_out;
assign o_valid_pw0 = relu0_valid;
assign o_data_pw1  = relu1_out;
assign o_valid_pw1 = relu1_valid;

// debug outputs
assign o_valid_pipe_dbg        = valid_pipe;
assign o_mode_pipe_dbg         = mode_pipe;
assign o_first_pipe_dbg        = first_pipe;
assign o_last_pipe_dbg         = last_pipe;

assign o_fifo0_rd_en_dbg       = fifo0_rd_en;
assign o_fifo1_rd_en_dbg       = fifo1_rd_en;
assign o_relu0_fifo_wr_en_dbg  = relu0_fifo_wr_en;
assign o_relu1_fifo_wr_en_dbg  = relu1_fifo_wr_en;

assign o_fifo0_full_dbg        = fifo0_full;
assign o_fifo0_empty_dbg       = fifo0_empty;
assign o_fifo1_full_dbg        = fifo1_full;
assign o_fifo1_empty_dbg       = fifo1_empty;

assign o_pw0_mac_out_dbg       = pw0_mac_out;
assign o_pw1_mac_out_dbg       = pw1_mac_out;
assign o_pw0_adder_out_dbg     = pw0_adder_out;
assign o_pw1_adder_out_dbg     = pw1_adder_out;
assign o_fifo0_out_dbg         = fifo0_out;
assign o_fifo1_out_dbg         = fifo1_out;
assign o_fifo0_delay0_dbg      = fifo0_delay[0];
assign o_fifo0_delay1_dbg      = fifo0_delay[1];
assign o_fifo1_delay0_dbg      = fifo1_delay[0];
assign o_fifo1_delay1_dbg      = fifo1_delay[1];
assign o_fifo0_empty_pipe0_dbg = fifo0_empty_pipe[0];
assign o_fifo0_empty_pipe1_dbg = fifo0_empty_pipe[1];
assign o_fifo1_empty_pipe0_dbg = fifo1_empty_pipe[0];
assign o_fifo1_empty_pipe1_dbg = fifo1_empty_pipe[1];
assign o_pw0_psum_out_dbg      = pw0_psum_out;
assign o_pw1_psum_out_dbg      = pw1_psum_out;
assign o_relu0_out_dbg         = relu0_out;
assign o_relu1_out_dbg         = relu1_out;
assign o_relu0_fifo_data_dbg   = relu0_fifo_data;
assign o_relu1_fifo_data_dbg   = relu1_fifo_data;

endmodule
