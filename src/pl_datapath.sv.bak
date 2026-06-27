// =============================================================================
// pl_datapath.sv
// Datapath pipeline de 5 estagios -- RV32I (P&H secoes 4.6-4.10)
//
// Estagios:
//   IF  -- busca instrucao (pl_imem, PC)
//   ID  -- decodificacao, leitura de registradores, deteccao de hazard
//   EX  -- execucao (ALU), resolucao de branch, forwarding
//   MEM -- acesso a memoria de dados / MMIO
//   WB  -- escrita no banco de registradores
//
// Tratamento de hazards:
//   Load-use stall : 1 ciclo de bolha (pl_hazard)
//   RAW data       : forwarding EX/MEM -> EX e MEM/WB -> EX (pl_forward)
//   Branch taken   : flush de IF e ID (2 NOPs) na resolucao em EX
//
// Decodificacao de endereco (estagio MEM):
//   alu_result[10] = 0 -> memoria de dados  (0x000-0x3FF)
//   alu_result[10] = 1 -> MMIO              (0x400-0x7FF)
//     alu_result[4:2] seleciona periferico dentro da janela MMIO
// =============================================================================

`timescale 1ns / 1ps

import pl_pipe_pkg::*;

module pl_datapath (
    input  logic        clk,
    input  logic        rst_n,

    // Sinais de controle vindos do estagio ID (pl_control)
	input  logic [1:0]  ALUSrcA, //rs1, pc ou zero
    input  logic        ALUSrcB, //rs2 ou imm
    input  logic        MemtoReg,
    input  logic        RegWrite,
    input  logic        MemRead,
    input  logic        MemWrite,
    input  logic        Branch,
    input  logic        JalSrc,    // 1 = JAL/JALR: wb_data recebe PC+4
    input  logic [1:0]  ALUOp,

    // Codigo de operacao da ALU (pl_alu_ctrl, usa campos do estagio EX)
    input  logic [3:0]  ALU_CC,

    // Campos realimentados ao pl_cpu para controle e ALU ctrl
    output logic [6:0]  Opcode,
    output logic [2:0]  Funct3_EX,
    output logic [6:0]  Funct7_EX,
    output logic [1:0]  ALUOp_EX,

    output logic [31:0] PC,

    // E/S Mapeada em Memoria -- DE2-115
    input  logic [17:0] SW,
    input  logic [3:0]  KEY,
    output logic [17:0] LEDR,
    output logic [8:0]  LEDG,
    output logic        UART_TXD,
    input  logic        UART_RXD,

    // Observabilidade para o testbench
    output logic        wb_reg_write,
    output logic [4:0]  wb_reg_dst,
    output logic [31:0] wb_reg_data,
    output logic        mem_wr_en,
    output logic [7:0]  mem_wr_addr,
    output logic [31:0] mem_wr_data
);

    // =========================================================================
    // Sinais internos
    // =========================================================================

    // PC
    logic [31:0] pc_reg, pc_plus4;

    // Registradores de pipeline
    if_id_t  if_id;
    id_ex_t  id_ex;
    ex_mem_t ex_mem;
    mem_wb_t mem_wb;

    // Hazard / branch
    logic        stall;
    logic        pc_src;
    logic [31:0] branch_target;

    // ID
    logic [31:0] rd1, rd2, imm_ext;

    // EX -- forwarding
    logic [1:0]  fwd_a, fwd_b;
    logic [31:0] fwd_srca, fwd_srcb, alu_srca, alu_srcb;
    logic [31:0] alu_result;
    logic        zero;
    logic        branch_taken;

    // WB
    logic [31:0] wb_data;

    // MEM
    logic        mmio_sel;
    logic [31:0] dmem_rd, mmio_rd, mem_read_data, load_data;
	logic [7:0]  selected_byte;
	logic [15:0] selected_half;

    // =========================================================================
    // IF -- Busca de instrucao
    // =========================================================================
    logic [31:0] instr_if;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)      pc_reg <= 32'b0;
        else if (pc_src) pc_reg <= branch_target;
        else if (!stall) pc_reg <= pc_plus4;
    end

    assign PC       = pc_reg;
    assign pc_plus4 = pc_reg + 32'd4;

    pl_imem imem (
        .addr  (pc_reg[9:2]),
        .instr (instr_if)
    );

    // =========================================================================
    // Registrador IF/ID
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id.pc    <= 32'b0;
            if_id.instr <= 32'b0;
        end else if (pc_src) begin
            if_id.pc    <= 32'b0;
            if_id.instr <= 32'b0;
        end else if (!stall) begin
            if_id.pc    <= pc_reg;
            if_id.instr <= instr_if;
        end
    end

    // =========================================================================
    // ID -- Decodificacao, banco de registradores, imediato, hazard
    // =========================================================================
    assign Opcode = if_id.instr[6:0];

    pl_hazard hazard (
        .if_id_rs1      (if_id.instr[19:15]),
        .if_id_rs2      (if_id.instr[24:20]),
        .id_ex_rd       (id_ex.rd),
        .id_ex_mem_read (id_ex.mem_read),
        .stall          (stall)
    );

    // Mux WB: JalSrc tem prioridade, depois MemtoReg, depois ALU
    assign wb_data = mem_wb.jal_src    ? mem_wb.pc_plus4  :
                     mem_wb.mem_to_reg ? mem_wb.read_data  :
                                         mem_wb.alu_result;

    pl_regfile regfile (
        .clk       (clk),
        .RegWrite  (mem_wb.reg_write),
        .rs1       (if_id.instr[19:15]),
        .rs2       (if_id.instr[24:20]),
        .rd        (mem_wb.rd),
        .WriteData (wb_data),
        .ReadData1 (rd1),
        .ReadData2 (rd2)
    );

    pl_sign_ext sign_ext (
        .Instr  (if_id.instr),
        .ImmExt (imm_ext)
    );

    assign wb_reg_write = mem_wb.reg_write;
    assign wb_reg_dst   = mem_wb.rd;
    assign wb_reg_data  = wb_data;

    // =========================================================================
    // Registrador ID/EX
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
			id_ex.alu_src_a  <= 2'b0;
            id_ex.alu_src_b  <= 1'b0;
            id_ex.mem_to_reg <= 1'b0;
            id_ex.reg_write  <= 1'b0;
            id_ex.mem_read   <= 1'b0;
            id_ex.mem_write  <= 1'b0;
            id_ex.alu_op     <= 2'b00;
            id_ex.branch     <= 1'b0;
            id_ex.jal_src    <= 1'b0;
            id_ex.pc         <= 32'b0;
            id_ex.pc_plus4   <= 32'b0;
            id_ex.rd1        <= 32'b0;
            id_ex.rd2        <= 32'b0;
            id_ex.rs1        <= 5'b0;
            id_ex.rs2        <= 5'b0;
            id_ex.rd         <= 5'b0;
            id_ex.imm_ext    <= 32'b0;
            id_ex.funct3     <= 3'b0;
            id_ex.funct7     <= 7'b0;
        end else if (stall || pc_src) begin
			id_ex.alu_src_a  <= 2'b0;
            id_ex.alu_src_b  <= 1'b0;
            id_ex.mem_to_reg <= 1'b0;
            id_ex.reg_write  <= 1'b0;
            id_ex.mem_read   <= 1'b0;
            id_ex.mem_write  <= 1'b0;
            id_ex.alu_op     <= 2'b00;
            id_ex.branch     <= 1'b0;
            id_ex.jal_src    <= 1'b0;
            id_ex.pc         <= 32'b0;
            id_ex.pc_plus4   <= 32'b0;
            id_ex.rd1        <= 32'b0;
            id_ex.rd2        <= 32'b0;
            id_ex.rs1        <= 5'b0;
            id_ex.rs2        <= 5'b0;
            id_ex.rd         <= 5'b0;
            id_ex.imm_ext    <= 32'b0;
            id_ex.funct3     <= 3'b0;
            id_ex.funct7     <= 7'b0;
        end else begin
			id_ex.alu_src_a  <= ALUSrcA;
            id_ex.alu_src_b  <= ALUSrcB;
            id_ex.mem_to_reg <= MemtoReg;
            id_ex.reg_write  <= RegWrite;
            id_ex.mem_read   <= MemRead;
            id_ex.mem_write  <= MemWrite;
            id_ex.alu_op     <= ALUOp;
            id_ex.branch     <= Branch;
            id_ex.jal_src    <= JalSrc;
            id_ex.pc         <= if_id.pc;
            id_ex.pc_plus4   <= if_id.pc + 32'd4;  // PC+4 desta instrucao
            id_ex.rd1        <= rd1;
            id_ex.rd2        <= rd2;
            id_ex.rs1        <= if_id.instr[19:15];
            id_ex.rs2        <= if_id.instr[24:20];
            id_ex.rd         <= if_id.instr[11:7];
            id_ex.imm_ext    <= imm_ext;
            id_ex.funct3     <= if_id.instr[14:12];
            id_ex.funct7     <= if_id.instr[31:25];
        end
    end

    assign Funct3_EX = id_ex.funct3;
    assign Funct7_EX = id_ex.funct7;
    assign ALUOp_EX  = id_ex.alu_op;

    // =========================================================================
    // EX -- Forwarding, ALU, resolucao de branch
    // =========================================================================
    pl_forward forward (
        .id_ex_rs1        (id_ex.rs1),
        .id_ex_rs2        (id_ex.rs2),
        .ex_mem_rd        (ex_mem.rd),
        .mem_wb_rd        (mem_wb.rd),
        .ex_mem_reg_write (ex_mem.reg_write),
        .mem_wb_reg_write (mem_wb.reg_write),
        .forward_a        (fwd_a),
        .forward_b        (fwd_b)
    );

    always_comb begin
        case (fwd_a)
            2'b10:   fwd_srca = ex_mem.alu_result;
            2'b01:   fwd_srca = wb_data;
            default: fwd_srca = id_ex.rd1;
        endcase
    end

    always_comb begin
        case (fwd_b)
            2'b10:   fwd_srcb = ex_mem.alu_result;
            2'b01:   fwd_srcb = wb_data;
            default: fwd_srcb = id_ex.rd2;
        endcase
    end
	
	always_comb begin
		case(id_ex.alu_src_a)//define SrcA
			2'b01: alu_srca = id_ex.pc;
			2'b10: alu_srca = 32'b0;
			default:  alu_srca = fwd_srca;
		endcase
	end
    assign alu_srcb = id_ex.alu_src_b ? id_ex.imm_ext : fwd_srcb;//define SrcB

    pl_alu alu (
        .SrcA      (alu_srca),
        .SrcB      (alu_srcb),
        .Operation (ALU_CC),
        .ALUResult (alu_result),
        .Zero      (zero)
    );

    // -------------------------------------------------------------------------
    // Condicao de branch -- depende de funct3
    // -------------------------------------------------------------------------
    always_comb begin
        case (id_ex.funct3)
            3'h0: branch_taken =  zero;            // BEQ
            3'h1: branch_taken = ~zero;            // BNE
            3'h4: branch_taken =  alu_result[0];   // BLT  (SLT=1 se a<b)
            3'h5: branch_taken = ~alu_result[0];   // BGE
            3'h6: branch_taken =  alu_result[0];   // BLTU
            3'h7: branch_taken = ~alu_result[0];   // BGEU
            default: branch_taken = zero;
        endcase
    end

    // -------------------------------------------------------------------------
    // Alvo do salto:
    //   JALR          -> ALUResult (rs1 + imm), bit 0 forcado a 0
    //   JAL / B-type  -> PC + imm_ext
    // -------------------------------------------------------------------------
    logic is_jalr;
    assign is_jalr = id_ex.jal_src & id_ex.alu_srcb; // JalSrc=1 e ALUSrcb=1 -> JALR

    assign branch_target = is_jalr ? {alu_result[31:1], 1'b0}
                                   : id_ex.pc + id_ex.imm_ext;

    assign pc_src = id_ex.branch && branch_taken;

    // =========================================================================
    // Registrador EX/MEM
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem.mem_to_reg  <= 1'b0;
            ex_mem.reg_write   <= 1'b0;
            ex_mem.mem_read    <= 1'b0;
            ex_mem.mem_write   <= 1'b0;
            ex_mem.jal_src     <= 1'b0;
            ex_mem.alu_result  <= 32'b0;
            ex_mem.write_data  <= 32'b0;
            ex_mem.pc_plus4    <= 32'b0;
            ex_mem.rd          <= 5'b0;
            ex_mem.funct3      <= 3'b0;
        end else begin
            ex_mem.mem_to_reg  <= id_ex.mem_to_reg;
            ex_mem.reg_write   <= id_ex.reg_write;
            ex_mem.mem_read    <= id_ex.mem_read;
            ex_mem.mem_write   <= id_ex.mem_write;
            ex_mem.jal_src     <= id_ex.jal_src;
            ex_mem.alu_result  <= alu_result;
            ex_mem.write_data  <= fwd_srcb;
            ex_mem.pc_plus4    <= id_ex.pc_plus4;
            ex_mem.rd          <= id_ex.rd;
            ex_mem.funct3      <= id_ex.funct3;
        end
    end

    // =========================================================================
    // MEM -- Memoria de dados + MMIO
    // =========================================================================
    assign mmio_sel = ex_mem.alu_result[10];

    pl_dmem dmem (
        .clk       (clk),
        .MemWrite  (ex_mem.mem_write & ~mmio_sel),
		.MenRead   (ex_mem.mem_read & ~mmio_sel),
        .addr      (ex_mem.alu_result[9:2]),
		.ByteOffset(ex_mem.alu_result[1:0]),
        .WriteData (ex_mem.write_data),
		.funct3    (ex_mem.funct3),
        .ReadData  (dmem_rd)//output mem
    );

    pl_mmio mmio (
        .clk       (clk),
        .rst_n     (rst_n),
        .MemWrite  (ex_mem.mem_write &  mmio_sel),
        .MemRead   (ex_mem.mem_read  &  mmio_sel),
        .addr      (ex_mem.alu_result[4:2]),
        .WriteData (ex_mem.write_data),
        .SW        (SW),
        .KEY       (KEY),
        .ReadData  (mmio_rd),
        .LEDR      (LEDR),
        .LEDG      (LEDG),
        .UART_TXD  (UART_TXD),
        .UART_RXD  (UART_RXD)
    );
	
	always_comb begin
		case(ex_mem.alu_result[1:0])
			2'b00: selected_byte = dmem_rd[7:0];
			2'b01: selected_byte = dmem_rd[15:8];
			2'b10: selected_byte = dmem_rd[23:16];
			2'b11: selected_byte = dmem_rd[31:24];
		endcase
		case(ex_mem.alu_result[1])
			1'b0: selected_half = dmem_rd[15:0];
			1'b1: selected_half = dmem_rd[31:16];
		endcase
	end
	
	always_comb begin
		    if (!ex_mem.mem_read)
				load_data = 32'b0;
		else begin
			case(ex_mem.funct3)
				3'b000: load_data = {{24{selected_byte[7]}},selected_byte};//Lb
				3'b001: load_data = {{16{selected_half[15]}},selected_half};// LH
				3'b010:	load_data = dmem_rd;// LW
				3'b100: load_data = {24'b0,selected_byte};// LBU
				3'b101: load_data = {16'b0,selected_half};// LHU
				default:load_data = dmem_rd;
			endcase
		end
	end
		
	
    assign mem_read_data = mmio_sel ? mmio_rd : load_data;

    assign mem_wr_en   = ex_mem.mem_write & ~mmio_sel;
    assign mem_wr_addr = ex_mem.alu_result[9:2];
    assign mem_wr_data = ex_mem.write_data;

    // =========================================================================
    // Registrador MEM/WB
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb.mem_to_reg <= 1'b0;
            mem_wb.reg_write  <= 1'b0;
            mem_wb.jal_src    <= 1'b0;
            mem_wb.alu_result <= 32'b0;
            mem_wb.read_data  <= 32'b0;
            mem_wb.pc_plus4   <= 32'b0;
            mem_wb.rd         <= 5'b0;
        end else begin
            mem_wb.mem_to_reg <= ex_mem.mem_to_reg;
            mem_wb.reg_write  <= ex_mem.reg_write;
            mem_wb.jal_src    <= ex_mem.jal_src;
            mem_wb.alu_result <= ex_mem.alu_result;
            mem_wb.read_data  <= mem_read_data;
            mem_wb.pc_plus4   <= ex_mem.pc_plus4;
            mem_wb.rd         <= ex_mem.rd;
        end
    end

    // WB: mux definido no bloco ID (wb_data)

endmodule