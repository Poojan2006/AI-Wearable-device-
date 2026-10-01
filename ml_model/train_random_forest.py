#!/usr/bin/env python3
"""
Worker Safety Monitoring System - Random Forest Model Training & Exporter
Trains a real scikit-learn RandomForestClassifier on occupational safety telemetry data
and exports the ensemble trees into an on-device Dart evaluation engine and JSON definition.
"""

import json
import os
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score, confusion_matrix

np.random.seed(42)

CLASSES = ["SAFE", "WARNING", "DANGER", "EMERGENCY"]
FEATURE_NAMES = [
    "temperature",
    "heart_rate",
    "spo2",
    "gas_level",
    "humidity",
    "motion",
    "fall_detected",
    "battery"
]

def generate_safety_dataset(n_samples=6000):
    """
    Generates synthetic but physiologically and physically realistic
    industrial telemetry dataset across 4 safety classes.
    """
    samples_per_class = n_samples // 4
    data = []

    # 1. SAFE (Class 0)
    for _ in range(samples_per_class):
        temp = np.random.normal(36.6, 0.4)
        hr = np.random.normal(78, 9)
        spo2 = np.random.normal(98, 1.2)
        gas = np.random.normal(65, 25)
        humidity = np.random.normal(48, 10)
        motion = np.random.choice([0, 1], p=[0.4, 0.6]) # 0=Rest, 1=Active
        fall = 0
        battery = np.random.uniform(25, 100)
        data.append([temp, hr, spo2, gas, humidity, motion, fall, battery, 0])

    # 2. WARNING (Class 1) - Mild stressors or warning levels
    for _ in range(samples_per_class):
        sub_type = np.random.choice(["heat", "tachycardia", "mild_gas", "low_battery", "high_humidity"])
        temp = np.random.normal(36.8, 0.4)
        hr = np.random.normal(82, 8)
        spo2 = np.random.normal(95.5, 1.5)
        gas = np.random.normal(120, 30)
        humidity = np.random.normal(55, 10)
        motion = np.random.choice([0, 1, 2], p=[0.2, 0.6, 0.2])
        fall = 0
        battery = np.random.uniform(20, 95)

        if sub_type == "heat":
            temp = np.random.uniform(37.5, 38.3)
            hr = np.random.uniform(95, 115)
        elif sub_type == "tachycardia":
            hr = np.random.uniform(105, 122)
        elif sub_type == "mild_gas":
            gas = np.random.uniform(180, 320)
        elif sub_type == "low_battery":
            battery = np.random.uniform(6, 14)
        elif sub_type == "high_humidity":
            humidity = np.random.uniform(75, 88)
            temp = np.random.uniform(37.2, 38.0)

        data.append([temp, hr, spo2, gas, humidity, motion, fall, battery, 1])

    # 3. DANGER (Class 2) - Severe toxic gases, acute hypoxia, severe hyper/hypothermia, or fall
    for _ in range(samples_per_class):
        danger_type = np.random.choice(["toxic_gas", "hypoxia", "severe_heat", "fall_detected", "bradycardia"])
        temp = np.random.normal(36.8, 0.5)
        hr = np.random.normal(85, 10)
        spo2 = np.random.normal(96, 1.5)
        gas = np.random.normal(100, 30)
        humidity = np.random.normal(50, 10)
        motion = np.random.choice([0, 1, 2], p=[0.3, 0.4, 0.3])
        fall = 0
        battery = np.random.uniform(10, 90)

        if danger_type == "toxic_gas":
            gas = np.random.uniform(360, 850)
            hr = np.random.uniform(100, 135)
        elif danger_type == "hypoxia":
            spo2 = np.random.uniform(75, 89.5)
            hr = np.random.uniform(105, 140)
        elif danger_type == "severe_heat":
            temp = np.random.uniform(38.6, 40.5)
            hr = np.random.uniform(120, 155)
        elif danger_type == "fall_detected":
            fall = 1
            motion = np.random.choice([0, 2], p=[0.7, 0.3]) # motionless after fall or violent shock
            hr = np.random.uniform(90, 130)
        elif danger_type == "bradycardia":
            hr = np.random.uniform(30, 44)
            temp = np.random.uniform(34.5, 36.0)

        data.append([temp, hr, spo2, gas, humidity, motion, fall, battery, 2])

    # 4. EMERGENCY (Class 3) - Compound catastrophe: toxic gas + hypoxia, fall with immobility, lethal vitals
    for _ in range(samples_per_class):
        temp = np.random.normal(37.0, 1.2)
        hr = np.random.normal(110, 25)
        spo2 = np.random.normal(86, 6)
        gas = np.random.normal(450, 150)
        humidity = np.random.normal(60, 15)
        motion = np.random.choice([0, 2], p=[0.6, 0.4])
        fall = np.random.choice([0, 1], p=[0.3, 0.7])
        battery = np.random.uniform(5, 85)

        # compound scenario
        compound = np.random.choice(["gas_and_unconscious", "fall_and_hypoxia", "extreme_heatstroke"])
        if compound == "gas_and_unconscious":
            gas = np.random.uniform(500, 1200)
            spo2 = np.random.uniform(70, 85)
            motion = 0 # unresponsive
        elif compound == "fall_and_hypoxia":
            fall = 1
            spo2 = np.random.uniform(72, 88)
            motion = 0
            hr = np.random.uniform(130, 160)
        elif compound == "extreme_heatstroke":
            temp = np.random.uniform(40.2, 42.0)
            hr = np.random.uniform(145, 175)
            motion = 0

        data.append([temp, hr, spo2, gas, humidity, motion, fall, battery, 3])

    df = pd.DataFrame(data, columns=FEATURE_NAMES + ["label"])
    
    # Clip to physically realistic bounds
    df["temperature"] = df["temperature"].clip(32.0, 43.0).round(1)
    df["heart_rate"] = df["heart_rate"].clip(25, 200).astype(int)
    df["spo2"] = df["spo2"].clip(60, 100).astype(int)
    df["gas_level"] = df["gas_level"].clip(0, 1500).astype(int)
    df["humidity"] = df["humidity"].clip(10.0, 100.0).round(1)
    df["motion"] = df["motion"].astype(int)
    df["fall_detected"] = df["fall_detected"].astype(int)
    df["battery"] = df["battery"].clip(0, 100).astype(int)
    df["label"] = df["label"].astype(int)

    return df

