# step1 debug tools

Written while chasing an all-X gate-level simulation. They are general netlist
and log inspection tools, not one-off scripts, and they stay in the tree
because the same questions come back at every step of the rebuild.

Every script has a `--selftest` that runs it against a synthetic fixture and
prints `SELFTEST PASS`. Run it once on a new machine, or when a result looks
wrong - two real bugs in these scripts were caught that way, and both had
already produced misleading output before the test existed.

**Never commit tool output.** The netlist and the PDK are under NDA. Reports
produced here quote cell names, net names and library paths; `.gitignore`
covers the ones these tools write, but check before adding new ones.

---

## The problem these were written for

Gate-level simulation of the routed netlist returns X on all 160 output bits.
The same testbench passes 8/8 on the RTL, and the synthesis netlist - which
has never been through place-and-route - fails identically to the routed one.
Full write-up, evidence and eliminated hypotheses: `Dualcore/R1_M5_GLS_handoff.md`
in the coaching workspace (not in this repo; it is not ASCII).

---

## run_gui - the simulation itself

```sh
./run_gui                                  routed netlist, with SDF
./run_gui 2>&1 | tee gls.log               ... and capture the log
```

| Variable | Effect |
|---|---|
| `RTL=1` | Simulate the RTL from `./filelist` instead of a netlist, with no `GLS` define. Holds the testbench, the flags and the simulator still so only the design description changes. |
| `NETLIST=<file>` | Which netlist to simulate. Default `./fullchip.pnr.v`; use `./netlist/fullchip.out.v` for post-synthesis simulation, the standard gate between synthesis and place-and-route. |
| `NO_SDF=1` | Skip SDF back-annotation. Pair it with `SEQ_UDP`. |
| `SEQ_UDP=+xmseq_udp_delay+20ps` | Floor delay for sequential UDPs. A zero-delay netlist needs it, because data and clock otherwise reach a flop at the same instant and race. It does **not** disable timing checks - those are a separate mechanism. |
| `GUI=+gui` | Open SimVision. Note that run-time output then goes to the SimVision console, so a piped log holds only the elaboration messages. |
| `+define+CLK_HALF=<ns>` | Clock half period. Defaults to 1.0 under `GLS`, 0.5 otherwise. |

`+define+` changes require re-elaboration. `rm -rf xcelium.d/` first, or the
snapshot is reused and the run does not test what it looks like it tests -
`simcheck.sh` flags that case.

---

## simcheck.sh - why the output went X, from a log you already have

```sh
./simcheck.sh gls.log
```

Counts timing check violations, elaboration errors and warnings, and runtime
errors; flags a reused snapshot; prints the SDF annotation lines and the
PASS/FAIL tally.

Read the violation count first. The TSMC cells declare their timing checks
with a notifier, and the flop UDP takes that notifier as an input: a violated
check forces Q to X by design. A netlist with no delays violates every check
at once, so X in a zero-delay run can say nothing at all about the netlist.
A count of zero rules that mechanism out.

`CUVWSP: N output port(s) was not connected` is benign - an instance with an
unused output. `SDFNEP: Unable to annotate to non-existent path` means the SDF
names a path the cell's `specify` block does not declare; those arcs keep zero
delay, which is where timing checks would fire if any were active.

---

## undriven.sh - every net that is read and never driven

```sh
./undriven.sh                                          whole netlist
./undriven.sh mac_col_bw8_bw_psum20_pr8_col_id3        one module
NETLIST=./netlist/fullchip.out.v ./undriven.sh         the synthesis netlist
```

Port directions are **read**, not guessed: modules defined in the netlist
contribute their own declarations, and the standard cells contribute theirs
from the library Verilog at `$COURSE_PDK` (read in place, never copied).

| Output | Meaning |
|---|---|
| `UNDRIVEN NET` | Read inside the module, nothing drives it. Z in simulation, and any gate it feeds goes X. |
| `UNDRIVEN OUT` | An output port with no driver inside the module. Expected, and harmless, where the parent never reads that output - the last stage of a chain. |
| `unresolved pins` | An instance whose module was in neither file. **A nonzero count means the scan is incomplete**; the result is not a clean report until this is empty. |

