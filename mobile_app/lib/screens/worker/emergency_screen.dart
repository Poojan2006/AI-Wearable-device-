import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/sync_service.dart';
import '../../services/notification_service.dart';
import '../../services/sms_service.dart';
import '../../services/ble_service.dart';
import '../../models/alert_model.dart';
import '../../models/prediction_result.dart';
import '../../core/utils/sound_haptic_helper.dart';

class EmergencyScreen extends StatefulWidget {
  final String workerId;
  final String workerName;
  final String? initialCause;

  const EmergencyScreen({
    super.key,
    required this.workerId,
    required this.workerName,
    this.initialCause,
  });

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  Timer? _alarmFeedbackTimer;

  bool _isDispatched = false;
  String _dispatchMessage = "Local Alarm Active. Queued for Cloud Dispatch.";

  bool _isSmsDispatched = false;
  bool _isSendingSms = false;
  String _smsMessage = "Initiating automatic cellular SMS to supervisor...";

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Trigger local alarms immediately (100% offline)
    SoundHapticHelper.triggerEmergencyFeedback();
    BleService.instance.writeSafetyStatus(SafetyStatus.emergency);
    NotificationService.instance.triggerSafetyAlert(
      status: SafetyStatus.emergency,
      title: "🚨 EMERGENCY SOS ACTIVATED",
      message: "Emergency broadcast initiated for worker ${widget.workerName}.",
    );

    // Periodic siren reminder
    _alarmFeedbackTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      SoundHapticHelper.triggerEmergencyFeedback();
      BleService.instance.writeSafetyStatus(SafetyStatus.emergency);
    });

    _recordSosAlert();
    _dispatchEmergencySms();
  }

  Future<void> _dispatchEmergencySms({bool force = true}) async {
    setState(() => _isSendingSms = true);
    final res = await SmsService.instance.sendDistressSms(
      workerId: widget.workerId,
      workerName: widget.workerName,
      condition: widget.initialCause ?? "Manual SOS distress panic button depressed",
      force: force,
    );

    if (mounted) {
      setState(() {
        _isSendingSms = false;
        _isSmsDispatched = res.success;
        if (res.success) {
          _smsMessage = "SMS Dispatched to Supervisor (${SmsService.instance.supervisorPhone})";
        } else if (res.mode == 'DISABLED') {
          _smsMessage = "Auto-SMS disabled in settings.";
        } else {
          _smsMessage = "SMS: ${res.mode} -> ${SmsService.instance.supervisorPhone}";
        }
      });
    }
  }

  Future<void> _recordSosAlert() async {
    final alert = AlertItem(
      workerId: widget.workerId,
      workerName: widget.workerName,
      type: 'SOS',
      message: widget.initialCause ?? 'Manual SOS activated by worker.',
      severity: 'EMERGENCY',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      acknowledged: false,
      synced: false,
    );

    await SyncService.instance.recordAlert(alert);

    setState(() {
      if (SyncService.instance.isOnline) {
        _isDispatched = true;
        _dispatchMessage = "SOS Transmitted to Supervisor Cloud Dashboard.";
      } else {
        _isDispatched = false;
        _dispatchMessage = "Saved Locally in Offline Queue. Will sync immediately when internet returns.";
      }
    });
  }

  @override
  void dispose() {
    _alarmFeedbackTimer?.cancel();
    _animController.dispose();
    BleService.instance.writeSafetyStatus(SafetyStatus.safe);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [
              Color(0xFF3B0712), // Deep crimson core
              Color(0xFF180306), // Outer dark space
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header Protocol Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF43F5E).withAlpha(120), width: 1.2),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFF43F5E), size: 16),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          "EMERGENCY PROTOCOL ACTIVE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Animated Flashing SOS Symbol
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
                      ),
                      border: Border.all(color: const Color(0xFFFF6484), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF43F5E).withAlpha(140),
                          blurRadius: 45,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emergency_rounded, color: Colors.white, size: 68),
                          SizedBox(height: 4),
                          Text(
                            "SOS ACTIVE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Status Information Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF220B12), Color(0xFF130508)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF43F5E).withAlpha(80), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(80),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${widget.workerName} (${widget.workerId})",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF43F5E).withAlpha(35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "PRIORITY 1",
                              style: TextStyle(color: Color(0xFFF43F5E), fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Cause: ${widget.initialCause ?? 'Manual Panic Activation'}",
                        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0x33F43F5E), height: 1),
                      const SizedBox(height: 10),
                      // 1. Cellular SMS status (Works 100% offline via GSM)
                      Row(
                        children: [
                          Icon(
                            _isSendingSms
                                ? Icons.sync_rounded
                                : _isSmsDispatched
                                    ? Icons.sms_rounded
                                    : Icons.sms_failed_rounded,
                            color: _isSmsDispatched ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _smsMessage,
                              style: TextStyle(
                                color: _isSmsDispatched ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!_isSendingSms)
                            InkWell(
                              onTap: () => _dispatchEmergencySms(force: true),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white30),
                                ),
                                child: const Text(
                                  "RE-SEND",
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 2. Cloud DB stream status
                      Row(
                        children: [
                          Icon(
                            _isDispatched ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                            color: _isDispatched ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _dispatchMessage,
                              style: TextStyle(
                                color: _isDispatched ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        "CANCEL EMERGENCY / FALSE ALARM",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.white.withAlpha(120), width: 1.2),
                        backgroundColor: Colors.white.withAlpha(15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
