/*
 * ===============================================================================
 * WORKER SAFETY MONITORING SYSTEM - ESP32 FIRMWARE
 * Target Hardware: ESP32-WROOM-32
 * Development Platform: Arduino IDE / PlatformIO
 * Protocol: Bluetooth Low Energy (BLE) GATT
 * ===============================================================================
 *
 * Characteristics:
 * 1. Telemetry Characteristic (UUID: 0000FFF1-0000-1000-8000-00805F9B34FB) - READ, NOTIFY
 * 2. GPS Characteristic       (UUID: 0000FFF2-0000-1000-8000-00805F9B34FB) - READ, NOTIFY
 * 3. Battery Characteristic   (UUID: 0000FFF3-0000-1000-8000-00805F9B34FB) - READ, NOTIFY
 * 4. Safety Status Char       (UUID: 0000FFF4-0000-1000-8000-00805F9B34FB) - READ, WRITE, NOTIFY
 * 5. SOS Trigger Char         (UUID: 0000FFF5-0000-1000-8000-00805F9B34FB) - READ, WRITE, NOTIFY
 * ===============================================================================
 */

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// -------------------------------------------------------------------------------
// Hardware Pin Definitions
// -------------------------------------------------------------------------------
#define PIN_SOS_BUTTON        4    // Active LOW button with internal pullup
#define PIN_BUZZER            18   // Piezo buzzer for local audible alarms
#define PIN_STATUS_LED_RED    19   // Danger / SOS LED indicator
#define PIN_STATUS_LED_GREEN  21   // Normal / Safe LED indicator
#define PIN_STATUS_LED_BLUE   22   // BLE connected indicator
#define PIN_BATTERY_ADC       34   // ADC pin for battery voltage divider
#define PIN_GAS_ANALOG        35   // MQ-2 / MQ-135 analog output pin

// -------------------------------------------------------------------------------
// BLE UUID Constants
// -------------------------------------------------------------------------------
#define SERVICE_UUID           "0000FFF0-0000-1000-8000-00805F9B34FB"
#define CHAR_TELEMETRY_UUID    "0000FFF1-0000-1000-8000-00805F9B34FB"
#define CHAR_GPS_UUID          "0000FFF2-0000-1000-8000-00805F9B34FB"
#define CHAR_BATTERY_UUID      "0000FFF3-0000-1000-8000-00805F9B34FB"
#define CHAR_SAFETY_STATUS_UUID "0000FFF4-0000-1000-8000-00805F9B34FB"
#define CHAR_SOS_UUID          "0000FFF5-0000-1000-8000-00805F9B34FB"

#define DEVICE_NAME            "ESP32_SAFE_01"

// -------------------------------------------------------------------------------
// Global State & Sensor Data
// -------------------------------------------------------------------------------
BLEServer* pServer = nullptr;
BLECharacteristic* pTelemetryChar = nullptr;
BLECharacteristic* pGpsChar = nullptr;
BLECharacteristic* pBatteryChar = nullptr;
BLECharacteristic* pSafetyStatusChar = nullptr;
BLECharacteristic* pSosChar = nullptr;

bool deviceConnected = false;
bool oldDeviceConnected = false;

// SOS state
volatile bool sosTriggered = false;
volatile unsigned long lastDebounceTime = 0;
const unsigned long DEBOUNCE_DELAY_MS = 250;

// Safety status received from phone AI (0=SAFE, 1=WARNING, 2=DANGER, 3=EMERGENCY)
uint8_t currentSafetyStatus = 0; 

// Simulated sensor values (used when physical I2C/SPI sensors are unpopulated)
float simulatedTemperature = 36.6;
int simulatedHeartRate = 78;
int simulatedSpO2 = 98;
int simulatedGasLevel = 65;
float simulatedHumidity = 50.0;
int simulatedMotion = 1; // 0=rest, 1=active, 2=shock
bool simulatedFall = false;
float simulatedLat = 17.4485;
float simulatedLon = 78.3742;
int batteryPercentage = 95;

unsigned long lastTelemetryMillis = 0;
const unsigned long TELEMETRY_INTERVAL_MS = 2000; // Broadcast every 2 seconds

// -------------------------------------------------------------------------------
// Interrupt Service Routine for Physical SOS Button
// -------------------------------------------------------------------------------
void IRAM_ATTR handleSosInterrupt() {
  unsigned long currentTime = millis();
  if ((currentTime - lastDebounceTime) > DEBOUNCE_DELAY_MS) {
    if (digitalRead(PIN_SOS_BUTTON) == LOW) {
      sosTriggered = true;
    }
    lastDebounceTime = currentTime;
  }
}

