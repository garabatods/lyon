import 'board_piece.dart';
import 'bug_color.dart';
import 'objective.dart';

class ObjectiveProgress {
  const ObjectiveProgress({
    this.glowsCreated = 0,
    this.bugsMoved = 0,
    this.clearedTotal = 0,
    this.clearedBig = 0,
    this.splitBig = 0,
    this.clearedByColor = const <BugColor, int>{},
    this.highestCascade = 0,
    this.highestDanger = 0,
    this.boardCleared = false,
    this.survivalSeconds = 0,
  });

  static const empty = ObjectiveProgress();

  final int glowsCreated;
  final int bugsMoved;
  final int clearedTotal;
  final int clearedBig;
  final int splitBig;
  final Map<BugColor, int> clearedByColor;
  final int highestCascade;
  final int highestDanger;
  final bool boardCleared;
  final double survivalSeconds;

  ObjectiveProgress registerGlowCreated() {
    return ObjectiveProgress(
      glowsCreated: glowsCreated + 1,
      bugsMoved: bugsMoved,
      clearedTotal: clearedTotal,
      clearedBig: clearedBig,
      splitBig: splitBig,
      clearedByColor: clearedByColor,
      highestCascade: highestCascade,
      highestDanger: highestDanger,
      boardCleared: boardCleared,
      survivalSeconds: survivalSeconds,
    );
  }

  ObjectiveProgress registerBugMoved() {
    return ObjectiveProgress(
      glowsCreated: glowsCreated,
      bugsMoved: bugsMoved + 1,
      clearedTotal: clearedTotal,
      clearedBig: clearedBig,
      splitBig: splitBig,
      clearedByColor: clearedByColor,
      highestCascade: highestCascade,
      highestDanger: highestDanger,
      boardCleared: boardCleared,
      survivalSeconds: survivalSeconds,
    );
  }

  ObjectiveProgress registerClear(
    List<BoardPiece> removed, {
    required int cascadeCount,
    required bool boardCleared,
    int bigSplitCount = 0,
    bool countClearValues = true,
  }) {
    final nextByColor = Map<BugColor, int>.from(clearedByColor);
    var nextTotal = clearedTotal;
    var nextBig = clearedBig;

    if (countClearValues) {
      for (final piece in removed) {
        final value = piece.clearValue;
        if (value <= 0) {
          continue;
        }
        nextTotal += value;
        nextByColor[piece.color] = (nextByColor[piece.color] ?? 0) + value;
        if (piece.isBigAnchor) {
          nextBig += 1;
        }
      }
    }

    return ObjectiveProgress(
      glowsCreated: glowsCreated,
      bugsMoved: bugsMoved,
      clearedTotal: nextTotal,
      clearedBig: nextBig,
      splitBig: splitBig + bigSplitCount,
      clearedByColor: nextByColor,
      highestCascade: highestCascade < cascadeCount
          ? cascadeCount
          : highestCascade,
      highestDanger: highestDanger,
      boardCleared: this.boardCleared || boardCleared,
      survivalSeconds: survivalSeconds,
    );
  }

  ObjectiveProgress registerDanger(int danger) {
    final nextDanger = danger > highestDanger ? danger : highestDanger;
    return ObjectiveProgress(
      glowsCreated: glowsCreated,
      bugsMoved: bugsMoved,
      clearedTotal: clearedTotal,
      clearedBig: clearedBig,
      splitBig: splitBig,
      clearedByColor: clearedByColor,
      highestCascade: highestCascade,
      highestDanger: nextDanger,
      boardCleared: boardCleared,
      survivalSeconds: survivalSeconds,
    );
  }

