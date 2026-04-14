`timescale 1ns / 1ps

module tb_pw_top;

    localparam DATA_WIDTH   = 16;
    localparam IN_CHANNELS  = 16;
    localparam OUT_CHANNELS = 16;
    localparam FIFO_MAX_PTR = 64*64;
    localparam PIPE_DEPTH   = 8;
    localparam PSUM_WIDTH   = (DATA_WIDTH * 2) + $clog2(IN_CHANNELS);

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
    wire                               o_valid_pw0;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_data_pw1;
    wire                               o_valid_pw1;

    wire [PIPE_DEPTH-1:0]              o_valid_pipe_dbg;
    wire [PIPE_DEPTH-1:0]              o_mode_pipe_dbg;
    wire [PIPE_DEPTH-1:0]              o_first_pipe_dbg;
    wire [PIPE_DEPTH-1:0]              o_last_pipe_dbg;
    wire                               o_fifo0_rd_en_dbg;
    wire                               o_fifo1_rd_en_dbg;
    wire                               o_relu0_fifo_wr_en_dbg;
    wire                               o_relu1_fifo_wr_en_dbg;
    wire                               o_fifo0_full_dbg;
    wire                               o_fifo0_empty_dbg;
    wire                               o_fifo1_full_dbg;
    wire                               o_fifo1_empty_dbg;
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
    wire                               o_fifo0_empty_pipe0_dbg;
    wire                               o_fifo0_empty_pipe1_dbg;
    wire                               o_fifo1_empty_pipe0_dbg;
    wire                               o_fifo1_empty_pipe1_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_pw0_psum_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_pw1_psum_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_relu0_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_relu1_out_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_relu0_fifo_data_dbg;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_relu1_fifo_data_dbg;

    integer oc;
    integer ic;
    integer err_count;
    reg signed [DATA_WIDTH-1:0] lane;

    pw_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS),
        .FIFO_MAX_PTR(FIFO_MAX_PTR),
        .PIPE_DEPTH(PIPE_DEPTH)
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

    task automatic clear_inputs;
        begin
            i_weight_valid    = 1'b0;
            i_valid           = 1'b0;
            i_mode            = 1'b0;
            i_is_first        = 1'b0;
            i_is_last         = 1'b0;
            i_fifo_mode       = 2'b11;
            i_data_feature    = 0;
            i_data_weight_pw0 = 0;
            i_data_weight_pw1 = 0;
            bias_pw0          = 0;
            bias_pw1          = 0;
        end
    endtask

    task automatic load_weights_once;
        input signed [DATA_WIDTH-1:0] w0_val;
        input signed [DATA_WIDTH-1:0] w1_val;
        begin
            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                    i_data_weight_pw0[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = w0_val;
                    i_data_weight_pw1[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = w1_val;
                end
            end

            @(negedge clk);
            i_weight_valid = 1'b1;
            @(negedge clk);
            i_weight_valid = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic set_feature_constant;
        input signed [DATA_WIDTH-1:0] feat_val;
        begin
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1)
                i_data_feature[ic*DATA_WIDTH +: DATA_WIDTH] = feat_val;
        end
    endtask

    task automatic set_bias_constant;
        input signed [DATA_WIDTH-1:0] b0_val;
        input signed [DATA_WIDTH-1:0] b1_val;
        begin
            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                bias_pw0[oc*DATA_WIDTH +: DATA_WIDTH] = b0_val;
                bias_pw1[oc*DATA_WIDTH +: DATA_WIDTH] = b1_val;
            end
        end
    endtask

    task automatic send_sample;
        input mode_val;
        input first_val;
        input last_val;
        begin
            @(negedge clk);
            i_mode     = mode_val;
            i_is_first = first_val;
            i_is_last  = last_val;
            i_valid    = 1'b1;
            @(negedge clk);
            i_valid    = 1'b0;
        end
    endtask

    task automatic wait_pw0_and_check_const;
        input signed [DATA_WIDTH-1:0] exp_val;
        input [127:0] tag;
        integer timeout;
        begin
            timeout = 0;
            while (!o_valid_pw0 && timeout < 40) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (!o_valid_pw0) begin
                $display("FAIL: %0s timeout waiting o_valid_pw0", tag);
                err_count = err_count + 1;
            end else begin
                #1;
                for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                    lane = $signed(o_data_pw0[oc*DATA_WIDTH +: DATA_WIDTH]);
                    if (lane !== exp_val) begin
                        $display("FAIL: %0s pw0 oc=%0d got=%0d exp=%0d time=%0t", tag, oc, lane, exp_val, $time);
                        err_count = err_count + 1;
                    end
                end
            end
        end
    endtask

    task automatic wait_both_and_check_const;
        input signed [DATA_WIDTH-1:0] exp_val_pw0;
        input signed [DATA_WIDTH-1:0] exp_val_pw1;
        input [127:0] tag;
        integer timeout;
        begin
            timeout = 0;
            while (!(o_valid_pw0 && o_valid_pw1) && timeout < 40) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (!(o_valid_pw0 && o_valid_pw1)) begin
                $display("FAIL: %0s timeout waiting o_valid_pw0/o_valid_pw1", tag);
                err_count = err_count + 1;
            end else begin
                #1;
                for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                    lane = $signed(o_data_pw0[oc*DATA_WIDTH +: DATA_WIDTH]);
                    if (lane !== exp_val_pw0) begin
                        $display("FAIL: %0s pw0 oc=%0d got=%0d exp=%0d time=%0t", tag, oc, lane, exp_val_pw0, $time);
                        err_count = err_count + 1;
                    end

                    lane = $signed(o_data_pw1[oc*DATA_WIDTH +: DATA_WIDTH]);
                    if (lane !== exp_val_pw1) begin
                        $display("FAIL: %0s pw1 oc=%0d got=%0d exp=%0d time=%0t", tag, oc, lane, exp_val_pw1, $time);
                        err_count = err_count + 1;
                    end
                end
            end
        end
    endtask

    task automatic ensure_no_pw1_valid;
        input [127:0] tag;
        integer k;
        begin
            for (k = 0; k < 6; k = k + 1) begin
                @(posedge clk);
                if (o_valid_pw1) begin
                    $display("FAIL: %0s unexpected o_valid_pw1 at time %0t", tag, $time);
                    err_count = err_count + 1;
                end
            end
        end
    endtask

    initial begin
        err_count = 0;
        clear_inputs();
        rst_n = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        load_weights_once(16'sd32, 16'sd16);

        // CASE0: mode=0, first=1, last=1
        // pw0: 16*32*32 = 16384 -> q = 16, + bias 4 -> 20
        // pw1: 16*32*16 =  8192 -> q =  8, + bias -5 -> 3
        clear_inputs();
        set_feature_constant(16'sd32);
        set_bias_constant(16'sd4, -16'sd5);
        send_sample(1'b0, 1'b1, 1'b1);
        wait_both_and_check_const(16'sd20, 16'sd3, "CASE0");

        // CASE1: mode=1, first=1, last=1
        // pw0: 16 + 8 + 10 = 34
        // pw1: no valid
        clear_inputs();
        set_feature_constant(16'sd32);
        set_bias_constant(16'sd10, 16'sd0);
        send_sample(1'b1, 1'b1, 1'b1);
        wait_pw0_and_check_const(16'sd34, "CASE1");
        ensure_no_pw1_valid("CASE1");

        if (err_count == 0)
            $display("PASS: tb_pw_top completed without errors");
        else
            $display("FAIL: tb_pw_top found %0d errors", err_count);

        $finish;
    end

endmodule