// -------------------------------------------------------------------------------
// BLE Server Callbacks
// -------------------------------------------------------------------------------
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    digitalWrite(PIN_STATUS_LED_BLUE, HIGH);
    Serial.println("[BLE] Client connected.");
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    digitalWrite(PIN_STATUS_LED_BLUE, LOW);
    Serial.println("[BLE] Client disconnected. Restarting advertising...");
  }
};

// -------------------------------------------------------------------------------
// Safety Status Characteristic Callbacks (Receives phone AI status)
// -------------------------------------------------------------------------------
class SafetyStatusCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue().c_str();
    if (value.length() > 0) {
      currentSafetyStatus = value[0];
      Serial.printf("[BLE] Received Safety Status update from phone: %d\n", currentSafetyStatus);

      // Trigger local alarm actuators based on severity
      if (currentSafetyStatus == 0) { // SAFE
        digitalWrite(PIN_STATUS_LED_GREEN, HIGH);
        digitalWrite(PIN_STATUS_LED_RED, LOW);
        noTone(PIN_BUZZER);
      } else if (currentSafetyStatus == 1) { // WARNING
        digitalWrite(PIN_STATUS_LED_GREEN, HIGH);
        digitalWrite(PIN_STATUS_LED_RED, HIGH); // Amber combination
        noTone(PIN_BUZZER);
      } else if (currentSafetyStatus == 2) { // DANGER
        digitalWrite(PIN_STATUS_LED_GREEN, LOW);
        digitalWrite(PIN_STATUS_LED_RED, HIGH);
        tone(PIN_BUZZER, 1800, 200); // Beep alarm
      } else if (currentSafetyStatus == 3) { // EMERGENCY
        digitalWrite(PIN_STATUS_LED_GREEN, LOW);
        digitalWrite(PIN_STATUS_LED_RED, HIGH);
        tone(PIN_BUZZER, 2500); // Continuous siren
      }
    }
  }
};

// -------------------------------------------------------------------------------
// Sensor Sampling & Simulation Routines
// -------------------------------------------------------------------------------
void readSensors() {
  // If physical analog gas sensor is wired, read ADC:
  // int gasRaw = analogRead(PIN_GAS_ANALOG);
  // simulatedGasLevel = map(gasRaw, 0, 4095, 20, 1000);

  // Add natural slight physical drift
  simulatedTemperature += (random(-5, 6) / 50.0);
  if (simulatedTemperature < 36.1) simulatedTemperature = 36.4;
  if (simulatedTemperature > 37.4) simulatedTemperature = 37.1;

  simulatedHeartRate += random(-2, 3);
  if (simulatedHeartRate < 68) simulatedHeartRate = 72;
  if (simulatedHeartRate > 95) simulatedHeartRate = 88;

  simulatedSpO2 += random(-1, 2);
  if (simulatedSpO2 < 96) simulatedSpO2 = 97;
  if (simulatedSpO2 > 100) simulatedSpO2 = 99;

  simulatedGasLevel += random(-3, 4);
  if (simulatedGasLevel < 35) simulatedGasLevel = 45;
  if (simulatedGasLevel > 180) simulatedGasLevel = 110;

  simulatedHumidity += (random(-5, 6) / 10.0);
  if (simulatedHumidity < 40.0) simulatedHumidity = 45.0;
  if (simulatedHumidity > 65.0) simulatedHumidity = 58.0;

  // Slowly drain simulated battery
  static unsigned long lastBatteryDrop = 0;
  if (millis() - lastBatteryDrop > 60000) { // every minute
    if (batteryPercentage > 10) batteryPercentage--;
    lastBatteryDrop = millis();
  }
}

