#!/bin/sh
# cmpnl.sh - is the defect in synthesis or in place-and-route?
#
# The routed netlist has nets that are read and never driven, which simulate as
# Z and turn the outputs X. The names involved (FE_RN_*, FE_OFN_*, FE_OCPN_*)
# are Design Compiler's, created by the set_fix_multiple_port_nets calls in
# run_dc.tcl, so the netlist may have arrived at Innovus already broken.
#
# This compares the two netlists on the properties that matter, which splits
# the problem in half instead of narrowing it one net at a time:
#
#   already wrong in the synthesis netlist -> fix run_dc.tcl
#   only wrong in the routed netlist       -> fix the Innovus flow, and the
#                                             first suspect is outputGen.tcl,
#                                             where saveNetlist is called with
#                                             no options at all
#
#   ./cmpnl.sh
#   DC_NETLIST=x.v PNR_NETLIST=y.v ./cmpnl.sh
#
# Run it from step1/, after synthesis and after place-and-route.

dc=${DC_NETLIST:-./netlist/fullchip.out.v}
pnr=${PNR_NETLIST:-fullchip.pnr.v}
here=$(dirname "$0")

for f in "$dc" "$pnr"; do
    [ -r "$f" ] || { echo "cmpnl.sh: cannot read $f" >&2; exit 1; }
done
[ -x "$here/undriven.sh" ] || { echo "cmpnl.sh: needs undriven.sh alongside it" >&2; exit 1; }

# The synthesis netlist is written to the directory dc_shell ran in and copied
# into netlist/ by hand, so it can silently be from an older run. Say when.
echo "synthesis netlist : $dc"
ls -l --time-style=+%Y-%m-%d\ %H:%M "$dc"  2>/dev/null | awk '{print "  written        :", $6, $7}'
echo "routed netlist    : $pnr"
ls -l --time-style=+%Y-%m-%d\ %H:%M "$pnr" 2>/dev/null | awk '{print "  written        :", $6, $7}'
if [ -r ./fullchip.out.v ]; then
    if cmp -s ./fullchip.out.v "$dc"; then
        echo "  netlist/ copy matches ./fullchip.out.v"
    else
        echo "  WARNING: ./fullchip.out.v differs from $dc - the copy into netlist/ is stale"
    fi
fi
echo

printf '%-26s %14s %14s\n' "" "synthesis" "routed"
row() { printf '%-26s %14s %14s\n' "$1" "$2" "$3"; }

# grep -c always prints a count but exits 1 when it finds none, so the exit
# status must not be turned into a second line of output.
count() { c=$(grep -c "$1" "$2" 2>/dev/null); echo "${c:-0}"; }

row "lines"                "$(wc -l < "$dc")"                     "$(wc -l < "$pnr")"
row "module definitions"   "$(count '^ *module' "$dc")"           "$(count '^ *module' "$pnr")"
row "1'b0 / 1'b1 constants" "$(count "1'b[01]" "$dc")"            "$(count "1'b[01]" "$pnr")"
row "tie cell instances"   "$(count 'TIE[HL]' "$dc")"             "$(count 'TIE[HL]' "$pnr")"
row "assign statements"    "$(count '^ *assign' "$dc")"           "$(count '^ *assign' "$pnr")"

d_out=$(NETLIST="$dc"  "$here/undriven.sh")
p_out=$(NETLIST="$pnr" "$here/undriven.sh")
row "UNDRIVEN NET"         "$(echo "$d_out" | grep -c 'UNDRIVEN NET')" "$(echo "$p_out" | grep -c 'UNDRIVEN NET')"
row "UNDRIVEN OUT"         "$(echo "$d_out" | grep -c 'UNDRIVEN OUT')" "$(echo "$p_out" | grep -c 'UNDRIVEN OUT')"

echo
echo "scan completeness (a scan with unresolved pins is not a clean result):"
echo "  synthesis : $(echo "$d_out" | tail -1)"
echo "  routed    : $(echo "$p_out" | tail -1)"
echo
echo "full reports written to undriven_dc.txt and undriven_pnr.txt"
printf '%s\n' "$d_out" > undriven_dc.txt
printf '%s\n' "$p_out" > undriven_pnr.txt
