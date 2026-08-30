# Post-route reports for step 1.
# Every number quoted in step1/README.md must be traceable to a file produced here.

# ---- timing: WNS, TNS and violating path count, setup and hold ----
timeDesign -postRoute -prefix postRoute
timeDesign -postRoute -hold -prefix postRoute

# ---- detailed critical paths ----
report_timing -late  -max_paths 5 > ${design}.post_route.timing_setup.rpt
report_timing -early -max_paths 5 > ${design}.post_route.timing_hold.rpt

# ---- power ----
report_power -outfile ${design}.post_route.power.rpt

# ---- area, instance count, density ----
summaryReport -nohtml -outfile ${design}.post_route.summary.rpt

# ---- clock tree skew: this flow uses CCOpt, see clock.tcl ----
# Wrapped in catch so a command-name difference between Innovus versions cannot
# abort the run before outputGen.tcl has written the .enc, netlist and SDF.
if {[catch {report_ccopt_clock_trees > ${design}.post_route.clocktree.rpt} msg]} {
    puts "WARN: report_ccopt_clock_trees failed - find the right name with: help *clock_tree*"
    puts "WARN: $msg"
}

# ---- numbers for the record; tool version is required before a metric counts ----
if {[catch {puts "RECORD tool      : [getVersion]"} msg]} { puts "WARN: getVersion - $msg" }
if {[catch {puts "RECORD instances : [llength [dbGet top.insts.name]]"} msg]} { puts "WARN: instances - $msg" }
if {[catch {puts "RECORD die box   : [dbGet top.fPlan.box]"} msg]} { puts "WARN: die box - $msg" }
if {[catch {puts "RECORD core box  : [dbGet top.fPlan.coreBox]"} msg]} { puts "WARN: core box - $msg" }

# Congestion is not reported here. This flow reads it out of the routeDesign log
# (search for "Overflow"). If this Innovus version has a report command for it,
# find the name with:  help *ongest*
# Utilization attributes vary by version; list what is available with:
#   dbGet top.fPlan.?
