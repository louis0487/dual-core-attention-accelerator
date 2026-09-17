# The chip layout only references the macros. Merge their Stage A layouts in,
# or the GDS has three empty cells (streamOut -merge, innovusTCR p.1669).
set macro_gds "./subckt/sram_w16_sram_bit64.gds2 ./subckt/sram_w16_sram_bit160.gds2"
foreach f $macro_gds {
    if {![file readable $f]} {
        puts "outputGen: ERROR - cannot read $f; copy the Stage A GDS into ./subckt first"
        return
    }
}
streamOut ${design}.gds2 -merge $macro_gds
write_lef_abstract ${design}.lef
defOut -netlist -routing ${design}.def
saveNetlist ${design}.pnr.v

setAnalysisMode -setup
set_analysis_view -setup WC_VIEW -hold WC_VIEW
do_extract_model -view WC_VIEW -format dotlib ${design}_WC.lib
write_sdf -view WC_VIEW ${design}_WC.sdf

setAnalysisMode -hold
set_analysis_view -setup BC_VIEW -hold BC_VIEW
do_extract_model -view BC_VIEW -format dotlib ${design}_BC.lib
write_sdf -view BC_VIEW ${design}_BC.sdf

setAnalysisMode -setup
set_analysis_view -setup WC_VIEW -hold BC_VIEW
