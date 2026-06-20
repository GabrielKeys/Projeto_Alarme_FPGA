\# Sistema Embarcado de Alarme Perimétrico com FPGA Basys 3 e ESP32



Projeto final da disciplina de \*\*Sistemas Embarcados\*\*.



\## Integrantes



\* Gabriel Chaves de Sousa Santos — 10376010

\* Anthony Luis Bachiega Rodrigues — 10410476

\* Pedro Luis Polegato Fileno — 10416636



\---



\## Objetivo



Desenvolver um sistema embarcado de alarme perimétrico para detecção e dissuasão de ameaças, utilizando uma central implementada em \*\*FPGA Basys 3\*\*, integrada a um \*\*ESP32\*\*, comunicação MQTT, dashboard/app em nuvem, alertas remotos ao usuário e contramedidas físicas.



O sistema monitora cinco zonas de segurança, identifica a zona violada, permite armamento/desarmamento, realiza contagem pós-violação programável e aciona alertas e contramedidas após confirmação do disparo.



\---



\## Arquitetura Geral



O sistema é composto por:



\* FPGA Basys 3

\* ESP32 DevKit

\* 5 zonas de sensores

\* Máquina de Estados Finita em VHDL

\* Tempo pós-violação programável de 0 a 120 segundos

\* Sirene / buzzer

\* Luz estroboscópica com chip LED de 50 W

\* Cerca elétrica didática

\* Dashboard/App em nuvem

\* Comunicação MQTT

\* Alerta por WhatsApp via CallMeBot

\* Alerta por SMS via Twilio



Fluxo geral:



```text

Sensores / Zonas

&#x20;       ↓

FPGA Basys 3

&#x20;       ↓

MEF + tempo programável

&#x20;       ↓

ESP32

&#x20;       ↓

MQTT / Dashboard / WhatsApp / SMS

&#x20;       ↓

Usuário

```



\---



\## Zonas Monitoradas



| Zona   | Local simulado  | Sensor                      |

| ------ | --------------- | --------------------------- |

| Zona 1 | Porta principal | Reed switch / botão         |

| Zona 2 | Janela lateral  | Sensor IR                   |

| Zona 3 | Área interna    | Sensor PIR                  |

| Zona 4 | Área externa    | Sensor ultrassônico HC-SR04 |

| Zona 5 | Área crítica    | Botão / reed switch         |



\---



\## Máquina de Estados



A central FPGA foi implementada em VHDL com uma Máquina de Estados Finita composta por:



\* `DESARMADO`

\* `ARMADO`

\* `CONTAGEM`

\* `DISPARO`

\* `RESET\_ESP`



\### Descrição dos estados



\* \*\*DESARMADO:\*\* sensores podem ser acionados sem gerar disparo. O display mostra `d`.

\* \*\*ARMADO:\*\* a central monitora as cinco zonas. O display mostra `A`.

\* \*\*CONTAGEM:\*\* após violação, a FPGA aguarda o tempo programado pelo usuário.

\* \*\*DISPARO:\*\* a FPGA aciona as saídas de alerta, envia a zona ao ESP32 e o display mostra `U`.

\* \*\*RESET\_ESP:\*\* estado de supervisão/watchdog caso o ESP32 não retorne `esp\_ok`.



\---



\## Tempo Programável Pós-Violação



O sistema permite programar, pela central FPGA, a quantidade de segundos após a violação de perímetro antes da realização das ações de disparo.



A programação é feita pelos switches da Basys 3:



| Recurso    | Função                                |

| ---------- | ------------------------------------- |

| SW0        | Armar/desarmar                        |

| SW1 a SW5  | Simulação das zonas                   |

| SW6 a SW12 | Tempo programável de 0 a 120 segundos |



Exemplos de configuração:



```text

0000000 = 0 segundos

0000001 = 1 segundo

0001010 = 10 segundos

0111100 = 60 segundos

1111000 = 120 segundos

```



Caso o valor configurado ultrapasse 120, o VHDL limita automaticamente para 120 segundos.



\---



\## Funcionalidades



\* Monitoramento de 5 zonas.

\* Identificação da zona violada.

\* Memorização da zona violada.

