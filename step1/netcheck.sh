#!/bin/sh
# netcheck.sh - find out whether a net is actually driven inside its module.
#
# Gate-level simulation reads an undriven net as Z. When a bit of the output
# comes back Z, the usual cause is a net the netlist writer left with a load
# but no driver. This walks the netlist module by module and prints every line
# that mentions the net, tagged with what that line does to it.
#
#   ./netcheck.sh FE_RN_1               # netlist defaults to fullchip.pnr.v
#   ./netcheck.sh FE_RN_1 other.v
#
# The name is matched exactly: FE_RN_1 does not match FE_RN_10. Prefix
# matching is what made the plain grep unreadable.
#
# Read the summary line under each module:
#   drivers=0  -> nothing drives it here. Z confirmed.
#   drivers>0  -> it is driven, so the Z has another source.
#
# DRIVER/LOAD on instance lines is a heuristic: the output pins of
# tcbn65gplus are Z ZN Q QN CO S CON SO, and anything else is taken as an
# input. If one line matters and its tag looks wrong, check that cell in the
# library.
#
# Self-test:  ./netcheck.sh --selftest

net=${1:-}
file=${2:-fullchip.pnr.v}

if [ "$net" = "--selftest" ]; then
    tmp=${TMPDIR:-/tmp}/netcheck_selftest.$$.v
    cat > "$tmp" <<'FAKE_EOF'
module undriven_case ( out );
  output [19:0] out ;
  wire FE_RN_1 ;
  assign out[18] = FE_RN_1 ;
  INVD1BWP U1 ( .I(out[3]), .ZN(out[4]) );
endmodule
module driven_case ( out );
  wire FE_RN_1 ;
  assign out[18] = FE_RN_1 ;
  ND2D1BWP U2 ( .A1(out[0]), .A2(out[1]), .ZN(FE_RN_1) );
  BUFFD2BWP U3 ( .I(FE_RN_1), .Z(out[19]) );
endmodule
module prefix_only ( out );
  wire FE_RN_10 ;
  assign out[7] = FE_RN_10 ;
endmodule
FAKE_EOF
    out=$("$0" FE_RN_1 "$tmp")
    rm -f "$tmp"
    echo "$out"
    fail=0
    echo "$out" | grep -q "prefix_only" && { echo "FAIL: matched FE_RN_10"; fail=1; }
    echo "$out" | grep -q "undriven_case" || { echo "FAIL: missed undriven_case"; fail=1; }
    echo "$out" | grep -q "DECL .* wire FE_RN_1" || { echo "FAIL: wire not tagged DECL"; fail=1; }
    echo "$out" | grep -q "DRIVER (cell out).*ND2D1BWP" || { echo "FAIL: .ZN() not tagged DRIVER"; fail=1; }
    echo "$out" | grep -q "LOAD.*BUFFD2BWP" || { echo "FAIL: .I() not tagged LOAD"; fail=1; }
    echo "$out" | grep -q "undriven_case" -A9 >/dev/null
    echo "$out" | awk '/undriven_case/{m=1} m&&/0 driver/{ok=1} END{exit !ok}' || { echo "FAIL: undriven_case should report 0 drivers"; fail=1; }
    echo "$out" | awk '/driven_case/{m=1} m&&/1 driver/{ok=1} END{exit !ok}' || { echo "FAIL: driven_case should report 1 driver"; fail=1; }
    [ $fail -eq 0 ] && echo "SELFTEST PASS"
    exit $fail
fi

if [ -z "$net" ]; then
    echo "usage: $0 <net_name> [netlist]   (or --selftest)" >&2
    exit 1
fi
if [ ! -r "$file" ]; then
    echo "$0: cannot read $file" >&2
    exit 1
fi

# The net name is passed to awk as data, never spliced into a regex with
# escapes - index() on a whitespace-stripped copy of the line does the pin
# matching instead, so a name containing [ ] or . cannot break the pattern.
awk -v net="$net" '
BEGIN {
    ref = "(^|[^A-Za-z0-9_])" net "([^A-Za-z0-9_]|$)"
    nout = split("Z ZN Q QN CO S CON SO", opin, " ")
}
/^ *module/ {
    mod = $2; sub(/\(.*/, "", mod)
    n = 0; drivers = 0; split("", L)
}
$0 ~ ref {
    sq = $0; gsub(/[ \t]/, "", sq)
    tag = "?"
    if (index(sq, "assign" net "=")) { tag = "DRIVER (assign)"; drivers++ }
    else {
        for (i = 1; i <= nout; i++)
            if (index(sq, "." opin[i] "(" net ")")) { tag = "DRIVER (cell out)"; drivers++; break }
        if (tag == "?") {
            if      ($0 ~ /^ *(wire|input|output|inout)[ \t]/) tag = "DECL"
            else if (index(sq, "(" net ")"))                   tag = "LOAD   (cell in)"
            else if (index(sq, "=" net))                       tag = "LOAD   (assign rhs)"
        }
    }
    L[++n] = sprintf("  %-18s %6d: %s", tag, NR, $0)
}
/^ *endmodule/ {
    if (n > 0) {
        printf "=== module %s ===\n", mod
        for (i = 1; i <= n; i++) print L[i]
        printf "  --> %s: %d driver(s), %d line(s)\n\n", net, drivers, n
        n = 0
    }
}
' "$file"
