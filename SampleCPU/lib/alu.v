`include "defines.vh"
module alu(
    input wire [11:0] alu_control,
    input wire [31:0] alu_src1,
    input wire [31:0] alu_src2,
    output wire [31:0] alu_result
);

    wire op_add;
    wire op_sub;
    wire op_slt;
    wire op_sltu;
    wire op_and;
    wire op_nor;
    wire op_or;
    wire op_xor;
    wire op_sll;
    wire op_srl;
    wire op_sra;
    wire op_lui;
    //match
    wire op_match;

    assign {op_add, op_sub, op_slt, op_sltu,
            op_and, op_nor, op_or, op_xor,
            op_sll, op_srl, op_sra, op_lui,
            //match
            op_match} = alu_control;
    
    wire [31:0] add_sub_result;
    wire [31:0] slt_result;
    wire [31:0] sltu_result;
    wire [31:0] and_result;
    wire [31:0] nor_result;
    wire [31:0] or_result;
    wire [31:0] xor_result;
    wire [31:0] sll_result;
    wire [31:0] srl_result;
    wire [31:0] sra_result;
    wire [31:0] lui_result;
    //match
    wire [31:0] match_result;
    // wire [24:0] matched;
    // assign matched=25'b0;

    //用match_rs和alu_src2从低位开始取8位进行循环比较
    //如果相等则matched的对应位为1
    //如果不相等则matched的对应位为0
    //最后将matched的低位赋值给match_result
    //match_result的即为alu_src2的最低位匹配到的位置
    //循环匹配

    // 定义一个变量，用于控制循环的迭代次数
    integer i;
    // 初始化 i 变量
    i = 0;
    while (i<=24) begin
        if(alu_sr1[7:0] != alu_src2[7:0]) begin
            match_result[i]=1;
        end
        else begin
            disable;
        end
        //alu_src2右移1位舍弃最低位,补0
        alu_src2={0'b0, alu_src2[31:1]};
        //加一位
        i=i+1;
    end

    assign and_result = alu_src1 & alu_src2;
    assign or_result = alu_src1 | alu_src2;
    assign nor_result = ~or_result;
    assign xor_result = alu_src1 ^ alu_src2;
    assign lui_result = {alu_src2[15:0], 16'b0};

    wire [31:0] adder_a;
    wire [31:0] adder_b;
    wire        adder_cin;
    wire [31:0] adder_result;
    wire        adder_cout;

    assign adder_a = alu_src1;
    assign adder_b = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;
    assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1 : 1'b0;
    assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

    assign add_sub_result = adder_result;

    assign slt_result[31:1] = 31'b0;
    assign slt_result[0] = (alu_src1[31] & ~alu_src2[31]) 
                         | (~(alu_src1[31]^alu_src2[31]) & adder_result[31]);
    
    assign sltu_result[31:1] = 31'b0;
    assign sltu_result[0] = ~adder_cout;

    assign sll_result = alu_src2 << alu_src1[4:0];
    assign srl_result = alu_src2 >> alu_src1[4:0];
    assign sra_result = ($signed(alu_src2)) >>> alu_src1[4:0];

    assign alu_result = ({32{op_add|op_sub  }} & add_sub_result)
                      | ({32{op_slt         }} & slt_result)
                      | ({32{op_sltu        }} & sltu_result)
                      | ({32{op_and         }} & and_result)
                      | ({32{op_nor         }} & nor_result)
                      | ({32{op_or          }} & or_result)
                      | ({32{op_xor         }} & xor_result)
                      | ({32{op_sll         }} & sll_result)
                      | ({32{op_srl         }} & srl_result)
                      | ({32{op_sra         }} & sra_result)
                      | ({32{op_lui         }} & lui_result)
                      //match
                      | ({32{op_match       }} & match_result);
                      
endmodule