\* Máquina de Estados Finita implementada em VHDL.

\* Tempo pós-violação programável de 0 a 120 segundos.

\* Acionamento de sirene/buzzer.

\* Acionamento de luz estroboscópica.

\* Acionamento de cerca elétrica didática.

\* Indicação visual por LEDs.

\* Indicação por display de sete segmentos.

\* Comunicação entre FPGA e ESP32.

\* Envio da zona violada ao ESP32 por meio de `esp\_zonas`.

\* Retorno `esp\_ok` do ESP32 para a FPGA.

\* Comunicação MQTT com dashboard/app.

\* Dashboard web com histórico, contador de disparos e status.

\* Controle por voz no dashboard.

\* Alerta por WhatsApp via CallMeBot.

\* Alerta por SMS via Twilio.



\---



\## Comunicação FPGA Basys 3 ↔ ESP32



A comunicação entre a Basys 3 e o ESP32 é feita por sinais digitais em lógica de 3,3 V, com GND comum entre as placas.



\### Sinais principais



| Função         | Basys 3 | ESP32               |

| -------------- | ------- | ------------------- |

| `esp\_alerta`   | JA1     | GPIO26              |

| `esp\_zonas\[0]` | JB1     | GPIO correspondente |

| `esp\_zonas\[1]` | JB2     | GPIO correspondente |

| `esp\_zonas\[2]` | JB3     | GPIO correspondente |

| `esp\_zonas\[3]` | JB4     | GPIO correspondente |

| `esp\_zonas\[4]` | JB7     | GPIO correspondente |

| `esp\_ok`       | JA10    | GPIO correspondente |

| GND comum      | GND     | GND                 |



A FPGA é responsável por confirmar o disparo e informar ao ESP32 qual zona foi violada. O ESP32 retorna `esp\_ok` indicando que recebeu e processou o alerta.



\---



\## ESP32



O ESP32 atua como módulo auxiliar de comunicação e integração com serviços externos.



Suas funções principais são:



\* Receber `esp\_alerta` da FPGA.

\* Ler a zona confirmada por `esp\_zonas`.

\* Publicar informações no broker MQTT.

\* Atualizar o dashboard/app.

\* Enviar alerta por WhatsApp.

\* Enviar alerta por SMS.

\* Acionar sirene/buzzer auxiliar.

\* Retornar `esp\_ok` para a FPGA.



Bibliotecas utilizadas:



\* `WiFi.h`

\* `WiFiClientSecure.h`

\* `HTTPClient.h`

\* `PubSubClient.h`



\---



\## MQTT



O ESP32 publica e recebe mensagens MQTT nos seguintes tópicos:



| Tópico                      | Função               |

| --------------------------- | -------------------- |

| `mackenzie/alarme/status`   | Estado do sistema    |

| `mackenzie/alarme/zona`     | Zona violada         |

| `mackenzie/alarme/mensagem` | Mensagem de alerta   |

| `mackenzie/alarme/esp\_ok`   | Confirmação do ESP32 |

| `mackenzie/alarme/comando`  | Comandos remotos     |



Comandos aceitos:



```text

armar

desarmar

```



\---



\## Dashboard e App/PWA



Foi desenvolvido um dashboard web para monitoramento em tempo real do sistema.



O dashboard apresenta:



\* Status do sistema.

\* Zona violada.

\* Mensagem completa do alerta.

\* Confirmação do ESP32.

\* Histórico dos eventos.

\* Contador de disparos.

\* Botões de armar/desarmar.

\* Controle por voz.



O dashboard também foi configurado como PWA, permitindo instalação no celular como aplicativo.



Arquivos principais:



```text

nuvem/

├── index.html

├── manifest.json

└── sw.js

```



\---



\## Controle por Voz



O dashboard possui reconhecimento de voz para envio dos comandos:



```text

armar alarme

desarmar alarme

```



Quando o comando é reconhecido, o dashboard publica a mensagem MQTT no tópico `mackenzie/alarme/comando`.



\---



\## Alertas ao Usuário



\### WhatsApp via CallMeBot



O alerta por WhatsApp usa o serviço \*\*CallMeBot\*\*.



