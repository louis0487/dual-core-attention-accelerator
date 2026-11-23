#!/bin/bash
# abstract_check.sh - read back what Stage A actually handed over.
#
# DRC and connectivity clean says the block can be manufactured. It says
# nothing about whether the abstract you are about to hand the parent is the
# one the specification asked for. This looks at the handoff itself.
#
# Usage, from step3/ after outputGen has run:
#     DESIGN=sram_w16_sram_bit64 bash abstract_check.sh
#     bash abstract_check.sh sram_w16_sram_bit160
#
# Read-only. Nothing here parses Liberty; the .lib section prints the blocks
# you need to read yourself, because guessing at a format is how a wrong number
# ends up in a report.

set -u
design=${1:-${DESIGN:-fullchip}}
echo "abstract_check: design = $design"
echo

# ------------------------------------------------------------------ 1. files
echo "1. handoff files"
missing=0
for f in "$design.lef" "${design}_WC.lib" "${design}_BC.lib" "$design.pnr.v" \
         "${design}_WC.sdf" "${design}_BC.sdf" "$design.gds2" "$design.def"; do
    if [ -r "$f" ]; then
        printf '  ok      %-40s %s\n' "$f" "$(du -h "$f" | cut -f1)"
    else
        printf '  MISSING %s\n' "$f"
        missing=$((missing + 1))
    fi
done
[ "$missing" -gt 0 ] && echo "  -> $missing file(s) missing; outputGen did not finish"

lef="$design.lef"
if [ ! -r "$lef" ]; then
    echo
    echo "abstract_check: no LEF, stopping"
    exit 1
fi

# -------------------------------------------------------------------- 2. LEF
echo
echo "2. LEF header"
grep -nE '^[[:space:]]*(MACRO|CLASS|SYMMETRY|SIZE|ORIGIN|SITE)[[:space:]]' "$lef" | head -8 | sed 's/^/  /'

echo
echo "3. obstruction layers  <- this is what -specifyTopLayer controls"
obs=$(sed -n '/^[[:space:]]*OBS/,/^[[:space:]]*END/p' "$lef" | grep -oE 'LAYER[[:space:]]+[A-Za-z0-9_]+' | awk '{print $2}' | sort | uniq -c)
if [ -z "$obs" ]; then
    echo "  (no OBS section found)"
else
    echo "$obs" | sed 's/^/  /'
    echo "  Expected: nothing above the fourth routing layer. A metal5 or higher"
    echo "  line here means the flag did not take and the parent cannot cross the"
    echo "  macro at all."
fi

echo
echo "4. pins"
npin=$(grep -cE '^[[:space:]]*PIN[[:space:]]' "$lef")
echo "  PIN entries: $npin"
pg=$(grep -nE 'USE[[:space:]]+(POWER|GROUND)' "$lef" | head -4)
if [ -n "$pg" ]; then
    echo "  power/ground pins present:"
    echo "$pg" | sed 's/^/    /'
else
    echo "  no PG pins in the abstract."
    echo "  That is the -stripePin decision showing up: the parent will have"
    echo "  nothing on M4 to connect VDD/VSS to. Check it at Stage B rather than"
    echo "  assuming sroute will complain."
fi
echo "  first few signal pins:"
grep -E '^[[:space:]]*PIN[[:space:]]' "$lef" | head -4 | sed 's/^/    /'

# -------------------------------------------------------------------- 5. LIB
lib="${design}_WC.lib"
echo
echo "5. timing model ($lib)"
if [ ! -r "$lib" ]; then
    echo "  not readable"
else
    echo "  cell:"
    grep -nE '^[[:space:]]*cell[[:space:]]*\(' "$lib" | head -3 | sed 's/^/    /'
    echo "  timing_type values present:"
    grep -oE 'timing_type[[:space:]]*:[[:space:]]*[a-z_]+' "$lib" | awk -F: '{gsub(/ /,"",$2); print $2}' | sort | uniq -c | sed 's/^/    /'
    echo
    echo "  These two are the contract Stage B inherits. Read them yourself:"
    echo "    setup on the address:  the pin (A[0]) block"
    echo "    access time:           the pin (Q[0]) block, related_pin CLK"
    echo
    for p in 'A\[0\]' 'Q\[0\]' 'CLK'; do
        ln=$(grep -nE "^[[:space:]]*pin[[:space:]]*\([[:space:]]*${p}[[:space:]]*\)" "$lib" | head -1 | cut -d: -f1)
        if [ -n "$ln" ]; then
            echo "  ---- $lib line $ln onwards ----"
            sed -n "${ln},$((ln + 34))p" "$lib" | sed 's/^/  /'
            echo
        else
            echo "  (no pin block matched $p)"
        fi
    done
fi

echo "abstract_check: read-only, nothing was changed"
