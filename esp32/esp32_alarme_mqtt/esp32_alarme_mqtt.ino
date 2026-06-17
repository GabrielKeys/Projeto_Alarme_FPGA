/*
  Projeto: Sistema de Alarme Perimetrico com FPGA + ESP32
  Loop fechado FPGA <-> ESP32

  Papel de cada lado, pra nao duplicar decisao:
  - ESP32: le os sensores reais (reed, IR, PIR, ultrassonico, botao) e
    espelha o estado de cada zona pra FPGA. So isso. Nao decide mais
    sozinho se houve alarme.
  - FPGA (alarme_top.vhd): recebe as 5 zonas, roda a MEF com o estado
    CONTAGEM (filtro de falso-positivo) e so quando confirma o disparo
    avisa o ESP32 por esp_alerta + esp_zonas, dizendo exatamente qual
    zona validou.
  - ESP32: ao ver esp_alerta, le esp_zonas (a decisao da FPGA, nao mais
    uma releitura dos proprios sensores), publica no MQTT, aciona a
    sirene/estrobo fisicos e devolve esp_ok pra FPGA.

  Ligacoes dos SENSORES (sem mudanca):
  - Zona 1 reed/botao: GPIO25 -> reed/botao -> GND
  - Zona 2 sensor IR: VCC->3V3, GND->GND, OUT->GPIO33
  - Zona 3 PIR: VCC->3V3, GND->GND, OUT->GPIO32 (leitura analogica)
  - Zona 4 HC-SR04: VCC->VIN/5V, GND->GND, TRIG->GPIO14, ECHO->divisor->GPIO35
      Divisor do ECHO: ECHO -> 1k -> GPIO35 -> 2k -> GND
  - Zona 5 botao: GPIO12 -> botao -> GND
  - Buzzer passivo: GPIO27 / GND
  - LED estrobo: GPIO13 -> resistor 220R -> LED -> GND

  Ligacoes NOVAS com a FPGA (Basys 3), todas em logica 3V3, GND comum
  obrigatorio entre as duas placas:

  Sentido FPGA -> ESP32 (a central avisa o ESP32):
    PMOD JA1 (esp_alerta)     -> GPIO26 (ja existia)
    PMOD JB1 (esp_zonas[0])   -> GPIO21
    PMOD JB2 (esp_zonas[1])   -> GPIO22
    PMOD JB3 (esp_zonas[2])   -> GPIO23
    PMOD JB4 (esp_zonas[3])   -> GPIO34
    PMOD JB7 (esp_zonas[4])   -> GPIO36
    PMOD JA2 (esp_reset)      -> GPIO39

  Sentido ESP32 -> FPGA (o ESP32 manda o espelho dos sensores):
    GPIO4  -> PMOD JC1 (zona1)
    GPIO5  -> PMOD JC2 (zona2)
    GPIO16 -> PMOD JC3 (zona3)
    GPIO17 -> PMOD JC4 (zona4)
    GPIO18 -> PMOD JC7 (zona5)
    GPIO19 -> PMOD JA10 (esp_ok)

  MQTT:
  - mackenzie/alarme/comando recebe: armar / desarmar
    (hoje so atualiza status no dashboard; quem de fato arma/desarma
    a central e o switch fisico botao_arm na FPGA)
*/

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <PubSubClient.h>

// ===== CONFIGURACOES DO WI-FI =====
const char* ssid = "GabrielEsp";
const char* password = "batata123";

// ===== CONFIGURACOES MQTT (broker privado, TLS, com autenticacao) =====
// ### PREENCHA AQUI ### com os dados do SEU cluster gratuito na HiveMQ Cloud
// (console.hivemq.cloud -> Create cluster -> Access Management -> Add credentials)
const char* mqtt_server = "SEU-CLUSTER.s1.eu.hivemq.cloud"; // host do seu cluster
const int   mqtt_port   = 8883;                              // 8883 = MQTT com TLS
const char* mqtt_user   = "SEU_USUARIO_MQTT";
const char* mqtt_pass   = "SUA_SENHA_MQTT";

// Topicos MQTT
const char* topic_status   = "mackenzie/alarme/status";
const char* topic_zona     = "mackenzie/alarme/zona";
const char* topic_mensagem = "mackenzie/alarme/mensagem";
const char* topic_esp_ok   = "mackenzie/alarme/esp_ok";
const char* topic_comando  = "mackenzie/alarme/comando";

