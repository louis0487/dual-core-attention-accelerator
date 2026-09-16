# Pin placement - Stage B, pins lined up with the macro pins they drive.
#
# Positions follow initialFloorplan.tcl: core 690 x 698 inside a 10 um margin,
# psum_mem at (20,20), qmem at (20,118), kmem at (20,418), 10 um halos.
#
# Direction along an edge: in Stage A, counterclockwise on the bottom edge and
# clockwise on the top edge both put index 0 at the left. Going round the same
# rectangle, clockwise on the left edge runs bottom to top and counterclockwise
# runs top to bottom. Every list below is built in index order, so index 0 is
# the pin at the start point.

# The end of qmem's left edge where D[0] lands after the rotation, top or
# bottom, read off the same orient_probe table as ori_qk.
set qk_d0_end ""
if {$qk_d0_end ne "top" && $qk_d0_end ne "bottom"} {
    puts "pinPlacement: ERROR - set qk_d0_end to top or bottom from the orient_probe table first"
    return
}

setPinAssignMode -pinEditInBatch true

# out[159:0] on the bottom edge at the 4 um pitch of psum_mem's Q pins. Both
# groups are centred on x = 355, the die centre and the macro centre, so each
# out[i] sits straight under Q[i].
set out_pins {}
for {set i 0} {$i < 160} {incr i} { lappend out_pins "out\[$i\]" }
editPin -pinWidth 0.1 -pinDepth 0.52 -fixOverlap 1 -unit MICRON -spreadDirection counterclockwise -side Bottom -layer 2 -spreadType center -spacing 4 -pin $out_pins

# mem_in[63:0] drives D on both 64 bit macros. Centre the group on the channel
# between them, y = 408, which spans 282 to 534, and start it at the end where
# D[0] sits, so every bit runs the same way into both macros.
set mem_pins {}
for {set i 0} {$i < 64} {incr i} { lappend mem_pins "mem_in\[$i\]" }
if {$qk_d0_end eq "top"} {
    editPin -fixOverlap 1 -unit MICRON -side Left -layer 3 -spacing 4 -spreadType start -start {0 534} -spreadDirection counterclockwise -pin $mem_pins
} else {
    editPin -fixOverlap 1 -unit MICRON -side Left -layer 3 -spacing 4 -spreadType start -start {0 282} -spreadDirection clockwise -pin $mem_pins
}

# inst[15:12] is the address of qmem and kmem, and the Stage A critical path
# starts at the address pin. Keep these four just above mem_in, between the
# address pins of the two macros.
set addr_pins {}
for {set i 12} {$i < 16} {incr i} { lappend addr_pins "inst\[$i\]" }
editPin -fixOverlap 1 -unit MICRON -side Left -layer 3 -spacing 4 -spreadType start -start {0 538} -spreadDirection clockwise -pin $addr_pins

# The rest beside psum_mem, whose address is inst[11:8].
set ctrl_pins {clk reset}
for {set i 0} {$i < 20} {incr i} {
    if {$i < 12 || $i > 15} { lappend ctrl_pins "inst\[$i\]" }
}
editPin -fixOverlap 1 -unit MICRON -side Left -layer 3 -spacing 4 -spreadType start -start {0 20} -spreadDirection clockwise -pin $ctrl_pins

setPinAssignMode -pinEditInBatch false
