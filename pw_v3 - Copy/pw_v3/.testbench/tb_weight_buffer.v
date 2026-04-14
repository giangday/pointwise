`timescale 1ns / 1ps

module tb_weight_buffer;

    localparam CLUSTER_SIZE = 8;
    localparam NUM_CLUSTERS = 2;
    localparam INPUT_WIDTH  = 8;
    localparam CHUNK_WIDTH  = 4;

    reg clk;
    reg rst_n;
    reg i_valid;
    reg [INPUT_WIDTH-1:0] i_data;
    wire [CLUSTER_SIZE*NUM_CLUSTERS-1:0] cluster_flat;
    wire o_valid;

    integer err_count;

    weight_buffer #(
        .CLUSTER_SIZE(CLUSTER_SIZE),
        .NUM_CLUSTERS(NUM_CLUSTERS),
        .INPUT_WIDTH(INPUT_WIDTH),
        .CHUNK_WIDTH(CHUNK_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid),
        .i_data(i_data),
        .cluster_flat(cluster_flat),
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
        i_data = 0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        i_valid = 1'b1;
        i_data  = 8'hBA;

        @(negedge clk);
        i_data  = 8'hDC;

        @(posedge clk);
        #1;
        if (o_valid !== 1'b1) begin
            $display("FAIL: weight_buffer o_valid not asserted");
            err_count = err_count + 1;
        end
        if (cluster_flat[7:0] !== 8'hCA) begin
            $display("FAIL: cluster0 got=%h exp=CA", cluster_flat[7:0]);
            err_count = err_count + 1;
        end
        if (cluster_flat[15:8] !== 8'hDB) begin
            $display("FAIL: cluster1 got=%h exp=DB", cluster_flat[15:8]);
            err_count = err_count + 1;
        end

        @(negedge clk);
        i_valid = 1'b0;

        if (err_count == 0)
            $display("PASS: tb_weight_buffer");
        else
            $display("FAIL: tb_weight_buffer errors=%0d", err_count);

        $finish;
    end

endmodule
