#!/bin/sh
# dcone.sh - walk the input cone of a register group inside one module.
#
# The waveform proved that key_q never loads in mac_col variants 1,3,5,6,7
# and loads correctly in 2,4,8. Internal net names are unreliable observers
# after synthesis - col_id2 shows an all-Z cnt_q while loading perfectly, so
# the real state lives on renamed nets - but instance pins and the nets
# between them are the netlist itself. This prints, for every flop whose
# instance name matches a pattern, the flop line, then walks upward from its
# control pins through the drivers, a few levels deep.
#
#   ./dcone.sh mac_col_bw8_bw_psum20_pr8_col_id1 key_q_reg
#   ./dcone.sh mac_col_bw8_bw_psum20_pr8_col_id8 key_q_reg
#   NETLIST=./fullchip.pnr.v ./dcone.sh <module> <regpat>
#
# What it prints:
#   the first matching flop's full instance line (all pins visible)
#   nets shared by many of the flops (the enable cone - data pins differ
#   per bit, control pins converge), each traced 3 levels up
#   one sample data (D) cone, 2 levels
#   NO DRIVER on a cone net is flagged - inside a clean netlist that means
#   the name is a module input port or the cone walked out of the module
#
# Pin direction notes: Z ZN Q QN CO CON SO are outputs; S is the sum output
# on adders but the select INPUT on MUX cells, so S counts as an output only
# on non-MUX cells. CP/CPN (clocks) are not traced.
#
#   ./dcone.sh --selftest

file=${NETLIST:-./netlist/fullchip.out.v}

