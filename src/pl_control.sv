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
//	  Lui     (0110111): lui
//   Auipc   (0010111): auipc
//
// Tabela de sinais de controle:
//   Sinal     | R-type | I-type | lw | sw | B-type | JAL | JALR | Lui | Auipc
//   ----------|--------|--------|----|----|--------|-----|-------------------
//   ALUSrc    |   0    |   1    |  1 |  1 |   0    |  0  |  1	  |  1  |  0
//   MemtoReg  |   0    |   0    |  1 |  - |   -    |  0  |  0   |  0  |  0 
//   RegWrite  |   1    |   1    |  1 |  0 |   0    |  1  |  1   |  1  |  1
//   MemRead   |   0    |   0    |  1 |  0 |   0    |  0  |  0   |  0  |  0
//   MemWrite  |   0    |   0    |  0 |  1 |   0    |  0  |  0   |  0  |  0
//   Branch    |   0    |   0    |  0 |  0 |   1    |  1  |  1   |  0  |  0
//   JalSrc    |   0    |   0    |  0 |  0 |   0    |  1  |  1   |  0  |  1
//   ALUOp[1]  |   1    |   1    |  0 |  0 |   0    |  0  |  0   |  0  |  0
//   ALUOp[0]  |   0    |   1    |  0 |  0 |   1    |  0  |  0   |  0  |  0
// =============================================================================

`timescale 1ns / 1ps

module pl_control (
    input  logic [6:0] Opcode,
    output logic       ALUSrc,
    output logic       MemtoReg,
    output logic       RegWrite,
    output logic       MemRead,
    output logic       MemWrite,
    output logic       Branch,
    output logic       JalSrc,    // 1 = wb_data recebe PC+4 (JAL/JALR)
    output logic [1:0] ALUOp
);

    localparam R_TYPE = 7'b0110011;
    localparam LOAD   = 7'b0000011;
	localparam I_TYPE = 7'b0010011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam JAL    = 7'b1101111;
    localparam JALR   = 7'b1100111;
	 localparam LUI    = 7'b0110111;
	 localparam AUIPC  = 7'b0010111;

    always_comb begin
        ALUSrc   = 1'b0;
        MemtoReg = 1'b0;
        RegWrite = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        Branch   = 1'b0;
        JalSrc   = 1'b0;
        ALUOp    = 2'b00;

        case (Opcode)
            R_TYPE: begin
                ALUSrc   = 1'b0;
                MemtoReg = 1'b0;
                RegWrite = 1'b1;
                ALUOp    = 2'b10;
            end
			I_TYPE: begin
				ALUSrc   = 1'b1;
				MemtoReg = 1'b0;
				RegWrite = 1'b1;
				MemRead  = 1'b0;
				ALUOp    = 2'b11;
				
			end
            LOAD: begin
                ALUSrc   = 1'b1;
                MemtoReg = 1'b1;
                RegWrite = 1'b1;
                MemRead  = 1'b1;
                ALUOp    = 2'b00;
            end
            STORE: begin
                ALUSrc   = 1'b1;
                MemWrite = 1'b1;
                ALUOp    = 2'b00;
            end
            BRANCH: begin
                Branch   = 1'b1;
                ALUOp    = 2'b01;
            end
            JAL: begin
                RegWrite = 1'b1;
                Branch   = 1'b1;
                JalSrc   = 1'b1;
                ALUOp    = 2'b00;  // ALU nao e usada; target = PC + imm no datapath
            end
            JALR: begin
                ALUSrc   = 1'b1;   // SrcB = imediato (rs1 + imm via ALU)
                RegWrite = 1'b1;
                Branch   = 1'b1;
                JalSrc   = 1'b1;
                ALUOp    = 2'b00;  // ADD: calcula rs1 + imm
            end
				LUI: begin
                ALUSrc   = 1'b1; 
                MemtoReg = 1'b0;
                RegWrite = 1'b1;
                MemRead  = 1'b0;
                ALUOp    = 2'b00;
				AUIPC: begin
                ALUSrc   = 1'b0;
                RegWrite = 1'b1;
					 Branch   = 1'b0;
					 JalSrc   = 1'b1;
                ALUOp    = 2'b00;
            end
            default: ; // sinais permanecem em zero (seguro)
        endcase
    end

endmodule
