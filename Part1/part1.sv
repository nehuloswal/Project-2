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

module memory_control_xf(clk, reset, s_valid_x, s_ready_x, m_addr_x, ready_write, conv_done, read_done);
  parameter LOGSIZE = 6, SIZE = 8;
  input clk, reset, s_valid_x, conv_done;
  output logic s_ready_x, read_done, ready_write;
  output logic [LOGSIZE - 1:0] m_addr_x;
  logic overflow;

  always_comb begin
    if (reset) 
      ready_write = 0;
    else if (s_ready_x == 1 && s_valid_x == 1 && read_done == 0)
      ready_write = 1;
  	else if (read_done)
  		ready_write = 0;
    else
      ready_write = 0;
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      s_ready_x <= 0;
      m_addr_x <= 0;
     // ready_write <= 0;
      m_addr_x <= 0;
     // read_done <= 0;
      overflow <= 0;
    end
    else begin 
      if (ready_write == 1) begin
        m_addr_x <= m_addr_x + 1;
      end
      if (m_addr_x < (SIZE) && (overflow == 0)) begin
        s_ready_x <= 1;
        // read_done <= 0;
      end 
       if (overflow) begin
      	s_ready_x <= 0;
        //read_done <= 1;
      end
        if (conv_done == 1) begin
          s_ready_x <= 1;
          m_addr_x <= 0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      overflow <= 0;
      read_done <= 0;
    end
    else if (m_addr_x == (SIZE-1) && (ready_write == 1)) begin
      overflow <= 1;
      read_done <= 1;
    end
    if (conv_done == 1) begin
      overflow <= 0;
      read_done <= 0;
    end
  end
endmodule

module conv_control(reset, clk, m_addr_read_x, m_addr_read_f, conv_done, read_done_x, read_done_f, m_valid_y, m_ready_y, en_acc, clr_acc);
  input reset, clk, read_done_x, read_done_f, m_ready_y;
  output logic [2:0] m_addr_read_x;
  output logic [1:0] m_addr_read_f;
  output logic conv_done, m_valid_y, en_acc, clr_acc;
  logic hold_state;
  logic [2:0] number_x;

  always_ff @(posedge clk) begin
    if (reset == 1) begin
      m_addr_read_f <= 0;
      m_addr_read_x <= 0;
      conv_done <= 0;
      m_valid_y <= 0;
      en_acc <= 0;
      clr_acc <= 1;
      number_x <= 1;
    end
    else begin 
      if (read_done_x && read_done_f && hold_state == 0 && m_valid_y == 0) begin
        en_acc <= 1;
        clr_acc <= 0;
        m_addr_read_x <= m_addr_read_x + 1;
        m_addr_read_f <= m_addr_read_f + 1;
      end
      if ((m_addr_read_f == 3) && (hold_state == 0)) begin
        m_addr_read_x <= number_x;
        number_x <= number_x + 1;
        m_addr_read_f <= 0;
        m_valid_y <= 1;
      end
      if ((number_x == 5) && (m_addr_read_f == 3) && hold_state != 1) begin
        conv_done <= 1;
        en_acc <= 0;
       // m_addr_read_x <= 0;
        //m_addr_read_f <= 0;
      end
      if ((m_valid_y == 1) && (m_ready_y == 0)) begin
        hold_state <= 1;
        en_acc <= 0;
      end
      else begin
        hold_state <= 0;
        en_acc <= 1;
      end
      if ((m_valid_y == 1) && (m_ready_y == 1)) begin
        m_valid_y <= 0;
        conv_done <= 0;
        clr_acc <= 1;
      end
    end
  end
endmodule

