## =========================================================
## BASYS 3 - 100 MHz CLOCK
## =========================================================
set_property PACKAGE_PIN W5 [get_ports CLK100MHZ]
set_property IOSTANDARD LVCMOS33 [get_ports CLK100MHZ]
create_clock -period 10.000 -name sys_clk [get_ports CLK100MHZ]

## =========================================================
## SLIDE SWITCHES SW[0] - SW[12]
## =========================================================
set_property PACKAGE_PIN V17 [get_ports {SW[0]}]
set_property PACKAGE_PIN V16 [get_ports {SW[1]}]
set_property PACKAGE_PIN W16 [get_ports {SW[2]}]
set_property PACKAGE_PIN W17 [get_ports {SW[3]}]
set_property PACKAGE_PIN W15 [get_ports {SW[4]}]
set_property PACKAGE_PIN V15 [get_ports {SW[5]}]
set_property PACKAGE_PIN W14 [get_ports {SW[6]}]
set_property PACKAGE_PIN W13 [get_ports {SW[7]}]
set_property PACKAGE_PIN V2  [get_ports {SW[8]}]
set_property PACKAGE_PIN T3  [get_ports {SW[9]}]
set_property PACKAGE_PIN T2  [get_ports {SW[10]}]
set_property PACKAGE_PIN R3  [get_ports {SW[11]}]
set_property PACKAGE_PIN W2  [get_ports {SW[12]}]

set_property IOSTANDARD LVCMOS33 [get_ports {SW[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[12]}]

## =========================================================
## REMAINING SLIDE SWITCHES SW[13] - SW[15]
## =========================================================
set_property PACKAGE_PIN U1 [get_ports {SW[13]}]
set_property PACKAGE_PIN T1 [get_ports {SW[14]}]
set_property PACKAGE_PIN R2 [get_ports {SW[15]}]

set_property IOSTANDARD LVCMOS33 [get_ports {SW[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[15]}]

## =========================================================
## PUSH BUTTONS
## =========================================================

## Center - Initialize
set_property PACKAGE_PIN U18 [get_ports BTNC]
set_property IOSTANDARD LVCMOS33 [get_ports BTNC]

## Up - Load Gate
set_property PACKAGE_PIN T18 [get_ports BTNU]
set_property IOSTANDARD LVCMOS33 [get_ports BTNU]

## Right - Start Circuit
set_property PACKAGE_PIN T17 [get_ports BTNR]
set_property IOSTANDARD LVCMOS33 [get_ports BTNR]

## Left - Reset
set_property PACKAGE_PIN W19 [get_ports BTNL]
set_property IOSTANDARD LVCMOS33 [get_ports BTNL]

## Down - Method A / Method B Selection
set_property PACKAGE_PIN U17 [get_ports BTND]
set_property IOSTANDARD LVCMOS33 [get_ports BTND]

## =========================================================
## LEDS LED[0] - LED[15]
## =========================================================
set_property PACKAGE_PIN U16 [get_ports {LED[0]}]
set_property PACKAGE_PIN E19 [get_ports {LED[1]}]
set_property PACKAGE_PIN U19 [get_ports {LED[2]}]
set_property PACKAGE_PIN V19 [get_ports {LED[3]}]
set_property PACKAGE_PIN W18 [get_ports {LED[4]}]
set_property PACKAGE_PIN U15 [get_ports {LED[5]}]
set_property PACKAGE_PIN U14 [get_ports {LED[6]}]
set_property PACKAGE_PIN V14 [get_ports {LED[7]}]
set_property PACKAGE_PIN V13 [get_ports {LED[8]}]
set_property PACKAGE_PIN V3  [get_ports {LED[9]}]
set_property PACKAGE_PIN W3  [get_ports {LED[10]}]
set_property PACKAGE_PIN U3  [get_ports {LED[11]}]
set_property PACKAGE_PIN P3  [get_ports {LED[12]}]
set_property PACKAGE_PIN N3  [get_ports {LED[13]}]
set_property PACKAGE_PIN P1  [get_ports {LED[14]}]
set_property PACKAGE_PIN L1  [get_ports {LED[15]}]

set_property IOSTANDARD LVCMOS33 [get_ports {LED[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[15]}]

## =========================================================
## USB UART - METHOD B
## =========================================================

## UART Receive
set_property PACKAGE_PIN B18 [get_ports RsRx]
set_property IOSTANDARD LVCMOS33 [get_ports RsRx]

## UART Transmit
set_property PACKAGE_PIN A18 [get_ports RsTx]
set_property IOSTANDARD LVCMOS33 [get_ports RsTx]
