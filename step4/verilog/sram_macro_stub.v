// Synthesis-only stubs for the two SRAM macros built in Stage A.
//
// Why these exist: core.v instantiates the memories by the names the Stage A
// abstracts carry, sram_w16_sram_bit64 and sram_w16_sram_bit160, so Innovus
// can match every memory in the netlist to its LEF. These declarations give
// Design Compiler the ports, widths and directions of those cells; a module it
// has never seen links as an unresolved reference with unknown pin directions.
//
// They are empty on purpose, and they only work if nothing else supplies the
// logic. The first Stage B runs left sram_w16.v out of the analyze list and
// still synthesized all three memories as flip-flops, because a Stage A run
// had left sram_w16 in the WORK design library of the same directory. The
// uniquified _0 / _1 names and the WEN_BAR port came from that logic. See the
// comments in run_dc.tcl for the numbers and for the dont_touch guard.
//
// Port names, order and widths follow sram_w16.v and the widths core.v
// elaborates to: pr*bw = 64 for qmem and kmem, col*bw_psum = 160 for pmem.
//
// WARNING: never put this file in a simulation filelist. It has no body, so
// every memory read returns X - the same signature as the R1 gate-level
// investigation. Simulation uses either the behavioural sram_w16.v or the
// macro's own post-route netlist, never this.

module sram_w16_sram_bit64 (CLK, D, Q, CEN, WEN, A);

  input         CLK;
  input         WEN;
  input         CEN;
  input  [63:0] D;
  input  [3:0]  A;
  output [63:0] Q;

endmodule


module sram_w16_sram_bit160 (CLK, D, Q, CEN, WEN, A);

  input          CLK;
  input          WEN;
  input          CEN;
  input  [159:0] D;
  input  [3:0]   A;
  output [159:0] Q;

endmodule
