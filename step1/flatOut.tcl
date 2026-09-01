# Flatten the hierarchy in the database, then regenerate the two files the
# gate-level simulation consumes.
#
# Background: checkDesign proved the database has zero undriven nets, yet the
# hierarchical netlist saveNetlist writes carries 25 of them - optimization
# punched nets across module boundaries and the writer drops some of those
# connections, leaving a local wire with a load and no driver. Simulation
# reads the defective text file, so the readout shifts by one row where the
# holes hit rd_ptr distribution and flips single bits where they hit mac
# operands. With the hierarchy dissolved there are no boundaries to write
# wrong, and the SDF written from the same flattened session names the same
# instances the netlist does.
#
# Physical results are untouched: GDS, DEF and LEF from the hierarchical run
# stay valid, and this session is saved separately as route_flat.enc - do NOT
# overwrite route.enc, the hierarchical database remains the reference. The
# flat .enc also serves the later VCD-to-Voltus power measurement, whose
# instance names must match the simulated netlist.
#
# Run inside Innovus, on the restored routed design:
#   restoreDesign route.enc.dat fullchip
#   source flatOut.tcl
# Then outside:  ./cmpnl.sh   (routed UNDRIVEN NET must drop to 0;
#                              module count dropping to 1 is expected)

if {![info exists design]} { set design fullchip }

ungroup * -flatten

saveNetlist ${design}.pnr.v

setAnalysisMode -setup
set_analysis_view -setup WC_VIEW -hold WC_VIEW
write_sdf -view WC_VIEW ${design}_WC.sdf

setAnalysisMode -hold
set_analysis_view -setup BC_VIEW -hold BC_VIEW
write_sdf -view BC_VIEW ${design}_BC.sdf

saveDesign route_flat.enc

puts "RECORD flatOut: netlist, WC/BC sdf and route_flat.enc written from the flattened database"
