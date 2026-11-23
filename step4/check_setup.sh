#!/bin/bash
# check_setup.sh - verify the step3 working directory before any flow run.
#
# Why a checker and not a copier: the files are already in place.  What is
# worth automating is the question "is what I copied still the right thing,
# and do my constraints name ports that actually exist".  Re-run this after
# every edit; it is read-only.
#
# Run from anywhere:
#     bash step3/check_setup.sh
#
# Exit status 0 = no ERROR lines.  WARN lines are judgement calls, not faults.
#
# Sections:
#   1. inventory   - every file the flow needs is present
#   2. provenance  - which source each copy came from, and whether it has
#                    been edited since (edits are expected once you start)
#   3. sdc sanity  - every port named in an .sdc exists in the module that
#                    .sdc constrains, spelled the same way (Verilog is case
#                    sensitive, and get_ports on a name that does not exist
#                    silently constrains nothing)
#   4. split       - the scripts that need a Stage A and a Stage B version

set -u

root=$(cd "$(dirname "$0")/.." && pwd)
s1="$root/step1"
s2="$root/step2"
s3="$root/step3"
errors=0
warns=0

err()  { echo "  ERROR $*"; errors=$((errors + 1)); }
warn() { echo "  WARN  $*"; warns=$((warns + 1)); }
ok()   { echo "  ok    $*"; }

echo "check_setup: repo root = $root"
for d in "$s1" "$s2" "$s3"; do
    [ -d "$d" ] || { echo "check_setup: ERROR - missing directory $d"; exit 1; }
done

# ---------------------------------------------------------------- 1. inventory
echo
echo "1. inventory"

flow_from_step1="checkNetlist.tcl clean_pnr.sh clock.tcl cmpnl.sh flatOut.tcl \
initialFloorplan.tcl loadDesignTech.tcl outputGen.tcl pinPlacement.tcl \
placement.tcl reportDesign.tcl route.tcl"

from_step2="filelist fullchip.sdc run_dc.tcl kdata.txt kdata_core0.txt \
kdata_core1.txt norm.txt norm_core0.txt norm_core1.txt qdata.txt vdata.txt"

own="orient_probe.tcl sram64.sdc sram160.sdc"

missing=0
for f in $flow_from_step1 $from_step2 $own; do
    [ -f "$s3/$f" ] || { err "missing step3/$f"; missing=$((missing + 1)); }
done
[ "$missing" -eq 0 ] && ok "all $(echo $flow_from_step1 $from_step2 $own | wc -w) expected files present"

n3=$(ls "$s3/verilog"/*.v 2>/dev/null | wc -l)
n2=$(ls "$s2/verilog"/*.v 2>/dev/null | wc -l)
if [ "$n3" -eq "$n2" ]; then
    ok "verilog file count matches step2 ($n3 files)"
else
    err "verilog count is $n3, step2 has $n2"
fi

# -------------------------------------------------------------- 2. provenance
echo
echo "2. provenance (edited = you changed it on purpose; unedited copies of a"
echo "   Stage B script still need Stage A treatment - see section 4)"

for f in $flow_from_step1; do
    if [ -f "$s1/$f" ] && [ -f "$s3/$f" ]; then
        if cmp -s "$s1/$f" "$s3/$f"; then ok "$f  = step1 copy, unedited"
        else                              ok "$f  from step1, EDITED"
        fi
    fi
done
for f in $from_step2; do
    if [ -f "$s2/$f" ] && [ -f "$s3/$f" ]; then
        if cmp -s "$s2/$f" "$s3/$f"; then ok "$f  = step2 copy, unedited"
        else                              ok "$f  from step2, EDITED"
        fi
    fi
done
if diff -rq "$s2/verilog" "$s3/verilog" >/dev/null 2>&1; then
    ok "verilog/  = step2 copy, unedited"
else
    ok "verilog/  from step2, EDITED"
fi

# -------------------------------------------------------------- 3. sdc sanity
echo
echo "3. sdc sanity"

# Which module each .sdc constrains.  Keep this table honest: if you add an
# .sdc, add its module here or it is not checked.
sdc_module() {
    case "$1" in
        fullchip.sdc)            echo "fullchip" ;;
        sram64.sdc|sram160.sdc)  echo "sram_w16" ;;
        *)                       echo "" ;;
    esac
}

# Port list of a module, from the old-style header "module name (a, b, c);"
module_ports() {
    local mod="$1"
    local f
    for f in "$s3"/verilog/*.v; do
        sed -n "/^[[:space:]]*module[[:space:]]\+${mod}[[:space:]]*(/,/)/p" "$f" 2>/dev/null |
            tr '\n' ' ' |
            sed -e "s/.*module[[:space:]]\+${mod}[[:space:]]*(//" -e 's/).*//' \
                -e 's/,/ /g' -e 's/[[:space:]]\+/ /g'
    done
}

for sdc in "$s3"/*.sdc; do
    [ -f "$sdc" ] || continue
    base=$(basename "$sdc")
    mod=$(sdc_module "$base")
    if [ -z "$mod" ]; then
        warn "$base  no module mapping in this script, not checked"
        continue
    fi
    ports=$(module_ports "$mod")
    if [ -z "$ports" ]; then
        err "$base  module '$mod' not found in step3/verilog, cannot check"
        continue
    fi

    # Names referenced literally as  get_ports NAME  or  get_ports {NAME}
    names=$(grep -o 'get_ports[[:space:]]*{\?[A-Za-z_][A-Za-z0-9_]*' "$sdc" |
            sed -e 's/get_ports[[:space:]]*{\?//' | sort -u)
    # Plus the value of  set clock_port NAME , which is used via $clock_port
    cp_val=$(grep -E '^[[:space:]]*set[[:space:]]+clock_port[[:space:]]+' "$sdc" |
             head -1 | awk '{print $3}' | tr -d '"')
    [ -n "$cp_val" ] && names="$names $cp_val"

    bad=0
    for n in $names; do
        case " $ports " in
            *" $n "*) : ;;
            *) err "$base  references port '$n' which module '$mod' does not have"
               bad=1 ;;
        esac
    done
    [ "$bad" -eq 0 ] && ok "$base  all referenced ports exist on '$mod'"

    # The clock port itself usually should not carry an input delay.
    if grep -q 'set_input_delay.*all_inputs' "$sdc"; then
        warn "$base  set_input_delay on [all_inputs] also constrains the clock port"
    fi
done

# ------------------------------------------------------------------- 4. split
echo
echo "4. Stage A / Stage B split"
echo "   These five behave differently for the SRAM macro and for the chip."
echo "   A single unedited copy means Stage A is not set up yet."

for f in loadDesignTech initialFloorplan pinPlacement placement outputGen; do
    a=0; b=0
    [ -f "$s3/${f}_sram.tcl" ] && a=1
    [ -f "$s3/${f}_core.tcl" ] && b=1
    if [ "$a" -eq 1 ] && [ "$b" -eq 1 ]; then
        ok "$f  Stage A and Stage B versions present"
    elif [ -f "$s3/$f.tcl" ]; then
        warn "$f.tcl  single copy - split into ${f}_sram.tcl and ${f}_core.tcl"
    else
        err "$f  no version found"
    fi
done
echo "   Shared by both stages (they read \$design): clock.tcl route.tcl reportDesign.tcl"

echo
echo "check_setup: $errors error(s), $warns warning(s)"
[ "$errors" -eq 0 ]
