// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module fullchip (clk, mem_in0, mem_in1, inst, reset, out);

parameter col = 8;
parameter bw = 8;
parameter bw_psum = 2*bw+4;
parameter pr = 16;

input  clk; 
input  [pr*bw-1:0] mem_in0; 
input  [pr*bw-1:0] mem_in1; 
input  [18:0] inst; 
input  reset;
output [2*bw_psum*col-1:0] out;

// FIFO CONTROL
wire sfp_fifo_rd_core0;
wire sfp_fifo_rd_core1;
assign sfp_fifo_rd_core0 = 1'b1;
assign sfp_fifo_rd_core1 = 1'b1;

// SUM SIGNALS
wire [bw_psum+3:0] sum_out_core0;
wire [bw_psum+3:0] sum_out_core1;

wire [bw_psum+3:0] sum_core0_to_core1;
wire [bw_psum+3:0] sum_core1_to_core0;  

wire sum0_busy;
wire sum1_busy;

wire send0;
wire send1;

// CDC: core0 -> core1
cdc_4phase #(.bw(bw), .bw_psum(bw_psum)) cdc0 (
    .clk_src(clk),                // assume same clk for simplicity
    .clk_dest(clk),
    .reset_src(reset),
    .reset_dest(reset),
    .data_in(sum_out_core0),
    .send(send0),                  // always send sum
    .data_out(sum_core0_to_core1),
    .busy(sum0_busy)
);

// CDC: core1 -> core0
cdc_4phase #(.bw(bw), .bw_psum(bw_psum)) cdc1 (
    .clk_src(clk),
    .clk_dest(clk),
    .reset_src(reset),
    .reset_dest(reset),
    .data_in(sum_out_core1),
    .send(send1),                  // always send sum
    .data_out(sum_core1_to_core0),
    .busy(sum1_busy)
);


core #(.bw(bw), .bw_psum(bw_psum), .col(col), .pr(pr)) core_instance0 (
      .reset(reset), 
      .clk(clk), 
      .mem_in(mem_in0), 
      .inst(inst),
      .out(out[col*bw_psum-1:0]),
      .sum_out(sum_out_core0),
      .sum_in(sum_out_core1),
      // .sum_in(sum_core1_to_core0),
      .sfp_fifo_rd(sfp_fifo_rd_core0),
      .sum_valid(send0)
);

core #(.bw(bw), .bw_psum(bw_psum), .col(col), .pr(pr)) core_instance1 (
      .reset(reset), 
      .clk(clk), 
      .mem_in(mem_in1), 
      .inst(inst),
      .out(out[2*bw_psum*col-1:bw_psum*col]),
      .sum_out(sum_out_core1),
      .sum_in(sum_out_core0),
      // .sum_in(sum_core0_to_core1),
      .sfp_fifo_rd(sfp_fifo_rd_core1),
      .sum_valid(send1)
);

endmodule
