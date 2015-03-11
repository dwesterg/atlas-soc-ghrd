package require -exact qsys 14.1

#Add Components
add_instance fft_sub FFT_sub 1.0

add_instance fft_ddr_bridge altera_address_span_extender 14.1
set_instance_parameter_value fft_ddr_bridge {DATA_WIDTH} {64}
set_instance_parameter_value fft_ddr_bridge {MASTER_ADDRESS_WIDTH} {32}
set_instance_parameter_value fft_ddr_bridge {SLAVE_ADDRESS_WIDTH} {27}
set_instance_parameter_value fft_ddr_bridge {BURSTCOUNT_WIDTH} {5}
set_instance_parameter_value fft_ddr_bridge {SUB_WINDOW_COUNT} {1}
set_instance_parameter_value fft_ddr_bridge {MASTER_ADDRESS_DEF} {0}
set_instance_parameter_value fft_ddr_bridge {TERMINATE_SLAVE_PORT} {1}
set_instance_parameter_value fft_ddr_bridge {MAX_PENDING_READS} {8}

# MM Connectivity
add_connection lw_mm_bridge.m0 fft_sub.s0 avalon
set_connection_parameter_value lw_mm_bridge.m0/fft_sub.s0 arbitrationPriority {1}
set_connection_parameter_value lw_mm_bridge.m0/fft_sub.s0 baseAddress {0x00080000}
set_connection_parameter_value lw_mm_bridge.m0/fft_sub.s0 defaultConnection {0}

add_connection fft_sub.to_ddr fft_ddr_bridge.windowed_slave avalon
set_connection_parameter_value fft_sub.to_ddr/fft_ddr_bridge.windowed_slave arbitrationPriority {1}
set_connection_parameter_value fft_sub.to_ddr/fft_ddr_bridge.windowed_slave baseAddress {0x0000}
set_connection_parameter_value fft_sub.to_ddr/fft_ddr_bridge.windowed_slave defaultConnection {0}    

# Interrupts   
add_connection hps_0.f2h_irq0 fft_sub.sgdma_from_fft_csr_irq interrupt
set_connection_parameter_value hps_0.f2h_irq0/fft_sub.sgdma_from_fft_csr_irq irqNumber {3}

add_connection hps_0.f2h_irq0 fft_sub.sgdma_to_fft_csr_irq interrupt
set_connection_parameter_value hps_0.f2h_irq0/fft_sub.sgdma_to_fft_csr_irq irqNumber {4}

add_connection intr_capturer_0.interrupt_receiver fft_sub.sgdma_from_fft_csr_irq interrupt
set_connection_parameter_value intr_capturer_0.interrupt_receiver/fft_sub.sgdma_from_fft_csr_irq irqNumber {3}

add_connection intr_capturer_0.interrupt_receiver fft_sub.sgdma_to_fft_csr_irq interrupt
set_connection_parameter_value intr_capturer_0.interrupt_receiver/fft_sub.sgdma_to_fft_csr_irq irqNumber {4}

# Clocks
add_connection hps_0.h2f_user1_clock fft_ddr_bridge.clock clock
add_connection hps_0.h2f_user1_clock fft_sub.clk clock

# Resets
add_connection hps_0.h2f_reset fft_sub.reset reset
add_connection hps_0.h2f_reset fft_ddr_bridge.reset reset
           
save_system
