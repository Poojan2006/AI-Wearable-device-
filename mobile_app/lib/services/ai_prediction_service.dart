import 'dart:math';

import '../models/telemetry_model.dart';
import '../models/prediction_result.dart';
import 'ml/compiled_random_forest.dart';

class AiPredictionService {
  static final AiPredictionService instance = AiPredictionService._internal();

  AiPredictionService._internal();

  /// Executes 100% on-device Random Forest ensemble inference on telemetry.
  /// Zero network calls. Zero Python server. Pure offline Dart computation.
  PredictionResult predict(Telemetry telemetry) {
    // 1. Feature Extraction
    // Features order must match train_random_forest.py:
    // [0: temperature, 1: heart_rate, 2: spo2, 3: gas_level, 4: humidity, 5: motion, 6: fall_detected, 7: battery]
    double motionVal = 1.0; // default active
    if (telemetry.motionStatus == 'REST') motionVal = 0.0;
    if (telemetry.motionStatus == 'SHOCK') motionVal = 2.0;

    // If a sensor is not connected (value 0), substitute nominal baseline
    // so the classifier evaluates the sensors that ARE physically connected (MPU6050, DHT, SOS)
    final double safeTemp = telemetry.temperature > 0
        ? telemetry.temperature
        : 26.5;
    final double safeHeart = telemetry.heartRate > 0
        ? telemetry.heartRate.toDouble()
        : 75.0;
    final double safeSpO2 = telemetry.spo2 > 0
        ? telemetry.spo2.toDouble()
        : 98.0;
    final double safeGas = telemetry.gasLevel > 0
        ? telemetry.gasLevel.toDouble()
        : 45.0;
    final double safeHumidity = telemetry.humidity > 0
        ? telemetry.humidity
        : 50.0;

    final List<double> features = [
      safeTemp,
      safeHeart,
      safeSpO2,
      safeGas,
      safeHumidity,
      motionVal,
      telemetry.fallDetected ? 1.0 : 0.0,
      telemetry.battery.toDouble(),
    ];

    // 2. Ensemble Tree Traversal
    final List<List<TreeNode>> trees = CompiledRandomForestModel.trees;
    final int numTrees = trees.length;
    const int numClasses = 4; // SAFE, WARNING, DANGER, EMERGENCY

    final List<double> accumulatedProbs = List.filled(numClasses, 0.0);

    for (final tree in trees) {
      final List<double> treeProbs = _evaluateTree(tree, features);
      for (int c = 0; c < numClasses; c++) {
        accumulatedProbs[c] += treeProbs[c];
      }
    }

    // 3. Average Probabilities across the Forest
    final List<double> finalProbs = accumulatedProbs
        .map((p) => p / numTrees)
        .toList();

    // 4. ArgMax Class Selection & Model Confidence
    int bestClassIdx = 0;
    double maxProb = -1.0;
    for (int c = 0; c < numClasses; c++) {
      if (finalProbs[c] > maxProb) {
        maxProb = finalProbs[c];
        bestClassIdx = c;
      }
    }

    SafetyStatus predictedStatus;
    switch (bestClassIdx) {
      case 1:
        predictedStatus = SafetyStatus.warning;
        break;
      case 2:
        predictedStatus = SafetyStatus.danger;
        break;
      case 3:
        predictedStatus = SafetyStatus.emergency;
        break;
      case 0:
      default:
        predictedStatus = SafetyStatus.safe;
        break;
    }

    // Hardware SOS override directly escalates to EMERGENCY
    if (telemetry.sos) {
      predictedStatus = SafetyStatus.emergency;
      maxProb = max(maxProb, 0.99);
    }

    // 5. Generate Ground-Truth Feature Explanations
    final factors = _extractContributingFactors(telemetry, predictedStatus);
    final reason = _generateHumanReadableReason(
      predictedStatus,
      factors,
      telemetry,
    );

    final Map<SafetyStatus, double> probMap = {
      SafetyStatus.safe: finalProbs[0],
      SafetyStatus.warning: finalProbs[1],
      SafetyStatus.danger: finalProbs[2],
      SafetyStatus.emergency: finalProbs[3],
    };

    return PredictionResult(
      status: predictedStatus,
      confidence: double.parse(maxProb.toStringAsFixed(3)),
      reason: reason,
      contributingFactors: factors,
      probabilities: probMap,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Traverses a single decision tree from root to leaf node
  List<double> _evaluateTree(List<TreeNode> tree, List<double> features) {
    if (tree.isEmpty) return const [1.0, 0.0, 0.0, 0.0];

    int currentNodeId = 0;

    // Safety guard against infinite loops in malformed trees
    int iterations = 0;
    while (iterations < 64) {
      iterations++;
      final node = tree[currentNodeId];

      if (node.isLeaf) {
        return node.probs;
      }

      final featureVal = features[node.feature];
      if (featureVal <= node.threshold) {
        if (node.left >= 0 && node.left < tree.length) {
          currentNodeId = node.left;
        } else {
          return node.probs;
        }
      } else {
        if (node.right >= 0 && node.right < tree.length) {
          currentNodeId = node.right;
        } else {
          return node.probs;
        }
      }
    }

    return tree[0].probs;
  }

  List<String> _extractContributingFactors(Telemetry t, SafetyStatus status) {
    final List<String> factors = [];

    if (t.sos) {
      factors.add("Hardware SOS emergency button depressed");
    }
    if (t.fallDetected) {
      factors.add(
        "Abrupt gravitational shock / worker fall event confirmed by MPU6050",
      );
    }
    if (t.gasLevel > 0) {
      if (t.gasLevel > 350) {
        factors.add(
          "Atmospheric toxic/combustible gas spike (${t.gasLevel} PPM, limit: 150 PPM)",
        );
      } else if (t.gasLevel > 180) {
        factors.add("Elevated ambient gas concentration (${t.gasLevel} PPM)");
      }
    }

    if (t.spo2 > 0) {
      if (t.spo2 < 90) {
        factors.add(
          "Acute hypoxia: SpO2 critically low (${t.spo2}%, nominal >= 95%)",
        );
      } else if (t.spo2 < 94) {
        factors.add("Borderline oxygen desaturation (${t.spo2}%)");
      }
    }

    if (t.temperature > 0.0) {
      if (t.temperature > 38.5) {
        factors.add(
          "Hyperthermia / Heat stroke condition (${t.temperature.toStringAsFixed(1)}°C)",
        );
      } else if (t.temperature < 35.0) {
        factors.add(
          "Hypothermia alert (${t.temperature.toStringAsFixed(1)}°C)",
        );
      } else if (t.temperature > 37.5) {
        factors.add(
          "Elevated ambient temperature (${t.temperature.toStringAsFixed(1)}°C)",
        );
      }
    }

    if (t.heartRate > 0) {
      if (t.heartRate > 120) {
        factors.add("Severe tachycardia (${t.heartRate} BPM, limit: 100 BPM)");
      } else if (t.heartRate < 45) {
        factors.add("Severe bradycardia (${t.heartRate} BPM)");
      } else if (t.heartRate > 100) {
        factors.add("Elevated cardiac exertion (${t.heartRate} BPM)");
      }
    }

    if (t.humidity > 80.0) {
      factors.add(
        "Extreme atmospheric humidity (${t.humidity.toStringAsFixed(1)}%)",
      );
    }

    if (t.battery < 15) {
      factors.add("Safety device battery critically depleted (${t.battery}%)");
    }

    if (factors.isEmpty && status == SafetyStatus.safe) {
      factors.add(
        "Hardware sensor readings (DHT & MPU6050) are within nominal limits.",
      );
    }

    return factors;
  }

  String _generateHumanReadableReason(
    SafetyStatus status,
    List<String> factors,
    Telemetry telemetry,
  ) {
    if (status == SafetyStatus.safe) {
      return "SAFE: All worker biometrics, posture, and environmental gas levels are stable.";
    }

    final StringBuffer sb = StringBuffer();
    sb.write(
      "${status.toDisplayString()} DETECTED by On-Device Random Forest AI.\n",
    );
    sb.write("Identified contributing hazard indicators:\n");

    for (final factor in factors) {
      sb.write(" • $factor\n");
    }

    if (status == SafetyStatus.emergency) {
      sb.write(
        "IMMEDIATE ACTION: Evacuate worker and dispatch emergency response team.",
      );
    } else if (status == SafetyStatus.danger) {
      sb.write(
        "ACTION REQUIRED: Relocate to designated safe zone immediately.",
      );
    } else {
      sb.write(
        "RECOMMENDED: Monitor telemetry, hydrate, and verify atmospheric ventilation.",
      );
    }

    return sb.toString().trim();
  }
}
