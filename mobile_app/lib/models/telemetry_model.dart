import 'package:uuid/uuid.dart';

class Telemetry {
  final String id;
  final String workerId;
  final String deviceId;
  final double temperature;
  final int heartRate;
  final int spo2;
  final int gasLevel;
  final double humidity;
  final double latitude;
  final double longitude;
  final int battery;
  final String motionStatus; // 'REST', 'ACTIVE', 'SHOCK'
  final bool fallDetected;
  final bool sos;
  final int timestamp;
  final bool synced;
  final int syncAttemptCount;
  final double totalG;
  final String aiStatus;

  Telemetry({
    String? id,
    this.workerId = '',
    this.deviceId = 'ESP32_UNKNOWN',
    this.temperature = 0.0,
    this.heartRate = 0,
    this.spo2 = 0,
    this.gasLevel = 0,
    this.humidity = 0.0,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.battery = 100,
    this.motionStatus = 'ACTIVE',
    this.totalG = 1.0,
    this.fallDetected = false,
    this.sos = false,
    int? timestamp,
    this.synced = false,
    this.syncAttemptCount = 0,
    this.aiStatus = 'SAFE',
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory Telemetry.fromJson(Map<String, dynamic> json, {String? workerIdOverride}) {
    // Robust parser that never crashes on malformed/missing fields
    double parseDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    int parseInt(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? fallback;
    }

    bool parseBool(dynamic val, bool fallback) {
      if (val == null) return fallback;
      if (val is bool) return val;
      if (val is num) return val != 0;
      final s = val.toString().toLowerCase().trim();
      return s == 'true' || s == '1';
    }

    // Determine motion status
    String motion = 'ACTIVE';
    if (json.containsKey('motion')) {
      final m = json['motion'];
      if (m is int) {
        if (m == 0) {
          motion = 'REST';
        } else if (m == 2) {
          motion = 'SHOCK';
        } else {
          motion = 'ACTIVE';
        }
      } else {
        motion = m.toString().toUpperCase();
      }
    } else if (json.containsKey('motionStatus')) {
      motion = json['motionStatus'].toString().toUpperCase();
    }

    // Timestamp handling: ESP32 might send seconds instead of millis
    int ts = parseInt(json['timestamp'], 0);
    if (ts > 0 && ts < 10000000000) {
      ts = ts * 1000; // convert seconds to milliseconds
    } else if (ts <= 0) {
      ts = DateTime.now().millisecondsSinceEpoch;
    }

    return Telemetry(
      id: json['id']?.toString() ?? const Uuid().v4(),
      workerId: workerIdOverride ?? json['workerId']?.toString() ?? '',
      deviceId: json['deviceId']?.toString() ?? 'ESP32_SAFE_01',
      temperature: parseDouble(json['temperature'], 0.0),
      heartRate: parseInt(json['heartRate'], 0),
      spo2: parseInt(json['spo2'], 0),
      gasLevel: parseInt(json['gasLevel'], 0),
      humidity: parseDouble(json['humidity'], 0.0),
      latitude: parseDouble(json['latitude'] ?? json['lat'], 0.0),
      longitude: parseDouble(json['longitude'] ?? json['lng'], 0.0),
      battery: parseInt(json['battery'], 100),
      motionStatus: motion,
      totalG: parseDouble(json['totalG'], 1.0),
      fallDetected: parseBool(json['fallDetected'], false),
      sos: parseBool(json['sos'], false),
      timestamp: ts,
      synced: parseBool(json['synced'], false),
      syncAttemptCount: parseInt(json['syncAttemptCount'], 0),
      aiStatus: json['aiStatus']?.toString() ?? 'SAFE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workerId': workerId,
      'deviceId': deviceId,
      'temperature': temperature,
      'heartRate': heartRate,
      'spo2': spo2,
      'gasLevel': gasLevel,
      'humidity': humidity,
      'latitude': latitude,
      'longitude': longitude,
      'battery': battery,
      'motionStatus': motionStatus,
      'fallDetected': fallDetected,
      'sos': sos,
      'timestamp': timestamp,
      'synced': synced,
      'syncAttemptCount': syncAttemptCount,
      'aiStatus': aiStatus,
    };
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'id': id,
      'workerId': workerId,
      'deviceId': deviceId,
      'temperature': temperature,
      'heartRate': heartRate,
      'spo2': spo2,
      'gasLevel': gasLevel,
      'humidity': humidity,
      'latitude': latitude,
      'longitude': longitude,
      'battery': battery,
      'motionStatus': motionStatus,
      'fallDetected': fallDetected,
      'sos': sos,
      'timestamp': timestamp,
      'aiStatus': aiStatus,
    };
  }

  factory Telemetry.fromSqlite(Map<String, dynamic> map) {
    return Telemetry(
      id: map['id']?.toString(),
      workerId: map['worker_id']?.toString() ?? '',
      deviceId: map['device_id']?.toString() ?? '',
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.0,
      heartRate: (map['heart_rate'] as num?)?.toInt() ?? 0,
      spo2: (map['spo2'] as num?)?.toInt() ?? 0,
      gasLevel: (map['gas_level'] as num?)?.toInt() ?? 0,
      humidity: (map['humidity'] as num?)?.toDouble() ?? 0.0,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      battery: (map['battery'] as num?)?.toInt() ?? 100,
      motionStatus: map['motion_status']?.toString() ?? 'ACTIVE',
      fallDetected: (map['fall_detected'] as num?)?.toInt() == 1,
      sos: (map['sos'] as num?)?.toInt() == 1,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      synced: (map['synced'] as num?)?.toInt() == 1,
      syncAttemptCount: (map['sync_attempt_count'] as num?)?.toInt() ?? 0,
      aiStatus: map['ai_status']?.toString() ?? 'SAFE',
    );
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'worker_id': workerId,
      'device_id': deviceId,
      'temperature': temperature,
      'heart_rate': heartRate,
      'spo2': spo2,
      'gas_level': gasLevel,
      'humidity': humidity,
      'latitude': latitude,
      'longitude': longitude,
      'battery': battery,
      'motion_status': motionStatus,
      'fall_detected': fallDetected ? 1 : 0,
      'sos': sos ? 1 : 0,
      'timestamp': timestamp,
      'synced': synced ? 1 : 0,
      'sync_attempt_count': syncAttemptCount,
      'ai_status': aiStatus,
    };
  }

  Telemetry copyWith({
    String? id,
    String? workerId,
    String? deviceId,
    double? temperature,
    int? heartRate,
    int? spo2,
    int? gasLevel,
    double? humidity,
    double? latitude,
    double? longitude,
    int? battery,
    String? motionStatus,
    bool? fallDetected,
    bool? sos,
    int? timestamp,
    bool? synced,
    int? syncAttemptCount,
    String? aiStatus,
  }) {
    return Telemetry(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      deviceId: deviceId ?? this.deviceId,
      temperature: temperature ?? this.temperature,
      heartRate: heartRate ?? this.heartRate,
      spo2: spo2 ?? this.spo2,
      gasLevel: gasLevel ?? this.gasLevel,
      humidity: humidity ?? this.humidity,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      battery: battery ?? this.battery,
      motionStatus: motionStatus ?? this.motionStatus,
      fallDetected: fallDetected ?? this.fallDetected,
      sos: sos ?? this.sos,
      timestamp: timestamp ?? this.timestamp,
      synced: synced ?? this.synced,
      syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
      aiStatus: aiStatus ?? this.aiStatus,
    );
  }
}
