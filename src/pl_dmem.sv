// =============================================================================
// pl_dmem.sv
// Memoria de dados -- RV32I pipelined
//
// Capacidade : 256 palavras x 32 bits = 1 KB
// Init file  : data.mif   (sintese Quartus)
//              data.hex   (simulacao ModelSim via $readmemh)
//
// Leitura  : assincrona (combinatorial) -- disponivel no estagio MEM
// Escrita  : sincrona (posedge clk, gated por MemWrite & ~mmio_sel)
// Endereco : alu_result[9:2]  (endereco de palavra de 8 bits)
// =============================================================================

`timescale 1ns / 1ps

module pl_dmem (
    input  logic        clk,
    input  logic        MemWrite,
    input  logic [7:0]  addr,
    input  logic [31:0] WriteData,
	 input  logic [2:0]  funct3,
    output logic [31:0] ReadData
);

    (* ram_init_file = "data.mif" *) logic [31:0] ram [0:255];

    // synthesis translate_off
    initial begin
        for (int i = 0; i < 256; i++) ram[i] = 32'h00000000;
        $readmemh("data.hex", ram);
    end
    // synthesis translate_on

    always@(posedge clk) begin
        if (MemWrite) begin
				case(funct3) begin
					3'b010:ram[addr] <= WriteData;//sw
					3'b000:ram[addr] <= {24{WriteData[7]},WriteData[7:0]};//sb
					3'b001:ram[addr] <= {16{WriteData[15]},WriteData[15:0]};//sh
					default:ram[addr] <= WriteData;
				endcase
		  end
    end

	always_comb begin
		case(funct3) begin
			3'b010: ReadData = ram[addr]; //lw 
			3'b000: ReadData = {24{ram[addr][7]},ram[addr][7:0]}; //lb
			3'b001: ReadData = {16{ram[addr][15]},ram[addr][15:0]}; //lh
			3'b100: ReadData = {24'b0,ram[addr][7:0]}; //lbu
			3'b101: ReadData = {16'b0,ram[addr][15:0]}; //lhu
			default: ReadData = ram[addr];
		endcase
	end
endmodule
