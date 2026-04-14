module pw0_pw1_adder #(
    parameter DATA_WIDTH = 16,
    parameter CHANNELS   = 16
)(
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire                           i_valid,
    input  wire                           i_mode,
    input  wire [CHANNELS*DATA_WIDTH-1:0] i_data_pw0,
    input  wire [CHANNELS*DATA_WIDTH-1:0] i_data_pw1,
    output reg  [CHANNELS*DATA_WIDTH-1:0] o_data_pw0,
    output reg  [CHANNELS*DATA_WIDTH-1:0] o_data_pw1
);

integer i;


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


always @(posedge clk) begin
    if (!rst_n) begin
        o_data_pw0 <= 0;
        o_data_pw1 <= 0;
    end else begin
        if (i_valid) begin
            for (i = 0; i < CHANNELS; i = i + 1) begin
                if (i_mode) begin
                    o_data_pw0[i*DATA_WIDTH +: DATA_WIDTH] <=
                        sat_add_lane(
                            i_data_pw0[i*DATA_WIDTH +: DATA_WIDTH],
                            i_data_pw1[i*DATA_WIDTH +: DATA_WIDTH]
                        );
                    o_data_pw1[i*DATA_WIDTH +: DATA_WIDTH] <= 0;
                end else begin
                    o_data_pw0[i*DATA_WIDTH +: DATA_WIDTH] <=
                        i_data_pw0[i*DATA_WIDTH +: DATA_WIDTH];

                    o_data_pw1[i*DATA_WIDTH +: DATA_WIDTH] <=
                        i_data_pw1[i*DATA_WIDTH +: DATA_WIDTH];
                end
            end
        end
    end
end

endmodule

