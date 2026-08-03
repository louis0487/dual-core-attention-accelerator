// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 

`timescale 1ns/1ps

module fullchip_tb;

parameter total_cycle = 8;   // how many streamed Q vectors will be processed
parameter bw = 8;            // Q & K vector bit precision
parameter bw_psum = 2*bw+4;  // partial sum bit precision
parameter pr = 8;           // how many products added in each dot product 
parameter col = 8;           // how many dot product units are equipped

integer qk_file ;
integer qk_file0 ; // file handler
integer qk_file1 ;
integer qk_scan_file ; // file handler


integer  captured_data;
integer  weight [col*pr-1:0];
`define NULL 0




integer  K[2*col-1:0][pr-1:0];
integer N[2*col-1:0][pr-1:0];            //  Norm[row][column]
integer V[total_cycle-1:0][pr-1:0];      //  V[row][column]
integer  Q[total_cycle-1:0][pr-1:0];
integer  result[total_cycle-1:0][2*col-1:0];
integer  sum0[total_cycle-1:0];
integer  sum1[total_cycle-1:0];
integer  abs_result[total_cycle-1:0][2*col-1:0];

integer i,j,k,t,p,q,s,u, m;






reg reset = 1;
reg clk = 0;
reg [pr*bw-1:0] mem_in0; 
reg [pr*bw-1:0] mem_in1; 
reg ofifo_rd = 0;
wire [18:0] inst; 
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
reg acc = 0;
reg div = 0;
wire [2*bw_psum*col-1:0] out;

assign inst[18] = div;
assign inst[17] = acc;
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
reg [bw_psum-1:0] norm5b;
reg [bw_psum*col-1:0] norm16b;

fullchip #(.bw(bw), .bw_psum(bw_psum), .col(col), .pr(pr)) fullchip_instance (
      .reset(reset),
      .clk(clk), 
      .mem_in0(mem_in0), 
      .mem_in1(mem_in1), 
      .inst(inst),
      .out(out)
);


initial begin 

  $dumpfile("fullchip_tb.vcd");
  $dumpvars(0,fullchip_tb);



///// Q data txt reading /////

$display("##### Q data txt reading #####");


  qk_file = $fopen("qdata.txt", "r");

  //// To get rid of first 3 lines in data file ////
  // qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);
  // qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);
  // qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);
  // qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);


  for (q=0; q<total_cycle; q=q+1) begin
    for (j=0; j<pr; j=j+1) begin
          qk_scan_file = $fscanf(qk_file, "%d\n", captured_data);
          Q[q][j] = captured_data;
          //$display("%d\n", Q[q][j]);
    end
  end
/////////////////////////////////




  for (q=0; q<2; q=q+1) begin
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
  end


///// K data txt reading /////

$display("##### K data txt reading #####");

  for (q=0; q<10; q=q+1) begin
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
  end
  reset = 0;

  qk_file0 = $fopen("kdata_core0.txt", "r");

  //// To get rid of first 4 lines in data file ////
  // qk_scan_file = $fscanf(qk_file0, "%s\n", captured_data);
  // qk_scan_file = $fscanf(qk_file0, "%s\n", captured_data);
  // qk_scan_file = $fscanf(qk_file0, "%s\n", captured_data);
  // qk_scan_file = $fscanf(qk_file0, "%s\n", captured_data);

  for (q=0; q<col; q=q+1) begin
    for (j=0; j<pr; j=j+1) begin
          qk_scan_file = $fscanf(qk_file0, "%d\n", captured_data);
          K[q][j] = captured_data;
          //$display("##### %d\n", K[q][j]);
    end
  end

  qk_file1 = $fopen("kdata_core1.txt", "r");

  //// To get rid of first 4 lines in data file ////
  // qk_scan_file = $fscanf(qk_file1, "%s\n", captured_data);
  // qk_scan_file = $fscanf(qk_file1, "%s\n", captured_data);
  // qk_scan_file = $fscanf(qk_file1, "%s\n", captured_data);
  // qk_scan_file = $fscanf(qk_file1, "%s\n", captured_data);

  for (q=col; q<2*col; q=q+1) begin
    for (j=0; j<pr; j=j+1) begin
          qk_scan_file = $fscanf(qk_file1, "%d\n", captured_data);
          K[q][j] = captured_data;
          //$display("##### %d\n", K[q][j]);
    end
  end
/////////////////////////////////


