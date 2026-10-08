import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A short, quiet burst of confetti for finishing a session. Skipped entirely when the
/// system asks for reduced motion.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.colors, this.count = 42});
  final List<Color> colors;
  final int count;
  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_c.value, widget.colors, widget.count),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.colors, this.count);
  final double t;
  final List<Color> colors;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7); // fixed seed: the same celebration every time
    final origin = Offset(size.width / 2, size.height * 0.28);
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.1;
      final speed = 140 + rnd.nextDouble() * 260;
      final spin = rnd.nextDouble() * math.pi * 4;
      final dx = math.cos(angle) * speed * t;
      final dy = math.sin(angle) * speed * t + 420 * t * t; // gravity
      final fade = (1 - ((t - 0.55) / 0.45)).clamp(0.0, 1.0);
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: fade);
      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(spin * t);
      final w = 6 + rnd.nextDouble() * 6;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.55), const Radius.circular(2)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => o.t != t;
}
