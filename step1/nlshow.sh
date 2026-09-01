#!/bin/sh
# nlshow.sh - look at one instance or one module in the routed netlist.
#
# netcheck.sh and portdir.sh answer questions about a name. This one shows the
# surrounding structure, which is what you need once a name looks wrong: what
# instance is that connection on, and what does the module on the other end
# actually declare.
#
#   ./nlshow.sh -l 36651                 the whole instance line 36651 sits in,
#                                        with the module that contains it
#   ./nlshow.sh -m mac_8in_bw8_bw_psum20_pr8_5
#                                        that module's header and every port
#                                        declaration, so port direction and
#                                        width are visible in one place
#   ./nlshow.sh -c 36651 8               8 raw lines either side, for when the
#                                        structural view misses something
#
#   NETLIST=other.v ./nlshow.sh -l 100   run against a different netlist
#
# Self-test:  ./nlshow.sh --selftest

file=${NETLIST:-fullchip.pnr.v}

if [ "$1" = "--selftest" ]; then
    tmp=${TMPDIR:-/tmp}/nlshow_selftest.$$.v
    cat > "$tmp" <<'FAKE_EOF'
module child ( a, WIDE_PORT, b );
  input a ;
  output [19:0] WIDE_PORT ;
  input b ;
  wire  internal ;
  INVD1BWP U9 ( .I(a), .ZN(internal) );
endmodule
module top ( x );
  wire FE_RN_1 ;
  child U1 ( .a(x),
        .WIDE_PORT(FE_RN_1),
        .b(x) );
  BUFFD2BWP U2 ( .I(x), .Z(x) );
endmodule
FAKE_EOF
    fail=0
    got=$(NETLIST="$tmp" "$0" -l 11)
    echo "$got"
    echo "$got" | grep -q "module: top"      || { echo "FAIL: wrong enclosing module"; fail=1; }
    echo "$got" | grep -q "child U1"         || { echo "FAIL: instance start not backtracked"; fail=1; }
    echo "$got" | grep -q "\.b(x) );"        || { echo "FAIL: instance not read to its end"; fail=1; }
    echo "$got" | grep -q "BUFFD2BWP"        && { echo "FAIL: ran past the instance"; fail=1; }
    echo
    got=$(NETLIST="$tmp" "$0" -m child)
    echo "$got"
    echo "$got" | grep -q "output \[19:0\] WIDE_PORT" || { echo "FAIL: port decl missing"; fail=1; }
    echo "$got" | grep -q "INVD1BWP"         && { echo "FAIL: printed instances, not just ports"; fail=1; }
    rm -f "$tmp"
    [ $fail -eq 0 ] && echo "SELFTEST PASS"
    exit $fail
fi

usage() { echo "usage: $0 -l <line> | -m <module> | -c <line> [context]   (or --selftest)" >&2; exit 1; }
[ -n "$2" ] || usage
[ -r "$file" ] || { echo "$0: cannot read $file" >&2; exit 1; }

case "$1" in
-c)
    n=${3:-5}
    lo=$(($2 - n)); [ $lo -lt 1 ] && lo=1
    sed -n "${lo},$(($2 + n))p" "$file" | cat -n | awk -v lo="$lo" '{ $1 = $1 + lo - 1; print }'
    ;;
-l)
    # An instance can span several lines. Start at a line whose first two
    # tokens are identifiers and which is not a declaration, end at the first
    # line closing with a semicolon.
    awk -v want="$2" '
    /^ *module/ { mod = $2; sub(/\(.*/, "", mod) }
    {
        if (!ins && $0 ~ /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]+[^ \t;]/ &&
            $0 !~ /^[ \t]*(module|endmodule|input|output|inout|wire|tri|reg|assign|supply0|supply1|parameter|defparam|specify|endspecify|`|\/\/)/) {
            ins = 1; s = NR; n = 0; split("", B)
        }
        if (ins) B[++n] = sprintf("%7d: %s", NR, $0)
        if (ins && $0 ~ /;[ \t]*$/) {
            if (want >= s && want <= NR) {
                print "module: " mod
                for (i = 1; i <= n; i++) print B[i]
                found = 1; exit
            }
            ins = 0
        }
    }
    END { if (!found) print "line " want " is not inside an instance (try -c)" }
    ' "$file"
    ;;
-m)
    awk -v M="$2" '
    !on && $0 ~ "^ *module[ \t]+" M "[ \t(]" { on = 1; hdr = 1 }
    on {
        if (hdr)                                   { printf "%7d: %s\n", NR, $0; if (index($0, ";")) hdr = 0; next }
        if ($0 ~ /^ *(input|output|inout)[ \t[]/)  { printf "%7d: %s\n", NR, $0; next }
        if ($0 ~ /^ *endmodule/)                   { found = 1; exit }
    }
    END { if (!found && !on) print "no module named " M }
    ' "$file"
    ;;
*)  usage ;;
esac
