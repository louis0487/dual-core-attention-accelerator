# R0 Archaeology - Step Map (COMPLETED 2026-08-14)

Ground rule: every cell carries file evidence (filename/path). Cells based on
inference rather than opened files are tagged [assessed]. Archaeology was closed
by decision on 2026-08-14: enough evidence to rebuild; remaining unknowns are
tagged instead of chased.

Trees referenced below (server home / local mirror):
- Tree A = `1D_Vector_Processor/` (step1-6)
- Tree B = `finalproject/1D_Vector_Processor/` (step1-5 + 6a/6b)

## Step map

| Official | Goal | Folder | Key files: run script -> inputs -> outputs | How it was run | What changes in rebuild |
|---|---|---|---|---|---|
| S1 | Single-core QK: RTL (8-input MAC redesign) + synthesis + PnR @ 1 GHz (negative WNS OK; FAQ5 = relax clock first) + GLS, results land in pmem | step1 in BOTH trees (full script set + per-stage PnR saves) | `run_dc.tcl` -> 12 RTL files (incl. `mac_8in.v`, `sram_w16.v` read as behavioral RTL, flat compile) -> `fullchip.out.v`; then `loadDesignTech / initialFloorplan / pinPlacement / placement / clock / route / outputGen .tcl` -> `netlist/fullchip.v` -> `.enc` saves + reports | `dc_shell -f run_dc.tcl` (journal: `command.log`); Innovus sourcing the tcl stages - per-stage journals `inn.cmd.gz` inside `initial/floorplan/placement/cts/route .enc.dat` | Re-derive `mac_8in` from the 16-input template MAC myself; scripts archived in repo `tcl/step1/` are the framework |
| S2 | Normalization: abs() on BOTH numerator and denominator -> row-wise sum -> divide -> write back to pmem; verify by behavioral sim | step2 in both trees | `step2/verilog/` + `command.log` only - no synthesis artifacts present | Behavioral simulation stage only (xcelium; no DC/Innovus traces in the folder) | Write normalizer RTL + TB, behavioral sim; no PnR at this step |
| S3 | Hierarchical flow: SRAM synthesized+PnR'd standalone into a macro (top = M4, pin pitch 4 um, D bottom / Q top / rest left) -> core treats SRAM as a cell; includes normalizer | Tree A step3 (14 tcl; the hierarchical buildout lives here) | SRAM leg: `run_dc_sram.tcl` -> `outputGen.tcl` (`write_lef_abstract` + `do_extract_model` -> `sram_w16.lef`, `_WC/_BC.lib`); core leg: `run_dc_core.tcl` + `loadDesignTech_core.tcl` + `pinPlacement_core.tcl` (SRAM consumed as macro). Saves: `sram_w16.dat`, `core.dat`, 5x `.enc.dat` with journals | Two-pass: SRAM macro first, then hierarchical core; all journals present | This IS the R3 map. Scripts archived in repo `tcl/step3/` |
| S4 | Dual-core: cross-clock-domain sum exchange (async protocol) | Tree B step4 | `run_dc.tcl` -> `fullchip.out.v` (4.57 MB); per-core data files `kdata_core0/core1`, `norm_core0/core1` (dual-core signature); `fullchip_tb.vcd` (GLS) | DC synth + GLS confirmed (`command.log` 159 KB); Innovus traces thin (`innovus.cmd` 0.9 KB only - no `.enc.dat` in folder) | PnR record thin [assessed: rebuild PnR by extending the step3 framework]; async sum-exchange RTL is the core new work |
| S5 | Official optimization step: setup WNS = 0 @ TYP, hold clean @ FAST, optimize the final dual-core only | Tree B step5 | `run_dc.tcl` + `fullchip.sdc` (tightened constraints) -> `fullchip.out.v` (7.76 MB) + GLS `vcd` | DC re-synth under tighter SDC + GLS; same thin-Innovus pattern as S4 | Rebuild = the real timing-closure round; expect iteration |
| S6 | B2 row-level sparsity (30%, numpy threshold) on top of S5 | Tree B step6a + step6b (pair); Tree A step6 [assessed: baseline-flavored run, out.v 19.9 MB ~ 6a's 20.4 MB] | 6a: `fullchip.out.v` 20.4 MB, no B2 dir = baseline. 6b: **`B2_threshold_tb/` dir present = B2 sparsity leg**, `fullchip.out.v` 4.57 MB. Both: `run_dc.tcl`, GLS `vcd` | DC synth + GLS per leg; comparison pair for the report | Rebuild reproduces the 6a-vs-6b comparison on top of rebuilt S5 |

## Verdict questions - resolved

- [x] **A. Division of labor**: Tree A = development/assignment line (holds the S2 behavioral stage, the complete S3 hierarchical buildout, and an S6-flavored experiment). Tree B = final package line (fresh S1, S4 dual-core, S5 optimization, S6a/6b graded pair). [assessed from file evidence; archaeology closed before full cross-diff]
- [x] **B. step6 vs 6a/6b**: **6b = B2 sparsity** (evidence: `step6b/B2_threshold_tb/` directory; out.v 4.57 MB) vs **6a = baseline** (no B2 dir; out.v 20.4 MB). Tree A step6 resembles the baseline leg [assessed by size/date, not diffed].
- [x] **C. S3 macro pin constraints**: `tcl/step3/pinPlacement.tcl` lines 2-4: `editPin -pin Q* -side Top`, `D* -side Bottom`, `{CLK WEN CEN A*} -side Left`, all `-spacing 4` (= 4 um pitch) - matches the official spec verbatim. Core-level pin plan: `pinPlacement_core.tcl` lines 21-24 (outputs bottom/L2, inputs left/L3). M4 top-layer cap not located in the pin scripts [assessed: lives in floorplan/route settings; confirm during R3].

## Rebuild intel

- Later-step PnR journals are thin/absent -> rebuild PnR for S4+ by extending the step3 script framework rather than replaying old runs.
- S2 is behavioral-only; do not add synthesis there.
- Remembered RTL delta across steps ("add ofifo + bitwidth fixes") is unverified memory - verify against official template when each step starts, via verilog diff.
- Step scripts now archived in repo: `tcl/step1/` (9 files), `tcl/step3/` (14 files); both NDA-scanned (path references only, no library content).
