# Floorplan for one SRAM macro (Stage A).
#
# The size comes from two constraints:
#
#   1. cell area at about 80 percent utilization, from the Stage A synthesis
#      area reports:
#          sram_w16_sram_bit64    12129.48 um2
#          sram_w16_sram_bit160   30068.64 um2
#
#   2. the 4 um pin pitch, which puts a hard floor under the width. D and Q run
#      along the bottom and top edges, so the edge has to be longer than
#      (bits - 1) * 4 um: 252 um for 64 bits, 636 um for 160 bits. A square
#      floorplan would be about 207 um a side for the 160 bit macro, and the
#      pins would not fit - which is why this uses -s and not -r.
#
# The width below is that pin floor rounded up; the height follows from
# area / utilization / width. Innovus snaps the core to the row grid, so read
# the achieved utilization back from the tool rather than trusting this
# arithmetic.
#
# $width and $design are set by loadDesignTech_sram.tcl.

switch -- $width {
    64      { set core_w 260 ; set core_h 59 }
    160     { set core_w 650 ; set core_h 58 }
    default { puts "initialFloorplan_sram: ERROR - no die size defined for width '$width'" ; return }
}

puts "initialFloorplan_sram: $design  core ${core_w} x ${core_h} um, margin 10 on each side"

floorPlan -site core -s $core_w $core_h 10.0 10.0 10.0 10.0

globalNetConnect VDD -type pgpin -pin VDD -inst * -verbose
globalNetConnect VSS -type pgpin -pin VSS -inst * -verbose

# Power planning.
# The core ring needs 3 + 2 + 3 = 8 um per side, which is what the 10 um die
# margin above is for.
addRing -spacing {top 2 bottom 2 left 2 right 2} -width {top 3 bottom 3 left 3 right 3} -layer {top M1 bottom M1 left M2 right M2} -center 1 -type core_rings -nets {VSS VDD}

# M4 stripes. Every 20 um carries one VDD/VSS pair 2 um wide, so M4 ends up
# 20 percent power and 80 percent free for signal routing. M4 is also the top
# layer of this macro and the layer the parent will connect power through
# (write_lef_abstract -stripePin -PGpinLayers 4), so this pattern is the power
# interface of the finished macro, not just an internal detail.
#
# The step1 script had a second, earlier addStripe with -width 20
# -number_of_sets 10. That was sized for a 550 x 200 block: ten sets of 20 um
# wide stripes is 400 um of solid metal, which would bury a core this narrow.
# Dropped here on purpose.
set sprCreateIeStripeNets {}
set sprCreateIeStripeLayers {}
set sprCreateIeStripeWidth 10.0
set sprCreateIeStripeSpacing 2.0
set sprCreateIeStripeThreshold 1.0
addStripe -skip_via_on_wire_shape Noshape -block_ring_top_layer_limit M1 -max_same_layer_jog_length 0.8 -padcore_ring_bottom_layer_limit M1 -set_to_set_distance 20 -skip_via_on_pin Standardcell -stacked_via_top_layer M4 -padcore_ring_top_layer_limit M1 -spacing 6 -merge_stripes_value 0.1 -layer M4 -block_ring_bottom_layer_limit M1 -width 2 -area {} -nets {VDD VSS} -stacked_via_bottom_layer M1

sroute

# Cap the macro at M4 so the parent can route over it on M5 and above.
# write_lef_abstract -specifyTopLayer 4 then limits the abstract's obstruction
# to the same four layers; without it the abstract obstructs every routing
# layer in the technology and nothing can cross the macro at all.
setMaxRouteLayer 4

saveDesign ${design}_initial.enc

timeDesign -preplace -prefix ${design}_preplace
