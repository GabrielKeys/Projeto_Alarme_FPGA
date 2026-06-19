## Clock da Basys 3 - 100 MHz
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clk]

## Reset - botão central
set_property PACKAGE_PIN U18 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

## Entradas por switches
## SW0 - armar/desarmar
set_property PACKAGE_PIN V17 [get_ports botao_arm]
set_property IOSTANDARD LVCMOS33 [get_ports botao_arm]

## SW1 - zona 1
set_property PACKAGE_PIN V16 [get_ports zona1]
set_property IOSTANDARD LVCMOS33 [get_ports zona1]

## SW2 - zona 2
set_property PACKAGE_PIN W16 [get_ports zona2]
set_property IOSTANDARD LVCMOS33 [get_ports zona2]

## SW3 - zona 3
set_property PACKAGE_PIN W17 [get_ports zona3]
set_property IOSTANDARD LVCMOS33 [get_ports zona3]

## SW4 - zona 4
set_property PACKAGE_PIN W15 [get_ports zona4]
set_property IOSTANDARD LVCMOS33 [get_ports zona4]

## SW5 - zona 5
set_property PACKAGE_PIN V15 [get_ports zona5]
set_property IOSTANDARD LVCMOS33 [get_ports zona5]


## Tempo programável pós-violação
## SW6 a SW12 = tempo_prog[0] a tempo_prog[6]
## Valor binário de 0 a 120 segundos
## Se passar de 120, o VHDL limita para 120

## SW6 - bit 0
set_property PACKAGE_PIN W14 [get_ports {tempo_prog[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {tempo_prog[0]}]

## SW7 - bit 1
set_property PACKAGE_PIN W13 [get_ports {tempo_prog[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {tempo_prog[1]}]

## SW8 - bit 2
set_property PACKAGE_PIN V2 [get_ports {tempo_prog[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {tempo_prog[2]}]

## SW9 - bit 3
set_property PACKAGE_PIN T3 [get_ports {tempo_prog[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {tempo_prog[3]}]

## SW10 - bit 4
set_property PACKAGE_PIN T2 [get_ports {tempo_prog[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {tempo_prog[4]}]

## SW11 - bit 5
set_property PACKAGE_PIN R3 [get_ports {tempo_prog[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {tempo_prog[5]}]

## SW12 - bit 6
set_property PACKAGE_PIN W2 [get_ports {tempo_prog[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {tempo_prog[6]}]


## PMOD JA10 - esp_ok vindo do ESP32
set_property PACKAGE_PIN G3 [get_ports esp_ok]
set_property IOSTANDARD LVCMOS33 [get_ports esp_ok]

## Saidas principais em LEDs
set_property PACKAGE_PIN U15 [get_ports sirene]
set_property IOSTANDARD LVCMOS33 [get_ports sirene]

set_property PACKAGE_PIN U14 [get_ports estrobo]
set_property IOSTANDARD LVCMOS33 [get_ports estrobo]

## PMOD JA1 - sinal de alerta para ESP32
set_property PACKAGE_PIN J1 [get_ports esp_alerta]
set_property IOSTANDARD LVCMOS33 [get_ports esp_alerta]

## esp_reset em LED visual da Basys
set_property PACKAGE_PIN V13 [get_ports esp_reset]
set_property IOSTANDARD LVCMOS33 [get_ports esp_reset]

## LEDs das zonas
set_property PACKAGE_PIN U16 [get_ports {leds_zona[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_zona[0]}]

set_property PACKAGE_PIN E19 [get_ports {leds_zona[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_zona[1]}]

set_property PACKAGE_PIN U19 [get_ports {leds_zona[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_zona[2]}]

set_property PACKAGE_PIN V19 [get_ports {leds_zona[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_zona[3]}]

set_property PACKAGE_PIN W18 [get_ports {leds_zona[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds_zona[4]}]

## Vetor enviado ao ESP32 pelo PMOD JB

## JB1 - Zona 1
set_property PACKAGE_PIN A14 [get_ports {esp_zonas[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {esp_zonas[0]}]

## JB2 - Zona 2
set_property PACKAGE_PIN A16 [get_ports {esp_zonas[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {esp_zonas[1]}]

## JB3 - Zona 3
set_property PACKAGE_PIN B15 [get_ports {esp_zonas[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {esp_zonas[2]}]

## JB4 - Zona 4
set_property PACKAGE_PIN B16 [get_ports {esp_zonas[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {esp_zonas[3]}]

## JB7 - Zona 5
set_property PACKAGE_PIN A15 [get_ports {esp_zonas[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {esp_zonas[4]}]

## Display de 7 segmentos
set_property PACKAGE_PIN W7 [get_ports {display[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[0]}]

set_property PACKAGE_PIN W6 [get_ports {display[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[1]}]

set_property PACKAGE_PIN U8 [get_ports {display[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[2]}]

set_property PACKAGE_PIN V8 [get_ports {display[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[3]}]

set_property PACKAGE_PIN U5 [get_ports {display[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[4]}]

set_property PACKAGE_PIN V5 [get_ports {display[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[5]}]

set_property PACKAGE_PIN U7 [get_ports {display[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[6]}]

## Configuração da FPGA
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]