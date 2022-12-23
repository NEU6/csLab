`include "defines.vh"
module regfile(
    input wire clk,
    input wire [4:0] raddr1,
    output wire [31:0] rdata1,
    input wire [4:0] raddr2,
    output wire [31:0] rdata2,
    
    input wire we,
    input wire [4:0] waddr,
    input wire [31:0] wdata,

    //数据相关新线
    input wire [`EX_TO_ID_WD-1:0] ex_to_id_bus,
    input wire [`MEM_TO_ID_WD-1:0] mem_to_id_bus,
    input wire [`WB_TO_ID_WD-1:0] wb_to_id_bus,
    
    //hilo 读写
    input wire [67:0] hl_bus,
    
    //hilo输出线
    output wire [31:0] hi_out,
    output wire [31:0] lo_out
);
    reg [31:0] reg_array [31:0];
    reg [31:0] reg_hi;//定义hi寄存器 
    reg [31:0] reg_lo;//定义lo寄存器
    // write
    always @ (posedge clk) begin
        if (we && waddr!=5'b0) begin
            reg_array[waddr] <= wdata;
        end
    end

    //数据相关新线打开
    wire ex_id_hi_we;          
    wire ex_id_lo_we;           
    wire [31:0] ex_id_hi_i;               
    wire [31:0] ex_id_lo_i;
    wire ex_id_wreg;
    wire [4:0] ex_id_waddr;
    wire [31:0] ex_id_wdata;
    assign {
        ex_id_hi_we,
        ex_id_lo_we,
        ex_id_hi_i,
        ex_id_lo_i,
        ex_id_wreg,
        ex_id_waddr,
        ex_id_wdata
    }= ex_to_id_bus;
    
    wire mem_id_hi_we;          
    wire mem_id_lo_we;           
    wire [31:0] mem_id_hi_i;               
    wire [31:0] mem_id_lo_i;
    wire mem_id_wreg;
    wire [4:0] mem_id_waddr;
    wire [31:0] mem_id_wdata;
    assign {
        mem_id_hi_we,
        mem_id_lo_we,
        mem_id_hi_i,
        mem_id_lo_i,
        mem_id_wreg,
        mem_id_waddr,
        mem_id_wdata
    }=mem_to_id_bus;
   
    wire wb_id_hi_we;          
    wire wb_id_lo_we;           
    wire [31:0] wb_id_hi_i;               
    wire [31:0] wb_id_lo_i;
    wire wb_id_wreg;
    wire [4:0] wb_id_waddr;
    wire [31:0] wb_id_wdata;
    assign {
        wb_id_hi_we,
        wb_id_lo_we,
        wb_id_hi_i,
        wb_id_lo_i,
        wb_id_wreg,
        wb_id_waddr,
        wb_id_wdata
    }=wb_to_id_bus;
    
    //hilo读写打开
    wire hi_we;
    wire lo_we;
    wire hi_read;
    wire lo_read;
    wire [31:0] hi_i;
    wire [31:0] lo_i;
    assign {
        hi_we,
        lo_we,
        hi_read,
        lo_read,
        hi_i,
        lo_i
    }=hl_bus;


    // read out1
    assign rdata1 = (raddr1 == 5'b0) ? 32'b0 : 
                    ((ex_id_wreg==1'b1)&&(ex_id_waddr==raddr1))?ex_id_wdata:
                    ((mem_id_wreg==1'b1)&&(mem_id_waddr==raddr1))?mem_id_wdata:
                    ((wb_id_wreg==1'b1)&&(wb_id_waddr==raddr1))?wb_id_wdata:reg_array[raddr1];

    // read out2
    assign rdata2 = (raddr2 == 5'b0) ? 32'b0 : 
                    ((ex_id_wreg==1'b1)&&(ex_id_waddr==raddr2))?ex_id_wdata:
                    ((mem_id_wreg==1'b1)&&(mem_id_waddr==raddr2))?mem_id_wdata:
                    ((wb_id_wreg==1'b1)&&(wb_id_waddr==raddr2))?wb_id_wdata:reg_array[raddr2];

    //read hi_out
    assign hi_out = (ex_id_hi_we) ? ex_id_hi_i:
                    (mem_id_hi_we)? mem_id_hi_i:
                    (wb_id_hi_we) ? wb_id_hi_i:
                    reg_hi; 
                    
    //read lo_out          
    assign lo_out = (ex_id_lo_we) ? ex_id_lo_i:
                    (mem_id_lo_we)? mem_id_lo_i:
                    (wb_id_lo_we) ? wb_id_lo_i:
                    reg_lo;        
     
endmodule