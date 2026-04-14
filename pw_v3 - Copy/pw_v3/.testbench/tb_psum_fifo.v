`timescale 1ns / 1ps

module tb_psum_fifo;

    localparam MAX_PTR    = 64;
    localparam DATA_WIDTH = 8;
    localparam OC         = 2;
    localparam BUS_WIDTH  = OC * DATA_WIDTH;

    reg clk;
    reg rst_n;
    reg [1:0] i_mode;
    reg [BUS_WIDTH-1:0] i_data;
    reg wr_en;
    reg rd_en;
    wire [BUS_WIDTH-1:0] o_data;
    wire full;
    wire empty;

    integer err_count;

    psum_fifo #(
        .MAX_PTR(MAX_PTR),
        .DATA_WIDTH(DATA_WIDTH),
        .OC(OC)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_mode(i_mode),
        .i_data(i_data),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .o_data(o_data),
        .full(full),
        .empty(empty)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task write_word;
        input [BUS_WIDTH-1:0] din;
        begin
            @(negedge clk);
            i_data = din;
            wr_en  = 1'b1;
            rd_en  = 1'b0;
            @(negedge clk);
            wr_en  = 1'b0;
        end
    endtask

    task read_and_check;
        input [BUS_WIDTH-1:0] exp;
        begin
            @(negedge clk);
            rd_en = 1'b1;
            wr_en = 1'b0;
            @(posedge clk);
            #1;
            if (o_data !== exp) begin
                $display("FAIL: psum_fifo got=%h exp=%h", o_data, exp);
                err_count = err_count + 1;
            end
            @(negedge clk);
            rd_en = 1'b0;
        end
    endtask

    initial begin
        err_count = 0;
        rst_n = 1'b0;
        i_mode = 2'b11;
        i_data = 0;
        wr_en = 1'b0;
        rd_en = 1'b0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        if (empty !== 1'b1) begin
            $display("FAIL: psum_fifo not empty after reset");
            err_count = err_count + 1;
        end

        write_word(16'h1122);
        write_word(16'h3344);

        if (empty !== 1'b0) begin
            $display("FAIL: psum_fifo empty asserted after write");
            err_count = err_count + 1;
        end

        read_and_check(16'h1122);
        read_and_check(16'h3344);

        if (empty !== 1'b1) begin
            $display("FAIL: psum_fifo not empty after reads");
            err_count = err_count + 1;
        end

        if (err_count == 0)
            $display("PASS: tb_psum_fifo");
        else
            $display("FAIL: tb_psum_fifo errors=%0d", err_count);

        $finish;
    end

endmodule
