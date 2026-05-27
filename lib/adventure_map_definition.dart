import 'dart:ui';

import 'game/models/level_definition.dart';
import 'game/models/level_set_id.dart';
import 'game/models/player_progress.dart';

const adventureMap01 = AdventureMapDefinition(
  id: 'map01',
  title: 'Lushbug Jungle',
  levelSetId: LevelSetId.map01,
  backgroundAsset: 'assets/images/adventure/maps/jungle/jungle_map3.png',
  canvasSize: Size(823, 2544),
  nodes: [
    AdventureLevelNodeDefinition(levelIndex: 0, center: Offset(404, 1956)),
    AdventureLevelNodeDefinition(levelIndex: 1, center: Offset(399, 1774)),
    AdventureLevelNodeDefinition(levelIndex: 2, center: Offset(436, 1615)),
    AdventureLevelNodeDefinition(levelIndex: 3, center: Offset(404, 1459)),
    AdventureLevelNodeDefinition(levelIndex: 4, center: Offset(412, 1269)),
    AdventureLevelNodeDefinition(levelIndex: 5, center: Offset(404, 1110)),
    AdventureLevelNodeDefinition(levelIndex: 6, center: Offset(382, 950)),
    AdventureLevelNodeDefinition(levelIndex: 7, center: Offset(447, 790)),
    AdventureLevelNodeDefinition(levelIndex: 8, center: Offset(412, 639)),
  ],
);

const adventureMapCards = <AdventureMapCardDefinition>[
  AdventureMapCardDefinition(
    id: 'map01',
    title: 'Lushbug Jungle',
    asset: 'assets/images/adventure/map01.png',
    unlockStarRequirement: 0,
    playable: true,
  ),
  AdventureMapCardDefinition(
    id: 'map02',
    title: 'Desert Oasis',
    asset: 'assets/images/adventure/map02.png',
    unlockStarRequirement: 15,
  ),
  AdventureMapCardDefinition(
    id: 'map03',
    title: 'Firefly Nightfall',
    asset: 'assets/images/adventure/map03.png',
    unlockStarRequirement: 30,
  ),
  AdventureMapCardDefinition(
    id: 'map04',
    title: 'Map 04',
    asset: 'assets/images/adventure/map04.png',
    unlockStarRequirement: 45,
  ),
  AdventureMapCardDefinition(
    id: 'map05',
    title: 'Map 05',
    asset: 'assets/images/adventure/map05.png',
    unlockStarRequirement: 60,
  ),
  AdventureMapCardDefinition(
    id: 'map06',
    title: 'Map 06',
    asset: 'assets/images/adventure/map06.png',
    unlockStarRequirement: 75,
  ),
  AdventureMapCardDefinition(
    id: 'map07',
    title: 'Map 07',
    asset: 'assets/images/adventure/map07.png',
    unlockStarRequirement: 90,
  ),
];

class AdventureMapCardDefinition {
  const AdventureMapCardDefinition({
    required this.id,
    required this.title,
    required this.asset,
    required this.unlockStarRequirement,
    this.playable = false,
  });

  final String id;
  final String title;
  final String asset;
  final int unlockStarRequirement;
  final bool playable;
}

class AdventureMapDefinition {
  const AdventureMapDefinition({
    required this.id,
    required this.title,
    required this.levelSetId,
    required this.backgroundAsset,
    required this.canvasSize,
    required this.nodes,
  });

  final String id;
  final String title;
  final LevelSetId levelSetId;
  final String backgroundAsset;
  final Size canvasSize;
  final List<AdventureLevelNodeDefinition> nodes;
}

class AdventureLevelNodeDefinition {
  const AdventureLevelNodeDefinition({
    required this.levelIndex,
    required this.center,
  });

  final int levelIndex;
  final Offset center;
}

enum AdventureLevelNodeState {
  locked,
  unlocked,
  current,
  oneStar,
  twoStar,
  complete,
}

enum AdventureCompletionAction { next, map }

enum AdventureMapCardAction { locked, playable, comingSoon }

