import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class MetricDataPoint {
  final double value;
  final DateTime timestamp;

  MetricDataPoint({required this.value, required this.timestamp});
}

class TrendChartCard extends StatelessWidget {
  final String title;
  final String unit;
  final List<double> dataPoints;
  final Color accentColor;
  final double? warningThreshold;
  final double? dangerThreshold;
  final String? subtitle;

  const TrendChartCard({
    super.key,
    required this.title,
    required this.unit,
    required this.dataPoints,
    required this.accentColor,
    this.warningThreshold,
    this.dangerThreshold,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderColor = AppTheme.border(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textSub = AppTheme.textSub(context);

    final hasData = dataPoints.isNotEmpty;
    final latestVal = hasData ? dataPoints.last : 0.0;
    final minVal = hasData ? dataPoints.reduce(math.min) : 0.0;
    final maxVal = hasData ? dataPoints.reduce(math.max) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title, Subtitle, Latest Value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 11, color: textSub),
                    ),
                  ],
                ],
              ),
              if (hasData)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      latestVal % 1 == 0
                          ? latestVal.toInt().toString()
                          : latestVal.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSub,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart canvas or empty state
          SizedBox(
            height: 90,
            width: double.infinity,
            child: hasData && dataPoints.length >= 2
                ? CustomPaint(
                    painter: _SparklinePainter(
                      data: dataPoints,
                      color: accentColor,
                      isDark: isDark,
                      warningThreshold: warningThreshold,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.show_chart_rounded,
                          size: 26,
                          color: textSub.withAlpha(100),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasData
                              ? "Collecting more real data points..."
                              : "No historical readings recorded yet",
                          style: TextStyle(fontSize: 11, color: textSub),
                        ),
                      ],
                    ),
                  ),
          ),

          if (hasData && dataPoints.length >= 2) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "MIN: ${minVal % 1 == 0 ? minVal.toInt() : minVal.toStringAsFixed(1)} $unit",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: textSub,
                  ),
                ),
                Text(
                  "${dataPoints.length} SAMPLES",
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: accentColor,
                  ),
                ),
                Text(
                  "MAX: ${maxVal % 1 == 0 ? maxVal.toInt() : maxVal.toStringAsFixed(1)} $unit",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: textSub,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool isDark;
  final double? warningThreshold;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.isDark,
    this.warningThreshold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final double minVal = data.reduce(math.min);
    final double maxVal = data.reduce(math.max);
    final double range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    // Padding
    const double padY = 8.0;
    final double drawHeight = size.height - (padY * 2);
    final double stepX = size.width / (data.length - 1);

    // Grid line (midline)
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withAlpha(18)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      gridPaint,
    );

    // Build smooth path
    final path = Path();
    final fillPath = Path();

    List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalized = (data[i] - minVal) / range;
      final y = size.height - padY - (normalized * drawHeight);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final ctrl1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final ctrl2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);

      path.cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, p1.dx, p1.dy);
      fillPath.cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    // Fill gradient
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withAlpha(isDark ? 60 : 40), color.withAlpha(0)],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Draw last point dot
    final lastPoint = points.last;
    final dotBgPaint = Paint()
      ..color = isDark ? const Color(0xFF131B2E) : Colors.white
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(lastPoint, 5, dotBgPaint);
    canvas.drawCircle(lastPoint, 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.isDark != isDark;
  }
}
