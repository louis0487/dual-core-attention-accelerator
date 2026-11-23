set top_module fullchip
set rtlPath "./verilog"

# Target library
set target_library $env(COURSE_PDK_DB)/tcbn65gpluswc.db 

set link_library $target_library
set symbol_library {}
set wire_load_mode enclosed
set timing_use_enhanced_capacitance_modeling true

set search_path [concat $rtlPath $search_path]
set link_library [concat * $link_library ]

set synthetic_library {}
set link_path [concat  $link_library $synthetic_library]
set dont_use_cells 1
set dont_use_cell_list ""

remove_design -all
if {[file exists template]} {
	exec rm -rf template
}
exec mkdir template
if {![file exists log]} {
    exec mkdir log
}
if {![file exists gate]} {
	exec mkdir gate
}

sh date
sh echo hostname
sh echo uptime

#Compiler directives
set compile_effort   "high"
set compile_no_new_cells_at_top_level false
set hdlin_enable_vpp true
set hdlin_auto_save_templates false

# Parallel execution. compile_ultra uses up to this many cores on the same
# machine (syn_command.pdf, printed page 2127: the default is 1, which means
# no parallel execution, and the maximum is 16). The speedup is not linear -
# only parts of the compile are threaded - and ieng6 is shared, so keep the
# number modest. report_host_options prints what is in effect, and a compile
# whose reported CPU time exceeds its elapsed time is the sign that the
# threads are actually running.
set_host_options -max_cores 4

define_design_lib WORK -path template
set verilogout_single_bit false

# read RTL
analyze -format verilog -lib WORK fullchip.v
analyze -format verilog -lib WORK core.v
analyze -format verilog -lib WORK mac_array.v
analyze -format verilog -lib WORK mac_col.v
analyze -format verilog -lib WORK mac_8in.v
analyze -format verilog -lib WORK sfp_row.v
analyze -format verilog -lib WORK ofifo.v
analyze -format verilog -lib WORK fifo_depth16.v
analyze -format verilog -lib WORK fifo_mux_16_1.v
analyze -format verilog -lib WORK fifo_mux_8_1.v
analyze -format verilog -lib WORK fifo_mux_2_1.v
# The memories are hard macros now, not logic. The behavioural RTL stays out
# and the stub below only declares their ports.
#
# Leaving sram_w16.v out is not enough on its own. elaborate also looks in the
# WORK design library, and that directory survives between runs unless the
# cleanup at the top of this script removes the same path define_design_lib
# points at. Stage A analyzed sram_w16.v into the library in this directory,
# so the first Stage B runs found it there and synthesized all three memories
# as flip-flops anyway, 1088 + 1088 + 2720 = 4896 of them. The clock fanout
# shows it: 9085 loads with the stale library, 4192 with the stubs, which is
# 9085 - 4896 plus the three macro clock pins.
#analyze -format verilog -lib WORK sram_w16.v
analyze -format verilog -lib WORK sram_macro_stub.v
analyze -format verilog -lib WORK sync.v

elaborate $top_module -lib WORK -update
current_design $top_module

# Link Design
link

# Keep the macro stubs exactly as declared.
#
# The count catches a stub that was never analyzed, or a core.v that still
# instantiates sram_w16 with a parameter while the library is clean. It cannot
# tell a stub from a behavioural memory of the same name, which is why the
# library has to be clean; the clock fanout in the log is the cross-check.
#
# What went wrong before came from synthesizing the stale behavioural
# memories: the two 64 bit copies were uniquified into sram_w16_sram_bit64_0
# and _1, and boundary optimization pulled the write enable inverter from
# core.v into the memory, complementing the port and renaming it WEN_BAR (the
# complemented-port case, set_boundary_optimization, syn_command.pdf printed
# page 1874). Neither should happen to these designs: uniquify creates no new
# design for anything carrying dont_touch (printed page 2571) and skips black
# box designs by default (printed page 2570), and with boundary optimization
# off no port is rewritten. The attributes cost nothing and say it explicitly.
set macro_designs [get_designs {sram_w16_sram_bit64 sram_w16_sram_bit160}]
if { [sizeof_collection $macro_designs] != 2 } {
    echo "****************************************************"
    echo "* ERROR!!!! expected 2 macro stub designs           *"
    echo "* Check that sram_macro_stub.v was analyzed and that*"
    echo "* core.v instantiates the macros by name, with no   *"
    echo "* parameter override.                               *"
    echo "****************************************************"
}
set_boundary_optimization $macro_designs false
set_dont_touch $macro_designs true

# Default SDC Constraints
read_sdc ${top_module}.sdc
propagate_constraints

current_design $top_module

set_cost_priority {max_transition max_fanout max_delay max_capacitance}
set_fix_multiple_port_nets -all -buffer_constants
set_fix_hold [all_clocks]

set_driving_cell -lib_cell BUFFD8 -pin Z [all_inputs]
#set_load [get_attribute "$target_library/BUFFD8/A" fanout_load] [all_outputs]
foreach_in_collection p [all_outputs] {
	set_load 0.050 $p
}

#More compiler directives
set compile_effort   "high"
set_app_var ungroup_keep_original_design true
set_register_merging [get_designs $top_module] false
set compile_seqmap_propagate_constants false
set compile_seqmap_propagate_high_effort false
# More constraints and setup before compile
foreach_in_collection design [ get_designs "*" ] {
	current_design $design
	#feedthrough / outputs / constants
	set_fix_multiple_port_nets -all
}
current_design $top_module
# Compile
# Source user compile options
compile_ultra -no_autoungroup -timing_high_effort_script -exact_map

# Write Out Design - Hierarchical
current_design $top_module

change_names -rules verilog -hierarchy

write -format verilog -hier -output [format "%s%s" $top_module .out.v]

# Write Reports
redirect [format "%s%s" log/ $top_module _area.rep] { report_area }
redirect -append [format "%s%s%s" log/ $top_module _area.rep] { report_reference }
redirect [format "%s%s%s" log/ $top_module _power.rep] { report_power }
redirect [format "%s%s%s" log/ $top_module _timing.rep] \
  { report_timing -path full -max_paths 100 -nets -transition_time -capacitance -significant_digits 3 -nosplit}

set inFile  [open log/$top_module\_area.rep]
while { [gets $inFile line]>=0 } {
    if { [regexp {Total cell area:} $line] } {
        set AREA [lindex $line 3]
    }
}
close $inFile
set inFile  [open log/$top_module\_power.rep]
while { [gets $inFile line]>=0 } {
    if { [regexp {Total Dynamic Power} $line] } {
        set PWR [lindex $line 4]
    } elseif { [regexp {Cell Leakage Power} $line] } {  
        set LEAK [lindex $line 4] 
    }
}
close $inFile

set unmapped_designs [get_designs -filter "is_unmapped == true" $top_module]
if {  [sizeof_collection $unmapped_designs] != 0 } {
	echo "****************************************************"
	echo "* ERROR!!!! Compile finished with unmapped logic.  *"
	echo "****************************************************"
}
# Done
sh date
sh uptime

# Done
echo "run.scr completed successfully"
