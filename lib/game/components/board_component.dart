import 'package:flame/components.dart';

class BoardComponent extends SpriteComponent {
  BoardComponent({required Sprite sprite})
    : super(sprite: sprite, anchor: Anchor.topLeft, priority: 10);
}
