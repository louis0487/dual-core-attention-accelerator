# Floorplan
floorPlan -site core -s 550 200 10.0 10.0 10.0 10.0

globalNetConnect VDD -type pgpin -pin VDD -inst * -verbose
globalNetConnect VSS -type pgpin -pin VSS -inst * -verbose

#Power Planning
addRing -spacing {top 2 bottom 2 left 2 right 2} -width {top 3 bottom 3 left 3 right 3} -layer {top M1 bottom M1 left M2 right M2} -center 1 -type core_rings -nets {VSS VDD}

addStripe -number_of_sets 10 -spacing 6 -layer M4 -width 20 -nets { VSS VDD }
set sprCreateIeStripeNets {}
set sprCreateIeStripeLayers {}
set sprCreateIeStripeWidth 10.0
set sprCreateIeStripeSpacing 2.0
set sprCreateIeStripeThreshold 1.0
addStripe -skip_via_on_wire_shape Noshape -block_ring_top_layer_limit M1 -max_same_layer_jog_length 0.8 -padcore_ring_bottom_layer_limit M1 -set_to_set_distance 20 -skip_via_on_pin Standardcell -stacked_via_top_layer M4 -padcore_ring_top_layer_limit M1 -spacing 10 -merge_stripes_value 0.1 -layer M4 -block_ring_bottom_layer_limit M1 -width 2 -area {} -nets {VDD VSS} -stacked_via_bottom_layer M1

sroute
# createPlaceBlockage -box [list 10 90 40 170]
# createPlaceBlockage -box [list 45 90 75 170]
# createPlaceBlockage -box [list 185 90 215 170]
# createPlaceBlockage -box [list 220 90 250 170]

setMaxRouteLayer 4

saveDesign initial.enc

timeDesign -preplace -prefix preplace
