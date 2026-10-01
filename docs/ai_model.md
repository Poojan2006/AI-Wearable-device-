# On-Device Random Forest AI Architecture & Training Pipeline

## 1. Principles
The safety AI system is designed to provide high-reliability, zero-latency inference directly on the worker's mobile phone without internet connectivity, Python servers, or cloud dependencies.

```
[ ESP32 Telemetry ]
        │
        ▼ (Feature Vector: 8 Dimensions)
[ x0: Temp, x1: HR, x2: SpO2, x3: Gas, x4: Humidity, x5: Motion, x6: Fall, x7: Battery ]
        │
        ▼
[ 20-Tree Ensemble Traversal in Dart ] (Compiled Trees in CompiledRandomForestModel)
        │
        ├── Tree 00 -> [P0, P1, P2, P3]
        ├── Tree 01 -> [P0, P1, P2, P3]
        │   ...
        └── Tree 19 -> [P0, P1, P2, P3]
        │
        ▼
[ Average Class Probability Vector ] -> ArgMax
        │
        ▼
PredictionResult(
  status: SafetyStatus.danger,
  confidence: 0.985,
  reason: "DANGER DETECTED by On-Device Random Forest AI...",
  contributingFactors: ["Atmospheric toxic gas spike (480 PPM)..."]
)
```

---

## 2. Feature Dimensions & Physiological Limits

| Feature | Index | Normal Range | Warning Range | Danger Range |
| :--- | :--- | :--- | :--- | :--- |
| **Temperature** | 0 | 36.1 - 37.2 °C | 37.3 - 38.4 °C | > 38.5 °C or < 35.0 °C |
| **Heart Rate** | 1 | 60 - 100 BPM | 101 - 120 BPM | > 120 BPM or < 45 BPM |
| **SpO2 Oxygen** | 2 | 95 - 100 % | 90 - 94 % | < 90 % (Acute Hypoxia) |
| **Toxic Gas PPM** | 3 | 0 - 150 PPM | 151 - 350 PPM | > 350 PPM (Toxic Spike) |
| **Humidity** | 4 | 30 - 65 % | 66 - 80 % | > 80 % |
| **Motion State** | 5 | 1 (Active) | 0 (Rest) | 2 (Violent Impact) |
| **Fall Detected** | 6 | 0 (No Fall) | 0 | 1 (Fall Confirmed) |
| **Battery** | 7 | > 50 % | 15 - 50 % | < 15 % |

---

## 3. Training Results & Metrics

- **Algorithm**: `sklearn.ensemble.RandomForestClassifier`
- **Parameters**: `n_estimators=20, max_depth=7, min_samples_split=4, min_samples_leaf=2`
- **Accuracy on Test Set**: **98.56%**
- **Inference Latency in Dart**: **< 1.0 ms**
- **Memory Footprint**: ~210 KB compiled Dart data structures.

### Feature Importances
1. `SpO2 Oxygen`: 26.05%
2. `Gas Level (PPM)`: 24.77%
3. `Heart Rate`: 19.37%
4. `Fall Detection`: 11.76%
5. `Temperature`: 9.11%
6. `Motion`: 4.71%
7. `Humidity`: 2.14%
8. `Battery`: 2.09%

---

## 4. Retraining the Model

To retrain the model with custom industrial telemetry:
```bash
# Activate virtual environment
source ml_model/.venv/bin/activate

# Execute training script
python ml_model/train_random_forest.py
```
This script automatically regenerates both `mobile_app/assets/models/random_forest_model.json` and the compiled Dart code in `mobile_app/lib/services/ml/compiled_random_forest.dart`.
