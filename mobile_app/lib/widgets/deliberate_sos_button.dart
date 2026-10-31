import 'dart:async';

import 'package:flutter/material.dart';

class DeliberateSosButton extends StatefulWidget {
  final VoidCallback onTrigger;
  final String label;

  const DeliberateSosButton({
    super.key,
    required this.onTrigger,
    this.label = "HOLD 2s TO TRIGGER SOS",
  });

  @override
  State<DeliberateSosButton> createState() => _DeliberateSosButtonState();
}

class _DeliberateSosButtonState extends State<DeliberateSosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _countdownTimer;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onTriggerCompleted();
      }
    });
  }

  void _onTriggerCompleted() {
    setState(() => _isHolding = false);
    _progressController.reset();
    widget.onTrigger();
  }

  void _handleTapDown(TapDownDetails _) {
    setState(() => _isHolding = true);
    _progressController.forward(from: 0.0);
  }

  void _handleTapUp(TapUpDetails _) {
    _cancelHold();
  }

  void _handleTapCancel() {
    _cancelHold();
  }

  void _cancelHold() {
    if (_isHolding) {
      setState(() => _isHolding = false);
      _progressController.reverse();
    }
    _countdownTimer?.cancel();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (context, child) {
          final progress = _progressController.value;
          final isPrimed = progress > 0.05;

          return Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPrimed
                    ? [const Color(0xFFDC2626), const Color(0xFF991B1B)]
                    : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withAlpha(isPrimed ? 120 : 60),
                  blurRadius: isPrimed ? 18 : 10,
                  spreadRadius: isPrimed ? 2 : 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Progress fill bar on hold
                  if (progress > 0)
                    FractionallySizedBox(
                      widthFactor: progress,
                      alignment: Alignment.centerLeft,
                      child: Container(color: Colors.white.withAlpha(60)),
                    ),

                  // Button content
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.sos_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isHolding
                                      ? "HOLDING... ${(progress * 100).toInt()}%"
                                      : widget.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  "Hold to prevent accidental activation",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
