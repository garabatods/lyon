import 'package:flame/components.dart';

class FxComponent extends SpriteComponent {
  FxComponent({
    required Sprite sprite,
    required Vector2 center,
    required double size,
    this.lifeSeconds = 0.32,
  }) : super(
         sprite: sprite,
         position: center,
         size: Vector2.all(size),
         anchor: Anchor.center,
         priority: 40,
       );

  final double lifeSeconds;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    scale = Vector2.all(1 + (_age / lifeSeconds) * 0.25);
    if (_age >= lifeSeconds) {
      removeFromParent();
    }
  }
}
