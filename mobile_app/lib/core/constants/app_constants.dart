import 'package:flutter/material.dart';

class AppConstants {
  // BLE UUIDs - Worker Safety Service
  static const String bleServiceUuid = "0000fff0-0000-1000-8000-00805f9b34fb";
  static const String charTelemetryUuid = "0000fff1-0000-1000-8000-00805f9b34fb";
  static const String charGpsUuid = "0000fff2-0000-1000-8000-00805f9b34fb";
  static const String charBatteryUuid = "0000fff3-0000-1000-8000-00805f9b34fb";
  static const String charSafetyStatusUuid = "0000fff4-0000-1000-8000-00805f9b34fb";
  static const String charSosUuid = "0000fff5-0000-1000-8000-00805f9b34fb";

  // App Strings
  static const String appName = "Safegaurd";
  static const String appTagline = "Industrial Worker Safety & Vital Monitoring";

  // Thresholds for Visual Warnings
  static const double tempSafeMin = 35.8;
  static const double tempSafeMax = 37.3;
  static const double tempWarningMax = 38.2;

  static const int hrSafeMin = 60;
  static const int hrSafeMax = 100;
  static const int hrWarningMax = 120;

  static const int spo2SafeMin = 95;
  static const int spo2WarningMin = 90;

  static const int gasSafeMax = 150;
  static const int gasWarningMax = 350;

  static const int batteryLowThreshold = 20;

  // Firebase Realtime DB Paths
  static const String rtdbUrl = "https://worker-safety-system-9798a-default-rtdb.asia-southeast1.firebasedatabase.app";
  static const String rtdbUsers = "users";
  static const String rtdbWorkers = "workers";
  static const String rtdbTelemetry = "telemetry";
  static const String rtdbAlerts = "alerts";
  static const String rtdbDevices = "devices";

  // Colors
  static const Color statusSafeColor = Color(0xFF10B981); // Emerald Teal
  static const Color statusWarningColor = Color(0xFFF59E0B); // Amber Flame
  static const Color statusDangerColor = Color(0xFFEF4444); // High Alert Crimson
  static const Color statusEmergencyColor = Color(0xFFF43F5E); // Vivid Emergency Pulse
}
