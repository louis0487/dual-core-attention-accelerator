
module sum_xchg.v (clk, reset, sum_xfer, fifo_head, fifo_pop, sum_rx, tx_data, tx_req, tx_ack, rx_data, rx_req, rx_ack);
// synopsys sync_set_reset "reset"
  parameter W = 24;
  localparam [1:0] S_IDLE = 2'd0,
	           S_LOAD = 2'd1,
		   S_WAIT_ACK = 2'd2,
		   S_WAIT_LOW = 2'd3;
  localparam R_IDLE = 1'd0,
	     R_ACK  = 1'd1;

  input  clk, reset, sum_xfer, tx_ack, rx_req;
  input  [W-1:0] fifo_head;
  output reg fifo_pop, tx_req, rx_ack;
  output reg [W-1:0] sum_rx;
  output reg [W-1:0] tx_data;
  input  [W-1:0] rx_data;

  reg [1:0] s_state;
  reg r_state;
  
  wire ack_s;
  wire req_s; 
  
  always@(posedge clk) begin
	if(reset) begin
		s_state  <= S_IDLE;
		tx_data  <= 0;
		tx_req   <= 0;
		fifo_pop <= 0;
	end else begin
		fifo_pop <= 0;
		case(s_state)
			S_IDLE: begin
				if(sum_xfer) begin
					tx_data <= fifo_head;
					s_state <= S_LOAD;
				end
			end
			S_LOAD: begin
				tx_req  <= 1'b1;
				s_state <= S_WAIT_ACK;
			end
			S_WAIT_ACK: begin
				if(ack_s) begin
					tx_req   <= 1'b0;
					fifo_pop <= 1'b1;
					s_state <= S_WAIT_LOW;
				end
			end
			S_WAIT_LOW: begin
				if(ack_s == 1'b0) begin
					s_state <= S_IDLE;
				end
			end
			default: begin
				s_state <= S_IDLE;
			end
		endcase
	end
  end

  always@(posedge clk) begin
	if(reset) begin
		r_state <= R_IDLE;
		sum_rx  <= 0;
		rx_ack  <= 0;
	end else begin
		case(r_state)
			R_IDLE: begin
				if(req_s) begin
					sum_rx  <= rx_data;
					rx_ack  <= 1'b1;
					r_state <= R_ACK;
				end
			end
			R_ACK:  begin
				if(req_s == 1'b0) begin
					rx_ack  <= 1'b0;
					r_state <= R_IDLE;
				end
			end
		endcase
	end
	
  end

endmodule