module convolutioner(clk, reset, m_addr_read_x, m_addr_read_f, m_data_out_y, en_acc, clr_acc, m_data_x, m_data_f);
  input clk, reset, en_acc, clr_acc;
  input [2:0] m_addr_read_x;
  input [1:0] m_addr_read_f;
  output logic signed [17:0] m_data_out_y;
  input signed [7:0] m_data_x;
  input signed [7:0] m_data_f;
  logic signed [15:0] w_mult_op;
  logic signed[17:0] w_addr_op;

  always_comb begin
    if (reset) begin
      w_addr_op = 0;
      w_mult_op = 0;
      m_data_out_y = 0;
    end
    else if (clr_acc) begin
      w_addr_op = 0;
      w_mult_op = 0;
      m_data_out_y = 0;
    end
    else if (en_acc) begin
      w_mult_op = m_data_x * m_data_f;
      w_addr_op = w_mult_op + m_data_out_y;
      m_data_out_y = w_addr_op;
    end
  end


  /*always_ff @(posedge clk) begin
    if (reset) begin
      m_data_out_y <= 0;
    end
    else if (clr_acc) begin
      m_data_out_y <= 0;
    end
    else if (en_acc)
      m_data_out_y <= w_addr_op;
  end*/
endmodule

module conv_8_4(clk, reset, s_data_in_x, s_valid_x, s_ready_x, s_data_in_f, s_valid_f, s_ready_f, m_data_out_y, m_valid_y, m_ready_y);
  input clk, reset, s_valid_x, s_valid_f, m_ready_y;
  input signed [7:0] s_data_in_x, s_data_in_f;
  output s_ready_x, s_ready_f, m_valid_y;
  output signed [17:0] m_data_out_y;
  logic [7:0] w_to_multx, w_to_multf;
  logic w_wr_en_x, w_wr_en_f, w_conv_done, w_read_done_x, w_read_done_f;
  logic [2:0] w_to_addrx, w_read_addr_x, w_write_addr_x;
  logic [1:0] w_to_addrf, w_read_addr_f, w_write_addr_f;
  logic e_acc,c_acc;

  always_comb begin
    if (w_wr_en_x == 0)
      w_to_addrx = w_read_addr_x;
    else
      w_to_addrx = w_write_addr_x;
    if (w_wr_en_f == 0)
      w_to_addrf = w_read_addr_f;
    else
      w_to_addrf = w_write_addr_f;
  end
  memory #(8, 8, 3) mx (.clk(clk), .data_in(s_data_in_x), .data_out(w_to_multx), .addr(w_to_addrx), .wr_en(w_wr_en_x));
  memory #(8, 4, 2) mf (.clk(clk), .data_in(s_data_in_f), .data_out(w_to_multf), .addr(w_to_addrf), .wr_en(w_wr_en_f));

  memory_control_xf #(3, 8) cx (.clk(clk), .reset(reset), .s_valid_x(s_valid_x), .s_ready_x(s_ready_x), .m_addr_x(w_write_addr_x), .ready_write(w_wr_en_x), .conv_done(w_conv_done), .read_done(w_read_done_x));

  memory_control_xf #(2, 4) cf (.clk(clk), .reset(reset), .s_valid_x(s_valid_f), .s_ready_x(s_ready_f), .m_addr_x(w_write_addr_f), .ready_write(w_wr_en_f), .conv_done(w_conv_done), .read_done(w_read_done_f));

  conv_control cc(.reset(reset), .clk(clk), .m_addr_read_x(w_read_addr_x), .m_addr_read_f(w_read_addr_f), .conv_done(w_conv_done), .read_done_x(w_read_done_x), .read_done_f(w_read_done_f), .m_valid_y(m_valid_y), .m_ready_y(m_ready_y), .en_acc(e_acc), .clr_acc(c_acc));

  convolutioner conv(.clk(clk), .reset(reset), .m_addr_read_x(w_to_addrx), .m_addr_read_f(w_to_addrf), .m_data_out_y(m_data_out_y), .en_acc(e_acc), .clr_acc(c_acc), .m_data_x(w_to_multx), .m_data_f(w_to_multf));
endmodule