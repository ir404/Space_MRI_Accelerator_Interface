# Clock signal
set_property PACKAGE_PIN W5 [get_ports clk]                            
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

# USB-UART Interface
set_property PACKAGE_PIN B18 [get_ports uart_rx_bit]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_bit]
set_property PACKAGE_PIN A18 [get_ports uart_tx_bit]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_bit]

# System Reset (Switch 0 - Far Right Switch)
# SW0 Flipped UP (HIGH)   = FSM runs normally (rst_n = '1')
# SW0 Flipped DOWN (LOW)  = System held in reset (rst_n = '0')
set_property PACKAGE_PIN V17 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# Diagnostic LEDs (Mapping from LEFT to RIGHT on the Basys 3 board)
# LED15 (Far Left)  - L1: Baud Locked (Indicates RX is synced to UART stream)
set_property PACKAGE_PIN L1 [get_ports baud_locked_out]
set_property IOSTANDARD LVCMOS33 [get_ports baud_locked_out]

# LED14             - P1: Frame Error (Indicates missing stop bit)
set_property PACKAGE_PIN P1 [get_ports frame_err_out]
set_property IOSTANDARD LVCMOS33 [get_ports frame_err_out]

# LED13             - N3: Header Error (Indicates wrong command byte like 0xA4)
set_property PACKAGE_PIN N3 [get_ports header_err_out]
set_property IOSTANDARD LVCMOS33 [get_ports header_err_out]

# LED12             - P3: CRC Error (Indicates payload corruption / remainder != 0)
set_property PACKAGE_PIN P3 [get_ports crc_error_out]
set_property IOSTANDARD LVCMOS33 [get_ports crc_error_out]

# LED11             - U3: CRC Valid (Pulses when a mathematically flawless packet is received)
set_property PACKAGE_PIN U3 [get_ports crc_valid_out]
set_property IOSTANDARD LVCMOS33 [get_ports crc_valid_out]

# LED10             - W3: Accelerator Done (Pulses when the dummy cipher finishes +3 shift)
set_property PACKAGE_PIN W3 [get_ports acc_done_out]
set_property IOSTANDARD LVCMOS33 [get_ports acc_done_out]