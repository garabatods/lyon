import 'package:flame/components.dart';

import '../assets/game_assets.dart';
import '../models/bug_color.dart';

typedef SpriteFactory = Sprite Function(String path);

class ChameleonComponent extends SpriteAnimationComponent {
  ChameleonComponent({
    required this.spriteFactory,
    required Vector2 center,
    required double chameleonSize,
  }) : super(
         position: center,
         size: Vector2.all(chameleonSize),
         anchor: Anchor.center,
         priority: 30,
       ) {
    playIdle(null);
  }

  final SpriteFactory spriteFactory;

  void setFacingRight(bool facingRight) {
    scale.x = facingRight ? -scale.x.abs() : scale.x.abs();
    scale.y = scale.y.abs();
  }

  void playIdle(BugColor? color) {
    animation = _animation(
      [GameAssets.chameleonIdle(color, 1), GameAssets.chameleonIdle(color, 2)],
      stepTime: 0.34,
      loop: true,
    );
  }

  void playWalk(BugColor? color) {
    animation = _animation(
      [
        GameAssets.chameleonWalk(color, 1),
        GameAssets.chameleonWalk(color, 2),
        GameAssets.chameleonWalk(color, 3),
      ],
      stepTime: 0.08,
      loop: false,
    );
  }

  void playSwallow(BugColor? color) {
    animation = _animation(
      [
        GameAssets.chameleonSwallow(color, 1),
        GameAssets.chameleonSwallow(color, 2),
        GameAssets.chameleonSwallow(color, 3),
      ],
      stepTime: 0.09,
      loop: false,
    );
  }

  void playSpit(BugColor? color) {
    animation = _animation(
      [
        GameAssets.chameleonSwallow(color, 3),
        GameAssets.chameleonSwallow(color, 2),
        GameAssets.chameleonSwallow(color, 1),
      ],
      stepTime: 0.09,
      loop: false,
    );
  }

  SpriteAnimation _animation(
    List<String> paths, {
    required double stepTime,
    required bool loop,
  }) {
    return SpriteAnimation.spriteList(
      paths.map(spriteFactory).toList(),
      stepTime: stepTime,
      loop: loop,
    );
  }
}
