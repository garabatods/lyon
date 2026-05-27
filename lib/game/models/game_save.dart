import 'dart:convert';

import 'board_piece.dart';
import 'board_state.dart';
import 'bug_color.dart';
import 'chameleon_state.dart';
import 'game_mode.dart';
import 'level_set_id.dart';
import 'objective_progress.dart';
import 'power_up.dart';

class GameSave {
  const GameSave({
    required this.levelSetId,
    required this.levelIndex,
    required this.mode,
    required this.columns,
    required this.chameleon,
    required this.score,
    required this.highestCascade,
    required this.currentArcadeLevel,
    required this.nextLevelScore,
    required this.combo,
    required this.comboRemaining,
    required this.danger,
    required this.powerCounts,
    required this.objectiveProgress,
    required this.timeRemaining,
    required this.refillTimer,
    required this.facingRight,
    required this.nextBigBugId,
  });

  static const currentVersion = 1;
  static const _legacyRequiredTutorialLevels = 6;

  final LevelSetId levelSetId;
  final int levelIndex;
  final GameMode mode;
  final List<List<BoardPiece>> columns;
  final ChameleonState chameleon;
  final int score;
  final int highestCascade;
  final int currentArcadeLevel;
  final int nextLevelScore;
  final int combo;
  final double comboRemaining;
  final int danger;
  final Map<PowerUpType, int> powerCounts;
  final ObjectiveProgress objectiveProgress;
  final double timeRemaining;
  final double refillTimer;
  final bool facingRight;
  final int nextBigBugId;

  BoardState toBoardState() => BoardState.fromPieces(columns);

  String encode() => jsonEncode(toJson());

  Map<String, Object?> toJson() {
    return {
      'version': currentVersion,
      'levelSetId': levelSetId.name,
      'levelIndex': levelIndex,
      'mode': mode.name,
      'columns': [
        for (final column in columns)
          [for (final piece in column) _pieceToJson(piece)],
      ],
      'chameleon': {
        'columnIndex': chameleon.columnIndex,
        'heldColor': chameleon.heldColor?.name,
        'heldCharged': chameleon.heldCharged,
        'swallowedCount': chameleon.swallowedCount,
      },
      'score': score,
      'highestCascade': highestCascade,
      'currentArcadeLevel': currentArcadeLevel,
      'nextLevelScore': nextLevelScore,
      'combo': combo,
      'comboRemaining': comboRemaining,
      'danger': danger,
      'powerCounts': {
        for (final entry in powerCounts.entries) entry.key.name: entry.value,
      },
      'objectiveProgress': objectiveProgress.toJson(),
      'timeRemaining': timeRemaining,
      'refillTimer': refillTimer,
      'facingRight': facingRight,
      'nextBigBugId': nextBigBugId,
    };
  }

