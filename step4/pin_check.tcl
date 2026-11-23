# pin_check.tcl - verify the macro's pin plan against the graded specification.
#
# The specification (Project_Instructions_official.md:25) is four claims:
#     D on the bottom edge, Q on the top edge, index 0 counted from the left,
#     every other pin on the left edge, 4 um pitch.
# The GUI shows you roughly which edge a bus landed on. It does not show you
# whether the pitch is exactly 4.000, and it does not show you which end of the
# bus index 0 sits at - and a reversed bus is legal, passes every tool check,
# and only appears later as a bus that crosses itself on the way to the core.
#
# Run it inside Innovus after pinPlacement_sram.tcl, on the same session:
#     source step3/pin_check.tcl
#
# Read-only: it queries the database and prints. It changes nothing and saves
# nothing. Exit lines starting with FAIL are the ones that matter.

proc pc_terms {} {
    set l {}
    catch {set l [dbGet -p top.terms]}
    if {$l eq "" || $l eq "0x0"} { catch {set l [dbGet top.terms]} }
    if {$l eq "0x0"} { set l {} }
    return $l
}

proc pc_nums {ptr attr} {
    if {[catch {dbGet -e $ptr.$attr} v]} { return {} }
    if {$v eq "" || $v eq "0x0"} { return {} }
    return [join $v]
}

# {attribute x y} for a terminal. A rect list collapses to its bounding-box centre.
proc pc_xy {ptr} {
    foreach a {pt rect box} {
        set n [pc_nums $ptr $a]
        set c [llength $n]
        if {$c == 2} { return [list $a [lindex $n 0] [lindex $n 1]] }
        if {$c >= 4 && [expr {$c % 4}] == 0} {
            set xs {}
            set ys {}
            for {set i 0} {$i < $c} {incr i 4} {
                lappend xs [lindex $n $i] [lindex $n [expr {$i + 2}]]
                lappend ys [lindex $n [expr {$i + 1}]] [lindex $n [expr {$i + 3}]]
            }
            set sx [lsort -real $xs]
            set sy [lsort -real $ys]
            return [list $a [expr {([lindex $sx 0] + [lindex $sx end]) / 2.0}] \
                            [expr {([lindex $sy 0] + [lindex $sy end]) / 2.0}]]
        }
    }
    return {}
}

proc pc_edge {px py llx lly urx ury} {
    set dl [expr {$px - $llx}]
    set dr [expr {$urx - $px}]
    set db [expr {$py - $lly}]
    set dt [expr {$ury - $py}]
    set m $dl ; set e LEFT
    if {$dr < $m} { set m $dr ; set e RIGHT }
    if {$db < $m} { set m $db ; set e BOTTOM }
    if {$dt < $m} { set m $dt ; set e TOP }
    return $e
}

# What the specification demands, per bus base name.
array set PC_SPEC {
    D    BOTTOM
    Q    TOP
    CLK  LEFT
    WEN  LEFT
    CEN  LEFT
    A    LEFT
}
set PC_PITCH 4.0
set PC_TOL   0.01

set terms [pc_terms]
if {[llength $terms] == 0} {
    puts "pin_check: ERROR - no top-level terminals found"
    return
}

set box [join [dbGet top.fPlan.box]]
if {[llength $box] < 4} {
    puts "pin_check: ERROR - could not read the die box"
    return
}
set llx [lindex $box 0] ; set lly [lindex $box 1]
set urx [lindex $box 2] ; set ury [lindex $box 3]
puts "pin_check: die box = $box  ([format %.1f [expr {$urx-$llx}]] x [format %.1f [expr {$ury-$lly}]] um)"

set probe [pc_xy [lindex $terms 0]]
if {$probe eq ""} {
    puts "pin_check: ERROR - no usable coordinate attribute on a terminal."
    catch { puts "pin_check: available attributes = [dbGet [lindex $terms 0].?]" }
    return
}
puts "pin_check: coordinates read from attribute '[lindex $probe 0]', [llength $terms] terminals"

