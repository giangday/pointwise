`timescale 1ns / 1ps

module tb_pw_top_smoke;

    localparam DATA_WIDTH   = 16;
    localparam IN_CHANNELS  = 16;
    localparam OUT_CHANNELS = 16;
    localparam FIFO_MAX_PTR = 64*64;

    reg clk;
    reg rst_n;
    reg i_weight_valid;
    reg i_valid;
    reg i_mode;
    reg i_is_first;
    reg i_is_last;
    reg [1:0] i_fifo_mode;
    reg [IN_CHANNELS*DATA_WIDTH-1:0] i_data_feature;
    reg [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight_pw0;
    reg [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight_pw1;
    reg [OUT_CHANNELS*DATA_WIDTH-1:0] bias_pw0;
    reg [OUT_CHANNELS*DATA_WIDTH-1:0] bias_pw1;

    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_data_pw0;
    wire o_valid_pw0;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_data_pw1;
    wire o_valid_pw1;
    wire [7:0] o_valid_pipe_dbg;
    wire [7:0] o_mode_pipe_dbg;
    wire [7:0] o_first_pipe_dbg;
    wire [7:0] o_last_pipe_dbg;
    wire o_fifo0_rd_en_dbg;
    wire o_fifo1_rd_en_dbg;
    wire o_relu0_fifo_wr_en_dbg;
    wire o_relu1_fifo_wr_en_dbg;
    wire o_fifo0_full_dbg;
    wire o_fifo0_empty_dbg;
    wire o_fifo1_full_dbg;
    wire o_fifo1_empty_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_pw0_mac_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_pw1_mac_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_pw0_adder_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_pw1_adder_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_fifo0_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_fifo1_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_fifo0_delay0_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_fifo0_delay1_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_fifo1_delay0_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_fifo1_delay1_dbg;
    wire o_fifo0_empty_pipe0_dbg;
    wire o_fifo0_empty_pipe1_dbg;
    wire o_fifo1_empty_pipe0_dbg;
    wire o_fifo1_empty_pipe1_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_pw0_psum_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_pw1_psum_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_relu0_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_relu1_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_relu0_fifo_data_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_relu1_fifo_data_dbg;

    integer oc;
    integer ic;
    integer err_count;

    pw_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS),
        .FIFO_MAX_PTR(FIFO_MAX_PTR)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_weight_valid(i_weight_valid),
        .i_valid(i_valid),
        .i_mode(i_mode),
        .i_is_first(i_is_first),
        .i_is_last(i_is_last),
        .i_fifo_mode(i_fifo_mode),
        .i_data_feature(i_data_feature),
        .i_data_weight_pw0(i_data_weight_pw0),
        .i_data_weight_pw1(i_data_weight_pw1),
        .bias_pw0(bias_pw0),
        .bias_pw1(bias_pw1),
        .o_data_pw0(o_data_pw0),
        .o_valid_pw0(o_valid_pw0),
        .o_data_pw1(o_data_pw1),
        .o_valid_pw1(o_valid_pw1),
        .o_valid_pipe_dbg(o_valid_pipe_dbg),
        .o_mode_pipe_dbg(o_mode_pipe_dbg),
        .o_first_pipe_dbg(o_first_pipe_dbg),
        .o_last_pipe_dbg(o_last_pipe_dbg),
        .o_fifo0_rd_en_dbg(o_fifo0_rd_en_dbg),
        .o_fifo1_rd_en_dbg(o_fifo1_rd_en_dbg),
        .o_relu0_fifo_wr_en_dbg(o_relu0_fifo_wr_en_dbg),
        .o_relu1_fifo_wr_en_dbg(o_relu1_fifo_wr_en_dbg),
        .o_fifo0_full_dbg(o_fifo0_full_dbg),
        .o_fifo0_empty_dbg(o_fifo0_empty_dbg),
        .o_fifo1_full_dbg(o_fifo1_full_dbg),
        .o_fifo1_empty_dbg(o_fifo1_empty_dbg),
        .o_pw0_mac_out_dbg(o_pw0_mac_out_dbg),
        .o_pw1_mac_out_dbg(o_pw1_mac_out_dbg),
        .o_pw0_adder_out_dbg(o_pw0_adder_out_dbg),
        .o_pw1_adder_out_dbg(o_pw1_adder_out_dbg),
        .o_fifo0_out_dbg(o_fifo0_out_dbg),
        .o_fifo1_out_dbg(o_fifo1_out_dbg),
        .o_fifo0_delay0_dbg(o_fifo0_delay0_dbg),
        .o_fifo0_delay1_dbg(o_fifo0_delay1_dbg),
        .o_fifo1_delay0_dbg(o_fifo1_delay0_dbg),
        .o_fifo1_delay1_dbg(o_fifo1_delay1_dbg),
        .o_fifo0_empty_pipe0_dbg(o_fifo0_empty_pipe0_dbg),
        .o_fifo0_empty_pipe1_dbg(o_fifo0_empty_pipe1_dbg),
        .o_fifo1_empty_pipe0_dbg(o_fifo1_empty_pipe0_dbg),
        .o_fifo1_empty_pipe1_dbg(o_fifo1_empty_pipe1_dbg),
        .o_pw0_psum_out_dbg(o_pw0_psum_out_dbg),
        .o_pw1_psum_out_dbg(o_pw1_psum_out_dbg),
        .o_relu0_out_dbg(o_relu0_out_dbg),
        .o_relu1_out_dbg(o_relu1_out_dbg),
        .o_relu0_fifo_data_dbg(o_relu0_fifo_data_dbg),
        .o_relu1_fifo_data_dbg(o_relu1_fifo_data_dbg)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        err_count = 0;
        rst_n = 1'b0;
        i_weight_valid = 1'b0;
        i_valid = 1'b0;
        i_mode = 1'b0;
        i_is_first = 1'b0;
        i_is_last = 1'b0;
        i_fifo_mode = 2'b11;
        i_data_feature = 0;
        i_data_weight_pw0 = 0;
        i_data_weight_pw1 = 0;
        bias_pw0 = 0;
        bias_pw1 = 0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        for (ic = 0; ic < IN_CHANNELS; ic = ic + 1)
            i_data_feature[ic*DATA_WIDTH +: DATA_WIDTH] = 16'sd32;

        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            bias_pw0[oc*DATA_WIDTH +: DATA_WIDTH] = 16'sd0;
            bias_pw1[oc*DATA_WIDTH +: DATA_WIDTH] = 16'sd0;
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                i_data_weight_pw0[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = 16'sd32;
                i_data_weight_pw1[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = 16'sd16;
            end
        end

        @(negedge clk);
        i_weight_valid = 1'b1;
        @(negedge clk);
        i_weight_valid = 1'b0;

        repeat (2) @(posedge clk);

        @(negedge clk);
        i_mode = 1'b0;
        i_is_first = 1'b1;
        i_is_last = 1'b1;
        i_valid = 1'b1;
        @(negedge clk);
        i_valid = 1'b0;

        repeat (20) @(posedge clk);

        if (o_valid_pw0 !== 1'b1) begin
            $display("WARN: tb_pw_top_smoke did not observe o_valid_pw0; pw_top.v may still need cleanup before this tb is runnable.");
        end

        $display("INFO: tb_pw_top_smoke created. This tb assumes pw_top.v compiles with its current debug signals.");
        $finish;
    end

endmodule
