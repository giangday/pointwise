module pw_top #(
    parameter DATA_WIDTH   = 16,
    parameter IN_CHANNELS  = 16,
    parameter OUT_CHANNELS = 16,
    parameter FIFO_MAX_PTR = 64*64,
    parameter PIPE_DEPTH   = 10
)(
    input  wire                                      clk,
    input  wire                                      rst_n,
    input  wire                                      i_weight_valid0,       //D: added
    input  wire                                      i_weight_valid1,       //D: added
    input  wire                                      i_valid,
    input  wire                                      i_mode,
    input  wire                                      i_is_first,
    input  wire                                      i_is_last,
    input  wire                                      i_rst_stage,           //reset flag stage done
    input  wire [7:0]                                i_fifo_mode,
    input  wire [IN_CHANNELS*DATA_WIDTH*2-1:0]       i_data_feature,
    input  wire [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight_pw,
    input  wire                                      i_bias_valid0,       //D: added
    input  wire                                      i_bias_valid1,       //D: added
    input  wire [OUT_CHANNELS*DATA_WIDTH-1:0]        i_bias_pw,

    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_data_pw0,
    output wire                                      o_valid_pw0,
    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_data_pw1,
    output wire                                      o_valid_pw1,
    output wire                                      o_stage_done           // flag stage done
//--------------------------------------------------------------------------------- 
//    output wire [PIPE_DEPTH-1:0]                     o_valid_pipe_dbg,
//    output wire [PIPE_DEPTH-1:0]                     o_mode_pipe_dbg,
//    output wire [PIPE_DEPTH-1:0]                     o_first_pipe_dbg,
//    output wire [PIPE_DEPTH-1:0]                     o_last_pipe_dbg,

//    output wire                                      o_fifo0_rd_en_dbg,
//    output wire                                      o_fifo1_rd_en_dbg,
//    output wire                                      o_relu0_fifo_wr_en_dbg,
//    output wire                                      o_relu1_fifo_wr_en_dbg,

//    output wire                                      o_fifo0_full_dbg,
//    output wire                                      o_fifo0_empty_dbg,
//    output wire                                      o_fifo1_full_dbg,
//    output wire                                      o_fifo1_empty_dbg,

//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_pw0_mac_out_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_pw1_mac_out_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_pw0_adder_out_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_pw1_adder_out_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_fifo0_out_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_fifo1_out_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_fifo0_delay0_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_fifo0_delay1_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_fifo1_delay0_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_fifo1_delay1_dbg,
//    output wire                                      o_fifo0_empty_pipe0_dbg,
//    output wire                                      o_fifo0_empty_pipe1_dbg,
//    output wire                                      o_fifo1_empty_pipe0_dbg,
//    output wire                                      o_fifo1_empty_pipe1_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_pw0_psum_out_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_pw1_psum_out_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_relu0_out_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_relu1_out_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_relu0_fifo_data_dbg,
//    output wire [OUT_CHANNELS*DATA_WIDTH-1:0]        o_relu1_fifo_data_dbg
);

localparam NUM_LEVELS = $clog2(IN_CHANNELS) + 1;
localparam FIFO_DELAY = 1;
localparam WEIGHT_TOTAL_WIDTH = OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH;
localparam CLUSTER_WIDTH = IN_CHANNELS*DATA_WIDTH;

reg  [PIPE_DEPTH-1:0] valid_pipe;
reg  [PIPE_DEPTH-1:0] mode_pipe;
reg  [PIPE_DEPTH-1:0] first_pipe;
reg  [PIPE_DEPTH-1:0] last_pipe;
reg                   weight_pw0_loaded;
reg                   weight_pw1_loaded;

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

wire [OUT_CHANNELS*DATA_WIDTH-1:0] bias_pw0;
wire [OUT_CHANNELS*DATA_WIDTH-1:0] bias_pw1;

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
wire feature_fire;
wire [WEIGHT_TOTAL_WIDTH-1:0] pw0_weight_buf;
wire [WEIGHT_TOTAL_WIDTH-1:0] pw1_weight_buf;
wire pw0_weight_valid;
wire pw1_weight_valid;



reg [OUT_CHANNELS*DATA_WIDTH-1:0] fifo0_data_delay0, fifo0_data_delay1;
reg [OUT_CHANNELS*DATA_WIDTH-1:0] fifo1_data_delay0, fifo1_data_delay1;

reg                               fifo0_empty0, fifo0_empty1, fifo0_empty2;
reg                               fifo1_empty0, fifo1_empty1, fifo1_empty2;

integer s;

assign feature_fire = i_valid & weight_pw0_loaded & weight_pw1_loaded;

always @(posedge clk) begin
    if (!rst_n) begin
        valid_pipe <= 0;
        mode_pipe  <= 0;
        first_pipe <= 0;
        last_pipe  <= 0;
        weight_pw0_loaded <= 1'b0;
        weight_pw1_loaded <= 1'b0;
    end else begin
        if (i_rst_stage) begin
            weight_pw0_loaded <= 1'b0;
            weight_pw1_loaded <= 1'b0;
        end else begin
            if (pw0_weight_valid)
                weight_pw0_loaded <= 1'b1;
            if (pw1_weight_valid)
                weight_pw1_loaded <= 1'b1;
        end
 
        valid_pipe <= {valid_pipe[PIPE_DEPTH-2:0], feature_fire};
        mode_pipe  <= {mode_pipe[PIPE_DEPTH-2:0], i_mode};
        first_pipe <= {first_pipe[PIPE_DEPTH-2:0], i_is_first};
        last_pipe  <= {last_pipe[PIPE_DEPTH-2:0], i_is_last};
    end
end

assign fifo0_rd_en = valid_pipe[6] & ~first_pipe[6];
assign fifo1_rd_en = valid_pipe[6] & ~first_pipe[6] & ~mode_pipe[6];


// fifo_empty = 1 la trong, fifo_empty = 0 la co du lieu
//tai chu ki n co data cuoi cung duoc doc ra tu fifo va tin hieu empty = 1
// nhu vay chu ki n-1 la chu ki co tin hieu empty = 0, co du lieu trong fifo 
// data va empty se delay cach nhau 1 chu ki
always @(posedge clk) begin
    if (!rst_n) begin
        // ===== data =====
        fifo0_data_delay0 <= 0;
        fifo0_data_delay1 <= 0;
        fifo1_data_delay0 <= 0;
        fifo1_data_delay1 <= 0;

        // ===== empty =====
        fifo0_empty0 <= 1'b1;
        fifo0_empty1 <= 1'b1;
        fifo0_empty2 <= 1'b1;

        fifo1_empty0 <= 1'b1;
        fifo1_empty1 <= 1'b1;
        fifo1_empty2 <= 1'b1;
    end else begin
        // =========================
        // Stage 0 
        // =========================
        fifo0_data_delay0 <= fifo0_out;
        fifo1_data_delay0 <= fifo1_out;

        fifo0_empty0 <= fifo0_empty;
        fifo1_empty0 <= fifo1_empty;

        // =========================
        // Stage 1
        // =========================
        fifo0_data_delay1 <= fifo0_data_delay0;
        fifo1_data_delay1 <= fifo1_data_delay0;

        fifo0_empty1 <= fifo0_empty0;
        fifo1_empty1 <= fifo1_empty0;

        // =========================
        // Stage 2 (empty only)
        // =========================
        fifo0_empty2 <= fifo0_empty1;
        fifo1_empty2 <= fifo1_empty1;
    end
end


// buffer weight vao 2 buffer rieng biet cho pw0 va pw1
weight_buffer #(
    .CLUSTER_SIZE(CLUSTER_WIDTH),
    .NUM_CLUSTERS(OUT_CHANNELS),
    .INPUT_WIDTH(WEIGHT_TOTAL_WIDTH),
    .CHUNK_WIDTH(CLUSTER_WIDTH)
) u_weight_buffer0 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(i_weight_valid0),
    .i_data(i_data_weight_pw),
    .cluster_flat(pw0_weight_buf),
    .o_valid(pw0_weight_valid)
);

