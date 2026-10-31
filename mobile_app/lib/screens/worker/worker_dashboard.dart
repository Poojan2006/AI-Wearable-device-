import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/ble_service.dart';
import '../../services/ai_prediction_service.dart';
import '../../services/notification_service.dart';
import '../../services/sync_service.dart';
import '../../services/sms_service.dart';
import '../../services/theme_service.dart';

import '../../models/user_model.dart';
import '../../models/telemetry_model.dart';
import '../../models/prediction_result.dart';
import '../../models/alert_model.dart';
import '../../database/local_database.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/safety_status_widget.dart';
import '../../widgets/telemetry_card.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/battery_indicator.dart';
import '../../widgets/deliberate_sos_button.dart';
import '../../widgets/trend_chart.dart';
import '../../widgets/theme_selector_dialog.dart';
import '../auth/login_screen.dart';
import 'device_scan_screen.dart';
import 'worker_history_screen.dart';
import 'emergency_screen.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final BleService _bleService = BleService.instance;
  final AiPredictionService _aiService = AiPredictionService.instance;
  final SyncService _syncService = SyncService.instance;
  final AuthService _authService = AuthService.instance;
  final SmsService _smsService = SmsService.instance;

  StreamSubscription? _telemetrySub;
  StreamSubscription? _sosSub;
  StreamSubscription? _syncCountSub;
  StreamSubscription? _lastSyncSub;
  StreamSubscription? _smsSub;
  StreamSubscription? _bleConnSub;

  AppUser? _user;
  Telemetry? _currentTelemetry;
  PredictionResult _currentPrediction = PredictionResult.safeDefault();
  List<AlertItem> _recentAlerts = [];
  List<Telemetry> _historyList = [];
  bool _isBleConnected = false;
  bool _isOnline = false;
  int _pendingCount = 0;
  DateTime? _lastSyncTime;

  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _user = _authService.currentUser;
    _isBleConnected = _bleService.isConnected;
    _isOnline = _syncService.isOnline;
    _pendingCount = _syncService.pendingCount;
    _lastSyncTime = _syncService.lastSyncTime;

    _setupListeners();
    _loadInitialData();
  }

  void _setupListeners() {
    // 1. Telemetry Stream from ESP32 BLE
    _telemetrySub = _bleService.telemetryStream.listen((telemetry) async {
      debugPrint(
        "[WorkerDashboard] Live BLE packet: HR=${telemetry.heartRate}, SpO2=${telemetry.spo2}, Temp=${telemetry.temperature}, Gas=${telemetry.gasLevel}",
      );

      if (_currentTelemetry == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ Live BLE telemetry connected: ${telemetry.deviceId}",
            ),
            backgroundColor: AppTheme.safeGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Execute 100% On-Device Random Forest Prediction
      final prediction = _aiService.predict(telemetry);

      // Feedback Safety Status back to ESP32 hardware via BLE
      _bleService.writeSafetyStatus(prediction.status);

      // Trigger local sound / notifications and automatic distress SMS if danger, fall or emergency
      if (prediction.status == SafetyStatus.danger ||
          prediction.status == SafetyStatus.emergency ||
          telemetry.fallDetected ||
          telemetry.sos) {
        NotificationService.instance.triggerSafetyAlert(
          status: prediction.status,
          title:
              "⚠️ OCCUPATIONAL SAFETY ALERT: ${prediction.status.toDisplayString()}",
          message: prediction.reason,
        );

        // Automatic cellular SMS to registered supervisor
        _smsService.sendDistressSms(
          workerId: _user?.workerId ?? 'W-104',
          workerName: _user?.name ?? 'Worker',
          condition: telemetry.sos
              ? "EMERGENCY SOS BUTTON ACTIVATED"
              : telemetry.fallDetected
              ? "WORKER FALL DETECTED (ACCELEROMETER SPIKE)"
              : prediction.reason,
          telemetry: telemetry,
        );
      }

      // Record to SQLite & Opportunistic Sync
      await _syncService.recordTelemetry(
        telemetry: telemetry.copyWith(workerId: _user?.workerId ?? 'W-104'),
        prediction: prediction,
        workerName: _user?.name,
      );

      if (mounted) {
        setState(() {
          _currentTelemetry = telemetry;
          _currentPrediction = prediction;
          _isBleConnected = true;
          _historyList.insert(0, telemetry);
          if (_historyList.length > 50) _historyList.removeLast();
        });
      }
    });

    _bleConnSub = _bleService.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isBleConnected = state == BluetoothConnectionState.connected;
          if (!_isBleConnected) {
            _currentTelemetry = null;
          }
        });
      }
    });

    // 2. Hardware SOS Trigger from ESP32
    _sosSub = _bleService.sosStream.listen((isTriggered) {
      if (isTriggered && mounted) {
        _smsService.sendDistressSms(
          workerId: _user?.workerId ?? 'W-104',
          workerName: _user?.name ?? 'Worker',
          condition: "ESP32 Hardware SOS button depressed",
          telemetry: _currentTelemetry,
          force: true,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmergencyScreen(
              workerId: _user?.workerId ?? 'W-104',
              workerName: _user?.name ?? 'Worker',
              initialCause: "ESP32 Hardware SOS button depressed.",
            ),
          ),
        );
      }
    });

    // 3. Online / Offline Stream
    _syncService.isOnlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });

    // 4. Sync queue count stream
    _syncCountSub = _syncService.pendingCountStream.listen((count) {
      if (mounted) setState(() => _pendingCount = count);
    });

    // 5. Last sync timestamp stream
    _lastSyncSub = _syncService.lastSyncTimeStream.listen((time) {
      if (mounted) setState(() => _lastSyncTime = time);
    });

    // 6. SMS dispatch result stream notification
    _smsSub = _smsService.dispatchStream.listen((result) {
      if (mounted && result.success && result.mode != 'SKIPPED_COOLDOWN') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "🚨 Distress SMS sent to Supervisor (${result.recipient})",
            ),
            backgroundColor: AppTheme.safeGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  Future<void> _loadInitialData() async {
    final workerId = _user?.workerId ?? 'W-104';
    final alerts = await LocalDatabase.instance.getRecentAlerts(
      workerId,
      limit: 5,
    );
    final history = await LocalDatabase.instance.getTelemetryHistory(
      workerId,
      limit: 30,
    );

    if (mounted) {
      setState(() {
        _recentAlerts = alerts;
        _historyList = history;
      });
    }
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _sosSub?.cancel();
    _syncCountSub?.cancel();
    _lastSyncSub?.cancel();
    _smsSub?.cancel();
    _bleConnSub?.cancel();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sign Out Confirmation"),
        content: const Text(
          "Are you sure you want to sign out of this device? Offline buffered records will remain safe in SQLite.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
            ),
            child: const Text("SIGN OUT"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _triggerSos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyScreen(
          workerId: _user?.workerId ?? 'W-104',
          workerName: _user?.name ?? 'Worker',
          initialCause: "Deliberate SOS emergency trigger activated.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: AppTheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Good Day, ${_user?.name.split(' ').first ?? 'Worker'}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${_user?.workerId.isNotEmpty == true ? _user!.workerId : 'W-104'} • Edge Active",
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.textSub(context),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "BLE Scanner",
            icon: const Icon(Icons.bluetooth_searching_rounded, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
            ),
          ),
          IconButton(
            tooltip: "Theme",
            icon: Icon(
              AppTheme.isDark(context)
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              size: 20,
            ),
            onPressed: () => ThemeSelectorDialog.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _navIndex,
          children: [
            _buildHomeTab(),
            _buildMonitoringTab(),
            _buildHistoryTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (idx) => setState(() => _navIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: "Overview",
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors_rounded),
            label: "Sensors",
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: "History",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: "Settings",
          ),
        ],
      ),
    );
  }

  // --- TAB 1: OVERVIEW / HOME ---
  Widget _buildHomeTab() {
    final telemetry =
        _currentTelemetry ??
        Telemetry(
          workerId: _user?.workerId ?? 'W-104',
          deviceId: _bleService.connectedDeviceId ?? 'ESP32_SAFE_01',
        );

    final syncTimeStr = _lastSyncTime != null
        ? DateFormat('hh:mm:ss a').format(_lastSyncTime!)
        : 'Pending Sync';

    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderColor = AppTheme.border(context);
    final textSub = AppTheme.textSub(context);

    return RefreshIndicator(
      onRefresh: () async {
        await _syncService.syncPendingRecords();
        await _loadInitialData();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Connection Status Bar (Bluetooth, Internet, Sync Queue)
          ConnectionStatusWidget(
            isBleConnected: _isBleConnected,
            isOnline: _isOnline,
            pendingSyncCount: _pendingCount,
            onBleTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
            ),
            onSyncTap: () => _syncService.syncPendingRecords(),
          ),
          const SizedBox(height: 10),

          // 2. Hardware BLE Node Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isBleConnected
                    ? AppTheme.safeGreen.withAlpha(isDark ? 120 : 80)
                    : AppTheme.warningAmber.withAlpha(isDark ? 120 : 80),
                width: 1.2,
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withAlpha(4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
              ),
              child: Row(
                children: [
                  Icon(
                    _isBleConnected
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_searching_rounded,
                    size: 16,
                    color: _isBleConnected
                        ? AppTheme.safeGreen
                        : AppTheme.warningAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isBleConnected
                          ? (_bleService.connectedDeviceId ?? "ESP32_SAFE_01")
                          : "NO ESP32 CONNECTED • TAP TO SCAN",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: _isBleConnected
                            ? AppTheme.safeGreen
                            : AppTheme.warningAmber,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isBleConnected && _currentTelemetry != null) ...[
                    BatteryIndicator(percentage: _currentTelemetry!.battery),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningAmber.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "PAIR",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.warningAmber,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. AI Safety Prediction Banner
          SafetyStatusWidget(
            status: _currentPrediction.status,
            confidence: _currentPrediction.confidence,
            isLarge: true,
          ),
          const SizedBox(height: 10),

          // 4. On-Device AI Explanation Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _currentPrediction.status == SafetyStatus.safe
                    ? borderColor
                    : _currentPrediction.status.color.withAlpha(100),
                width: 1,
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withAlpha(4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: _currentPrediction.status.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "ON-DEVICE INFERENCE ENGINE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: textSub,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _currentTelemetry == null
                      ? "Waiting for live BLE telemetry stream from ESP32 wearable node..."
                      : _currentPrediction.reason,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textPrimary(context),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5. Deliberate SOS Emergency Button (requires 2s hold to prevent accidental triggers)
          DeliberateSosButton(onTrigger: _triggerSos),
          const SizedBox(height: 14),

          // 6. Live Sensory Telemetry Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "LIVE SENSORY TELEMETRY",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textSub,
                  letterSpacing: 0.8,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _navIndex = 1),
                child: const Text(
                  "DETAILED VIEW →",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2x2 Telemetry Grid
          Row(
            children: [
              Expanded(
                child: TelemetryCard(
                  title: "Heart Rate",
                  value: (_currentTelemetry != null && telemetry.heartRate > 0)
                      ? "${telemetry.heartRate}"
                      : "--",
                  unit: "BPM",
                  icon: Icons.favorite_rounded,
                  accentColor: const Color(0xFFE11D48),
                  statusLabel:
                      (_currentTelemetry != null && telemetry.heartRate > 0)
                      ? (telemetry.heartRate > 100 ? "ELEVATED" : "NORMAL")
                      : "WAITING",
                  progressPercent:
                      (_currentTelemetry != null && telemetry.heartRate > 0)
                      ? (telemetry.heartRate / 160.0).clamp(0.0, 1.0)
                      : 0.0,
                  onTap: () => setState(() => _navIndex = 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TelemetryCard(
                  title: "SpO2 Oxygen",
                  value: (_currentTelemetry != null && telemetry.spo2 > 0)
                      ? "${telemetry.spo2}"
                      : "--",
                  unit: "%",
                  icon: Icons.water_drop_rounded,
                  accentColor: const Color(0xFF0284C7),
                  statusLabel: (_currentTelemetry != null && telemetry.spo2 > 0)
                      ? (telemetry.spo2 < 95 ? "LOW O2" : "OPTIMAL")
                      : "WAITING",
                  progressPercent:
                      (_currentTelemetry != null && telemetry.spo2 > 0)
                      ? (telemetry.spo2 / 100.0).clamp(0.0, 1.0)
                      : 0.0,
                  onTap: () => setState(() => _navIndex = 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TelemetryCard(
                  title: "Temperature",
                  value:
                      (_currentTelemetry != null && telemetry.temperature > 0)
                      ? telemetry.temperature.toStringAsFixed(1)
                      : "--",
                  unit: "°C",
                  icon: Icons.thermostat_rounded,
                  accentColor:
                      (_currentTelemetry != null &&
                          telemetry.temperature > 37.5)
                      ? AppTheme.warningAmber
                      : AppTheme.safeGreen,
                  statusLabel:
                      (_currentTelemetry != null && telemetry.temperature > 0)
                      ? (telemetry.temperature > 37.5
                            ? "HIGH HEAT"
                            : "DHT22 OK")
                      : "WAITING",
                  progressPercent:
                      (_currentTelemetry != null && telemetry.temperature > 0)
                      ? ((telemetry.temperature - 15.0) / 30.0).clamp(0.0, 1.0)
                      : 0.0,
                  onTap: () => setState(() => _navIndex = 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TelemetryCard(
                  title: "Gas Sensor",
                  value: _currentTelemetry != null
                      ? "${telemetry.gasLevel}"
                      : "--",
                  unit: "PPM",
                  icon: Icons.air_rounded,
                  accentColor:
                      _currentTelemetry != null && telemetry.gasLevel > 300
                      ? AppTheme.dangerRed
                      : (_currentTelemetry != null && telemetry.gasLevel > 150
                            ? AppTheme.warningAmber
                            : AppTheme.safeGreen),
                  statusLabel: _currentTelemetry != null
                      ? (telemetry.gasLevel > 300
                            ? "HAZARDOUS"
                            : (telemetry.gasLevel > 150 ? "ELEVATED" : "SAFE"))
                      : "WAITING",
                  progressPercent: _currentTelemetry != null
                      ? (telemetry.gasLevel / 500.0).clamp(0.0, 1.0)
                      : 0.0,
                  onTap: () => setState(() => _navIndex = 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 7. Sync Health & Diagnostic Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, size: 15, color: textSub),
                    const SizedBox(width: 6),
                    Text(
                      "Last Sync: $syncTimeStr",
                      style: TextStyle(
                        color: textSub,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _syncService.syncPendingRecords(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary.withAlpha(
                      isDark ? 40 : 20,
                    ),
                    foregroundColor: AppTheme.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    "SYNC NOW",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 8. Recent Local Alerts
          if (_recentAlerts.isNotEmpty) ...[
            Text(
              "RECENT SAFETY ALERTS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textSub,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            ..._recentAlerts.take(3).map((a) => AlertCard(alert: a)),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- TAB 2: DETAILED SENSORS & TREND VISUALIZATION ---
  Widget _buildMonitoringTab() {
    final telemetry =
        _currentTelemetry ??
        Telemetry(
          workerId: _user?.workerId ?? 'W-104',
          deviceId: _bleService.connectedDeviceId ?? 'ESP32_SAFE_01',
        );

    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderColor = AppTheme.border(context);
    final textSub = AppTheme.textSub(context);

    // Extract historical points from local database buffer
    final hrPoints = _historyList
        .where((t) => t.heartRate > 0)
        .map((t) => t.heartRate.toDouble())
        .toList()
        .reversed
        .toList();

    final tempPoints = _historyList
        .where((t) => t.temperature > 0)
        .map((t) => t.temperature)
        .toList()
        .reversed
        .toList();

    final gasPoints = _historyList
        .where((t) => t.gasLevel > 0)
        .map((t) => t.gasLevel.toDouble())
        .toList()
        .reversed
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ESP32 Buzzer Diagnostic Test Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              if (!_isBleConnected) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "⚠️ ESP32 is not connected! Tap Overview to connect first.",
                    ),
                    backgroundColor: AppTheme.warningAmber,
                  ),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("🔊 Testing ESP32 alert buzzer on GPIO 18..."),
                  backgroundColor: AppTheme.primary,
                  duration: Duration(seconds: 2),
                ),
              );
              await _bleService.testBuzzer();
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.volume_up_rounded,
                    color: AppTheme.infoBlue,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "TEST ESP32 BUZZER ALARM (GPIO 18)",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: AppTheme.infoBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Kinetic Motion & Fall Detection Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "KINETIC POSTURE & FALL ANALYSIS (MPU6050)",
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: textSub,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildKineticCol(
                    icon: Icons.directions_walk_rounded,
                    label: "Motion State",
                    value: _currentTelemetry != null
                        ? telemetry.motionStatus
                        : "WAITING",
                    color: AppTheme.infoBlue,
                  ),
                  Container(width: 1, height: 36, color: borderColor),
                  _buildKineticCol(
                    icon: Icons.personal_injury_rounded,
                    label: "Fall Detection",
                    value: _currentTelemetry != null
                        ? (telemetry.fallDetected ? "FALL SHOCK" : "CLEAR")
                        : "--",
                    color: _currentTelemetry != null && telemetry.fallDetected
                        ? AppTheme.dangerRed
                        : AppTheme.safeGreen,
                  ),
                  Container(width: 1, height: 36, color: borderColor),
                  _buildKineticCol(
                    icon: Icons.sos_rounded,
                    label: "Hardware SOS",
                    value: _currentTelemetry != null
                        ? (telemetry.sos ? "TRIGGERED" : "OFF")
                        : "--",
                    color: _currentTelemetry != null && telemetry.sos
                        ? AppTheme.dangerRed
                        : AppTheme.safeGreen,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Historical Trend Charts (Real historical data from SQLite buffer)
        Text(
          "HISTORICAL SENSOR TRENDS",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: textSub,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        TrendChartCard(
          title: "Heart Rate Trend",
          unit: "BPM",
          dataPoints: hrPoints,
          accentColor: const Color(0xFFE11D48),
          subtitle: "Normal range: 60 - 100 BPM",
        ),
        const SizedBox(height: 12),

        TrendChartCard(
          title: "Ambient Temperature Trend",
          unit: "°C",
          dataPoints: tempPoints,
          accentColor: AppTheme.safeGreen,
          subtitle: "DHT22 environmental tracking",
        ),
        const SizedBox(height: 12),

        TrendChartCard(
          title: "Toxic Gas PPM Trend",
          unit: "PPM",
          dataPoints: gasPoints,
          accentColor: AppTheme.warningAmber,
          subtitle: "MQ Gas Sensor detection over time",
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildKineticCol({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSub(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // --- TAB 3: AUDIT HISTORY ---
  Widget _buildHistoryTab() {
    return WorkerHistoryScreen(workerId: _user?.workerId ?? 'W-104');
  }

  // --- TAB 4: SETTINGS & PROFILE ---
  Widget _buildSettingsTab() {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderColor = AppTheme.border(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textSub = AppTheme.textSub(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Worker Identity Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary.withAlpha(60),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: AppTheme.primary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user?.name ?? 'Alex Rivera',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${_user?.email ?? 'worker@safeguard.io'} • ID: ${_user?.workerId ?? 'W-104'}",
                      style: TextStyle(fontSize: 12, color: textSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          "PREFERENCES & SYSTEM",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: textSub,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        // Visual Theme Switcher Tile
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: AppTheme.primary,
                ),
                title: Text(
                  "Visual Theme Mode",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  ThemeService.instance.themeMode == ThemeMode.light
                      ? "Light Mode (Default)"
                      : (ThemeService.instance.themeMode == ThemeMode.dark
                            ? "Dark Mode"
                            : "System Default"),
                  style: TextStyle(fontSize: 11, color: textSub),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => ThemeSelectorDialog.show(context),
              ),
              Divider(color: borderColor, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.phone_forwarded_rounded,
                  color: AppTheme.safeGreen,
                ),
                title: Text(
                  "Supervisor SMS Contact",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  "${_smsService.supervisorPhone} • ${_smsService.autoSmsEnabled ? 'Auto-SMS Active' : 'Manual'}",
                  style: TextStyle(fontSize: 11, color: textSub),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showEditSupervisorPhoneDialog,
              ),
              Divider(color: borderColor, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.bluetooth_searching_rounded,
                  color: AppTheme.infoBlue,
                ),
                title: Text(
                  "ESP32 BLE Scanner",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  _isBleConnected
                      ? "Connected to ${_bleService.connectedDeviceId}"
                      : "No device connected",
                  style: TextStyle(fontSize: 11, color: textSub),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Sign Out Button
        OutlinedButton.icon(
          onPressed: _handleLogout,
          icon: const Icon(
            Icons.logout_rounded,
            size: 16,
            color: AppTheme.dangerRed,
          ),
          label: const Text(
            "SIGN OUT",
            style: TextStyle(
              color: AppTheme.dangerRed,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: AppTheme.dangerRed.withAlpha(120),
              width: 1.2,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  void _showEditSupervisorPhoneDialog() {
    final controller = TextEditingController(text: _smsService.supervisorPhone);
    bool autoSms = _smsService.autoSmsEnabled;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.phone_forwarded_rounded,
                color: AppTheme.safeGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Supervisor Contact",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "When distress is detected (SOS, fall, or acute danger), the phone transmits an SMS to this number via GSM towers (100% offline from internet).",
                  style: TextStyle(
                    color: AppTheme.textSub(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Supervisor Phone Number",
                    prefixIcon: Icon(Icons.phone_rounded, size: 18),
                    hintText: "+919876543210",
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "Auto-SMS on Distress",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    "Send SMS on SOS, Fall, Toxic Gas & Hypoxia",
                    style: TextStyle(
                      color: AppTheme.textSub(context),
                      fontSize: 11,
                    ),
                  ),
                  value: autoSms,
                  activeThumbColor: AppTheme.safeGreen,
                  onChanged: (val) => setDlgState(() => autoSms = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              onPressed: () async {
                final phone = controller.text.trim();
                if (phone.isNotEmpty) {
                  await _smsService.setSupervisorPhone(phone);
                  await _smsService.setAutoSmsEnabled(autoSms);
                  setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Supervisor SMS contact set to $phone"),
                        backgroundColor: AppTheme.safeGreen,
                      ),
                    );
                  }
                }
              },
              child: const Text("SAVE NUMBER"),
            ),
          ],
        ),
      ),
    );
  }
}
