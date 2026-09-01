#!/bin/sh
# round5.sh - one register further up: cnt_q and load_ready_q cones.
#
# The key_q enable logic decoded correctly in both a broken and a working
# variant - col_id1 rebuilds inst_q[0] & (cnt==8) & !reset, col_id8 rebuilds
# inst_q[0] & (cnt==1) & !reset, each matching its RTL threshold - so the
# fault sits in what feeds them: col_id1's cnt_q is verifiably X in the
# waveform even though the RTL resets it. The counter's own flops, and
# load_ready_q which gates the counting (and resets to 1, a case DC
# implements differently from reset-to-0), are the next cones up.
#
#   ./round5.sh 2>&1 | tee round5.log

here=$(dirname "$0")
bad=mac_col_bw8_bw_psum20_pr8_col_id1
good=mac_col_bw8_bw_psum20_pr8_col_id8

for m in "$bad" "$good"; do
    for r in cnt_q_reg load_ready; do
        echo "==================== $m / $r ===================="
        "$here/dcone.sh" "$m" "$r"
        echo
    done
done
