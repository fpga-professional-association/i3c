# Build / Verification Evidence

Captured logs from actually running the three verification flows on this RTL. All are
**regenerable** — re-run the commands and you get the same results (that's the point of
the open-source flow). Committed here so the evidence is in-repo, not just on disk.

| File | Flow | Command that produced it |
|---|---|---|
| `formal_run.log` | SymbiYosys formal suite (ALL GREEN, 41 tasks) | `source tools/env.sh && cd formal && ./run.sh` |
| `sim_run.log` | Icarus simulation (21/21 PASS) | `source tools/env.sh && ./sim/run.sh` |
| `quartus/build_console.log` | Quartus synth + fit + STA console | `./syn/altera/build.sh all` |
| `quartus/i3c_target.syn.summary` | Synthesis summary | (Quartus) |
| `quartus/i3c_target.fit.summary` | Fitter summary — **528 ALMs, 348 regs, 2 RAM blocks** | (Quartus) |
| `quartus/i3c_target.sta.summary` | STA summary — **Setup +3.5 / Hold +0.02 ns, met** | (Quartus) |
| `quartus/i3c_target.sta.head.rpt` | STA report header (multi-corner tables) | (Quartus) |
| `quartus/i3c_target.flow.rpt` | Full compile-flow report | (Quartus) |

The full Quartus report set and a GUI-openable project (`i3c_target.qpf`) live in the
staged build dir `C:\i3c_quartus\` (created by `syn/altera/build.sh`); open
`C:\i3c_quartus\i3c_target.qpf` in the Quartus GUI to browse the Compilation Report.
The project files themselves are version-controlled in `syn/altera/`.
