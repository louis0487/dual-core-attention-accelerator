#!/bin/sh
# round2.sh - which tool broke the netlist: Design Compiler or Innovus?
#
# Round 1 established that the routed netlist genuinely carries undriven
# scalar nets whose names embed rd_ptr, key_q and q_temp - the fifo read
# pointer distribution and two mac operand bits. A dead read pointer makes
# every fifo readout X, which matches the all-X result rows exactly.
#
# What round 1 could NOT establish is whether the synthesis netlist already
# has the same damage: its 8 reported "undriven rd_ptr[3:0]" entries came
# from a scanner defect (a part-select load token never collected the per-bit
# flop drivers), so they may all be false alarms. undriven.sh is fixed now,
# and this run makes the call:
#
#   1  undriven.sh selftest       proves the part-select fix
#   2  cmpnl.sh                   honest undriven counts for both netlists
#   3  rd_ptr inside fifo_depth16, synthesis netlist
#        per module: how many lines touch rd_ptr, and how many of those are
#        flop Q outputs driving rd_ptr bits. Zero flop lines = the pointer
#        register is gone and the netlist left synthesis already dead. Four
#        or five flop lines per module = the pointer is intact and the
#        breakage is Innovus's restructuring (setOptMode -restruct is on in
#        placement.tcl). One representative module is printed in full.
#   4  wr_ptr, same check         the write side worked in simulation, so
#                                 this is the control for the method itself:
#                                 it must come back intact
#   5  key_q[53] in mac_col_col_id2, both netlists
#        the routed netlist lost this exact bit (FE_OFN1759_key_q_53,
#        undriven). If the synthesis netlist drives it, that loss too is
#        Innovus's.
#
# Usage, from step1/:
#
#   ./round2.sh 2>&1 | tee round2.log
#
# The log quotes an NDA netlist; *.log is gitignored, never commit it.
#
#   ./round2.sh --selftest        checks only the module-scoped counter

dc=./netlist/fullchip.out.v
pnr=./fullchip.pnr.v
here=$(dirname "$0")

# modscan NETPAT DRVPAT MODFILTER FULLMOD FILE
#   Per module whose name matches MODFILTER: count lines matching NETPAT and,
#   of those, lines matching DRVPAT (the driver shape). The module named
#   FULLMOD additionally gets its matching lines printed in full. Patterns
#   are awk regexes and travel via ENVIRON, not -v: -v processes escape
#   sequences, which turned rd_ptr\[ into an invalid regex.
modscan() {
    NETPAT="$1" DRVPAT="$2" MODFILT="$3" FULLMOD="$4" awk '
    BEGIN { pat = ENVIRON["NETPAT"]; drvpat = ENVIRON["DRVPAT"]
            mfilt = ENVIRON["MODFILT"]; fullmod = ENVIRON["FULLMOD"] }
    /^ *module/ { mod = $2; sub(/\(.*/, "", mod); n = 0; d = 0; buf = "" }
    mod ~ mfilt && $0 ~ pat {
        n++
        if ($0 ~ drvpat) d++
        if (mod == fullmod) buf = buf sprintf("    %6d: %s\n", NR, $0)
    }
    /^ *endmodule/ && mod ~ mfilt && n > 0 {
        printf "  %-44s %3d line(s), %d driver line(s)\n", mod, n, d
        if (buf != "") printf "%s", buf
        mod = ""
    }
    ' "$5"
}

if [ "$1" = "--selftest" ]; then
    t=${TMPDIR:-/tmp}/round2_selftest.$$.v
    cat > "$t" <<'FAKE_EOF'
module fifo_fake_0 ( out, clk );
  wire [4:0] rd_ptr;
  FLOPX1 rd_ptr_reg_0_ ( .CP(clk), .Q(rd_ptr[0]) );
  FLOPX1 rd_ptr_reg_1_ ( .CP(clk), .Q(rd_ptr[1]) );
  MUX16 m ( .sel(rd_ptr[3:0]), .out(out) );
endmodule
module fifo_fake_1 ( out, clk );
  wire [4:0] rd_ptr;
  MUX16 m ( .sel(rd_ptr[3:0]), .out(out) );
endmodule
module unrelated ( o );
  INVX1 u ( .I(rd_ptr_lookalike), .ZN(o) );
endmodule
FAKE_EOF
    out=$(modscan 'rd_ptr\[' '\.Q *\( *rd_ptr\[' 'fifo_fake' 'fifo_fake_0' "$t")
    rm -f "$t"
    echo "$out"
    fail=0
    echo "$out" | grep -q "fifo_fake_0 .* 3 line(s), 2 driver line(s)" || { echo "FAIL: count wrong on fifo_fake_0"; fail=1; }
    echo "$out" | grep -q "fifo_fake_1 .* 1 line(s), 0 driver line(s)" || { echo "FAIL: driverless module miscounted"; fail=1; }
    echo "$out" | grep -q "MUX16"                                      || { echo "FAIL: full listing missing"; fail=1; }
    echo "$out" | grep -q "unrelated"                                  && { echo "FAIL: module filter leaked"; fail=1; }
    [ $fail -eq 0 ] && echo "SELFTEST PASS"
    exit $fail
fi

for f in "$dc" "$pnr"; do
    [ -r "$f" ] || { echo "round2.sh: cannot read $f" >&2; exit 1; }
done

banner() { echo; echo "==================== $1 ===================="; }

banner "1. undriven.sh selftest (part-select fix)"
"$here/undriven.sh" --selftest | tail -1

banner "2. cmpnl.sh with the fixed scanner"
"$here/cmpnl.sh"

banner "3. rd_ptr inside fifo_depth16, synthesis netlist"
echo "  (driver line = a flop Q pin driving an rd_ptr bit)"
modscan 'rd_ptr\[' '\.Q *\( *rd_ptr\[' 'fifo_depth16' 'fifo_depth16_bw20_simd1_0' "$dc"

banner "4. wr_ptr inside fifo_depth16, synthesis netlist (method control)"
modscan 'wr_ptr\[' '\.Q *\( *wr_ptr\[' 'fifo_depth16' '' "$dc"

banner "5. key_q[53] in mac_col_col_id2, synthesis netlist"
modscan 'key_q\[53\]' '\.Q *\( *key_q\[53\]' 'mac_col_bw8_bw_psum20_pr8_col_id2' 'mac_col_bw8_bw_psum20_pr8_col_id2' "$dc"

banner "5b. key_q[53] in mac_col_col_id2, routed netlist"
modscan 'key_q\[53\]' '\.Q *\( *key_q\[53\]' 'mac_col_bw8_bw_psum20_pr8_col_id2' 'mac_col_bw8_bw_psum20_pr8_col_id2' "$pnr"

echo
echo "done - send round2.log back; it stays uncommitted"