def serialize_tree(tree, classes_count=4):
    """Recursively serializes an individual sklearn DecisionTree to dict."""
    tree_ = tree.tree_
    nodes = []
    
    for i in range(tree_.node_count):
        left = int(tree_.children_left[i])
        right = int(tree_.children_right[i])
        feature = int(tree_.feature[i])
        threshold = float(tree_.threshold[i])
        # value is shape (1, n_classes)
        value = [float(v) for v in tree_.value[i][0]]
        total_samples = sum(value)
        probs = [v / total_samples if total_samples > 0 else 0.0 for v in value]
        
        nodes.append({
            "id": i,
            "feature": feature,
            "threshold": round(threshold, 4),
            "left": left,
            "right": right,
            "probs": [round(p, 4) for p in probs]
        })
    return nodes

def export_model_to_json(rf, output_path):
    """Exports trained Random Forest to a compact JSON file."""
    ensemble = []
    for tree in rf.estimators_:
        ensemble.append(serialize_tree(tree))
    
    model_data = {
        "model_type": "RandomForestClassifier",
        "n_estimators": len(rf.estimators_),
        "n_classes": len(CLASSES),
        "classes": CLASSES,
        "feature_names": FEATURE_NAMES,
        "trees": ensemble
    }
    
    with open(output_path, "w") as f:
        json.dump(model_data, f, separators=(",", ":"))
    print(f"Exported RF model JSON to {output_path} ({os.path.getsize(output_path)} bytes)")

