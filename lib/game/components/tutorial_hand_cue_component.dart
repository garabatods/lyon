import 'dart:math';

import 'package:flame/components.dart';

class TutorialHandCueComponent extends SpriteComponent {
  TutorialHandCueComponent({
    required Sprite sprite,
    required Vector2 start,
    required Vector2 end,
    required Vector2 size,
  }) : _start = start,
       _end = end,
       super(
         sprite: sprite,
         position: _positionForTouchPoint(start, size, 1),
         size: size,
         anchor: Anchor.topLeft,
         priority: 62,
       );

  static const double _cycleSeconds = 1.35;
  static const double _movePortion = 0.68;
  static const double _fingerTipX = 0.22;
  static const double _fingerTipY = 0.18;

  final Vector2 _start;
  final Vector2 _end;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age = (_age + dt) % _cycleSeconds;
    final cycle = _age / _cycleSeconds;
    if (cycle > _movePortion) {
      _placeFingerTipAt(_end, 0.96);
      return;
    }

    final t = cycle / _movePortion;
    final eased = 0.5 - (cos(t * pi) * 0.5);
    final touchPoint = _start + ((_end - _start) * eased);
    _placeFingerTipAt(touchPoint, 0.92 + sin(t * pi) * 0.08);
  }

  void _placeFingerTipAt(Vector2 touchPoint, double scaleValue) {
    scale = Vector2.all(scaleValue);
    position = _positionForTouchPoint(touchPoint, size, scaleValue);
  }

  static Vector2 _positionForTouchPoint(
    Vector2 touchPoint,
    Vector2 size,
    double scaleValue,
  ) {
    return touchPoint -
        Vector2(
          size.x * scaleValue * _fingerTipX,
          size.y * scaleValue * _fingerTipY,
        );
  }
}
