# Firebase Realtime Database Schema & Security Architecture

## 1. Database Schema Overview

The system uses Firebase Realtime Database to provide high-speed synchronization between worker devices and the supervisor dashboard when internet connectivity is available.

```
/
├── users/
│   └── {userId}/
│       ├── name: string
│       ├── email: string
│       ├── role: "worker" | "supervisor"
│       ├── workerId: string (e.g. "W-104")
│       └── createdAt: timestamp
│
├── workers/
│   └── {workerId}/
│       ├── name: string
│       ├── deviceId: string
│       ├── status: "SAFE" | "WARNING" | "DANGER" | "EMERGENCY"
│       ├── battery: number (0-100)
│       ├── latitude: number
│       ├── longitude: number
│       ├── lastSeen: timestamp
│       └── lastUpdated: timestamp
│
├── telemetry/
│   └── {workerId}/
│       ├── latest/
│       │   ├── temperature: number
│       │   ├── heartRate: number
│       │   ├── spo2: number
│       │   ├── gasLevel: number
│       │   ├── humidity: number
│       │   ├── latitude: number
│       │   ├── longitude: number
│       │   ├── battery: number
│       │   ├── motionStatus: string
│       │   ├── fallDetected: boolean
│       │   ├── sos: boolean
│       │   ├── aiStatus: string
│       │   ├── eventId: string
│       │   └── timestamp: number
│       │
│       └── history/
│           └── {eventId}/ (e.g. "W-104_1727690020000_a1b2c3")
│               └── [Snapshot matching latest]
│
├── alerts/
│   └── {alertId}/
│       ├── workerId: string
│       ├── workerName: string
│       ├── type: "SOS" | "FALL_DETECTED" | "TOXIC_GAS" | "HYPOXIA" | "HIGH_TEMP"
│       ├── message: string
│       ├── severity: "WARNING" | "DANGER" | "EMERGENCY"
│       ├── timestamp: number
│       └── acknowledged: boolean
│
└── devices/
    └── {deviceId}/
        ├── workerId: string
        ├── status: string
        └── lastSeen: timestamp
```

---

## 2. Idempotency & Conflict Resolution

- Every telemetry snapshot generates a deterministic unique key: `{workerId}_{timestamp}_{uuidShort}`.
- Telemetry pushes to both `telemetry/{workerId}/latest` (for instant supervisor gauge updates) and `telemetry/{workerId}/history/{eventId}` (for temporal auditing).
- Even if a network disconnect occurs mid-batch, re-transmitting the batch will simply overwrite with identical keys without creating duplicate historical rows.

---

## 3. Security Rules Summary

1. **Role Enforcement**: Stored in `users/{uid}/role`.
2. **Worker Isolation**: A worker account can only write their own telemetry and alerts, and cannot view or alter other workers' data.
3. **Supervisor Privileges**: Supervisors have read permissions over the entire fleet, and write access only to update incident acknowledgments (`acknowledged: true`).
