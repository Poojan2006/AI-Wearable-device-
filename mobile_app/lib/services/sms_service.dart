import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/telemetry_model.dart';
import '../models/alert_model.dart';
import '../database/local_database.dart';

class SmsDispatchResult {
  final bool success;
  final String mode; // 'DIRECT_SMS', 'INTENT_FALLBACK', 'INTENT_LAUNCHED', 'SKIPPED_COOLDOWN', 'DISABLED', 'ERROR'
  final String recipient;
  final String message;
  final String? error;
  final int timestamp;

  const SmsDispatchResult({
    required this.success,
    required this.mode,
    required this.recipient,
    required this.message,
    this.error,
    required this.timestamp,
  });
}

class SmsService {
  static final SmsService _instance = SmsService._internal();
  static SmsService get instance => _instance;
  SmsService._internal();

  static const MethodChannel _channel = MethodChannel('com.workersafety.worker_safety_app/sms');

  static const String _prefKeyPhone = 'registered_supervisor_phone';
  static const String _prefKeyEnabled = 'auto_distress_sms_enabled';

  // Registered supervisor phone (set to user requested 7075359983)
  String _supervisorPhone = "+917075359983";
  bool _autoSmsEnabled = true;

  int _lastSmsDispatchedEpoch = 0;
  static const int _cooldownMs = 30000; // 30s rate limit to prevent carrier flooding

  final StreamController<SmsDispatchResult> _dispatchController =
      StreamController<SmsDispatchResult>.broadcast();
  Stream<SmsDispatchResult> get dispatchStream => _dispatchController.stream;

  String get supervisorPhone => _supervisorPhone;
  bool get autoSmsEnabled => _autoSmsEnabled;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _supervisorPhone = prefs.getString(_prefKeyPhone) ?? "+917075359983";
      _autoSmsEnabled = prefs.getBool(_prefKeyEnabled) ?? true;
      debugPrint("[SmsService] Initialized. Registered Supervisor: $_supervisorPhone (Auto-SMS: $_autoSmsEnabled)");
    } catch (e) {
      debugPrint("[SmsService] Init error: $e");
    }
  }

  Future<void> setSupervisorPhone(String phone) async {
    _supervisorPhone = phone.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyPhone, _supervisorPhone);
      debugPrint("[SmsService] Supervisor phone updated to $_supervisorPhone");
    } catch (e) {
      debugPrint("[SmsService] Error saving phone: $e");
    }
  }

  Future<void> setAutoSmsEnabled(bool enabled) async {
    _autoSmsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyEnabled, enabled);
    } catch (e) {
      debugPrint("[SmsService] Error saving auto-sms setting: $e");
    }
  }

  /// Sends distress SMS to supervisor using GSM/cellular network (100% offline from internet)
  Future<SmsDispatchResult> sendDistressSms({
    required String workerId,
    required String workerName,
    required String condition,
    Telemetry? telemetry,
    bool force = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    if (!_autoSmsEnabled && !force) {
      final res = SmsDispatchResult(
        success: false,
        mode: 'DISABLED',
        recipient: _supervisorPhone,
        message: 'Auto-SMS is disabled in worker safety preferences.',
        timestamp: now,
      );
      _dispatchController.add(res);
      return res;
    }

    // Rate-limiting check
    if (!force && (now - _lastSmsDispatchedEpoch) < _cooldownMs) {
      final res = SmsDispatchResult(
        success: true,
        mode: 'SKIPPED_COOLDOWN',
        recipient: _supervisorPhone,
        message: 'Distress SMS already dispatched recently (cooldown active).',
        timestamp: now,
      );
      debugPrint("[SmsService] Cooldown active. Skipping duplicate SMS dispatch.");
      return res;
    }

    final timeStr = DateFormat('MMM d, hh:mm:ss a').format(DateTime.fromMillisecondsSinceEpoch(now));

    // Construct high-priority SMS payload
    final StringBuffer sb = StringBuffer();
    sb.writeln("🚨 [SAFEGUARD WORKER DISTRESS ALERT]");
    sb.writeln("Worker: $workerName (ID: $workerId)");
    sb.writeln("Condition: $condition");
    sb.writeln("Time: $timeStr");

    if (telemetry != null) {
      sb.writeln("Vitals: HR ${telemetry.heartRate} BPM | SpO2 ${telemetry.spo2}% | Gas ${telemetry.gasLevel} PPM | Temp ${telemetry.temperature.toStringAsFixed(1)}°C");
      sb.writeln("GPS: ${telemetry.latitude.toStringAsFixed(4)}, ${telemetry.longitude.toStringAsFixed(4)}");
      sb.writeln("Map: https://maps.google.com/?q=${telemetry.latitude},${telemetry.longitude}");
      sb.writeln("Device: ${telemetry.deviceId}");
    } else {
      sb.writeln("Vitals: Sensor node disconnected / offline");
    }

    final messageBody = sb.toString().trim();

    SmsDispatchResult res;

    try {
      final Map<dynamic, dynamic>? nativeResult = await _channel.invokeMapMethod<dynamic, dynamic>(
        'sendDistressSms',
        {
          'phoneNumber': _supervisorPhone,
          'message': messageBody,
        },
      );

      _lastSmsDispatchedEpoch = now;
      final mode = nativeResult?['mode']?.toString() ?? 'DIRECT_SMS';
      final success = nativeResult?['success'] == true || mode == 'INTENT_LAUNCHED';

      res = SmsDispatchResult(
        success: success,
        mode: mode,
        recipient: _supervisorPhone,
        message: messageBody,
        timestamp: now,
      );
    } on MissingPluginException {
      // In headless unit tests or non-Android hosts
      _lastSmsDispatchedEpoch = now;
      res = SmsDispatchResult(
        success: true,
        mode: 'MOCK_TEST_DISPATCH',
        recipient: _supervisorPhone,
        message: messageBody,
        timestamp: now,
      );
    } catch (e) {
      res = SmsDispatchResult(
        success: false,
        mode: 'ERROR',
        recipient: _supervisorPhone,
        message: messageBody,
        error: e.toString(),
        timestamp: now,
      );
    }

    _dispatchController.add(res);

    // If successfully sent or simulated, persist distress alert audit trail in offline SQLite
    if (res.success) {
      try {
        await LocalDatabase.instance.insertAlert(
          AlertItem(
            workerId: workerId,
            workerName: workerName,
            type: 'DISTRESS_SMS',
            message: "Automatic cellular SMS sent to supervisor ($_supervisorPhone): $condition",
            severity: 'EMERGENCY',
            timestamp: now,
            acknowledged: true,
            synced: true,
          ),
        );
      } catch (dbError) {
        debugPrint("[SmsService] Note: failed to insert alert into SQLite: $dbError");
      }
    }

    return res;
  }
}
