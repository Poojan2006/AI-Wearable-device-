import 'package:uuid/uuid.dart';

class SyncQueueItem {
  final String id;
  final String recordType; // 'telemetry', 'alert', 'sos'
  final String recordId;
  final String payload; // Serialized JSON payload
  final int createdAt;
  final int retryCount;
  final String status; // 'PENDING', 'IN_FLIGHT', 'FAILED'

  SyncQueueItem({
    String? id,
    required this.recordType,
    required this.recordId,
    required this.payload,
    int? createdAt,
    this.retryCount = 0,
    this.status = 'PENDING',
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  factory SyncQueueItem.fromSqlite(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id']?.toString() ?? const Uuid().v4(),
      recordType: map['record_type']?.toString() ?? 'telemetry',
      recordId: map['record_id']?.toString() ?? '',
      payload: map['payload']?.toString() ?? '{}',
      createdAt: (map['created_at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      status: map['status']?.toString() ?? 'PENDING',
    );
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'record_type': recordType,
      'record_id': recordId,
      'payload': payload,
      'created_at': createdAt,
      'retry_count': retryCount,
      'status': status,
    };
  }

  SyncQueueItem copyWith({
    String? id,
    String? recordType,
    String? recordId,
    String? payload,
    int? createdAt,
    int? retryCount,
    String? status,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      recordType: recordType ?? this.recordType,
      recordId: recordId ?? this.recordId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
    );
  }
}
