module psum_adder_pw #(
    parameter DATA_WIDTH   = 16,
    parameter CHANNELS     = 16
)(
    input  wire                               clk,
    input  wire                               rst_n,

    input  wire                               i_valid,
    input  wire                               i_is_first,

    input  wire [CHANNELS*DATA_WIDTH-1:0]     i_data,
    input  wire [CHANNELS*DATA_WIDTH-1:0]     i_fifo_data,
    input  wire                               i_fifo_empty,

    output reg  [CHANNELS*DATA_WIDTH-1:0]     o_data
);

integer ch;
function signed [DATA_WIDTH-1:0] sat_add_lane;
    input signed [DATA_WIDTH-1:0] a;
    input signed [DATA_WIDTH-1:0] b;
    reg   signed [DATA_WIDTH-1:0] sum;
    reg overflow;
begin
    sum = a + b;

    overflow = (a[DATA_WIDTH-1] == b[DATA_WIDTH-1]) &&
               (sum[DATA_WIDTH-1] != a[DATA_WIDTH-1]);

    if (overflow) begin
        if (a[DATA_WIDTH-1] == 0)
            sat_add_lane = {1'b0, {(DATA_WIDTH-1){1'b1}}}; // max
        else
            sat_add_lane = {1'b1, {(DATA_WIDTH-1){1'b0}}}; // min
    end else begin
        sat_add_lane = sum;
    end
end
endfunction

//is_first: co cong psum khong
//is_last: cho ket qua vao o_data, neu khong thi cho vao fifo
// First-Last: 1:0 :  khong cong psum , cho vao fifo
// First-Last: 0:1 :  cong psum va bias, cho ra o_data
// First-Last: 0:0 :  cong psum, cho vao fifo
// First-Last: 1:1 :  khong cong psum ma cong bias, cho ra o_data

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_data <= 0;
    end else if (i_valid) begin
        for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
            if (i_is_first || i_fifo_empty) begin //empty khi count=0, khong con psum nao trong fifo
                o_data[ch*DATA_WIDTH +: DATA_WIDTH] <=
                    i_data[ch*DATA_WIDTH +: DATA_WIDTH];
            end else begin
                o_data[ch*DATA_WIDTH +: DATA_WIDTH] <=
                    sat_add_lane(
                        i_data[ch*DATA_WIDTH +: DATA_WIDTH],
                        i_fifo_data[ch*DATA_WIDTH +: DATA_WIDTH]
                    );
            end
        end
    end
end





endmodule
