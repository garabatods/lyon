import '../models/bug_color.dart';

class GameAssets {
  static const background = 'backgrpund_jungle_controls.png';
  static const board = 'board_6x8_empty.png';
  static const fxPop = 'fx_pop.png';
  static const fxSparkle = 'fx_sparkle.png';
  static const fxComboBurst = 'fx_combo_burst.png';
  static const tutorialHandRight = 'tutorial/pointHand_Right.png';
  static const tutorialHandLeft = 'tutorial/pointHand_Left.png';

  static String ladybug(BugColor color) => 'ladybug_${color.name}.png';

  static String ladybugFrame(BugColor color, int frame) {
    return 'ladybugs/${color.name}/ladybug_${color.name}_anim0$frame.png';
  }

  static String colorSplash(BugColor color) {
    return 'fx_color_splash_${color.name}.png';
  }

  static String chameleonIdle(BugColor? color, int frame) {
    final folder = color?.name ?? 'neutral';
    return 'chameleon/$folder/chameleon_idle0$frame.png';
  }

  static String chameleonWalk(BugColor? color, int frame) {
    final folder = color?.name ?? 'neutral';
    return 'chameleon/$folder/chameleon_walk0$frame.png';
  }

  static String chameleonSwallow(BugColor? color, int frame) {
    final folder = color?.name ?? 'neutral';
    return 'chameleon/$folder/chameleon_swallow0$frame.png';
  }

  static List<String> allImages() {
    final files = <String>[
      background,
      board,
      fxPop,
      fxSparkle,
      fxComboBurst,
      tutorialHandRight,
      tutorialHandLeft,
      'ui_panel_small.png',
      'ui_panel_wide.png',
      for (final color in BugColor.active) ladybug(color),
      for (final color in BugColor.active) ...[
        ladybugFrame(color, 1),
        ladybugFrame(color, 2),
        ladybugFrame(color, 3),
      ],
      for (final color in [BugColor.red, BugColor.blue, BugColor.yellow])
        colorSplash(color),
    ];

    final folders = <BugColor?>[null, ...BugColor.active];
    for (final color in folders) {
      files.addAll([
        chameleonIdle(color, 1),
        chameleonIdle(color, 2),
        chameleonWalk(color, 1),
        chameleonWalk(color, 2),
        chameleonWalk(color, 3),
        chameleonSwallow(color, 1),
        chameleonSwallow(color, 2),
        chameleonSwallow(color, 3),
      ]);
    }

    return files;
  }
}
