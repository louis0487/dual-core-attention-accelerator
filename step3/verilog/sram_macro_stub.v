// Synthesis-only stubs for the two SRAM macros built in Stage A.
//
// Why these exist: with no module declaration at all, Design Compiler treats
// the memories as unresolved black boxes that it owns. The first Stage B run
// proved what that costs - it uniquified the two 64 bit instances into
// sram_w16_sram_bit64_0 and _1, and boundary optimization pulled the write
// enable inverter through the port and renamed it WEN_BAR. Innovus then
// matched only sram_w16_sram_bit160 against the abstracts and silently built
// the other two as empty hierarchical shells.
//
// Declaring the ports here removes the guesswork. run_dc.tcl additionally
// sets dont_touch and turns boundary optimization off on both designs, which
// is what stops the uniquify and the port rename. All three are needed.
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
