#!/bin/sh
# clean_pnr.sh - clear the previous place-and-route run before starting a new
# one on the re-synthesized netlist.
#
# The netlist changed (sync_set_reset re-synthesis), so every derived artifact
# is stale: databases, routed netlist, SDF, GDS, reports, and the simulation
# snapshot built from the old netlist. Leaving them in place is how this
# debugging effort lost rounds before - a failed step silently hands the next
# command an old file. Text reports are archived, binaries are deleted.
#
#   ./clean_pnr.sh
#
# Kept untouched: verilog/, netlist/ (the NEW synthesis netlist lives there),
# constraints/, all .tcl and .sh tools, the input vectors, README, and the
# investigation logs (round*.log, dcone*.log, gls_postsyn.log - the 8/8 PASS
# record).
#
# Note for the bookkeeping: the M4 metrics recorded on 2026-08-31 (WNS -0.351,
# 47574 instances, and the rest) belong to the OLD netlist. The re-run will
# produce new numbers, and those records need re-measuring - the archive keeps
# the old reports so the two runs can be compared honestly.

arch=pre_syncreset_run
mkdir -p "$arch"

echo "archiving text reports to $arch/ ..."
for p in timingReports fullchip.*.rpt *.summary fullchip.conn.rpt.old fullchip.drc.rpt.old fullchip.geom.rpt.old; do
    [ -e "$p" ] && mv -v "$p" "$arch/" 2>/dev/null
done

echo
echo "deleting stale binaries and databases ..."
for p in *.enc *.enc.dat fullchip.pnr.v fullchip_WC.sdf fullchip_BC.sdf \
         fullchip_WC.lib fullchip_BC.lib fullchip.gds2 fullchip.def fullchip.def.gz \
         streamOut.map scheduling_file.cts* model.asrt* fp_check.txt pin_check.txt \
         xcelium.d fullchip_gls.vcd fullchip_tb.vcd innovus.log* innovus.cmd* \
         inn.cmd* *.logv; do
    [ -e "$p" ] && rm -rf "$p" && echo "  removed $p"
done

echo
echo "left in place:"
ls
