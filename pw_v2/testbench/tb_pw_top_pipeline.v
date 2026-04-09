`timescale 1ns / 1ps

module tb_pw_top_pipeline;

    localparam DATA_WIDTH     = 16;
    localparam IN_CHANNELS    = 16;
    localparam OUT_CHANNELS   = 16;
    localparam FIFO_MAX_PTR   = 64*64;
    localparam PIPE_DEPTH     = 8;
    localparam NUM_PIPE_CASES = 8;

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

    reg signed [DATA_WIDTH-1:0] expected_pw0 [0:NUM_PIPE_CASES-1];
    reg signed [DATA_WIDTH-1:0] expected_pw1 [0:NUM_PIPE_CASES-1];
    reg                         expected_pw1_valid [0:NUM_PIPE_CASES-1];
    reg                         case_mode [0:NUM_PIPE_CASES-1];

    integer oc;
    integer ic;
    integer issue_idx;
    integer check_idx;
    integer err_count;
    integer timeout;
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
        begin
            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                    i_data_weight_pw0[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = 16'sd32;
                    i_data_weight_pw1[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = 16'sd16;
                end
                bias_pw0[oc*DATA_WIDTH +: DATA_WIDTH] = 16'sd1;
                bias_pw1[oc*DATA_WIDTH +: DATA_WIDTH] = 16'sd2;
            end

            @(negedge clk);
            i_weight_valid = 1'b1;
            @(negedge clk);
            i_weight_valid = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic prepare_case;
        input integer case_id;
        integer feat_val;
        integer mac0_val;
        integer mac1_val;
        begin
            feat_val = (case_id + 1) * 8;
            case_mode[case_id] = case_id[0];
            expected_pw1_valid[case_id] = ~case_mode[case_id];

            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1)
                i_data_feature[ic*DATA_WIDTH +: DATA_WIDTH] = feat_val;

            mac0_val = feat_val / 2;
            mac1_val = feat_val / 4;

            if (case_mode[case_id]) begin
                expected_pw0[case_id] = mac0_val + mac1_val + 1;
                expected_pw1[case_id] = 0;
            end else begin
                expected_pw0[case_id] = mac0_val + 1;
                expected_pw1[case_id] = mac1_val + 2;
            end
        end
    endtask

    task automatic check_const_bus;
        input [OUT_CHANNELS*DATA_WIDTH-1:0] bus_data;
        input signed [DATA_WIDTH-1:0] exp_val;
        input [127:0] tag;
        begin
            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                lane = $signed(bus_data[oc*DATA_WIDTH +: DATA_WIDTH]);
                if (lane !== exp_val) begin
                    $display("FAIL: %0s oc=%0d got=%0d exp=%0d time=%0t", tag, oc, lane, exp_val, $time);
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
                check_const_bus(o_data_pw0, expected_pw0[check_idx], "PIPE_PW0");

                if (expected_pw1_valid[check_idx]) begin
                    if (!o_valid_pw1) begin
                        $display("FAIL: case=%0d missing o_valid_pw1 at time %0t", check_idx, $time);
                        err_count = err_count + 1;
                    end else begin
                        check_const_bus(o_data_pw1, expected_pw1[check_idx], "PIPE_PW1");
                    end
                end else if (o_valid_pw1) begin
                    $display("FAIL: case=%0d unexpected o_valid_pw1 at time %0t", check_idx, $time);
                    err_count = err_count + 1;
                end

                check_idx = check_idx + 1;
            end
        end
    end

    initial begin
        err_count = 0;
        issue_idx = 0;
        check_idx = 0;
        timeout = 0;
        clear_inputs();
        rst_n = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        load_weights_once();

        for (issue_idx = 0; issue_idx < NUM_PIPE_CASES; issue_idx = issue_idx + 1) begin
            prepare_case(issue_idx);

            @(negedge clk);
            i_mode      = case_mode[issue_idx];
            i_is_first  = 1'b1;
            i_is_last   = 1'b1;
            i_valid     = 1'b1;

            @(negedge clk);
            i_valid     = 1'b0;
        end

        i_weight_valid = 1'b0;
        i_valid        = 1'b0;
        i_mode         = 1'b0;
        i_is_first     = 1'b0;
        i_is_last      = 1'b0;
        i_fifo_mode    = 2'b11;

        while ((check_idx < NUM_PIPE_CASES) && (timeout < 80)) begin
            @(negedge clk);
            timeout = timeout + 1;
        end

        if (check_idx != NUM_PIPE_CASES) begin
            $display("FAIL: timeout waiting pipeline outputs checked=%0d exp=%0d", check_idx, NUM_PIPE_CASES);
            err_count = err_count + 1;
        end

        if (err_count == 0)
            $display("PASS: tb_pw_top_pipeline completed without errors");
        else
            $display("FAIL: tb_pw_top_pipeline found %0d errors", err_count);

        $finish;
    end

endmodule



