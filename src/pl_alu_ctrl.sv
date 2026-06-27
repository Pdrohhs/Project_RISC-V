// =============================================================================
// pl_alu_ctrl.sv
// Unidade de Controle da ALU -- RV32I pipelined (P&H secao 4.4)
//
// Entradas (do estagio EX -- registrador ID/EX):
//   ALUOp[1:0] : codigo do controlador principal
//     2'b00 : Load/Store  -> forcar ADD
//     2'b01 : Branch BEQ  -> forcar SUB
//     2'b10 : R-type      -> decodificar via Funct3/Funct7
//     2'b11 : I-type      -> decodifica via Funct3
//	   2'b00 : Lui/Auipc   -> forcar ADD

//   Funct7[6:0], Funct3[2:0] : campos da instrucao
//
// Saida Operation[3:0] -> pl_alu.sv:
//   R-type
//   4'd01 : ADD  -- adicao com sinal
//   4'd02 : SUB  -- subtracao com sinal  (BEQ usa Zero)
//   4'd03 : XOR  -- OU-exclusivo bit a bit
//   4'd04 : OR   -- OU bit a bit
//   4'd05 : AND  -- E bit a bit
//   4'd06 : SLL  -- deslocamento logico a esquerda
//   4'd07 : SRL  -- deslocamento logico a direita
//   4'd08 : SRA  -- deslocamento aritmetico a direita
//   4'd09 : SLTU -- set-less-than sem sinal
//   4'd11 : SLT  -- set-less-than com sinal
//
//	 I-type
//   4'd01 : ADDI -- adicao com sinal e imediato
//   4'd04 : ORI  -- OU bit a bit com o imediato
//   4'd05 : ANDI -- E bit a bit com o imediato  
//   4'd06 : SLLI -- deslocamento logico a esquerda e imediato como contador
//   4'd07 : SRLI -- deslocamento logico a direita e imediato como contador
//   4'd08 : SRAI -- deslocamento aritmetico a direita e imediato como contador 
//	 4'd11 : SRTI -- set-less-than com sinal e imediato 
// =============================================================================

`timescale 1ns / 1ps

module pl_alu_ctrl (
    input  logic [1:0] ALUOp,
    input  logic [6:0] Funct7,
    input  logic [2:0] Funct3,
    output logic [3:0] Operation
);

    always_comb begin
        case (ALUOp)
            2'b00: Operation = 4'd01;   // Load / Store -> ADD

            2'b01: begin   // Branch BEQ  -> SUB
                case (Funct3)
                    3'h0: Operation = 4'd02;  // BEQ  -> SUB
                    3'h1: Operation = 4'd02;  // BNE  -> SUB
                    3'h4: Operation = 4'd11;  // BLT  -> SLT
                    3'h5: Operation = 4'd11;  // BGE  -> SLT
                    3'h6: Operation = 4'd09;  // BLTU -> SLTU
                    3'h7: Operation = 4'd09;  // BGEU -> SLTU
                    default: Operation = 4'd02;
                endcase
            end

            2'b10: begin                // R-type: decodificar Funct3/Funct7
                case (Funct3)
                    3'h0: Operation = Funct7[5] ? 4'd02 : 4'd01; // SUB ou ADD
                    3'h1: Operation = 4'd06;  // SLL
                    3'h2: Operation = 4'd11;  // SLT
                    3'h3: Operation = 4'd09;  // SLTU
                    3'h4: Operation = 4'd03;  // XOR
                    3'h5: Operation = Funct7[5] ? 4'd08 : 4'd07; // SRA ou SRL
                    3'h6: Operation = 4'd04;  // OR
                    3'h7: Operation = 4'd05;  // AND
                    default: Operation = 4'd01;
                endcase
				end	
			
				2'b11:begin //I-type: decodificar Funct3
					case(Funct3)
						3'b000: Operation = 4'd01;  //addi
						3'b001: Operation = 4'd06;  //slli
						3'b010: Operation = 4'd11;  //srti
                        3'b011: Operation = 4'd09;  // SLTIU
                        3'b100: Operation = 4'd03;  // XORI
						3'b101: Operation = Funct7[5] ? 4'd08 : 4'd07; // srai ou srli
						3'b110: Operation = 4'd04;  //ori
						3'b111: Operation = 4'd05; //andi
						default: Operation = 4'd01;
					endcase
				end

            default: Operation = 4'd01;
        endcase
    end

endmodule
