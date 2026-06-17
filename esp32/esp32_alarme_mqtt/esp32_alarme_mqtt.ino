/*
  Projeto: Sistema de Alarme Perimétrico com FPGA + ESP32
  Teste físico com sensores simulando zonas

  Estado atual:
  - Sistema com estado ARMADO/DESARMADO via MQTT
  - Botão secreto físico no GPIO5
  - Zona 1: botão/reed no GPIO25
  - Zona 2: sensor IR no GPIO33
  - Zona 3: PIR HC-SR501 no GPIO32 por leitura analógica
  - Zona 4: sensor ultrassônico HC-SR04
  - Zona 5: botão no GPIO12
  - Buzzer passivo/sirene no GPIO27
  - LED estroboscópico no GPIO13

  Ligações:
  - Botão secreto:
      GPIO5 -> botão -> GND

  - Botão de alerta:
      GPIO26 -> botão -> GND

  - Zona 1 reed/botão:
      GPIO25 -> reed/botão -> GND

  - Zona 2 sensor IR:
      VCC -> 3V3
      GND -> GND
      OUT -> GPIO33

  - Zona 3 PIR:
      VCC -> 3V3
      GND -> GND
      OUT -> GPIO32

  - Zona 5 botão:
      GPIO12 -> botão -> GND

  - Buzzer passivo:
      um pino -> GPIO27
      outro pino -> GND

  - LED estrobo:
      GPIO13 -> resistor 220R -> perna maior do LED
      perna menor do LED -> GND

  - HC-SR04:
      VCC  -> VIN/5V
      GND  -> GND
      TRIG -> GPIO14
      ECHO -> divisor com resistores -> GPIO35

  Divisor do ECHO:
      ECHO -> 1k -> GPIO35
      GPIO35 -> 2k -> GND
      Obs: se só tiver resistores de 1k, use dois de 1k em série para formar 2k.

  MQTT:
  - mackenzie/alarme/comando recebe:
      armar
      desarmar
*/

#include <WiFi.h>
#include <PubSubClient.h>

// ===== CONFIGURAÇÕES DO WI-FI =====
const char* ssid = "";
const char* password = "";

// ===== CONFIGURAÇÕES MQTT =====
const char* mqtt_server = "broker.hivemq.com";
const int mqtt_port = 1883;

// Tópicos MQTT
const char* topic_status   = "mackenzie/alarme/status";
const char* topic_zona     = "mackenzie/alarme/zona";
const char* topic_mensagem = "mackenzie/alarme/mensagem";
const char* topic_esp_ok   = "mackenzie/alarme/esp_ok";
const char* topic_comando  = "mackenzie/alarme/comando";

WiFiClient espClient;
PubSubClient client(espClient);

// ===== PINOS ESP32 =====
#define PIN_BOTAO_SECRETO 5

#define PIN_ESP_ALERTA  26
#define PIN_BUZZER      27
#define PIN_ESTROBO     13

#define PIN_ZONA_1      25
#define PIN_ZONA_2      33
#define PIN_ZONA_3      32

#define PIN_ZONA_4_TRIG 14
#define PIN_ZONA_4_ECHO 35

#define PIN_ZONA_5      12

#define LIMIAR_PIR      3900

int ultimaZona = 0;
bool alertaProcessado = false;
bool sistemaArmado = false;

// Controle do botão secreto
bool ultimoEstadoBotaoSecreto = HIGH;
unsigned long ultimoTempoBotaoSecreto = 0;
const unsigned long debounceBotaoSecreto = 250;

