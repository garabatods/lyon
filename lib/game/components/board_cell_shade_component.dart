import 'dart:ui';

import 'package:flame/components.dart';

class BoardCellShadeComponent extends RectangleComponent {
  BoardCellShadeComponent({required Vector2 center, required Vector2 size})
    : super(
        position: center,
        size: size,
        anchor: Anchor.center,
        priority: 16,
        paint: Paint()..color = const Color(0x66000000),
      );
}
