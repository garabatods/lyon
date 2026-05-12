import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

class ColumnWarningComponent extends PositionComponent {
  ColumnWarningComponent({
    required this.full,
    required Vector2 center,
    required Vector2 size,
    required double badgeRadius,
  }) : _badgeRadius = badgeRadius,
       super(position: center, size: size, anchor: Anchor.center, priority: 18);

  final bool full;
  final double _badgeRadius;
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final pulse = (math.sin(_time * math.pi * (full ? 5.2 : 3.0)) + 1) / 2;
    final color = full ? const Color(0xFFFF4E35) : const Color(0xFFFFC84F);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final radius = Radius.circular(size.x * 0.18);

    final fill = Paint()
      ..color = color.withValues(alpha: full ? 0.07 + pulse * 0.05 : 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);

    final stroke = Paint()
      ..color = color.withValues(alpha: full ? 0.55 + pulse * 0.22 : 0.48)
      ..strokeWidth = full ? 3 : 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(2), radius), stroke);

    final badgeCenter = Offset(size.x / 2, -_badgeRadius * 0.18);
    final badgePaint = Paint()
      ..color = color.withValues(alpha: 0.88 + pulse * 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(badgeCenter, _badgeRadius, badgePaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: full ? '!' : '6',
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: _badgeRadius * (full ? 1.45 : 1.05),
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(
              color: Color(0xAA000000),
              blurRadius: 3,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      badgeCenter - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }
}
