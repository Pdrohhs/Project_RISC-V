// =============================================================================
// pl_control.sv
// Unidade de Controle Principal -- RV32I pipelined (P&H secao 4.4)
//
// Decodifica o opcode de 7 bits (estagio ID) e gera os sinais de controle
// que serao propagados pelos registradores de pipeline.
//
// Instrucoes suportadas:
//   R-type  (0110011): add,and,xor,sll,srl,sra,sltu
//	 I-type  (0010011): addi,slli,srti,srli,srai,ori,andi
//   Load    (0000011): lw,lb,lh,lbu,lhu
//   S-type  (0100011): sw,sb,sh
//   B-type  (1100011): beq,bne,blt,bge,bltu,bgeu
//   JAL     (1101111): jal
//   JALR    (1100111): jalr
//	 Lui     (0110111): lui
//   Auipc   (0010111): auipc
//
// Tabela de sinais de controle:
//   Sinal     		| R-type | I-type | lw | sw | B-type | JAL | JALR | Lui | Auipc
//   ---------------|--------|--------|----|----|--------|-----|------|-----|------
//   ALUSrcA[1:0]   |   00   |   00   | 00 | 00 |   00   | 00  |  00  |  10 |  01   00=reg, 01=PC, 10=zero
//   ALUSrcB   		|    0   |    1   |  1 |  1 |    0   |  0  |   1  |   1 |   1   0=reg, 1=imm
//   MemtoReg  		|    0   |    0   |  1 |  - |    -   |  0  |   0  |   0 |   0   0=ALU, 1=mem
//   RegWrite  		|    1   |    1   |  1 |  0 |    0   |  1  |   1  |   1 |   1
//   MemRead   		|    0   |    0   |  1 |  0 |    0   |  0  |   0  |   0 |   0
//   MemWrite  		|    0   |    0   |  0 |  1 |    0   |  0  |   0  |   0 |   0
//   Branch    		|    0   |    0   |  0 |  0 |    1   |  1  |   1  |   0 |   0
//   JalSrc    		|    0   |    0   |  0 |  0 |    0   |  1  |   1  |   0 |   0
//   ALUOp[1:0]  	|   10   |   11   | 00 | 00 |   01   | 00  |  00  |  00 |  00
// =============================================================================

`timescale 1ns / 1ps

module pl_control (
    input  logic [6:0] Opcode,
    output logic [1:0] ALUSrcA,  // 00=reg, 01=PC, 10=zero
    output logic       ALUSrcB,  // 0=reg, 1=imm
    output logic       MemtoReg,
    output logic       RegWrite,
    output logic       MemRead,
    output logic       MemWrite,
    output logic       Branch,
    output logic       JalSrc,
    output logic [1:0] ALUOp
);
 
    localparam R_TYPE = 7'b0110011;
    localparam I_TYPE = 7'b0010011;
    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam JAL    = 7'b1101111;
    localparam JALR   = 7'b1100111;
    localparam LUI    = 7'b0110111;
    localparam AUIPC  = 7'b0010111;
 
    always_comb begin
        ALUSrcA  = 2'b00;
        ALUSrcB  = 1'b0;
        MemtoReg = 1'b0;
        RegWrite = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        Branch   = 1'b0;
        JalSrc   = 1'b0;
        ALUOp    = 2'b00;
 
        case (Opcode)
            R_TYPE: begin
                ALUSrcA  = 2'b00;  // rs1
                ALUSrcB  = 1'b0;   // rs2
                MemtoReg = 1'b0;
                RegWrite = 1'b1;
                ALUOp    = 2'b10;
            end
 
            I_TYPE: begin
                ALUSrcA  = 2'b00;  // rs1
                ALUSrcB  = 1'b1;   // imm
                MemtoReg = 1'b0;
                RegWrite = 1'b1;
                ALUOp    = 2'b11;
            end
 
            LOAD: begin
                ALUSrcA  = 2'b00;  // rs1
                ALUSrcB  = 1'b1;   // imm
                MemtoReg = 1'b1;
                RegWrite = 1'b1;
                MemRead  = 1'b1;
                ALUOp    = 2'b00;
            end
 
            STORE: begin
                ALUSrcA  = 2'b00;  // rs1
                ALUSrcB  = 1'b1;   // imm
                MemWrite = 1'b1;
                ALUOp    = 2'b00;
            end
 
            BRANCH: begin
                ALUSrcA  = 2'b00;  // rs1
                ALUSrcB  = 1'b0;   // rs2
                Branch   = 1'b1;
                ALUOp    = 2'b01;
            end
 
            JAL: begin
                // ALU nao calcula target; datapath usa PC + imm diretamente
                // ALUSrcB = 0 distingue JAL de JALR no datapath (is_jalr)
                ALUSrcA  = 2'b00;
                ALUSrcB  = 1'b0;   // FIX: explicitado — JAL nao usa ALU para target
                RegWrite = 1'b1;
                Branch   = 1'b1;
                JalSrc   = 1'b1;
                ALUOp    = 2'b00;
            end
 
            JALR: begin
                // ALU calcula rs1 + imm; bit 0 forcado a 0 no datapath
                ALUSrcA  = 2'b00;  // rs1
                ALUSrcB  = 1'b1;   // imm  ← ALUSrcB=1 distingue JALR de JAL
                RegWrite = 1'b1;
                Branch   = 1'b1;
                JalSrc   = 1'b1;
                ALUOp    = 2'b00;  // ADD: rs1 + imm
            end
 
            LUI: begin
                ALUSrcA  = 2'b10;  // zero (ALU faz 0 + imm = imm)
                ALUSrcB  = 1'b1;   // imm
                MemtoReg = 1'b0;
                RegWrite = 1'b1;
                ALUOp    = 2'b00;
            end  // FIX: end que estava faltando — AUIPC estava dentro do bloco LUI
 
            AUIPC: begin
                ALUSrcA  = 2'b01;  // PC (ALU faz PC + imm)
                ALUSrcB  = 1'b1;   // imm
                RegWrite = 1'b1;
                ALUOp    = 2'b00;
            end
 
            default: ; // todos os sinais ja estao em zero (seguro)
        endcase
    end
 
endmodule
