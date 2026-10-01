import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

enum SafetyStatus {
  safe,
  warning,
  danger,
  emergency;

  static SafetyStatus fromString(String? val) {
    if (val == null) return SafetyStatus.safe;
    switch (val.toUpperCase().trim()) {
      case 'WARNING':
        return SafetyStatus.warning;
      case 'DANGER':
        return SafetyStatus.danger;
      case 'EMERGENCY':
        return SafetyStatus.emergency;
      case 'SAFE':
      default:
        return SafetyStatus.safe;
    }
  }

  String toDisplayString() {
    switch (this) {
      case SafetyStatus.safe:
        return 'SAFE';
      case SafetyStatus.warning:
        return 'WARNING';
      case SafetyStatus.danger:
        return 'DANGER';
      case SafetyStatus.emergency:
        return 'EMERGENCY';
    }
  }

  Color get color {
    switch (this) {
      case SafetyStatus.safe:
        return AppConstants.statusSafeColor;
      case SafetyStatus.warning:
        return AppConstants.statusWarningColor;
      case SafetyStatus.danger:
        return AppConstants.statusDangerColor;
      case SafetyStatus.emergency:
        return AppConstants.statusEmergencyColor;
    }
  }

  IconData get icon {
    switch (this) {
      case SafetyStatus.safe:
        return Icons.verified_user_rounded;
      case SafetyStatus.warning:
        return Icons.warning_amber_rounded;
      case SafetyStatus.danger:
        return Icons.dangerous_rounded;
      case SafetyStatus.emergency:
        return Icons.emergency_rounded;
    }
  }
}

class PredictionResult {
  final SafetyStatus status;
  final double confidence; // Actual model probability between 0.0 and 1.0
  final String reason;
  final List<String> contributingFactors;
  final Map<SafetyStatus, double> probabilities;
  final int timestamp;

  const PredictionResult({
    required this.status,
    required this.confidence,
    required this.reason,
    this.contributingFactors = const [],
    this.probabilities = const {},
    required this.timestamp,
  });

  factory PredictionResult.safeDefault() {
    return PredictionResult(
      status: SafetyStatus.safe,
      confidence: 1.0,
      reason: "All vitals and atmospheric telemetry are within normal OSHA safety standards.",
      contributingFactors: const ["Normal vitals", "Normal gas concentration"],
      probabilities: const {SafetyStatus.safe: 1.0},
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.toDisplayString(),
      'confidence': confidence,
      'reason': reason,
      'contributingFactors': contributingFactors,
      'probabilities': probabilities.map((k, v) => MapEntry(k.toDisplayString(), v)),
      'timestamp': timestamp,
    };
  }

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final status = SafetyStatus.fromString(json['status']?.toString());
    final probsRaw = json['probabilities'] as Map<String, dynamic>?;
    final Map<SafetyStatus, double> probs = {};
    if (probsRaw != null) {
      probsRaw.forEach((k, v) {
        probs[SafetyStatus.fromString(k)] = (v as num).toDouble();
      });
    }

    return PredictionResult(
      status: status,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason']?.toString() ?? 'No explanation available',
      contributingFactors: (json['contributingFactors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      probabilities: probs,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
