import 'package:chameleon_puzzle_demo/adventure_map_definition.dart';
import 'package:chameleon_puzzle_demo/game/levels/demo_levels.dart';
import 'package:chameleon_puzzle_demo/game/models/player_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'map01 definition stores node positions in source image coordinates',
    () {
      expect(adventureMap01.canvasSize.width, 823);
      expect(adventureMap01.canvasSize.height, 2544);
      expect(
        adventureMap01.backgroundAsset,
        'assets/images/adventure/maps/jungle/jungle_map3.png',
      );
      expect(adventureMap01.nodes, hasLength(map01Levels.length));
      expect(adventureMap01.nodes.first.center.dx, 404);
      expect(adventureMap01.nodes.first.center.dy, 1956);
      expect(adventureMap01.nodes.last.center.dx, 412);
      expect(adventureMap01.nodes.last.center.dy, 639);
    },
  );

  test('level unlocks follow previous-level star completion', () {
    expect(
      isAdventureLevelUnlocked(
        progress: PlayerProgress.initial,
        levels: map01Levels,
        levelIndex: 0,
      ),
      isTrue,
    );
    expect(
      isAdventureLevelUnlocked(
        progress: PlayerProgress.initial,
        levels: map01Levels,
        levelIndex: 1,
      ),
      isFalse,
    );

    final progress = PlayerProgress.initial.recordLevelStars(
      map01Levels.first.id,
      1,
    );

    expect(
      isAdventureLevelUnlocked(
        progress: progress,
        levels: map01Levels,
        levelIndex: 1,
      ),
      isTrue,
    );
    expect(
      isAdventureLevelUnlocked(
        progress: progress,
        levels: map01Levels,
        levelIndex: 2,
      ),
      isFalse,
    );
  });

  test('first adventure level index chooses next unstarred unlocked level', () {
    final afterLevelOne = PlayerProgress.initial.recordLevelStars(
      map01Levels[0].id,
      2,
    );
    final afterLevelTwo = afterLevelOne.recordLevelStars(map01Levels[1].id, 1);

    expect(
      firstAdventureLevelIndex(
        progress: PlayerProgress.initial,
        levels: map01Levels,
      ),
      0,
    );
    expect(
      firstAdventureLevelIndex(progress: afterLevelOne, levels: map01Levels),
      1,
    );
    expect(
      firstAdventureLevelIndex(progress: afterLevelTwo, levels: map01Levels),
      2,
    );
  });

  test('completed replays return to map only when the next level is done', () {
    final levelOneDone = PlayerProgress.initial.recordLevelStars(
      map01Levels[0].id,
      2,
    );
    final levelOneAndTwoDone = levelOneDone.recordLevelStars(
      map01Levels[1].id,
      1,
    );
    final allDone = map01Levels.fold<PlayerProgress>(
      PlayerProgress.initial,
      (progress, level) => progress.recordLevelStars(level.id, 1),
    );

    expect(
      shouldReturnToMapAfterCompletedReplay(
        progress: PlayerProgress.initial,
        levels: map01Levels,
        levelIndex: 0,
      ),
      isFalse,
    );
    expect(
      shouldReturnToMapAfterCompletedReplay(
        progress: levelOneDone,
        levels: map01Levels,
        levelIndex: 0,
      ),
      isFalse,
    );
    expect(
      shouldReturnToMapAfterCompletedReplay(
        progress: levelOneAndTwoDone,
        levels: map01Levels,
        levelIndex: 0,
      ),
      isTrue,
    );
    expect(
      shouldReturnToMapAfterCompletedReplay(
        progress: allDone,
        levels: map01Levels,
        levelIndex: map01Levels.length - 1,
      ),
      isTrue,
    );
  });

  test('completion action chooses next for fresh level progress', () {
    expect(
      completionActionForAdventureLevel(
        progress: PlayerProgress.initial,
        levels: map01Levels,
        levelIndex: 0,
      ),
      AdventureCompletionAction.next,
    );
  });

  test('completion action maps replays when next level is already done', () {
    final progress = PlayerProgress.initial
        .recordLevelStars(map01Levels[0].id, 2)
        .recordLevelStars(map01Levels[1].id, 1);

    expect(
      completionActionForAdventureLevel(
        progress: progress,
        levels: map01Levels,
        levelIndex: 0,
      ),
      AdventureCompletionAction.map,
    );
  });

  test('completion action advances replays when next level is unfinished', () {
    final progress = PlayerProgress.initial.recordLevelStars(
      map01Levels[0].id,
      2,
    );

    expect(
      completionActionForAdventureLevel(
        progress: progress,
        levels: map01Levels,
        levelIndex: 0,
      ),
      AdventureCompletionAction.next,
    );
  });

  test('completion action maps final level completion', () {
    final progress = PlayerProgress.initial.recordLevelStars(
      map01Levels.last.id,
      2,
    );

    expect(
      completionActionForAdventureLevel(
        progress: progress,
        levels: map01Levels,
        levelIndex: map01Levels.length - 1,
      ),
      AdventureCompletionAction.map,
    );
  });

  test('node states reflect lock, current, stars, and completion', () {
    final current = adventureLevelNodeState(
      progress: PlayerProgress.initial,
      levels: map01Levels,
      levelIndex: 0,
      currentLevelIndex: 0,
    );
    final locked = adventureLevelNodeState(
      progress: PlayerProgress.initial,
      levels: map01Levels,
      levelIndex: 1,
      currentLevelIndex: 0,
    );
    final oneStar = adventureLevelNodeState(
      progress: PlayerProgress.initial.recordLevelStars(map01Levels[0].id, 1),
      levels: map01Levels,
      levelIndex: 0,
      currentLevelIndex: 1,
    );
    final complete = adventureLevelNodeState(
      progress: PlayerProgress.initial.recordLevelStars(map01Levels[0].id, 3),
      levels: map01Levels,
      levelIndex: 0,
      currentLevelIndex: 1,
    );

    expect(current, AdventureLevelNodeState.current);
    expect(locked, AdventureLevelNodeState.locked);
    expect(oneStar, AdventureLevelNodeState.oneStar);
    expect(complete, AdventureLevelNodeState.complete);
  });

  test('map cards use star thresholds and playability flags', () {
    expect(adventureMapCards, hasLength(7));
    expect(adventureMapCards[0].id, 'map01');
    expect(adventureMapCards[0].unlockStarRequirement, 0);
    expect(adventureMapCards[0].playable, isTrue);
    expect(adventureMapCards[1].id, 'map02');
    expect(adventureMapCards[1].unlockStarRequirement, 15);
    expect(adventureMapCards[1].playable, isFalse);
    expect(adventureMapCards.map((map) => map.unlockStarRequirement), [
      0,
      15,
      30,
      45,
      60,
      75,
      90,
    ]);
  });

  test('map card unlocks use remaining Map01 stars', () {
    final map02 = adventureMapCards[1];

    expect(
      isAdventureMapCardUnlocked(map: adventureMapCards.first, earnedStars: 0),
      isTrue,
    );
    expect(isAdventureMapCardUnlocked(map: map02, earnedStars: 14), isFalse);
    expect(isAdventureMapCardUnlocked(map: map02, earnedStars: 15), isTrue);
    expect(adventureMapCardStarsNeeded(map: map02, earnedStars: 0), 15);
    expect(adventureMapCardStarsNeeded(map: map02, earnedStars: 10), 5);
    expect(adventureMapCardStarsNeeded(map: map02, earnedStars: 20), 0);
  });

  test('map card action keeps future maps out of gameplay', () {
    expect(
      adventureMapCardAction(map: adventureMapCards.first, earnedStars: 0),
      AdventureMapCardAction.playable,
    );
    expect(
      adventureMapCardAction(map: adventureMapCards[1], earnedStars: 14),
      AdventureMapCardAction.locked,
    );
    expect(
      adventureMapCardAction(map: adventureMapCards[1], earnedStars: 15),
      AdventureMapCardAction.comingSoon,
    );
  });
}
