`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,

    //数据相关新线
    output wire [`EX_TO_ID_WD-1:0] ex_to_id_bus,

    //气泡
    output wire is_lw,
    //ex段stall请求
    output wire stallreq_for_ex,
    //
    output wire div_ready_to_id
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
        end
    end

    wire [31:0] ex_pc, inst;
    wire [11:0] alu_op;
    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    //
    wire [3:0] data_ram_readen;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [31:0] rf_rdata1, rf_rdata2;
    reg is_in_delayslot;
    wire hi_we;         
    wire lo_we;         
    wire [31:0] hi_ex; 
    wire [31:0] lo_ex; 
    wire if_mul;        
    wire if_div;        
    wire [31:0] hi_out_id;         
    wire [31:0] lo_out_id;         
    wire hi_read; 
    wire lo_read; 
    wire hi_write;
    wire lo_write;
    //打开
    assign {
        data_ram_readen, 
        hi_write,        
        lo_write,        
        hi_read,         
        lo_read,         
        hi_out_id,        
        lo_out_id,        
        ex_pc,          // 148:117
        inst,           // 116:85
        alu_op,         // 84:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rf_rdata1,         // 63:32
        rf_rdata2          // 31:0
    } = id_to_ex_bus_r;

    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};
    assign imm_zero_extend = {16'b0, inst[15:0]};
    assign sa_zero_extend = {27'b0,inst[10:6]};

    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;

    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;
    
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );

    //结果
    assign ex_result =  hi_read ? hi_out_id:
                        lo_read ? lo_out_id:
                        alu_result;
    


    // // EX to MEM
    // assign ex_to_mem_bus = {
    //     ex_pc,          // 75:44
    //     data_ram_en,    // 43
    //     data_ram_wen,   // 42:39
    //     sel_rf_res,     // 38
    //     rf_we,          // 37
    //     rf_waddr,       // 36:32
    //     ex_result       // 31:0
    // };

    // //数据相关新线
    // assign ex_to_id_bus={
    //     rf_we,          // 37
    //     rf_waddr,       // 36:32
    //     ex_result       // 31:0
    // };

    //气泡
    assign is_lw=(inst[31:26]==6'b10_0011)?1'b1:1'b0; 
    
    // MUL part
    wire inst_mult;                           
    wire inst_multu;
    //指令                     
    assign inst_mult    = inst[31:26]==6'b00_0000&inst[15:6]==10'b00000_00000&inst[5:0]==6'b01_1000;
    assign inst_multu   = inst[31:26]==6'b00_0000&inst[15:6]==10'b00000_00000&inst[5:0]==6'b01_1001;     
    wire [63:0] mul_result;
    wire mul_signed; // 有符号乘法标记
    assign mul_signed = inst_mult;         
    assign if_mul=inst_mult | inst_multu;   
    wire [31:0] rf_rdata_mul1;              
    wire [31:0] rf_rdata_mul2;              
    assign rf_rdata_mul1 = (if_mul) ? rf_rdata1 : 32'd0 ;  
    assign rf_rdata_mul2 = (if_mul) ? rf_rdata2 : 32'd0 ;         
    mul u_mul(
    	.clk        (clk            ),
        .resetn     (~rst           ),
        .mul_signed (mul_signed     ),
        .ina        ( rf_rdata_mul1     ), // 乘法源操作数1
        .inb        ( rf_rdata_mul2     ), // 乘法源操作数2
        .result     (mul_result     ) // 乘法结果 64bit
    );

    // DIV part
    wire [63:0] div_result;
    wire inst_div, inst_divu;
    //操作
    assign inst_div    = inst[31:26]==6'b00_0000&inst[15:6]==10'b00000_00000&inst[5:0]==6'b01_1010;
    assign inst_divu   = inst[31:26]==6'b00_0000&inst[15:6]==10'b00000_00000&inst[5:0]==6'b01_1011;
    wire div_ready_i;
    //ex段stall请求
    //reg stallreq_for_div;
    //assign stallreq_for_ex = stallreq_for_div;
    assign if_div=inst_div|inst_divu;   
    
    assign stallreq_for_ex = (if_div) & div_ready_i==1'b0;
    assign div_ready_to_id = div_ready_i;

    reg [31:0] div_opdata1_o;
    reg [31:0] div_opdata2_o;
    reg div_start_o;
    reg signed_div_o;

    div u_div(
    	.rst          (rst          ),
        .clk          (clk          ),
        .signed_div_i (signed_div_o ),
        .opdata1_i    (div_opdata1_o    ),
        .opdata2_i    (div_opdata2_o    ),
        .start_i      (div_start_o      ),
        .annul_i      (1'b0      ),
        .result_o     (div_result     ), // 除法结果 64bit
        .ready_o      (div_ready_i    )
    );

    always @ (*) begin
        if (rst) begin
            //stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
        end
        else begin
            //stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
            case ({inst_div,inst_divu})
                2'b10:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1;
                        //stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        //stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        //stallreq_for_div = `NoStop;
                    end
                end
                2'b01:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        //stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        //stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        //stallreq_for_div = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end

    // mul_result 和 div_result 可以直接使用
     assign hi_ex = (if_mul)? mul_result[63:32]:
                    (if_div)?div_result[63:32]:
                    (hi_write)? rf_rdata1:
                     32'b0;
                  
     assign lo_ex= (if_mul)? mul_result[31:0]:
                   (if_div)?div_result[31:0]:
                   (lo_write)? rf_rdata1:
                    32'b0;
                   
    assign hi_we=inst_div|inst_divu|inst_mult|inst_multu|hi_write;
    assign lo_we=inst_div|inst_divu|inst_mult|inst_multu|lo_write;
    
    assign ex_to_mem_bus = {
        data_ram_readen,            
        hi_we,                   
        lo_we,                    
        hi_ex,                    //存回HI寄存器的值
        lo_ex,                    //存回LO寄存器的值
        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };
    
    //新增
    assign ex_to_id_bus={
        hi_we,                   
        lo_we,                   
        hi_ex,                    
        lo_ex,
        rf_we,
        rf_waddr,
        ex_result           
    };
    
    //写数据
    //assign data_sram_wdata = rf_rdata2;
    assign data_sram_en = data_ram_en;
    //写使能信号 
    assign data_sram_wen =   (data_ram_readen==4'b0101 && ex_result[1:0] == 2'b00 )? 4'b0001 
                            :(data_ram_readen==4'b0101 && ex_result[1:0] == 2'b01 )? 4'b0010
                            :(data_ram_readen==4'b0101 && ex_result[1:0] == 2'b10 )? 4'b0100
                            :(data_ram_readen==4'b0101 && ex_result[1:0] == 2'b11 )? 4'b1000
                            :(data_ram_readen==4'b0111 && ex_result[1:0] == 2'b00 )? 4'b0011
                            :(data_ram_readen==4'b0111 && ex_result[1:0] == 2'b10 )? 4'b1100
                            : data_ram_wen;
    //内存的地址        
    assign data_sram_addr = ex_result;  
    assign data_sram_wdata = data_sram_wen==4'b1111 ? rf_rdata2 
                            :data_sram_wen==4'b0001 ? {24'b0,rf_rdata2[7:0]}
                            :data_sram_wen==4'b0010 ? {16'b0,rf_rdata2[7:0],8'b0}
                            :data_sram_wen==4'b0100 ? {8'b0,rf_rdata2[7:0],16'b0}
                            :data_sram_wen==4'b1000 ? {rf_rdata2[7:0],24'b0}
                            :data_sram_wen==4'b0011 ? {16'b0,rf_rdata2[15:0]}
                            :data_sram_wen==4'b1100 ? {rf_rdata2[15:0],16'b0}
                            :32'b0;
                            
endmodule