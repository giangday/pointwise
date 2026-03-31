module single_fifo #(
    parameter DATA_WIDTH = 16*16,
    parameter MAX_PTR    = 64*64
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire [DATA_WIDTH-1:0]        i_data,
    input  wire                         wr_en,
    input  wire                         rd_en,
    input  wire [$clog2(MAX_PTR+1)-1:0] current_max_depth,
    output reg  [DATA_WIDTH-1:0]        o_data,
    output wire                         full,
    output wire                         empty
);

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:MAX_PTR-1];

    reg [$clog2(MAX_PTR)-1:0] wr_ptr;
    reg [$clog2(MAX_PTR)-1:0] rd_ptr;
    reg [$clog2(MAX_PTR):0]   count;

    wire do_write;
    wire do_read;

    assign do_write = wr_en && !full;
    assign do_read  = rd_en && !empty;

    assign full  = (count == current_max_depth);
    assign empty = (count == 0);

    always @(posedge clk) begin
        if (do_write) begin
            mem[wr_ptr] <= i_data;
        end

        if (do_read) begin
            o_data <= mem[rd_ptr];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 1'b0;
            rd_ptr <= 1'b0;
            count  <= 1'b0;
        end else begin
            if (do_write) begin
                wr_ptr <= (wr_ptr == current_max_depth-1) ? 1'b0 : (wr_ptr + 1'b1);
            end

            if (do_read) begin
                rd_ptr <= (rd_ptr == current_max_depth-1) ? 1'b0 : (rd_ptr + 1'b1);
            end

            case ({do_write, do_read})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule





module psum_single_fifo #(
    parameter MAX_PTR    = 64*64,
    parameter DATA_WIDTH = 16,
    parameter OC         = 16
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire [1:0]               mode,
    input  wire [OC*DATA_WIDTH-1:0] i_data,
    input  wire                     wr_en,
    input  wire                     rd_en,
    output wire [OC*DATA_WIDTH-1:0] o_data,
    output wire                     full,
    output wire                     empty
);

    reg [$clog2(MAX_PTR+1)-1:0] current_max_depth;

    always @(*) begin
        case (mode)
            2'b00: current_max_depth = 13'd4096;
            2'b01: current_max_depth = 13'd1024;
            2'b10: current_max_depth = 13'd256;
            2'b11: current_max_depth = 13'd64;
            default: current_max_depth = 13'd4096;
        endcase
    end

    single_fifo #(
        .DATA_WIDTH(OC * DATA_WIDTH),
        .MAX_PTR(MAX_PTR)
    ) fifo_inst (
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

endmodule
