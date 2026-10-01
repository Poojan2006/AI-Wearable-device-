# Worker Safety Monitoring System Architecture & Specification Blueprint

## 1. Executive Summary & Design Principles

The Worker Safety Monitoring System provides an industrial-grade, safety-critical architecture designed for hazardous working environments (mining, petrochemical refineries, high-temperature manufacturing, confined spaces). 

### The Inviolable Core Principle
**CRITICAL SAFETY FUNCTIONS NEVER DEPEND ON THE CLOUD OR INTERNET CONNECTIVITY.**

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

## 2. Dual-Role Architecture

| Feature | Worker Role | Supervisor Role |
| :--- | :--- | :--- |
| **Primary Device** | Field Mobile Phone (paired with ESP32) | Tablet / Desktop / Mobile Phone |
| **Offline Capability** | Full standalone functionality (Sensor parsing, Local AI, Alerts, SQLite) | Read-only cached view if offline; live updates when online |
| **BLE Communication** | Connects to ESP32 device via BLE GATT | None (Supervisor monitors remotely via cloud) |
| **AI Inference** | Runs Random Forest locally on real-time telemetry stream | Displays worker AI safety status and diagnostics |
| **Local Alerts** | Audible/vibrational alarms, full-screen emergency modal | Push notifications via FCM & audio chimes |
| **Location** | Device GPS via `geolocator` | Fleet map view via `flutter_map` + OpenStreetMap |
| **Data Synchronization** | Pushes buffered SQLite telemetry & alerts via idempotent sync | Listens to Firebase Realtime DB streams |

---

## 3. BLE GATT Protocol Specification

### Service UUID: `0000FFF0-0000-1000-8000-00805F9B34FB` (Worker Safety Service)

| Characteristic | UUID | Properties | Description / Payload Format |
| :--- | :--- | :--- | :--- |
| **Telemetry** | `0000FFF1-0000-1000-8000-00805F9B34FB` | READ, NOTIFY | JSON packet (temp, heartRate, spo2, gasLevel, humidity, motion, fallDetected, timestamp) |
| **GPS** | `0000FFF2-0000-1000-8000-00805F9B34FB` | READ, NOTIFY | Latitude, longitude, altitude, speed from hardware GPS module |
| **Battery** | `0000FFF3-0000-1000-8000-00805F9B34FB` | READ, NOTIFY | Battery % (0-100), voltage (mV), charging status |
| **Safety Status**| `0000FFF4-0000-1000-8000-00805F9B34FB` | READ, WRITE, NOTIFY | Current device state code (0: SAFE, 1: WARNING, 2: DANGER, 3: EMERGENCY) |
| **SOS Trigger** | `0000FFF5-0000-1000-8000-00805F9B34FB` | READ, WRITE, NOTIFY | Instantaneous hardware SOS button trigger byte (`0x01` = Active, `0x00` = Clear) |

---

## 4. Local SQLite Database Schema (Offline-First)

1. **`users`**:
   - `id TEXT PRIMARY KEY`, `email TEXT`, `name TEXT`, `role TEXT`, `worker_id TEXT`, `cached_at INTEGER`
2. **`telemetry`**:
   - `id TEXT PRIMARY KEY`, `worker_id TEXT`, `device_id TEXT`, `temperature REAL`, `heart_rate INTEGER`, `spo2 INTEGER`, `gas_level INTEGER`, `humidity REAL`, `latitude REAL`, `longitude REAL`, `battery INTEGER`, `motion_status TEXT`, `fall_detected INTEGER`, `sos INTEGER`, `timestamp INTEGER`, `synced INTEGER DEFAULT 0`, `sync_attempt_count INTEGER DEFAULT 0`
3. **`alerts`**:
   - `id TEXT PRIMARY KEY`, `worker_id TEXT`, `type TEXT`, `message TEXT`, `severity TEXT`, `timestamp INTEGER`, `acknowledged INTEGER DEFAULT 0`, `synced INTEGER DEFAULT 0`
4. **`predictions`**:
   - `id TEXT PRIMARY KEY`, `telemetry_id TEXT`, `status TEXT`, `confidence REAL`, `reason TEXT`, `timestamp INTEGER`
5. **`sync_queue`**:
   - `id TEXT PRIMARY KEY`, `record_type TEXT`, `record_id TEXT`, `payload TEXT`, `created_at INTEGER`, `retry_count INTEGER DEFAULT 0`, `status TEXT`
6. **`devices`**:
   - `device_id TEXT PRIMARY KEY`, `worker_id TEXT`, `name TEXT`, `last_connected INTEGER`, `rssi INTEGER`

---

## 5. On-Device Random Forest AI Architecture

- **Training Pipeline**: Python 3 script using `scikit-learn`'s `RandomForestClassifier`.
- **Features (8 dimensions)**:
  1. Temperature (°C)
  2. Heart Rate (BPM)
  3. Oxygen Saturation (SpO2 %)
  4. Gas Concentration (PPM)
  5. Ambient Humidity (% RH)
  6. Motion Index (0: Rest, 1: Active, 2: Violent/Irregular)
  7. Fall Detection Flag (0 or 1)
  8. Battery Level (%)
- **Classes**:
  - `SAFE` (Normal vitals and environment)
  - `WARNING` (Elevated vitals or rising gas levels)
  - `DANGER` (Toxic gas threshold breached, hypoxia SpO2 < 90%, extreme hyperthermia, or fall detected)
  - `EMERGENCY` (Hardware SOS activated or multiple compound danger flags)
- **Deployment Strategy**:
  - The trained forest (n_estimators=20, max_depth=8) is serialized into an optimized Dart model structure / JSON tree hierarchy.
  - The Dart `AiPredictionService` traverses tree decision nodes locally in < 1ms without invoking any external server.
  - Generates transparent, deterministic reason explanations based on feature contributions.

---

## 6. Firebase Realtime Database Structure & Security Rules

```json
{
  "users": {
    "$userId": {
      "name": "Poojan Marneni",
      "email": "worker@safety.io",
      "role": "worker",
      "workerId": "W-104",
      "createdAt": 1727690000000
    }
  },
  "workers": {
    "$workerId": {
      "name": "Poojan Marneni",
      "deviceId": "ESP32_SAFE_01",
      "status": "SAFE",
      "battery": 92,
      "latitude": 17.4485,
      "longitude": 78.3742,
      "lastSeen": 1727690020000,
      "lastUpdated": 1727690020000
    }
  },
  "telemetry": {
    "$workerId": {
      "latest": {
        "temperature": 36.6,
        "heartRate": 78,
        "spo2": 98,
        "gasLevel": 45,
        "humidity": 52.0,
        "battery": 92,
        "aiStatus": "SAFE",
        "timestamp": 1727690020000
      },
      "history": {
        "$eventId": { ... }
      }
    }
  },
  "alerts": {
    "$alertId": {
      "workerId": "W-104",
      "type": "GAS_SPIKE",
      "message": "Dangerous gas concentration detected (420 PPM)",
      "severity": "DANGER",
      "timestamp": 1727690020000,
      "acknowledged": false
    }
  }
}
```
