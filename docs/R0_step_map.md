# R0 Archaeology - Step Map (W3 deliverable, due 2026-08-16)

Ground rule: every cell needs file evidence (filename/path), not memory.
The "Official goal" column is pre-filled from the official project instructions;
fill the remaining columns on the server while inventorying.

## Four questions per step folder (to fill the table)

1. Who runs: which run scripts (tcl/sh) are in the folder, and which tool does each call (dc_shell / innovus / xcelium)?
2. What it eats: which RTL / netlist / SDC inputs? (check read/source/set near the top of the tcl)
3. What it produces: netlist / .enc / waveforms / reports?
4. Which official step (and which sentence of it) does this folder correspond to?

## Step map

| Official | Goal (pre-filled) | Folder (which tree) | Key files: run script -> inputs -> outputs | How it was run | What to change in rebuild |
|---|---|---|---|---|---|
| S1 | Single-core QK: RTL (8-input MAC redesign) + synthesis + PnR @ 1 GHz (negative WNS OK; FAQ5 = relax clock first) + GLS, results land in pmem | | | | |
| S2 | Normalization: abs() on BOTH numerator and denominator -> row-wise sum -> divide -> write back to pmem; verify by behavioral sim | | | | |
| S3 | Hierarchical flow: SRAM synthesized+PnR'd standalone into a macro (top layer = M4, pin pitch 4 um, D pins bottom / Q pins top / rest left) -> core treats SRAM as a cell, hierarchical synth+PnR; includes normalizer | | | | |
| S4 | Dual-core: cross-clock-domain sum exchange (async protocol) | | | | |
| S5 | Official optimization step: setup WNS = 0 @ TYP, hold clean @ FAST, optimize the final dual-core only | | | | |
| S6 | B2 row-level sparsity (30%, numpy threshold) on top of S5 | | | | |

## Three verdict questions (evidence filenames required)

- [ ] A. Division of labor between the two trees: `1D_Vector_Processor/` (step1-6) vs `finalproject/1D_Vector_Processor/` (step1-5 + 6a/6b) - what period/purpose is each, and which tree is the rebuild baseline? (Evidence: diff same-named steps' RTL or logs across the trees)
- [ ] B. step6 vs step6a/6b: which of 6a/6b is baseline and which is B2 sparsity? And which version is the top tree's step6? (Evidence: RTL diff or run log)
- [ ] C. Where do official S3's macro constraints land: M4 top / 4 um pin pitch / D bottom, Q top - which tcl file, which lines, in your step3? (Advance scouting for R3)

## Note while inventorying (rebuild intel)

- Rough runtime per step (log timestamp head vs tail) -> sets expectations for the rebuild
- Signs of past struggle/reruns (multiple logs, *_old files) -> minefield markers for the rebuild
