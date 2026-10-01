import 'package:uuid/uuid.dart';

class AlertItem {
  final String id;
  final String workerId;
  final String workerName;
  final String type; // 'SOS', 'FALL_DETECTED', 'TOXIC_GAS', 'HYPOXIA', 'EXTREME_TEMP'
  final String message;
  final String severity; // 'WARNING', 'DANGER', 'EMERGENCY'
  final int timestamp;
  final bool acknowledged;
  final bool synced;

  AlertItem({
    String? id,
    required this.workerId,
    this.workerName = 'Worker',
    required this.type,
    required this.message,
    required this.severity,
    int? timestamp,
    this.acknowledged = false,
    this.synced = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory AlertItem.fromJson(Map<String, dynamic> json, {String? id}) {
    return AlertItem(
      id: id ?? json['id']?.toString() ?? const Uuid().v4(),
      workerId: json['workerId']?.toString() ?? '',
      workerName: json['workerName']?.toString() ?? 'Worker',
      type: json['type']?.toString() ?? 'ALERT',
      message: json['message']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'WARNING',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      acknowledged: json['acknowledged'] == true || json['acknowledged'] == 1,
      synced: json['synced'] == true || json['synced'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workerId': workerId,
      'workerName': workerName,
      'type': type,
      'message': message,
      'severity': severity,
      'timestamp': timestamp,
      'acknowledged': acknowledged,
      'synced': synced,
    };
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'id': id,
      'workerId': workerId,
      'workerName': workerName,
      'type': type,
      'message': message,
      'severity': severity,
      'timestamp': timestamp,
      'acknowledged': acknowledged,
    };
  }

  factory AlertItem.fromSqlite(Map<String, dynamic> map) {
    return AlertItem(
      id: map['id']?.toString(),
      workerId: map['worker_id']?.toString() ?? '',
      workerName: map['worker_name']?.toString() ?? 'Worker',
      type: map['type']?.toString() ?? 'ALERT',
      message: map['message']?.toString() ?? '',
      severity: map['severity']?.toString() ?? 'WARNING',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      acknowledged: (map['acknowledged'] as num?)?.toInt() == 1,
      synced: (map['synced'] as num?)?.toInt() == 1,
    );
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'worker_id': workerId,
      'worker_name': workerName,
      'type': type,
      'message': message,
      'severity': severity,
      'timestamp': timestamp,
      'acknowledged': acknowledged ? 1 : 0,
      'synced': synced ? 1 : 0,
    };
  }

  AlertItem copyWith({
    String? id,
    String? workerId,
    String? workerName,
    String? type,
    String? message,
    String? severity,
    int? timestamp,
    bool? acknowledged,
    bool? synced,
  }) {
    return AlertItem(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      type: type ?? this.type,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      acknowledged: acknowledged ?? this.acknowledged,
      synced: synced ?? this.synced,
    );
  }
}
