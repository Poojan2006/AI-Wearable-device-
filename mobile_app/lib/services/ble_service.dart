import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../models/telemetry_model.dart';
import '../models/prediction_result.dart';
import '../models/device_model.dart';

class BleService {
  static final BleService instance = BleService._internal();

  BleService._internal() {
    _initBluetoothListeners();
  }

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _telemetryChar;
  BluetoothCharacteristic? _gpsChar;
  BluetoothCharacteristic? _batteryChar;
  BluetoothCharacteristic? _safetyStatusChar;
  BluetoothCharacteristic? _sosChar;

  StreamSubscription? _connectionSub;
  StreamSubscription? _telemetrySub;
  StreamSubscription? _sosSub;
  StreamSubscription? _batterySub;
  StreamSubscription? _gpsSub;

  bool _isAutoReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 8;
  Timer? _reconnectTimer;

  // Virtual Node Simulation for hardware-free testing
  bool _isVirtualNodeActive = false;
  Timer? _virtualNodeTimer;

  // Stream Controllers
  final _telemetryController = StreamController<Telemetry>.broadcast();
  final _sosController = StreamController<bool>.broadcast();
  final _batteryController = StreamController<int>.broadcast();
  final _gpsController = StreamController<Map<String, double>>.broadcast();
  final _connectionStateController =
      StreamController<BluetoothConnectionState>.broadcast();
  final _devicesListController = StreamController<List<DeviceModel>>.broadcast();

  // Public Streams
  Stream<Telemetry> get telemetryStream => _telemetryController.stream;
  Stream<bool> get sosStream => _sosController.stream;
  Stream<int> get batteryStream => _batteryController.stream;
  Stream<Map<String, double>> get gpsStream => _gpsController.stream;
  Stream<BluetoothConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<List<DeviceModel>> get devicesListStream =>
      _devicesListController.stream;

  // Public State Getters
  bool get isConnected =>
      _connectedDevice != null || _isVirtualNodeActive;
  bool get isVirtualNodeActive => _isVirtualNodeActive;
  String? get connectedDeviceId =>
      _isVirtualNodeActive ? 'ESP32_SIMULATED_01' : _connectedDevice?.remoteId.str;
  String? get connectedDeviceName =>
      _isVirtualNodeActive ? 'ESP32_SAFE_01 (Virtual)' : (_connectedDevice?.platformName.isNotEmpty == true ? _connectedDevice!.platformName : 'ESP32 Safe Node');

  void _initBluetoothListeners() {
    // Skip hardware BLE platform initialization when executing under test harness
    if (bool.fromEnvironment('dart.vm.product') == false) {
      try {
        if (const bool.fromEnvironment('flutter.inspector.structuredErrors') ||
            StackTrace.current.toString().contains('test_async') ||
            StackTrace.current.toString().contains('package:test')) {
          return;
        }
      } catch (_) {}
    }

    try {
      FlutterBluePlus.adapterState.listen((state) {
        if (state != BluetoothAdapterState.on && _connectedDevice != null) {
          disconnect();
        }
      }, onError: (_) {});
    } catch (_) {}
  }