Quando a FPGA confirma o disparo após o estado `CONTAGEM`, o ESP32 monta uma URL com a mensagem e faz uma requisição HTTPS para o serviço:



```text

https://api.callmebot.com/whatsapp.php?phone=NUMERO\_CADASTRADO\&text=ALERTA: Zona X violada\&apikey=CHAVE\_API

```



O CallMeBot recebe a requisição e envia a mensagem para o WhatsApp previamente cadastrado.



Para funcionamento correto, são necessários:



\* Cadastro prévio do número no CallMeBot.

\* Chave `apikey` fornecida pelo serviço.

\* ESP32 conectado à internet.

\* Função `enviarWhatsApp()` no firmware.



A função é chamada junto com `publicarMQTT()` e `enviarSMS()` quando a FPGA confirma a zona violada.



\### SMS via Twilio



O envio de SMS foi implementado utilizando a plataforma \*\*Twilio\*\*.



Após a confirmação do disparo, o ESP32 monta a mensagem e realiza uma requisição HTTPS autenticada para a API do Twilio.



A mensagem enviada segue o padrão:



```text

ALERTA: Zona X violada - Local protegido

```



Em contas trial do Twilio, o número de destino precisa estar verificado no painel da plataforma.



\---



\## Contramedidas



O sistema possui duas contramedidas físicas principais:



1\. Cerca elétrica didática.

2\. Luz estroboscópica com chip LED de 50 W.



Além disso, possui sinalização sonora por buzzer/sirene.



\### Cerca elétrica didática



A cerca elétrica foi implementada como uma contramedida física de demonstração. O circuito utiliza temporizador 555, transistor e estágio de potência para simular uma cerca ativa de baixa potência.



A implementação foi tratada como didática e segura para apresentação acadêmica.



\### Luz estroboscópica com chip LED de 50 W



A luz estroboscópica foi implementada com um chip LED de 50 W acionado por circuito externo de potência.



O LED não é ligado diretamente ao ESP32 ou à FPGA. O acionamento é feito por estágio intermediário, com alimentação externa adequada.



\### Sirene / buzzer



A sirene auxiliar foi prototipada com um buzzer passivo acionado pelo ESP32 via PWM.



\---



\## Segurança Elétrica



Foram adotados os seguintes cuidados:



\* Não alimentar cargas diretamente pela FPGA.

\* Não alimentar cargas diretamente pelos GPIOs do ESP32.

\* Utilizar GND comum entre Basys 3 e ESP32.

\* Não aplicar sinais de 5 V diretamente em entradas de 3,3 V.

\* Utilizar divisor de tensão no ECHO do HC-SR04.

\* Utilizar transistor, MOSFET ou relé para cargas externas.

\* Usar fonte externa para LED de 50 W e cerca elétrica didática.

\* Manter a cerca elétrica como simulação didática segura.

\* Não publicar credenciais reais no repositório.



\---



\## Estrutura do Repositório



```text

Projeto\_Alarme\_FPGA/

├── vivado\_fpga/

│   ├── src/

│   │   └── alarme\_top.vhd

│   ├── tb/

│   │   └── tb\_alarme\_top.vhd

│   └── constraints/

│       └── alarme\_basys3.xdc

├── esp32/

│   └── esp32\_alarme\_mqtt/

│       └── esp32\_alarme\_mqtt.ino

├── nuvem/

│   ├── index.html

│   ├── manifest.json

│   └── sw.js

├── documentacao/

├── imagens/

└── README.md

```



\---



\## Status Atual



\* \[x] Definição do escopo.

\* \[x] Arquitetura lógica.

\* \[x] Máquina de Estados Finita.

\* \[x] Código VHDL da central.

\* \[x] Estado `CONTAGEM`.

\* \[x] Tempo programável 0 a 120 s.

\* \[x] Watchdog/reset lógico do ESP32.

\* \[x] Testbench.

\* \[x] Simulação comportamental no Vivado.

\* \[x] Síntese no Vivado.

\* \[x] Implementação no Vivado.

\* \[x] Geração do bitstream.

\* \[x] Arquivo de constraints da Basys 3.

\* \[x] Envio da zona violada para o ESP32 por `esp\_zonas`.

\* \[x] Memorização da zona violada.

