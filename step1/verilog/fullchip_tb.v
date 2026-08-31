// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 

`timescale 1ns/1ps

// Clock half period, in the 1 ns units of the timescale above.
//
// Behavioural simulation runs at the 1.0 ns target. Gate-level simulation
// cannot: post-route reg2reg WNS is -0.170 ns, so the routed netlist needs at
// least 1.170 ns, and this testbench gives its inputs only half a period of
// setup where the SDC assumed 0.8 ns. 2.0 ns clears both with margin.
//
// Override from the command line to tighten it, for example
//   xrun ... +define+CLK_HALF=0.7      -> 1.4 ns period
`ifndef CLK_HALF
  `ifdef GLS
    `define CLK_HALF 1.0
  `else
    `define CLK_HALF 0.5
  `endif
`endif

module fullchip_tb;

parameter total_cycle = 8;   // how many streamed Q vectors will be processed
parameter bw = 8;            // Q & K vector bit precision
parameter bw_psum = 2*bw+4;  // partial sum bit precision
parameter pr = 8;           // how many products added in each dot product 
parameter col = 8;           // how many dot product units are equipped

integer qk_file ; // file handler
integer qk_scan_file ; // file handler


integer  captured_data;
integer  weight [col*pr-1:0];
`define NULL 0




integer  K[col-1:0][pr-1:0];
integer  Q[total_cycle-1:0][pr-1:0];
integer  result[total_cycle-1:0][col-1:0];
integer  sum[total_cycle-1:0];

integer i,j,k,t,p,q,s,u, m;





reg reset = 1;
reg clk = 0;
reg [pr*bw-1:0] mem_in; 
reg ofifo_rd = 0;
wire [16:0] inst; 
reg qmem_rd = 0;
reg qmem_wr = 0; 
reg kmem_rd = 0; 
reg kmem_wr = 0;
reg pmem_rd = 0; 
reg pmem_wr = 0; 
reg execute = 0;
reg load = 0;
reg [3:0] qkmem_add = 0;
reg [3:0] pmem_add = 0;


assign inst[16] = ofifo_rd;
assign inst[15:12] = qkmem_add;
assign inst[11:8]  = pmem_add;
assign inst[7] = execute;
assign inst[6] = load;
assign inst[5] = qmem_rd;
assign inst[4] = qmem_wr;
assign inst[3] = kmem_rd;
assign inst[2] = kmem_wr;
assign inst[1] = pmem_rd;
assign inst[0] = pmem_wr;



reg [bw_psum-1:0] temp5b;
reg [bw_psum+3:0] temp_sum;
reg [bw_psum*col-1:0] temp16b;

// readout path: chip output port, expected rows, and self-check counters
wire [bw_psum*col-1:0] out;
reg  [bw_psum*col-1:0] golden [total_cycle-1:0];
integer errors;
integer pass_cnt;



// Synthesis resolves the parameters into the netlist, so the mapped fullchip
// has an empty parameter list. Passing overrides to it is an elaboration
// error (CUTMIP, "too many module instance parameter assignments"), so the
// gate-level build instantiates it bare.
`ifdef GLS
fullchip fullchip_instance (
`else
fullchip #(.bw(bw), .bw_psum(bw_psum), .col(col), .pr(pr)) fullchip_instance (
`endif
      .reset(reset),
      .clk(clk), 
      .mem_in(mem_in), 
      .inst(inst),
      .out(out)
);


initial begin 

`ifdef GLS
  // Back-annotate the worst-case corner SDF onto the routed netlist. This has
  // to come first: annotation must land before any timing-dependent activity.
  // The trailing arguments matter. The SDF carries min::max delay pairs, so
  // without "MAXIMUM" the simulator picks the typical column, which these
  // triplets leave empty. This is the form the course flow uses.
  $sdf_annotate("fullchip_WC.sdf", fullchip_instance, , , "MAXIMUM", "1:1:1", "FROM_MTM");

  // Dump the whole hierarchy. Voltus needs activity on the flop outputs and
  // internal nets to reach 100% annotation when this VCD is fed back into
  // Innovus for power analysis; the chip boundary alone would leave it
  // estimating everything past the primary inputs.
  $dumpfile("fullchip_gls.vcd");
`else
  $dumpfile("fullchip_tb.vcd");
