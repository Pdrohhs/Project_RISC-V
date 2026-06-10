// =============================================================================
// pl_control.sv
// Unidade de Controle Principal -- RV32I pipelined (P&H secao 4.4)
//
// Decodifica o opcode de 7 bits (estagio ID) e gera os sinais de controle
// que serao propagados pelos registradores de pipeline.
//
// Instrucoes suportadas:
//   R-type    (0110011): add,and,xor,sll,srl,sra,sltu
//   I-type    (0010011): addi,slli,srti,srli,srai,ori,andi
//   Load      (0000011): lw
//   S-type    (0100011): sw
//   B-type    (1100011): beq
//   J-type    (1101111): jal
//   I-type-J  (1100111): jalr
//
// Tabela de sinais de controle:
//   Sinal     | R-type | I-type | lw | sw | beq | jal | jalr
//   ----------|--------|--------|----|----|-----|-----|-----
//   ALUSrc    |   0    |   1    |  1 |  1 |  0  |  0  |  1
//   MemtoReg  |   0    |   0    |  1 |  - |  -  |  -  |  -
//   RegWrite  |   1    |   1    |  1 |  0 |  0  |  1  |  1
//   MemRead   |   0    |   0    |  1 |  0 |  0  |  0  |  0
//   MemWrite  |   0    |   0    |  0 |  1 |  0  |  0  |  0
//   Branch    |   0    |   0    |  0 |  0 |  1  |  0  |  0
//   Jump      |   0    |   0    |  0 |  0 |  0  |  1  |  1
//   ALUOp     |  10    |  11    | 00 | 00 | 01  | 00  | 00
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
    output logic       Jump,        // jal and jalr teste
    output logic [1:0] ALUOp
);

    localparam R_TYPE    = 7'b0110011;
    localparam LOAD      = 7'b0000011;
    localparam I_TYPE    = 7'b0010011;
    localparam STORE     = 7'b0100011;
    localparam BRANCH    = 7'b1100011;
    localparam JUMP_JAL  = 7'b1101111;  
    localparam JUMP_JALR = 7'b1100111;  

    always_comb begin
        ALUSrc   = 1'b0;
        MemtoReg = 1'b0;
        RegWrite = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        Branch   = 1'b0;
        Jump     = 1'b0;         
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
            JUMP_JAL: begin
                // JAL rd, offset:
                //   rd = PC+4
                //   PC = PC + imm_J
                // O jump eh resolvido no estagio EX. O alvo vem de
                //   branch_target = pc + imm_ext  (PC do ID/EX + offsets J)
                Jump     = 1'b1;
                RegWrite = 1'b1;
                // MemtoReg nao importa: jump=1 no WB seleciona PC+4
            end
            JUMP_JALR: begin
                // JALR rd, rs1, imm:
                //   rd = PC+4
                //   PC = (rs1 + imm_I) & ~1
                // A ALU calcula rs1 + imm (ALUSrc=1, ALUOp=00=ADD)
                // O alvo vem de alu_result (no EX), e o bit 0 e zerado no datapath
                Jump     = 1'b1;
                ALUSrc   = 1'b1;    // ALU usa o imediato (rs1 + imm_I)
                RegWrite = 1'b1;
                ALUOp    = 2'b00;   // Forca ADD na ALU
                // MemtoReg nao importa: jump=1 no WB seleciona PC+4
            end
            default: ; // sinais permanecem em zero (seguro)
        endcase
    end

endmodule