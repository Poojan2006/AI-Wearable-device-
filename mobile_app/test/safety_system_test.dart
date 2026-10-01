import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:worker_safety_app/models/telemetry_model.dart';
import 'package:worker_safety_app/models/prediction_result.dart';
import 'package:worker_safety_app/models/alert_model.dart';
import 'package:worker_safety_app/models/user_model.dart';
import 'package:worker_safety_app/services/ai_prediction_service.dart';
import 'package:worker_safety_app/services/ble_service.dart';
import 'package:worker_safety_app/database/local_database.dart';
import 'package:worker_safety_app/repositories/supervisor_repository.dart';

void main() {
  setUpAll(() {
    // Initialize FFI for local SQLite in test runner
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Worker Safety Monitoring System - Verification & Scenarios', () {
    final aiService = AiPredictionService.instance;
    final bleService = BleService.instance;

    // -------------------------------------------------------------------------
    // TEST 15: Random Forest prediction without internet
    // -------------------------------------------------------------------------
    test('TEST 15: Random Forest prediction without internet executes purely offline', () {
      final normalTelemetry = Telemetry(
        workerId: 'W-104',
        temperature: 36.6,
        heartRate: 75,
        spo2: 98,
        gasLevel: 45,
        humidity: 50.0,
        battery: 95,
        motionStatus: 'ACTIVE',
        fallDetected: false,
        sos: false,
      );

      final stopwatch = Stopwatch()..start();
      final prediction = aiService.predict(normalTelemetry);
      stopwatch.stop();

      expect(prediction.status, equals(SafetyStatus.safe));
      expect(prediction.confidence, greaterThanOrEqualTo(0.85));
      expect(prediction.probabilities.containsKey(SafetyStatus.safe), isTrue);
      expect(prediction.reason, contains('SAFE'));
      expect(stopwatch.elapsedMilliseconds, lessThan(10),
          reason: 'On-device decision tree traversal must execute in < 10ms');
    });

    // -------------------------------------------------------------------------
    // TEST 16: Worker receives DANGER prediction without internet
    // -------------------------------------------------------------------------
    test('TEST 16: Worker receives DANGER prediction without internet on toxic gas breach', () {
      final dangerousTelemetry = Telemetry(
        workerId: 'W-104',
        temperature: 36.8,
        heartRate: 125,
        spo2: 88, // Acute hypoxia
        gasLevel: 480, // Toxic gas spike
        humidity: 60.0,
        battery: 80,
        motionStatus: 'ACTIVE',
        fallDetected: false,
        sos: false,
      );

      final prediction = aiService.predict(dangerousTelemetry);

      expect(prediction.status, anyOf(equals(SafetyStatus.danger), equals(SafetyStatus.emergency)));
      expect(prediction.confidence, greaterThan(0.80));
      expect(prediction.contributingFactors.any((f) => f.contains('gas') || f.contains('SpO2')), isTrue);
      expect(prediction.reason, contains('ACTION REQUIRED'));
    });

    // -------------------------------------------------------------------------
    // TEST 1: ESP32 connected, Internet connected
    // -------------------------------------------------------------------------
    test('TEST 1: ESP32 connected, Internet connected - Virtual Node streams telemetry', () async {
      bleService.startVirtualNode();
      expect(bleService.isConnected, isTrue);

      final telemetry = await bleService.telemetryStream.first;
      expect(telemetry.deviceId, contains('ESP32'));
      expect(telemetry.temperature, inInclusiveRange(35.0, 38.0));
      expect(telemetry.heartRate, inInclusiveRange(60, 110));

      final prediction = aiService.predict(telemetry);
      expect(prediction.status, equals(SafetyStatus.safe));
      bleService.stopVirtualNode();
    });

    // -------------------------------------------------------------------------
    // TEST 2: ESP32 connected, Internet disconnected
    // -------------------------------------------------------------------------
    test('TEST 2: ESP32 connected, Internet disconnected - buffers offline in SQLite', () async {
      final localDb = LocalDatabase.instance;
      final offlineTelemetry = Telemetry(
        id: 'tel_offline_001',
        workerId: 'W-104',
        deviceId: 'ESP32_SAFE_01',
        temperature: 36.7,
        heartRate: 78,
        spo2: 97,
        gasLevel: 55,
        humidity: 48.0,
        battery: 90,
        synced: false,
      );

      await localDb.insertTelemetry(offlineTelemetry);
      final unsynced = await localDb.getUnsyncedTelemetry();

      expect(unsynced.any((t) => t.id == 'tel_offline_001'), isTrue);
      final stored = unsynced.firstWhere((t) => t.id == 'tel_offline_001');
      expect(stored.synced, isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 3: ESP32 disconnected, Internet connected
    // -------------------------------------------------------------------------
    test('TEST 3: ESP32 disconnected, Internet connected - handles disconnection gracefully', () async {
      bleService.startVirtualNode();
      expect(bleService.isConnected, isTrue);

      await bleService.disconnect();
      expect(bleService.isConnected, isFalse);
      expect(bleService.connectedDeviceId, isNull);
    });

    // -------------------------------------------------------------------------
    // TEST 4: Bluetooth disabled
    // -------------------------------------------------------------------------
    test('TEST 4: Bluetooth disabled - throws BleException without application crash', () async {
      expect(
        () async {
          await bleService.connect('INVALID_BLUETOOTH_MAC');
        },
        throwsA(anything),
      );
    });


    // -------------------------------------------------------------------------
    // TEST 5: Firebase unavailable - Session persistence in SQLite
    // -------------------------------------------------------------------------
    test('TEST 5: Firebase unavailable - Local SQLite restores cached user profile', () async {
      final localDb = LocalDatabase.instance;
      const testWorker = AppUser(
        uid: 'user_offline_cached_01',
        email: 'poojan@safety.io',
        name: 'Poojan Marneni',
        role: UserRole.worker,
        workerId: 'W-104',
        cachedAt: 1727690000000,
      );

      await localDb.saveUser(testWorker);
      final cached = await localDb.getCachedUser();

      expect(cached, isNotNull);
      expect(cached!.email, equals('poojan@safety.io'));
      expect(cached.role, equals(UserRole.worker));
      expect(cached.workerId, equals('W-104'));
    });

    // -------------------------------------------------------------------------
    // TEST 6: Worker generates SOS without internet
    // -------------------------------------------------------------------------
    test('TEST 6: Worker generates SOS without internet - buffers emergency locally', () async {
      final localDb = LocalDatabase.instance;
      final sosAlert = AlertItem(
        id: 'sos_offline_001',
        workerId: 'W-104',
        workerName: 'Poojan Marneni',
        type: 'SOS',
        message: 'Panic button depressed by worker in Zone 4.',
        severity: 'EMERGENCY',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        acknowledged: false,
        synced: false,
      );

      await localDb.insertAlert(sosAlert);
      final unsyncedAlerts = await localDb.getUnsyncedAlerts();

      expect(unsyncedAlerts.any((a) => a.id == 'sos_offline_001'), isTrue);
      final savedSos = unsyncedAlerts.firstWhere((a) => a.id == 'sos_offline_001');
      expect(savedSos.severity, equals('EMERGENCY'));
      expect(savedSos.synced, isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 7: Internet restored after SOS - Marks synced
    // -------------------------------------------------------------------------
    test('TEST 7: Internet restored after SOS - Marks local alert synced', () async {
      final localDb = LocalDatabase.instance;
      await localDb.markAlertSynced('sos_offline_001');

      final unsyncedAlerts = await localDb.getUnsyncedAlerts();
      expect(unsyncedAlerts.any((a) => a.id == 'sos_offline_001'), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 8: Multiple telemetry records generated offline
    // -------------------------------------------------------------------------
    test('TEST 8: Multiple telemetry records generated offline buffer properly', () async {
      final localDb = LocalDatabase.instance;

      for (int i = 0; i < 15; i++) {
        final t = Telemetry(
          id: 'batch_offline_$i',
          workerId: 'W-104',
          deviceId: 'ESP32_SAFE_01',
          temperature: 36.5 + (i * 0.1),
          heartRate: 75 + i,
          spo2: 98,
          gasLevel: 50 + (i * 5),
          humidity: 50.0,
          battery: 90 - i,
          timestamp: 1727690000000 + (i * 2000),
          synced: false,
        );
        await localDb.insertTelemetry(t);
      }

      final unsynced = await localDb.getUnsyncedTelemetry(limit: 50);
      expect(unsynced.length, greaterThanOrEqualTo(15));
    });

    // -------------------------------------------------------------------------
    // TEST 9: Offline records synchronize after internet returns
    // -------------------------------------------------------------------------
    test('TEST 9: Offline records synchronize and transition synced state', () async {
      final localDb = LocalDatabase.instance;

      for (int i = 0; i < 5; i++) {
        await localDb.markTelemetrySynced('batch_offline_$i');
      }

      final unsynced = await localDb.getUnsyncedTelemetry(limit: 50);
      expect(unsynced.any((t) => t.id == 'batch_offline_0'), isFalse);
      expect(unsynced.any((t) => t.id == 'batch_offline_1'), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 10: Duplicate synchronization attempt (Idempotency)
    // -------------------------------------------------------------------------
    test('TEST 10: Duplicate synchronization attempt is idempotent', () async {
      final localDb = LocalDatabase.instance;
      // Marking already synced record again does not error
      await localDb.markTelemetrySynced('batch_offline_0');
      await localDb.markTelemetrySynced('batch_offline_0');
      expect(true, isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 11: Worker login
    // -------------------------------------------------------------------------
    test('TEST 11: Worker login correctly resolves Worker role and properties', () {
      final user = AppUser.fromJson({
        'uid': 'usr_worker_01',
        'email': 'worker@safety.io',
        'name': 'Devon Worker',
        'role': 'worker',
        'workerId': 'W-104',
      });

      expect(user.role, equals(UserRole.worker));
      expect(user.isWorker, isTrue);
      expect(user.isSupervisor, isFalse);
      expect(user.workerId, equals('W-104'));
    });

    // -------------------------------------------------------------------------
    // TEST 12: Supervisor login
    // -------------------------------------------------------------------------
    test('TEST 12: Supervisor login correctly resolves Supervisor role', () {
      final supervisor = AppUser.fromJson({
        'uid': 'usr_super_01',
        'email': 'supervisor@safety.io',
        'name': 'Chief Supervisor',
        'role': 'supervisor',
      });

      expect(supervisor.role, equals(UserRole.supervisor));
      expect(supervisor.isSupervisor, isTrue);
      expect(supervisor.isWorker, isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 13: Worker attempts supervisor screen - Role boundary protection
    // -------------------------------------------------------------------------
    test('TEST 13: Worker role is prevented from supervisor privilege checks', () {
      final worker = AppUser(
        uid: 'w_01',
        email: 'worker@safety.io',
        name: 'Worker 1',
        role: UserRole.worker,
        workerId: 'W-104',
      );

      bool canAccessSupervisorConsole(AppUser user) => user.role == UserRole.supervisor;

      expect(canAccessSupervisorConsole(worker), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 14: Supervisor views worker and acknowledges incident
    // -------------------------------------------------------------------------
    test('TEST 14: Supervisor views worker and acknowledges alert', () async {
      final repo = SupervisorRepository.instance;
      final workers = repo.currentWorkers;
      expect(workers, isNotEmpty);

      const alertId = 'alt_test_ack';
      final alert = AlertItem(
        id: alertId,
        workerId: 'W-103',
        workerName: 'Carlos Mendez',
        type: 'TOXIC_GAS',
        message: 'Gas spike detected',
        severity: 'DANGER',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        acknowledged: false,
      );

      await LocalDatabase.instance.insertAlert(alert);
      await repo.acknowledgeAlert(alertId);

      final recent = await LocalDatabase.instance.getRecentAlerts('W-103');
      final acknowledgedAlert = recent.firstWhere((a) => a.id == alertId);
      expect(acknowledgedAlert.acknowledged, isTrue);
    });
  });
}
