`timescale 1ns / 1ps

module tb_psum_single_fifo;

    localparam MAX_PTR    = 16;
    localparam DATA_WIDTH = 8;
    localparam OC         = 4;
    localparam BUS_WIDTH  = OC * DATA_WIDTH;

    reg clk;
    reg rst_n;
    reg [1:0] mode;
    reg [BUS_WIDTH-1:0] i_data;
    reg wr_en;
    reg rd_en;
    wire [BUS_WIDTH-1:0] o_data;
    wire full;
    wire empty;

    integer err_count;

    psum_single_fifo #(
        .MAX_PTR(MAX_PTR),
        .DATA_WIDTH(DATA_WIDTH),
        .OC(OC)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode(mode),
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

    task write_one;
        input [BUS_WIDTH-1:0] data_in;
        begin
            @(negedge clk);
            i_data = data_in;
            wr_en  = 1'b1;
            rd_en  = 1'b0;
            @(negedge clk);
            wr_en  = 1'b0;
        end
    endtask

    task read_one;
        input [BUS_WIDTH-1:0] exp_data;
        input [127:0] msg;
        begin
            @(negedge clk);
            rd_en = 1'b1;
            wr_en = 1'b0;
            @(posedge clk);
            #1;
            if (o_data !== exp_data) begin
                $display("FAIL: %0s got=%h exp=%h time=%0t", msg, o_data, exp_data, $time);
                err_count = err_count + 1;
            end else begin
                $display("PASS: %0s data=%h", msg, o_data);
            end
            @(negedge clk);
            rd_en = 1'b0;
        end
    endtask

    task check_flags;
        input exp_full;
        input exp_empty;
        input [127:0] msg;
        begin
            if ((full !== exp_full) || (empty !== exp_empty)) begin
                $display("FAIL: %0s full=%b exp_full=%b empty=%b exp_empty=%b time=%0t",
                         msg, full, exp_full, empty, exp_empty, $time);
                err_count = err_count + 1;
            end else begin
                $display("PASS: %0s full=%b empty=%b", msg, full, empty);
            end
        end
    endtask

    initial begin
        rst_n     = 1'b0;
        mode      = 2'b10;
        i_data    = '0;
        wr_en     = 1'b0;
        rd_en     = 1'b0;
        err_count = 0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // =========================================================
        // MODE = 2'b11 -> depth = 2
        // =========================================================
        mode = 2'b11;
        @(posedge clk);

        check_flags(1'b0, 1'b1, "mode=11 reset state");

        write_one(32'h11_22_33_44);
        check_flags(1'b0, 1'b0, "mode=11 write first");

        write_one(32'h55_66_77_88);
        check_flags(1'b1, 1'b0, "mode=11 write second full");

        write_one(32'hAA_BB_CC_DD);
        check_flags(1'b1, 1'b0, "mode=11 write when full ignored");

        read_one(32'h11_22_33_44, "mode=11 read first");
        check_flags(1'b0, 1'b0, "mode=11 after first read");

        read_one(32'h55_66_77_88, "mode=11 read second");
        check_flags(1'b0, 1'b1, "mode=11 empty again");

        // =========================================================
        // RESET before next mode
        // =========================================================
        @(negedge clk);
        rst_n = 1'b0;
        @(negedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // =========================================================
        // MODE = 2'b10 -> depth = 4
        // =========================================================
        mode = 2'b10;
        @(posedge clk);

        write_one(32'h01_02_03_04);
        write_one(32'h05_06_07_08);
        write_one(32'h09_0A_0B_0C);
        write_one(32'h0D_0E_0F_10);
        check_flags(1'b1, 1'b0, "mode=10 full at depth 4");

        read_one(32'h01_02_03_04, "mode=10 read #1");
        read_one(32'h05_06_07_08, "mode=10 read #2");
        read_one(32'h09_0A_0B_0C, "mode=10 read #3");
        read_one(32'h0D_0E_0F_10, "mode=10 read #4");
        check_flags(1'b0, 1'b1, "mode=10 empty after 4 reads");

        // =========================================================
        // RESET before next mode
        // =========================================================
        @(negedge clk);
        rst_n = 1'b0;
        @(negedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // =========================================================
        // MODE = 2'b01 -> depth = 8
        // =========================================================
        mode = 2'b01;
        @(posedge clk);

        write_one(32'h10_00_00_01);
        write_one(32'h20_00_00_02);
        write_one(32'h30_00_00_03);
        write_one(32'h40_00_00_04);
        write_one(32'h50_00_00_05);
        write_one(32'h60_00_00_06);
        write_one(32'h70_00_00_07);
        write_one(32'h80_00_00_08);
        check_flags(1'b1, 1'b0, "mode=01 full at depth 8");

        read_one(32'h10_00_00_01, "mode=01 read #1");
        read_one(32'h20_00_00_02, "mode=01 read #2");
        read_one(32'h30_00_00_03, "mode=01 read #3");
        read_one(32'h40_00_00_04, "mode=01 read #4");
        read_one(32'h50_00_00_05, "mode=01 read #5");
        read_one(32'h60_00_00_06, "mode=01 read #6");
        read_one(32'h70_00_00_07, "mode=01 read #7");
        read_one(32'h80_00_00_08, "mode=01 read #8");
        check_flags(1'b0, 1'b1, "mode=01 empty after 8 reads");

        // =========================================================
        // RESET before next mode
        // =========================================================
        @(negedge clk);
        rst_n = 1'b0;
        @(negedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // =========================================================
        // MODE = 2'b00 -> depth = 16
        // =========================================================
        mode = 2'b00;
        @(posedge clk);

        write_one(32'hA0_00_00_01);
        write_one(32'hA1_00_00_02);
        write_one(32'hA2_00_00_03);
        write_one(32'hA3_00_00_04);
        write_one(32'hA4_00_00_05);
        write_one(32'hA5_00_00_06);
        write_one(32'hA6_00_00_07);
        write_one(32'hA7_00_00_08);
        write_one(32'hA8_00_00_09);
        write_one(32'hA9_00_00_0A);
        write_one(32'hAA_00_00_0B);
        write_one(32'hAB_00_00_0C);
        write_one(32'hAC_00_00_0D);
        write_one(32'hAD_00_00_0E);
        write_one(32'hAE_00_00_0F);
        write_one(32'hAF_00_00_10);
        check_flags(1'b1, 1'b0, "mode=00 full at depth 16");

        read_one(32'hA0_00_00_01, "mode=00 read #1");
        read_one(32'hA1_00_00_02, "mode=00 read #2");
        read_one(32'hA2_00_00_03, "mode=00 read #3");
        read_one(32'hA3_00_00_04, "mode=00 read #4");
        read_one(32'hA4_00_00_05, "mode=00 read #5");
        read_one(32'hA5_00_00_06, "mode=00 read #6");
        read_one(32'hA6_00_00_07, "mode=00 read #7");
        read_one(32'hA7_00_00_08, "mode=00 read #8");
        read_one(32'hA8_00_00_09, "mode=00 read #9");
        read_one(32'hA9_00_00_0A, "mode=00 read #10");
        read_one(32'hAA_00_00_0B, "mode=00 read #11");
        read_one(32'hAB_00_00_0C, "mode=00 read #12");
        read_one(32'hAC_00_00_0D, "mode=00 read #13");
        read_one(32'hAD_00_00_0E, "mode=00 read #14");
        read_one(32'hAE_00_00_0F, "mode=00 read #15");
        read_one(32'hAF_00_00_10, "mode=00 read #16");
        check_flags(1'b0, 1'b1, "mode=00 empty after 16 reads");

        if (err_count == 0)
            $display("PASS: tb_psum_single_fifo completed without errors");
        else
            $display("FAIL: tb_psum_single_fifo found %0d errors", err_count);

        $finish;
    end

endmodule
