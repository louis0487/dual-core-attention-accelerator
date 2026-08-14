setPinAssignMode -pinEditInBatch true

# ------------------------------------------------------------------------------
# Old SRAM Pin Placements (Commented out)
# ------------------------------------------------------------------------------
# editPin -pin Q* -side Top -layer 2 -spacing 4 -spreadDirection clockwise -spreadType center
# editPin -pin D* -side Bottom -layer 2 -spacing 4 -spreadDirection counterclockwise -spreadType center
# editPin -pin {CLK WEN CEN A*} -side Left -layer 3 -spacing 4 -spreadDirection clockwise -spreadType center

# ------------------------------------------------------------------------------
# Old Complex Pin Assignments (Commented out)
# ------------------------------------------------------------------------------
# editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Left -layer 1 -spreadType center -spacing 4 -pin {clk {inst[0]} ... reset}
# editPin -pinWidth 0.1 -pinDepth 0.52 -fixOverlap 1 -unit MICRON -spreadDirection counterclockwise -side Right -layer 2 -spreadType center -spacing 4.0 -pin {{sum_out[0]} ... {sum_out[23]}}

# ------------------------------------------------------------------------------
# NEW Core Pin Placement (Inputs = West/Left, Outputs = South/Bottom)
# ------------------------------------------------------------------------------

# 1. Output pins at South (Bottom edge). Using Layer 2 (Vertical routing).
editPin -pin {out* sum_out*} -side Bottom -layer 2 -spacing 2 -spreadDirection counterclockwise -spreadType center

# 2. Input pins at West (Left edge). Using Layer 3 (Horizontal routing).
editPin -pin {clk reset sfp_fifo_rd inst* mem_in* sum_in*} -side Left -layer 3 -spacing 2 -spreadDirection clockwise -spreadType center

setPinAssignMode -pinEditInBatch false