\* \[x] Código ESP32 com Wi-Fi.

\* \[x] Comunicação MQTT configurada.

\* \[x] Dashboard funcional.

\* \[x] PWA configurado.

\* \[x] Controle por voz no dashboard.

\* \[x] Envio da zona violada via MQTT.

\* \[x] Alerta por WhatsApp via CallMeBot.

\* \[x] Alerta por SMS via Twilio.

\* \[x] Circuito de luz estroboscópica com LED 50 W.

\* \[x] Circuito de cerca elétrica didática.

\* \[x] Relatório técnico.

\* \[x] Diagramas de circuitos.

\* \[ ] Testes finais integrados na maquete completa.



\---



\## Resultado da Simulação



A simulação comportamental realizada no Vivado validou a sequência principal da MEF:



```text

DESARMADO → ARMADO → CONTAGEM → DISPARO → DESARMADO

```



Durante o teste, uma zona foi violada, o vetor de zonas foi memorizado e o sistema entrou no estado de contagem antes do disparo.



Também foi validado o sinal `esp\_zonas`, que envia ao ESP32 o vetor da zona violada, permitindo que a comunicação com a nuvem informe exatamente qual região foi acionada.



\---



\## Fluxo no Vivado



O projeto passou pelas etapas de:



\* Simulação comportamental.

\* Síntese.

\* Implementação.

\* Geração de bitstream.

\* Visualização do circuito RTL.



O circuito RTL gerado pelo Vivado mostra que a descrição em VHDL foi sintetizada em lógica digital real, contendo registradores, multiplexadores, comparadores, portas lógicas e contadores.



\---



\## Redução de Falso-Positivos



O projeto utiliza o estado `CONTAGEM` para reduzir disparos indevidos.



Quando uma zona é violada, o sistema não dispara imediatamente. Primeiro, aguarda o tempo programado na central FPGA. Se o sistema continuar em condição de violação após esse período, o disparo é confirmado.



Além disso, a zona violada é memorizada no sinal `zona\_memoria`, garantindo que o evento correto seja mantido durante o disparo.



\---



\## Relatório



Foi criado um relatório técnico do projeto contendo:



\* Objetivo do sistema.

\* Arquitetura geral.

\* Central FPGA em VHDL.

\* Máquina de Estados Finita.

\* Tempo programável 0 a 120 s.

\* Simulação no Vivado.

\* Síntese, implementação e bitstream.

\* ESP32 e MQTT.

\* Dashboard/PWA.

\* WhatsApp via CallMeBot.

\* SMS via Twilio.

\* Contramedidas.

\* Circuitos físicos.

\* Circuito RTL gerado no Vivado.

\* Testes realizados.

\* Limitações e melhorias futuras.



O arquivo está disponível em:



```text

documentacao/Relatório Projeto.docx

```



\---



\## Tecnologias Utilizadas



\* VHDL

\* Vivado

\* FPGA Basys 3

\* Artix-7

\* ESP32

\* Arduino IDE

\* MQTT

\* HiveMQ

\* HTML

\* JavaScript

\* PWA

\* CallMeBot

\* Twilio

\* Circuitos com temporizador 555

\* Circuitos de acionamento de potência



\---



\## Observação sobre Credenciais



As credenciais reais foram removidas ou devem ser substituídas por placeholders antes de qualquer publicação.



Não devem ser enviados ao GitHub:



\* Senhas de Wi-Fi.

\* Usuários e senhas MQTT.

\* Tokens Twilio.

\* API keys do CallMeBot.

\* Números de telefone completos.

\* Chaves privadas ou credenciais de serviços externos.



Exemplo de placeholder:



```cpp

const char\* mqtt\_user = "COLOQUE\_USUARIO\_AQUI";

const char\* mqtt\_pass = "COLOQUE\_SENHA\_AQUI";

const char\* whatsapp\_apikey = "COLOQUE\_APIKEY\_AQUI";

```



\---



\## Palavras-chave



FPGA, Sistemas Embarcados, Embedded Systems, Basys 3, Artix-7, VHDL, IoT, MQTT, ESP32, Dashboard, PWA, WhatsApp, SMS, CallMeBot, Twilio, Mackenzie.



