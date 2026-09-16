# Load design - Stage B, the chip with the two SRAM macros linked in.
#
# The difference from loadDesignTech_sram.tcl is three lists. The PDK LEF and
# the PDK timing libraries are no longer alone: each one gains the macros that
# Stage A produced, and Innovus reads Liberty directly, so nothing here needs a
# Synopsys .db - that format was only ever a Design Compiler requirement.
#
# Quoting matters on those three lines. A single file can be passed bare, as
# the _sram version does; a list of files has to be one quoted argument or the
# second path is read as the start of another option.

set libdir            $env(COURSE_PDK)
set design            "fullchip"
set netlist           "./netlist/$design.out.v"

# The chip SDC stays where Design Compiler reads it (run_dc.tcl sources
# ${top_module}.sdc from this directory), so both tools use one file and it
# cannot drift. The per-macro SDCs live in constraints/ because Stage A put
# them there.
set sdc               "./$design.sdc"

set best_timing_lib   "$libdir/lib/tcbn65gplusbc.lib"
set worst_timing_lib  "$libdir/lib/tcbn65gpluswc.lib"
set lef               "$libdir/lef/tcbn65gplus_8lmT2.lef"
set best_captbl       "$libdir/captbl/cln65g+_1p08m+alrdl_top2_cbest.captable"
set worst_captbl      "$libdir/captbl/cln65g+_1p08m+alrdl_top2_cworst.captable"

# Stage A handoff. The abstract carries the boundary, the pins and an
# obstruction that stops at M4, which is what lets this level route over the
# macros on M5 and above.
set macrodir          "./subckt"
set macro_lef         "$macrodir/sram_w16_sram_bit64.lef $macrodir/sram_w16_sram_bit160.lef"
set macro_wc          "$macrodir/sram_w16_sram_bit64_WC.lib $macrodir/sram_w16_sram_bit160_WC.lib"
set macro_bc          "$macrodir/sram_w16_sram_bit64_BC.lib $macrodir/sram_w16_sram_bit160_BC.lib"

foreach f [concat $macro_lef $macro_wc $macro_bc] {
    if {![file readable $f]} {
        puts "loadDesignTech_core: ERROR - cannot read $f"
        puts "loadDesignTech_core: copy the Stage A outputs into $macrodir before running this"
        return
    }
}

# default settings
set init_pwr_net "VDD"
set init_gnd_net "VSS"

# default settings
set init_verilog "$netlist"
set init_design_netlisttype "Verilog"
set init_design_settop 1
set init_top_cell "$design"
set init_lef_file "$lef $macro_lef"

# MCMM setup
create_library_set -name WC_LIB -timing "$worst_timing_lib $macro_wc"
create_library_set -name BC_LIB -timing "$best_timing_lib $macro_bc"
create_rc_corner -name Cmax -cap_table $worst_captbl -T 125
create_rc_corner -name Cmin -cap_table $best_captbl -T -40
create_delay_corner -name WC -library_set WC_LIB -rc_corner Cmax
create_delay_corner -name BC -library_set BC_LIB -rc_corner Cmin
create_constraint_mode -name CON -sdc_file [list $sdc]
create_analysis_view -name WC_VIEW -delay_corner WC -constraint_mode CON
create_analysis_view -name BC_VIEW -delay_corner BC -constraint_mode CON
init_design -setup {WC_VIEW} -hold {BC_VIEW}

set_interactive_constraint_modes {CON}
setDesignMode -process 65

# Read back what actually came in. Each memory has to resolve to one of the
# abstracts above: sram_w16_sram_bit64 twice, sram_w16_sram_bit160 once. A
# cell name with no matching LEF is not an error when the netlist also defines
# it as a module - init_design builds it as an ordinary hierarchical instance
# and carries on with fewer macros. An earlier netlist did exactly that: its
# two 64 bit memories were synthesized logic named _0 and _1. Catch it here,
# in the first minute, not after a full place and route.
puts ""
proc ldc_list {expr_} {
    set v ""
    catch {set v [eval $expr_]}
    if {$v eq "0x0"} { set v "" }
    return $v
}
puts "loadDesignTech_core: memory instances found in the netlist:"
foreach i [ldc_list {dbGet -e top.insts.name *mem*}] {
    puts "    $i"
}
puts "loadDesignTech_core: cells they resolved to:"
foreach c [lsort -unique [ldc_list {dbGet -e top.insts.cell.name *sram*}]] {
    puts "    $c"
}
puts "loadDesignTech_core: an empty list above, or a cell name carrying _0 or _1,"
puts "loadDesignTech_core: means the abstract does not match the netlist."
