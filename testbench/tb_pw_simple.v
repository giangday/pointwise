`timescale 1ns / 1ps

module tb_pw_top;

    localparam DATA_WIDTH   = 16;
    localparam IN_CHANNELS  = 16;
    localparam OUT_CHANNELS = 16;
    localparam FIFO_MAX_PTR = 64*64;

    reg clk;
    reg rst_n;
    reg i_valid;
    reg i_mode;
    reg i_is_first;
    reg i_is_last;
    // reg i_is_relu;
    reg [1:0] i_fifo_mode;

    reg [IN_CHANNELS*DATA_WIDTH-1:0] i_data_feature;
    reg [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight_pw0;
    reg [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight_pw1;
    reg [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_bias_pw0;
    reg [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_bias_pw1;

    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_data_pw0;
    wire o_valid_pw0;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_data_pw1;
    wire o_valid_pw1;

    integer oc;
    integer ic;
    integer err_count;
    reg signed [DATA_WIDTH-1:0] lane_val;

    pw_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS),
        .FIFO_MAX_PTR(FIFO_MAX_PTR)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid),
        .i_mode(i_mode),
        .i_is_first(i_is_first),
        .i_is_last(i_is_last),
        // .i_is_relu(i_is_relu),
        .i_fifo_mode(i_fifo_mode),
        .i_data_feature(i_data_feature),
        .i_data_weight_pw0(i_data_weight_pw0),
        .i_data_weight_pw1(i_data_weight_pw1),
        .i_data_bias_pw0(i_data_bias_pw0),
        .i_data_bias_pw1(i_data_bias_pw1),
        .o_data_pw0(o_data_pw0),
        .o_valid_pw0(o_valid_pw0),
        .o_data_pw1(o_data_pw1),
        .o_valid_pw1(o_valid_pw1)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n           = 1'b0;
        i_valid         = 1'b0;
        i_mode          = 1'b0;
        i_is_first      = 1'b0;
        i_is_last       = 1'b0;
        i_is_relu       = 1'b0;
        i_fifo_mode     = 2'b11;

        i_data_feature  = '0;
        i_data_weight_pw0 = '0;
        i_data_weight_pw1 = '0;
        i_data_bias_pw0   = '0;
        i_data_bias_pw1   = '0;

        err_count = 0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // feature = 0
        for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
            i_data_feature[ic*DATA_WIDTH +: DATA_WIDTH] = 16'sd0;
        end

        // weight = 0, bias constant
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                i_data_weight_pw0[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = 16'sd0;
                i_data_weight_pw1[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = 16'sd0;
                i_data_bias_pw0[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH]   = 16'sd2048;
                i_data_bias_pw1[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH]   = 16'sd3072;
            end
        end

        // send 1 sample
        @(negedge clk);
        i_mode     = 1'b0;
        i_is_first = 1'b1;
        i_is_last  = 1'b1;
        i_is_relu  = 1'b0;
        i_valid    = 1'b1;

        @(negedge clk);
        i_valid    = 1'b0;

        // wait result pw0
        wait(o_valid_pw0 == 1'b1);
        #1;
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            lane_val = $signed(o_data_pw0[oc*DATA_WIDTH +: DATA_WIDTH]);
            if (lane_val !== 16'sd32) begin
                $display("FAIL: pw0 oc=%0d got=%0d exp=32 time=%0t", oc, lane_val, $time);
                err_count = err_count + 1;
            end
        end
        $display("CHECK: pw0 done");

        // wait result pw1
        wait(o_valid_pw1 == 1'b1);
        #1;
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            lane_val = $signed(o_data_pw1[oc*DATA_WIDTH +: DATA_WIDTH]);
            if (lane_val !== 16'sd48) begin
                $display("FAIL: pw1 oc=%0d got=%0d exp=48 time=%0t", oc, lane_val, $time);
                err_count = err_count + 1;
            end
        end
        $display("CHECK: pw1 done");

        if (err_count == 0)
            $display("PASS: simple tb_pw_top passed");
        else
            $display("FAIL: simple tb_pw_top has %0d errors", err_count);

        $finish;
    end

endmodule
