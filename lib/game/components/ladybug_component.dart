import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../models/bug_color.dart';

class LadybugComponent extends SpriteAnimationComponent {
  LadybugComponent({
    required SpriteAnimation animation,
    required this.color,
    required bool charged,
    required Vector2 center,
    required double bugSize,
    bool big = false,
  }) : super(
         animation: animation,
         position: center,
         size: Vector2.all(bugSize),
         anchor: Anchor.center,
         priority: big ? 24 : 20,
       ) {
    if (big) {
      add(BigBugGlowComponent(radius: bugSize * 0.52));
    }
    if (charged) {
      add(ChargedGlowComponent(radius: bugSize * 0.56));
    }
  }

  final BugColor color;

  Vector2? _targetPosition;
  double _fallVelocity = 0;
  int _bounces = 0;

  void fallTo(Vector2 target) {
    _targetPosition = target.clone();
    _fallVelocity = 120;
    _bounces = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target = _targetPosition;
    if (target == null) {
      return;
    }

    position.x += (target.x - position.x) * (dt * 12).clamp(0, 1);

    if (position.y < target.y) {
      _fallVelocity += 2400 * dt;
      position.y += _fallVelocity * dt;
    } else if (position.y > target.y + 1) {
      position.y += (target.y - position.y) * (dt * 14).clamp(0, 1);
    } else if (_bounces == 0 && _fallVelocity > 420) {
      position.y = target.y;
      _fallVelocity = -_fallVelocity * 0.18;
      _bounces += 1;
    } else if (_fallVelocity < 0) {
      _fallVelocity += 2200 * dt;
      position.y += _fallVelocity * dt;
    } else {
      position = target;
      _targetPosition = null;
      _fallVelocity = 0;
    }
  }
}

class ChargedGlowComponent extends CircleComponent {
  ChargedGlowComponent({required double radius})
    : _baseRadius = radius,
      super(
        radius: radius,
        position: Vector2.all(radius / 0.56 / 2),
        anchor: Anchor.center,
        priority: -1,
        paint: Paint()
          ..color = const Color(0xFFFFF3A6).withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );

  final double _baseRadius;
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final pulse = (math.sin(_time * math.pi * 2.6) + 1) / 2;
    radius = _baseRadius * (1.02 + pulse * 0.16);
    paint.color = const Color(
      0xFFFFF3A6,
    ).withValues(alpha: 0.30 + pulse * 0.28);
  }
}

class BigBugGlowComponent extends CircleComponent {
  BigBugGlowComponent({required double radius})
    : _baseRadius = radius,
      super(
        radius: radius,
        position: Vector2.all(radius / 0.52 / 2),
        anchor: Anchor.center,
        priority: -1,
        paint: Paint()
          ..color = const Color(0xFFFFB84D).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );

  final double _baseRadius;
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final pulse = (math.sin(_time * math.pi * 2.0) + 1) / 2;
    radius = _baseRadius * (1.0 + pulse * 0.08);
    paint.color = const Color(
      0xFFFFB84D,
    ).withValues(alpha: 0.22 + pulse * 0.22);
  }
}
