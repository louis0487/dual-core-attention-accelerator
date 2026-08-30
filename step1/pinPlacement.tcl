setPinAssignMode -pinEditInBatch true
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Left -layer 1 -spreadType center -spacing 4 -pin {clk {inst[0]} {inst[1]} {inst[2]} {inst[3]} {inst[4]} {inst[5]} {inst[6]} {inst[7]} {inst[8]} {inst[9]} {inst[10]} {inst[11]} {inst[12]} {inst[13]} {inst[14]} {inst[15]} {inst[16]} {mem_in[0]} {mem_in[1]} {mem_in[2]} {mem_in[3]} {mem_in[4]} {mem_in[5]} {mem_in[6]} {mem_in[7]} {mem_in[8]} {mem_in[9]} {mem_in[10]} {mem_in[11]} {mem_in[12]} {mem_in[13]} {mem_in[14]} {mem_in[15]} {mem_in[16]} {mem_in[17]} {mem_in[18]} {mem_in[19]} {mem_in[20]} {mem_in[21]} {mem_in[22]} {mem_in[23]} {mem_in[24]} {mem_in[25]} {mem_in[26]} {mem_in[27]} {mem_in[28]} {mem_in[29]} {mem_in[30]} {mem_in[31]} {mem_in[32]} {mem_in[33]} {mem_in[34]} {mem_in[35]} {mem_in[36]} {mem_in[37]} {mem_in[38]} {mem_in[39]} {mem_in[40]} {mem_in[41]} {mem_in[42]} {mem_in[43]} {mem_in[44]} {mem_in[45]} {mem_in[46]} {mem_in[47]} {mem_in[48]} {mem_in[49]} {mem_in[50]} {mem_in[51]} {mem_in[52]} {mem_in[53]} {mem_in[54]} {mem_in[55]} {mem_in[56]} {mem_in[57]} {mem_in[58]} {mem_in[59]} {mem_in[60]} {mem_in[61]} {mem_in[62]} {mem_in[63]} reset}
set out_pins {}
for {set i 0} {$i < 160} {incr i} { lappend out_pins "out\[$i\]"}
puts "out_pins:[llength $out_pins] first=[lindex $out_pins 0] last=[lindex $out_pins end]"

editPin -pinWidth 0.1 -pinDepth 0.52 -fixOverlap 1 -unit MICRON -spreadDirection counterclockwise -side Bottom -layer 2 -spreadType center -spacing 2.0 -pin $out_pins

setPinAssignMode -pinEditInBatch false

