#!/bin/sh
# round1.sh - first evidence harvest of the new investigation round.
#
# The handoff (Dualcore/R1_M5_GLS_handoff.md) left several static questions
# open. Every one of them is answerable without the GUI and without a new
# simulation, so this collects them all in one non-interactive run:
#
#   1  undriven.sh selftest      the fixed version has never run on the real
#                                netlist; prove the tool before trusting it
#   2  cmpnl.sh                  constants, tie cells, assigns and undriven
#                                nets, synthesis netlist vs routed netlist,
#                                plus the stale-copy check on
#                                netlist/fullchip.out.v (handoff 5.8, 5.9)
#   3  FE_* input port usage     DC punched extra input ports through the
#                                hierarchy. An undriven net feeding an UNUSED
#                                port is harmless; feeding a USED port it is
#                                an X source. Reported per module, for both
#                                netlists (handoff 5.3)
#   4  mac_16in references       in the RTL filelist but never analyzed by
#                                run_dc.tcl; a reference from design RTL
#                                would mean a black box (handoff 5.7)
#   5  library directory listing what sits next to tcbn65gplus.v - extra
#                                model files or defines the run may need
#                                (handoff 5.6)
#   6  formal tool probe         whether lec / fm_shell exist here, for the
#                                LEC option (handoff 5.4)
#
# Usage, from step1/:
#
#   ./round1.sh 2>&1 | tee round1.log
#
# The log is full of net and cell names from an NDA netlist. It must never be
# committed; *.log is gitignored.
#
# Self-test (checks only the new port-usage scanner; the other steps reuse
# tools that carry their own selftests):
#
#   ./round1.sh --selftest

here=$(dirname "$0")

# --- the one piece of new logic: per-module usage of FE_* input ports -------
# A port list mention or its own declaration is not usage; any body reference
# is. Declarations are assumed single-line, which holds for DC verilog output.
portscan() {
    awk '
    function refpat(n) { return "(^|[^A-Za-z0-9_])" n "([^A-Za-z0-9_]|$)" }
    /^ *module/ { mod = $2; sub(/\(.*/, "", mod); hdr = 1; n = 0
                  split("", P); split("", C) }
    hdr { if ($0 ~ /\);/) hdr = 0; next }
    /^ *input[ \t]/ {
        line = $0; sub(/;.*/, "", line); sub(/^ *input/, "", line)
        gsub(/\[[^]]*\]/, "", line)
        m = split(line, T, /[ \t,]+/)
        for (i = 1; i <= m; i++)
            if (T[i] ~ /^FE_/) { P[++n] = T[i]; C[T[i]] = 0 }
        next
    }
    /^ *(output|inout|wire)[ \t[]/ { next }
    n > 0 {
        for (i = 1; i <= n; i++)
            if ($0 ~ refpat(P[i])) C[P[i]]++
    }
    /^ *endmodule/ {
        if (n > 0) {
            used = 0; unus = ""
            for (i = 1; i <= n; i++)
                if (C[P[i]] > 0) used++; else unus = unus " " P[i]
            printf "  %-44s %2d FE input port(s): %d used, %d unused%s\n", \
                   mod, n, used, n - used, (unus == "" ? "" : "  UNUSED:" unus)
            total += n; totunused += (n - used)
        }
    }
    END { printf "  ---- %d FE input ports, %d unused\n", total, totunused }
    ' "$1"
}

if [ "$1" = "--selftest" ]; then
    t=${TMPDIR:-/tmp}/round1_selftest.$$.v
    cat > "$t" <<'FAKE_EOF'
module has_both ( out, a,
        FE_OFN9_q_temp_1,
        FE_OFN10_q_temp_2);
  output [19:0] out;
  input [63:0] a;
  input FE_OFN9_q_temp_1;
  input FE_OFN10_q_temp_2;
  wire FE_OFN9_q_temp_1x;
  FAKECELL1 U1 ( .A1(FE_OFN9_q_temp_1), .A2(a[0]), .ZN(out[0]) );
endmodule
module no_fe_ports ( o, i );
  output o;
  input i;
  FAKECELL1 U1 ( .A1(i), .ZN(o) );
endmodule
FAKE_EOF
    out=$(portscan "$t")
    rm -f "$t"
    echo "$out"
    fail=0
    echo "$out" | grep -q "has_both .*2 FE input port(s): 1 used, 1 unused  UNUSED: FE_OFN10_q_temp_2" \
        || { echo "FAIL: used/unused split wrong"; fail=1; }
    echo "$out" | grep -q "no_fe_ports" \
        && { echo "FAIL: module without FE ports reported"; fail=1; }
    # FE_OFN9_q_temp_1x must not have credited FE_OFN9_q_temp_1 (exact match),
    # and the wire declaration must not count as usage either - the single
    # counted reference must be the FAKECELL1 line.
    echo "$out" | grep -q "1 used" || { echo "FAIL: exact-match reference lost"; fail=1; }
    [ $fail -eq 0 ] && echo "SELFTEST PASS"
    exit $fail
fi

dc=./netlist/fullchip.out.v
pnr=./fullchip.pnr.v

banner() { echo; echo "==================== $1 ===================="; }

banner "1. undriven.sh selftest"
"$here/undriven.sh" --selftest | tail -1

banner "2. cmpnl.sh (constants / tie cells / undriven, both netlists)"
"$here/cmpnl.sh"

banner "3. FE_* input port usage, synthesis netlist"
[ -r "$dc" ] && portscan "$dc" || echo "  cannot read $dc"

banner "3b. FE_* input port usage, routed netlist"
[ -r "$pnr" ] && portscan "$pnr" || echo "  cannot read $pnr"

banner "4. mac_16in references in design RTL"
grep -rn 'mac_16in' ./verilog/ 2>/dev/null || echo "  (none)"

banner "5. library verilog directory"
if [ -n "${COURSE_PDK:-}" ]; then
    ls -l "$COURSE_PDK/verilog/" 2>/dev/null || echo "  cannot list $COURSE_PDK/verilog"
else
    echo "  COURSE_PDK is not set"
fi

banner "6. formal tool availability"
for t in lec fm_shell formality; do
    p=$(command -v "$t" 2>/dev/null)
    printf '  %-10s %s\n' "$t" "${p:-not found}"
done

echo
echo "done - send round1.log back; it is gitignored and must stay uncommitted"
