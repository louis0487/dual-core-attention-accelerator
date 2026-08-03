# Floorplan
#
# Akalantri modified - starting util lowered for optimal density
# iter 2 trial with 70 pc start util
#floorPlan -s 780 500 10.0 10.0 10.0 10.0
floorPlan -s 780 500 10.0 10.0 10.0 10.0
#floorPlan -site core -r 2 0.80 10.0 10.0 10.0 10.0


globalNetConnect VDD -type pgpin -pin VDD -inst * -verbose
globalNetConnect VSS -type pgpin -pin VSS -inst * -verbose

addRing -spacing {top 2 bottom 2 left 2 right 2} -width {top 3 bottom 3 left 3 right 3} -layer {top M1 bottom M1 left M2 right M2} -center 1 -type core_rings -nets {VSS VDD}

setAddStripeMode -break_at {block_ring}

addStripe -skip_via_on_wire_shape Noshape -block_ring_top_layer_limit M1 -max_same_layer_jog_length 0.8 -padcore_ring_bottom_layer_limit M1 -set_to_set_distance 16 -skip_via_on_pin Standardcell -stacked_via_top_layer M8 -padcore_ring_top_layer_limit M1 -spacing 3 -merge_stripes_value 0.1 -direction horizontal -layer M5 -block_ring_bottom_layer_limit M1 -width 1.6 -area {} -nets {VDD VSS} -stacked_via_bottom_layer M1

# Can play around with locations again since flipping and rotation is not feasible for hooking up full pg pins of macros!!
setObjFPlanBox Instance core_instance_gen_0__core_instance/qmem_instance 81.845 352.0 221.845 452.0
setObjFPlanBox Instance core_instance_gen_0__core_instance/kmem_instance 81.845 190.0 221.845 290.0
setObjFPlanBox Instance core_instance_gen_0__core_instance/psum_mem_instance 140.005 38.8 770.005 158.8

# kmem and qmem are flipped and rotated such that the inputs of both these mems face the inputs of Core. this way it'be aligned well
# Potential downside - clock port of each mem will move to the bottom. When the clock tree is created in core, mems *might* have detoured clock path,but shouldn't be that bad...lets see

#flipOrRotateObject -rotate R90 -name qmem_instance
#flipOrRotateObject -flip MY -name qmem_instance
#flipOrRotateObject -rotate R90 -name kmem_instance
#flipOrRotateObject -flip MY -name kmem_instance

flipOrRotateObject -flip MX -name core_instance_gen_0__core_instance/psum_mem_instance

addHaloToBlock {3 3 3 3} core_instance_gen_0__core_instance/qmem_instance
addHaloToBlock {3 3 3 3} core_instance_gen_0__core_instance/kmem_instance
addHaloToBlock {3 3 3 3} core_instance_gen_0__core_instance/psum_mem_instance


addRing -type block_rings -nets {VSS VDD} -around each_block -spacing {top 0.5 bottom 0.5 left 0.5 right 0.5} -width {top 1 bottom 1 left 1 right 1} -layer {top M3 bottom M3 left M2 right M2}

globalNetConnect VDD -type pgpin -pin VDD -sinst core_instance_gen_0__core_instance/qmem_instance    -verbose -override
globalNetConnect VSS -type pgpin -pin VSS -sinst core_instance_gen_0__core_instance/qmem_instance    -verbose -override
globalNetConnect VDD -type pgpin -pin VDD -sinst core_instance_gen_0__core_instance/kmem_instance    -verbose -override
globalNetConnect VSS -type pgpin -pin VSS -sinst core_instance_gen_0__core_instance/kmem_instance    -verbose -override
globalNetConnect VDD -type pgpin -pin VDD -sinst core_instance_gen_0__core_instance/sum_mem_instance -verbose -override
globalNetConnect VSS -type pgpin -pin VSS -sinst core_instance_gen_0__core_instance/sum_mem_instance -verbose -override


sroute


# Fix macro loc before placement, otherwise tool will surely move the macros
dbSet [dbGet top.insts.name core_instance_gen_0__core_instance/mem_instance -p].pStatus fixed
dbSet [dbGet top.insts.name core_instance_gen_0__core_instance/mem_instance -p].pStatus fixed
dbSet [dbGet top.insts.name core_instance_gen_0__core_instance/sum_mem_instance -p].pStatus fixed
