// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission
//
// Dual-core testbench for step 4, rewritten from the step 3 testbench.
//
// Two free-running clocks with unrelated periods drive the two cores. Each
// core is fed by its own core_drv, which replays the step 3 sequence (Q/K
// write, K load, execute, ofifo -> pmem, readout) on that core's clock. The two
// drivers only meet at barriers, and only where the cores depend on each other:
// around every row-sum exchange of the normalization.
//
// Checks, per core:
//   RESULT       Q x K rows against the testbench model
//   NORM RESULT  normalized rows. Both cores divide by the same number,
//                (S0 >> 7) + (S1 >> 7): sfp_row.v:61 truncates each core's
//                sum before adding them, and the model does exactly that.
//   NV RESULT    norm x V on the same hardware (FAQ 32): norm_coreN.txt goes
//                into qmem, vdata.txt into kmem, each core on its own with no
//                cross-core merge (R4 ruling F1).
//
// norm_core0/1.txt are the inputs of the norm x V run, not the expected output
// of the normalization - they do not match the hardware model of this Q/K data
// - so the normalization is checked against the model, as in step 3.
//
// Override the clocks from the command line, e.g. +define+CLK1_HALF=2.0.
// Keep the two periods unrelated (not an integer ratio): the point of this
// step is that the cores do not share a clock.

`timescale 1ns/1ps

`ifndef CLK0_HALF
  `define CLK0_HALF 0.5
`endif
`ifndef CLK1_HALF
  `define CLK1_HALF 0.65
`endif

module fullchip_tb;

parameter bw = 8;
parameter bw_psum = 2*bw+4;
parameter pr = 8;
parameter col = 8;

reg clk0 = 0;
reg clk1 = 0;
always #`CLK0_HALF clk0 = ~clk0;
always #`CLK1_HALF clk1 = ~clk1;

wire              reset0, reset1;
wire [20:0]       inst0, inst1;
wire [pr*bw-1:0]  mem_in0, mem_in1;
wire [bw_psum*col-1:0] out0, out1;
wire [7:0]        bar0, bar1;
wire              done0, done1;
wire [31:0]       err0, err1;

