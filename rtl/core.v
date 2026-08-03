// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module core (clk, sum_out, mem_in, out, inst, reset, sum_in, sfp_fifo_rd, sum_valid);

parameter col = 8;
parameter bw = 8;
parameter bw_psum = 2*bw+4;
parameter pr = 8;

output [bw_psum+3:0] sum_out;           
output [bw_psum*col-1:0] out;           // partial sum memory
output sum_valid;
wire   [bw_psum*col-1:0] pmem_out;
input  [pr*bw-1:0] mem_in;              // data input bus feeding Query or Keys data into the core
input  clk;
input  [18:0] inst;                     // instruction bus (NEED TO CHANGE FOR MORE INSTRUCTIONS)
input  reset;
input [bw_psum+3:0] sum_in;             // For SFP, sum softmax from cores (STEP 2)
input  sfp_fifo_rd;                 // read enable for sum ofifo (FOR DUAL CORE)

wire  [pr*bw-1:0] mac_in;               // Input into the mac array (this could be key [1] or query [0])
wire  [pr*bw-1:0] kmem_out;             // Key values
wire  [pr*bw-1:0] qmem_out;             // Query values
wire  [bw_psum*col-1:0] pmem_in;        // Input into the psum memory (this could be sfp [1] or mac result from OFIFO [0])
wire  [bw_psum*col-1:0] fifo_out;
wire  [bw_psum*col-1:0] sfp_out;
wire  [bw_psum*col-1:0] array_out;
wire  [col-1:0] fifo_wr;
wire  ofifo_rd;
wire [3:0] qkmem_add;
wire [3:0] pmem_add;

wire  qmem_rd;
wire  qmem_wr; 
wire  kmem_rd;
wire  kmem_wr; 
wire  pmem_rd;
wire  pmem_wr; 

// Step 2: SFP
wire acc;                               // when acc = 1, perform sum_q = |x0| + |x1| + |x2| + ... + |x7|
wire div;                               // when div = 1, normalization 
wire fifo_ext_rd;                       // read signal for external FIFO  (other core sum)
wire [bw_psum+3:0] sfp_sum_in;          // sum from another core (cross-core softmax)
wire [col*bw_psum-1:0] pmem_sfp;        // final normalized output from sfp

assign ofifo_rd = inst[16];
assign qkmem_add = inst[15:12];
assign pmem_add = inst[11:8];

assign qmem_rd = inst[5];
assign qmem_wr = inst[4];
assign kmem_rd = inst[3];
assign kmem_wr = inst[2];
assign pmem_rd = inst[1];
assign pmem_wr = inst[0];
assign sum_valid = div;

assign mac_in  = inst[6] ? kmem_out : qmem_out;         // Chooses whether mac receives Key or Query values
// assign pmem_in = fifo_out;                   // NEEDS FIXING FOR DUAL CORE & SFP (STEP 1 ONLY)
assign pmem_in = inst[18] ? pmem_sfp : fifo_out;     // STEP 2: STORE SFP RESULTS INTO PMEM

// Step 2: Output Normalization 
assign acc = inst[17];
assign div = inst[18];
// assign fifo_ext_rd = 0;         // STEP 2 (SINGLE CORE)
// assign sfp_sum_in = 0;          // STEP 2 (SINGLE CORE)
assign fifo_ext_rd = sfp_fifo_rd;   // FOR DUAL CORE (STEP 4)
assign sfp_sum_in = sum_in; // FOR DUAL CORE (STEP 4)
assign out = pmem_out;

mac_array #(.bw(bw), .bw_psum(bw_psum), .col(col), .pr(pr)) mac_array_instance (
        .in(mac_in), 
        .clk(clk), 
        .reset(reset), 
        .inst(inst[7:6]),     
        .fifo_wr(fifo_wr),     
	.out(array_out)
);

ofifo #(.bw(bw_psum), .col(col))  ofifo_inst (
        .reset(reset),
        .clk(clk),
        .in(array_out),
        .wr(fifo_wr),
        .rd(ofifo_rd),
        .o_valid(fifo_valid),
        .out(fifo_out)
);


sram_w16 #(.sram_bit(pr*bw)) qmem_instance (
        .CLK(clk),
        .D(mem_in),
        .Q(qmem_out),
        .CEN(!(qmem_rd||qmem_wr)),
        .WEN(!qmem_wr), 
        .A(qkmem_add)
);

sram_w16 #(.sram_bit(pr*bw)) kmem_instance (
        .CLK(clk),
        .D(mem_in),
        .Q(kmem_out),
        .CEN(!(kmem_rd||kmem_wr)),
        .WEN(!kmem_wr), 
        .A(qkmem_add)
);

sram_w16 #(.sram_bit(col*bw_psum)) psum_mem_instance (
        .CLK(clk),
        .D(pmem_in),
        .Q(pmem_out),
        .CEN(!(pmem_rd||pmem_wr)),
        .WEN(!pmem_wr), 
        .A(pmem_add)
);

// Step 2: SFP Initialization
sfp_row #(.col(col), .bw(bw)) sfp_instance (
	.clk(clk),
	.acc(acc),
	.div(div),
	.fifo_ext_rd(fifo_ext_rd),        // read enable for other core fifo
	.sum_in(sfp_sum_in),              // sfp sum from other core
	.sum_out(sum_out),
	.sfp_in(pmem_out),
	.sfp_out(pmem_sfp)
);

  //////////// For printing purpose ////////////
  always @(posedge clk) begin
      if(pmem_wr)
         $display("Memory write to PSUM mem add %x %x ", pmem_add, pmem_in); 
  end



endmodule
