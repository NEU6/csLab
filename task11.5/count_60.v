module count_60(
    input wire rst,
    input wire clk,
    input wire en,
    output wire [6:0] count,
    output wire co
);
    wire[2:0] count6;
    wire[3:0] count10;
    wire co10,co6;
    
    count_10 u_count_10(
    	.rst   (rst   ),
        .clk   (clk   ),
        .en    (en    ),
        .count (count10 ),
        .co    (co10    )
    );
    
    count_6 u_count_6(
    	.rst   (rst   ),
        .clk   (clk   ),
        .en    (co10  ),
        .count (count6 ),
        .co    (co6    )
    );

and result_co(co,co6,co10); 
assign count = {count6,count10}; 

endmodule