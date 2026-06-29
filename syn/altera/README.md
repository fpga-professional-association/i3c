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

## Results (Quartus Prime Pro 25.3, Cyclone 10 GX, final RTL 2026-06-28)
| Stage | Result |
|---|---|
| Analysis & Synthesis | **0 errors** (4 benign warnings) |
| Fitter (place & route) | **0 errors** |
| STA | **Timing requirements met** |

- **Setup:** comfortable positive worst-case slack at the 8.000 ns (125 MHz) target →
  **Fmax ≈ 244 MHz** on this device (comfortably above the ≥100 MHz floor, D-1).
- **Hold:** worst-case slack **+0.020 ns** (met).
- **Resources:** ~904 logic cells, 19 RAM segments, 1 bidirectional pin (SDA).

(Re-confirmed after the post-sim RTL fixes: 5-bit register index, DAA `bit_resync`,
FIFO `clear`, front-end release-tail `OE_TAIL`, bit-engine `tx_first`, FSM `read_done_q`,
live-`rnw` CCC-ACK decode. Fmax decreased modestly vs the first build from the added
logic — still well within margin.)

Benign warnings: `avs_readdata[31:24]` tied GND (those register-read bits are unused);
some unused registers optimized away; "not fully constrained" for the deliberately
cut async SDA/SCL paths (`set_false_path` in the SDC — closed by the synchronizers + sim).

## Notes / next steps for a real board
- Add pin-location assignments (`set_location_assignment`) for SDA/SCL/clk/Avalon to
  the target board before generating a programming file.
- For an open-drain SDA pad, set the pad to the bus IO standard and (if needed) swap the
  inferred tri-state in `i3c_io_altera.sv` for an `ALTIOBUF` instance.
- Cyclone 10 GX is Quartus **Pro**; for MAX 10 / Cyclone IV/V use Quartus Standard/Lite
  (the RTL is identical — only the QSF FAMILY/DEVICE changes).