`endif
  $dumpvars(0, fullchip_tb);



///// Q data txt reading /////

$display("##### Q data txt reading #####");


  qk_file = $fopen("qdata.txt", "r");



  for (q=0; q<total_cycle; q=q+1) begin
    for (j=0; j<pr; j=j+1) begin
          qk_scan_file = $fscanf(qk_file, "%d\n", captured_data);
          Q[q][j] = captured_data;
          //$display("%d\n", K[q][j]);
    end
  end
/////////////////////////////////




  for (q=0; q<2; q=q+1) begin
    #`CLK_HALF clk = 1'b0;   
    #`CLK_HALF clk = 1'b1;   
  end




///// K data txt reading /////

$display("##### K data txt reading #####");

  for (q=0; q<10; q=q+1) begin
    #`CLK_HALF clk = 1'b0;   
    #`CLK_HALF clk = 1'b1;   
  end
  reset = 0;

  qk_file = $fopen("kdata.txt", "r");





  for (q=0; q<col; q=q+1) begin
    for (j=0; j<pr; j=j+1) begin
          qk_scan_file = $fscanf(qk_file, "%d\n", captured_data);
          K[q][j] = captured_data;
          //$display("##### %d\n", K[q][j]);
    end
  end
/////////////////////////////////








/////////////// Estimated result printing /////////////////


$display("##### Estimated multiplication result #####");

  for (t=0; t<total_cycle; t=t+1) begin
     for (q=0; q<col; q=q+1) begin
       result[t][q] = 0;
     end
  end

  for (t=0; t<total_cycle; t=t+1) begin
     for (q=0; q<col; q=q+1) begin
         for (k=0; k<pr; k=k+1) begin
            result[t][q] = result[t][q] + Q[t][k] * K[q][k];
         end

         temp5b = result[t][q];
         temp16b = {temp16b[139:0], temp5b};
     end

     //$display("%d %d %d %d %d %d %d %d", result[t][0], result[t][1], result[t][2], result[t][3], result[t][4], result[t][5], result[t][6], result[t][7]);
     golden[t] = temp16b;
     $display("prd @cycle%2d: %40h", t, temp16b);
  end

//////////////////////////////////////////////






///// Qmem writing  /////

$display("##### Qmem writing  #####");

  for (q=0; q<total_cycle; q=q+1) begin

    #`CLK_HALF clk = 1'b0;  
    qmem_wr = 1;  if (q>0) qkmem_add = qkmem_add + 1; 
    
    mem_in[1*bw-1:0*bw] = Q[q][0];
    mem_in[2*bw-1:1*bw] = Q[q][1];
    mem_in[3*bw-1:2*bw] = Q[q][2];
    mem_in[4*bw-1:3*bw] = Q[q][3];
    mem_in[5*bw-1:4*bw] = Q[q][4];
    mem_in[6*bw-1:5*bw] = Q[q][5];
    mem_in[7*bw-1:6*bw] = Q[q][6];
    mem_in[8*bw-1:7*bw] = Q[q][7];

    #`CLK_HALF clk = 1'b1;  

  end


  #`CLK_HALF clk = 1'b0;  
  qmem_wr = 0; 
  qkmem_add = 0;
  #`CLK_HALF clk = 1'b1;  
///////////////////////////////////////////





///// Kmem writing  /////

$display("##### Kmem writing #####");

  for (q=0; q<col; q=q+1) begin

    #`CLK_HALF clk = 1'b0;  
    kmem_wr = 1; if (q>0) qkmem_add = qkmem_add + 1; 
    
    mem_in[1*bw-1:0*bw] = K[q][0];
    mem_in[2*bw-1:1*bw] = K[q][1];
    mem_in[3*bw-1:2*bw] = K[q][2];
    mem_in[4*bw-1:3*bw] = K[q][3];
    mem_in[5*bw-1:4*bw] = K[q][4];
    mem_in[6*bw-1:5*bw] = K[q][5];
    mem_in[7*bw-1:6*bw] = K[q][6];
    mem_in[8*bw-1:7*bw] = K[q][7];

    #`CLK_HALF clk = 1'b1;  

  end

  #`CLK_HALF clk = 1'b0;  
  kmem_wr = 0;  
  qkmem_add = 0;
  #`CLK_HALF clk = 1'b1;  
