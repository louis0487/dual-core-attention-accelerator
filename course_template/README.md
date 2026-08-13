# Course Template (Rebuild Baseline)

Original course-provided starter for the ECE260B final project (UCSD, Prof. Mingu Kang) —
kept here verbatim as the **baseline for the rebuild series** (`rebuild/step1` … `rebuild/step6` branches):
re-implementing the full flow from RTL through PnR, one step per week.

Contents: template Verilog (MAC array/column, SRAM behavioral models, FIFOs, OFIFO, SFP row,
synchronizer stub, full-chip top + testbench) and input/reference data files (`qdata/kdata/vdata/norm*.txt`).
No PDK material is included. The template MAC is 16-input; the project spec calls for an 8-input redesign —
that redesign is where the rebuild starts.
