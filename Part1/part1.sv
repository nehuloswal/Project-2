module memory(clk, data_in, data_out, addr, wr_en);
	parameter WIDTH=16, SIZE=64, LOGSIZE=6;
	input [WIDTH-1:0] data_in;
	output logic [WIDTH-1:0] data_out;
	input [LOGSIZE-1:0] addr;
	input clk, wr_en;
	logic [SIZE-1:0][WIDTH-1:0] mem;
	always_ff @(posedge clk) begin 
		data_out <= mem[addr];
		if (wr_en)
			mem[addr] <= data_in; 
	end
endmodule

module memory_control_x(clk, reset, s_valid_x, s_ready_x, m_addr_x, c_addr_x);
	input clk, reset
endmodule

module memory_control_f();
endmodule

module conv_8_4(clk, reset, s_data_in_x, s_valid_x, s_ready_x, s_data_in_f, s_valid_f, s_ready_f, m_data_out_y, m_valid_y, m_ready_y);
	input clk, reset, s_valid_x, s_valid_f, m_ready_y;
	input signed [7:0] s_data_in_x, s_data_in_f;
	output s_ready_x, s_ready_f, m_valid_y;
	output signed [17:0]m_data_out_y;

	memory m1 (.clk(clk), .data_in)