weight_buffer #(
    .CLUSTER_SIZE(CLUSTER_WIDTH),
    .NUM_CLUSTERS(OUT_CHANNELS),
    .INPUT_WIDTH(WEIGHT_TOTAL_WIDTH),
    .CHUNK_WIDTH(CLUSTER_WIDTH)
) u_weight_buffer1 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(i_weight_valid1),
    .i_data(i_data_weight_pw),
    .cluster_flat(pw1_weight_buf),
    .o_valid(pw1_weight_valid)
);

// MAC module: nhan i_data_feature voi i_data_weight_pw, dua ra pw0_mac_out va pw1_mac_out
pw_mac #(
    .DATA_WIDTH(DATA_WIDTH),
    .IN_CHANNELS(IN_CHANNELS),
    .OUT_CHANNELS(OUT_CHANNELS)
) u_pw_mac0 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(feature_fire),
    .i_valid_pipe(valid_pipe[6:0]),
    .i_data_feature(i_data_feature[IN_CHANNELS*DATA_WIDTH-1:0]),
    .i_data_weight(pw0_weight_buf),
    .o_data(pw0_mac_out)
);

pw_mac #(
    .DATA_WIDTH(DATA_WIDTH),
    .IN_CHANNELS(IN_CHANNELS),
    .OUT_CHANNELS(OUT_CHANNELS)
) u_pw_mac1 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(feature_fire),
    .i_valid_pipe(valid_pipe[6:0]),
    .i_data_feature(i_data_feature[IN_CHANNELS*DATA_WIDTH*2-1:IN_CHANNELS*DATA_WIDTH]),
    .i_data_weight(pw1_weight_buf),
    .o_data(pw1_mac_out)
);

