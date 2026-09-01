#!/bin/sh
# undriven.sh - every net that has loads but no driver, module by module.
#
# The gate-level simulation returns X. Tracing one net at a time with
# netcheck.sh / portdir.sh / nlshow.sh confirmed that at least one input bit of
# mac_8in is fed by an undriven net, and DC generated several more nets of the
# same family. This does the whole netlist at once instead.
#
# Port directions are read, not guessed: every module defined in the netlist
# contributes its own declarations, and the standard cells contribute theirs
# from the library Verilog. Nothing is inferred from a pin name.
#
#   ./undriven.sh                             whole netlist
#   ./undriven.sh mac_col_bw8_bw_psum20_pr8_col_id3      one module
#   NETLIST=./netlist/fullchip.out.v ./undriven.sh       the synthesis netlist
#
# The library is read where it lives and never copied, so no foundry file
# enters this tree.
#
# Reported categories:
#   UNDRIVEN NET   a net inside the module is read and nothing drives it. In
#                  simulation it is Z, and any gate it feeds goes X.
#   UNDRIVEN OUT   an output port of the module has no driver inside it. This
#                  is expected where the parent never reads that output - the
#                  last column of a chain - and harmless there.
#   unresolved     an instance whose module was found in neither file, so its
#                  pin directions are unknown. A nonzero count means the scan
#                  is incomplete; the names are listed so it can be checked.
#
# Buses are counted in both directions. The first version of this script got
# that wrong and over-reported by an order of magnitude: a port declared
# output [63:0] q_out is driven bit by bit, so the bare name q_out never
# collects a driver of its own and looked dead. So now a bare name counts as
# driven if any of its bits is, and a bit counts as driven if it is, or if
# something drives the whole bus. A bus with one dead bit is still caught,
# because the load sits on that bit.
#
# Self-test:  ./undriven.sh --selftest

file=${NETLIST:-fullchip.pnr.v}
cells=${CELLLIB:-$COURSE_PDK/verilog/tcbn65gplus.v}

if [ "$1" = "--selftest" ]; then
    d=${TMPDIR:-/tmp}/undriven_selftest.$$
    mkdir -p "$d"
    cat > "$d/cells.v" <<'FAKE_EOF'
module INVD1BWP (ZN, I);
  output ZN;
  input I;
endmodule
module ND2D1BWP (ZN, A1, A2);
  output ZN;
  input A1, A2;
endmodule
FAKE_EOF
    cat > "$d/nl.v" <<'FAKE_EOF'
module leaf ( out, a, EXTRA );
  output out ;
  input a ;
  input EXTRA ;
  INVD1BWP U1 ( .I(a), .ZN(out) );
endmodule
module buswide ( wide, i );
  output [3:0] wide ;
  input i ;
  INVD1BWP B0 ( .I(i), .ZN(wide[0]) );
  INVD1BWP B1 ( .I(i), .ZN(wide[1]) );
  INVD1BWP B2 ( .I(i), .ZN(wide[2]) );
  INVD1BWP B3 ( .I(i), .ZN(wide[3]) );
endmodule
module busgap ( o, i );
  output o ;
  input i ;
  wire [1:0] w ;
  INVD1BWP G0 ( .I(i), .ZN(w[0]) );
  ND2D1BWP G1 ( .A1(w[0]), .A2(w[1]), .ZN(o) );
endmodule
module partsel ( o, i );
  output o ;
  input i ;
  wire [3:0] p ;
  wire [3:0] dead ;
  INVD1BWP P0 ( .I(i), .ZN(p[0]) );
  INVD1BWP P1 ( .I(i), .ZN(p[1]) );
  INVD1BWP P2 ( .I(i), .ZN(p[2]) );
  INVD1BWP P3 ( .I(i), .ZN(p[3]) );
  leaf U9 ( .out(o), .a(p[3:0]), .EXTRA(dead[3:0]) );
endmodule
module top ( o, i );
  output o ;
  output deadout ;
  input i ;
  wire good, orphan ;
  INVD1BWP U1 ( .I(i), .ZN(good) );
  leaf U2 ( .out(o), .a(good), .EXTRA(orphan) );
  MYSTERYCELL U3 ( .FOO(i), .BAR(o) );
endmodule
FAKE_EOF
    out=$(NETLIST="$d/nl.v" CELLLIB="$d/cells.v" "$0")
    rm -rf "$d"
    echo "$out"
    fail=0
    echo "$out" | grep -q "UNDRIVEN NET  *orphan"   || { echo "FAIL: orphan not reported"; fail=1; }
    echo "$out" | grep -q "UNDRIVEN OUT  *deadout"  || { echo "FAIL: dead output not reported"; fail=1; }
    echo "$out" | grep -q "UNDRIVEN.* good"         && { echo "FAIL: driven net reported"; fail=1; }
    echo "$out" | grep -q "MYSTERYCELL"             || { echo "FAIL: unknown cell not surfaced"; fail=1; }
    echo "$out" | grep -q "wide"                    && { echo "FAIL: bit-driven bus falsely reported"; fail=1; }
    echo "$out" | grep -q "UNDRIVEN NET  *w\[1\]"   || { echo "FAIL: dead bit of a live bus missed"; fail=1; }
    echo "$out" | grep -q "p\[3:0\]"                && { echo "FAIL: part-select over a bit-driven bus falsely reported"; fail=1; }
    echo "$out" | grep -q "UNDRIVEN NET  *dead\[3:0\]" || { echo "FAIL: undriven part-select missed"; fail=1; }
    [ $fail -eq 0 ] && echo "SELFTEST PASS"
    exit $fail
