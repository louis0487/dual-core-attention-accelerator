# Floorplan - Stage B, the chip with the three SRAM macros placed.
#
# The macros set the size here, not the cell area. With a 10 um halo all round
# and the Stage A abstracts (64 bit 280 x 79, 160 bit 670 x 78):
#   width  = psum_mem 670 + 10 + 10                   = 690
#   height = psum_mem row 98 + qmem 300 + kmem 300    = 698
# That leaves one rectangle for the standard cells, (109,108)-(700,708),
# 591 x 600 = 354600 um2, for 151790.40 um2 of cells (log/fullchip_area.rep),
# a density of 42.8 percent.
#
#   +------+---------------------------+
#   | kmem |                           |
#   +------+       standard cells      |
#   | qmem |                           |
#   +------+---------------------------+
#   |            psum_mem              |
#   +----------------------------------+
#
# psum_mem lies on the bottom edge flipped, D up towards the logic that fills it
# and Q down onto out[159:0]. qmem and kmem are turned a quarter clockwise, D
# left towards mem_in and Q right towards the core.

# Orientation codes, read off the orient_probe.tcl tables. The manual does not
# say which way R90 turns, so these are measured, not assumed.
#   ori_pmem : psum_mem with D on TOP, Q on BOTTOM and D[0] at the left end
#   ori_qk   : qmem with D on LEFT, Q on RIGHT and CLK on TOP
# Run orient_probe in its own session and restart before sourcing this file;
# its header says not to save a design from the session it ran in.
set ori_pmem ""
set ori_qk   ""
if {$ori_pmem eq "" || $ori_qk eq ""} {
    puts "initialFloorplan: ERROR - set ori_pmem and ori_qk from the orient_probe tables first"
    return
}

floorPlan -site core -s 690 698 10.0 10.0 10.0 10.0

globalNetConnect VDD -type pgpin -pin VDD -inst * -verbose
globalNetConnect VSS -type pgpin -pin VSS -inst * -verbose

# Lower left corner of each macro, in die coordinates. Exact instance names, not
# a wildcard: the archived tcl/step3 script took the first match of *qmem*, got
# an ordinary cell, and its macro placement did nothing without an error.
# placeInstance snaps to the nearest site and fixes the instance by default
# (innovusTCR p.2397).
placeInstance core_instance/psum_mem_instance 20 20  $ori_pmem
placeInstance core_instance/qmem_instance     20 118 $ori_qk
placeInstance core_instance/kmem_instance     20 418 $ori_qk

# Halos only after placement: the manual defines them on the current
# orientation (p.761).
foreach m {psum_mem_instance qmem_instance kmem_instance} {
    addHaloToBlock 10 10 10 10 core_instance/$m
}

# No standard cell rows under the macros (cutRow with no options cuts them at
# every block, p.880), so sroute lays no M1 rails over their obstruction.
cutRow

# Power planning
addRing -spacing {top 2 bottom 2 left 2 right 2} -width {top 3 bottom 3 left 3 right 3} -layer {top M1 bottom M1 left M2 right M2} -center 1 -type core_rings -nets {VSS VDD}

# The step1 stripes were on M4, and the macro abstracts obstruct M1-M4, so no
# stripe may cross a macro below M5. The macro power pins are its M4 stripes
# (write_lef_abstract -stripePin -PGpinLayers 4), and a stripe that crosses a
# block power pin gets a via onto it by default (-skip_via_on_pin defaults to
# Standardcell only, p.2806). So power comes from above, across each macro's
# pins:
#   M6 vertical   - across qmem and kmem, whose M4 pins turn horizontal with
#                   the rotation; also feeds the standard cell rails, at the
#                   20 um pitch the step1 M4 stripes used
#   M5 horizontal - across psum_mem, whose M4 pins stay vertical after a flip
# Offset 30 puts the first sets over the macros, M6 inside x 20-99 and M5
# inside y 20-98. The manual measures the offset from the boundary of the
# stripe area without saying whether that is the core edge or the ring, so
# check in the GUI that every macro has a VDD/VSS pair across it.
addStripe -nets {VDD VSS} -layer M6 -direction vertical -width 2 -spacing 2 -set_to_set_distance 20 -start_from left -start_offset 30 -stacked_via_bottom_layer M1 -stacked_via_top_layer M6
addStripe -nets {VDD VSS} -layer M5 -direction horizontal -width 2 -spacing 2 -set_to_set_distance 40 -start_from bottom -start_offset 30 -stacked_via_bottom_layer M1 -stacked_via_top_layer M6

# Only the standard cell follow pins. The macro pins are already tied in by the
# stripe vias; left to its default, sroute tries all five kinds (p.2862).
sroute -connect {corePin}

setMaxRouteLayer 6

saveDesign ${design}_initial.enc

timeDesign -preplace -prefix ${design}_preplace