  static GameSave? decode(String encoded) {
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

  static GameSave? fromJson(Map<String, Object?> json) {
    if (_asInt(json['version']) != currentVersion) {
      return null;
    }

    final columnsJson = json['columns'];
    if (columnsJson is! List || columnsJson.length != BoardState.columnCount) {
      return null;
    }

    final columns = <List<BoardPiece>>[];
    for (final columnJson in columnsJson) {
      if (columnJson is! List || columnJson.length > BoardState.rowCount) {
        return null;
      }
      final column = <BoardPiece>[];
      for (final pieceJson in columnJson) {
        if (pieceJson is! Map) {
          return null;
        }
        final piece = _pieceFromJson(pieceJson);
        if (piece == null) {
          return null;
        }
        column.add(piece);
      }
      columns.add(column);
    }

    final chameleonJson = json['chameleon'];
    if (chameleonJson is! Map) {
      return null;
    }
    final columnIndex = _asInt(chameleonJson['columnIndex']);
    if (columnIndex == null ||
        columnIndex < 0 ||
        columnIndex >= BoardState.columnCount) {
      return null;
    }
    final heldColor = _enumByName(BugColor.values, chameleonJson['heldColor']);
    final heldCharged = _asBool(chameleonJson['heldCharged']) ?? false;
    final swallowedCount = (_asInt(chameleonJson['swallowedCount']) ?? 0)
        .clamp(0, 2)
        .toInt();
    if (chameleonJson['heldColor'] != null && heldColor == null) {
      return null;
    }

    final powerCountsJson = json['powerCounts'];
    if (powerCountsJson is! Map) {
      return null;
    }
    final powerCounts = <PowerUpType, int>{};
    for (final entry in powerCountsJson.entries) {
      final type = _enumByName(PowerUpType.values, entry.key);
      final count = _asInt(entry.value);
      if (type != null && count != null) {
        powerCounts[type] = count.clamp(0, 999).toInt();
      }
    }

    final mode =
        _enumByName(GameMode.values, json['mode']) ?? GameMode.timeTrial;
    final objectiveProgressJson = json['objectiveProgress'];
    final objectiveProgress = objectiveProgressJson is Map
        ? ObjectiveProgress.fromJson(objectiveProgressJson)
        : ObjectiveProgress.empty;

    final score = _asInt(json['score']);
    final highestCascade = _asInt(json['highestCascade']);
    final currentArcadeLevel = _asInt(json['currentArcadeLevel']);
    final nextLevelScore = _asInt(json['nextLevelScore']);
    final combo = _asInt(json['combo']);
    final danger = _asInt(json['danger']);
    final nextBigBugId = _asInt(json['nextBigBugId']);
    final timeRemaining = _asDouble(json['timeRemaining']);
    final refillTimer = _asDouble(json['refillTimer']);
    final comboRemaining = _asDouble(json['comboRemaining']);
    final facingRight = _asBool(json['facingRight']);

    if (score == null ||
        highestCascade == null ||
        currentArcadeLevel == null ||
        nextLevelScore == null ||
        combo == null ||
        danger == null ||
        nextBigBugId == null ||
        timeRemaining == null ||
        refillTimer == null ||
        comboRemaining == null ||
        facingRight == null) {
      return null;
    }

    final rawLevelIndex = (_asInt(json['levelIndex']) ?? 0)
        .clamp(0, 999)
        .toInt();
    final decodedLevelSet = _enumByName(LevelSetId.values, json['levelSetId']);
    final levelSetId =
        decodedLevelSet ??
        (rawLevelIndex < _legacyRequiredTutorialLevels
            ? LevelSetId.tutorial
            : LevelSetId.map01);
    final levelIndex =
        decodedLevelSet == null &&
            rawLevelIndex >= _legacyRequiredTutorialLevels
        ? rawLevelIndex - _legacyRequiredTutorialLevels
        : rawLevelIndex;

    return GameSave(
      levelSetId: levelSetId,
      levelIndex: levelIndex,
      mode: mode,
      columns: columns,
      chameleon: ChameleonState(
        columnIndex: columnIndex,
        heldColor: heldColor,
        heldCharged: heldColor != null && heldCharged,
        swallowedCount: heldColor == null ? 0 : swallowedCount,
      ),
      score: score.clamp(0, 99999999).toInt(),
      highestCascade: highestCascade.clamp(0, 999).toInt(),
      currentArcadeLevel: currentArcadeLevel.clamp(1, 999).toInt(),
      nextLevelScore: nextLevelScore.clamp(1, 99999999).toInt(),
      combo: combo.clamp(0, 999).toInt(),
      comboRemaining: comboRemaining.clamp(0, 30).toDouble(),
      danger: danger.clamp(0, 99).toInt(),
      powerCounts: powerCounts,
      objectiveProgress: objectiveProgress,
      timeRemaining: timeRemaining.clamp(0, 180).toDouble(),
      refillTimer: refillTimer.clamp(0, 30).toDouble(),
      facingRight: facingRight,
      nextBigBugId: nextBigBugId.clamp(1, 999999).toInt(),
    );
  }

  static Map<String, Object?> _pieceToJson(BoardPiece piece) {
    return {
      'color': piece.color.name,
      'charged': piece.charged,
      'type': piece.type.name,
      'bigId': piece.bigId,
    };
  }

  static BoardPiece? _pieceFromJson(Map<dynamic, dynamic> json) {
    final color = _enumByName(BugColor.values, json['color']);
    final type = _enumByName(BoardPieceType.values, json['type']);
    if (color == null || type == null) {
      return null;
    }
    return BoardPiece(
      color,
      charged: _asBool(json['charged']) ?? false,
      type: type,
      bigId: _asInt(json['bigId']),
    );
  }

  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) {
      return null;
    }
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is double && value.isFinite) {
      return value.round();
    }
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is int) {
      return value.toDouble();
    }
    if (value is double && value.isFinite) {
      return value;
    }
    return null;
  }

  static bool? _asBool(Object? value) => value is bool ? value : null;
}
