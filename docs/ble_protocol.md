# Bluetooth Low Energy (BLE) GATT Protocol Specification

## 1. Overview
The Worker Safety Wearable Node communicates directly with the Worker Mobile Application using standard Bluetooth Low Energy (BLE) GATT protocols. No cellular, Wi-Fi, or internet connection is required for this communication link.

```
+--------------------+                       +----------------------+
| ESP32-WROOM-32     |   BLE 4.2 / 5.0 GATT  | Worker Mobile App    |
| (GATT Server)      | ====================> | (GATT Client)        |
| - Sensors & ADC    |                       | - Local AI Inference |
| - Hardware SOS Pin | <==================== | - SQLite DB          |
+--------------------+   Safety Feedback     +----------------------+
```

---

## 2. UUID Definitions

All characteristics are namespaced under the custom Worker Safety Service UUID:

| Identifier | UUID | Description |
| :--- | :--- | :--- |
| **Service UUID** | `0000FFF0-0000-1000-8000-00805F9B34FB` | Worker Safety Service |
| **Telemetry Characteristic** | `0000FFF1-0000-1000-8000-00805F9B34FB` | Real-time sensor vitals |
| **GPS Characteristic** | `0000FFF2-0000-1000-8000-00805F9B34FB` | Location coordinates |
| **Battery Characteristic** | `0000FFF3-0000-1000-8000-00805F9B34FB` | Battery & power telemetry |
| **Safety Status Characteristic**| `0000FFF4-0000-1000-8000-00805F9B34FB` | Bidirectional state sync |
| **SOS Characteristic** | `0000FFF5-0000-1000-8000-00805F9B34FB` | Hardware panic interrupt |

---

## 3. Characteristics Detail & Packet Payloads

### Characteristic 1: Telemetry (`0000FFF1-...`)
- **Properties**: `READ`, `NOTIFY`
- **Rate**: 0.5 Hz - 1.0 Hz (Every 1000ms - 2000ms)
- **Format**: Compact JSON string (UTF-8)
- **MTU Negotiated**: 256 bytes

```json
{
  "deviceId": "ESP32_SAFE_01",
  "temperature": 36.8,
  "heartRate": 82,
  "spo2": 98,
  "gasLevel": 65,
  "humidity": 52.0,
  "latitude": 17.448500,
  "longitude": 78.374200,
  "battery": 92,
  "fallDetected": false,
  "sos": false,
  "timestamp": 1727690000
}
```

### Characteristic 2: GPS (`0000FFF2-...`)
- **Properties**: `READ`, `NOTIFY`
- **Format**: JSON string
```json
{"lat": 17.448500, "lng": 78.374200}
```

### Characteristic 3: Battery (`0000FFF3-...`)
- **Properties**: `READ`, `NOTIFY`
- **Format**: JSON string
```json
{"battery": 92, "voltage": 4120}
```

### Characteristic 4: Safety Status Feedback (`0000FFF4-...`)
- **Properties**: `READ`, `WRITE`, `NOTIFY`
- **Direction**: Mobile Phone AI -> ESP32 Wearable
- **Format**: Single Byte `uint8_t`

| Code | Value | Meaning | Hardware Action on ESP32 |
| :--- | :--- | :--- | :--- |
| `0x00` | 0 | `SAFE` | Green LED steady, Buzzer OFF |
| `0x01` | 1 | `WARNING` | Amber LED (Red+Green), Buzzer OFF |
| `0x02` | 2 | `DANGER` | Red LED ON, Intermittent Buzzer 1800Hz |
| `0x03` | 3 | `EMERGENCY` | Red LED flashing, Continuous Siren 2500Hz |

### Characteristic 5: Hardware SOS Interrupt (`0000FFF5-...`)
- **Properties**: `READ`, `WRITE`, `NOTIFY`
- **Trigger**: Active-LOW physical push button attached to GPIO 4 with hardware debounce.
- **Payload**: `0x01` upon button press.

---

## 4. Connection Lifecycle & Reconnection State Machine

```
[ Unconnected ] ──(BLE Scan & Match UUID)──► [ Connected ]
       ▲                                            │
       │                                     (Discover Services)
       │                                            ▼
(Auto-Reconnect Periodic Timer)              [ Subscribed to Notifications ]
       ▲                                            │
       │                                     (Stream Packets & Infer AI)
       │                                            ▼
[ Disconnected Event ] ◄──(Signal Drop / Out of Range)
```

1. **Auto Reconnection**: On unexpected disconnection, the mobile app initiates auto-reconnect backoff (every 4 seconds, up to 8 attempts).
2. **Clean Disconnect**: If worker manually disconnects from the UI, auto-reconnection is halted.
