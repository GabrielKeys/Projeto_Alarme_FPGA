/*
  Projeto: Sistema de Alarme Perimétrico com FPGA + ESP32
  Teste físico com sensores simulando zonas

  Estado atual:
  - Zona 1: botão/reed simulado no GPIO32
  - Zona 2: sensor IR no GPIO33
  - Zona 3: PIR ignorado temporariamente
  - Zona 4: sensor ultrassônico HC-SR04
  - Zona 5: botão no GPIO12
  - Buzzer passivo/sirene no GPIO27
  - LED estroboscópico no GPIO13

  Ligações:
  - Botão de alerta: GPIO26 -> botão -> GND
  - Botões zonas 1 e 5: GPIO -> botão -> GND
  - Sensor IR: OUT -> GPIO33
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
      ECHO -> divisor com 2 resistores de 1k -> GPIO35

  Divisor do ECHO:
      ECHO -> 1k -> GPIO35
      GPIO35 -> 1k -> GND
*/

#include <WiFi.h>
#include <PubSubClient.h>

// ===== CONFIGURAÇÕES DO WI-FI =====
const char* ssid = "rede";
const char* password = "senha";

// ===== CONFIGURAÇÕES MQTT =====
const char* mqtt_server = "broker.hivemq.com";
const int mqtt_port = 1883;

// Tópicos MQTT
const char* topic_status   = "mackenzie/alarme/status";
const char* topic_zona     = "mackenzie/alarme/zona";
const char* topic_mensagem = "mackenzie/alarme/mensagem";
const char* topic_esp_ok   = "mackenzie/alarme/esp_ok";

WiFiClient espClient;
PubSubClient client(espClient);

// ===== PINOS ESP32 =====
#define PIN_ESP_ALERTA  26
#define PIN_BUZZER      27
#define PIN_ESTROBO     13

#define PIN_ZONA_1      32
#define PIN_ZONA_2      33
#define PIN_ZONA_3      25

#define PIN_ZONA_4_TRIG 14
#define PIN_ZONA_4_ECHO 35

#define PIN_ZONA_5      12

int ultimaZona = 0;
bool alertaProcessado = false;

void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(PIN_ESP_ALERTA, INPUT_PULLUP);

  pinMode(PIN_ZONA_1, INPUT_PULLUP);
  pinMode(PIN_ZONA_2, INPUT_PULLUP);

  // Zona 3/PIR ignorada temporariamente
  pinMode(PIN_ZONA_3, INPUT);

  // Zona 4/HC-SR04
  pinMode(PIN_ZONA_4_TRIG, OUTPUT);
  pinMode(PIN_ZONA_4_ECHO, INPUT);
  digitalWrite(PIN_ZONA_4_TRIG, LOW);

  pinMode(PIN_ZONA_5, INPUT_PULLUP);

  // Buzzer passivo no ESP32
  ledcAttach(PIN_BUZZER, 2000, 8);
  ledcWriteTone(PIN_BUZZER, 0);

  // LED estrobo
  pinMode(PIN_ESTROBO, OUTPUT);
  digitalWrite(PIN_ESTROBO, LOW);

  conectarWiFi();

  client.setServer(mqtt_server, mqtt_port);

  Serial.println("ESP32 iniciado com MQTT.");
  Serial.println("Zona 3/PIR ignorada temporariamente.");
  Serial.println("Zona 4 usando HC-SR04.");
  Serial.println("Buzzer passivo no GPIO27.");
  Serial.println("LED estrobo no GPIO13.");
  Serial.println("Aperte uma zona e depois aperte o botao de alerta.");
}

void loop() {
  if (!client.connected()) {
    reconectarMQTT();
  }

  client.loop();

  int alerta = digitalRead(PIN_ESP_ALERTA);

  if (alerta == LOW && alertaProcessado == false) {
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
      client.publish(topic_status, "ESP32 conectado");
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

  // Zona 3/PIR ignorada temporariamente
  // if (digitalRead(PIN_ZONA_3) == HIGH) return 3;

  if (zona4UltrassomViolada()) return 4;

  if (digitalRead(PIN_ZONA_5) == LOW) return 5;

  return 0;
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

  if (distancia > 0 && distancia < 30) {
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
}