`timescale 1ns / 1ps

module tb_pw_mac;

    localparam DATA_WIDTH   = 16;
    localparam IN_CHANNELS  = 16;
    localparam OUT_CHANNELS = 4;
    localparam PSUM_WIDTH   = (DATA_WIDTH * 2) + $clog2(IN_CHANNELS);
    localparam NUM_LEVELS   = $clog2(IN_CHANNELS) + 1;

    reg clk;
    reg rst_n;
    reg i_valid;
    reg [NUM_LEVELS-1:0] i_valid_pipe;
    reg [IN_CHANNELS*DATA_WIDTH-1:0] i_data_feature;
    reg [OUT_CHANNELS*IN_CHANNELS*DATA_WIDTH-1:0] i_data_weight;
    wire [OUT_CHANNELS*DATA_WIDTH-1:0] o_data;

    integer oc;
    integer ic;
    integer err_count;
    reg signed [DATA_WIDTH-1:0] lane;

    pw_mac #(
        .DATA_WIDTH(DATA_WIDTH),
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid),
        .i_valid_pipe(i_valid_pipe),
        .i_data_feature(i_data_feature),
        .i_data_weight(i_data_weight),
        .o_data(o_data)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            i_valid_pipe <= 0;
        else
            i_valid_pipe <= {i_valid_pipe[NUM_LEVELS-2:0], i_valid};
    end

    initial begin
        err_count = 0;
        rst_n = 1'b0;
        i_valid = 1'b0;
        i_valid_pipe = 0;
        i_data_feature = 0;
        i_data_weight = 0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        for (ic = 0; ic < IN_CHANNELS; ic = ic + 1)
            i_data_feature[ic*DATA_WIDTH +: DATA_WIDTH] = 16'sd32;

        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1)
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1)
                i_data_weight[(oc*IN_CHANNELS+ic)*DATA_WIDTH +: DATA_WIDTH] = 16'sd32;

        @(negedge clk);
        i_valid = 1'b1;
        @(negedge clk);
        i_valid = 1'b0;

        repeat (6) @(posedge clk);
        #1;

        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            lane = $signed(o_data[oc*DATA_WIDTH +: DATA_WIDTH]);
            if (lane !== 16'sd16) begin
                $display("FAIL: pw_mac lane %0d got=%0d exp=16", oc, lane);
                err_count = err_count + 1;
            end
        end

        if (err_count == 0)
            $display("PASS: tb_pw_mac");
        else
            $display("FAIL: tb_pw_mac errors=%0d", err_count);

        $finish;
    end

endmodule
