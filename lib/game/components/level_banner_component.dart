import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';

class LevelBannerComponent extends TextComponent {
  LevelBannerComponent({required String text, required Vector2 gameSize})
    : _gameSize = gameSize,
      super(
        text: text,
        position: Vector2(-gameSize.x * 0.42, gameSize.y * 0.45),
        anchor: Anchor.center,
        priority: 95,
      ) {
    _applyStyle(0);
  }

  final Vector2 _gameSize;
  double _age = 0;
  static const _lifeSeconds = 1.65;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    final progress = (_age / _lifeSeconds).clamp(0.0, 1.0);
    final xProgress = progress < 0.28
        ? _easeOut(progress / 0.28)
        : progress > 0.72
        ? 1 + _easeIn((progress - 0.72) / 0.28)
        : 1.0;
    position.x = -_gameSize.x * 0.42 + xProgress * _gameSize.x * 0.92;
    scale = Vector2.all(
      1.0 + (1 - (progress - 0.5).abs() * 2).clamp(0, 1) * 0.10,
    );
    _applyStyle(
      progress < 0.18
          ? progress / 0.18
          : progress > 0.82
          ? 1 - ((progress - 0.82) / 0.18)
          : 1,
    );
    if (_age >= _lifeSeconds) {
      removeFromParent();
    }
  }

  double _easeOut(double t) => 1 - (1 - t) * (1 - t) * (1 - t);

  double _easeIn(double t) => t * t * t;

  void _applyStyle(double alpha) {
    textRenderer = TextPaint(
      style: TextStyle(
        color: const Color(0xFFFFF2B2).withValues(alpha: alpha.clamp(0, 1)),
        fontSize: 42,
        fontWeight: FontWeight.w900,
        shadows: const [
          Shadow(color: Color(0xEE000000), blurRadius: 8, offset: Offset(2, 3)),
          Shadow(color: Color(0xFFFF7D5B), blurRadius: 14),
        ],
      ),
    );
  }
}
