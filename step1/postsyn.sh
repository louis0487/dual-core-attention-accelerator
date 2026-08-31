#!/bin/sh
# postsyn.sh - post-synthesis gate-level simulation, done right.
#
# The first attempt at this run was typed by hand and lost the sequential UDP
# delay flag on the way: gls_postsyn.log contains no xmseq_udp_delay, so that
# run measured the zero-delay race - data and clock reaching every flop in
# the same instant - which turns ANY netlist to X, broken or perfect. Its
# 0/8 result says nothing and retired the wrong suspect.
#
# This wraps the documented invocation so no flag can go missing again, and
# verifies afterwards that the flag actually reached the simulator.
#
#   ./postsyn.sh          runs, logs to gls_postsyn.log, checks itself
#
# Expected outcomes:
#   8/8 PASS   the synthesis netlist is functionally sound, which upgrades
#              the static evidence (zero undriven nets, intact pointers) to
#              dynamic proof. The fault lives entirely in place-and-route.
#   0/8 all-X  a real mechanism survives on a clean netlist with the race
#              floored - go to the waveform and look at rd_ptr of one
#              fifo_depth16: counting from zero, or X.

here=$(dirname "$0")
log=gls_postsyn.log

# A stale snapshot would resimulate the previous elaboration with the old
# flags, silently ignoring the ones added here.
rm -rf xcelium.d

NETLIST=./netlist/fullchip.out.v \
NO_SDF=1 \
SEQ_UDP=+xmseq_udp_delay+20ps \
"$here/run_gui" 2>&1 | tee "$log"

echo
echo "---- self-check ----"
if grep -q 'xmseq_udp_delay' "$log"; then
    echo "OK: xmseq_udp_delay reached the simulator"
else
    echo "INVALID RUN: xmseq_udp_delay is not in the log - do not use this result"
fi
grep -c 'xmelab:' "$log" | awk '{ if ($1 > 0) print "OK: fresh elaboration (" $1 " xmelab lines)";
                                  else print "INVALID RUN: snapshot reuse, no elaboration" }'
grep '#####' "$log" | tail -1