///////////////////////////////////////////



  for (q=0; q<2; q=q+1) begin
    #`CLK_HALF clk = 1'b0;  
    #`CLK_HALF clk = 1'b1;   
  end




/////  K data loading  /////
$display("##### K data loading to processor #####");

  for (q=0; q<col+1; q=q+1) begin
    #`CLK_HALF clk = 1'b0;  
    load = 1; 
    if (q==1) kmem_rd = 1;
    if (q>1) begin
       qkmem_add = qkmem_add + 1;
    end

    #`CLK_HALF clk = 1'b1;  
  end

  #`CLK_HALF clk = 1'b0;  
  kmem_rd = 0; qkmem_add = 0;
  #`CLK_HALF clk = 1'b1;  

  #`CLK_HALF clk = 1'b0;  
  load = 0; 
  #`CLK_HALF clk = 1'b1;  

///////////////////////////////////////////

 for (q=0; q<10; q=q+1) begin
    #`CLK_HALF clk = 1'b0;   
    #`CLK_HALF clk = 1'b1;   
 end





///// execution  /////
$display("##### execute #####");

  for (q=0; q<total_cycle; q=q+1) begin
    #`CLK_HALF clk = 1'b0;  
    execute = 1; 
    qmem_rd = 1;

    if (q>0) begin
       qkmem_add = qkmem_add + 1;
    end

    #`CLK_HALF clk = 1'b1;  
  end

  #`CLK_HALF clk = 1'b0;  
  qmem_rd = 0; qkmem_add = 0; execute = 0;
  #`CLK_HALF clk = 1'b1;  


///////////////////////////////////////////

 for (q=0; q<10; q=q+1) begin
    #`CLK_HALF clk = 1'b0;   
    #`CLK_HALF clk = 1'b1;   
 end




////////////// output fifo rd and wb to psum mem ///////////////////

$display("##### move ofifo to pmem #####");

  for (q=0; q<total_cycle; q=q+1) begin
    #`CLK_HALF clk = 1'b0;  
    ofifo_rd = 1; 
    pmem_wr = 1; 

    if (q>0) begin
       pmem_add = pmem_add + 1;
    end

    #`CLK_HALF clk = 1'b1;  
  end

  #`CLK_HALF clk = 1'b0;  
  pmem_wr = 0; pmem_add = 0; ofifo_rd = 0;
  #`CLK_HALF clk = 1'b1;  

///////////////////////////////////////////




///////// readout from pmem and self-check ///////////

$display("##### readout from pmem #####");

  errors   = 0;
  pass_cnt = 0;

  // pmem is a synchronous-read SRAM (Q <= memory[A] on posedge), so a word
  // requested at one posedge is only stable in the next time step. The loop
  // runs one extra iteration: it checks the row requested in the previous
  // iteration, then issues the next address.
  for (q=0; q<total_cycle+1; q=q+1) begin

    #`CLK_HALF clk = 1'b0;  

    if (q>0) begin
      if (out === golden[q-1]) begin
        pass_cnt = pass_cnt + 1;
        $display("row %0d PASS: %40h", q-1, out);
      end
      else begin
        errors = errors + 1;
        $display("row %0d FAIL: got %40h exp %40h", q-1, out, golden[q-1]);
      end
    end

    if (q<total_cycle) begin
      pmem_rd  = 1; 
      pmem_add = q; 
    end
    else begin
      pmem_rd = 0; 
    end

    #`CLK_HALF clk = 1'b1;  

  end

  #`CLK_HALF clk = 1'b0;  
  pmem_rd = 0; pmem_add = 0;
  #`CLK_HALF clk = 1'b1;  

  $display("##### RESULT: %0d PASS / %0d FAIL #####", pass_cnt, errors);

///////////////////////////////////////////




  #10 $finish;


end

endmodule




