module weight_buffer #(
    parameter DATA_WIDTH              = 16,
    parameter FEATURE_IN_PARALLEL     = 16,
    parameter OC_PARALLEL_1_CLOCK     = 16,
    parameter WEIGHT_LOAD_1_CLOCK     = 4,
    parameter NUM_KERNEL_LOAD_1_CLOCK = 8,
    parameter TOTAL_WEIGHT_IN_WIDTH   = 512
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [TOTAL_WEIGHT_IN_WIDTH-1:0] i_data_weight,
    input  wire i_sig_wr_en,
    input  wire [2:0] i_sig_load_step,
    input  wire i_sig_bank_sel,
    output reg  [(FEATURE_IN_PARALLEL*OC_PARALLEL_1_CLOCK*DATA_WIDTH)-1:0] o_data_weight_to_mac,
    output wire o_sig_weight_load_done
);

localparam TOTAL_WEIGHT_OUT_WIDTH = FEATURE_IN_PARALLEL * OC_PARALLEL_1_CLOCK * DATA_WIDTH;

reg [DATA_WIDTH-1:0] weight_bank_a [0:OC_PARALLEL_1_CLOCK-1][0:FEATURE_IN_PARALLEL-1];
reg [DATA_WIDTH-1:0] weight_bank_b [0:OC_PARALLEL_1_CLOCK-1][0:FEATURE_IN_PARALLEL-1];

wire [3:0] weight_offset = {i_sig_load_step[2:1], 2'b00};
wire [3:0] kernel_start  = i_sig_load_step[0] ? 4'd8 : 4'd0;

integer i;
always @(posedge clk) begin
    if (i_sig_wr_en) begin
        for (i = 0; i < NUM_KERNEL_LOAD_1_CLOCK; i = i + 1) begin
            if (i_sig_bank_sel) begin
                weight_bank_a[kernel_start + i][weight_offset + 0] <= i_data_weight[(i*64) + (0*16) +: 16];
                weight_bank_a[kernel_start + i][weight_offset + 1] <= i_data_weight[(i*64) + (1*16) +: 16];
                weight_bank_a[kernel_start + i][weight_offset + 2] <= i_data_weight[(i*64) + (2*16) +: 16];
                weight_bank_a[kernel_start + i][weight_offset + 3] <= i_data_weight[(i*64) + (3*16) +: 16];
            end else begin
                weight_bank_b[kernel_start + i][weight_offset + 0] <= i_data_weight[(i*64) + (0*16) +: 16];
                weight_bank_b[kernel_start + i][weight_offset + 1] <= i_data_weight[(i*64) + (1*16) +: 16];
                weight_bank_b[kernel_start + i][weight_offset + 2] <= i_data_weight[(i*64) + (2*16) +: 16];
                weight_bank_b[kernel_start + i][weight_offset + 3] <= i_data_weight[(i*64) + (3*16) +: 16];
            end
        end
    end
end

wire [TOTAL_WEIGHT_OUT_WIDTH-1:0] weight_out_a;
wire [TOTAL_WEIGHT_OUT_WIDTH-1:0] weight_out_b;

genvar k, w;
generate
    for (k = 0; k < OC_PARALLEL_1_CLOCK; k = k + 1) begin : GEN_OC
        for (w = 0; w < FEATURE_IN_PARALLEL; w = w + 1) begin : GEN_IC
            assign weight_out_a[k*FEATURE_IN_PARALLEL*DATA_WIDTH + w*DATA_WIDTH +: DATA_WIDTH] = weight_bank_a[k][w];
            assign weight_out_b[k*FEATURE_IN_PARALLEL*DATA_WIDTH + w*DATA_WIDTH +: DATA_WIDTH] = weight_bank_b[k][w];
        end
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_data_weight_to_mac <= 1'b0;
    end else if (i_sig_bank_sel) begin
        o_data_weight_to_mac <= weight_out_b;
    end else begin
        o_data_weight_to_mac <= weight_out_a;
    end
end

assign o_sig_weight_load_done = i_sig_wr_en && (i_sig_load_step == 3'b111);

endmodule
