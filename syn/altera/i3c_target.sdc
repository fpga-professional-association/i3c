# =============================================================================
# i3c_target.sdc  -  Timing constraints for the I3C Target on Altera
#
# sys_clk must be >= 100 MHz (design_decisions D-1: 3-sample rule for a 24 ns
# SCL-High). We constrain 125 MHz (8.0 ns) as the closure target. SDA/SCL are
# asynchronous bus inputs (synchronized internally) and the SDA output is async
# to the bus, so those paths are cut (closed by the synchronizer + sim, not STA).
# =============================================================================

create_clock -name clk      -period 8.000 [get_ports clk]
create_clock -name avl_clk  -period 8.000 [get_ports avl_clk]

derive_clock_uncertainty

# Avalon clock defaults to sys_clk (AVL_ASYNC=0); treat them as the same domain.
set_clock_groups -exclusive -group {clk} -group {avl_clk}

# Asynchronous I3C bus pads (metastability handled by the 2-3 FF synchronizers).
set_false_path -from [get_ports {SCL SDA}] -to [all_registers]
set_false_path -from [all_registers] -to   [get_ports {SDA}]

# Reset de-assertion is synchronized internally.
set_false_path -from [get_ports {rst_n avl_rst_n}] -to [all_registers]
