// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module fullchip (clk0, mem_in0, inst0, reset0, out0, clk1, mem_in1, inst1, reset1, out1);

parameter col = 8;
parameter bw = 8;
parameter bw_psum = 2*bw+4;
parameter pr = 8;

input  clk0, clk1; 
input  [pr*bw-1:0] mem_in0; 
input  [pr*bw-1:0] mem_in1; 
input  [20:0] inst0; 
input  [20:0] inst1;
input  reset0, reset1;
output [bw_psum*col-1:0] out0;
output [bw_psum*col-1:0] out1;

wire [bw_psum+3:0] x01_data;
wire x01_req;
wire x01_ack;
wire [bw_psum+3:0] x10_data;
wire x10_req;
wire x10_ack;

core #(.bw(bw), .bw_psum(bw_psum), .col(col), .pr(pr)) core_instance0 (
      .reset(reset0), 
      .clk(clk0), 
      .mem_in(mem_in0), 
      .inst(inst0),
      .out(out0),
      .tx_data(x01_data),
      .tx_req(x01_req),
      .tx_ack(x01_ack),
      .rx_data(x10_data),
      .rx_req(x10_req),
      .rx_ack(x10_ack)
);

core #(.bw(bw), .bw_psum(bw_psum), .col(col), .pr(pr)) core_instance1 (
      .reset(reset1), 
      .clk(clk1), 
      .mem_in(mem_in1), 
      .inst(inst1),
      .out(out1),
      .tx_data(x10_data),
      .tx_req(x10_req),
      .tx_ack(x10_ack),
      .rx_data(x01_data),
      .rx_req(x01_req),
      .rx_ack(x01_ack)

);

endmodule