// cong pw0_mac_out voi pw1_mac_out, neu i_mode = 0 thi cong, neu i_mode = 1 thi khong cong ma dua thang pw0_mac_out vao pw0_adder_out va pw1_mac_out vao pw1_adder_out
pw0_pw1_adder #(
    .DATA_WIDTH(DATA_WIDTH),
    .CHANNELS(OUT_CHANNELS)
) u_pw0_pw1_adder (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(valid_pipe[7]),
    .i_mode(mode_pipe[7]),
    .i_data_pw0(pw0_mac_out),
    .i_data_pw1(pw1_mac_out),
    .o_data_pw0(pw0_adder_out),
    .o_data_pw1(pw1_adder_out)
);

// fifo dung de luu tru psum tam thoi, khi nao can cong psum thi doc ra tu fifo, neu fifo empty thi coi nhu 0
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


// cong thuc tinh psum trong psum_adder_pw, neu la first thi khong cong psum tu fifo, neu khong phai first thi cong voi psum tu fifo (neu fifo empty thi coi nhu 0)
psum_adder_pw #(
    .DATA_WIDTH(DATA_WIDTH),
    .CHANNELS(OUT_CHANNELS)
) u_psum_adder0 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(valid_pipe[8]),
    .i_is_first(first_pipe[8]),
    .i_data(pw0_adder_out),
    .i_fifo_data(fifo0_data_delay1),
    .i_fifo_empty(fifo0_empty2),
    .o_data(pw0_psum_out)
);

psum_adder_pw #(
    .DATA_WIDTH(DATA_WIDTH),
    .CHANNELS(OUT_CHANNELS)
) u_psum_adder1 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(valid_pipe[8] & ~mode_pipe[8]),
    .i_is_first(first_pipe[8]),
    .i_data(pw1_adder_out),
    .i_fifo_data(fifo1_data_delay1),
    .i_fifo_empty(fifo1_empty2),
    .o_data(pw1_psum_out)
);

// added bias buffer
bias_buffer #(
    .DATA_WIDTH(DATA_WIDTH),
    .CHANNELS(OUT_CHANNELS)
) u_bias_buffer0 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(i_bias_valid0), //D: added
    .i_data(i_bias_pw),
    .o_data(bias_pw0)
);

