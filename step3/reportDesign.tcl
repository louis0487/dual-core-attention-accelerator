# Post-route reports for step 1.
# Every number quoted in step1/README.md must be traceable to a file produced here.
#
# Command syntax checked against the Innovus Text Command Reference, product
# version 19.11. The tool on the server is 21.1, so a name may still have moved;
# every call that could differ between versions is wrapped in catch so a failure
# cannot abort the run before outputGen.tcl has written the .enc, netlist and SDF.

# ---- timing: WNS, TNS and violating path count, setup and hold ----
# Reports land in ./timingReports/ :
#   fullchip_postRoute.summary        setup WNS / TNS / violating paths
#   fullchip_postRoute_hold.summary   the same for hold
#   fullchip_postRoute_*.tarpt        per path group detail
# timeDesign also reports Density, which is one source for utilization.
timeDesign -postRoute -prefix postRoute
timeDesign -postRoute -hold -prefix postRoute

# ---- detailed critical paths ----
report_timing -late  -max_paths 5 > ${design}.post_route.timing_setup.rpt
report_timing -early -max_paths 5 > ${design}.post_route.timing_hold.rpt

# ---- power ----
report_power -outfile ${design}.post_route.power.rpt

# ---- area, instance count, floorplan and placement density ----
summaryReport -nohtml -outfile ${design}.post_route.summary.rpt

# ---- congestion: reportCongestion requires routing, which has run by now ----
if {[catch {reportCongestion -overflow > ${design}.post_route.congestion.rpt} msg]} {
    puts "WARN: reportCongestion -overflow - $msg"
}
if {[catch {reportCongestion -hotSpot >> ${design}.post_route.congestion.rpt} msg]} {
    puts "WARN: reportCongestion -hotSpot - $msg"
}

# ---- clock tree, CCOpt flow (see clock.tcl) ----
# report_ccopt_skew_groups is the skew report: it gives skew and insertion delay
# per skew group. report_ccopt_clock_trees reports gate depth and buffering,
# which is useful context but is NOT skew - do not quote it as the skew number.
if {[catch {report_ccopt_skew_groups -file ${design}.post_route.skew.rpt} msg]} {
    puts "WARN: report_ccopt_skew_groups - $msg"
}
if {[catch {report_ccopt_clock_trees -summary -file ${design}.post_route.clocktree.rpt} msg]} {
    puts "WARN: report_ccopt_clock_trees - $msg"
}

# ---- numbers for the record; a metric without a tool version does not count ----
if {[catch {puts "RECORD tool      : [getVersion]"} msg]} { puts "WARN: getVersion - $msg" }
if {[catch {puts "RECORD instances : [llength [dbGet top.insts.name]]"} msg]} { puts "WARN: instances - $msg" }
if {[catch {puts "RECORD die box   : [dbGet top.fPlan.box]"} msg]} { puts "WARN: die box - $msg" }
if {[catch {puts "RECORD core box  : [dbGet top.fPlan.coreBox]"} msg]} { puts "WARN: core box - $msg" }

# Utilization comes from the timeDesign Density line or the Floorplan/Placement
# section of summaryReport. To list what the database exposes:  dbGet top.fPlan.?
