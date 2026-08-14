# ====================================================================
# 1. Floorplan Setup
# ====================================================================
floorPlan -s 800 500 20.0 20.0 20.0 20.0

# ====================================================================
# 2. Global Net Connections (Standard Cells)
# ====================================================================
globalNetConnect VDD -type pgpin -pin VDD -inst * -verbose
globalNetConnect VSS -type pgpin -pin VSS -inst * -verbose

# ====================================================================
# 3. Core Power Rings & Stripes
# ====================================================================
addRing -spacing {top 1 bottom 1 left 1 right 1} -width {top 2 bottom 2 left 2 right 2} -layer {top M1 bottom M1 left M2 right M2} -center 1 -type core_rings -nets {VSS VDD}

setAddStripeMode -break_at {block_ring}

addStripe -skip_via_on_wire_shape Noshape -block_ring_top_layer_limit M1 -max_same_layer_jog_length 0.8 -padcore_ring_bottom_layer_limit M1 -number_of_sets 10 -skip_via_on_pin Standardcell -stacked_via_top_layer M8 -padcore_ring_top_layer_limit M1 -spacing 0.4 -merge_stripes_value 0.1 -direction horizontal -layer M5 -block_ring_bottom_layer_limit M1 -width 1 -area {} -nets {VDD VSS} -stacked_via_bottom_layer M1

# ====================================================================
# 4. Macro Placement
# ====================================================================

set my_qmem [lindex [dbGet top.insts.name *qmem*] 0]
set my_kmem [lindex [dbGet top.insts.name *kmem*] 0]
set my_psum [lindex [dbGet top.insts.name *psum*] 0]


puts "Found QMEM as: $my_qmem"
puts "Found KMEM as: $my_kmem"
puts "Found PSUM as: $my_psum"


placeInstance $my_qmem 50 50 R90
placeInstance $my_kmem 300 50 R90
placeInstance $my_psum 550 50 R90

addHaloToBlock 10 10 10 10 -allMacro

# ====================================================================
# 5. Macro Power Rings & Connections
# ====================================================================
addRing -nets {VDD VSS} -type block_rings -around each_block -layer {top M3 bottom M3 left M2 right M2} -width {top 0.5 bottom 0.5 left 0.5 right 0.5} -spacing {top 0.5 bottom 0.5 left 0.5 right 0.5}


globalNetConnect VDD -type pgpin -pin VDD -sinst $my_qmem -verbose -override
globalNetConnect VSS -type pgpin -pin VSS -sinst $my_qmem -verbose -override
globalNetConnect VDD -type pgpin -pin VDD -sinst $my_kmem -verbose -override
globalNetConnect VSS -type pgpin -pin VSS -sinst $my_kmem -verbose -override
globalNetConnect VDD -type pgpin -pin VDD -sinst $my_psum -verbose -override
globalNetConnect VSS -type pgpin -pin VSS -sinst $my_psum -verbose -override

# ====================================================================
# 6. Special Routing (Sroute)
# ====================================================================
sroute -connect { blockPin padPin padRing corePin floatingStripe } -layerChangeRange { M1 M5 } -blockPinTarget { nearestTarget } -allowJogging 1 -crossoverViaLayerRange { M1 M5 } -nets { VDD VSS } -allowLayerChange 1

# ====================================================================
# 7. Fix Macro Locations
# ====================================================================

dbSet [dbGet top.insts.name $my_qmem -p].pStatus fixed
dbSet [dbGet top.insts.name $my_kmem -p].pStatus fixed
dbSet [dbGet top.insts.name $my_psum -p].pStatus fixed


