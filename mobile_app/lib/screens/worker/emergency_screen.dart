import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/sync_service.dart';
import '../../services/notification_service.dart';
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
    NotificationService.instance.triggerSafetyAlert(
      status: SafetyStatus.emergency,
      title: "🚨 EMERGENCY SOS ACTIVATED",
      message: "Emergency broadcast initiated for worker ${widget.workerName}.",
    );

    // Periodic siren reminder
    _alarmFeedbackTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      SoundHapticHelper.triggerEmergencyFeedback();
    });

    _recordSosAlert();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF450A0A), // Deep Crimson
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "OCCUPATIONAL EMERGENCY PROTOCOL",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              // Animated Flashing SOS Symbol
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFDC2626),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withAlpha(153),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emergency_rounded, color: Colors.white, size: 72),
                        SizedBox(height: 4),
                        Text(
                          "SOS ACTIVE",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
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
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withAlpha(128)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Worker: ${widget.workerName} (${widget.workerId})",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Cause: ${widget.initialCause ?? 'Manual Panic Activation'}",
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          _isDispatched ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                          color: _isDispatched ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dispatchMessage,
                            style: TextStyle(
                              color: _isDispatched ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
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
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    label: const Text(
                      "CANCEL EMERGENCY / FALSE ALARM",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.white70, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
