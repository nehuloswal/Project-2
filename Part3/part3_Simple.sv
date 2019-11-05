// Peter Milder, 10/4/19
// Testbench for ESE 507 Project 2 Part 2

// This testbench does the following:
//    - opens file random_in_f.hex and random_in_x.hex (input values to simulate) and stores 
//      their values in arrays
//    - opens expected_out.hex (expected output values) and stores its values in an array
//    - on each clock cycle, randomly picks values for valid and ready control signals
//    - uses these random control values to decide when to give new input and receive output
//    - automatically check expected output is correct
module memory(clk, data_in, data_out, addr, wr_en);
  parameter WIDTH=16, SIZE=64, LOGSIZE=6;
  input [WIDTH-1:0] data_in;
  output logic signed [WIDTH-1:0] data_out [3:0];
  input [LOGSIZE-1:0] addr;
  input clk, wr_en;
  logic [SIZE-1:0][WIDTH-1:0] mem;
  always_ff @(posedge clk) begin
    for (int i = 0;i < 4;i++) 
      data_out[i] <= mem[addr + i];
    if (wr_en)
      mem[addr] <= data_in; 
  end
endmodule

module memory_control_xf(clk, reset, s_valid_x, s_ready_x, m_addr_x, ready_write, conv_done, read_done, valid_y, wait_on_another);
  parameter LOGSIZE = 6, SIZE = 8;
  input clk, reset, s_valid_x, conv_done, valid_y, wait_on_another;
  output logic s_ready_x, read_done, ready_write;
  output logic [LOGSIZE - 1:0] m_addr_x;
  logic overflow;

  always_comb begin
    if (reset) begin 
      ready_write = 0;
    end
    else if (s_ready_x == 1 && s_valid_x == 1 && read_done == 0)
      ready_write = 1;
    else
      ready_write = 0;
  end

  always_comb begin
    if (reset || overflow) 
      s_ready_x = 0;
    else if ((m_addr_x < (SIZE) && (overflow == 0)) /*|| (conv_done == 1 && valid_y == 0)*/) 
      s_ready_x = 1;
    else
      s_ready_x = 0;
  end

  always_ff @(posedge clk) begin
    if (reset) begin;
      m_addr_x <= 0;
      
    end
    else  if (ready_write == 1) begin
        m_addr_x <= m_addr_x + 1;
      end
    /*else if (conv_done == 1 && valid_y == 0) begin
          m_addr_x <= 0;
      end*/
    end

  always_ff @(posedge clk) begin
    if (reset) begin
      overflow <= 0;
      read_done <= 0;
    end
    else if (conv_done == 1 && ready_write == 0 && wait_on_another && valid_y == 0) begin
      overflow <= 0;
      read_done <= 0;
    end    
    else if (m_addr_x == (SIZE-1) && (ready_write == 1)) begin
      overflow <= 1;
      read_done <= 1;
    end
  end
endmodule

module conv_control(reset, clk, m_addr_read_x, m_addr_read_f, conv_done, read_done_x, read_done_f, m_valid_y, m_ready_y, en_acc, clr_acc);
  input reset, clk, read_done_x, read_done_f, m_ready_y;
  output logic [2:0] m_addr_read_x;
  output logic [1:0] m_addr_read_f;
  output logic conv_done, m_valid_y, en_acc, clr_acc;
  logic hold_state, en_val_y, dis_conv_y;
  logic [6:0] number_x;

  always_ff @(posedge clk) begin
    if (reset == 1) begin
      m_addr_read_f <= 0;
      m_addr_read_x <= 0;
      conv_done <= 0;
      m_valid_y <= 0;
      en_acc <= 0;
      clr_acc <= 1;
      number_x <= 1;
      en_val_y <= 0;
    end
    else begin 
      
      if (read_done_x && read_done_f && hold_state == 0 && m_valid_y == 0 && en_val_y == 0) begin
        en_acc <= 1;
        clr_acc <= 0;
        m_addr_read_x <= m_addr_read_x + 1;
        en_val_y <= 1; 
      end
      /*if ((m_addr_read_f == 31) && (hold_state == 0) && en_val_y == 0 && m_valid_y == 0) begin
        m_addr_read_x <= number_x;
        number_x <= number_x + 1;
        m_addr_read_f <= 0;
        en_val_y <= 1;
      end*/
      if ((m_addr_read_x == 5) /*&& (m_addr_read_f == 31)*/ && hold_state != 1) begin
        conv_done <= 1;  
        en_acc <= 0;        
        m_addr_read_x <= 0;
        m_addr_read_f <= 0;
       // number_x <= 1;
      end
     if (en_val_y) begin
     	if (m_addr_read_x < 5 || hold_state == 1) begin
        	m_valid_y <= 1;
        	en_val_y <= 0;
        	en_acc <= 0;
    	end
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
        dis_conv_y <= 1;
        clr_acc <= 1;
      end
      if (dis_conv_y) begin
        conv_done <= 0;
        dis_conv_y <= 0;
      end
      if (en_val_y == 1)
        en_acc <= 0;
    end
  end