// -------------------------------------------------------------------------------
// Packet Formatting & BLE Notification
// -------------------------------------------------------------------------------
void sendTelemetryPacket() {
  readSensors();

  unsigned long epochSec = 1727690000 + (millis() / 1000);

  // Compact JSON telemetry payload
  char jsonBuffer[256];
  snprintf(
    jsonBuffer, sizeof(jsonBuffer),
    "{\"deviceId\":\"%s\",\"temperature\":%.1f,\"heartRate\":%d,\"spo2\":%d,\"gasLevel\":%d,\"humidity\":%.1f,\"latitude\":%.6f,\"longitude\":%.6f,\"battery\":%d,\"fallDetected\":%s,\"sos\":%s,\"timestamp\":%lu}",
    DEVICE_NAME,
    simulatedTemperature,
    simulatedHeartRate,
    simulatedSpO2,
    simulatedGasLevel,
    simulatedHumidity,
    simulatedLat,
    simulatedLon,
    batteryPercentage,
    simulatedFall ? "true" : "false",
    sosTriggered ? "true" : "false",
    epochSec
  );

  pTelemetryChar->setValue(jsonBuffer);
  pTelemetryChar->notify();
  Serial.printf("[BLE] Broadcast Telemetry: %s\n", jsonBuffer);

  // Send Battery characteristic
  char batBuffer[32];
  snprintf(batBuffer, sizeof(batBuffer), "{\"battery\":%d,\"voltage\":4100}", batteryPercentage);
  pBatteryChar->setValue(batBuffer);
  pBatteryChar->notify();

  // Send GPS characteristic
  char gpsBuffer[64];
  snprintf(gpsBuffer, sizeof(gpsBuffer), "{\"lat\":%.6f,\"lng\":%.6f}", simulatedLat, simulatedLon);
  pGpsChar->setValue(gpsBuffer);
  pGpsChar->notify();
}

void triggerEmergencySos() {
  Serial.println("[EMERGENCY] Physical SOS Button Activated!");
  digitalWrite(PIN_STATUS_LED_RED, HIGH);
  tone(PIN_BUZZER, 2500, 1000); // Alert chime

  // Notify SOS characteristic immediately
  uint8_t sosPayload[1] = { 0x01 };
  pSosChar->setValue(sosPayload, 1);
  pSosChar->notify();

  // Immediately broadcast telemetry packet with sos: true
  sendTelemetryPacket();
}

// -------------------------------------------------------------------------------
// Setup Routine
// -------------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n==================================================");
  Serial.println("Worker Safety Monitoring Wearable Node - ESP32");
  Serial.println("==================================================");

  // Configure I/O pins
  pinMode(PIN_SOS_BUTTON, INPUT_PULLUP);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_STATUS_LED_RED, OUTPUT);
  pinMode(PIN_STATUS_LED_GREEN, OUTPUT);
  pinMode(PIN_STATUS_LED_BLUE, OUTPUT);

  // Attach hardware interrupt for instantaneous SOS trigger
  attachInterrupt(digitalPinToInterrupt(PIN_SOS_BUTTON), handleSosInterrupt, FALLING);

  // Initialize LEDs
  digitalWrite(PIN_STATUS_LED_GREEN, HIGH); // Default Safe
  digitalWrite(PIN_STATUS_LED_RED, LOW);
  digitalWrite(PIN_STATUS_LED_BLUE, LOW);

  // Initialize BLE Device
  BLEDevice::init(DEVICE_NAME);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  // Create Worker Safety Service
  BLEService* pService = pServer->createService(SERVICE_UUID);

  // 1. Telemetry Characteristic
  pTelemetryChar = pService->createCharacteristic(
    CHAR_TELEMETRY_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pTelemetryChar->addDescriptor(new BLE2902());

  // 2. GPS Characteristic
  pGpsChar = pService->createCharacteristic(
    CHAR_GPS_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pGpsChar->addDescriptor(new BLE2902());

  // 3. Battery Characteristic
  pBatteryChar = pService->createCharacteristic(
    CHAR_BATTERY_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pBatteryChar->addDescriptor(new BLE2902());

  // 4. Safety Status Characteristic (Bidirectional)
  pSafetyStatusChar = pService->createCharacteristic(
    CHAR_SAFETY_STATUS_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY
  );
  pSafetyStatusChar->setCallbacks(new SafetyStatusCallbacks());
  pSafetyStatusChar->addDescriptor(new BLE2902());

  // 5. SOS Characteristic
  pSosChar = pService->createCharacteristic(
    CHAR_SOS_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY
  );
  pSosChar->addDescriptor(new BLE2902());

  // Start Service
  pService->start();

  // Start Advertising
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06); // Functions for iPhone connections
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Advertising started. Waiting for Worker mobile app to pair...");
}

// -------------------------------------------------------------------------------
// Main Superloop
// -------------------------------------------------------------------------------
void loop() {
  // Check if hardware SOS interrupt was triggered
  if (sosTriggered) {
    triggerEmergencySos();
    sosTriggered = false; // Reset trigger after notifying
  }

  // Handle periodic telemetry updates when connected
  if (deviceConnected) {
    if (millis() - lastTelemetryMillis >= TELEMETRY_INTERVAL_MS) {
      sendTelemetryPacket();
      lastTelemetryMillis = millis();
    }
  }

  // Handle reconnection management
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // Give Bluetooth stack time to settle
    pServer->startAdvertising();
    Serial.println("[BLE] Re-opened advertising after disconnect.");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  delay(20);
}