fi

[ -r "$file" ]  || { echo "$0: cannot read netlist $file" >&2; exit 1; }
[ -r "$cells" ] || { echo "$0: cannot read cell library $cells - set CELLLIB or COURSE_PDK" >&2; exit 1; }

# The netlist is read twice: once for port directions, once for the analysis,
# since a module can be instantiated before it is defined.
awk -v only="$1" '
function base(t,   b) { b = t; sub(/\[.*/, "", b); return b }
function credit(t) { drv[t]++; drvBus[base(t)]++ }
function note(expr, isDrv,   n, T, i, t) {
    gsub(/[{}]/, " ", expr)
    n = split(expr, T, /[ \t,]+/)
    for (i = 1; i <= n; i++) {
        t = T[i]
        if (t == "" || t ~ /^[0-9]/) continue
        if (isDrv) credit(t); else ld[t]++
        seen[t] = 1
    }
}
function ports(s,   i, start, pname, depth, p, expr, d) {
    i = 1
    while (match(substr(s, i), /\.[A-Za-z_][A-Za-z0-9_$]*\(/)) {
        start = i + RSTART - 1
        pname = substr(s, start + 1, RLENGTH - 2)
        depth = 1; p = start + RLENGTH
        while (depth > 0 && p <= length(s)) {
            if (substr(s, p, 1) == "(") depth++
            else if (substr(s, p, 1) == ")") depth--
            p++
        }
        expr = substr(s, start + RLENGTH, p - 1 - (start + RLENGTH))
        d = dir[curtype, pname]
        if (d == "output" || d == "inout") note(expr, 1)
        else if (d == "input")             note(expr, 0)
        else { note(expr, 0); unresolved[curtype " ." pname]++ }
        i = p
    }
}
FNR == 1 { phase++ }

# ---- phases 1 and 2: port directions, from the cell library and the netlist
phase <= 2 {
    if ($0 ~ /^ *(module|primitive)[ \t]/) { u = $2; sub(/\(.*/, "", u) }
    if (dbuf != "")                                   dbuf = dbuf " " $0
    else if ($0 ~ /^ *(input|output|inout)[ \t[]/)    dbuf = $0
    if (dbuf == "" || index(dbuf, ";") == 0) next
    dd = dbuf; sub(/^ */, "", dd); sub(/[ \t].*/, "", dd)
    bb = dbuf; sub(/^ *(input|output|inout)/, "", bb); sub(/;.*/, "", bb)
    gsub(/\[[^]]*\]/, "", bb)
    np = split(bb, P, /[ \t,]+/)
    for (i = 1; i <= np; i++) if (P[i] != "") dir[u, P[i]] = dd
    dbuf = ""
    next
}

# ---- phase 3: driver and load census, netlist only
/^ *module[ \t]/ {
    mod = $2; sub(/\(.*/, "", mod)
    split("", drv); split("", drvBus); split("", ld); split("", seen); split("", isout)
    # An input port of this module is driven from outside; an output must be
    # driven from inside, so it counts as a load.
    for (k in dir) {
        split(k, K, SUBSEP)
        if (K[1] != mod) continue
        if (dir[k] == "input" || dir[k] == "inout") { credit(K[2]); seen[K[2]] = 1 }
        else if (dir[k] == "output")                { ld[K[2]]++; seen[K[2]] = 1; isout[K[2]] = 1 }
    }
    next
}
/^ *assign[ \t]/ {
    a = $0; sub(/^ *assign[ \t]*/, "", a); sub(/;.*/, "", a)
    e = index(a, "=")
    if (e > 0) { note(substr(a, 1, e - 1), 1); note(substr(a, e + 1), 0) }
    next
}
{
    if (!ins && $0 ~ /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]+[^ \t;]/ &&
        $0 !~ /^[ \t]*(module|endmodule|input|output|inout|wire|tri|reg|assign|supply0|supply1|parameter|defparam|specify|endspecify|`|\/\/)/) {
        ins = 1; curtype = $1; ibuf = ""
    }
    if (ins) ibuf = ibuf " " $0
    if (ins && $0 ~ /;[ \t]*$/) { ports(ibuf); ins = 0 }
}
/^ *endmodule/ {
    if (mod == "" || (only != "" && mod != only)) { mod = ""; next }
    hits = 0
    for (t in seen) {
        # A bare bus name is driven if any of its bits is; a bit is driven if
        # it is, or if something drives the whole bus. A part-select token like
        # rd_ptr[3:0] also accepts per-bit drivers - the first version did not,
        # and reported every hierarchical connection written as a part-select
        # over a bit-driven bus as undriven.
        if (t == base(t))                     d = drvBus[t]
        else if (t ~ /\[[0-9]+:[0-9]+\]$/)    d = drv[t] + drv[base(t)] + drvBus[base(t)]
        else                                  d = drv[t] + drv[base(t)]
        if (d > 0 || ld[t] == 0) continue
        if (!hits++) printf "=== module %s ===\n", mod
        printf "  %-13s %-34s loads=%d\n", (isout[t] ? "UNDRIVEN OUT" : "UNDRIVEN NET"), t, ld[t]
        total++
    }
    if (hits) print ""
    mod = ""
}
END {
    printf "%d undriven net(s)\n", total
    nu = 0
    for (k in unresolved) { if (!nu++) print "\nunresolved pins (module not found in netlist or library):"; print "  " k }
    if (!nu) print "all instance pins resolved"
}
' "$cells" "$file" "$file"