  ObjectiveProgress markBoardCleared(bool boardCleared) {
    if (!boardCleared || this.boardCleared) {
      return this;
    }
    return ObjectiveProgress(
      glowsCreated: glowsCreated,
      bugsMoved: bugsMoved,
      clearedTotal: clearedTotal,
      clearedBig: clearedBig,
      splitBig: splitBig,
      clearedByColor: clearedByColor,
      highestCascade: highestCascade,
      highestDanger: highestDanger,
      boardCleared: true,
      survivalSeconds: survivalSeconds,
    );
  }

  ObjectiveProgress registerSurvival(double seconds) {
    if (seconds <= 0) {
      return this;
    }
    return ObjectiveProgress(
      glowsCreated: glowsCreated,
      bugsMoved: bugsMoved,
      clearedTotal: clearedTotal,
      clearedBig: clearedBig,
      splitBig: splitBig,
      clearedByColor: clearedByColor,
      highestCascade: highestCascade,
      highestDanger: highestDanger,
      boardCleared: boardCleared,
      survivalSeconds: survivalSeconds + seconds,
    );
  }

  int valueFor(Objective objective) {
    return switch (objective.type) {
      ObjectiveType.makeGlow => glowsCreated,
      ObjectiveType.moveBug => bugsMoved,
      ObjectiveType.clearColor => clearedByColor[objective.color] ?? 0,
      ObjectiveType.clearTotal => clearedTotal,
      ObjectiveType.clearBig => clearedBig,
      ObjectiveType.splitBig => splitBig,
      ObjectiveType.reachCascade => highestCascade,
      ObjectiveType.reachDanger => highestDanger,
      ObjectiveType.clearAll => boardCleared ? 1 : 0,
      ObjectiveType.surviveSeconds => survivalSeconds.floor(),
    };
  }

  int targetFor(Objective objective) => objective.target;

  bool isComplete(Objective objective) {
    return valueFor(objective) >= targetFor(objective);
  }

  Map<String, Object?> toJson() {
    return {
      'glowsCreated': glowsCreated,
      'bugsMoved': bugsMoved,
      'clearedTotal': clearedTotal,
      'clearedBig': clearedBig,
      'splitBig': splitBig,
      'clearedByColor': {
        for (final entry in clearedByColor.entries) entry.key.name: entry.value,
      },
      'highestCascade': highestCascade,
      'highestDanger': highestDanger,
      'boardCleared': boardCleared,
      'survivalSeconds': survivalSeconds,
    };
  }

  static ObjectiveProgress fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) {
      return empty;
    }

    final colorsJson = json['clearedByColor'];
    final byColor = <BugColor, int>{};
    if (colorsJson is Map) {
      for (final entry in colorsJson.entries) {
        final color = _enumByName(BugColor.values, entry.key);
        final value = _asInt(entry.value);
        if (color != null && value != null) {
          byColor[color] = value.clamp(0, 999999).toInt();
        }
      }
    }

    return ObjectiveProgress(
      glowsCreated: (_asInt(json['glowsCreated']) ?? 0)
          .clamp(0, 999999)
          .toInt(),
      bugsMoved: (_asInt(json['bugsMoved']) ?? 0).clamp(0, 999999).toInt(),
      clearedTotal: (_asInt(json['clearedTotal']) ?? 0)
          .clamp(0, 999999)
          .toInt(),
      clearedBig: (_asInt(json['clearedBig']) ?? 0).clamp(0, 999999).toInt(),
      splitBig: (_asInt(json['splitBig']) ?? 0).clamp(0, 999999).toInt(),
      clearedByColor: byColor,
      highestCascade: (_asInt(json['highestCascade']) ?? 0)
          .clamp(0, 999)
          .toInt(),
      highestDanger: (_asInt(json['highestDanger']) ?? 0).clamp(0, 999).toInt(),
      boardCleared: json['boardCleared'] == true,
      survivalSeconds: (_asDouble(json['survivalSeconds']) ?? 0)
          .clamp(0, 999999)
          .toDouble(),
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
    if (value is num && value.isFinite) {
      return value.toDouble();
    }
    return null;
  }
}
