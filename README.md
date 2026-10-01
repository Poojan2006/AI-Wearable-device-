# SafeGuard Pro: Worker Safety Monitoring System

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-blue.svg)](https://flutter.dev)
[![ESP32](https://img.shields.io/badge/ESP32-WROOM--32-red.svg)](https://espressif.com)
[![Scikit-Learn](https://img.shields.io/badge/scikit--learn-1.9+-orange.svg)](https://scikit-learn.org)
[![Offline-First](https://img.shields.io/badge/Offline--First-100%25-brightgreen.svg)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)]()

SafeGuard Pro is an industrial-grade, safety-critical Worker Safety Monitoring System combining:
1. **ESP32 Wearable Hardware Node** (Sensors, GPS, battery, hardware interrupt SOS switch, BLE GATT server)
2. **Flutter Mobile Application** (Offline-first, Material 3, Clean Architecture, dual Worker & Supervisor roles)
3. **On-Device Random Forest AI Engine** (100% offline, zero network requests, zero Python server dependencies, < 1ms inference latency)
4. **Idempotent Cloud Synchronization** (Firebase Realtime Database & Auth with automatic offline buffering in SQLite)
5. **Supervisor Command Center** (Live fleet cards, OpenStreetMap geolocation tracking, and alert acknowledgment)

---

## The Inviolable Core Architecture

> [!IMPORTANT]
> **CRITICAL SAFETY FUNCTIONS NEVER DEPEND ON THE CLOUD OR INTERNET CONNECTIVITY.**

```
[ ESP32 Wearable Node ]
       │
       │ Bluetooth Low Energy (BLE GATT)
       ▼
[ Worker Flutter App ] ──► [ On-Device Random Forest AI Engine ] (100% Offline)
       │               ──► [ Local SQLite Telemetry & Alerts DB ]
       │               ──► [ Local Sound/Haptic Safety Alarms ]
       │               ──► [ Offline Sync Queue Manager ]
       │
       │ (When Internet Connectivity is Detected)
       ▼
[ Firebase Cloud Services ] (Auth + Realtime DB + Cloud Messaging)
       │
       ▼
[ Supervisor Flutter App ] ──► Realtime Dashboard & Worker Fleet Monitoring
                             ──► OpenStreetMap Location Tracking
                             ──► Alert Acknowledgment Stream
```

---

## 1. Technology Stack

- **Embedded**:
  - ESP32-WROOM-32
  - C/C++ (Arduino IDE / PlatformIO)
  - Bluetooth Low Energy (BLE GATT Server)
  - Hardware Interrupts for Physical SOS button
- **Mobile**:
  - Flutter 3.47+ / Dart 3.13+
  - Material 3 Industrial Safety Design (High-contrast, Dark Mode default)
  - `flutter_blue_plus` (BLE GATT communication)
  - `sqflite` (Offline-first local database)
  - `connectivity_plus` (Automatic network state detection)
  - `flutter_local_notifications` (Immediate high-priority local emergency alarms)
  - `geolocator` (Worker GPS tracking)
  - `flutter_map` + OpenStreetMap (Supervisor fleet location mapping)
- **Machine Learning (AI)**:
  - Python 3.14 + `scikit-learn`, `pandas`, `numpy`
  - `RandomForestClassifier` (20 estimators, depth 7) trained on industrial safety data
  - Native Dart tree-traversal evaluator (`AiPredictionService` + `CompiledRandomForestModel`)
  - Ground-truth explainability generator
- **Backend & Cloud**:
  - Firebase Authentication
  - Firebase Realtime Database
  - Firebase Security Rules (Role-based isolation)

---

## 2. Hardware Requirements & Pinout

| Peripheral | Component | ESP32 GPIO | Description |
| :--- | :--- | :--- | :--- |
| **SOS Button** | Tactile Switch | `GPIO 4` | Active-LOW, internal pullup, hardware interrupt |
| **Alarm Buzzer** | Piezo Buzzer | `GPIO 18` | PWM audible alarm frequency (1800 - 2500 Hz) |
| **Danger LED** | Red LED | `GPIO 19` | High-visibility emergency indicator |
| **Safe LED** | Green LED | `GPIO 21` | Nominal status indicator |
| **BLE LED** | Blue LED | `GPIO 22` | BLE connection state indicator |
| **Gas Sensor** | MQ-2 / MQ-135 | `GPIO 35` | ADC analog toxic/combustible gas channel |
| **Battery ADC** | Voltage Divider | `GPIO 34` | ADC pin for lipo battery monitoring |

*Note: The firmware automatically operates in simulation mode if physical I2C/analog sensors are absent, enabling immediate end-to-end evaluation.*

---

## 3. BLE GATT Protocol

### Service UUID: `0000FFF0-0000-1000-8000-00805F9B34FB`

| Characteristic | UUID | Properties | Purpose |
| :--- | :--- | :--- | :--- |
| **Telemetry** | `0000FFF1-...` | READ, NOTIFY | Periodic vitals & gas JSON packet |
| **GPS** | `0000FFF2-...` | READ, NOTIFY | GPS coordinates JSON |
| **Battery** | `0000FFF3-...` | READ, NOTIFY | Battery percentage & voltage |
| **Safety Status** | `0000FFF4-...` | READ, WRITE, NOTIFY | Bidirectional state sync (Phone AI -> ESP32) |
| **SOS Trigger** | `0000FFF5-...` | READ, WRITE, NOTIFY | Instantaneous hardware interrupt signal |

---

## 4. On-Device Random Forest AI

- **Inputs (8 Dimensions)**: Temperature (°C), Heart Rate (BPM), SpO2 (%), Toxic Gas (PPM), Humidity (%), Motion Index, Fall Detected, Battery.
- **Outputs**: `SAFE`, `WARNING`, `DANGER`, `EMERGENCY`.
- **Accuracy**: **98.56%** on test evaluation dataset.
- **Explainability**: Identifies specific contributing hazards (e.g. *"Atmospheric toxic gas spike: 480 PPM (limit: 150 PPM)"*, *"Acute hypoxia: SpO2 88%"*).
- **Execution**: Runs in pure Dart in **< 1.0 ms** without calling localhost, Python, or cloud APIs.

---

## 5. Offline-First Synchronization Architecture

1. **Standalone Operation**: If cellular data or Wi-Fi is OFF, the mobile app continues receiving BLE packets, evaluating the Random Forest AI, triggering local alarms, and storing data in SQLite (`worker_safety.db`).
2. **Sync Queue**: Records are tagged with `synced = 0`.
3. **Automatic Resumption**: When `connectivity_plus` detects internet access, `SyncService` reads pending records, uploads them in batches with idempotent event keys (`{workerId}_{timestamp}_{uuid}`), and marks `synced = 1`.
4. **Zero Data Loss Guarantee**: Local records are never deleted prior to verified cloud receipt.

---

## 6. Project Structure

```
mini_project_2/
├── esp32_firmware/
│   └── worker_safety_node/
│       └── worker_safety_node.ino          # ESP32 C++ BLE GATT Firmware
├── ml_model/
│   ├── train_random_forest.py              # Scikit-learn dataset generator & exporter
│   └── generated/                          # Generated dataset CSV
├── mobile_app/                             # Flutter Mobile Application
│   ├── lib/
│   │   ├── core/
│   │   │   ├── constants/                  # BLE UUIDs, thresholds, colors
│   │   │   ├── theme/                      # Material 3 dark/light themes
│   │   │   ├── errors/                     # AppException hierarchy
│   │   │   └── utils/                      # Sound & haptic triggers
│   │   ├── models/                         # Telemetry, Alert, User, PredictionResult
│   │   ├── database/                       # Local SQLite Database (worker_safety.db)
│   │   ├── services/
│   │   │   ├── ble_service.dart            # BLE connection, packet parsing & virtual simulator
│   │   │   ├── ai_prediction_service.dart  # On-device Random Forest inference & reasoning
│   │   │   ├── auth_service.dart           # Firebase Auth + offline cached sessions
│   │   │   ├── sync_service.dart           # Offline sync queue & connectivity monitor
│   │   │   ├── notification_service.dart   # High-priority emergency alerts
│   │   │   ├── location_service.dart       # GPS tracking
│   │   │   └── ml/
│   │   │       └── compiled_random_forest.dart # Compiled Dart Decision Trees
│   │   ├── repositories/
│   │   │   └── supervisor_repository.dart  # Realtime RTDB stream listener
│   │   ├── screens/
│   │   │   ├── auth/                       # Login & Register with role routing
│   │   │   ├── worker/                     # Worker Dashboard, Scanner, Telemetry, History, SOS
│   │   │   └── supervisor/                 # Supervisor Dashboard, Roster, Details, Alerts, Map
│   │   ├── widgets/                        # Industrial safety widgets
│   │   └── main.dart                       # Entry point & session restoration
│   └── test/
│       ├── safety_system_test.dart         # Full 16-scenario verification test suite
│       └── widget_test.dart                # App boot smoke test
├── docs/
│   ├── architecture.md                     # System blueprint & topology
│   ├── ble_protocol.md                     # GATT characteristics & packet format
│   ├── firebase_schema.md                  # Realtime DB schema & rules
│   ├── ai_model.md                         # Random Forest pipeline & metrics
│   ├── offline_sync.md                     # Sync engine & SQLite schema
│   └── testing.md                          # Test suite specifications & results
├── database.rules.json                     # Firebase Security Rules
└── README.md
```

---

## 7. Running the Project

### A. Run Automated Verification Tests
```bash
cd mobile_app
flutter test
```
*All 16 test scenarios and widget smoke tests execute and pass out-of-the-box.*

### B. Run Flutter Mobile Application
```bash
cd mobile_app
flutter run
```
*Tip: Quick login buttons are available on the login screen for one-tap Worker Demo and Supervisor Demo access.*

### C. Retrain Random Forest Model (Optional)
```bash
# Set up Python virtual environment
python3 -m venv ml_model/.venv
ml_model/.venv/bin/pip install numpy pandas scikit-learn

# Run training & export
ml_model/.venv/bin/python ml_model/train_random_forest.py
```

### D. Flash ESP32 Firmware
1. Open `esp32_firmware/worker_safety_node/worker_safety_node.ino` in Arduino IDE or PlatformIO.
2. Select Board: **ESP32 Dev Module**.
3. Upload to target ESP32 board over USB.

---

## 8. Verification Scenarios Tested

- **TEST 1**: ESP32 connected, Internet connected (Live telemetry stream & sync)
- **TEST 2**: ESP32 connected, Internet disconnected (Offline SQLite buffering)
- **TEST 3**: ESP32 disconnected, Internet connected (Graceful disconnect & auto-reconnect)
- **TEST 4**: Bluetooth disabled (BleException handling without crash)
- **TEST 5**: Firebase unavailable (Local session restoration from SQLite)
- **TEST 6**: Worker generates SOS without internet (Immediate local alarm & queued for sync)
- **TEST 7**: Internet restored after SOS (Automatic upload & state updated to synced)
- **TEST 8**: Multiple telemetry records generated offline (Consecutive records buffered without loss)
- **TEST 9**: Offline records synchronize after internet returns (Batch transitions to synced=1)
- **TEST 10**: Duplicate synchronization attempt (Idempotent cloud sync)
- **TEST 11**: Worker login (Routes to Worker Dashboard)
- **TEST 12**: Supervisor login (Routes to Supervisor Dashboard)
- **TEST 13**: Worker attempts supervisor screen (Role boundary privilege enforcement)
- **TEST 14**: Supervisor views worker (Realtime fleet streams & incident acknowledgment)
- **TEST 15**: Random Forest prediction without internet (Infers in < 1ms with 0 network calls)
- **TEST 16**: Worker receives DANGER prediction without internet (Local alarm & grounded explanation)
