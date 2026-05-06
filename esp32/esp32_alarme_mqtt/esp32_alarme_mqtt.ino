/*
  Projeto: Sistema de Alarme Perimétrico com FPGA + ESP32
  Função: Receber sinais da FPGA e enviar alerta via MQTT
*/

#include <WiFi.h>
#include <PubSubClient.h>

// ===== CONFIGURAÇÕES DO WI-FI =====
const char* ssid = "Rede";
const char* password = "Senha";

// ===== CONFIGURAÇÕES MQTT =====
// Broker público para teste inicial
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
#define PIN_ESP_OK      27
#define PIN_ZONA_1      32
#define PIN_ZONA_2      33
#define PIN_ZONA_3      25
#define PIN_ZONA_4      14
#define PIN_ZONA_5      12

int ultimaZona = 0;

void setup() {
  Serial.begin(115200);

  pinMode(PIN_ESP_ALERTA, INPUT);

  pinMode(PIN_ZONA_1, INPUT);
  pinMode(PIN_ZONA_2, INPUT);
  pinMode(PIN_ZONA_3, INPUT);
  pinMode(PIN_ZONA_4, INPUT);
  pinMode(PIN_ZONA_5, INPUT);

  pinMode(PIN_ESP_OK, OUTPUT);
  digitalWrite(PIN_ESP_OK, LOW);

  conectarWiFi();

  client.setServer(mqtt_server, mqtt_port);

  Serial.println("ESP32 iniciado com MQTT.");
  Serial.println("Aguardando alerta da FPGA...");
}

void loop() {
  if (!client.connected()) {
    reconectarMQTT();
  }

  client.loop();

  int alerta = digitalRead(PIN_ESP_ALERTA);

  if (alerta == HIGH) {
    ultimaZona = identificarZona();

    if (ultimaZona > 0) {
      String mensagem = montarMensagem(ultimaZona);

      Serial.println("ALERTA RECEBIDO DA FPGA");
      Serial.println(mensagem);

      publicarMQTT(ultimaZona, mensagem);

      digitalWrite(PIN_ESP_OK, HIGH);
      delay(1000);
      digitalWrite(PIN_ESP_OK, LOW);

      delay(2000);
    }
  }
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
  if (digitalRead(PIN_ZONA_1) == HIGH) return 1;
  if (digitalRead(PIN_ZONA_2) == HIGH) return 2;
  if (digitalRead(PIN_ZONA_3) == HIGH) return 3;
  if (digitalRead(PIN_ZONA_4) == HIGH) return 4;
  if (digitalRead(PIN_ZONA_5) == HIGH) return 5;

  return 0;
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

  Serial.println("Dados publicados via MQTT:");
  Serial.println("Status: disparo");
  Serial.print("Zona: ");
  Serial.println(zona);
  Serial.println(mensagem);
}