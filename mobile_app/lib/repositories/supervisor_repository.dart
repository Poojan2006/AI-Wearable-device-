import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/telemetry_model.dart';
import '../models/alert_model.dart';
import '../core/constants/app_constants.dart';
import '../database/local_database.dart';

class FleetWorker {
  final String workerId;
  final String name;
  final String deviceId;
  final String status; // 'SAFE', 'WARNING', 'DANGER', 'EMERGENCY'
  final int battery;
  final double latitude;
  final double longitude;
  final int lastSeen;
  final int lastUpdated;

  FleetWorker({
    required this.workerId,
    required this.name,
    this.deviceId = 'ESP32_SAFE_01',
    this.status = 'SAFE',
    this.battery = 90,
    this.latitude = 17.4485,
    this.longitude = 78.3742,
    required this.lastSeen,
    required this.lastUpdated,
  });

  factory FleetWorker.fromMap(String id, Map<dynamic, dynamic> map) {
    return FleetWorker(
      workerId: id,
      name: map['name']?.toString() ?? 'Worker $id',
      deviceId: map['deviceId']?.toString() ?? 'ESP32_SAFE_01',
      status: map['status']?.toString() ?? 'SAFE',
      battery: (map['battery'] as num?)?.toInt() ?? 85,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 17.4485,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 78.3742,
      lastSeen:
          (map['lastSeen'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      lastUpdated:
          (map['lastUpdated'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class SupervisorRepository {
  static final SupervisorRepository instance = SupervisorRepository._internal();

  SupervisorRepository._internal() {
    _initRealtimeListeners();
  }

  StreamSubscription? _workersSub;
  StreamSubscription? _alertsSub;

  final _workersController = StreamController<List<FleetWorker>>.broadcast();
  final _alertsController = StreamController<List<AlertItem>>.broadcast();

  Stream<List<FleetWorker>> get workersStream => _workersController.stream;
  Stream<List<AlertItem>> get alertsStream => _alertsController.stream;

  List<FleetWorker> _cachedWorkers = [];
  List<AlertItem> _cachedAlerts = [];

  List<FleetWorker> get currentWorkers => _cachedWorkers;
  List<AlertItem> get currentAlerts => _cachedAlerts;

  void _initRealtimeListeners() {
    if (Firebase.apps.isEmpty) {
      _loadOfflineOrDemoFleet();
      return;
    }

    try {
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: AppConstants.rtdbUrl,
      );

      // 1. Listen to Realtime Database Workers node
      _workersSub = db
          .ref(AppConstants.rtdbWorkers)
          .onValue
          .listen(
            (event) {
              if (event.snapshot.exists && event.snapshot.value is Map) {
                final data = event.snapshot.value as Map<dynamic, dynamic>;
                final List<FleetWorker> workers = [];
                data.forEach((key, val) {
                  if (val is Map) {
                    workers.add(FleetWorker.fromMap(key.toString(), val));
                  }
                });
                _cachedWorkers = workers;
                _workersController.add(workers);
              } else {
                _loadOfflineOrDemoFleet();
              }
            },
            onError: (_) {
              _loadOfflineOrDemoFleet();
            },
          );

      // 2. Listen to Realtime Database Alerts node
      _alertsSub = db
          .ref(AppConstants.rtdbAlerts)
          .onValue
          .listen(
            (event) {
              if (event.snapshot.exists && event.snapshot.value is Map) {
                final data = event.snapshot.value as Map<dynamic, dynamic>;
                final List<AlertItem> alerts = [];
                data.forEach((key, val) {
                  if (val is Map) {
                    final map = Map<String, dynamic>.from(val);
                    alerts.add(AlertItem.fromJson(map, id: key.toString()));
                  }
                });
                // Sort descending by timestamp
                alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                _cachedAlerts = alerts;
                _alertsController.add(alerts);
              } else {
                _loadOfflineAlerts();
              }
            },
            onError: (_) {
              _loadOfflineAlerts();
            },
          );
    } catch (_) {
      _loadOfflineOrDemoFleet();
    }
  }

  void _loadOfflineOrDemoFleet() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _cachedWorkers = [
      FleetWorker(
        workerId: 'W-104',
        name: 'Poojan Marneni',
        deviceId: 'ESP32_SAFE_01',
        status: 'SAFE',
        battery: 100,
        latitude: 17.4501,
        longitude: 78.3739,
        lastSeen: now,
        lastUpdated: now,
      ),
    ];
    _workersController.add(_cachedWorkers);

    _loadOfflineAlerts();
  }

  void _loadOfflineAlerts() async {
    try {
      final localAlerts = await LocalDatabase.instance.getRecentAlerts(
        '',
        limit: 30,
      );
      _cachedAlerts = localAlerts;
      _alertsController.add(localAlerts);
    } catch (_) {
      _cachedAlerts = [];
      _alertsController.add([]);
    }
  }

  Stream<Telemetry?> getWorkerTelemetryStream(String workerId) {
    if (Firebase.apps.isEmpty) {
      return Stream.value(null);
    }

    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: AppConstants.rtdbUrl,
    )
        .ref('${AppConstants.rtdbTelemetry}/$workerId/latest')
        .onValue
        .map((event) {
          if (event.snapshot.exists && event.snapshot.value is Map) {
            final map = Map<String, dynamic>.from(event.snapshot.value as Map);
            return Telemetry.fromJson(map);
          }
          return null;
        });
  }

  Future<void> acknowledgeAlert(String alertId) async {
    // 1. Update in local SQLite
    await LocalDatabase.instance.acknowledgeAlert(alertId);

    // 2. Update in Firebase Realtime DB if available
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: AppConstants.rtdbUrl,
        )
            .ref('${AppConstants.rtdbAlerts}/$alertId')
            .update({'acknowledged': true});
      } catch (_) {}
    }

    // 3. Update cached state locally
    final idx = _cachedAlerts.indexWhere((a) => a.id == alertId);
    if (idx >= 0) {
      _cachedAlerts[idx] = _cachedAlerts[idx].copyWith(acknowledged: true);
      _alertsController.add(List.from(_cachedAlerts));
    }
  }

  void dispose() {
    _workersSub?.cancel();
    _alertsSub?.cancel();
    _workersController.close();
    _alertsController.close();
  }
}
