package require -exact qsys 14.1

# Modify HPS
set_instance_parameter_value hps_0 {GPIO_Enable} {No No No No No No No No No Yes No No No No No No No No No No No No No No No No No No No No No No No No No Yes No No No No Yes No No No No No No No No No No No No Yes Yes No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No}
set_instance_parameter_value hps_0 {LOANIO_Enable} {No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No Yes No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No}
    
#Add Components
add_instance irq_bridge_0 altera_irq_bridge
set_instance_parameter_value irq_bridge_0 {IRQ_WIDTH} {1}
set_instance_parameter_value irq_bridge_0 {IRQ_N} {0}

# connections and connection parameters
# IRQ
add_connection hps_0.f2h_irq0 irq_bridge_0.sender0_irq interrupt
set_connection_parameter_value hps_0.f2h_irq0/irq_bridge_0.sender0_irq irqNumber {6}

# Clocks
add_connection hps_0.h2f_user0_clock irq_bridge_0.clk clock

# Resets
add_connection clk_0.clk_reset irq_bridge_0.clk_reset reset

# exported interfaces 
add_interface adc_irq interrupt receiver
set_interface_property adc_irq EXPORT_OF irq_bridge_0.receiver_irq   

add_interface hps_0_h2f_loan_io conduit end
set_interface_property hps_0_h2f_loan_io EXPORT_OF hps_0.h2f_loan_io
    
save_system    
