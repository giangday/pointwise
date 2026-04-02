module relu_output #(
    parameter DATA_WIDTH = 16,
    parameter CHANNELS   = 16
)(
    input  wire                              clk,
    input  wire                              rst_n,

    input  wire                              i_valid,
    input  wire                              i_is_last,
    // input  wire                              i_is_relu,

    input  wire [CHANNELS*DATA_WIDTH-1:0]    i_data,

    // ===== FIFO =====
    output wire                              o_fifo_wr_en,
    output wire [CHANNELS*DATA_WIDTH-1:0]    o_fifo_data,

    // ===== OUTPUT =====
    output reg  [CHANNELS*DATA_WIDTH-1:0]    o_data,
    output reg                               o_valid
);

// =====================================================
//  Control MUST align with data (same stage)
// =====================================================
wire do_fifo   = i_valid && !i_is_last;
wire do_output = i_valid &&  i_is_last;

// =====================================================
// FIFO write (same cycle với data)
// =====================================================
assign o_fifo_wr_en = do_fifo;
assign o_fifo_data  = i_data;

// =====================================================
// ReLU combinational
// =====================================================
wire [CHANNELS*DATA_WIDTH-1:0] relu_out;

genvar ch;
generate
    for (ch = 0; ch < CHANNELS; ch = ch + 1) begin : GEN_RELU
        wire signed [DATA_WIDTH-1:0] lane;
        assign lane = i_data[ch*DATA_WIDTH +: DATA_WIDTH];

        assign relu_out[ch*DATA_WIDTH +: DATA_WIDTH] =
            lane[DATA_WIDTH-1] ? {DATA_WIDTH{1'b0}} : lane;
    end
endgenerate

// =====================================================
// Output register (final stage)
// =====================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_data  <= 0;
        o_valid <= 1'b0;
    end else begin
        o_valid <= do_output;

        if (do_output) begin
            o_data <= relu_out;
        end
    end
end

endmodule
