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

module memory_control_xf(clk, reset, s_valid_x, s_ready_x, m_addr_x, ready_write, conv_done);
	parameter LOGSIZE = 6, SIZE = 8;
	input clk, reset, s_valid_x, ready;
	output s_ready_x, wen;
	output [LOGSIZE - 1:0] m_addr_x;
	logic count, conv_done;

	always_ff @(posedge clk) begin
		if (reset) begin
			s_ready_x <= 0;
			m_addr_x <= 0;
			ready_write <= 0;
			m_addr_x <= 0;
		end 
		else begin
			if(s_ready_x == 1 && s_valid_x == 1)
				ready_write <= 1;
			else
				ready_write <= 0;
		end
		if (ready_write == 1)
			m_addr_x <= m_addr_x + 1;
		if (m_addr_x < (SIZE - 1)) 
			s_ready_x <= 1;
		else 
			s_ready_x <= 0;
		if (conv_done == 1) begin
			s_ready_x <= 1;
			m_addr_x <= 0;
		end
	end
endmodule

module conv_control();
endmodule

module conv_8_4(clk, reset, s_data_in_x, s_valid_x, s_ready_x, s_data_in_f, s_valid_f, s_ready_f, m_data_out_y, m_valid_y, m_ready_y);
	input clk, reset, s_valid_x, s_valid_f, m_ready_y;
	input signed [7:0] s_data_in_x, s_data_in_f;
	output s_ready_x, s_ready_f, m_valid_y;
	output signed [17:0]m_data_out_y;

	memory m1 (.clk(clk), .data_in)