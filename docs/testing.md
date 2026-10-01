# Comprehensive Testing Strategy & Verification Scenarios

## 1. Test Suite Architecture

The system features an automated 16-scenario verification suite in `mobile_app/test/safety_system_test.dart` and `mobile_app/test/widget_test.dart`.

To execute all tests:
```bash
cd mobile_app
flutter test
```

---

## 2. Verification Scenarios & Results

| # | Test Scenario | Verification Condition | Result |
| :--- | :--- | :--- | :--- |
| **TEST 1** | ESP32 connected, Internet connected | Telemetry streams from BLE, AI infers status, sync queue active | **PASSED** |
| **TEST 2** | ESP32 connected, Internet disconnected | Sensor stream continues, AI infers offline, saved in SQLite `synced=0` | **PASSED** |
| **TEST 3** | ESP32 disconnected, Internet connected | Disconnection state detected, auto-reconnect armed, UI does not crash | **PASSED** |
| **TEST 4** | Bluetooth disabled | Handled gracefully via `BleException` with user warning | **PASSED** |
| **TEST 5** | Firebase unavailable | System falls back to local SQLite session cache without crashing | **PASSED** |
| **TEST 6** | Worker generates SOS without internet | Panic button triggers local siren, saves alert locally with `synced=0` | **PASSED** |
| **TEST 7** | Internet restored after SOS | Offline emergency record uploaded, marked `synced=1` | **PASSED** |
| **TEST 8** | Multiple telemetry records generated offline | 15+ records buffered consecutively in SQLite without data loss | **PASSED** |
| **TEST 9** | Offline records synchronize after internet returns | Batch transitions SQLite rows from `synced=0` to `synced=1` | **PASSED** |
| **TEST 10** | Duplicate synchronization attempt | Idempotency verified: re-syncing records does not create duplicates | **PASSED** |
| **TEST 11** | Worker login | Validates worker role resolution and routing to Worker Dashboard | **PASSED** |
| **TEST 12** | Supervisor login | Validates supervisor role resolution and routing to Supervisor Dashboard | **PASSED** |
| **TEST 13** | Worker attempts supervisor screen | Route boundary privilege checks prevent unauthorized worker access | **PASSED** |
| **TEST 14** | Supervisor views worker | Live fleet stream updates, alert acknowledgment updates status | **PASSED** |
| **TEST 15** | Random Forest prediction without internet | Executes 20-tree traversal in < 1ms with 0 network calls | **PASSED** |
| **TEST 16** | Worker receives DANGER prediction without internet | Toxic gas / hypoxia inputs yield DANGER with grounded explanation | **PASSED** |

---

## 3. Interactive Offline Simulation Lab

The Worker Dashboard contains a dedicated **Offline Test Simulation Lab** widget:
- **Simulate Toxic Gas Spike**: Injects 520 PPM gas telemetry -> Triggers AI DANGER prediction -> Local high-priority notification & haptics.
- **Simulate Worker Fall**: Injects kinetic shock + fall event -> Triggers AI DANGER/EMERGENCY prediction -> Generates local alert.
- **Simulate Hypoxia**: Injects 82% SpO2 -> Triggers AI DANGER prediction -> Alerts worker to vacate confined space.
- **Trigger Emergency SOS**: Large red button -> Opens flashing emergency screen -> Alerts queued for cloud sync.
