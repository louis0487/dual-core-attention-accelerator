# Native Innovus netlist checks, for the gate-level simulation debug.
#
# The routed netlist has nets that carry a load and no driver, which reads as
# Z in simulation. Rather than keep parsing the Verilog by hand, ask the tool.
#
# Run it on the routed database:
#   innovus
#   restoreDesign route.enc.dat fullchip
#   source checkNetlist.tcl
#
# checkDesign options, from the Innovus Text Command Reference 19.11:
#   -netlist      netlist checking, valid at any point after the design loads
#   -danglingNet  nets with no instance or top-level terminals; needs -netlist
#   -tieHiLo      tie-high and tie-low pin checking
#   -assigns      reports all assign statements, including assigns to 1'b0/1'b1
#
# What to look for in the report:
#   undriven / no driver nets    the Z source, if it is in the database
#   tie hi/lo pins unconnected   constants that never got a driver. outputGen
#                                calls saveNetlist with no options, and the
#                                manual says the default writes 1'b* constants,
#                                yet the netlist contains none - so either the
#                                constants never reached the database, or they
#                                were dropped on the way out
#   assign statements            the netlist has only four; the report says
#                                what the database thinks they are

if {![info exists design]} { set design fullchip }

checkDesign -netlist -danglingNet -tieHiLo -assigns \
            -noHtml -outfile ${design}.checkDesign.rpt

reportDanglingNet -outfile ${design}.danglingNet.rpt

puts "RECORD wrote ${design}.checkDesign.rpt and ${design}.danglingNet.rpt"
