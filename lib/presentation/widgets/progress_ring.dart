import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A ring that fills from 0 to [value] (animated unless the user asked for reduced motion).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    required this.track,
    this.size = 96,
    this.stroke = 10,
    this.child,
    this.semanticLabel,
  });
  final double value; // 0..1
  final Color color, track;
  final double size, stroke;
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduce ? v : 0, end: v),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, t, _) => CustomPaint(
            painter: _RingPainter(t, color, track, stroke),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.color, this.track, this.stroke);
  final double t, stroke;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (t > 0) {
      final fg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * t, false, fg);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.t != t || o.color != color || o.track != track || o.stroke != stroke;
}
