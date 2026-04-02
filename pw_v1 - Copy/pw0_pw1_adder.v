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

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_data_pw0 <= 0;
        o_data_pw1 <= 0;
    end else begin
        if (i_valid) begin
            for (i = 0; i < CHANNELS; i = i + 1) begin
                if (i_mode) begin
                    o_data_pw0[i*DATA_WIDTH +: DATA_WIDTH] <=
                        $signed(i_data_pw0[i*DATA_WIDTH +: DATA_WIDTH]) +
                        $signed(i_data_pw1[i*DATA_WIDTH +: DATA_WIDTH]);
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


