class DeviceModel {
  final String id;
  final String name;
  final int rssi;
  final bool isConnected;
  final int lastSeen;

  const DeviceModel({
    required this.id,
    required this.name,
    this.rssi = -60,
    this.isConnected = false,
    required this.lastSeen,
  });

  factory DeviceModel.fromSqlite(Map<String, dynamic> map) {
    return DeviceModel(
      id: map['device_id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'ESP32 Device',
      rssi: (map['rssi'] as num?)?.toInt() ?? -60,
      isConnected: false,
      lastSeen: (map['last_connected'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toSqliteMap(String workerId) {
    return {
      'device_id': id,
      'worker_id': workerId,
      'name': name,
      'last_connected': lastSeen,
      'rssi': rssi,
    };
  }

  DeviceModel copyWith({
    String? id,
    String? name,
    int? rssi,
    bool? isConnected,
    int? lastSeen,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      isConnected: isConnected ?? this.isConnected,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