# Collect: bus -> list of {index edge running_coordinate name}
array unset PC ; array set PC {}
set skipped 0
foreach t $terms {
    if {$t eq "0x0"} { continue }
    set name [dbGet $t.name]
    set xy [pc_xy $t]
    if {$xy eq ""} { incr skipped ; continue }
    set px [lindex $xy 1] ; set py [lindex $xy 2]
    set edge [pc_edge $px $py $llx $lly $urx $ury]
    # Along a top or bottom edge the bus runs in x; along a side edge, in y.
    set run [expr {($edge eq "TOP" || $edge eq "BOTTOM") ? $px : $py}]
    if {[regexp {^(.+)\[([0-9]+)\]$} $name -> base idx]} {
        lappend PC($base) [list $idx $edge $run $name]
    } else {
        lappend PC($name) [list -1 $edge $run $name]
    }
}
if {$skipped > 0} { puts "pin_check: WARN - $skipped terminal(s) had no readable coordinate" }

puts ""
puts [format "%-6s %5s  %-16s %-8s %-9s %-8s %s" BUS COUNT EDGE INDEX0 PITCH SPEC RESULT]
set fails {}

foreach base [lsort [array names PC]] {
    set rows $PC($base)
    set n [llength $rows]

    # One edge for the whole bus, or it is already wrong.
    set edges {}
    foreach r $rows { lappend edges [lindex $r 1] }
    set edges [lsort -unique $edges]
    set edge [expr {[llength $edges] == 1 ? [lindex $edges 0] : "SPLIT:[join $edges /]"}]

    # Pitch across the bus, and the widest gap, which exposes uneven spreading.
    set runs {}
    foreach r $rows { lappend runs [lindex $r 2] }
    set runs [lsort -real $runs]
    set pitch "-"
    set maxgap "-"
    if {$n > 1} {
        set span [expr {[lindex $runs end] - [lindex $runs 0]}]
        set pitch [format %.3f [expr {$span / ($n - 1)}]]
        set g 0.0
        for {set i 1} {$i < $n} {incr i} {
            set d [expr {[lindex $runs $i] - [lindex $runs [expr {$i-1}]]}]
            if {$d > $g} { set g $d }
        }
        set maxgap [format %.3f $g]
    }

    # Which end index 0 sits at.
    set idx0 "-"
    if {$n > 1} {
        set r0 ""
        foreach r $rows { if {[lindex $r 0] == 0} { set r0 [lindex $r 2] } }
        if {$r0 ne ""} {
            set lo [lindex $runs 0] ; set hi [lindex $runs end]
            if {[expr {abs($r0 - $lo)}] < [expr {abs($r0 - $hi)}]} {
                set idx0 [expr {($edge eq "TOP" || $edge eq "BOTTOM") ? "left" : "bottom"}]
            } else {
                set idx0 [expr {($edge eq "TOP" || $edge eq "BOTTOM") ? "RIGHT" : "TOP"}]
            }
        }
    }

    set want "-"
    if {[info exists PC_SPEC($base)]} { set want $PC_SPEC($base) }

    set bad {}
    if {$want ne "-" && $edge ne $want} { lappend bad "edge is $edge, spec says $want" }
    if {$pitch ne "-" && [expr {abs($pitch - $PC_PITCH)}] > $PC_TOL} {
        lappend bad "pitch is $pitch, spec says $PC_PITCH"
    }
    if {$pitch ne "-" && $maxgap ne "-" && [expr {abs($maxgap - $pitch)}] > $PC_TOL} {
        lappend bad "uneven: widest gap $maxgap against an average of $pitch"
    }
    if {($base eq "D" || $base eq "Q") && $idx0 ne "-" && $idx0 ne "left"} {
        lappend bad "index 0 is at the $idx0 end, spec says from the left"
    }
    set result [expr {[llength $bad] == 0 ? "PASS" : "FAIL"}]
    if {[llength $bad] > 0} { lappend fails [list $base $bad] }

    puts [format "%-6s %5d  %-16s %-8s %-9s %-8s %s" $base $n $edge $idx0 $pitch $want $result]
}

puts ""
if {[llength $fails] == 0} {
    puts "pin_check: PASS - every bus is on the edge the specification names, at [format %.1f $PC_PITCH] um, with index 0 from the left"
} else {
    foreach f $fails {
        foreach reason [lindex $f 1] { puts "FAIL [lindex $f 0]: $reason" }
    }
    puts "pin_check: [llength $fails] bus(es) do not match the specification"
}
puts "RECORD pin_check: read-only, nothing was changed or saved"
