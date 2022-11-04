module count_6(
    input wire rst,
    input wire clk,
    input wire en,
    output reg [2:0] count,
    output reg co
);
    always @ (posedge clk) begin
        if (rst) begin
            count <= 3'b0;
            co <= 1'b0;
        end
        else if (en) begin
             if (count == 3'd4) begin
                co <= 1'b1;
                count <= count + 1'b1;
            end
            else if (count == 3'd5) begin
                count <= 3'b0;
                co <= 1'b0; 
            end
            else begin
                count <= count + 1'b1;
                co <= 1'b0;
            end
        end
    end
endmodule