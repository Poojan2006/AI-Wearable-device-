import 'package:flutter/services.dart';

class SoundHapticHelper {
  static Future<void> triggerWarningFeedback() async {
    await HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.alert);
  }

  static Future<void> triggerDangerFeedback() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.alert);
  }

  static Future<void> triggerEmergencyFeedback() async {
    for (int i = 0; i < 4; i++) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await SystemSound.play(SystemSoundType.alert);
  }
}