void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(PIN_BOTAO_SECRETO, INPUT_PULLUP);
  pinMode(PIN_ESP_ALERTA, INPUT_PULLUP);

  pinMode(PIN_ZONA_1, INPUT_PULLUP);
  pinMode(PIN_ZONA_2, INPUT_PULLUP);

  pinMode(PIN_ZONA_3, INPUT_PULLDOWN);
  analogReadResolution(12);
  analogSetPinAttenuation(PIN_ZONA_3, ADC_11db);

  pinMode(PIN_ZONA_4_TRIG, OUTPUT);
  pinMode(PIN_ZONA_4_ECHO, INPUT);
  digitalWrite(PIN_ZONA_4_TRIG, LOW);

  pinMode(PIN_ZONA_5, INPUT_PULLUP);

  ledcAttach(PIN_BUZZER, 2000, 8);
  ledcWriteTone(PIN_BUZZER, 0);

  pinMode(PIN_ESTROBO, OUTPUT);
  digitalWrite(PIN_ESTROBO, LOW);

  conectarWiFi();

  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callbackMQTT);

  Serial.println("ESP32 iniciado com MQTT.");
  Serial.println("Sistema inicia DESARMADO.");
  Serial.println("Botao secreto no GPIO5.");
  Serial.println("Comandos MQTT: armar / desarmar");
  Serial.println("Zona 1 reed/botao no GPIO25.");
  Serial.println("Zona 2 IR no GPIO33.");
  Serial.println("Zona 3 PIR analogico no GPIO32.");
  Serial.println("Zona 4 usando HC-SR04.");
  Serial.println("Zona 5 botao no GPIO12.");
  Serial.println("Buzzer passivo no GPIO27.");
  Serial.println("LED estrobo no GPIO13.");
}

void loop() {
  if (!client.connected()) {
    reconectarMQTT();
  }

  client.loop();

  verificarBotaoSecreto();

  int alerta = digitalRead(PIN_ESP_ALERTA);

  if (alerta == LOW && alertaProcessado == false) {

    if (sistemaArmado == false) {
      Serial.println("Alerta ignorado: sistema desarmado.");
      client.publish(topic_mensagem, "Alerta ignorado: sistema desarmado");
      alertaProcessado = true;
      return;
    }

    ultimaZona = identificarZona();

    if (ultimaZona > 0) {
      String mensagem = montarMensagem(ultimaZona);

      Serial.println("ALERTA RECEBIDO");
      Serial.println(mensagem);

      publicarMQTT(ultimaZona, mensagem);

      acionarContramedidas();

      alertaProcessado = true;
    } else {
      Serial.println("Alerta acionado, mas nenhuma zona foi detectada.");
      alertaProcessado = true;
    }
  }

  if (alerta == HIGH) {
    alertaProcessado = false;
  }
}

void verificarBotaoSecreto() {
  bool estadoAtual = digitalRead(PIN_BOTAO_SECRETO);

  if (estadoAtual == LOW && ultimoEstadoBotaoSecreto == HIGH) {
    unsigned long agora = millis();

    if (agora - ultimoTempoBotaoSecreto > debounceBotaoSecreto) {
      sistemaArmado = !sistemaArmado;

      if (sistemaArmado) {
        Serial.println("Sistema ARMADO pelo botao secreto.");
        client.publish(topic_status, "armado");
        client.publish(topic_mensagem, "Sistema armado pelo botao secreto");
      } else {
        Serial.println("Sistema DESARMADO pelo botao secreto.");
        client.publish(topic_status, "desarmado");
        client.publish(topic_mensagem, "Sistema desarmado pelo botao secreto");
      }

      ultimoTempoBotaoSecreto = agora;
    }
  }

  ultimoEstadoBotaoSecreto = estadoAtual;
}

void callbackMQTT(char* topic, byte* payload, unsigned int length) {
  String mensagem = "";

  for (unsigned int i = 0; i < length; i++) {
    mensagem += (char)payload[i];
  }

  mensagem.trim();
  mensagem.toLowerCase();

  Serial.print("Comando MQTT recebido: ");
  Serial.println(mensagem);

  if (mensagem == "armar") {
    sistemaArmado = true;
    client.publish(topic_status, "armado");
    client.publish(topic_mensagem, "Sistema armado via MQTT");
    Serial.println("Sistema ARMADO.");
  }

  if (mensagem == "desarmar") {
    sistemaArmado = false;
    client.publish(topic_status, "desarmado");
    client.publish(topic_mensagem, "Sistema desarmado via MQTT");
    Serial.println("Sistema DESARMADO.");
  }
}

