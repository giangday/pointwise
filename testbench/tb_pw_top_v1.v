`timescale 1ns / 1ps

module tb_pw_top;

    localparam DATA_WIDTH   = 16;
    localparam IN_CHANNELS  = 16;
    localparam OUT_CHANNELS = 16;
    localparam FIFO_MAX_PTR = 64*64;
    localparam PIPE_DEPTH   = 8;
    localparam PSUM_WIDTH   = (DATA_WIDTH * 2) + $clog2(IN_CHANNELS);
    localparam NUM_RANDOM_TILES = 12;

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

    reg signed [DATA_WIDTH-1:0] model_fifo0 [0:OUT_CHANNELS-1];
    reg signed [DATA_WIDTH-1:0] model_fifo1 [0:OUT_CHANNELS-1];
    reg signed [DATA_WIDTH-1:0] exp_pw0_lane [0:OUT_CHANNELS-1];
    reg signed [DATA_WIDTH-1:0] exp_pw1_lane [0:OUT_CHANNELS-1];

    integer oc;
    integer ic;
    integer err_count;
    integer seed;
    integer tile_idx;
    integer pass_idx;
    integer tile_len;
    integer tmp;
    reg     tile_mode;
    reg     pass_first;
    reg     pass_last;

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

    function integer rand_range;
        input integer low;
        input integer high;
        integer span;
        integer raw;
    begin
        span = high - low + 1;
        raw = $random(seed);
        if (raw < 0)
            raw = -raw;
        rand_range = low + (raw % span);
    end
    endfunction

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

    task automatic clear_model_fifo;
        begin
            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                model_fifo0[oc] = 0;
                model_fifo1[oc] = 0;
                exp_pw0_lane[oc] = 0;
                exp_pw1_lane[oc] = 0;
            end
        end
    endtask

    task automatic fill_random_data;
        integer feat_val;
        integer w0_val;
        integer w1_val;
        integer b0_val;
        integer b1_val;
        begin
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                feat_val = rand_range(-64, 63);
                i_data_feature[ic*DATA_WIDTH +: DATA_WIDTH] = feat_val;
            end

            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                    w0_val = rand_range(-32, 31);
                    w1_val = rand_range(-32, 31);
                    b0_val = rand_range(-256, 255);
                    b1_val = rand_range(-256, 255);

                    i_data_weight_pw0[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = w0_val;
                    i_data_weight_pw1[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = w1_val;
                    i_data_bias_pw0[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH]   = b0_val;
                    i_data_bias_pw1[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH]   = b1_val;
                end
            end
        end
    endtask

    task automatic send_input;
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

    task automatic compute_expected;
        input mode_val;
        input first_val;
        input last_val;
        integer oc_idx;
        integer ic_idx;
        reg signed [PSUM_WIDTH-1:0] acc0;
        reg signed [PSUM_WIDTH-1:0] acc1;
        reg signed [DATA_WIDTH-1:0] mac0_lane;
        reg signed [DATA_WIDTH-1:0] mac1_lane;
        reg signed [DATA_WIDTH-1:0] ad0_lane;
        reg signed [DATA_WIDTH-1:0] ad1_lane;
        reg signed [DATA_WIDTH-1:0] ps0_lane;
        reg signed [DATA_WIDTH-1:0] ps1_lane;
        reg signed [DATA_WIDTH:0]   sum16;
        begin
            for (oc_idx = 0; oc_idx < OUT_CHANNELS; oc_idx = oc_idx + 1) begin
                acc0 = 0;
                acc1 = 0;

                for (ic_idx = 0; ic_idx < IN_CHANNELS; ic_idx = ic_idx + 1) begin
                    acc0 = acc0
                         + $signed(i_data_feature[ic_idx*DATA_WIDTH +: DATA_WIDTH])
                         * $signed(i_data_weight_pw0[(oc_idx*IN_CHANNELS+ic_idx)*DATA_WIDTH +: DATA_WIDTH])
                         + $signed(i_data_bias_pw0[(oc_idx*IN_CHANNELS+ic_idx)*DATA_WIDTH +: DATA_WIDTH]);

                    acc1 = acc1
                         + $signed(i_data_feature[ic_idx*DATA_WIDTH +: DATA_WIDTH])
                         * $signed(i_data_weight_pw1[(oc_idx*IN_CHANNELS+ic_idx)*DATA_WIDTH +: DATA_WIDTH])
                         + $signed(i_data_bias_pw1[(oc_idx*IN_CHANNELS+ic_idx)*DATA_WIDTH +: DATA_WIDTH]);
                end

                mac0_lane = quantize_lane(acc0);
                mac1_lane = quantize_lane(acc1);

                if (mode_val) begin
                    sum16 = $signed(mac0_lane) + $signed(mac1_lane);
                    ad0_lane = sum16[DATA_WIDTH-1:0];
                    ad1_lane = 0;
                end else begin
                    ad0_lane = mac0_lane;
                    ad1_lane = mac1_lane;
                end

                if (first_val) begin
                    ps0_lane = ad0_lane;
                    ps1_lane = ad1_lane;
                end else begin
                    sum16 = $signed(ad0_lane) + $signed(model_fifo0[oc_idx]);
                    ps0_lane = sum16[DATA_WIDTH-1:0];

                    if (mode_val) begin
                        ps1_lane = 0;
                    end else begin
                        sum16 = $signed(ad1_lane) + $signed(model_fifo1[oc_idx]);
                        ps1_lane = sum16[DATA_WIDTH-1:0];
                    end
                end

                if (last_val) begin
                    exp_pw0_lane[oc_idx] = relu_lane(ps0_lane);
                    exp_pw1_lane[oc_idx] = relu_lane(ps1_lane);
                end else begin
                    model_fifo0[oc_idx] = ps0_lane;
                    if (!mode_val)
                        model_fifo1[oc_idx] = ps1_lane;
                end
            end

            if (last_val) begin
                for (oc_idx = 0; oc_idx < OUT_CHANNELS; oc_idx = oc_idx + 1) begin
                    model_fifo0[oc_idx] = 0;
                    model_fifo1[oc_idx] = 0;
                end
            end
        end
    endtask

    task automatic check_output_lanes;
        input [OUT_CHANNELS*DATA_WIDTH-1:0] bus_data;
        input branch_id;
        input [127:0] tag;
        reg signed [DATA_WIDTH-1:0] lane;
        reg signed [DATA_WIDTH-1:0] exp_lane;
        begin
            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                lane = $signed(bus_data[oc*DATA_WIDTH +: DATA_WIDTH]);
                exp_lane = branch_id ? exp_pw1_lane[oc] : exp_pw0_lane[oc];
                if (lane !== exp_lane) begin
                    $display("FAIL: %0s branch=%0d oc=%0d got=%0d exp=%0d time=%0t",
                             tag, branch_id, oc, lane, exp_lane, $time);
                    err_count = err_count + 1;
                end
            end
        end
    endtask

    task automatic wait_and_check_last;
        input mode_val;
        input [127:0] tag;
        integer timeout;
        integer guard_cycles;
        begin
            timeout = 0;
            while (!o_valid_pw0 && timeout < 50) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (!o_valid_pw0) begin
                $display("FAIL: %0s timeout waiting o_valid_pw0", tag);
                err_count = err_count + 1;
            end else begin
                check_output_lanes(o_data_pw0, 1'b0, tag);

                if (mode_val) begin
                    if (o_valid_pw1) begin
                        $display("FAIL: %0s unexpected o_valid_pw1 at time %0t", tag, $time);
                        err_count = err_count + 1;
                    end
                end else begin
                    if (!o_valid_pw1) begin
                        $display("FAIL: %0s missing o_valid_pw1 at time %0t", tag, $time);
                        err_count = err_count + 1;
                    end else begin
                        check_output_lanes(o_data_pw1, 1'b1, tag);
                    end
                end
            end

            for (guard_cycles = 0; guard_cycles < 3; guard_cycles = guard_cycles + 1) begin
                @(posedge clk);
                if (mode_val && o_valid_pw1) begin
                    $display("FAIL: %0s unexpected delayed o_valid_pw1 at time %0t", tag, $time);
                    err_count = err_count + 1;
                end
            end
        end
    endtask

    initial begin
        err_count = 0;
        seed = 32'h1357_2468;
        clear_inputs();
        clear_model_fifo();
        rst_n = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        for (tile_idx = 0; tile_idx < NUM_RANDOM_TILES; tile_idx = tile_idx + 1) begin
            tile_mode = rand_range(0, 1);
            tile_len  = rand_range(1, 3);
            clear_model_fifo();

            $display("RANDOM TILE %0d mode=%0d passes=%0d start_time=%0t",
                     tile_idx, tile_mode, tile_len, $time);

            for (pass_idx = 0; pass_idx < tile_len; pass_idx = pass_idx + 1) begin
                pass_first = (pass_idx == 0);
                pass_last  = (pass_idx == tile_len-1);

                clear_inputs();
                fill_random_data();
                compute_expected(tile_mode, pass_first, pass_last);
                send_input(tile_mode, pass_first, pass_last);

                if (pass_last) begin
                    wait_and_check_last(tile_mode, "RANDOM");
                end else begin
                    repeat (12) @(posedge clk);
                end
            end

            repeat (2) @(posedge clk);
        end

        if (err_count == 0)
            $display("PASS: tb_pw_top random test completed without errors");
        else
            $display("FAIL: tb_pw_top random test found %0d errors", err_count);

        repeat (10) @(posedge clk);
        $stop;
    end

endmodule
