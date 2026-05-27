import 'package:chameleon_puzzle_demo/game/levels/demo_levels.dart';
import 'package:chameleon_puzzle_demo/game/models/game_mode.dart';
import 'package:chameleon_puzzle_demo/game/models/level_definition.dart';
import 'package:chameleon_puzzle_demo/game/models/player_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tutorial unlocks adventure and time trial after level 6', () {
    final afterLevelOne = PlayerProgress.initial.completeTutorialLevel(1);

    expect(afterLevelOne.tutorialCompleted, isFalse);
    expect(afterLevelOne.isModeUnlocked(GameMode.adventure), isFalse);
    expect(afterLevelOne.isModeUnlocked(GameMode.timeTrial), isFalse);

    final afterLevelThree = afterLevelOne.completeTutorialLevel(3);

    expect(afterLevelThree.tutorialCompleted, isFalse);
    expect(afterLevelThree.isModeUnlocked(GameMode.adventure), isFalse);
    expect(afterLevelThree.isModeUnlocked(GameMode.timeTrial), isFalse);

    final afterLevelFour = afterLevelThree.completeTutorialLevel(4);

    expect(afterLevelFour.tutorialCompleted, isFalse);
    expect(afterLevelFour.isModeUnlocked(GameMode.adventure), isFalse);
    expect(afterLevelFour.isModeUnlocked(GameMode.timeTrial), isFalse);

    final afterLevelFive = afterLevelFour.completeTutorialLevel(5);

    expect(afterLevelFive.tutorialCompleted, isFalse);
    expect(afterLevelFive.isModeUnlocked(GameMode.adventure), isFalse);
    expect(afterLevelFive.isModeUnlocked(GameMode.timeTrial), isFalse);

    final afterLevelSix = afterLevelFive.completeTutorialLevel(6);

    expect(afterLevelSix.tutorialCompleted, isTrue);
    expect(afterLevelSix.isModeUnlocked(GameMode.adventure), isTrue);
    expect(afterLevelSix.isModeUnlocked(GameMode.timeTrial), isTrue);
  });

  test('old progress json decodes with empty level stars', () {
    final progress = PlayerProgress.decode(
      '{"version":1,"hasSeenTutorialIntro":true,'
      '"highestTutorialLevelCompleted":2,'
      '"unlockedModes":["adventure","timeTrial"]}',
    );

    expect(progress, isNotNull);
    expect(progress!.bestStarsByLevelId, isEmpty);
  });

  test('level stars only keep the best result', () {
    final progress = PlayerProgress.initial
        .recordLevelStars('tutorial_drag_glow', 2)
        .recordLevelStars('tutorial_drag_glow', 1)
        .recordLevelStars('first_pressure', 3);

    expect(progress.starsForLevel('tutorial_drag_glow'), 2);
    expect(progress.starsForLevel('first_pressure'), 3);

    final improved = progress.recordLevelStars('tutorial_drag_glow', 3);
    expect(improved.starsForLevel('tutorial_drag_glow'), 3);
  });

  test('totalStarsForLevelIds sums saved best stars', () {
    final progress = PlayerProgress.initial
        .recordLevelStars('a', 1)
        .recordLevelStars('b', 3)
        .recordLevelStars('c', 2);

    expect(progress.totalStarsForLevelIds(['a', 'b', 'c']), 6);
    expect(progress.totalStarsForLevelIds(['a', 'missing']), 1);
  });

  test('map01 star total uses map01 levels only', () {
    final progress = PlayerProgress.initial
        .recordLevelStars(map01Levels.first.id, 3)
        .recordLevelStars(tutorialLevels.first.id, 3);

    expect(map01Levels, hasLength(9));
    expect(
      progress.totalStarsForLevelIds(map01Levels.map((level) => level.id)),
      3,
    );
    expect(map01Levels.length * 3, 27);
  });

  test('time thresholds award completion stars', () {
    const thresholds = LevelStarThresholds(
      twoStarSecondsRemaining: 75,
      threeStarSecondsRemaining: 105,
    );

    expect(thresholds.starsForCompletion(20), 1);
    expect(thresholds.starsForCompletion(75), 2);
    expect(thresholds.starsForCompletion(105), 3);
  });
}
