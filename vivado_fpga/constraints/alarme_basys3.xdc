## Clock da Basys 3 - 100 MHz
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clk]

## Reset - botão central
set_property PACKAGE_PIN U18 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

## Botao de armar/desarmar - switch onboard (mantido)
set_property PACKAGE_PIN V17 [get_ports botao_arm]
set_property IOSTANDARD LVCMOS33 [get_ports botao_arm]

## Zonas 1 a 5 - migradas dos switches onboard para o PMOD JC,
## porque agora recebem o espelho dos sensores reais vindo do ESP32
## (antes eram switches de bancada so para testar a MEF sem sensores).

## JC1 - Zona 1 (reed switch, via ESP32)
set_property PACKAGE_PIN K17 [get_ports zona1]
set_property IOSTANDARD LVCMOS33 [get_ports zona1]

## JC2 - Zona 2 (sensor IR, via ESP32)
set_property PACKAGE_PIN M18 [get_ports zona2]
set_property IOSTANDARD LVCMOS33 [get_ports zona2]

## JC3 - Zona 3 (PIR, via ESP32)
set_property PACKAGE_PIN N17 [get_ports zona3]
set_property IOSTANDARD LVCMOS33 [get_ports zona3]

## JC4 - Zona 4 (ultrassonico HC-SR04, via ESP32)
set_property PACKAGE_PIN P18 [get_ports zona4]
set_property IOSTANDARD LVCMOS33 [get_ports zona4]

## JC7 - Zona 5 (botao/reed adicional, via ESP32)
set_property PACKAGE_PIN L17 [get_ports zona5]
set_property IOSTANDARD LVCMOS33 [get_ports zona5]

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

## PMOD JA2 - reset do ESP32 (watchdog). Antes estava no LED V13
## e nunca chegava de fato no ESP32; agora vai por fio de verdade.
set_property PACKAGE_PIN L2 [get_ports esp_reset]
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