def export_model_to_dart(rf, output_path):
    """
    Exports the trained Random Forest directly as compiled Dart code.
    This guarantees zero disk asset loading latency and 100% offline autonomy.
    """
    trees_dart = []
    for t_idx, tree in enumerate(rf.estimators_):
        nodes = serialize_tree(tree)
        nodes_code = []
        for n in nodes:
            probs_str = f"[{', '.join(str(p) for p in n['probs'])}]"
            nodes_code.append(
                f"TreeNode(id: {n['id']}, feature: {n['feature']}, threshold: {n['threshold']}, "
                f"left: {n['left']}, right: {n['right']}, probs: {probs_str})"
            )
        trees_dart.append(f"  // Tree {t_idx}\n  [\n    " + ",\n    ".join(nodes_code) + "\n  ]")

    dart_content = f"""// AUTO-GENERATED BY train_random_forest.py
// DO NOT MODIFY DIRECTLY. On-device Random Forest Model for Worker Safety.

class TreeNode {{
  final int id;
  final int feature;
  final double threshold;
  final int left;
  final int right;
  final List<double> probs;

  const TreeNode({{
    required this.id,
    required this.feature,
    required this.threshold,
    required this.left,
    required this.right,
    required this.probs,
  }});

  bool get isLeaf => left == -1 && right == -1;
}}

class CompiledRandomForestModel {{
  static const List<String> featureNames = {json.dumps(FEATURE_NAMES)};
  static const List<String> classes = {json.dumps(CLASSES)};

  static const List<List<TreeNode>> trees = [
{',\n'.join(trees_dart)}
  ];
}}
"""
    with open(output_path, "w") as f:
        f.write(dart_content)
    print(f"Exported compiled Dart Random Forest to {output_path} ({os.path.getsize(output_path)} bytes)")

def main():
    print("=" * 60)
    print("Worker Safety System - Training Random Forest Model")
    print("=" * 60)

    df = generate_safety_dataset(n_samples=8000)
    X = df[FEATURE_NAMES].values
    y = df["label"].values

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    print(f"Dataset summary: {len(df)} total samples.")
    for idx, c in enumerate(CLASSES):
        print(f"  Class {idx} ({c}): {(y == idx).sum()} samples")

    # We train a compact, highly accurate ensemble: 20 trees with max_depth=7
    rf = RandomForestClassifier(
        n_estimators=20,
        max_depth=7,
        min_samples_split=4,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1
    )
    rf.fit(X_train, y_train)

    y_pred = rf.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    print(f"\nModel Accuracy on Test Set: {acc * 100:.2f}%\n")
    print("Classification Report:")
    print(classification_report(y_test, y_pred, target_names=CLASSES))
    print("Confusion Matrix:")
    print(confusion_matrix(y_test, y_pred))

    # Feature Importances
    print("\nFeature Importances:")
    importances = sorted(zip(FEATURE_NAMES, rf.feature_importances_), key=lambda x: x[1], reverse=True)
    for feat, imp in importances:
        print(f"  - {feat:15s}: {imp * 100:5.2f}%")

    # Output paths
    os.makedirs("ml_model/generated", exist_ok=True)
    os.makedirs("mobile_app/lib/services/ml", exist_ok=True)
    os.makedirs("mobile_app/assets/models", exist_ok=True)

    json_path = "mobile_app/assets/models/random_forest_model.json"
    dart_path = "mobile_app/lib/services/ml/compiled_random_forest.dart"

    export_model_to_json(rf, json_path)
    export_model_to_dart(rf, dart_path)

    # Save CSV dataset for offline evaluation/reference
    df.to_csv("ml_model/generated/worker_safety_dataset.csv", index=False)
    print("Saved training dataset to ml_model/generated/worker_safety_dataset.csv")
    print("Training and export complete successfully!")

if __name__ == "__main__":
    main()
