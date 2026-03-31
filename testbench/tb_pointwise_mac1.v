`timescale 1ns / 1ps

module tb_pointwise_mac1;

    localparam DATA_WIDTH   = 16;
    localparam IN_CHANNELS  = 16;
    localparam OUT_CHANNELS = 16;
    localparam PSUM_WIDTH   = (DATA_WIDTH * 2) + $clog2(IN_CHANNELS);

    reg clk;
    reg rst_n;
    reg i_valid;
    reg [IN_CHANNELS*DATA_WIDTH-1:0] i_data_feature;
    reg [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight;
    wire [OUT_CHANNELS*PSUM_WIDTH-1:0] o_data_psum;
    wire o_valid;

    integer oc;
    integer ic;
    integer err_count;

    reg signed [PSUM_WIDTH-1:0] expected_case0;
    reg signed [PSUM_WIDTH-1:0] expected_case1;
    reg signed [PSUM_WIDTH-1:0] expected_case2;
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

    task automatic clear_inputs;
        begin
            i_data_feature = 1'b0;
            i_data_weight  = 1'b0;
        end
    endtask

    task automatic load_case0;
        begin
            // feature = all 1
            // weight  = all 2
            // expected = 16 * (1*2) = 32
            clear_inputs();
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1)
                i_data_feature[ic*DATA_WIDTH +: DATA_WIDTH] = 16'sd1;

            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1)
                for (ic = 0; ic < IN_CHANNELS; ic = ic + 1)
                    i_data_weight[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = 16'sd2;
        end
    endtask

    task automatic load_case1;
        begin
            // feature = all 2
            // weight  = all 3
            // expected = 16 * (2*3) = 96
            clear_inputs();
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1)
                i_data_feature[ic*DATA_WIDTH +: DATA_WIDTH] = 16'sd2;

            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1)
                for (ic = 0; ic < IN_CHANNELS; ic = ic + 1)
                    i_data_weight[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = 16'sd3;
        end
    endtask

    task automatic load_case2;
        begin
            // feature = all -1
            // weight  = all 4
            // expected = 16 * (-1*4) = -64
            clear_inputs();
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1)
                i_data_feature[ic*DATA_WIDTH +: DATA_WIDTH] = -16'sd1;

            for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1)
                for (ic = 0; ic < IN_CHANNELS; ic = ic + 1)
                    i_data_weight[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = 16'sd4;
        end
    endtask

    task automatic send_one_pulse;
        begin
            i_valid = 1'b1;
            @(posedge clk);
            i_valid = 1'b0;
        end
    endtask

    task automatic check_all_channels;
        input signed [PSUM_WIDTH-1:0] expected_val;
        input [127:0] case_name;
        begin
            if (!o_valid) begin
                $display("ERROR: %0s expected o_valid=1 at time %0t", case_name, $time);
                err_count = err_count + 1;
            end else begin
                for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
                    dut_lane = $signed(o_data_psum[oc*PSUM_WIDTH +: PSUM_WIDTH]);
                    if (dut_lane !== expected_val) begin
                        $display("ERROR: %0s oc=%0d got=%0d exp=%0d time=%0t",
                                 case_name, oc, dut_lane, expected_val, $time);
                        err_count = err_count + 1;
                    end
                end
            end
        end
    endtask

    initial begin
        i_valid         = 1'b0;
        i_data_feature  = 1'b0;
        i_data_weight   = 1'b0;
        err_count       = 0;

        expected_case0  = 36'sd32;
        expected_case1  = 36'sd96;
        expected_case2  = -36'sd64;

        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        load_case0();
        send_one_pulse();

        repeat (5) @(posedge clk);
        check_all_channels(expected_case0, "CASE0");

        load_case1();
        send_one_pulse();

        repeat (5) @(posedge clk);
        check_all_channels(expected_case1, "CASE1");

        load_case2();
        send_one_pulse();

        repeat (5) @(posedge clk);
        check_all_channels(expected_case2, "CASE2");

        if (err_count == 0)
            $display("PASS: all manual test vectors matched");
        else
            $display("FAIL: total mismatches = %0d", err_count);

        $finish;
    end

endmodule