// Synthesis resolves the parameters into the netlist, so the mapped fullchip
// has an empty parameter list and the gate-level build instantiates it bare.
`ifdef GLS
fullchip fullchip_instance (
`else
fullchip #(.bw(bw), .bw_psum(bw_psum), .col(col), .pr(pr)) fullchip_instance (
`endif
      .clk0(clk0), .reset0(reset0), .inst0(inst0), .mem_in0(mem_in0), .out0(out0),
      .clk1(clk1), .reset1(reset1), .inst1(inst1), .mem_in1(mem_in1), .out1(out1)
);

core_drv #(.ID(0), .KFILE("kdata_core0.txt"), .KFILE_OTHER("kdata_core1.txt"),
           .NFILE("norm_core0.txt")) drv0 (
      .clk(clk0), .reset(reset0), .inst(inst0), .mem_in(mem_in0), .out(out0),
      .bar(bar0), .bar_other(bar1), .done(done0), .errors_total(err0)
);

core_drv #(.ID(1), .KFILE("kdata_core1.txt"), .KFILE_OTHER("kdata_core0.txt"),
           .NFILE("norm_core1.txt")) drv1 (
      .clk(clk1), .reset(reset1), .inst(inst1), .mem_in(mem_in1), .out(out1),
      .bar(bar1), .bar_other(bar0), .done(done1), .errors_total(err1)
);

initial begin
  $dumpfile("fullchip_tb.vcd");
  $dumpvars(0, fullchip_tb);
  $display("##### clk0 period %0.3f ns, clk1 period %0.3f ns #####",
           2.0*`CLK0_HALF, 2.0*`CLK1_HALF);
  wait (done0 && done1);
  if (err0 + err1 == 0)
    $display("##### ALL PASS #####");
  else
    $display("##### %0d FAIL IN TOTAL #####", err0 + err1);
  #10 $finish;
end

// A lost handshake leaves a driver waiting at a barrier forever; stop instead.
initial begin
  repeat (20000) @(posedge clk0);
  $display("##### TIMEOUT: a driver is stuck (bar0=%0d bar1=%0d) #####", bar0, bar1);
  $finish;
end

endmodule


// One core's stimulus, on that core's clock. Inputs change on the falling edge
// and are sampled on the next rising edge, as in the step 3 testbench.
module core_drv (clk, reset, inst, mem_in, out, bar, bar_other, done, errors_total);

parameter ID          = 0;
parameter KFILE       = "kdata_core0.txt";
parameter KFILE_OTHER = "kdata_core1.txt";   // only for the other core's row sums
parameter NFILE       = "norm_core0.txt";
parameter bw          = 8;
parameter bw_psum     = 2*bw+4;
parameter pr          = 8;
parameter col         = 8;
parameter total_cycle = 8;

// Cycles of this core's clock to wait after a sum_xfer pulse, before the
// barrier. One transfer takes at most 7 sender + 6 receiver cycles end to end
// (the load cycle, then four crossings of a two-flop synchronizer plus one
// cycle for the state machine to act on each). Waiting 20 own cycles and then
// meeting at a barrier means at least 20 cycles of the slower clock have
// passed, so both transfers are over and both senders are back in S_IDLE.
parameter XFER_WAIT   = 20;

input                       clk;
output reg                  reset;
output [20:0]               inst;
output reg [pr*bw-1:0]      mem_in;
input  [bw_psum*col-1:0]    out;
output reg [7:0]            bar;
input  [7:0]                bar_other;
output reg                  done;
output reg [31:0]           errors_total;

reg sum_xfer = 0;
reg norm = 0;
reg div  = 0;
reg acc  = 0;
reg ofifo_rd = 0;
reg execute = 0;
reg load = 0;
reg qmem_rd = 0;
reg qmem_wr = 0;
reg kmem_rd = 0;
reg kmem_wr = 0;
reg pmem_rd = 0;
reg pmem_wr = 0;
reg [3:0] qkmem_add = 0;
reg [3:0] pmem_add = 0;

assign inst[20]    = sum_xfer;
assign inst[19]    = norm;
assign inst[18]    = div;
assign inst[17]    = acc;
assign inst[16]    = ofifo_rd;
assign inst[15:12] = qkmem_add;
assign inst[11:8]  = pmem_add;
assign inst[7]     = execute;
assign inst[6]     = load;
assign inst[5]     = qmem_rd;
assign inst[4]     = qmem_wr;
assign inst[3]     = kmem_rd;
assign inst[2]     = kmem_wr;
assign inst[1]     = pmem_rd;
assign inst[0]     = pmem_wr;

// ponytail: every matrix here is 8 x 8 (total_cycle = col = pr = 8), so one
// 3-D array holds all five and a run just names which two it multiplies.
localparam MQ = 0, MK = 1, MKO = 2, MN = 3, MV = 4;
integer M [0:4][0:7][0:7];

integer R  [0:7][0:7];     // product of the run being modelled
integer RO [0:7][0:7];     // the other core's Q x K, for its row sums
reg [bw_psum*col-1:0] golden      [0:total_cycle-1];
reg [bw_psum*col-1:0] golden_norm [0:total_cycle-1];
reg [bw_psum*col-1:0] golden_nv   [0:total_cycle-1];

integer fd, scan, val, i, j, k, q, t, s_own, s_oth, divisor, pass_cnt, errors;
reg [bw_psum-1:0]     elem;
reg [bw_psum*col-1:0] rowv;

task cyc;                       // wait for this core's falling edge
  @(negedge clk);
endtask

task idle(input integer n);
  for (i = 0; i < n; i = i + 1) cyc;
endtask

// Generation-count barrier: no flag to clear, so no race between a fast
// driver re-entering and a slow one still leaving the previous barrier.
task barrier;
  begin
    bar = bar + 1;
    wait (bar_other >= bar);
  end
endtask

task read_mat(input integer m);
  begin
    for (i = 0; i < 8; i = i + 1)
      for (j = 0; j < 8; j = j + 1) begin
        scan = $fscanf(fd, "%d", val);
        M[m][i][j] = val;
      end
    $fclose(fd);
  end
endtask

// R[t][c] = sum_k M[ma][t][k] * M[mb][c][k] - what the mac array computes
task mul(input integer ma, input integer mb);
  for (t = 0; t < 8; t = t + 1)
    for (q = 0; q < 8; q = q + 1) begin
      R[t][q] = 0;
      for (k = 0; k < 8; k = k + 1)
        R[t][q] = R[t][q] + M[ma][t][k] * M[mb][q][k];
    end
endtask

// column 0 ends up in the top bits, as in the step 3 testbench
task pack_row(input integer t2);
  for (q = 0; q < col; q = q + 1) begin
    elem   = R[t2][q];
    rowv = {rowv[bw_psum*(col-1)-1:0], elem};
  end
endtask

// write the two operand matrices, load K, execute, move ofifo -> pmem
task run_qk(input integer ma, input integer mb);
  begin
    // qmem
    for (q = 0; q < total_cycle; q = q + 1) begin
      cyc;
      qmem_wr = 1; if (q > 0) qkmem_add = qkmem_add + 1;
      for (k = 0; k < pr; k = k + 1) mem_in[k*bw +: bw] = M[ma][q][k];
    end
    cyc; qmem_wr = 0; qkmem_add = 0;

    // kmem
    for (q = 0; q < col; q = q + 1) begin
      cyc;
      kmem_wr = 1; if (q > 0) qkmem_add = qkmem_add + 1;
      for (k = 0; k < pr; k = k + 1) mem_in[k*bw +: bw] = M[mb][q][k];
    end
    cyc; kmem_wr = 0; qkmem_add = 0;
    idle(2);

    // K into the processor
    for (q = 0; q < col+1; q = q + 1) begin
      cyc;
      load = 1;
      if (q == 1) kmem_rd = 1;
      if (q > 1)  qkmem_add = qkmem_add + 1;
    end
    cyc; kmem_rd = 0; qkmem_add = 0;
    cyc; load = 0;
    idle(10);

    // execute
    for (q = 0; q < total_cycle; q = q + 1) begin
      cyc;
      execute = 1; qmem_rd = 1;
      if (q > 0) qkmem_add = qkmem_add + 1;
    end
    cyc; qmem_rd = 0; qkmem_add = 0; execute = 0;
    idle(10);

    // ofifo -> pmem
    for (q = 0; q < total_cycle; q = q + 1) begin
      cyc;
      ofifo_rd = 1; pmem_wr = 1;
      if (q > 0) pmem_add = pmem_add + 1;
    end
    cyc; pmem_wr = 0; pmem_add = 0; ofifo_rd = 0;
  end
endtask

// pmem is a synchronous-read SRAM: the loop checks the row requested in the
// previous iteration, then issues the next address.
task readout(input integer which);
  begin
    pass_cnt = 0;
    errors   = 0;
    for (q = 0; q < total_cycle+1; q = q + 1) begin
      cyc;
      if (q > 0) begin
        rowv = (which == 0) ? golden[q-1] :
                 (which == 1) ? golden_norm[q-1] : golden_nv[q-1];
        if (out === rowv) begin
          pass_cnt = pass_cnt + 1;
          $display("core%0d %s row %0d PASS: %40h", ID,
                   (which == 0) ? "qk  " : (which == 1) ? "norm" : "nv  ", q-1, out);
        end
        else begin
          errors = errors + 1;
          $display("core%0d %s row %0d FAIL: got %40h exp %40h", ID,
                   (which == 0) ? "qk  " : (which == 1) ? "norm" : "nv  ", q-1, out, rowv);
        end
      end
      if (q < total_cycle) begin pmem_rd = 1; pmem_add = q; end
      else                       pmem_rd = 0;
    end
    cyc; pmem_rd = 0; pmem_add = 0;
    errors_total = errors_total + errors;
    $display("##### core%0d %s: %0d PASS / %0d FAIL #####", ID,
             (which == 0) ? "RESULT     " : (which == 1) ? "NORM RESULT" : "NV RESULT  ",
             pass_cnt, errors);
  end
endtask


initial begin
  reset = 1;
  done  = 0;
  bar   = 0;
  errors_total = 0;
  mem_in = 0;

  fd = $fopen("qdata.txt",  "r"); read_mat(MQ);
  fd = $fopen(KFILE,        "r"); read_mat(MK);
  fd = $fopen(KFILE_OTHER,  "r"); read_mat(MKO);
  fd = $fopen(NFILE,        "r"); read_mat(MN);
  fd = $fopen("vdata.txt",  "r"); read_mat(MV);

  // golden: Q x K of this core
  mul(MQ, MK);
  for (t = 0; t < total_cycle; t = t + 1) begin pack_row(t); golden[t] = rowv; end
  for (t = 0; t < 8; t = t + 1) for (q = 0; q < 8; q = q + 1) RO[t][q] = R[t][q];

  // golden: normalization, with the other core's row sums from its own K
  mul(MQ, MKO);
  for (t = 0; t < total_cycle; t = t + 1) begin
    s_own = 0; s_oth = 0;
    for (q = 0; q < col; q = q + 1) begin
      s_own = s_own + ((RO[t][q] < 0) ? -RO[t][q] : RO[t][q]);
      s_oth = s_oth + ((R[t][q]  < 0) ? -R[t][q]  : R[t][q]);
    end
    divisor = (s_own >> 7) + (s_oth >> 7);
    if (divisor == 0)
      $display("WARNING core%0d row %0d: divisor is 0, the rtl divide will produce x", ID, t);
    for (q = 0; q < col; q = q + 1) begin
      elem   = ((RO[t][q] < 0) ? -RO[t][q] : RO[t][q]) / divisor;
      rowv = {rowv[bw_psum*(col-1)-1:0], elem};
    end
    golden_norm[t] = rowv;
  end

  // golden: norm x V
  mul(MN, MV);
  for (t = 0; t < total_cycle; t = t + 1) begin pack_row(t); golden_nv[t] = rowv; end

  idle(12);
  reset = 0;

  ///// run 1: Q x K /////
  $display("##### core%0d: Q x K #####", ID);
  run_qk(MQ, MK);
  readout(0);

  ///// normalize pass A: one row sum per row into both sum fifos /////
  cyc; pmem_rd = 1; pmem_add = 0;          // prime row 0
  for (q = 0; q < total_cycle; q = q + 1) begin
    cyc;
    acc = 1;
    if (q < total_cycle-1) begin pmem_rd = 1; pmem_add = q + 1; end
    else                         pmem_rd = 0;
  end
  cyc; acc = 0; pmem_add = 0;              // the last sum lands on this edge
  idle(2);

  ///// normalize pass B: exchange row sums, then divide /////
  $display("##### core%0d: exchange and divide #####", ID);
  for (t = 0; t < total_cycle; t = t + 1) begin
    // Both cores have finished dividing the previous row, so no new transfer
    // can overwrite a sum_rx that is still waiting for its divide.
    barrier;
    cyc; sum_xfer = 1;                     // send this core's row t sum
    cyc; sum_xfer = 0;
    idle(XFER_WAIT);
    barrier;                               // both transfers of row t are done

    cyc; pmem_rd = 1; pmem_wr = 0; norm = 0; pmem_add = t;   // address row t
    cyc; pmem_rd = 0; div = 1;                                // divide
    cyc; div = 0; norm = 1; pmem_wr = 1; pmem_add = t;        // write back
  end
  cyc; norm = 0; pmem_wr = 0; pmem_add = 0;
  readout(1);

  ///// run 2: norm x V, after a reset of this core /////
  // No exchange is in flight: the last barrier above came after both senders
  // were back in S_IDLE.
  cyc; reset = 1;
  idle(12);
  reset = 0;
  $display("##### core%0d: norm x V #####", ID);
  run_qk(MN, MV);
  readout(2);

  done = 1;
end

endmodule
