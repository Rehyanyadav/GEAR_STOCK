import 'dart:math' as math;

import 'package:flutter/material.dart';

class GooeyHoverButton extends StatefulWidget {
  const GooeyHoverButton({required this.child, super.key});

  final Widget child;

  @override
  State<GooeyHoverButton> createState() => _GooeyHoverButtonState();
}

class _GooeyHoverButtonState extends State<GooeyHoverButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ValueNotifier<Offset> _pointer;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _pointer = ValueNotifier(const Offset(0.5, 0.5));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pointer.dispose();
    super.dispose();
  }

  void _onHover(PointerEvent event) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      _size = box.size;
      if (_size.isEmpty) return;
      _pointer.value = Offset(
        (event.localPosition.dx / _size.width).clamp(0.0, 1.0).toDouble(),
        (event.localPosition.dy / _size.height).clamp(0.0, 1.0).toDouble(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      onEnter: (event) {
        _onHover(event);
        _controller.forward();
      },
      onHover: _onHover,
      onExit: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _pointer]),
        child: widget.child,
        builder: (context, child) => Transform.scale(
          scale: 1 + _controller.value * 0.012,
          child: CustomPaint(
            foregroundPainter: _GooeyEdgePainter(
              progress: Curves.easeOutCubic.transform(_controller.value),
              pointer: _pointer.value,
              accent: accent,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GooeyEdgePainter extends CustomPainter {
  const _GooeyEdgePainter({
    required this.progress,
    required this.pointer,
    required this.accent,
  });

  final double progress;
  final Offset pointer;
  final Color accent;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (progress <= 0 || canvasSize.isEmpty) return;

    final radius = 7 * progress;
    final trackX = (pointer.dx * canvasSize.width).clamp(
      radius * 2,
      canvasSize.width - radius * 2,
    );
    final isTop = pointer.dy < 0.5;
    final edgeY = isTop ? radius * 0.18 : canvasSize.height - radius * 0.18;
    final direction = isTop ? 1.0 : -1.0;

    final glowPaint = Paint()
      ..color = accent.withAlpha((38 * progress).round())
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * progress);
    final bodyPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withAlpha((145 * progress).round()),
              accent.withAlpha((72 * progress).round()),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(trackX, edgeY),
              radius: radius * 1.8,
            ),
          );

    for (final offset in [-radius * 1.05, 0.0, radius * 1.05]) {
      final lobe = Offset(trackX + offset, edgeY);
      canvas.drawCircle(lobe, radius * (offset == 0 ? 0.84 : 0.66), glowPaint);
      canvas.drawCircle(lobe, radius * (offset == 0 ? 0.58 : 0.44), bodyPaint);
    }

    final neck = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(trackX, edgeY + direction * radius * 0.9),
        width: radius * 1.3,
        height: radius * 2.1,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(neck, glowPaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha((95 * progress).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(trackX - radius * 0.1, edgeY + direction * radius * 0.3),
        radius: radius * 0.42,
      ),
      math.pi * 1.05,
      math.pi * 0.82,
      false,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(_GooeyEdgePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.pointer != pointer ||
      oldDelegate.accent != accent;
}
