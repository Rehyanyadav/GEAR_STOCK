import 'dart:math' as math;

import 'package:flutter/material.dart';

class LiquidBackground extends StatefulWidget {
  const LiquidBackground({required this.child, super.key});

  final Widget child;

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _disableAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations == _disableAnimations) return;
    _disableAnimations = disableAnimations;
    if (disableAnimations) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _LiquidPainter(
            animation: _disableAnimations == true
                ? const AlwaysStoppedAnimation(0)
                : _controller,
            accent: scheme.primary,
            highlight: scheme.primaryFixed,
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _LiquidPainter extends CustomPainter {
  const _LiquidPainter({
    required this.animation,
    required this.accent,
    required this.highlight,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color accent;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final time = animation.value * math.pi * 2;

    _drawWave(canvas, size, time, size.height * 0.3, 24, accent, 27);
    _drawWave(canvas, size, time + 1.5, size.height * 0.33, 17, highlight, 19);
    _drawWave(
      canvas,
      size,
      time + math.pi,
      size.height * 0.84,
      -23,
      accent,
      23,
    );

    _drawBlob(
      canvas,
      center: Offset(size.width * 1.02, size.height * 0.19),
      radius: size.shortestSide * 0.25,
      phase: time * 0.42,
      color: accent,
      opacity: 0.14,
    );
    _drawBlob(
      canvas,
      center: Offset(size.width * -0.03, size.height * 0.79),
      radius: size.shortestSide * 0.24,
      phase: -time * 0.35 + 1.8,
      color: highlight,
      opacity: 0.16,
    );

    _drawBubbles(canvas, size, time);
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    double phase,
    double baseline,
    double amplitude,
    Color color,
    int opacity,
  ) {
    final isBottomWave = baseline > size.height / 2;
    final edgeY = isBottomWave ? size.height : 0.0;
    final path = Path()..moveTo(0, edgeY);
    for (var x = 0.0; x <= size.width; x += 6) {
      final progress = x / size.width;
      final wave =
          math.sin(progress * math.pi * 2.2 + phase) * amplitude +
          math.sin(progress * math.pi * 4.4 - phase * 0.7) * amplitude * 0.22;
      final y = baseline + wave;
      if (x == 0) {
        path.lineTo(x, y);
      } else {
        final previousProgress = (x - 6) / size.width;
        final previousY =
            baseline +
            math.sin(previousProgress * math.pi * 2.2 + phase) * amplitude +
            math.sin(previousProgress * math.pi * 4.4 - phase * 0.7) *
                amplitude *
                0.22;
        final midpointX = x - 3;
        path.quadraticBezierTo(
          midpointX,
          previousY,
          midpointX,
          (previousY + y) / 2,
        );
        path.quadraticBezierTo(midpointX, y, x, y);
      }
    }
    path
      ..lineTo(size.width, edgeY)
      ..close();
    canvas.drawPath(path, _wavePaint(color, opacity));
  }

  Paint _wavePaint(Color color, int opacity) =>
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withAlpha(opacity),
            color.withAlpha((opacity * 0.35).round()),
          ],
        ).createShader(const Rect.fromLTWH(0, 0, 1, 300));

  void _drawBlob(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double phase,
    required Color color,
    required double opacity,
  }) {
    const points = 48;
    final path = Path();
    final vertices = <Offset>[];
    for (var i = 0; i < points; i++) {
      final angle = i / points * math.pi * 2;
      final breathing =
          1 +
          0.09 * math.sin(angle * 3 + phase) +
          0.045 * math.sin(angle * 5 - phase * 0.8);
      vertices.add(
        center +
            Offset(
              math.cos(angle) * radius * breathing,
              math.sin(angle) * radius * breathing * 0.8,
            ),
      );
    }

    for (var i = 0; i < points; i++) {
      final current = vertices[i];
      final next = vertices[(i + 1) % points];
      final midpoint = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      if (i == 0) {
        path.moveTo(midpoint.dx, midpoint.dy);
      }
      path.quadraticBezierTo(current.dx, current.dy, midpoint.dx, midpoint.dy);
    }
    path.close();

    final rect = Rect.fromCircle(center: center, radius: radius * 1.45);
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  void _drawBubbles(Canvas canvas, Size size, double time) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accent.withAlpha(48);

    for (var i = 0; i < 6; i++) {
      final progress = (animation.value + i / 6) % 1;
      final x =
          size.width * (0.12 + (i % 3) * 0.38) + math.sin(time + i * 1.7) * 10;
      final y = size.height * (0.4 + (i % 2) * 0.4) - progress * 90;
      final radius = 2.5 + (i % 3) * 1.5;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_LiquidPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.accent != accent ||
      oldDelegate.highlight != highlight;
}
