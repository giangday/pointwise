`timescale 1ns / 1ps

module tb_pw0_pw1_adder;

    localparam DATA_WIDTH = 16;
    localparam CHANNELS   = 4;

    reg clk;
    reg rst_n;
    reg i_valid;
    reg i_mode;
    reg [CHANNELS*DATA_WIDTH-1:0] i_data_pw0;
    reg [CHANNELS*DATA_WIDTH-1:0] i_data_pw1;
    wire [CHANNELS*DATA_WIDTH-1:0] o_data_pw0;
    wire [CHANNELS*DATA_WIDTH-1:0] o_data_pw1;

    integer err_count;
    integer ch;
    reg signed [DATA_WIDTH-1:0] lane0;
    reg signed [DATA_WIDTH-1:0] lane1;

    pw0_pw1_adder #(
        .DATA_WIDTH(DATA_WIDTH),
        .CHANNELS(CHANNELS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid),
        .i_mode(i_mode),
        .i_data_pw0(i_data_pw0),
        .i_data_pw1(i_data_pw1),
        .o_data_pw0(o_data_pw0),
        .o_data_pw1(o_data_pw1)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        err_count = 0;
        rst_n = 1'b0;
        i_valid = 1'b0;
        i_mode = 1'b0;
        i_data_pw0 = 0;
        i_data_pw1 = 0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        i_data_pw0 = {16'sd4,16'sd3,16'sd2,16'sd1};
        i_data_pw1 = {16'sd8,16'sd7,16'sd6,16'sd5};
        @(negedge clk);
        i_mode = 1'b0;
        i_valid = 1'b1;
        @(posedge clk);
        #1;
        for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
            if ($signed(o_data_pw0[ch*DATA_WIDTH +: DATA_WIDTH]) !== $signed(i_data_pw0[ch*DATA_WIDTH +: DATA_WIDTH])) err_count = err_count + 1;
            if ($signed(o_data_pw1[ch*DATA_WIDTH +: DATA_WIDTH]) !== $signed(i_data_pw1[ch*DATA_WIDTH +: DATA_WIDTH])) err_count = err_count + 1;
        end
        @(negedge clk);
        i_valid = 1'b0;

        i_data_pw0 = {16'sd1,16'sd20000,16'sd10,16'sd30000};
        i_data_pw1 = {16'sd2,16'sd20000,-16'sd5,16'sd10000};
        @(negedge clk);
        i_mode = 1'b1;
        i_valid = 1'b1;
        @(posedge clk);
        #1;

        lane0 = $signed(o_data_pw0[0*DATA_WIDTH +: DATA_WIDTH]);
        lane1 = $signed(o_data_pw1[0*DATA_WIDTH +: DATA_WIDTH]);
        if (lane0 !== 16'sd32767 || lane1 !== 16'sd0) err_count = err_count + 1;

        lane0 = $signed(o_data_pw0[1*DATA_WIDTH +: DATA_WIDTH]);
        lane1 = $signed(o_data_pw1[1*DATA_WIDTH +: DATA_WIDTH]);
        if (lane0 !== 16'sd5 || lane1 !== 16'sd0) err_count = err_count + 1;

        lane0 = $signed(o_data_pw0[2*DATA_WIDTH +: DATA_WIDTH]);
        lane1 = $signed(o_data_pw1[2*DATA_WIDTH +: DATA_WIDTH]);
        if (lane0 !== 16'sd32767 || lane1 !== 16'sd0) err_count = err_count + 1;

        lane0 = $signed(o_data_pw0[3*DATA_WIDTH +: DATA_WIDTH]);
        lane1 = $signed(o_data_pw1[3*DATA_WIDTH +: DATA_WIDTH]);
        if (lane0 !== 16'sd3 || lane1 !== 16'sd0) err_count = err_count + 1;

        @(negedge clk);
        i_valid = 1'b0;

        if (err_count == 0)
            $display("PASS: tb_pw0_pw1_adder");
        else
            $display("FAIL: tb_pw0_pw1_adder errors=%0d", err_count);

        $finish;
    end

endmodule
