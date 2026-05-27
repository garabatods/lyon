import 'dart:convert';

import 'game_mode.dart';

class PlayerProgress {
  const PlayerProgress({
    required this.hasSeenTutorialIntro,
    required this.highestTutorialLevelCompleted,
    required this.unlockedModes,
    required this.bestStarsByLevelId,
  });

  static const currentVersion = 1;
  static const requiredTutorialLevels = 6;

  static const initial = PlayerProgress(
    hasSeenTutorialIntro: false,
    highestTutorialLevelCompleted: 0,
    unlockedModes: <GameMode>{},
    bestStarsByLevelId: <String, int>{},
  );

  final bool hasSeenTutorialIntro;
  final int highestTutorialLevelCompleted;
  final Set<GameMode> unlockedModes;
  final Map<String, int> bestStarsByLevelId;

  bool get tutorialCompleted =>
      highestTutorialLevelCompleted >= requiredTutorialLevels;

  bool isModeUnlocked(GameMode mode) {
    return tutorialCompleted || unlockedModes.contains(mode);
  }

  PlayerProgress copyWith({
    bool? hasSeenTutorialIntro,
    int? highestTutorialLevelCompleted,
    Set<GameMode>? unlockedModes,
    Map<String, int>? bestStarsByLevelId,
  }) {
    return PlayerProgress(
      hasSeenTutorialIntro: hasSeenTutorialIntro ?? this.hasSeenTutorialIntro,
      highestTutorialLevelCompleted:
          highestTutorialLevelCompleted ?? this.highestTutorialLevelCompleted,
      unlockedModes: unlockedModes ?? this.unlockedModes,
      bestStarsByLevelId: bestStarsByLevelId ?? this.bestStarsByLevelId,
    );
  }

  PlayerProgress markTutorialIntroSeen() {
    return copyWith(hasSeenTutorialIntro: true);
  }

  PlayerProgress completeTutorialLevel(int levelNumber) {
    final nextHighest = levelNumber > highestTutorialLevelCompleted
        ? levelNumber
        : highestTutorialLevelCompleted;
    final nextModes = Set<GameMode>.from(unlockedModes);
    if (nextHighest >= requiredTutorialLevels) {
      nextModes
        ..add(GameMode.adventure)
        ..add(GameMode.timeTrial);
    }
    return copyWith(
      highestTutorialLevelCompleted: nextHighest,
      unlockedModes: nextModes,
    );
  }

  int starsForLevel(String levelId) {
    return bestStarsByLevelId[levelId] ?? 0;
  }

  int totalStarsForLevelIds(Iterable<String> levelIds) {
    var total = 0;
    for (final levelId in levelIds) {
      total += starsForLevel(levelId);
    }
    return total;
  }

  PlayerProgress recordLevelStars(String levelId, int stars) {
    final normalizedStars = stars.clamp(0, 3).toInt();
    final currentStars = starsForLevel(levelId);
    if (normalizedStars <= currentStars) {
      return this;
    }
    return copyWith(
      bestStarsByLevelId: {...bestStarsByLevelId, levelId: normalizedStars},
    );
  }

  String encode() => jsonEncode(toJson());

  Map<String, Object?> toJson() {
    return {
      'version': currentVersion,
      'hasSeenTutorialIntro': hasSeenTutorialIntro,
      'highestTutorialLevelCompleted': highestTutorialLevelCompleted,
      'unlockedModes': [for (final mode in unlockedModes) mode.name],
      'bestStarsByLevelId': bestStarsByLevelId,
    };
  }

  static PlayerProgress? decode(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      return fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  static PlayerProgress? fromJson(Map<String, Object?> json) {
    if (json['version'] != currentVersion) {
      return null;
    }

    final unlockedJson = json['unlockedModes'];
    final unlockedModes = <GameMode>{};
    if (unlockedJson is List) {
      for (final value in unlockedJson) {
        final mode = _modeByName(value);
        if (mode != null) {
          unlockedModes.add(mode);
        }
      }
    }

    final starsJson = json['bestStarsByLevelId'];
    final bestStarsByLevelId = <String, int>{};
    if (starsJson is Map) {
      for (final entry in starsJson.entries) {
        final levelId = entry.key;
        final stars = _asInt(entry.value);
        if (levelId is String && stars != null) {
          bestStarsByLevelId[levelId] = stars.clamp(0, 3).toInt();
        }
      }
    }

    return PlayerProgress(
      hasSeenTutorialIntro: json['hasSeenTutorialIntro'] == true,
      highestTutorialLevelCompleted:
          _asInt(
            json['highestTutorialLevelCompleted'],
          )?.clamp(0, 999).toInt() ??
          0,
      unlockedModes: unlockedModes,
      bestStarsByLevelId: bestStarsByLevelId,
    );
  }

  static GameMode? _modeByName(Object? name) {
    if (name is! String) {
      return null;
    }
    for (final mode in GameMode.values) {
      if (mode.name == name) {
        return mode;
      }
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}
