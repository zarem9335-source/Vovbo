import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/dragon_theme.dart';

class PingChartWidget extends StatelessWidget {
  final List<int> samples;
  final int avgPing;
  final int jitterMs;
  final bool isLiveMonitoring;
  final VoidCallback onToggleMonitor;

  const PingChartWidget({
    super.key,
    required this.samples,
    required this.avgPing,
    required this.jitterMs,
    required this.isLiveMonitoring,
    required this.onToggleMonitor,
  });

  @override
  Widget build(BuildContext context) {
    final stabilityLabel = jitterMs <= 15
        ? 'STABLE'
        : jitterMs <= 45
            ? 'MODERATE'
            : 'HIGH JITTER';
    final stabilityColor = jitterMs <= 15
        ? DragonColors.electricBlue
        : jitterMs <= 45
            ? DragonColors.emberOrange
            : DragonColors.crimsonRed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart_rounded,
                    color: DragonColors.electricBlue, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'LIVE PING & JITTER (1s)',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stabilityColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: stabilityColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    '$stabilityLabel • ±${jitterMs}ms',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: stabilityColor),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onToggleMonitor,
                  child: Icon(
                    isLiveMonitoring
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    color: isLiveMonitoring
                        ? DragonColors.crimsonRed
                        : DragonColors.electricBlue,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 82,
              width: double.infinity,
              child: CustomPaint(
                painter: _PingLinePainter(
                  samples: samples,
                  lineColor: stabilityColor,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Latest: ${samples.isNotEmpty ? (samples.last > 0 ? "${samples.last} ms" : "Timeout") : "--"}',
                  style: const TextStyle(
                      fontSize: 11, color: DragonColors.textSecondary),
                ),
                Text(
                  'Avg: ${avgPing > 0 ? "$avgPing ms" : "--"}',
                  style: const TextStyle(
                      fontSize: 11, color: DragonColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PingLinePainter extends CustomPainter {
  final List<int> samples;
  final Color lineColor;

  _PingLinePainter({required this.samples, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.8;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (samples.length < 2) return;

    final valid = samples.where((s) => s > 0).toList();
    final maxVal =
        valid.isEmpty ? 200.0 : math.max(120.0, valid.reduce(math.max).toDouble());

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < samples.length; i++) {
      final x = (i / (samples.length - 1)) * size.width;
      final val = samples[i] <= 0 ? maxVal : samples[i].toDouble();
      final y = size.height - ((val / maxVal).clamp(0.05, 1.0) * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.32), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _PingLinePainter oldDelegate) => true;
}
