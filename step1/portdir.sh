#!/bin/sh
# portdir.sh - which module declares this port, and in which direction?
#
# netcheck.sh tags a connection like  .SOME_PORT(net)  by looking the pin name
# up in the standard cell output list. That works for library cells and fails
# for hierarchical instances, where the port belongs to another module in the
# same netlist. A port that turns out to be an output means the net IS driven
# and netcheck's "0 driver(s)" was a false alarm.
#
#   ./portdir.sh FE_OFCPN556_q_temp_126
#   ./portdir.sh PORT_A PORT_B PORT_C          # several at once
#   NETLIST=other.v ./portdir.sh PORT_A
#
# A name reported as "not declared as a port anywhere" is a plain net, so the
# connection that mentions it really is a library cell pin - look that cell up
# in the library instead.
#
# Self-test:  ./portdir.sh --selftest

file=${NETLIST:-fullchip.pnr.v}

if [ "$1" = "--selftest" ]; then
    tmp=${TMPDIR:-/tmp}/portdir_selftest.$$.v
    cat > "$tmp" <<'FAKE_EOF'
module child ( a, FE_OFN9_q_temp_1, b );
  input a ;
  output [19:0] FE_OFN9_q_temp_1 ;
  input b ;
endmodule
module sink ( c, IN_ONLY );
  input c, IN_ONLY ;
  output d ;
endmodule
module top ( x );
  wire FE_RN_1 ;
  child U1 ( .a(x), .FE_OFN9_q_temp_1(FE_RN_1), .b(x) );
endmodule
FAKE_EOF
    out=$(NETLIST="$tmp" "$0" FE_OFN9_q_temp_1 IN_ONLY NOSUCHPORT)
    rm -f "$tmp"
    echo "$out"
    fail=0
    echo "$out" | grep -q "output .*FE_OFN9_q_temp_1 .*child"  || { echo "FAIL: output port missed"; fail=1; }
    echo "$out" | grep -q "input .*IN_ONLY .*sink"             || { echo "FAIL: grouped input decl missed"; fail=1; }
    echo "$out" | grep -q "NOSUCHPORT: not declared"           || { echo "FAIL: absent port not reported"; fail=1; }
    [ $fail -eq 0 ] && echo "SELFTEST PASS"
    exit $fail
fi

if [ -z "$1" ]; then
    echo "usage: $0 <port> [port...]   (or --selftest)" >&2
    exit 1
fi
if [ ! -r "$file" ]; then
    echo "$0: cannot read $file" >&2
    exit 1
fi

awk -v want="$*" '
BEGIN { nw = split(want, W, " "); for (i = 1; i <= nw; i++) wanted[W[i]] = 1 }
/^ *module/ { mod = $2; sub(/\(.*/, "", mod) }
{
    # A declaration can run over several lines, so collect until the semicolon.
    if (buf != "")                                   buf = buf " " $0
    else if ($0 ~ /^ *(input|output|inout)[ \t[]/) { buf = $0; start = NR }
    if (buf == "" || index(buf, ";") == 0) next

    dir = buf; sub(/^ */, "", dir); sub(/[ \t].*/, "", dir)
    body = buf; sub(/^ *(input|output|inout)/, "", body); sub(/;.*/, "", body)
    gsub(/\[[^]]*\]/, "", body)                      # drop the bit range
    np = split(body, P, /[ \t,]+/)
    for (i = 1; i <= np; i++)
        if (P[i] != "" && (P[i] in wanted)) {
            printf "%-7s %-34s in module %-40s line %d\n", dir, P[i], mod, start
            seen[P[i]] = 1
        }
    buf = ""
}
END {
    for (i = 1; i <= nw; i++)
        if (!(W[i] in seen)) printf "%s: not declared as a port anywhere (plain net or library cell pin)\n", W[i]
}
' "$file"