bias_buffer #(
    .DATA_WIDTH(DATA_WIDTH),
    .CHANNELS(OUT_CHANNELS)
) u_bias_buffer1 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(i_bias_valid1), //D: added
    .i_data(i_bias_pw),
    .o_data(bias_pw1)
);

// added relu + output module
relu_output #(
    .DATA_WIDTH(DATA_WIDTH),
    .CHANNELS(OUT_CHANNELS)
) u_relu_output0 (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(valid_pipe[9]),
    .i_is_last(last_pipe[9]),
    .i_data(pw0_psum_out),
    .i_bias(bias_pw0),
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
    .i_valid(valid_pipe[9] & ~mode_pipe[9]),
    .i_is_last(last_pipe[9]),
    .i_data(pw1_psum_out),
    .i_bias(bias_pw1),
    .o_fifo_wr_en(relu1_fifo_wr_en),
    .o_fifo_data(relu1_fifo_data),
    .o_data(relu1_out),
    .o_valid(relu1_valid)
);

// count stage done: neu da duyet het du lieu cua stage do thi set stage_done = 1, nguoc lai thi set stage_done = 0
count_stage_done u_count_stage_done0 (
    .clk(clk),
    .rst_n(rst_n),
    .rst_stage_done(i_rst_stage),
    .relu_valid(relu0_valid),
    .i_mode(i_fifo_mode),
    .o_stage_done(o_stage_done)
);



assign o_data_pw0  = relu0_out;
assign o_valid_pw0 = relu0_valid;
assign o_data_pw1  = relu1_out;
assign o_valid_pw1 = relu1_valid;

// debug outputs
//assign o_valid_pipe_dbg        = valid_pipe;
//assign o_mode_pipe_dbg         = mode_pipe;
//assign o_first_pipe_dbg        = first_pipe;
//assign o_last_pipe_dbg         = last_pipe;

//assign o_fifo0_rd_en_dbg       = fifo0_rd_en;
//assign o_fifo1_rd_en_dbg       = fifo1_rd_en;
//assign o_relu0_fifo_wr_en_dbg  = relu0_fifo_wr_en;
//assign o_relu1_fifo_wr_en_dbg  = relu1_fifo_wr_en;

//assign o_fifo0_full_dbg        = fifo0_full;
//assign o_fifo0_empty_dbg       = fifo0_empty;
//assign o_fifo1_full_dbg        = fifo1_full;
//assign o_fifo1_empty_dbg       = fifo1_empty;

//assign o_pw0_mac_out_dbg       = pw0_mac_out;
//assign o_pw1_mac_out_dbg       = pw1_mac_out;
//assign o_pw0_adder_out_dbg     = pw0_adder_out;
//assign o_pw1_adder_out_dbg     = pw1_adder_out;
//assign o_fifo0_out_dbg         = fifo0_out;
//assign o_fifo1_out_dbg         = fifo1_out;
//assign o_fifo0_delay0_dbg      = fifo0_data_delay0;
//assign o_fifo0_delay1_dbg      = fifo0_data_delay1;
//assign o_fifo1_delay0_dbg      = fifo1_data_delay0;
//assign o_fifo1_delay1_dbg      = fifo1_data_delay1;
//assign o_fifo0_empty_pipe0_dbg = fifo0_empty1;
//assign o_fifo0_empty_pipe1_dbg = fifo0_empty2;
//assign o_fifo1_empty_pipe0_dbg = fifo1_empty1;
//assign o_fifo1_empty_pipe1_dbg = fifo1_empty2;
//assign o_pw0_psum_out_dbg      = pw0_psum_out;
//assign o_pw1_psum_out_dbg      = pw1_psum_out;
//assign o_relu0_out_dbg         = relu0_out;
//assign o_relu1_out_dbg         = relu1_out;
//assign o_relu0_fifo_data_dbg   = relu0_fifo_data;
//assign o_relu1_fifo_data_dbg   = relu1_fifo_data;

endmodule