endmodule

module convolutioner(clk, reset, m_addr_read_x, m_addr_read_f, m_data_out_y, en_acc, clr_acc, m_data_x, m_data_f);
  input clk, reset, en_acc, clr_acc;
  input [2:0] m_addr_read_x;
  input [1:0] m_addr_read_f;
  output logic signed [17:0] m_data_out_y;
  input signed [7:0] m_data_x [3:0];
  input signed [7:0] m_data_f [3:0];
  logic signed [15:0] w_mult_op [3:0];
  logic signed [17:0] w_addr_op;
genvar i;
generate
for(i = 0; i < 4; i++) begin
  always_comb begin
    if (reset) begin
     // w_addr_op = 0;
      w_mult_op[i] = 0;
    end
    else if (clr_acc) begin
    //  w_addr_op = 0;
      w_mult_op[i] = 0;
    end
    else if (en_acc) 
        w_mult_op[i] = m_data_x[i] * m_data_f[i];
    else
        w_mult_op[i] = 0;
    end
  end
  endgenerate

  always_comb begin
    if (reset) begin
     // w_addr_op = 0;
      w_addr_op = 0;
    end
    else if (clr_acc) begin
    //  w_addr_op = 0;
      w_addr_op = 0;
    end
    else if (en_acc) 
       w_addr_op = w_mult_op[0] + w_mult_op[1] + w_mult_op[2] + w_mult_op[3];
    else
        w_addr_op = 0;
    end

  //assign w_addr_op = w_mult_op[0] + w_mult_op[1] + w_mult_op[2] + w_mult_op[3];


/*genvar j
generate
for(j = 0; j < 4; j++)
  always_comb begin
    if (reset) begin
      w_addr_op = 0;
      //w_mult_op = 0;
    end
    else if (clr_acc) begin
     w_addr_op = 0;
      w_mult_op = 0;
    end
    else if (en_acc) begin
        w_mult_op[i] = m_data_x[i][7:0] * m_data_f[i][7:0];
    else
        w_mult_op[i] = 0;
    end
  endgenerate*/



      //w_addr_op = w_mult_op[0][15:0] + w_mult_op[1][15:0] + w_mult_op[2][15:0] + w_mult_op[3][15:0];
      /*+ w_mult_op[4] + w_mult_op[5] + w_mult_op[7] + w_mult_op[8] + 
        w_mult_op[9] + w_mult_op[10] + w_mult_op[11] + w_mult_op[12] + w_mult_op[13] + w_mult_op[14] + w_mult_op[15] + w_mult_op[16] +
        w_mult_op[17] + w_mult_op[18] + w_mult_op[19] + w_mult_op[20] + w_mult_op[21] + w_mult_op[22] + w_mult_op[23] + w_mult_op[24] +
        w_mult_op[25] + w_mult_op[26] + w_mult_op[27] + w_mult_op[28] + w_mult_op[29] + w_mult_op[30] + w_mult_op[31]*/;
    /*end
   else
    w_addr_op = m_data_out_y;
  end*/

  always_ff @(posedge clk) begin
    if (reset || (clr_acc == 1))
      m_data_out_y <= 0;
    else if (en_acc)
      m_data_out_y <= w_addr_op;
    else
      m_data_out_y <= m_data_out_y;
  end
endmodule

