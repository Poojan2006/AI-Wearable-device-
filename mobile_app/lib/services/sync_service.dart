import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/telemetry_model.dart';
import '../models/alert_model.dart';
import '../models/prediction_result.dart';
import '../database/local_database.dart';
import '../core/constants/app_constants.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();

  SyncService._internal() {
    _initConnectivityListener();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;

  bool _isOnline = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  int _pendingCount = 0;

  final _isOnlineController = StreamController<bool>.broadcast();
  final _pendingCountController = StreamController<int>.broadcast();
  final _lastSyncTimeController = StreamController<DateTime?>.broadcast();

  Stream<bool> get isOnlineStream => _isOnlineController.stream;
  Stream<int> get pendingCountStream => _pendingCountController.stream;
  Stream<DateTime?> get lastSyncTimeStream => _lastSyncTimeController.stream;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get pendingCount => _pendingCount;

  void _initConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((results) async {
      final hasConnection = results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet,
      );

      _isOnline = hasConnection;
      _isOnlineController.add(_isOnline);

      if (_isOnline) {
        // Internet became available -> automatically trigger queue sync!
        await syncPendingRecords();
      }
    });

    // Check initial connectivity
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet,
      );
      _isOnlineController.add(_isOnline);
      await refreshPendingCount();
    } catch (_) {}
  }

  Future<void> refreshPendingCount() async {
    try {
      _pendingCount = await LocalDatabase.instance.getPendingSyncCount();
      _pendingCountController.add(_pendingCount);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Record Telemetry (Offline-First Pipeline)
  // ---------------------------------------------------------------------------
  Future<void> recordTelemetry({
    required Telemetry telemetry,
    required PredictionResult prediction,
    String? workerName,
  }) async {
    // 1. Always save to local SQLite first
    final telemetryWithAi = telemetry.copyWith(
      aiStatus: prediction.status.toDisplayString(),
    );
    await LocalDatabase.instance.insertTelemetry(telemetryWithAi);
    await LocalDatabase.instance.insertPrediction(telemetry.id, prediction);

    // 2. If warning or higher, automatically generate and store alert
    if (prediction.status != SafetyStatus.safe) {
      String alertType = 'ANOMALY';
      if (telemetry.sos) {
        alertType = 'SOS';
      } else if (telemetry.fallDetected) {
        alertType = 'FALL_DETECTED';
      } else if (telemetry.gasLevel > 350) {
        alertType = 'TOXIC_GAS';
      } else if (telemetry.spo2 < 90) {
        alertType = 'HYPOXIA';
      } else if (telemetry.temperature > 38.5) {
        alertType = 'HIGH_TEMP';
      }

      final alert = AlertItem(
        workerId: telemetry.workerId,
        workerName: workerName ?? 'Worker',
        type: alertType,
        message: prediction.reason,
        severity: prediction.status.toDisplayString(),
        timestamp: telemetry.timestamp,
        acknowledged: false,
        synced: false,
      );

      await recordAlert(alert);
    }

    await refreshPendingCount();

    // 3. If online, attempt immediate sync
    if (_isOnline) {
      unawaited(syncPendingRecords());
    }
  }

  // ---------------------------------------------------------------------------
  // Record Alert (Offline-First Pipeline)
  // ---------------------------------------------------------------------------
  Future<void> recordAlert(AlertItem alert) async {
    await LocalDatabase.instance.insertAlert(alert);
    await refreshPendingCount();

    if (_isOnline) {
      unawaited(syncPendingRecords());
    }
  }

  // ---------------------------------------------------------------------------
  // Cloud Synchronization Engine
  // ---------------------------------------------------------------------------
  Future<void> syncPendingRecords() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      if (Firebase.apps.isEmpty) {
        _isSyncing = false;
        return;
      }

      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: AppConstants.rtdbUrl,
      );

      // 1. Sync pending telemetry records
      final unsyncedTelemetry = await LocalDatabase.instance
          .getUnsyncedTelemetry(limit: 40);

      for (final t in unsyncedTelemetry) {
        try {
          final workerKey = t.workerId.isNotEmpty
              ? t.workerId
              : 'UNKNOWN_WORKER';
          final eventId = '${workerKey}_${t.timestamp}_${t.id.substring(0, 6)}';

          final telemetryData = {
            ...t.toFirebaseMap(),
            'eventId': eventId,
            'serverSyncTimestamp': ServerValue.timestamp,
          };

          // Update latest telemetry for supervisor live stream
          await db
              .ref('${AppConstants.rtdbTelemetry}/$workerKey/latest')
              .update(telemetryData);

          // Append to history log
          await db
              .ref('${AppConstants.rtdbTelemetry}/$workerKey/history/$eventId')
              .set(telemetryData);

          // Update worker fleet status
          await db.ref('${AppConstants.rtdbWorkers}/$workerKey').update({
            'status': t.aiStatus,
            'deviceId': t.deviceId,
            'battery': t.battery,
            'latitude': t.latitude,
            'longitude': t.longitude,
            'lastSeen': ServerValue.timestamp,
            'lastUpdated': t.timestamp,
          });

          // Mark local record as successfully synced
          await LocalDatabase.instance.markTelemetrySynced(t.id);
        } catch (_) {
          // If a single record fails, keep in queue and continue
        }
      }

      // 2. Sync pending alerts
      final unsyncedAlerts = await LocalDatabase.instance.getUnsyncedAlerts(
        limit: 20,
      );

      for (final a in unsyncedAlerts) {
        try {
          final alertData = {
            ...a.toFirebaseMap(),
            'serverSyncTimestamp': ServerValue.timestamp,
          };

          await db.ref('${AppConstants.rtdbAlerts}/${a.id}').set(alertData);
          await LocalDatabase.instance.markAlertSynced(a.id);
        } catch (_) {}
      }

      _lastSyncTime = DateTime.now();
      _lastSyncTimeController.add(_lastSyncTime);
    } catch (_) {
    } finally {
      _isSyncing = false;
      await refreshPendingCount();
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _isOnlineController.close();
    _pendingCountController.close();
    _lastSyncTimeController.close();
  }
}