bool isAdventureLevelUnlocked({
  required PlayerProgress progress,
  required List<LevelDefinition> levels,
  required int levelIndex,
}) {
  if (levelIndex < 0 || levelIndex >= levels.length) {
    return false;
  }
  if (levelIndex == 0) {
    return true;
  }
  return progress.starsForLevel(levels[levelIndex - 1].id) > 0;
}

int firstAdventureLevelIndex({
  required PlayerProgress progress,
  required List<LevelDefinition> levels,
}) {
  for (var index = 0; index < levels.length; index += 1) {
    if (isAdventureLevelUnlocked(
          progress: progress,
          levels: levels,
          levelIndex: index,
        ) &&
        progress.starsForLevel(levels[index].id) == 0) {
      return index;
    }
  }

  for (var index = levels.length - 1; index >= 0; index -= 1) {
    if (isAdventureLevelUnlocked(
      progress: progress,
      levels: levels,
      levelIndex: index,
    )) {
      return index;
    }
  }

  return 0;
}

bool shouldReturnToMapAfterCompletedReplay({
  required PlayerProgress progress,
  required List<LevelDefinition> levels,
  required int levelIndex,
}) {
  if (levelIndex < 0 || levelIndex >= levels.length) {
    return false;
  }
  if (progress.starsForLevel(levels[levelIndex].id) == 0) {
    return false;
  }

  final nextLevelIndex = levelIndex + 1;
  if (nextLevelIndex >= levels.length) {
    return true;
  }
  return progress.starsForLevel(levels[nextLevelIndex].id) > 0;
}

AdventureCompletionAction completionActionForAdventureLevel({
  required PlayerProgress progress,
  required List<LevelDefinition> levels,
  required int levelIndex,
}) {
  if (levelIndex < 0 || levelIndex >= levels.length) {
    return AdventureCompletionAction.map;
  }

  final nextLevelIndex = levelIndex + 1;
  if (nextLevelIndex >= levels.length) {
    return AdventureCompletionAction.map;
  }

  final replayingCompletedLevel =
      progress.starsForLevel(levels[levelIndex].id) > 0;
  final nextLevelCompleted =
      progress.starsForLevel(levels[nextLevelIndex].id) > 0;
  if (replayingCompletedLevel && nextLevelCompleted) {
    return AdventureCompletionAction.map;
  }

  return AdventureCompletionAction.next;
}

bool isAdventureMapCardUnlocked({
  required AdventureMapCardDefinition map,
  required int earnedStars,
}) {
  return earnedStars >= map.unlockStarRequirement;
}

int adventureMapCardStarsNeeded({
  required AdventureMapCardDefinition map,
  required int earnedStars,
}) {
  final remaining = map.unlockStarRequirement - earnedStars;
  if (remaining <= 0) {
    return 0;
  }
  return remaining;
}

AdventureMapCardAction adventureMapCardAction({
  required AdventureMapCardDefinition map,
  required int earnedStars,
}) {
  if (!isAdventureMapCardUnlocked(map: map, earnedStars: earnedStars)) {
    return AdventureMapCardAction.locked;
  }
  if (map.playable) {
    return AdventureMapCardAction.playable;
  }
  return AdventureMapCardAction.comingSoon;
}

AdventureLevelNodeState adventureLevelNodeState({
  required PlayerProgress progress,
  required List<LevelDefinition> levels,
  required int levelIndex,
  required int currentLevelIndex,
}) {
  if (!isAdventureLevelUnlocked(
    progress: progress,
    levels: levels,
    levelIndex: levelIndex,
  )) {
    return AdventureLevelNodeState.locked;
  }

  final stars = progress.starsForLevel(levels[levelIndex].id);
  if (stars >= 3) {
    return AdventureLevelNodeState.complete;
  }
  if (stars == 2) {
    return AdventureLevelNodeState.twoStar;
  }
  if (stars == 1) {
    return AdventureLevelNodeState.oneStar;
  }
  if (levelIndex == currentLevelIndex) {
    return AdventureLevelNodeState.current;
  }
  return AdventureLevelNodeState.unlocked;
}