module conv_8_4(clk, reset, s_data_in_x, s_valid_x, s_ready_x, s_data_in_f, s_valid_f, s_ready_f, m_data_out_y, m_valid_y, m_ready_y);
  input clk, reset, s_valid_x, s_valid_f, m_ready_y;
  input signed [7:0] s_data_in_x, s_data_in_f;
  output s_ready_x, s_ready_f, m_valid_y;
  output signed [17:0] m_data_out_y;
  logic signed [7:0] w_to_multf  [3:0];
  logic signed [7:0] w_to_multx [3:0];
  logic w_wr_en_x, w_wr_en_f, w_conv_done, w_read_done_x, w_read_done_f;
  logic [2:0] w_to_addrx, w_read_addr_x, w_write_addr_x;
  logic [1:0] w_to_addrf, w_read_addr_f, w_write_addr_f;
  logic e_acc,c_acc;

  always_comb begin
    if (w_wr_en_x == 1)
      w_to_addrx = w_write_addr_x;
    else
      w_to_addrx = w_read_addr_x;
    if (w_wr_en_f == 1)
      w_to_addrf = w_write_addr_f;
    else
      w_to_addrf = w_read_addr_f;
  end
  memory #(8, 8, 3) mx (.clk(clk), .data_in(s_data_in_x), .data_out(w_to_multx), .addr(w_to_addrx), .wr_en(w_wr_en_x));
  memory #(8, 4, 2) mf (.clk(clk), .data_in(s_data_in_f), .data_out(w_to_multf), .addr(w_to_addrf), .wr_en(w_wr_en_f));

  memory_control_xf #(3, 8) cx (.clk(clk), .reset(reset), .s_valid_x(s_valid_x), .s_ready_x(s_ready_x), .m_addr_x(w_write_addr_x), .ready_write(w_wr_en_x), .conv_done(w_conv_done), .read_done(w_read_done_x), .valid_y(m_valid_y), .wait_on_another(w_read_done_f));

  memory_control_xf #(2, 4) cf (.clk(clk), .reset(reset), .s_valid_x(s_valid_f), .s_ready_x(s_ready_f), .m_addr_x(w_write_addr_f), .ready_write(w_wr_en_f), .conv_done(w_conv_done), .read_done(w_read_done_f), .valid_y(m_valid_y), .wait_on_another(w_read_done_x));

  conv_control cc(.reset(reset), .clk(clk), .m_addr_read_x(w_read_addr_x), .m_addr_read_f(w_read_addr_f), .conv_done(w_conv_done), .read_done_x(w_read_done_x), .read_done_f(w_read_done_f), .m_valid_y(m_valid_y), .m_ready_y(m_ready_y), .en_acc(e_acc), .clr_acc(c_acc));

  convolutioner conv(.clk(clk), .reset(reset), .m_addr_read_x(w_to_addrx), .m_addr_read_f(w_to_addrf), .m_data_out_y(m_data_out_y), .en_acc(e_acc), .clr_acc(c_acc), .m_data_x(w_to_multx), .m_data_f(w_to_multf));
endmodule