# trace FILE - reads MOD and REGPAT from the environment.
trace() {
    awk '
    BEGIN { mod = ENVIRON["MOD"]; regpat = ENVIRON["REGPAT"]
            split("Z ZN Q QN CO CON SO", O, " "); no = 7 }
    function isout(pin, ityp) {
        if (pin == "S") return (ityp !~ /MUX|MX/)
        for (k = 1; k <= no; k++) if (pin == O[k]) return 1
        return 0
    }
    function squash(s) { gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); return s }
    function base(t) { sub(/\[.*/, "", t); return t }

    /^ *module/ { cur = $2; sub(/\(.*/, "", cur); inmod = (cur == mod) }
    inmod && /^ *(input|inout)[ \t[]/ {
        d = $0; sub(/;.*/, "", d); sub(/^ *(input|inout)/, "", d)
        gsub(/\[[^]]*\]/, "", d)
        n = split(d, T, /[ \t,]+/)
        for (i = 1; i <= n; i++) if (T[i] != "") port[T[i]] = 1
        next
    }
    inmod {
        if (!ins && $0 ~ /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]+[^ \t;]/ &&
            $0 !~ /^[ \t]*(module|endmodule|input|output|inout|wire|tri|assign|supply|parameter|`|\/\/)/) {
            ins = 1; ibuf = ""
        }
        if (ins) ibuf = ibuf " " $0
        if (ins && /;[ \t]*$/) {
            line = squash(ibuf); ins = 0
            split(line, W, " "); ityp = W[1]; iname = W[2]
            ni++; I[ni] = line; TY[ni] = ityp; NM[ni] = iname
            rest = line
            while (match(rest, /\.[A-Za-z0-9_]+\(/)) {
                pin = substr(rest, RSTART + 1, RLENGTH - 2)
                rest = substr(rest, RSTART + RLENGTH)
                p = index(rest, ")"); expr = substr(rest, 1, p - 1)
                gsub(/[ \t]/, "", expr); rest = substr(rest, p + 1)
                if (expr ~ /[{,]/) continue
                if (isout(pin, ityp)) drv[expr] = ni
                else { PIN[ni, ++np[ni]] = pin; NET[ni, np[ni]] = expr }
            }
        }
    }
    /^ *endmodule/ && inmod { inmod = 0 }

    END {
        nstart = 0
        for (i = 1; i <= ni; i++)
            if (NM[i] ~ regpat) { nstart++; S[nstart] = i }
        if (!nstart) { print "no instance matching " regpat " in " mod; exit 1 }
        printf "%d instances match %s in %s; first one:\n  %s\n\n", nstart, regpat, mod, I[S[1]]
        for (s = 1; s <= nstart; s++) {
            i = S[s]
            for (k = 1; k <= np[i]; k++)
                if (PIN[i, k] !~ /^CP/) { cnt[NET[i, k]]++; pinof[NET[i, k]] = PIN[i, k] }
        }
        thresh = nstart / 2; if (thresh < 2) thresh = 2
        print "shared control nets (on more than half of the flops), traced up:"
        for (n in cnt) if (cnt[n] >= thresh) {
            printf "  pin .%s net %s (on %d flops)\n", pinof[n], n, cnt[n]
            walk(n, 1, 3)
        }
        print ""
        i = S[1]
        for (k = 1; k <= np[i]; k++) if (PIN[i, k] == "D") {
            printf "sample data cone, .D of %s:\n", NM[i]
            walk(NET[i, k], 1, 2)
        }
    }
    function walk(net, depth, maxd,   i, k, pad) {
        pad = sprintf("%*s", depth * 4, "")
        if (net in seen) { print pad "(" net ": shown above)"; return }
        seen[net] = 1
        if (base(net) in port) { print pad net " <- module input port"; return }
        if (!(net in drv)) { print pad net " <- NO DRIVER in this module"; return }
        i = drv[net]
        print pad net " <- " I[i]
        if (depth >= maxd) return
        for (k = 1; k <= np[i]; k++)
            if (PIN[i, k] !~ /^CP/) walk(NET[i, k], depth + 1, maxd)
    }
    ' "$1"
}

if [ "$1" = "--selftest" ]; then
    t=${TMPDIR:-/tmp}/dcone_selftest.$$.v
    cat > "$t" <<'FAKE_EOF'
module m1 ( o, clk, top_in );
  input clk;
  input top_in;
  wire q0, q1;
  EDFQD1 key_q_reg_0_ ( .D(d0), .E(en), .CP(clk), .Q(q0) );
  EDFQD1 key_q_reg_1_ ( .D(d1), .E(en), .CP(clk), .Q(q1) );
  ND2D1 U1 ( .A1(x1), .A2(orphan), .ZN(en) );
  INVD1 U2 ( .I(top_in), .ZN(x1) );
  MUX2D0 U3 ( .I0(a0), .I1(b0), .S(x1), .Z(d0) );
endmodule
module decoy ( o );
  EDFQD1 key_q_reg_0_ ( .D(z), .E(z2), .CP(c), .Q(o) );
endmodule
FAKE_EOF
    out=$(MOD=m1 REGPAT=key_q_reg trace "$t")
    rm -f "$t"
    echo "$out"
    fail=0
    echo "$out" | grep -q "2 instances match"                    || { echo "FAIL: start set wrong"; fail=1; }
    echo "$out" | grep -q "pin .E net en (on 2 flops)"           || { echo "FAIL: shared enable not found"; fail=1; }
    echo "$out" | grep -q "en <- ND2D1 U1"                       || { echo "FAIL: enable driver not traced"; fail=1; }
    echo "$out" | grep -q "x1 <- INVD1 U2"                       || { echo "FAIL: depth-2 not traced"; fail=1; }
    echo "$out" | grep -q "orphan <- NO DRIVER"                  || { echo "FAIL: undriven cone net not flagged"; fail=1; }
    echo "$out" | grep -q "top_in <- module input port"          || { echo "FAIL: port not recognised"; fail=1; }
    echo "$out" | grep -q "d0 <- MUX2D0 U3"                      || { echo "FAIL: sample D cone missing"; fail=1; }
    echo "$out" | grep -q "decoy"                                && { echo "FAIL: module scope leaked"; fail=1; }
    [ $fail -eq 0 ] && echo "SELFTEST PASS"
    exit $fail
fi

[ -n "$2" ] || { echo "usage: $0 <module> <instance-name-pattern>   (or --selftest)" >&2; exit 1; }
[ -r "$file" ] || { echo "dcone.sh: cannot read $file" >&2; exit 1; }
MOD="$1" REGPAT="$2" trace "$file"
