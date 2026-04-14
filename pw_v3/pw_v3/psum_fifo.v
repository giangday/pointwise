module psum_fifo #(
    parameter MAX_PTR    = 64*64,
    parameter DATA_WIDTH = 16,
    parameter OC         = 16
)(
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire [7:0]               i_mode,

    input  wire [OC*DATA_WIDTH-1:0] i_data,
    input  wire                     wr_en,
    input  wire                     rd_en,

    output reg  [OC*DATA_WIDTH-1:0] o_data,
    output wire                     full,
    output wire                     empty
);

localparam TOTAL_WIDTH = OC * DATA_WIDTH;

// ================= BRAM =================
(* ram_style = "block" *)
reg [TOTAL_WIDTH-1:0] mem [0:MAX_PTR-1];

// ================= POINTER =================
reg [$clog2(MAX_PTR)-1:0] wr_ptr;
reg [$clog2(MAX_PTR)-1:0] rd_ptr;
reg [$clog2(MAX_PTR):0]   count;

// ================= DEPTH CONTROL =================
reg [$clog2(MAX_PTR+1)-1:0] current_max_depth;

always @(*) begin
    case (i_mode)
        8'b01000000: current_max_depth = 4096;
        8'b00100000: current_max_depth = 1024;
        8'b00010000: current_max_depth = 256;
        8'b00001000: current_max_depth = 64;
        default: current_max_depth = 4096;
    endcase
end

// ================= CONTROL =================
wire do_write = wr_en && !full;
wire do_read  = rd_en && !empty;

assign full  = (count == current_max_depth);
//empty=1 khi count = 0
assign empty = (count == 0);


// ================= MEMORY ACCESS =================
always @(posedge clk) begin
    if (do_write)
        mem[wr_ptr] <= i_data;

    if (do_read)
        o_data <= mem[rd_ptr];
end

// ================= POINTER + COUNT =================
always @(posedge clk) begin
    if (!rst_n) begin
        wr_ptr <= 0;
        rd_ptr <= 0;
        count  <= 0;
    end else begin

        if (do_write)
            wr_ptr <= (wr_ptr == current_max_depth-1) ? 0 : (wr_ptr + 1'b1);

        if (do_read)
            rd_ptr <= (rd_ptr == current_max_depth-1) ? 0 : (rd_ptr + 1'b1);

        case ({do_write, do_read})
            2'b10: count <= count + 1'b1;
            2'b01: count <= count - 1'b1;
            default: count <= count;
        endcase
    end
end

endmodule