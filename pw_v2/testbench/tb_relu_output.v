`timescale 1ns / 1ps

module tb_relu_output;

    localparam DATA_WIDTH = 16;
    localparam CHANNELS   = 4;

    reg clk;
    reg rst_n;
    reg i_valid;
    reg i_is_last;
    reg [CHANNELS*DATA_WIDTH-1:0] i_data;
    reg [CHANNELS*DATA_WIDTH-1:0] i_bias;
    wire o_fifo_wr_en;
    wire [CHANNELS*DATA_WIDTH-1:0] o_fifo_data;
    wire [CHANNELS*DATA_WIDTH-1:0] o_data;
    wire o_valid;

    integer err_count;

    relu_output #(
        .DATA_WIDTH(DATA_WIDTH),
        .CHANNELS(CHANNELS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid),
        .i_is_last(i_is_last),
        .i_data(i_data),
        .i_bias(i_bias),
        .o_fifo_wr_en(o_fifo_wr_en),
        .o_fifo_data(o_fifo_data),
        .o_data(o_data),
        .o_valid(o_valid)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        err_count = 0;
        rst_n = 1'b0;
        i_valid = 1'b0;
        i_is_last = 1'b0;
        i_data = 0;
        i_bias = 0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        i_data = {16'sd4,16'sd3,16'sd2,16'sd1};
        i_bias = 0;
        @(negedge clk);
        i_valid = 1'b1;
        i_is_last = 1'b0;
        #1;
        if (o_fifo_wr_en !== 1'b1 || o_fifo_data !== i_data) begin
            $display("FAIL: relu_output fifo path");
            err_count = err_count + 1;
        end
        @(negedge clk);
        i_valid = 1'b0;

        i_data = {16'sd1000,-16'sd32000,-16'sd100,16'sd1000};
        i_bias = {16'sd1000,-16'sd1000,16'sd50,16'sd24};
        @(negedge clk);
        i_valid = 1'b1;
        i_is_last = 1'b1;
        @(posedge clk);
        #1;
        if (o_valid !== 1'b1) begin
            $display("FAIL: relu_output o_valid");
            err_count = err_count + 1;
        end
        if ($signed(o_data[0*DATA_WIDTH +: DATA_WIDTH]) !== 16'sd1024) err_count = err_count + 1;
        if ($signed(o_data[1*DATA_WIDTH +: DATA_WIDTH]) !== 16'sd0) err_count = err_count + 1;
        if ($signed(o_data[2*DATA_WIDTH +: DATA_WIDTH]) !== 16'sd0) err_count = err_count + 1;
        if ($signed(o_data[3*DATA_WIDTH +: DATA_WIDTH]) !== 16'sd2000) err_count = err_count + 1;
        @(negedge clk);
        i_valid = 1'b0;

        if (err_count == 0)
            $display("PASS: tb_relu_output");
        else
            $display("FAIL: tb_relu_output errors=%0d", err_count);

        $finish;
    end

endmodule
