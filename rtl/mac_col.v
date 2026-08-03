// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_col (free_clk, gated_clk, reset, out, q_in, q_out, i_inst, fifo_wr, o_inst, zero_weight);

parameter bw = 8;
parameter bw_psum = 2*bw+6; // For sum of 8 product, we only need 3 extra space for carry out.
parameter pr = 8;
parameter col_id = 0;

output signed [bw_psum-1:0] out;
input  signed [pr*bw-1:0] q_in;
output signed [pr*bw-1:0] q_out;
input  free_clk, reset;
input gated_clk;
input  [1:0] i_inst; // [1]: execute, [0]: load 
output [1:0] o_inst; // [1]: execute, [0]: load 
output fifo_wr;
output   zero_weight;

reg    load_ready_q;
reg    [3:0] cnt_q;
reg    [1:0] inst_q;
reg    [1:0] inst_2q;

reg   signed [pr*bw-1:0] query_q;
reg   signed [pr*bw-1:0] key_q;
wire  signed [bw_psum-1:0] psum;
// Pipelining
reg [1:0] inst_3q;
reg [1:0] inst_4q;
reg [1:0] inst_5q;

// Reverted to baseline delays
assign o_inst  = inst_q;
assign fifo_wr = inst_5q[1];
assign q_out   = query_q;
assign out     = psum;

// Instantiating the combinational mac_8in
mac_8in #(.bw(bw), .bw_psum(bw_psum), .pr(pr)) mac_16in_instance (
  .a(query_q), 
  .b(key_q),
	.out(psum),
	.clk(gated_clk),
	.reset(reset)
); 
reg zero_weight0;
reg zero_weight1;
reg zero_weight2;
reg zero_w_t;

assign zero_weight = zero_weight2 ? zero_w_t : 0;

always @ (posedge gated_clk) begin
  if (reset) begin
    cnt_q <= 0;
    load_ready_q <= 1;
    zero_w_t <= 0;
    zero_weight0 <= 1'b0;
  end
  else begin
    if (inst_q[0]) begin
       if (cnt_q == 9-col_id)begin
         cnt_q <= 0;
         key_q <= q_in;
         load_ready_q <= 0;
         if(q_in == 0) begin
          zero_w_t <= 1'b1;
          zero_weight0 <= 1'b1;
         end
       end
       else if (load_ready_q)
         cnt_q <= cnt_q + 1;
    end
  end
end

always @ (posedge free_clk) begin
	if(reset) begin
		inst_q <= 0;
		inst_2q <= 0;
		inst_3q <= 0;
		inst_4q <= 0;
		inst_5q <= 0;
		query_q <= 0;
		zero_weight1 <= 0;
		zero_weight2 <= 0;
	end
  	else begin
  	  	inst_q <= i_inst;
  	  	inst_2q <= inst_q;
  	  	inst_3q <= inst_2q;
  	  	inst_4q <= inst_3q;
  	  	inst_5q <= inst_4q;
        zero_weight1 <= zero_weight0;
        zero_weight2 <= zero_weight1;
    		if (inst_q[0]) begin
			query_q <= q_in;
		end
		if(inst_q[1] && !inst_q[0] ) begin
			query_q <= q_in;
		end
	end
end

endmodule