  // ---------------------------------------------------------------------------
  // BLE Scanning
  // ---------------------------------------------------------------------------
  Future<void> startScan({Duration timeout = const Duration(seconds: 12)}) async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        throw BleException("Bluetooth LE is not supported on this device.");
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        throw BleException("Bluetooth is disabled. Please enable Bluetooth.");
      }

      final List<DeviceModel> foundDevices = [];
      FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : (r.advertisementData.advName.isNotEmpty
                  ? r.advertisementData.advName
                  : 'ESP32 Node (${r.device.remoteId.str.substring(0, 5)})');

          final deviceModel = DeviceModel(
            id: r.device.remoteId.str,
            name: name,
            rssi: r.rssi,
            isConnected: _connectedDevice?.remoteId.str == r.device.remoteId.str,
            lastSeen: DateTime.now().millisecondsSinceEpoch,
          );

          final existingIdx = foundDevices.indexWhere((d) => d.id == deviceModel.id);
          if (existingIdx >= 0) {
            foundDevices[existingIdx] = deviceModel;
          } else {
            foundDevices.add(deviceModel);
          }
          _devicesListController.add(List.from(foundDevices));
        }
      });

      await FlutterBluePlus.startScan(
        withServices: [Guid(AppConstants.bleServiceUuid)],
        timeout: timeout,
      );
    } catch (e) {
      // If service UUID filter returns nothing or platform restricts it, fallback to general scan
      try {
        await FlutterBluePlus.startScan(timeout: timeout);
      } catch (err) {
        throw BleException("BLE Scan Failed: $err");
      }
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Device Connection & Service Discovery
  // ---------------------------------------------------------------------------
  Future<void> connect(String deviceId, {bool autoReconnect = true}) async {
    try {
      stopVirtualNode(); // If virtual node was running, stop it
      await stopScan();

      final device = BluetoothDevice.fromId(deviceId);
      _connectedDevice = device;

      _connectionSub?.cancel();
      _connectionSub = device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == BluetoothConnectionState.disconnected) {
          _cleanUpCharacteristics();
          if (autoReconnect && !_isAutoReconnecting) {
            _triggerAutoReconnect(deviceId);
          }
        } else if (state == BluetoothConnectionState.connected) {
          _isAutoReconnecting = false;
          _reconnectAttempts = 0;
          _reconnectTimer?.cancel();
        }
      });

      // Connect with timeout
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );


      // Negotiate optimal MTU for fast JSON packets
      try {
        await device.requestMtu(256);
      } catch (_) {}

      // Discover Services
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() ==
            AppConstants.bleServiceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            final uuid = char.uuid.toString().toLowerCase();
            if (uuid == AppConstants.charTelemetryUuid.toLowerCase()) {
              _telemetryChar = char;
            } else if (uuid == AppConstants.charGpsUuid.toLowerCase()) {
              _gpsChar = char;
            } else if (uuid == AppConstants.charBatteryUuid.toLowerCase()) {
              _batteryChar = char;
            } else if (uuid == AppConstants.charSafetyStatusUuid.toLowerCase()) {
              _safetyStatusChar = char;
            } else if (uuid == AppConstants.charSosUuid.toLowerCase()) {
              _sosChar = char;
            }
          }
        }
      }

      await _subscribeToNotifications();
    } catch (e) {
      _cleanUpCharacteristics();
      _connectedDevice = null;
      throw BleException("Failed to connect to ESP32: $e");
    }
  }

  Future<void> _subscribeToNotifications() async {
    // 1. Subscribe to Telemetry Characteristic
    if (_telemetryChar != null) {
      await _telemetryChar!.setNotifyValue(true);
      _telemetrySub?.cancel();
      _telemetrySub = _telemetryChar!.lastValueStream.listen((bytes) {
        if (bytes.isNotEmpty) {
          _parseTelemetryBytes(bytes);
        }
      });
    }

    // 2. Subscribe to Hardware SOS Characteristic
    if (_sosChar != null) {
      await _sosChar!.setNotifyValue(true);
      _sosSub?.cancel();
      _sosSub = _sosChar!.lastValueStream.listen((bytes) {
        if (bytes.isNotEmpty && bytes[0] == 0x01) {
          _sosController.add(true);
        }
      });
    }

    // 3. Subscribe to Battery Characteristic
    if (_batteryChar != null) {
      await _batteryChar!.setNotifyValue(true);
      _batterySub?.cancel();
      _batterySub = _batteryChar!.lastValueStream.listen((bytes) {
        try {
          final str = utf8.decode(bytes);
          final map = jsonDecode(str) as Map<String, dynamic>;
          if (map.containsKey('battery')) {
            _batteryController.add(map['battery'] as int);
          }
        } catch (_) {}
      });
    }

    // 4. Subscribe to GPS Characteristic
    if (_gpsChar != null) {
      await _gpsChar!.setNotifyValue(true);
      _gpsSub?.cancel();
      _gpsSub = _gpsChar!.lastValueStream.listen((bytes) {
        try {
          final str = utf8.decode(bytes);
          final map = jsonDecode(str) as Map<String, dynamic>;
          if (map.containsKey('lat') && map.containsKey('lng')) {
            _gpsController.add({
              'latitude': (map['lat'] as num).toDouble(),
              'longitude': (map['lng'] as num).toDouble(),
            });
          }
        } catch (_) {}
      });
    }
  }


  void _parseTelemetryBytes(List<int> bytes) {
    try {
      final jsonStr = utf8.decode(bytes).trim();
      if (jsonStr.isEmpty) return;

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final telemetry = Telemetry.fromJson(map);

      _telemetryController.add(telemetry);

      if (telemetry.sos) {
        _sosController.add(true);
      }
    } catch (e) {
      // Malformed packet ignored gracefully
    }
  }

  // ---------------------------------------------------------------------------
  // Bidirectional Command: Write Safety Status back to ESP32
  // ---------------------------------------------------------------------------
  Future<void> writeSafetyStatus(SafetyStatus status) async {
    if (_safetyStatusChar == null || _connectedDevice == null) return;

    try {
      int code = 0;
      switch (status) {
        case SafetyStatus.safe:
          code = 0;
          break;
        case SafetyStatus.warning:
          code = 1;
          break;
        case SafetyStatus.danger:
          code = 2;
          break;
        case SafetyStatus.emergency:
          code = 3;
          break;
      }
      await _safetyStatusChar!.write([code], withoutResponse: false);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Disconnection & Auto-Reconnection Management
  // ---------------------------------------------------------------------------
  Future<void> disconnect() async {
    _isAutoReconnecting = false;
    _reconnectTimer?.cancel();
    stopVirtualNode();

    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}

    _cleanUpCharacteristics();
    _connectedDevice = null;
    _connectionStateController.add(BluetoothConnectionState.disconnected);
  }

  void _triggerAutoReconnect(String deviceId) {
    if (_isAutoReconnecting) return;
    _isAutoReconnecting = true;
    _reconnectAttempts = 0;

    _reconnectTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      _reconnectAttempts++;
      if (_reconnectAttempts > _maxReconnectAttempts) {
        timer.cancel();
        _isAutoReconnecting = false;
        return;
      }

      try {
        await connect(deviceId, autoReconnect: true);
        timer.cancel();
        _isAutoReconnecting = false;
      } catch (_) {
        // Will retry in next period
      }
    });
  }

  void _cleanUpCharacteristics() {
    _telemetrySub?.cancel();
    _sosSub?.cancel();
    _batterySub?.cancel();
    _gpsSub?.cancel();
    _telemetryChar = null;
    _gpsChar = null;
    _batteryChar = null;
    _safetyStatusChar = null;
    _sosChar = null;
  }

  // ---------------------------------------------------------------------------
  // Virtual ESP32 Simulator Node (for Offline & Hardware-Free Evaluation)
  // ---------------------------------------------------------------------------
  void startVirtualNode({String deviceId = "ESP32_SIMULATED_01"}) {
    if (_isVirtualNodeActive) return;
    _isVirtualNodeActive = true;
    _connectionStateController.add(BluetoothConnectionState.connected);

    double temp = 36.6;
    int hr = 76;
    int spo2 = 98;
    int gas = 45;
    double humidity = 50.0;
    int battery = 96;

    _virtualNodeTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isVirtualNodeActive) {
        timer.cancel();
        return;
      }

      // Natural sensor jitter
      final random = Random();
      temp = double.parse((temp + (random.nextInt(11) - 5) / 50.0).toStringAsFixed(1));
      if (temp < 36.2) temp = 36.5;
      if (temp > 37.2) temp = 36.9;

      hr += random.nextInt(5) - 2;
      if (hr < 70) hr = 74;
      if (hr > 88) hr = 80;

      gas += random.nextInt(7) - 3;
      if (gas < 30) gas = 45;
      if (gas > 120) gas = 80;

      final telemetry = Telemetry(
        deviceId: deviceId,
        temperature: temp,
        heartRate: hr,
        spo2: spo2,
        gasLevel: gas,
        humidity: humidity,
        latitude: 17.4485 + (random.nextDouble() * 0.0005),
        longitude: 78.3742 + (random.nextDouble() * 0.0005),
        battery: battery,
        motionStatus: 'ACTIVE',
        fallDetected: false,
        sos: false,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        synced: false,
      );

      _telemetryController.add(telemetry);
    });
  }

  void stopVirtualNode() {
    _isVirtualNodeActive = false;
    _virtualNodeTimer?.cancel();
    _virtualNodeTimer = null;
    _connectionStateController.add(BluetoothConnectionState.disconnected);
  }

  /// Injects simulated emergency conditions for instant offline testing
  void simulateEmergencyCondition({
    bool triggerSos = false,
    bool triggerFall = false,
    bool triggerToxicGas = false,
    bool triggerHypoxia = false,
  }) {
    if (!_isVirtualNodeActive) {
      startVirtualNode();
    }

    final telemetry = Telemetry(
      deviceId: 'ESP32_SIMULATED_01',
      temperature: 37.1,
      heartRate: triggerSos || triggerToxicGas ? 135 : 82,
      spo2: triggerHypoxia ? 82 : 97,
      gasLevel: triggerToxicGas ? 520 : 65,
      humidity: 55.0,
      latitude: 17.4485,
      longitude: 78.3742,
      battery: 88,
      motionStatus: triggerFall ? 'SHOCK' : 'ACTIVE',
      fallDetected: triggerFall,
      sos: triggerSos,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      synced: false,
    );

    _telemetryController.add(telemetry);
    if (triggerSos) {
      _sosController.add(true);
    }
  }

  void dispose() {
    _connectionSub?.cancel();
    _telemetrySub?.cancel();
    _sosSub?.cancel();
    _batterySub?.cancel();
    _gpsSub?.cancel();
    _virtualNodeTimer?.cancel();
    _reconnectTimer?.cancel();
    _telemetryController.close();
    _sosController.close();
    _batteryController.close();
    _gpsController.close();
    _connectionStateController.close();
    _devicesListController.close();
  }
}
