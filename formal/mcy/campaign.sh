#!/usr/bin/env bash
cd "$(dirname "$0")/../.."
source tools/env.sh >/dev/null 2>&1
LOG=formal/mcy/results.txt; : > "$LOG"
declare -A M=( [i3c_sda_mux]="i3c_pkg.sv i3c_sda_mux.sv" [i3c_bit_engine]="i3c_pkg.sv i3c_bit_engine.sv" [i3c_framer]="i3c_pkg.sv i3c_framer.sv" [i3c_bus_frontend]="i3c_bus_frontend.sv" [i3c_fifo]="i3c_pkg.sv i3c_fifo.sv" [i3c_protocol_fsm]="i3c_pkg.sv i3c_protocol_fsm.sv" [i3c_daa]="i3c_pkg.sv i3c_daa.sv" [i3c_ccc]="i3c_pkg.sv i3c_ccc.sv" [i3c_ibi]="i3c_pkg.sv i3c_ibi.sv" [i3c_error_recovery]="i3c_pkg.sv i3c_error_recovery.sv" [i3c_regfile]="i3c_pkg.sv i3c_regfile.sv" [i3c_avalon_mm]="i3c_pkg.sv i3c_avalon_mm.sv" )
for mod in i3c_sda_mux i3c_bit_engine i3c_framer i3c_bus_frontend i3c_fifo i3c_protocol_fsm i3c_daa i3c_ccc i3c_ibi i3c_error_recovery i3c_regfile i3c_avalon_mm; do
  formal/mcy/gen.sh "$mod" 60 ${M[$mod]} >/dev/null 2>&1
  ( cd "formal/mcy/$mod" && mcy init >/dev/null 2>&1 && timeout 600 mcy run -j8 >/dev/null 2>&1
    cov="$(mcy status 2>&1 | grep -i coverage | tail -1)"
    done_n="$(mcy status 2>&1 | grep -oE 'contains [0-9]+ cached results' | grep -oE '[0-9]+')"
    printf "%-22s %-50s [%s mutants run]\n" "$mod" "${cov:-NO RESULT}" "${done_n:-0}" >> "$LOG" )
done
echo "CAMPAIGN DONE" >> "$LOG"
