// Simulation models for the two SRAM hard macros.
//
// core.v instantiates the memories by their macro cell names, because that is
// how this step builds the chip: synthesis is shown the ports only
// (sram_macro_stub.v) and place-and-route drops in the Stage A abstracts.
// Behavioural simulation still needs something that behaves like a memory
// behind those names, and that is this file. It wraps the course model rather
// than copying the memory behaviour.
//
// Three files define these two module names, and no two of them may be read
// into the same run:
//
//   sram_macro_stub.v                  ports only, synthesis only
//   sram_macro_model.v                 this file, behavioural, RTL simulation
//   subckt/sram_w16_sram_bit*.pnr.v    Stage A gate level, for gate-level
//                                      simulation with the macro SDFs
//
// The stub in a simulation makes every read return X, which looks exactly
// like a design bug and is not one.
//
// The widths are fixed, because a macro has one size. They match core.v with
// pr = bw = col = 8 and bw_psum = 20: 8 * 8 = 64 for the Q and K memories,
// 8 * 20 = 160 for the partial sum memory. Changing those parameters means
// building new macros, not editing this file.

module sram_w16_sram_bit64 (CLK, D, Q, CEN, WEN, A);

  input  CLK;
  input  CEN;
  input  WEN;
  input  [63:0] D;
  input  [3:0]  A;
  output [63:0] Q;

  sram_w16 #(.sram_bit(64)) macro_body (
        .CLK(CLK),
        .D(D),
        .Q(Q),
        .CEN(CEN),
        .WEN(WEN),
        .A(A)
  );

endmodule


module sram_w16_sram_bit160 (CLK, D, Q, CEN, WEN, A);

  input  CLK;
  input  CEN;
  input  WEN;
  input  [159:0] D;
  input  [3:0]   A;
  output [159:0] Q;

  sram_w16 #(.sram_bit(160)) macro_body (
        .CLK(CLK),
        .D(D),
        .Q(Q),
        .CEN(CEN),
        .WEN(WEN),
        .A(A)
  );

endmodule
