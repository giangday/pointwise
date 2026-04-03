`timescale 1ns / 1ps

module tb_pw_top_pipeline;

    localparam DATA_WIDTH     = 16;
    localparam IN_CHANNELS    = 16;
    localparam OUT_CHANNELS   = 16;
    localparam FIFO_MAX_PTR   = 64*64;
    localparam PIPE_DEPTH     = 8;
    localparam PSUM_WIDTH     = (DATA_WIDTH * 2) + $clog2(IN_CHANNELS);
    localparam NUM_PIPE_CASES = 256;

    reg clk;
    reg rst_n;
    reg i_valid;
    reg i_mode;
    reg i_is_first;
    reg i_is_last;
    reg [1:0] i_fifo_mode;
    reg [IN_CHANNELS*DATA_WIDTH-1:0] i_data_feature;
    reg [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight_pw0;
    reg [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight_pw1;
    reg [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_bias_pw0;
    reg [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_bias_pw1;

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

    reg signed [DATA_WIDTH-1:0] expected_pw0 [0:NUM_PIPE_CASES-1][0:OUT_CHANNELS-1];
    reg signed [DATA_WIDTH-1:0] expected_pw1 [0:NUM_PIPE_CASES-1][0:OUT_CHANNELS-1];
    reg                         expected_pw1_valid [0:NUM_PIPE_CASES-1];
    reg                         case_mode [0:NUM_PIPE_CASES-1];

    integer oc;
    integer ic;
    integer issue_idx;
    integer check_idx;
    integer err_count;
    integer timeout;

    pw_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS),
        .FIFO_MAX_PTR(FIFO_MAX_PTR),
        .PIPE_DEPTH(PIPE_DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid),
        .i_mode(i_mode),
        .i_is_first(i_is_first),
        .i_is_last(i_is_last),
        .i_fifo_mode(i_fifo_mode),
        .i_data_feature(i_data_feature),
        .i_data_weight_pw0(i_data_weight_pw0),
        .i_data_weight_pw1(i_data_weight_pw1),
        .i_data_bias_pw0(i_data_bias_pw0),
        .i_data_bias_pw1(i_data_bias_pw1),
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

    function signed [DATA_WIDTH-1:0] relu_lane;
        input signed [DATA_WIDTH-1:0] in_val;
    begin
        if (in_val[DATA_WIDTH-1])
            relu_lane = 0;
        else
            relu_lane = in_val;
    end
    endfunction

    function signed [DATA_WIDTH-1:0] quantize_lane;
        input signed [PSUM_WIDTH-1:0] in_val;
        reg   signed [PSUM_WIDTH-1:0] rounded_val;
        reg   signed [PSUM_WIDTH-1:0] shifted_val;
    begin
        if (in_val >= 0)
            rounded_val = in_val + ({{(PSUM_WIDTH-1){1'b0}}, 1'b1} <<< 9);
        else
            rounded_val = in_val - ({{(PSUM_WIDTH-1){1'b0}}, 1'b1} <<< 9);

        shifted_val = rounded_val >>> 10;

        if (shifted_val > $signed(16'sh7FFF))
            quantize_lane = 16'sh7FFF;
        else if (shifted_val < $signed(16'sh8000))
            quantize_lane = 16'sh8000;
        else
            quantize_lane = shifted_val[DATA_WIDTH-1:0];
    end
    endfunction

    task automatic clear_inputs;
        begin
            i_valid           = 1'b0;
            i_mode            = 1'b0;
            i_is_first        = 1'b0;
            i_is_last         = 1'b0;
            i_fifo_mode       = 2'b11;
            i_data_feature    = 0;
            i_data_weight_pw0 = 0;
            i_data_weight_pw1 = 0;
            i_data_bias_pw0   = 0;
            i_data_bias_pw1   = 0;
        end
    endtask

    task automatic fill_uniform_data;
        input signed [DATA_WIDTH-1:0] feat_val;
        input signed [DATA_WIDTH-1:0] w0_val;
        input signed [DATA_WIDTH-1:0] w1_val;
        input signed [DATA_WIDTH-1:0] b0_val;
        input signed [DATA_WIDTH-1:0] b1_val;
        begin
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1)
                i_data_feature[ic*DATA_WIDTH +: DATA_WIDTH] = feat_val;

            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                    i_data_weight_pw0[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = w0_val;
                    i_data_weight_pw1[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = w1_val;
                    i_data_bias_pw0[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH]   = b0_val;
                    i_data_bias_pw1[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH]   = b1_val;
                end
            end
        end
    endtask

    task automatic prepare_case;
        input integer case_id;
        input        mode_val;
        integer feat_val;
        integer w0_val;
        integer w1_val;
        integer b0_val;
        integer b1_val;
        reg signed [PSUM_WIDTH-1:0] raw0;
        reg signed [PSUM_WIDTH-1:0] raw1;
        reg signed [DATA_WIDTH-1:0] mac0_lane;
        reg signed [DATA_WIDTH-1:0] mac1_lane;
        reg signed [DATA_WIDTH:0]   sum16;
    begin
        feat_val = case_id - 3;
        w0_val   = (case_id % 5) - 2;
        w1_val   = ((case_id + 2) % 5) - 2;
        b0_val   = (case_id + 1) * 32;
        b1_val   = ((case_id % 4) - 1) * 32;

        case_mode[case_id] = mode_val;
        expected_pw1_valid[case_id] = ~mode_val;

        fill_uniform_data(feat_val, w0_val, w1_val, b0_val, b1_val);

        raw0 = IN_CHANNELS * ((feat_val * w0_val) + b0_val);
        raw1 = IN_CHANNELS * ((feat_val * w1_val) + b1_val);

        mac0_lane = quantize_lane(raw0);
        mac1_lane = quantize_lane(raw1);

        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            if (mode_val) begin
                sum16 = $signed(mac0_lane) + $signed(mac1_lane);
                expected_pw0[case_id][oc] = relu_lane(sum16[DATA_WIDTH-1:0]);
                expected_pw1[case_id][oc] = 0;
            end else begin
                expected_pw0[case_id][oc] = relu_lane(mac0_lane);
                expected_pw1[case_id][oc] = relu_lane(mac1_lane);
            end
        end
    end
    endtask

    task automatic check_branch_bus;
        input integer case_id;
        input        branch_sel;
        input [OUT_CHANNELS*DATA_WIDTH-1:0] bus_data;
        reg signed [DATA_WIDTH-1:0] lane;
        reg signed [DATA_WIDTH-1:0] exp_lane;
    begin
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            lane = $signed(bus_data[oc*DATA_WIDTH +: DATA_WIDTH]);
            exp_lane = branch_sel ? expected_pw1[case_id][oc] : expected_pw0[case_id][oc];
            if (lane !== exp_lane) begin
                $display("FAIL: case=%0d branch=%0d oc=%0d got=%0d exp=%0d time=%0t",
                         case_id, branch_sel, oc, lane, exp_lane, $time);
                err_count = err_count + 1;
            end
        end
    end
    endtask

    always @(negedge clk) begin
        if (rst_n && o_valid_pw0) begin
            if (check_idx >= NUM_PIPE_CASES) begin
                $display("FAIL: extra pipeline output at time %0t", $time);
                err_count = err_count + 1;
            end else begin
                check_branch_bus(check_idx, 1'b0, o_data_pw0);

                if (expected_pw1_valid[check_idx]) begin
                    if (!o_valid_pw1) begin
                        $display("FAIL: case=%0d missing o_valid_pw1 at time %0t",
                                 check_idx, $time);
                        err_count = err_count + 1;
                    end else begin
                        check_branch_bus(check_idx, 1'b1, o_data_pw1);
                    end
                end else if (o_valid_pw1) begin
                    $display("FAIL: case=%0d unexpected o_valid_pw1 at time %0t",
                             check_idx, $time);
                    err_count = err_count + 1;
                end

                $display("PIPE CASE %0d checked at time %0t", check_idx, $time);
                check_idx = check_idx + 1;
            end
        end
    end

    initial begin
        err_count = 0;
        issue_idx = 0;
        check_idx = 0;
        timeout   = 0;

        clear_inputs();
        rst_n = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        for (issue_idx = 0; issue_idx < NUM_PIPE_CASES; issue_idx = issue_idx + 1) begin
            prepare_case(issue_idx, issue_idx[0]);

            i_valid     = 1'b1;
            i_mode      = case_mode[issue_idx];
            i_is_first  = 1'b1;
            i_is_last   = 1'b1;
            i_fifo_mode = 2'b11;

            $display("PIPE CASE %0d/%0d issued mode=%0d issue_time=%0t",
                     issue_idx, NUM_PIPE_CASES-1, case_mode[issue_idx], $time);

            @(negedge clk);
        end

        clear_inputs();

        while ((check_idx < NUM_PIPE_CASES) && (timeout < 40)) begin
            @(negedge clk);
            timeout = timeout + 1;
        end

        if (check_idx != NUM_PIPE_CASES) begin
            $display("FAIL: timeout waiting pipeline outputs checked=%0d exp=%0d",
                     check_idx, NUM_PIPE_CASES);
            err_count = err_count + 1;
        end

        if (err_count == 0)
            $display("PASS: tb_pw_top_pipeline completed without errors");
        else
            $display("FAIL: tb_pw_top_pipeline found %0d errors", err_count);

        repeat (5) @(posedge clk);
        $finish;
    end

endmodule
