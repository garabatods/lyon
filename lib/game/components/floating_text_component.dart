import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';

class FloatingTextComponent extends TextComponent {
  FloatingTextComponent({
    required String text,
    required Vector2 position,
    required this.color,
    this.lifeSeconds = 0.85,
    this.fontSize = 24,
    this.floatSpeed = 54,
  }) : super(
         text: text,
         position: position,
         anchor: Anchor.center,
         priority: 80,
       ) {
    _applyTextStyle(1);
  }

  final Color color;
  final double lifeSeconds;
  final double fontSize;
  final double floatSpeed;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position.y -= floatSpeed * dt;
    final progress = (_age / lifeSeconds).clamp(0.0, 1.0);
    scale = Vector2.all(1 + progress * 0.18);
    _applyTextStyle(1 - progress);
    if (_age >= lifeSeconds) {
      removeFromParent();
    }
  }

  void _applyTextStyle(double alpha) {
    textRenderer = TextPaint(
      style: TextStyle(
        color: color.withValues(alpha: alpha.clamp(0.0, 1.0)),
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        shadows: const [
          Shadow(color: Color(0xCC000000), blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
    );
  }
}