// ===== CONFIGURACOES DO ALERTA POR WHATSAPP (CallMeBot, gratuito) =====
// ### PREENCHA AQUI ### depois de cadastrar seu numero no CallMeBot
// (mande "I allow callmebot to send me messages" pelo WhatsApp para
// +34 644 59 71 67 e ele responde com o apikey)
const char* whatsapp_numero  = "55119XXXXXXXX"; // com codigo do pais, sem + nem espaco
const char* whatsapp_apikey  = "SEU_APIKEY_CALLMEBOT";

WiFiClientSecure espClient;
PubSubClient client(espClient);

// ===== PINOS DOS SENSORES (ESP32 le o mundo real) =====
#define PIN_ZONA_1      25   // Reed/botao
#define PIN_ZONA_2      33   // Sensor IR
#define PIN_ZONA_3      32   // PIR por leitura analogica

#define PIN_ZONA_4_TRIG 14
#define PIN_ZONA_4_ECHO 35

#define PIN_ZONA_5      12

// ===== PINOS DOS ATUADORES LOCAIS =====
#define PIN_BUZZER      27
#define PIN_ESTROBO     13

// ===== PINOS DA COMUNICACAO COM A FPGA =====

// FPGA -> ESP32
#define PIN_ESP_ALERTA     26   // esp_alerta (PMOD JA1)
#define PIN_FPGA_ZONA0     21   // esp_zonas[0] = zona1 (PMOD JB1)
#define PIN_FPGA_ZONA1     22   // esp_zonas[1] = zona2 (PMOD JB2)
#define PIN_FPGA_ZONA2     23   // esp_zonas[2] = zona3 (PMOD JB3)
#define PIN_FPGA_ZONA3     34   // esp_zonas[3] = zona4 (PMOD JB4)
#define PIN_FPGA_ZONA4     36   // esp_zonas[4] = zona5 (PMOD JB7)
#define PIN_ESP_RESET_IN   39   // esp_reset (PMOD JA2)

// ESP32 -> FPGA
#define PIN_ZONA1_OUT      4    // zona1 (PMOD JC1)
#define PIN_ZONA2_OUT      5    // zona2 (PMOD JC2)
#define PIN_ZONA3_OUT      16   // zona3 (PMOD JC3)
#define PIN_ZONA4_OUT      17   // zona4 (PMOD JC4)
#define PIN_ZONA5_OUT      18   // zona5 (PMOD JC7)
#define PIN_ESP_OK_OUT     19   // esp_ok (PMOD JA10)

// Limiar do PIR analogico
// Como o sinal estava parado por volta de 3600,
// usamos 3900 para evitar falso positivo.
#define LIMIAR_PIR      3900

bool alertaProcessado = false;

