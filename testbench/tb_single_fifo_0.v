`timescale 1ns / 1ps

module tb_single_fifo;

    localparam DATA_WIDTH = 8;
    localparam MAX_PTR    = 16;
    localparam DEPTH      = 4;

    reg clk;
    reg rst_n;
    reg [DATA_WIDTH-1:0] i_data;
    reg wr_en;
    reg rd_en;
    reg [$clog2(MAX_PTR+1)-1:0] current_max_depth;
    wire [DATA_WIDTH-1:0] o_data;
    wire full;
    wire empty;

    integer err_count;

    single_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_PTR(MAX_PTR)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_data(i_data),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .current_max_depth(current_max_depth),
        .o_data(o_data),
        .full(full),
        .empty(empty)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task check_status;
        input exp_full;
        input exp_empty;
        input [127:0] msg;
        begin
            if (full !== exp_full || empty !== exp_empty) begin
                $display("FAIL: %0s full=%b exp_full=%b empty=%b exp_empty=%b time=%0t",
                         msg, full, exp_full, empty, exp_empty, $time);
                err_count = err_count + 1;
            end else begin
                $display("PASS: %0s", msg);
            end
        end
    endtask

    task write_one;
        input [DATA_WIDTH-1:0] data;
        begin
            @(negedge clk);
            i_data = data;
            wr_en  = 1'b1;
            rd_en  = 1'b0;
            @(negedge clk);
            wr_en  = 1'b0;
        end
    endtask

    task read_one;
        input [DATA_WIDTH-1:0] exp_data;
        input [127:0] msg;
        begin
            @(negedge clk);
            rd_en = 1'b1;
            wr_en = 1'b0;
            @(posedge clk);
            #1;
            if (o_data !== exp_data) begin
                $display("FAIL: %0s got=%0d exp=%0d time=%0t", msg, o_data, exp_data, $time);
                err_count = err_count + 1;
            end else begin
                $display("PASS: %0s data=%0d", msg, o_data);
            end
            @(negedge clk);
            rd_en = 1'b0;
        end
    endtask

    initial begin
        rst_n = 1'b0;
        i_data = '0;
        wr_en = 1'b0;
        rd_en = 1'b0;
        current_max_depth = DEPTH;
        err_count = 0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        check_status(1'b0, 1'b1, "reset state");

        write_one(8'd11);
        check_status(1'b0, 1'b0, "write 11");

        write_one(8'd22);
        check_status(1'b0, 1'b0, "write 22");

        write_one(8'd33);
        check_status(1'b0, 1'b0, "write 33");

        write_one(8'd44);
        check_status(1'b1, 1'b0, "write 44, fifo full");

        // write when full: must be ignored
        write_one(8'd55);
        check_status(1'b1, 1'b0, "write when full ignored");

        read_one(8'd11, "read first");
        check_status(1'b0, 1'b0, "after read first");

        read_one(8'd22, "read second");
        check_status(1'b0, 1'b0, "after read second");

        write_one(8'd66);
        check_status(1'b0, 1'b0, "write 66 after wrap");

        write_one(8'd77);
        check_status(1'b1, 1'b0, "write 77, fifo full again");

        read_one(8'd33, "read third");
        read_one(8'd44, "read fourth");
        read_one(8'd66, "read fifth");
        read_one(8'd77, "read sixth");
        check_status(1'b0, 1'b1, "fifo empty again");

        // read when empty: must be ignored
        @(negedge clk);
        rd_en = 1'b1;
        @(negedge clk);
        rd_en = 1'b0;
        check_status(1'b0, 1'b1, "read when empty ignored");

        if (err_count == 0)
            $display("PASS: tb_single_fifo completed without errors");
        else
            $display("FAIL: tb_single_fifo found %0d errors", err_count);

        $finish;
    end

endmodule
