`timescale 1ns / 1ps

module tb_psum_adder_pw;

    localparam DATA_WIDTH = 16;
    localparam CHANNELS   = 4;

    reg clk;
    reg rst_n;
    reg i_valid;
    reg i_is_first;
    reg [CHANNELS*DATA_WIDTH-1:0] i_data;
    reg [CHANNELS*DATA_WIDTH-1:0] i_fifo_data;
    reg i_fifo_empty;
    wire [CHANNELS*DATA_WIDTH-1:0] o_data;

    integer err_count;
    integer ch;
    reg signed [DATA_WIDTH-1:0] lane;

    psum_adder_pw #(
        .DATA_WIDTH(DATA_WIDTH),
        .CHANNELS(CHANNELS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid),
        .i_is_first(i_is_first),
        .i_data(i_data),
        .i_fifo_data(i_fifo_data),
        .i_fifo_empty(i_fifo_empty),
        .o_data(o_data)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        err_count = 0;
        rst_n = 1'b0;
        i_valid = 1'b0;
        i_is_first = 1'b0;
        i_data = 0;
        i_fifo_data = 0;
        i_fifo_empty = 1'b1;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        i_data = {16'sd4,16'sd3,16'sd2,16'sd1};
        i_fifo_data = {16'sd9,16'sd9,16'sd9,16'sd9};
        i_fifo_empty = 1'b1;
        @(negedge clk);
        i_is_first = 1'b1;
        i_valid = 1'b1;
        @(posedge clk);
        #1;
        for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
            if ($signed(o_data[ch*DATA_WIDTH +: DATA_WIDTH]) !== $signed(i_data[ch*DATA_WIDTH +: DATA_WIDTH])) err_count = err_count + 1;
        end
        @(negedge clk);
        i_valid = 1'b0;

        i_data = {16'sd30000,16'sd200,16'sd100,-16'sd30000};
        i_fifo_data = {16'sd10000,-16'sd50,16'sd50,-16'sd10000};
        i_fifo_empty = 1'b0;
        @(negedge clk);
        i_is_first = 1'b0;
        i_valid = 1'b1;
        @(posedge clk);
        #1;

        if ($signed(o_data[0*DATA_WIDTH +: DATA_WIDTH]) !== -16'sd32768) err_count = err_count + 1;
        if ($signed(o_data[1*DATA_WIDTH +: DATA_WIDTH]) !== 16'sd150) err_count = err_count + 1;
        if ($signed(o_data[2*DATA_WIDTH +: DATA_WIDTH]) !== 16'sd150) err_count = err_count + 1;
        if ($signed(o_data[3*DATA_WIDTH +: DATA_WIDTH]) !== 16'sd32767) err_count = err_count + 1;

        @(negedge clk);
        i_valid = 1'b0;

        if (err_count == 0)
            $display("PASS: tb_psum_adder_pw");
        else
            $display("FAIL: tb_psum_adder_pw errors=%0d", err_count);

        $finish;
    end

endmodule