/////////////// Estimated result printing /////////////////
/*
// STEP 1
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
     $display("prd @cycle%2d: %40h", t, temp16b);
  end

// STEP 2
$display("##### Absolute value and sum computation #####");
  // Compute absolute value and sum per cycle
  for (t=0; t<total_cycle; t=t+1) begin
      sum[t] = 0;
      for (q=0; q<col; q=q+1) begin
          // absolute value
          abs_result[t][q] = (result[t][q] > 0) ? result[t][q] : (~result[t][q])+1;
          sum[t] = sum[t] + abs_result[t][q];
      end
      $display("sum @cycle%2d = %40h", t, sum[t]);
  end

// STEP 2
$display("##### Estimated normalization result #####");
  for (t=0; t<total_cycle; t=t+1) begin
     for (q=0; q<col; q=q+1) begin
        if(sum[t] != 0) begin
          // $display("t=%0d q=%0d abs_result=%0d (0x%0h) sum=%0d (0x%0h)", t, q, abs_result[t][q], abs_result[t][q], sum[t], sum[t]);
          norm5b = {abs_result[t][q], 8'b0}/sum[t];   // appends 8 zeros to the right (abs_result * 256)
        end
        else
          norm5b = 0;
        norm16b = {norm16b[139:0],norm5b};
     end
     $display("norm @cycle%2d: %40h", t, norm16b);
  end
*/


// STEP 4: Q * K
$display("##### Estimated multiplication result for CORE0 #####");
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
     $display("prd0 @cycle%2d: %40h", t, temp16b);
  end

$display("##### Absolute value and sum computation for CORE0 #####");
  for (t=0; t<total_cycle; t=t+1) begin
      sum0[t] = 0;
      for (q=0; q<col; q=q+1) begin
          // absolute value
          abs_result[t][q] = (result[t][q] > 0) ? result[t][q] : (~result[t][q])+1;
          sum0[t] = sum0[t] + abs_result[t][q];
      end
      $display("sum0 @cycle%2d = %40h", t, sum0[t]);
  end

$display("##### Estimated multiplication result for CORE1 #####");
  for (t=0; t<total_cycle; t=t+1) begin
      for (q=col; q<2*col; q=q+1) begin
        result[t][q] = 0;
      end
    end
  for (t=0; t<total_cycle; t=t+1) begin
     for (q=col; q<2*col; q=q+1) begin
         for (k=0; k<pr; k=k+1) begin
            // $display("CORE1: Q[%2d][%2d] * K[%2d][%2d] = %2d * %2d = %2d", t, k, q, k, Q[t][k], K[q][k], Q[t][k] * K[q][k]);
            result[t][q] = result[t][q] + Q[t][k] * K[q][k];
         end

         temp5b = result[t][q];
         temp16b = {temp16b[139:0], temp5b};
     end

     //$display("%d %d %d %d %d %d %d %d", result[t][0], result[t][1], result[t][2], result[t][3], result[t][4], result[t][5], result[t][6], result[t][7]);
     $display("prd1 @cycle%2d: %40h", t, temp16b);
  end

$display("##### Absolute value and sum computation for CORE1 #####");
  for (t=0; t<total_cycle; t=t+1) begin
      sum1[t] = 0;
      for (q=col; q<2*col; q=q+1) begin
          // absolute value
          abs_result[t][q] = (result[t][q] > 0) ? result[t][q] : (~result[t][q])+1;
          sum1[t] = sum1[t] + abs_result[t][q];
      end
      $display("sum1 @cycle%2d = %40h", t, sum1[t]);
  end

