# Altera Synthesis & Timing (Quartus Prime Pro)

The device-agnostic RTL builds for a real Altera device; the only vendor-specific
file is `rtl/altera/i3c_io_altera.sv` (tri-state SDA pad).

## Build
Quartus runs as a Windows process (WSL invokes the `.exe`), so the project is staged
under `C:\i3c_quartus`:
```
syn/altera/build.sh syn    # analysis & synthesis only (fast synthesizability check)
syn/altera/build.sh all    # syn + fitter (P&R) + STA
```
Files: `i3c_target.qsf` (project), `i3c_target.sdc` (timing). Default device is
**Cyclone 10 GX `10CX220YF780E5G`** (also installed: Agilex 3 / Agilex 5 — change
`FAMILY`/`DEVICE` in the QSF). Toolchain found at `C:\altera_pro\25.3`.

## Results (Quartus Prime Pro 25.3, Cyclone 10 GX `10CX220YF780E5G`, final RTL)
| Stage | Result |
|---|---|
| Analysis & Synthesis | **0 errors** |
| Fitter (place & route) | **0 errors** |
| Resources | **528 ALMs, 348 registers, 2 RAM blocks, 84 pins** (post-fit; synthesis estimate ~900 logic cells) |

### Timing — read this carefully

The honest result, split by path class (this is what STA reports once the I/O is fully
constrained — see the SDC and the "I/O constraints" note below):

| Path class | Worst-case setup slack @ 8.0 ns (125 MHz) | Verdict |
|---|---|---|
| **Register-to-register + input** (the actual logic) | **+2.4 ns** | **MET** — pure reg-to-reg Fmax ≈ 244 MHz |
| Hold (all) | +0.02 ns | MET |
| **Combinational Avalon *output* pins** (`avs_readdata`/`waitrequest`/`irq`) | **−2.86 ns** | does **not** close standalone |

**The internal logic meets 125 MHz** (the meaningful result for an on-chip IP). The
failing paths are *only* the Avalon **output** pins, which are **combinational**
(`avs_readdata` is a RAM-read → mux; `avs_waitrequest` and `irq` are reductions) and go
through the FPGA **output-pad buffer (~3.65 ns)** to a hypothetical external register.

This is an **out-of-context (OOC) artifact, not a design flaw**: an Avalon-MM agent is an
**on-chip IP boundary**, not chip pins — in a real system (Platform Designer) these ports
connect to the interconnect with **no output-pad buffer**, so the paths are RAM/mux →
interconnect register (~2.6 ns) and close easily. Synthesizing the IP *standalone with the
Avalon ports as chip pins* is what exposes the pad-buffer delay. Note also that Avalon
**requires `waitrequest` to be combinational**, so it cannot be registered.

> **Earlier versions of these docs claimed "timing met @125 MHz" unqualified. That was
> wrong** — it held only because the I/O ports were *unconstrained* (STA wasn't analyzing
> them). With a complete SDC the truthful statement is the table above.

**For a true chip-pin Avalon deployment** (rather than an on-chip IP), close the output
paths by: (1) registering the registerable outputs (`avs_readdata` → 2-cycle Avalon read
latency, gated by `readdatavalid`); (2) adding `set_location_assignment` pin placement and
an I/O standard; (3) budgeting `set_output_delay` to the real downstream register.

### I/O constraints (`i3c_target.sdc`)
Constrains every domain so STA is meaningful: `create_clock` on `clk`; async SDA/SCL pads
and reset cut with `set_false_path` (metastability closed by the 2–3 FF synchronizers, not
STA); Avalon-MM I/O given `set_input_delay`/`set_output_delay` (placeholder ~1 ns budgets —
set to the real master for sign-off). This reduced unconstrained ports from **35 in / 28
out to 1 in / 1 out** (the remaining two are the tied-off `avl_clk` pin and the `SDA`
inout, which carry no real logic paths in the default `AVL_ASYNC=0` build).

## Notes / next steps for a real board
- Add pin-location assignments (`set_location_assignment`) for SDA/SCL/clk/Avalon to
  the target board before generating a programming file.
- For an open-drain SDA pad, set the pad to the bus IO standard and (if needed) swap the
  inferred tri-state in `i3c_io_altera.sv` for an `ALTIOBUF` instance.
- Cyclone 10 GX is Quartus **Pro**; for MAX 10 / Cyclone IV/V use Quartus Standard/Lite
  (the RTL is identical — only the QSF FAMILY/DEVICE changes).