void setup() {
  Serial.begin(115200);
  delay(1000);

  // ----- Sensores -----
  pinMode(PIN_ZONA_1, INPUT_PULLUP);
  pinMode(PIN_ZONA_2, INPUT_PULLUP);

  pinMode(PIN_ZONA_3, INPUT_PULLDOWN);
  analogReadResolution(12);
  analogSetPinAttenuation(PIN_ZONA_3, ADC_11db);

  pinMode(PIN_ZONA_4_TRIG, OUTPUT);
  pinMode(PIN_ZONA_4_ECHO, INPUT);
  digitalWrite(PIN_ZONA_4_TRIG, LOW);

  pinMode(PIN_ZONA_5, INPUT_PULLUP);

  // ----- Atuadores locais -----
  ledcAttach(PIN_BUZZER, 2000, 8);
  ledcWriteTone(PIN_BUZZER, 0);

  pinMode(PIN_ESTROBO, OUTPUT);
  digitalWrite(PIN_ESTROBO, LOW);

  // ----- Entradas vindas da FPGA -----
  // esp_alerta e esp_zonas/esp_reset sao sempre dirigidos pela FPGA
  // (saida ativa, push-pull), entao INPUT simples basta. Uso pulldown
  // so como seguranca caso a FPGA ainda nao tenha configurado o
  // bitstream no momento em que o ESP32 liga.
  pinMode(PIN_ESP_ALERTA, INPUT_PULLDOWN);
  pinMode(PIN_FPGA_ZONA0, INPUT_PULLDOWN);
  pinMode(PIN_FPGA_ZONA1, INPUT_PULLDOWN);
  pinMode(PIN_FPGA_ZONA2, INPUT_PULLDOWN);
  pinMode(PIN_FPGA_ZONA3, INPUT_PULLDOWN);
  pinMode(PIN_FPGA_ZONA4, INPUT_PULLDOWN);
  pinMode(PIN_ESP_RESET_IN, INPUT_PULLDOWN);

  // ----- Saidas para a FPGA -----
  pinMode(PIN_ZONA1_OUT, OUTPUT);
  pinMode(PIN_ZONA2_OUT, OUTPUT);
  pinMode(PIN_ZONA3_OUT, OUTPUT);
  pinMode(PIN_ZONA4_OUT, OUTPUT);
  pinMode(PIN_ZONA5_OUT, OUTPUT);
  pinMode(PIN_ESP_OK_OUT, OUTPUT);

  digitalWrite(PIN_ZONA1_OUT, LOW);
  digitalWrite(PIN_ZONA2_OUT, LOW);
  digitalWrite(PIN_ZONA3_OUT, LOW);
  digitalWrite(PIN_ZONA4_OUT, LOW);
  digitalWrite(PIN_ZONA5_OUT, LOW);
  digitalWrite(PIN_ESP_OK_OUT, LOW);

  conectarWiFi();

  // TLS sem validar a cadeia de certificado do broker (setInsecure).
  // O trafego continua criptografado e o login (usuario/senha) continua
  // exigido pelo broker, o que ja resolve o problema principal (qualquer
  // um podia publicar/ler no broker publico antigo sem autenticacao).
  // Se quiser validacao completa da cadeia, pegue o certificado exato
  // do seu cluster no painel da HiveMQ Cloud e troque por
  // espClient.setCACert(...).
  espClient.setInsecure();

  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callbackMQTT);

  Serial.println("ESP32 iniciado.");
  Serial.println("Espelhando sensores para a FPGA via PMOD JC.");
  Serial.println("Lendo decisao da FPGA via PMOD JB (esp_zonas) e JA1 (esp_alerta).");
}

void loop() {
  if (!client.connected()) {
    reconectarMQTT();
  }

  client.loop();

  // Sempre espelha o estado real dos sensores para a FPGA.
  // Quem decide se isso configura um disparo e a MEF na FPGA.
  espelharZonasParaFPGA();

  // ----- Le a decisao da FPGA -----
  int alerta = digitalRead(PIN_ESP_ALERTA);

  if (alerta == HIGH && alertaProcessado == false) {

    int zona = lerZonaConfirmadaPelaFPGA();

    if (zona > 0) {
      String mensagem = montarMensagem(zona);

      Serial.println("ALERTA CONFIRMADO PELA FPGA (pos estado CONTAGEM)");
      Serial.println(mensagem);

      publicarMQTT(zona, mensagem);
      enviarWhatsApp(mensagem);
      acionarContramedidas();

      digitalWrite(PIN_ESP_OK_OUT, HIGH); // confirma recebimento para a FPGA
    } else {
      // esp_alerta subiu mas esp_zonas chegou 00000: normalmente
      // fiacao do PMOD JB solta ou GND nao comum entre as placas.
      Serial.println("esp_alerta ativo, porem esp_zonas = 00000. Checar fiacao do PMOD JB.");
      client.publish(topic_mensagem, "Alerta da FPGA sem zona identificada - checar fiacao");
    }

    alertaProcessado = true;
  }

  // Libera novo alerta e baixa o esp_ok quando a FPGA volta a zerar esp_alerta
  if (alerta == LOW) {
    alertaProcessado = false;
    digitalWrite(PIN_ESP_OK_OUT, LOW);
  }

  // ----- Watchdog: a FPGA pede reset porque nao recebeu esp_ok a tempo -----
  if (digitalRead(PIN_ESP_RESET_IN) == HIGH) {
    Serial.println("Reset solicitado pela FPGA (watchdog). Reiniciando ESP32...");
    if (client.connected()) {
      client.publish(topic_mensagem, "ESP32 reiniciado por timeout do watchdog da FPGA");
    }
    delay(200);
    ESP.restart();
  }
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

  // Observacao: quem de fato arma/desarma a central e o switch botao_arm
  // na FPGA. Isso aqui so atualiza o status mostrado no dashboard.
  if (mensagem == "armar") {
    client.publish(topic_status, "armado");
    client.publish(topic_mensagem, "Comando armar recebido (arme tambem o switch na FPGA)");
  }

  if (mensagem == "desarmar") {
    client.publish(topic_status, "desarmado");
    client.publish(topic_mensagem, "Comando desarmar recebido (desarme tambem o switch na FPGA)");
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

    if (client.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
      Serial.println("conectado.");
      client.subscribe(topic_comando);
      client.publish(topic_mensagem, "ESP32 reconectado ao broker MQTT");
    } else {
      Serial.print("falhou, rc=");
      Serial.print(client.state());
      Serial.println(" tentando novamente em 5 segundos");
      delay(5000);
    }
  }
}

