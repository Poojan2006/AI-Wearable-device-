# Offline-First Architecture & Synchronization Engine

## 1. Core Principle
In dangerous industrial sites, cellular connectivity is frequently obstructed by subterranean depth, reinforced concrete, or steel framing. The safety monitoring pipeline never halts due to lack of network connectivity.

```
       WORKER DEVICE (OFFLINE)
+------------------------------------+
| Live BLE Telemetry Stream          |
|                 │                  |
|                 ▼                  |
| On-Device Random Forest AI         |
|                 │                  |
|                 ▼                  |
| Local Alarms / Haptics / Siren     |
|                 │                  |
|                 ▼                  |
| SQLite Database (worker_safety.db) |
|   - telemetry (synced = 0)         |
|   - alerts    (synced = 0)         |
+------------------------------------+
                  │
                  │ (Connectivity Restored: connectivity_plus)
                  ▼
         CLOUD DISPATCH ENGINE
+------------------------------------+
| 1. Query pending SQLite records    |
| 2. Push batch to Firebase RTDB     |
| 3. Verify acknowledgment           |
| 4. Update SQLite: synced = 1       |
+------------------------------------+
```

---

## 2. SQLite Database Schema

The local database (`worker_safety.db`) maintains six tables:
1. `users`: Cached authentication session (email, role, workerId) for zero-latency offline boot.
2. `telemetry`: Full time-series telemetry records with `synced INTEGER DEFAULT 0`.
3. `alerts`: Hazard incident log with `acknowledged` and `synced` flags.
4. `predictions`: AI inference output, confidence, and human-readable reasoning logs.
5. `sync_queue`: Idempotent queue buffer for guaranteed delivery.
6. `devices`: Known paired Bluetooth LE peripheral cache.

---

## 3. Synchronization Lifecycle

1. **Detection**: `connectivity_plus` detects transitions between `ConnectivityResult.none` and active connections (`wifi`, `mobile`, `ethernet`).
2. **Locking**: `_isSyncing` mutex prevents duplicate concurrent runs.
3. **Idempotent Keys**: Each upload contains a deterministic key: `{workerId}_{timestamp}_{uuid}`.
4. **Failure Resiliency**: If any single network write times out or fails, the record remains in SQLite with `synced = 0` and its `retry_count` is incremented. Records are never deleted prior to verified cloud receipt.