void acionarContramedidas() {
  Serial.println("Sirene e estrobo acionados.");

  for (int i = 0; i < 8; i++) {
    digitalWrite(PIN_ESTROBO, HIGH);
    ledcWriteTone(PIN_BUZZER, 2500);
    delay(150);

    digitalWrite(PIN_ESTROBO, LOW);
    ledcWriteTone(PIN_BUZZER, 3500);
    delay(150);
  }

  ledcWriteTone(PIN_BUZZER, 0);
  digitalWrite(PIN_ESTROBO, LOW);
}

void conectarWiFi() {
  Serial.print("Conectando ao Wi-Fi: ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.println("Wi-Fi conectado.");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
}

void reconectarMQTT() {
  while (!client.connected()) {
    Serial.print("Conectando ao broker MQTT... ");

    String clientId = "ESP32_Alarme_FPGA_";
    clientId += String(random(0xffff), HEX);

    if (client.connect(clientId.c_str())) {
      Serial.println("conectado.");

      client.subscribe(topic_comando);

      if (sistemaArmado) {
        client.publish(topic_status, "armado");
        client.publish(topic_mensagem, "ESP32 reconectado. Sistema armado.");
      } else {
        client.publish(topic_status, "desarmado");
        client.publish(topic_mensagem, "ESP32 conectado. Sistema desarmado.");
      }
    } else {
      Serial.print("falhou, rc=");
      Serial.print(client.state());
      Serial.println(" tentando novamente em 5 segundos");
      delay(5000);
    }
  }
}

int identificarZona() {
  if (digitalRead(PIN_ZONA_1) == LOW) return 1;
  if (digitalRead(PIN_ZONA_2) == LOW) return 2;
  if (zona3PIRViolada()) return 3;
  if (zona4UltrassomViolada()) return 4;
  if (digitalRead(PIN_ZONA_5) == LOW) return 5;

  return 0;
}

bool zona3PIRViolada() {
  long soma = 0;

  for (int i = 0; i < 10; i++) {
    soma += analogRead(PIN_ZONA_3);
    delay(2);
  }

  int valorPIR = soma / 10;

  Serial.print("PIR analogico medio: ");
  Serial.println(valorPIR);

  if (valorPIR > LIMIAR_PIR) {
    Serial.println("Zona 3 violada. PIR detectou movimento.");
    return true;
  }

  return false;
}

bool zona4UltrassomViolada() {
  digitalWrite(PIN_ZONA_4_TRIG, LOW);
  delayMicroseconds(2);

  digitalWrite(PIN_ZONA_4_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_ZONA_4_TRIG, LOW);

  long duracao = pulseIn(PIN_ZONA_4_ECHO, HIGH, 30000);

  if (duracao == 0) {
    return false;
  }

  float distancia = duracao * 0.034 / 2.0;

  if (distancia > 0 && distancia < 15) {
    Serial.print("Zona 4 violada. Distancia: ");
    Serial.print(distancia);
    Serial.println(" cm");
    return true;
  }

  return false;
}

String montarMensagem(int zona) {
  String local = "";

  switch (zona) {
    case 1:
      local = "Porta principal";
      break;
    case 2:
      local = "Janela lateral";
      break;
    case 3:
      local = "Area interna";
      break;
    case 4:
      local = "Area externa";
      break;
    case 5:
      local = "Area critica";
      break;
    default:
      local = "Desconhecida";
      break;
  }

  return "ALERTA: Zona " + String(zona) + " violada - " + local;
}

void publicarMQTT(int zona, String mensagem) {
  String zonaStr = String(zona);

  client.publish(topic_status, "disparo");
  client.publish(topic_zona, zonaStr.c_str());
  client.publish(topic_mensagem, mensagem.c_str());
  client.publish(topic_esp_ok, "ok");

  Serial.println("Dados publicados via MQTT.");
  Serial.print("Zona: ");
  Serial.println(zona);
  Serial.println(mensagem);
}