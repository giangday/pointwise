// modlue dem xem stage da xong chua, neu stage da xong thi set flag stage_done len 1, neu stage chua xong thi set flag stage_done len 0, 
// stage da xong khi da duyet het du lieu cua stage do
// input la relu0_valid, relu1_valid, 
// i_mode dung de xac dinh stage
// output la stage_done


module count_stage_done (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       relu_valid,
    input  wire       rst_stage_done,
    input  wire [7:0] i_mode,  
    output reg        o_stage_done
);

    reg [7:0] count1;
    reg [7:0] count2;

    wire [7:0] mode_max = i_mode - 8'd1;

    wire count1_done = (count1 == mode_max);
    wire count2_done = (count2 == mode_max);

    always @(posedge clk) begin
        if (!rst_n) begin
            count1       <= 8'd0;
            count2       <= 8'd0;
            o_stage_done <= 1'b0;
        end
        else if (rst_stage_done) begin
            count1       <= 8'd0;
            count2       <= 8'd0;
            o_stage_done <= 1'b0;
        end
        else begin
            if (relu_valid) begin
                if (count1_done) begin
                    count1 <= 8'd0;

                    if (count2_done) begin
                        count2       <= 8'd0;
                        o_stage_done <= 1'b1; // sticky
                    end
                    else begin
                        count2 <= count2 + 8'd1;
                    end
                end
                else begin
                    count1 <= count1 + 8'd1;
                end
            end
        end
    end

endmodule



