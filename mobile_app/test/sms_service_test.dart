import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:worker_safety_app/models/telemetry_model.dart';
import 'package:worker_safety_app/services/sms_service.dart';
import 'package:worker_safety_app/database/local_database.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SmsService.instance.initialize();
  });

  group('Automatic Distress Cellular SMS Service Tests', () {
    test(
      'Initializes with default industrial safety supervisor phone',
      () async {
        expect(SmsService.instance.supervisorPhone, equals('+917075359983'));
        expect(SmsService.instance.autoSmsEnabled, isTrue);
      },
    );

    test(
      'Supervisor phone number and auto-sms toggle can be configured',
      () async {
        await SmsService.instance.setSupervisorPhone('+14155552671');
        await SmsService.instance.setAutoSmsEnabled(false);

        expect(SmsService.instance.supervisorPhone, equals('+14155552671'));
        expect(SmsService.instance.autoSmsEnabled, isFalse);

        // Re-enable for subsequent tests
        await SmsService.instance.setAutoSmsEnabled(true);
        expect(SmsService.instance.autoSmsEnabled, isTrue);
      },
    );

    test(
      'Dispatches distress SMS with complete vital signs and GPS coordinates',
      () async {
        final telemetry = Telemetry(
          workerId: 'W-104',
          temperature: 37.2,
          heartRate: 142,
          spo2: 86,
          gasLevel: 420,
          humidity: 65.0,
          battery: 88,
          motionStatus: 'FALL',
          fallDetected: true,
          sos: true,
          latitude: 37.7749,
          longitude: -122.4194,
          deviceId: 'SAFEGUARD-NODE-04',
        );

        final result = await SmsService.instance.sendDistressSms(
          workerId: 'W-104',
          workerName: 'Alex Rivera',
          condition: 'HARDWARE SOS & FALL DETECTED',
          telemetry: telemetry,
          force: true,
        );

        expect(result.success, isTrue);
        expect(result.recipient, equals('+917075359983'));
        expect(
          result.message,
          contains('🚨 [SAFEGUARD WORKER DISTRESS ALERT]'),
        );
        expect(result.message, contains('Alex Rivera (ID: W-104)'));
        expect(result.message, contains('HARDWARE SOS & FALL DETECTED'));
        expect(result.message, contains('HR 142 BPM'));
        expect(result.message, contains('SpO2 86%'));
        expect(result.message, contains('Gas 420 PPM'));
        expect(
          result.message,
          contains('https://maps.google.com/?q=37.7749,-122.4194'),
        );
        expect(result.message, contains('SAFEGUARD-NODE-04'));
      },
    );

    test('30-second rate limiter prevents SMS flooding during continuous telemetry breaches', () async {
      // First dispatch with force overrides any residual cooldown
      final firstResult = await SmsService.instance.sendDistressSms(
        workerId: 'W-104',
        workerName: 'Alex Rivera',
        condition: 'ACUTE HYPOXIA (SpO2: 84%)',
        force: true,
      );
      expect(firstResult.success, isTrue);

      // Second immediate dispatch without force is debounced to protect carrier limits
      final secondResult = await SmsService.instance.sendDistressSms(
        workerId: 'W-104',
        workerName: 'Alex Rivera',
        condition: 'ACUTE HYPOXIA (SpO2: 83%)',
        force: false,
      );
      expect(secondResult.mode, equals('SKIPPED_COOLDOWN'));

      // Third dispatch with force: true (such as emergency button press) bypasses cooldown
      final thirdResult = await SmsService.instance.sendDistressSms(
        workerId: 'W-104',
        workerName: 'Alex Rivera',
        condition: 'CRITICAL WORKER PANIC SOS',
        force: true,
      );
      expect(thirdResult.mode, isNot('SKIPPED_COOLDOWN'));
      expect(thirdResult.success, isTrue);
    });

    test(
      'Auto-SMS disabled setting skips automated dispatches unless forced',
      () async {
        await SmsService.instance.setAutoSmsEnabled(false);

        final result = await SmsService.instance.sendDistressSms(
          workerId: 'W-104',
          workerName: 'Alex Rivera',
          condition: 'GAS LEAK WARNING',
          force: false,
        );
        expect(result.mode, equals('DISABLED'));
        expect(result.success, isFalse);

        // Restore
        await SmsService.instance.setAutoSmsEnabled(true);
      },
    );

    test(
      'Dispatched distress SMS logs an audit record into SQLite alerts table',
      () async {
        await SmsService.instance.sendDistressSms(
          workerId: 'W-104',
          workerName: 'Alex Rivera',
          condition: 'HIGH CO2 TOXIC THRESHOLD',
          force: true,
        );

        final alerts = await LocalDatabase.instance.getRecentAlerts('W-104');
        final smsAlert = alerts.firstWhere((a) => a.type == 'DISTRESS_SMS');

        expect(smsAlert.workerId, equals('W-104'));
        expect(smsAlert.severity, equals('EMERGENCY'));
        expect(
          smsAlert.message,
          contains('Automatic cellular SMS sent to supervisor'),
        );
      },
    );
  });
}