module check_timing();

    logic clk, s_valid_x, s_valid_f, s_ready_x, s_ready_f, m_valid_y, m_ready_y, reset;
    logic signed [7:0] s_data_in_x, s_data_in_f;
    logic signed [17:0] m_data_out_y;
   
    initial clk=0;
    always #5 clk = ~clk;
   

    conv_8_4 dut (.clk(clk), .reset(reset), 
                  .s_data_in_x(s_data_in_x),   .s_valid_x(s_valid_x), .s_ready_x(s_ready_x),
                  .s_data_in_f(s_data_in_f),   .s_valid_f(s_valid_f), .s_ready_f(s_ready_f),
                  .m_data_out_y(m_data_out_y), .m_valid_y(m_valid_y), .m_ready_y(m_ready_y));



    //////////////////////////////////////////////////////////////////////////////////////////////////
    // code to feed some test inputs
  
    // rb, rb2, and rb3 represent random bits. Each clock cycle, we will randomize the value of these bits.
    // We will use rb to determine when to let our testbench send new x data. (When rb==0, we will not send valid data)
    // We will use rb2 to determine when to let our testbench send new f data. (When rb2==0, we will not send valid data)
    // We will use rb3 to determine when to let our testbench receive new y data. (When rb3==0, we will not receive results)
    logic rb, rb2, rb3;
    integer ignore;
    always begin
       @(posedge clk);
       #1;
       ignore = std::randomize(rb, rb2, rb3); // randomize rb
    end

    // Put our test data into these arrays. These are the values we will feed as input into the system.
    // We will do two tests; each will take 8 values for x and 4 values for f.
    logic [7:0] invals_x[0:31] = '{10,-20,30,-40,50,60,70,80, -90, 100, -110, 120, -50, 40, 30, -20, 1, 2, 3, 4, 5, 6, 7, 8, 11, 22, 33, 44, 55, 66, 77, 88};
    logic [7:0] invals_f[0:15] = '{10,20,-30,40, -50, -60, 70, 80, 1, 1, 1, 1, 1, 1, 1, 1}; 

    logic signed [17:0] expectedOut[0:19] = '{-2800, 3600, 400, 1600, 2800, 400, 6000, -2000, 2200, 600, 10, 14, 18, 22, 26, 110, 154, 198, 242, 286};
    
    logic [15:0] x_count;

    /////////////////////////
    // Setting values for input x

    // If our random bit rb is set to 1, and if x_count is within the range of our test vector (invals),
    // we will set s_valid_x to 1.
    always @* begin
       if ((x_count>=0) && (x_count<32) && (rb==1'b1)) begin
          s_valid_x=1;
       end
       else
          s_valid_x=0;
    end

    // If s_valid_x is set to 1, we will put data on s_data_in_x.
    // If s_valid_x is 0, we will put an X on the data_in to test that your system does not 
    // process the invalid input.
    always @* begin
       if (s_valid_x == 1)
          s_data_in_x = invals_x[x_count];
       else
          s_data_in_x = 'x;
    end

    // If we set s_valid_x and s_ready_x asserted on this clock edge, we will increment x_count just after
    // this clock edge.
    always @(posedge clk) begin
       if (s_valid_x && s_ready_x)
          x_count <= #1 x_count+1;
    end


    ////////////////////////
    // Setting values for input f

    // Same logic but with f_count and s_data_in_f
    
    logic [15:0] f_count;
    always @* begin
       if ((f_count>=0) && (f_count < 16) && (rb2==1'b1)) begin
          s_valid_f=1;
       end
       else
          s_valid_f=0;
    end
    always @* begin
       if (s_valid_f == 1)
          s_data_in_f = invals_f[f_count];
       else
          s_data_in_f = 'x;
    end
    always @(posedge clk) begin
       if (s_valid_f && s_ready_f)
          f_count <= #1 f_count+1;
    end


    /////////////////////////////
    // code to receive the output values

    // we will use another random bit (rb3) to determine if we can assert m_ready_y.
    logic [15:0] y_count;
    always @* begin
        if ((y_count >= 0) && (y_count < 20) && (rb3==1'b1))
            m_ready_y = 1;
        else
            m_ready_y = 0;
    end

    always @(posedge clk) begin
        if (m_ready_y && m_valid_y) begin
            if (m_data_out_y !== expectedOut[y_count]) 
                $display("ERROR:   y[%d] = %d    expected output = %d", y_count, m_data_out_y, expectedOut[y_count]);
            else
                $display("SUCCESS: y[%d] = %d", y_count, m_data_out_y);
            y_count = y_count+1; 
        end 
    end

    ////////////////////////////////////////////////////////////////////////////////

    initial begin
        x_count=0; f_count=0; y_count=0;

        // Before first clock edge, initialize
        m_ready_y = 0; 
        reset = 0;
    
        // reset
        @(posedge clk); #1; reset = 1; 
        @(posedge clk); #1; reset = 0; 

        // wait until the outputs have come out, then finish.
        wait(y_count==20);

        // Now we're done!
        
        // Just as a test: wait another 100 cycles and make sure the DUT doesn't assert m_valid again.
        // It shouldn't, because the system finished the inputs it was given, so it should be waiting
        // for new input data.
        repeat(100) begin
            @(posedge clk);
            if (m_valid_y == 1)
                $display("ERROR: DUT asserted m_valid_y incorrectly");
        end
        
        $finish;
    end


    // This is just here to keep the testbench from running forever in case of error.
    // In other words, if your system never produces three outputs, this code will stop 
    // the simulation after 1000 clock cycles.
    initial begin
        repeat(100000) begin
            @(posedge clk);
        end
        $display("Warning: Output not produced within 10000 clock cycles; stopping simulation so it doens't run forever");
        $stop;
    end

endmodule
