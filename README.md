# Sistema Embarcado de Alarme Perimétrico com FPGA

Projeto final da disciplina de Sistemas Embarcados.

## Objetivo

Desenvolver um sistema embarcado perimétrico de detecção e dissuasão de ameaças, utilizando uma central implementada em FPGA Basys 3, integrada a ESP32, comunicação MQTT, dashboard em nuvem e alertas ao usuário.

## Arquitetura Geral

O sistema é composto por:

- FPGA Basys 3
- ESP32
- 5 zonas de sensores
- Sirene
- Luz estroboscópica
- Dashboard em nuvem
- Comunicação MQTT

Fluxo geral:

```text
Sensores → FPGA Basys 3 → ESP32 → MQTT → Dashboard/Nuvem → Usuário
```

## Zonas Monitoradas

| Zona | Local Simulado | Sensor |
|---|---|---|
| Zona 1 | Porta principal | Reed switch |
| Zona 2 | Janela lateral | Sensor IR |
| Zona 3 | Área interna | PIR |
| Zona 4 | Área externa | Ultrassônico HC-SR04 |
| Zona 5 | Área crítica | Botão/Reed switch |

## Máquina de Estados

A central FPGA foi implementada com uma Máquina de Estados Finita composta por:

- DESARMADO
- ARMADO
- CONTAGEM
- DISPARO
- RESET_ESP

## Funcionalidades

- Monitoramento de 5 zonas
- Identificação da zona violada
- Memorização da zona violada para manter o evento correto durante o disparo
- Acionamento de sirene
- Acionamento de luz estroboscópica
- Indicação visual por LEDs
- Indicação por display de sete segmentos
- Comunicação com ESP32
- Envio da zona violada para o ESP32 por meio do sinal `esp_zonas`
- Envio futuro de alertas via MQTT para dashboard
- Código inicial do ESP32 para leitura de alerta e identificação da zona violada
- Código ESP32 com conexão Wi-Fi
- Comunicação MQTT configurada
- Publicação do status, zona violada e mensagem de alerta via MQTT

## Estrutura do Repositório

```text
Projeto_Alarme_FPGA/
├── vivado_fpga/
│   ├── src/
│   │   └── alarme_top.vhd
│   ├── tb/
│   │   └── tb_alarme_top.vhd
│   └── constraints/
├── esp32/
├── nuvem/
├── documentacao/
└── imagens/
```

## Status Atual

- [x] Definição do escopo
- [x] Arquitetura lógica
- [x] MEF principal
- [x] Código VHDL inicial
- [x] Testbench
- [x] Simulação comportamental no Vivado
- [x] Envio da zona violada para o ESP32 por `esp_zonas`
- [x] Memorização da zona violada
- [x] Arquivo de constraints da Basys 3
- [x] Síntese no Vivado
- [x] Implementação no Vivado
- [x] Geração do bitstream
- [x] Código ESP32 inicial compilado
- [x] Integração MQTT configurada
- [x] Envio da zona violada via MQTT
- [x] Planejamento do dashboard
- [x] Planejamento dos alertas ao usuário
- [x] Dashboard funcional
- [x] Teste manual do dashboard via MQTT
- [ ] Teste físico na placa

## Resultado da Simulação

A simulação comportamental realizada no Vivado validou a sequência principal da MEF:

```text
DESARMADO → ARMADO → CONTAGEM → DISPARO → DESARMADO
```

Durante o teste, a Zona 3 foi violada, o vetor de zonas indicou `04`, o contador atingiu 10 ciclos e o sistema entrou no estado de disparo.

Também foi validado o sinal `esp_zonas`, que envia ao ESP32 o vetor da zona violada. Durante a simulação, a violação da Zona 3 gerou o valor `04`, permitindo que a comunicação futura com a nuvem informe exatamente qual zona foi violada.

## Fluxo no Vivado

Além da simulação comportamental, o projeto também passou pelas etapas de síntese, implementação e geração de bitstream no Vivado. A geração do bitstream foi concluída com sucesso após a criação do arquivo de constraints da Basys 3, indicando que o projeto está preparado para futura programação da FPGA.

## ESP32

## ESP32

Foi criado um código para o ESP32 no Arduino IDE. O ESP32 realiza a leitura do sinal `esp_alerta` e do vetor `esp_zonas[4:0]`, identificando qual zona foi violada.

O código também prevê o envio do sinal `esp_ok` para a FPGA, indicando que o alerta foi recebido e processado.

Posteriormente, o código foi atualizado para incluir conexão Wi-Fi e comunicação MQTT, utilizando as bibliotecas `WiFi.h` e `PubSubClient.h`.

O ESP32 publica as informações nos seguintes tópicos MQTT:

- `mackenzie/alarme/status`
- `mackenzie/alarme/zona`
- `mackenzie/alarme/mensagem`
- `mackenzie/alarme/esp_ok`

Com isso, o sistema passa a enviar para a nuvem o status do alarme, a zona violada e a mensagem de alerta. A compilação do código foi realizada com sucesso no Arduino IDE.

## Dashboard e Alertas

Foi planejado um dashboard em nuvem/mobile para exibir as informações enviadas pelo ESP32 via MQTT.

O dashboard deverá apresentar:

- Status do sistema
- Zona violada
- Mensagem completa do alerta
- Confirmação do ESP32
- Histórico dos eventos
- Contador de disparos

As mensagens de alerta foram definidas para informar explicitamente qual zona foi violada, por exemplo:

```text
ALERTA: Zona 3 violada - Area interna

Foi realizado um teste manual do dashboard utilizando o cliente WebSocket da HiveMQ. As mensagens MQTT foram publicadas nos tópicos do projeto e o dashboard atualizou corretamente o status do sistema, a zona violada, a mensagem de alerta, a confirmação do ESP32, o contador de disparos e o histórico de eventos.

## Redução de Falso-Positivos

O projeto prevê estratégias para reduzir disparos indevidos do alarme.

Na versão atual, a principal estratégia é o uso do estado `CONTAGEM` na Máquina de Estados Finita. Quando uma zona é violada, o sistema não dispara imediatamente; primeiro realiza uma contagem antes de acionar sirene, estrobo e comunicação com o ESP32.

Além disso, foi implementada a memorização da zona violada por meio do sinal `zona_memoria`, garantindo que o evento correto seja mantido durante a contagem e o disparo.

Como extensão futura, os dados registrados no dashboard poderão ser usados para análise estatística e possível aplicação de IA simples, considerando fatores como horário, frequência de disparos, zona acionada e repetição de eventos.

## Relatório Parcial

Foi criado um relatório parcial do projeto contendo:

- Objetivo do sistema
- Arquitetura geral
- Central FPGA em VHDL
- Simulação no Vivado
- Síntese, implementação e bitstream
- ESP32 e MQTT
- Dashboard
- Estratégia inicial de redução de falso-positivos
- Próximas etapas

O arquivo está disponível em:

```text
documentacao/relatorio_parcial.txt

## Tecnologias Utilizadas

- VHDL
- Vivado
- FPGA Basys 3
- ESP32
- MQTT
- Dashboard em nuvem

## Palavras-chave

FPGA, Sistemas Embarcados, Embedded Systems, Basys 3, Artix-7, VHDL, IoT, MQTT, ESP32, Mackenzie.