# orient_probe.tcl - measure what each Innovus orientation code does to a block
#
# Why this exists:
#   Innovus accepts eight orientation codes.  The instance attribute is
#   documented as
#       orient(settable): enum(MX MX90 MY MY90 R0 R180 R270 R90 Unknown)
#   (innovusTCR.pdf p.293 and p.299), but the manual never states which way
#   R90 turns.  Guessing costs a full floorplan round, because a macro is
#   fixed once placed.  So measure it.
#
#   This script places ONE instance at the SAME spot in all eight
#   orientations and reports, for each probe pin, which edge of the instance
#   the pin landed on and how far along that edge it sits.
#
# Usage inside Innovus, after the macro LEF is loaded and the instance exists:
#       source step3/orient_probe.tcl
#   With no setup it probes the first instance whose name contains "qmem",
#   using D[0], D[last], Q[0], Q[last] and CLK.  To aim it somewhere else,
#   set any of these before sourcing:
#       set OP_INST psum
#       set OP_PINS {D[0] D[159] Q[0] CLK}
#       set OP_X 100
#       set OP_Y 100
#
# Reading the table:
#       BOTTOM@0.02   the pin sits on the bottom edge, 2% of the way along
#                     that edge measured from the left (or from the bottom,
#                     for a left/right edge).
#   Compare D[0] against D[last] to see which way the bus runs after the
#   rotation - that is the bit-order question, not just the edge question.
#
# This script writes no file and saves no design.  It restores the original
# location, orientation and placement status on the way out.  Do NOT
# saveDesign from the session you ran it in.

proc op_instterms {ip} {
    set l {}
    catch {set l [dbGet -p $ip.instTerms]}
    if {$l eq "" || $l eq "0x0"} { catch {set l [dbGet $ip.instTerms]} }
    if {$l eq "0x0"} { set l {} }
    return $l
}

proc op_base {n} {
    set k [string last "/" $n]
    if {$k >= 0} { return [string range $n [expr {$k + 1}] end] }
    return $n
}

proc op_nums {ptr attr} {
    if {[catch {dbGet -e $ptr.$attr} v]} { return {} }
    if {$v eq "" || $v eq "0x0"} { return {} }
    return [join $v]
}

# Return {attribute x y} for a pin, trying the attributes that can carry a
# location.  A rect list collapses to the centre of its bounding box.
proc op_xy {ptr} {
    foreach a {pt rect box} {
        set n [op_nums $ptr $a]
        set c [llength $n]
        if {$c == 2} {
            return [list $a [lindex $n 0] [lindex $n 1]]
        }
        if {$c >= 4 && [expr {$c % 4}] == 0} {
            set xs {}
            set ys {}
            for {set i 0} {$i < $c} {incr i 4} {
                lappend xs [lindex $n $i] [lindex $n [expr {$i + 2}]]
                lappend ys [lindex $n [expr {$i + 1}]] [lindex $n [expr {$i + 3}]]
            }
            set sx [lsort -real $xs]
            set sy [lsort -real $ys]
            set cx [expr {([lindex $sx 0] + [lindex $sx end]) / 2.0}]
            set cy [expr {([lindex $sy 0] + [lindex $sy end]) / 2.0}]
            return [list $a $cx $cy]
        }
    }
    return {}
}

proc op_edge {px py llx lly urx ury} {
    set dl [expr {$px - $llx}]
    set dr [expr {$urx - $px}]
    set db [expr {$py - $lly}]
    set dt [expr {$ury - $py}]
    set w  [expr {$urx - $llx}]
    set h  [expr {$ury - $lly}]
    set m $dl
    set e LEFT
    if {$dr < $m} { set m $dr ; set e RIGHT }
    if {$db < $m} { set m $db ; set e BOTTOM }
    if {$dt < $m} { set m $dt ; set e TOP }
    set f 0.0
    if {$e eq "LEFT" || $e eq "RIGHT"} {
        if {$h > 0} { set f [expr {($py - $lly) / $h}] }
    } else {
        if {$w > 0} { set f [expr {($px - $llx) / $w}] }
    }
    return [format "%-6s@%.2f" $e $f]
}

proc op_find_pin {ip pin} {
    foreach it [op_instterms $ip] {
        if {$it eq "0x0"} { continue }
        if {[string equal [op_base [dbGet $it.name]] $pin]} { return $it }
    }
    return ""
}

# Highest index found among pins named <base>[n]; -1 if the base does not exist.
proc op_last_bit {ip base} {
    set best -1
    set pat [format {^%s\[([0-9]+)\]$} $base]
    foreach it [op_instterms $ip] {
        if {$it eq "0x0"} { continue }
        if {[regexp $pat [op_base [dbGet $it.name]] -> idx]} {
            if {$idx > $best} { set best $idx }
        }
    }
    return $best
}

