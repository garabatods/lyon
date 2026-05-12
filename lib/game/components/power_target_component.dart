import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

class PowerTargetComponent extends PositionComponent {
  PowerTargetComponent({
    required Vector2 center,
    required Vector2 size,
    required this.color,
    this.reticle = false,
  }) : super(position: center, size: size, anchor: Anchor.center, priority: 35);

  final Color color;
  final bool reticle;
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final pulse = (math.sin(_time * math.pi * 3.4) + 1) / 2;
    final rect = Offset.zero & Size(size.x, size.y);
    final radius = Radius.circular(size.x * 0.2);

    final fill = Paint()
      ..color = color.withValues(alpha: 0.12 + pulse * 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);

    final stroke = Paint()
      ..color = color.withValues(alpha: 0.55 + pulse * 0.35)
      ..strokeWidth = reticle ? 4 : 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(3), radius), stroke);

    if (!reticle) {
      return;
    }

    final center = Offset(size.x / 2, size.y / 2);
    final leafPaint = Paint()
      ..color = color.withValues(alpha: 0.75 + pulse * 0.2)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 4; i += 1) {
      final angle = (math.pi / 2) * i + pulse * 0.18;
      final offset = Offset(math.cos(angle), math.sin(angle)) * size.x * 0.39;
      canvas.save();
      canvas.translate(center.dx + offset.dx, center.dy + offset.dy);
      canvas.rotate(angle + math.pi / 4);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.x * 0.18,
          height: size.y * 0.32,
        ),
        leafPaint,
      );
      canvas.restore();
    }

    final ring = Paint()
      ..color = const Color(0xFFFFF2B2).withValues(alpha: 0.65 + pulse * 0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, size.x * (0.25 + pulse * 0.03), ring);
  }
}
