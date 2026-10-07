import 'package:flutter/material.dart';
import '../models/prediction_result.dart';

class SafetyStatusWidget extends StatelessWidget {
  final SafetyStatus status;
  final double? confidence;
  final bool isLarge;

  const SafetyStatusWidget({
    super.key,
    required this.status,
    this.confidence,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    final icon = status.icon;
    final title = status.toDisplayString();

    if (!isLarge) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(80), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withAlpha(160), blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha(42),
            const Color(0xFF131C32),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withAlpha(85), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(28),
            blurRadius: 22,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(38),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(100), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(50),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "SAFETY STATUS",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: Colors.white.withAlpha(160),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withAlpha(28),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withAlpha(70)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, size: 10, color: color),
                              const SizedBox(width: 2),
                              Text(
                                "EDGE RF",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: color,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (confidence != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "AI Prediction Confidence",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(160),
                  ),
                ),
                Text(
                  "${(confidence! * 100).toStringAsFixed(1)}%",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: confidence!.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: Colors.white.withAlpha(15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
