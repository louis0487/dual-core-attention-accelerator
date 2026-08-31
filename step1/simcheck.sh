#!/bin/sh
# simcheck.sh - read a gate-level simulation log for the reasons output goes X.
#
# Both the routed netlist and the synthesis netlist simulate to all X, which
# rules out place-and-route and points at something the two runs share. The
# testbench is verified against the RTL run, so what is left is the invocation
# and the cell library, and the log already says what happened there.
#
#   ./simcheck.sh gls.log
#   ./simcheck.sh gls_postsyn.log
#
# What each section means:
#
#   timing check violations
#       The TSMC cells declare $setuphold and friends with a notifier, and the
#       flop UDP takes that notifier as an input: a violated check forces Q to
#       X on purpose. A netlist with no delays violates every check at once, so
#       a zero-delay run is expected to go X unless timing checks are off. This
#       is a property of the run, not of the netlist. +xmseq_udp_delay only
#       spaces out the sequential UDPs, it does not stop the checks firing.
#
#   elaboration errors and warnings
#       A module that resolves to nothing has no drivers, and everything it
#       feeds is Z then X. This is where that shows up.
#
#   snapshot reuse
#       "Loading snapshot" with no xmelab lines means the design was not
#       rebuilt, so a changed +define+ never took effect and the run does not
#       test what it looks like it tests. Remove xcelium.d and rerun.
#
#   SDF annotation
#       Anything short of 100% leaves the rest of the arcs at zero delay, which
#       is where the timing checks then fire.
#
# Self-test:  ./simcheck.sh --selftest

if [ "$1" = "--selftest" ]; then
    t=${TMPDIR:-/tmp}/simcheck_selftest.$$.log
    # A real elaboration and a reused snapshot are mutually exclusive - the
    # whole point of the reuse check is that no xmelab line appears - so the
    # two cases need separate fixtures.
    cat > "$t" <<'FAKE_EOF'
xmelab: *W,CUVWSP (./verilog/x.v,10|3): module MISSINGCELL is undefined.
xmsim: *W,TCHKMS (/pdk/verilog/tcbn65gplus.v,900|20): Timing violation on setuphold
xmsim: *W,SETUPV: setup time violation at U123.CP
xmsim: *W,HOLDV: hold time violation at U124.CP
SDF Annotation Summary: 91.11% of path delays annotated
##### RESULT: 0 PASS / 8 FAIL #####
FAKE_EOF
    out=$("$0" "$t")
    cat > "$t" <<'FAKE_EOF'
Loading snapshot worklib.fullchip_tb:v .......... Done
##### RESULT: 0 PASS / 8 FAIL #####
FAKE_EOF
    reuse=$("$0" "$t")
    rm -f "$t"
    echo "$out"
    fail=0
    echo "$out"   | grep -q "timing check violations *: 3" || { echo "FAIL: violation count wrong"; fail=1; }
    echo "$out"   | grep -q "MISSINGCELL"                  || { echo "FAIL: elaboration warning missed"; fail=1; }
    echo "$out"   | grep -q "91.11"                        || { echo "FAIL: SDF line missed"; fail=1; }
    echo "$out"   | grep -q "snapshot was reused"          && { echo "FAIL: reuse flagged on a real elaboration"; fail=1; }
    echo "$reuse" | grep -q "snapshot was reused"          || { echo "FAIL: snapshot reuse missed"; fail=1; }
    [ $fail -eq 0 ] && echo "SELFTEST PASS"
    exit $fail
fi

log=${1:-gls.log}
[ -r "$log" ] || { echo "usage: $0 <sim log>   (or --selftest)" >&2; exit 1; }

# Xcelium tags timing check violations with these mnemonics. TCHK covers the
# generic message, the rest are the individual checks.
tchk='TCHKMS|SETUPV|HOLDV|RECOVERY|REMOVAL|WIDTH violation|PERIOD violation|Timing violation'

n_tchk=$(grep -Ec "$tchk" "$log")
n_elab=$(grep -c 'xmelab: \*[EW]' "$log")
n_err=$(grep -c 'xmsim: \*E' "$log")

echo "log: $log"
printf '  %-26s: %s\n' "timing check violations" "$n_tchk"
printf '  %-26s: %s\n' "elaboration errors/warns" "$n_elab"
printf '  %-26s: %s\n' "runtime errors" "$n_err"

if grep -q 'Loading snapshot' "$log" && [ "$(grep -c 'xmelab:' "$log")" -eq 0 ]; then
    echo "  NOTE: the snapshot was reused - no elaboration ran, so any +define+ change did not apply"
fi
echo

if [ "$n_tchk" -gt 0 ]; then
    echo "first timing check violations:"
    grep -E "$tchk" "$log" | head -5 | sed 's/^/  /'
    echo "  ... $n_tchk in total"
    echo
    echo "  A violated check drives the cell notifier, and the flop UDP turns Q to X."
    echo "  In a zero-delay run every check fires, so X here says nothing about the"
    echo "  netlist. Rerun with timing checks disabled before drawing any conclusion."
    echo
fi

if [ "$n_elab" -gt 0 ]; then
    echo "elaboration messages:"
    grep 'xmelab: \*[EW]' "$log" | head -10 | sed 's/^/  /'
    echo
fi

if [ "$n_err" -gt 0 ]; then
    echo "runtime errors:"
    grep 'xmsim: \*E' "$log" | head -10 | sed 's/^/  /'
    echo
fi

if grep -qi 'sdf' "$log"; then
    echo "SDF annotation:"
    grep -i 'sdf' "$log" | head -8 | sed 's/^/  /'
    echo
fi

grep -E '#####|PASS|FAIL' "$log" | tail -5 | sed 's/^/  /'
