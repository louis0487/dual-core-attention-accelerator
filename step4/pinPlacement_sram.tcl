# Pin placement for the SRAM macro (Stage A).
#
# This is the graded specification, not a free choice
# (Project_Instructions_official.md:25): 4 um pin pitch, D on the bottom edge,
# Q on the top edge, index 0 counted from the left, every other pin on the left
# edge. The three commands below are the reference implementation of it.
#
# Layer split: data pins on M2, control pins on M3, power stripes on M4. The
# signal pins and the power grid therefore never compete for the same layer,
# which is what lets M4 be handed to the parent as the power interface.
#
# Index order: on the top edge clockwise runs left to right, and on the bottom
# edge counterclockwise runs left to right, so both buses start at the left as
# the specification requires. Confirm it in the layout before the macro is
# frozen - a reversed bus is legal, passes every check here, and only shows up
# later as a bus that crosses itself on the way to the core.

setPinAssignMode -pinEditInBatch true

editPin -pin Q* -side Top -layer 2 -spacing 4 -spreadDirection clockwise -spreadType center
editPin -pin D* -side Bottom -layer 2 -spacing 4 -spreadDirection counterclockwise -spreadType center
editPin -pin {CLK WEN CEN A*} -side Left -layer 3 -spacing 4 -spreadDirection clockwise -spreadType center

setPinAssignMode -pinEditInBatch false