Check the last line before reading anything else.

Buses are counted in both directions: a bare name counts as driven if any of
its bits is, a bit counts as driven if it is or if something drives the whole
bus, and a part-select token like `rd_ptr[3:0]` also accepts per-bit drivers.
A bus with one dead bit is still caught when the load sits on that bit. The
first version got the bare-name direction wrong and reported 337 nets, SRAM
outputs included; the second missed the part-select case and reported every
hierarchical `.sel(rd_ptr[3:0])`-style connection over a bit-driven bus as
undriven. Both cases are in the selftest now.

**Remaining blind spot.** A whole-bus load (`.b(key_q)`) over a bus missing
just one bit driver is NOT caught: the load sits on the bare name, and any
one bit driver credits it. When a single bit matters, check it by name with
a scoped scan (see round2.sh's modscan) rather than trusting a clean
undriven.sh report.

---

## netcheck.sh - one net, line by line

```sh
./netcheck.sh FE_RN_1                 defaults to fullchip.pnr.v
./netcheck.sh FE_RN_1 other.v
```

Prints every line in every module that mentions the net, tagged DECL, DRIVER
or LOAD, with a driver count per module. Matching is exact: `FE_RN_1` does not
pull in `FE_RN_10`.

**Known limitation.** DRIVER is decided by comparing the pin name against the
standard cell output pins (Z ZN Q QN CO S CON SO). That is right for library
cells and wrong for a connection to another module in the same netlist, where
the direction lives in that module's declarations. This reported four modules
as having zero drivers when the question was still open; `portdir.sh` settled
it. Use `undriven.sh` when the answer has to be trusted - it reads directions
rather than inferring them.

---

## portdir.sh - which module declares this port, and which way

```sh
./portdir.sh FE_OFN463_q_temp_192
./portdir.sh PORT_A PORT_B PORT_C
```

The follow-up to a `netcheck.sh` result on a hierarchical connection. An
`output` means the net is driven and the zero-driver reading was a false
alarm; an `input` means it really is a load with no source. A name reported as
not declared anywhere is a plain net, so the connection is a library cell pin.

---

## nlshow.sh - structure, not names

```sh
./nlshow.sh -l 36651                      the whole instance that line sits in
./nlshow.sh -m mac_8in_bw8_bw_psum20_pr8_5    a module header and its ports
./nlshow.sh -c 36651 8                    8 raw lines either side
```

For when a name looks wrong and the next question is what it is attached to.
`-l` backtracks to the start of the instance and reads to its closing
semicolon, so a connection spanning seventy lines still comes out whole. `-m`
prints the header and every port declaration and nothing else, which is how
the four DC-generated inputs on `mac_8in` were found.

---

## cmpnl.sh - synthesis netlist against routed netlist

```sh
./cmpnl.sh
```

Compares line counts, module counts, `1'b0`/`1'b1` constants, tie cell
instances, assign statements and undriven nets between
`./netlist/fullchip.out.v` and `./fullchip.pnr.v`, and writes the full
undriven reports to `undriven_dc.txt` and `undriven_pnr.txt`.

It also warns when `./netlist/fullchip.out.v` differs from the
`./fullchip.out.v` that synthesis wrote beside it. That copy is manual -
`run_dc.tcl` writes to the directory dc_shell ran in while
`loadDesignTech.tcl` reads from `netlist/` - so it can silently be from an
earlier run.

---

## checkNetlist.tcl - ask Innovus instead of parsing Verilog

```
innovus
restoreDesign route.enc.dat fullchip
source checkNetlist.tcl
```

Runs `checkDesign -netlist -danglingNet -tieHiLo -assigns` and
`reportDanglingNet`. Option names come from the Text Command Reference 19.11.

Note the manual's definition: `-danglingNet` finds nets with **no** instance
or top-level terminals. A net with one load and no driver has a terminal, so
it will not appear there - read the `-netlist` and `-tieHiLo` sections for
that case.