if {![info exists OP_INST]} { set OP_INST "qmem" }
if {![info exists OP_X]}    { set OP_X 50 }
if {![info exists OP_Y]}    { set OP_Y 50 }

# Announce immediately: a silent source means the wrong file was read.
puts "orient_probe: starting, instance pattern = *${OP_INST}*"

set op_ptrs [dbGet -p top.insts.name *${OP_INST}*]
if {$op_ptrs eq "0x0" || [llength $op_ptrs] == 0} {
    puts "orient_probe: ERROR - no instance matches *${OP_INST}*, nothing measured"
    return
}
set ip [lindex $op_ptrs 0]
set op_name [dbGet $ip.name]
puts "orient_probe: [llength $op_ptrs] instance(s) matched, probing $op_name"

if {![info exists OP_PINS]} {
    set OP_PINS {}
    foreach b {D Q} {
        set last [op_last_bit $ip $b]
        if {$last >= 0} {
            lappend OP_PINS "${b}\[0\]"
            if {$last > 0} { lappend OP_PINS "${b}\[$last\]" }
        }
    }
    lappend OP_PINS CLK
    puts "orient_probe: probe pins chosen automatically: $OP_PINS"
}

set op_first [op_find_pin $ip [lindex $OP_PINS 0]]
if {$op_first eq ""} {
    puts "orient_probe: ERROR - pin [lindex $OP_PINS 0] not found on $op_name"
    puts "orient_probe: first 20 pin names on this instance:"
    set c 0
    foreach it [op_instterms $ip] {
        if {$c >= 20} { break }
        puts "    [dbGet $it.name]"
        incr c
    }
    return
}
catch { puts "orient_probe: instTerm attributes = [dbGet $op_first.?]" }
set op_probe [op_xy $op_first]
if {$op_probe eq ""} {
    puts "orient_probe: ERROR - no usable coordinate attribute on the pin."
    puts "orient_probe: run  dbGet $op_first.?  and add the right attribute to op_xy"
    return
}
puts "orient_probe: pin coordinates read from attribute '[lindex $op_probe 0]'"

set op_pt0 [join [dbGet $ip.pt]]
set op_or0 [dbGet $ip.orient]
set op_ps0 [dbGet $ip.pStatus]
puts "orient_probe: original orient=$op_or0 pStatus=$op_ps0 pt=$op_pt0"

if {$op_ps0 eq "fixed" || $op_ps0 eq "cover"} {
    puts "orient_probe: instance is $op_ps0, relaxing to placed so it can be moved"
    catch { dbSet $ip.pStatus placed }
}

set op_hdr [format "%-6s" "ORIENT"]
foreach p $OP_PINS { append op_hdr [format " | %-13s" $p] }
puts ""
puts "orient_probe: every row places the instance at $OP_X $OP_Y; edge is relative to the instance box"
puts $op_hdr

foreach o {R0 R90 R180 R270 MX MY MX90 MY90} {
    if {[catch { placeInstance $op_name $OP_X $OP_Y $o } msg]} {
        puts [format "%-6s | placeInstance failed: %s" $o $msg]
        continue
    }
    set b [join [dbGet $ip.box]]
    if {[llength $b] < 4} {
        puts [format "%-6s | could not read instance box" $o]
        continue
    }
    set llx [lindex $b 0]
    set lly [lindex $b 1]
    set urx [lindex $b 2]
    set ury [lindex $b 3]
    set row [format "%-6s" $o]
    foreach p $OP_PINS {
        set it [op_find_pin $ip $p]
        if {$it eq ""} {
            append row [format " | %-13s" "not found"]
            continue
        }
        set xy [op_xy $it]
        if {$xy eq ""} {
            append row [format " | %-13s" "no coord"]
            continue
        }
        append row [format " | %-13s" [op_edge [lindex $xy 1] [lindex $xy 2] $llx $lly $urx $ury]]
    }
    append row [format "   box={%s}" $b]
    puts $row
}

puts ""
if {[catch { placeInstance $op_name [lindex $op_pt0 0] [lindex $op_pt0 1] $op_or0 } msg]} {
    puts "orient_probe: WARNING - could not restore placement: $msg"
}
catch { dbSet $ip.pStatus $op_ps0 }
puts "orient_probe: restored orient=[dbGet $ip.orient] pStatus=[dbGet $ip.pStatus] pt=[join [dbGet $ip.pt]]"
if {$op_ps0 eq "unplaced"} {
    puts "orient_probe: NOTE - this instance was unplaced before the run; re-source your floorplan script before continuing"
}
puts "RECORD orient_probe: the table above is the measured meaning of each code - do NOT saveDesign from this session"
