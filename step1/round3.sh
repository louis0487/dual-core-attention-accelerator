#!/bin/sh
# round3.sh - how did each mac_col variant implement the key_q load?
#
# The run-B waveform localised the X to the mac columns themselves, with a
# hard split: col_id 2, 4, 8 compute every psum cleanly, col_id 1, 3, 5, 6, 7
# are X on every psum. All eight instantiate the same RTL; DC uniquified them
# and optimised each separately, so they can differ in structure.
#
# The suspect register is key_q: loaded once, never refreshed, X poisons the
# whole column. RTL load semantics overwrite an X unconditionally. A gate
# implementation only does so if the load path ISOLATES the old value:
#
#   isolating   MUX2 (.I0(q_in), .I1(key_q), .S(en))   AND(0,X)=0 kills X
#   sticky      any XOR/XNR with the register on an input: X^a = X for all a,
#               so an X old value survives the load forever
#
# col_id2 is verifiably mux-form (round2 printed its MUX2D0) and is a clean
# column. This counts, per variant, the load-path cell families that mention
# key_q or query_q, and prints the observed verdict next to the expected one.
#
#   ./round3.sh                    on the synthesis netlist (the origin)
#   NETLIST=./fullchip.pnr.v ./round3.sh
#
# Read the table: X columns showing XOR lines where clean columns show MUX
# lines confirms the mechanism. All-zero XOR counts everywhere would mean the
# feedback taps an intermediate net rather than the named one - inconclusive,
# and the next tool is a D-cone tracer, not a conclusion.
#
#   ./round3.sh --selftest

file=${NETLIST:-./netlist/fullchip.out.v}

scan() {
    awk '
    /^ *module/ { mod = $2; sub(/\(.*/, "", mod)
                  nmk = 0; nxk = 0; nmq = 0; nxq = 0 }
    mod ~ /^mac_col/ {
        if ($0 ~ /key_q\[/) {
            if ($0 ~ /(MUX|MX)[A-Z0-9]*D[0-9]/) nmk++
            if ($0 ~ /(XOR|XNR)[A-Z0-9]*D[0-9]/) nxk++
        }
        if ($0 ~ /query_q\[/) {
            if ($0 ~ /(MUX|MX)[A-Z0-9]*D[0-9]/) nmq++
            if ($0 ~ /(XOR|XNR)[A-Z0-9]*D[0-9]/) nxq++
        }
    }
    /^ *endmodule/ && mod ~ /^mac_col/ {
        id = mod; sub(/.*col_id/, "", id)
        expect = (id == 2 || id == 4 || id == 8) ? "clean" : "X"
        printf "  %-40s key_q: %3d MUX %3d XOR | query_q: %3d MUX %3d XOR | waveform: %s\n", \
               mod, nmk, nxk, nmq, nxq, expect
        mod = ""
    }
    ' "$1"
}

if [ "$1" = "--selftest" ]; then
    t=${TMPDIR:-/tmp}/round3_selftest.$$.v
    cat > "$t" <<'FAKE_EOF'
module mac_col_bw8_bw_psum20_pr8_col_id2 ( o );
  MUX2D0 U1 ( .I0(q_in[53]), .I1(key_q[53]), .S(n6), .Z(n134) );
  MUX2D0 U2 ( .I0(q_in[52]), .I1(key_q[52]), .S(n6), .Z(n135) );
  XNR2D1 U3 ( .A1(query_q[3]), .A2(n9), .ZN(n10) );
endmodule
module mac_col_bw8_bw_psum20_pr8_col_id5 ( o );
  XOR2D1 U1 ( .A1(key_q[10]), .A2(n7), .Z(n99) );
  CKXOR2D1 U2 ( .A1(key_q[11]), .A2(n8), .Z(n98) );
endmodule
module not_a_mac_col ( o );
  MUX2D0 U1 ( .I0(a), .I1(key_q[1]), .S(s), .Z(o) );
endmodule
FAKE_EOF
    out=$(scan "$t")
    rm -f "$t"
    echo "$out"
    fail=0
    echo "$out" | grep -Eq "col_id2 +key_q: +2 MUX +0 XOR \| query_q: +0 MUX +1 XOR \| waveform: clean" || { echo "FAIL: col_id2 counts wrong"; fail=1; }
    echo "$out" | grep -Eq "col_id5 +key_q: +0 MUX +2 XOR .* waveform: X" || { echo "FAIL: col_id5 counts wrong"; fail=1; }
    echo "$out" | grep -q "not_a_mac_col" && { echo "FAIL: module filter leaked"; fail=1; }
    [ $fail -eq 0 ] && echo "SELFTEST PASS"
    exit $fail
fi

[ -r "$file" ] || { echo "round3.sh: cannot read $file" >&2; exit 1; }
echo "netlist: $file"
echo "(expected from the run-B waveform: col_id 2,4,8 clean; 1,3,5,6,7 X)"
scan "$file"