$display("##### Estimated normalization result for CORE0 #####");
  for (t=0; t<total_cycle; t=t+1) begin
     for (q=0; q<col; q=q+1) begin
        if((sum0[t] + sum1[t]) != 0) begin
          norm5b = {abs_result[t][q], 8'b0}/(sum0[t] + sum1[t]);
        end
        else
          norm5b = 0;
        norm16b = {norm16b[139:0],norm5b};
     end
     $display("norm0 @cycle%2d: %40h", t, norm16b);
  end

$display("##### Estimated normalization result for CORE1 #####");
  for (t=0; t<total_cycle; t=t+1) begin
     for (q=col; q<2*col; q=q+1) begin
        if((sum0[t] + sum1[t]) != 0) begin
          // $display("t=%0d q=%0d abs_result=%0d (0x%0h) sum0=%0d (0x%0h) sum1=%0d (0x%0h) sum0+sum1=%0d (0x%0h)", t, q, abs_result[t][q], abs_result[t][q], sum0[t], sum0[t], sum1[t], sum1[t], sum0[t]+sum1[t], sum0[t]+sum1[t]);
          norm5b = {abs_result[t][q], 8'b0}/(sum0[t] + sum1[t]);
        end
        else
          norm5b = 0;
        norm16b = {norm16b[139:0],norm5b};
     end
     $display("norm1 @cycle%2d: %40h", t, norm16b);
  end



///// Qmem writing  /////

$display("##### Qmem writing  #####");

  for (q=0; q<total_cycle; q=q+1) begin

    #0.5 clk = 1'b0;  
    qmem_wr = 1;  if (q>0) qkmem_add = qkmem_add + 1; 

    mem_in0[1*bw-1:0*bw] = Q[q][0];
    mem_in0[2*bw-1:1*bw] = Q[q][1];
    mem_in0[3*bw-1:2*bw] = Q[q][2];
    mem_in0[4*bw-1:3*bw] = Q[q][3];
    mem_in0[5*bw-1:4*bw] = Q[q][4];
    mem_in0[6*bw-1:5*bw] = Q[q][5];
    mem_in0[7*bw-1:6*bw] = Q[q][6];
    mem_in0[8*bw-1:7*bw] = Q[q][7];

    mem_in1[1*bw-1:0*bw] = Q[q][0];
    mem_in1[2*bw-1:1*bw] = Q[q][1];
    mem_in1[3*bw-1:2*bw] = Q[q][2];
    mem_in1[4*bw-1:3*bw] = Q[q][3];
    mem_in1[5*bw-1:4*bw] = Q[q][4];
    mem_in1[6*bw-1:5*bw] = Q[q][5];
    mem_in1[7*bw-1:6*bw] = Q[q][6];
    mem_in1[8*bw-1:7*bw] = Q[q][7];

    /*
    mem_in[1*bw-1:0*bw] = Q[q][0];
    mem_in[2*bw-1:1*bw] = Q[q][1];
    mem_in[3*bw-1:2*bw] = Q[q][2];
    mem_in[4*bw-1:3*bw] = Q[q][3];
    mem_in[5*bw-1:4*bw] = Q[q][4];
    mem_in[6*bw-1:5*bw] = Q[q][5];
    mem_in[7*bw-1:6*bw] = Q[q][6];
    mem_in[8*bw-1:7*bw] = Q[q][7];
    mem_in[9*bw-1:8*bw] = Q[q][8];
    mem_in[10*bw-1:9*bw] = Q[q][9];
    mem_in[11*bw-1:10*bw] = Q[q][10];
    mem_in[12*bw-1:11*bw] = Q[q][11];
    mem_in[13*bw-1:12*bw] = Q[q][12];
    mem_in[14*bw-1:13*bw] = Q[q][13];
    mem_in[15*bw-1:14*bw] = Q[q][14];
    mem_in[16*bw-1:15*bw] = Q[q][15];
    */

    #0.5 clk = 1'b1;  

  end


  #0.5 clk = 1'b0;  
  qmem_wr = 0; 
  qkmem_add = 0;
  #0.5 clk = 1'b1;  
///////////////////////////////////////////





///// Kmem writing  /////

$display("##### Kmem writing #####");

  for (q=0; q<col; q=q+1) begin

    #0.5 clk = 1'b0;  
    kmem_wr = 1; if (q>0) qkmem_add = qkmem_add + 1; 

    mem_in0[1*bw-1:0*bw] = K[q][0];
    mem_in0[2*bw-1:1*bw] = K[q][1];
    mem_in0[3*bw-1:2*bw] = K[q][2];
    mem_in0[4*bw-1:3*bw] = K[q][3];
    mem_in0[5*bw-1:4*bw] = K[q][4];
    mem_in0[6*bw-1:5*bw] = K[q][5];
    mem_in0[7*bw-1:6*bw] = K[q][6];
    mem_in0[8*bw-1:7*bw] = K[q][7];

    mem_in1[1*bw-1:0*bw] = K[q+col][0];
    mem_in1[2*bw-1:1*bw] = K[q+col][1];
    mem_in1[3*bw-1:2*bw] = K[q+col][2];
    mem_in1[4*bw-1:3*bw] = K[q+col][3];
    mem_in1[5*bw-1:4*bw] = K[q+col][4];
    mem_in1[6*bw-1:5*bw] = K[q+col][5];
    mem_in1[7*bw-1:6*bw] = K[q+col][6];
    mem_in1[8*bw-1:7*bw] = K[q+col][7];
    
    /*
    mem_in[1*bw-1:0*bw] = K[q][0];
    mem_in[2*bw-1:1*bw] = K[q][1];
    mem_in[3*bw-1:2*bw] = K[q][2];
    mem_in[4*bw-1:3*bw] = K[q][3];
    mem_in[5*bw-1:4*bw] = K[q][4];
    mem_in[6*bw-1:5*bw] = K[q][5];
    mem_in[7*bw-1:6*bw] = K[q][6];
    mem_in[8*bw-1:7*bw] = K[q][7];
    mem_in[9*bw-1:8*bw] = K[q][8];
    mem_in[10*bw-1:9*bw] = K[q][9];
    mem_in[11*bw-1:10*bw] = K[q][10];
    mem_in[12*bw-1:11*bw] = K[q][11];
    mem_in[13*bw-1:12*bw] = K[q][12];
    mem_in[14*bw-1:13*bw] = K[q][13];
    mem_in[15*bw-1:14*bw] = K[q][14];
    mem_in[16*bw-1:15*bw] = K[q][15];
    */

    #0.5 clk = 1'b1;  

  end

  #0.5 clk = 1'b0;  
  kmem_wr = 0;  
  qkmem_add = 0;
  #0.5 clk = 1'b1;  
///////////////////////////////////////////



  for (q=0; q<2; q=q+1) begin
    #0.5 clk = 1'b0;  
    #0.5 clk = 1'b1;   
  end


/////  K data loading  /////
$display("##### K data loading to processor #####");

  for (q=0; q<col+1; q=q+1) begin
    #0.5 clk = 1'b0;  
    load = 1; 
    if (q==1) kmem_rd = 1;
    if (q>1) begin
       qkmem_add = qkmem_add + 1;
    end

    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;  
  kmem_rd = 0; qkmem_add = 0;
  #0.5 clk = 1'b1;  

  #0.5 clk = 1'b0;  
  load = 0; 
  #0.5 clk = 1'b1;  

///////////////////////////////////////////

 for (q=0; q<10; q=q+1) begin
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
 end





///// execution  /////
$display("##### execute #####");

  for (q=0; q<total_cycle; q=q+1) begin
    #0.5 clk = 1'b0;  
    execute = 1; 
    qmem_rd = 1;

    if (q>0) begin
       qkmem_add = qkmem_add + 1;
    end

    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;  
  qmem_rd = 0; qkmem_add = 0; execute = 0;
  #0.5 clk = 1'b1;  


///////////////////////////////////////////

 for (q=0; q<10; q=q+1) begin
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
 end




////////////// output fifo rd and wb to psum mem ///////////////////

$display("##### move ofifo to pmem #####");

  for (q=0; q<total_cycle; q=q+1) begin
    #0.5 clk = 1'b0;  
    ofifo_rd = 1; 
    pmem_wr = 1; 

    if (q>0) begin
       pmem_add = pmem_add + 1;
    end

    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;  
  pmem_wr = 0; pmem_add = 0; ofifo_rd = 0;
  #0.5 clk = 1'b1;  

///////////////////////////////////////////

 for (q=0; q<10; q=q+1) begin
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
 end

// STEP 2
////////////// sfp accumulation ///////////////////
$display("##### sfp normalization and wb to pmem #####");
  for (q=0; q<total_cycle; q=q+1) begin
    #0.5 clk = 1'b0; 
    div = 0;
    pmem_rd = 1;
    pmem_wr = 0;

    if (q>0) begin
       pmem_add = pmem_add + 1;
    end

    #0.5 clk = 1'b1; 

    #0.5 clk = 1'b0;
    acc = 1;
    pmem_rd = 0;
    #0.5 clk = 1'b1;
    
    #0.5 clk = 1'b0;
    acc = 0;
    #0.5 clk = 1'b1;
    
    #0.5 clk = 1'b0;
    div = 1;
    #0.5 clk = 1'b1;
    
    #0.5 clk = 1'b0;
    pmem_wr = 1;
    #0.5 clk = 1'b1;
  end

  #0.5 clk = 1'b0; 
  pmem_rd = 0; pmem_add = 0; acc = 0; div = 0; pmem_wr = 0;
  #0.5 clk = 1'b1;

///////////////////////////////////////////

for (q=0; q<5; q=q+1) begin
  #0.5 clk = 1'b0;   
  #0.5 clk = 1'b1;   
end
#0.5 clk = 1'b0;   
reset = 1;
clk = 0;
ofifo_rd = 0;
qmem_rd = 0;
qmem_wr = 0; 
kmem_rd = 0;
kmem_wr = 0;
pmem_rd = 0; 
pmem_wr = 0; 
execute = 0;
load = 0;
qkmem_add = 0;
pmem_add = 0;
acc = 0;
div = 0;
#0.5 clk = 1'b1;  

///// V data txt reading /////

$display("##### V data txt reading #####");


  qk_file = $fopen("vdata.txt", "r");

  //// To get rid of first 3 lines in data file ////
  // qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);
  // qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);
  // qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);
  // qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);


  for (q=0; q<total_cycle; q=q+1) begin
    for (j=0; j<pr; j=j+1) begin
          qk_scan_file = $fscanf(qk_file, "%d\n", captured_data);
          V[q][j] = captured_data;
          //$display("%d\n", V[q][j]);
    end
  end

/////////////////////////////////
  for (q=0; q<2; q=q+1) begin
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
  end


///// Norm data txt reading /////
  $display("##### Norm data txt reading #####");

  for (t=0; t<10; t=t+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
  end

  reset = 0;

  //////////////// CORE0 //////////////////
  qk_file0 = $fopen("norm_core0.txt", "r");
  for (q=0; q<col; q=q+1) begin
    for (j=0; j<pr; j=j+1) begin
          qk_scan_file = $fscanf(qk_file0, "%d\n", captured_data);
          N[q][j] = captured_data;
          //$display("##### %d\n", N[q][j]);
    end
  end

  //////////////// CORE1 //////////////////
  qk_file1 = $fopen("norm_core1.txt", "r");

  for (q=col; q<2*col; q=q+1) begin
    for (j=0; j<pr; j=j+1) begin
          qk_scan_file = $fscanf(qk_file1, "%d\n", captured_data);
          N[q][j] = captured_data;
          //$display("##### %d\n", [q][j]);
    end
  end


//////////////////////////////////////////////
// STEP 4: Norm * V
$display("##### Estimated Norm * V for CORE0 #####");
  for (t=0; t<total_cycle; t=t+1) begin
      for (q=0; q<col; q=q+1) begin
        result[t][q] = 0;
      end
    end
  for (t=0; t<total_cycle; t=t+1) begin   // time step (clock cycle)
     for (q=0; q<col; q=q+1) begin   
         for (k=0; k<pr; k=k+1) begin
            result[t][q] = result[t][q] + N[q][k] * V[t][k];
         end

         temp5b = result[t][q];
         temp16b = {temp16b[139:0], temp5b};
     end
     $display("NV0 @cycle%2d: %40h", t, temp16b);
  end


$display("##### Estimated Norm * V for CORE1 #####");
  for (t=0; t<total_cycle; t=t+1) begin
      for (q=col; q<2*col; q=q+1) begin
        result[t][q] = 0;
      end
    end
  for (t=0; t<total_cycle; t=t+1) begin   // time step (clock cycle)
     for (q=col; q<2*col; q=q+1) begin
         for (k=0; k<pr; k=k+1) begin
            // $display("CORE1: N[%2d][%2d] * V[%2d][%2d] = %2d * %2d = %2d", q+col, k, t, k, N[q+col][k], V[t][k], N[q+col][k] * V[t][k]);
            result[t][q] = result[t][q] + N[q][k] * V[t][k];
         end

         temp5b = result[t][q];
         temp16b = {temp16b[139:0], temp5b};
     end
     $display("NV1 @cycle%2d: %40h", t, temp16b);
  end
//////////////////////////////////////////////


///// Vmem writing  /////

  $display("##### Vmem writing #####");

  
  for (q=0; q<total_cycle; q=q+1) begin

    #0.5 clk = 1'b0;  
    qmem_wr = 1;  if (q>0) qkmem_add = qkmem_add + 1; 

    mem_in0[1*bw-1:0*bw] = V[q][0];
    mem_in0[2*bw-1:1*bw] = V[q][1];
    mem_in0[3*bw-1:2*bw] = V[q][2];
    mem_in0[4*bw-1:3*bw] = V[q][3];
    mem_in0[5*bw-1:4*bw] = V[q][4];
    mem_in0[6*bw-1:5*bw] = V[q][5];
    mem_in0[7*bw-1:6*bw] = V[q][6];
    mem_in0[8*bw-1:7*bw] = V[q][7];

    mem_in1[1*bw-1:0*bw] = V[q][0];
    mem_in1[2*bw-1:1*bw] = V[q][1];
    mem_in1[3*bw-1:2*bw] = V[q][2];
    mem_in1[4*bw-1:3*bw] = V[q][3];
    mem_in1[5*bw-1:4*bw] = V[q][4];
    mem_in1[6*bw-1:5*bw] = V[q][5];
    mem_in1[7*bw-1:6*bw] = V[q][6];
    mem_in1[8*bw-1:7*bw] = V[q][7];

    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;  
  qmem_wr = 0; 
  qkmem_add = 0;
  #0.5 clk = 1'b1;  


///// Norm writing  /////
  $display("##### Norm mem writing #####");

  for (q=0; q<col; q=q+1) begin

    #0.5 clk = 1'b0;  
    kmem_wr = 1; if (q>0) qkmem_add = qkmem_add + 1; 

    mem_in0[1*bw-1:0*bw] = N[q][0];
    mem_in0[2*bw-1:1*bw] = N[q][1];
    mem_in0[3*bw-1:2*bw] = N[q][2];
    mem_in0[4*bw-1:3*bw] = N[q][3];
    mem_in0[5*bw-1:4*bw] = N[q][4];
    mem_in0[6*bw-1:5*bw] = N[q][5];
    mem_in0[7*bw-1:6*bw] = N[q][6];
    mem_in0[8*bw-1:7*bw] = N[q][7];

    mem_in1[1*bw-1:0*bw] = N[q+col][0];
    mem_in1[2*bw-1:1*bw] = N[q+col][1];
    mem_in1[3*bw-1:2*bw] = N[q+col][2];
    mem_in1[4*bw-1:3*bw] = N[q+col][3];
    mem_in1[5*bw-1:4*bw] = N[q+col][4];
    mem_in1[6*bw-1:5*bw] = N[q+col][5];
    mem_in1[7*bw-1:6*bw] = N[q+col][6];
    mem_in1[8*bw-1:7*bw] = N[q+col][7];

    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;  
  kmem_wr = 0;  
  qkmem_add = 0;
  #0.5 clk = 1'b1;  
///////////////////////////////////////////

  for (q=0; q<2; q=q+1) begin
    #0.5 clk = 1'b0;  
    #0.5 clk = 1'b1;   
  end


/////  V data loading  /////
$display("##### V data loading to processor #####");

  for (q=0; q<col+1; q=q+1) begin
    #0.5 clk = 1'b0;  
    load = 1; 
    if (q==1) kmem_rd = 1;
    if (q>1) begin
       qkmem_add = qkmem_add + 1;
    end

    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;  
  kmem_rd = 0; qkmem_add = 0;
  #0.5 clk = 1'b1;  

  #0.5 clk = 1'b0;  
  load = 0; 
  #0.5 clk = 1'b1;  

///////////////////////////////////////////

 for (q=0; q<10; q=q+1) begin
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
 end


///// execution  /////
$display("##### execute #####");

  for (q=0; q<total_cycle; q=q+1) begin
    #0.5 clk = 1'b0;  
    execute = 1; 
    qmem_rd = 1;

    if (q>0) begin
       qkmem_add = qkmem_add + 1;
    end

    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;  
  qmem_rd = 0; qkmem_add = 0; execute = 0;
  #0.5 clk = 1'b1;  


///////////////////////////////////////////

 for (q=0; q<10; q=q+1) begin
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
 end

////////////// output fifo rd and wb to psum mem ///////////////////

$display("##### move ofifo to pmem #####");

  for (q=0; q<total_cycle; q=q+1) begin
    #0.5 clk = 1'b0;  
    ofifo_rd = 1; 
    pmem_wr = 1; 

    if (q>0) begin
       pmem_add = pmem_add + 1;
    end

    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;  
  pmem_wr = 0; pmem_add = 0; ofifo_rd = 0;
  #0.5 clk = 1'b1;  

///////////////////////////////////////////

 for (q=0; q<10; q=q+1) begin
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
 end



  #10 $finish;


end

endmodule




