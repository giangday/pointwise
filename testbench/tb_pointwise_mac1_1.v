`timescale 1ns / 1ps

module tb_pointwise_mac1_1;

    localparam DATA_WIDTH   = 16;
    localparam IN_CHANNELS  = 16;
    localparam OUT_CHANNELS = 16;
    localparam PSUM_WIDTH   = (DATA_WIDTH * 2) + $clog2(IN_CHANNELS);
    localparam NUM_TESTS    = 100;

    reg clk;
    reg rst_n;
    reg i_valid;
    reg [IN_CHANNELS*DATA_WIDTH-1:0] i_data_feature;
    reg [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight;
    wire [OUT_CHANNELS*PSUM_WIDTH-1:0] o_data_psum;
    wire o_valid;

    reg signed [DATA_WIDTH-1:0] feature_vec [0:IN_CHANNELS-1];
    reg signed [DATA_WIDTH-1:0] weight_mat  [0:OUT_CHANNELS-1][0:IN_CHANNELS-1];
    reg signed [PSUM_WIDTH-1:0] expected_q  [0:NUM_TESTS-1][0:OUT_CHANNELS-1];

    integer test_idx;
    integer valid_idx;
    integer oc;
    integer ic;
    integer err_count;
    integer seed;

    reg signed [PSUM_WIDTH-1:0] sum_ref;
    reg signed [PSUM_WIDTH-1:0] dut_lane;

    pointwise_mac1 #(
        .DATA_WIDTH(DATA_WIDTH),
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS),
        .PSUM_WIDTH(PSUM_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid),
        .i_data_feature(i_data_feature),
        .i_data_weight(i_data_weight),
        .o_data_psum(o_data_psum),
        .o_valid(o_valid)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic gen_case;
        input integer case_id;
        begin
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                feature_vec[ic] = $random(seed);
                i_data_feature[ic*DATA_WIDTH +: DATA_WIDTH] = feature_vec[ic];
            end

            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                sum_ref = 1'b0;
                for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                    weight_mat[oc][ic] = $random(seed);
                    i_data_weight[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = weight_mat[oc][ic];
                    sum_ref = sum_ref + feature_vec[ic] * weight_mat[oc][ic];
                end
                expected_q[case_id][oc] = sum_ref;
            end
        end
    endtask

    task automatic check_case;
    input integer case_id;
    reg case_has_error;
    begin
        case_has_error = 1'b0;

        if (!o_valid) begin
            $display("FAIL: case %0d expected o_valid=1 at time %0t", case_id, $time);
            err_count = err_count + 1;
            case_has_error = 1'b1;
        end else begin
            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                dut_lane = $signed(o_data_psum[oc*PSUM_WIDTH +: PSUM_WIDTH]);
                if (dut_lane !== expected_q[case_id][oc]) begin
                    $display("FAIL: case=%0d oc=%0d got=%0d exp=%0d time=%0t",
                             case_id, oc, dut_lane, expected_q[case_id][oc], $time);
                    err_count = err_count + 1;
                    case_has_error = 1'b1;
                end
            end
        end

        if (!case_has_error) begin
            $display("PASS: case %0d at time %0t", case_id, $time);
        end
    end
endtask


    initial begin
    rst_n          = 1'b0;
    i_valid        = 1'b0;
    i_data_feature = 0;
    i_data_weight  = 0;
    err_count      = 0;
    valid_idx      = 0;
    seed           = 32'h1234_5678;

    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    for (test_idx = 0; test_idx < NUM_TESTS; test_idx = test_idx + 1) begin
        $display("Running case %0d", test_idx);

        gen_case(test_idx);
        i_valid = 1'b1;
        @(posedge clk);

        if (o_valid) begin
            check_case(valid_idx);
            valid_idx = valid_idx + 1;
        end

        i_valid = 1'b0;
        @(posedge clk);

        if (o_valid) begin
            check_case(valid_idx);
            valid_idx = valid_idx + 1;
        end
    end

    while (valid_idx < NUM_TESTS) begin
        @(posedge clk);
        if (o_valid) begin
            check_case(valid_idx);
            valid_idx = valid_idx + 1;
        end
    end

    if (err_count == 0)
        $display("PASS: pointwise_mac1 passed %0d tests", NUM_TESTS);
    else
        $display("FAIL: pointwise_mac1 has %0d mismatches", err_count);

    $finish;
end


endmodule
