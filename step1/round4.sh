#!/bin/sh
# round4.sh - what does each mac_col variant's key path actually look like?
#
# round3 counted MUX and XOR cells with key_q on the line and found 63 MUX in
# col_id2 and nothing anywhere else - clean and X variants alike. So the
# literal net name is on the cells in exactly one variant, and the other
# seven route their load path through renamed intermediate nets. A histogram
# by cell family of every line that mentions the register shows how each
# variant stores and feeds it, without assuming any particular form.
#
#   ./round4.sh                    synthesis netlist
#   NETLIST=./fullchip.pnr.v ./round4.sh
#
# Reading it: DF* lines are the flops themselves (expect ~64 everywhere).
# Anything else that appears in one verdict-class and not the other - mux
# families, AOI/OAI, inverter-heavy storage - is the structural difference
# that decides clean against X. A variant showing ONLY flop lines keeps its
# whole load cone on renamed nets, and the flop count itself still says
# whether all 64 bits kept their registers.
#
#   ./round4.sh --selftest

file=${NETLIST:-./netlist/fullchip.out.v}

scan() {
    awk '
    function fam(s,   c) {
        c = s; sub(/^[ \t]+/, "", c); sub(/[ \t].*/, "", c)
        sub(/D[0-9]+$/, "", c); sub(/[0-9]+$/, "", c)
        return c
    }
    /^ *module/ { mod = $2; sub(/\(.*/, "", mod); split("", H); n = 0 }
    mod ~ /^mac_col/ && /key_q\[/ && !/^ *(wire|input|output)/ {
        H[fam($0)]++; n++
    }
    /^ *endmodule/ && mod ~ /^mac_col/ {
        id = mod; sub(/.*col_id/, "", id)
        verdict = (id == 2 || id == 4 || id == 8) ? "clean" : "X"
        line = ""
        for (f in H) line = line " " f ":" H[f]
        printf "  col_id%-2s (%5s) %3d key_q line(s):%s\n", id, verdict, n, line
        mod = ""
    }
    ' "$1"
}

if [ "$1" = "--selftest" ]; then
    t=${TMPDIR:-/tmp}/round4_selftest.$$.v
    cat > "$t" <<'FAKE_EOF'
module mac_col_bw8_bw_psum20_pr8_col_id2 ( o );
  wire key_q[0];
  DFQD4 key_q_reg_0_ ( .D(n1), .Q(key_q[0]) );
  MUX2D0 U1 ( .I0(a), .I1(key_q[0]), .Z(n1) );
  mac_8in_x m ( .b(key_q[63:0]) );
endmodule
module mac_col_bw8_bw_psum20_pr8_col_id1 ( o );
  DFQD1 key_q_reg_0_ ( .D(n2), .Q(key_q[0]) );
  DFQD1 key_q_reg_1_ ( .D(n3), .Q(key_q[1]) );
endmodule
FAKE_EOF
    out=$(scan "$t")
    rm -f "$t"
    echo "$out"
    fail=0
    echo "$out" | grep -Eq "col_id2 +\(clean\) +3 key_q" || { echo "FAIL: col_id2 total wrong"; fail=1; }
    echo "$out" | grep "col_id2" | grep -q "MUX:1"    || { echo "FAIL: mux family missed"; fail=1; }
    echo "$out" | grep "col_id2" | grep -q "DFQ:1"    || { echo "FAIL: flop family missed"; fail=1; }
    echo "$out" | grep "col_id2" | grep -q "mac_8in_x:1"   || { echo "FAIL: instance connection missed"; fail=1; }
    echo "$out" | grep -Eq "col_id1 +\( +X\) +2 key_q" || { echo "FAIL: col_id1 total wrong"; fail=1; }
    [ $fail -eq 0 ] && echo "SELFTEST PASS"
    exit $fail
fi

[ -r "$file" ] || { echo "round4.sh: cannot read $file" >&2; exit 1; }
echo "netlist: $file"
echo "(verdicts from the run-B waveform; DF*=the flops themselves)"
scan "$file"
