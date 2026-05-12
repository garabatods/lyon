import 'package:flame/components.dart';

class BackgroundComponent extends SpriteComponent {
  BackgroundComponent({required Sprite sprite})
    : super(sprite: sprite, anchor: Anchor.topLeft, priority: 0);
}