// ===== Leitura dos sensores reais e espelho para a FPGA =====

void espelharZonasParaFPGA() {
  bool z1 = (digitalRead(PIN_ZONA_1) == LOW);   // reed/botao ativo em LOW
  bool z2 = (digitalRead(PIN_ZONA_2) == LOW);   // IR ativo em LOW
  bool z3 = zona3PIRViolada();
  bool z4 = zona4UltrassomViolada();
  bool z5 = (digitalRead(PIN_ZONA_5) == LOW);   // botao ativo em LOW

  digitalWrite(PIN_ZONA1_OUT, z1 ? HIGH : LOW);
  digitalWrite(PIN_ZONA2_OUT, z2 ? HIGH : LOW);
  digitalWrite(PIN_ZONA3_OUT, z3 ? HIGH : LOW);
  digitalWrite(PIN_ZONA4_OUT, z4 ? HIGH : LOW);
  digitalWrite(PIN_ZONA5_OUT, z5 ? HIGH : LOW);
}

bool zona3PIRViolada() {
  long soma = 0;

  for (int i = 0; i < 10; i++) {
    soma += analogRead(PIN_ZONA_3);
    delay(2);
  }

  int valorPIR = soma / 10;

  return (valorPIR > LIMIAR_PIR);
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

  return (distancia > 0 && distancia < 15);
}

// ===== Leitura da decisao da FPGA (esp_zonas) =====

int lerZonaConfirmadaPelaFPGA() {
  // Mesma ordem do VHDL: esp_zonas(0)=zona1 ... esp_zonas(4)=zona5
  if (digitalRead(PIN_FPGA_ZONA0) == HIGH) return 1;
  if (digitalRead(PIN_FPGA_ZONA1) == HIGH) return 2;
  if (digitalRead(PIN_FPGA_ZONA2) == HIGH) return 3;
  if (digitalRead(PIN_FPGA_ZONA3) == HIGH) return 4;
  if (digitalRead(PIN_FPGA_ZONA4) == HIGH) return 5;
  return 0;
}

String montarMensagem(int zona) {
  String local = "";

  switch (zona) {
    case 1: local = "Porta principal"; break;
    case 2: local = "Janela lateral";   break;
    case 3: local = "Area interna";     break;
    case 4: local = "Area externa";     break;
    case 5: local = "Area critica";     break;
    default: local = "Desconhecida";    break;
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
  Serial.print("Zona confirmada pela FPGA: ");
  Serial.println(zona);
  Serial.println(mensagem);
}

// Segundo canal de alerta, independente do dashboard/MQTT, como o
// enunciado pede (alem da nuvem, um contato direto com o usuario).
void enviarWhatsApp(String mensagem) {
  WiFiClientSecure httpClient;
  httpClient.setInsecure(); // mesma logica do MQTT: criptografado, sem pin de certificado

  HTTPClient https;

  String textoCodificado = mensagem;
  textoCodificado.replace(" ", "%20");
  textoCodificado.replace(":", "%3A");

  String url = "https://api.callmebot.com/whatsapp.php?phone=" + String(whatsapp_numero) +
               "&text=" + textoCodificado +
               "&apikey=" + String(whatsapp_apikey);

  if (https.begin(httpClient, url)) {
    int codigo = https.GET();
    Serial.print("CallMeBot HTTP: ");
    Serial.println(codigo);
    https.end();
  } else {
    Serial.println("Falha ao iniciar requisicao HTTPS para o CallMeBot.");
  }
}
