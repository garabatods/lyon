import 'dart:math';

import '../models/board_piece.dart';
import '../models/board_state.dart';
import '../models/bug_color.dart';
import 'match_system.dart';

class PressureRowGenerator {
  PressureRowGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;
  final MatchSystem _matchSystem = MatchSystem();

  List<BoardPiece> spawnRow({
    required BoardState board,
    required int arcadeLevel,
  }) {
    final tuning = _PressureTuning.forLevel(arcadeLevel);
    final palette = _paletteFor(board, tuning);
    final wantsBigSetup =
        _bigAnchorCount(board) < tuning.maxBigBugs &&
        _random.nextDouble() < tuning.bigSetupChance;

    var bestColors = _randomCandidate(board, palette, tuning, wantsBigSetup);
    var bestScore = _scoreCandidate(board, bestColors, tuning, wantsBigSetup);

    for (var attempt = 0; attempt < tuning.candidateAttempts; attempt += 1) {
      final colors = _randomCandidate(board, palette, tuning, wantsBigSetup);
      final score = _scoreCandidate(board, colors, tuning, wantsBigSetup);
      if (score > bestScore) {
        bestColors = colors;
        bestScore = score;
      }
    }

    return [for (final color in bestColors) BoardPiece(color)];
  }

  List<BugColor> _paletteFor(BoardState board, _PressureTuning tuning) {
    final colors = <BugColor>{...tuning.unlockedColors};
    for (final column in board.columns) {
      for (final piece in column) {
        colors.add(piece.color);
      }
    }
    return colors.toList();
  }

  List<BugColor> _randomCandidate(
    BoardState board,
    List<BugColor> palette,
    _PressureTuning tuning,
    bool wantsBigSetup,
  ) {
    final colors = <BugColor>[
      for (var column = 0; column < BoardState.columnCount; column += 1)
        _weightedColorFor(board, column, palette),
    ];

    _breakLongRuns(colors, palette);
    if (_random.nextDouble() < tuning.pairChance) {
      _placeLoosePair(board, colors, palette);
    }
    if (wantsBigSetup) {
      _tryPlaceBigSetup(board, colors, palette);
    }
    _breakLongRuns(colors, palette);
    return colors;
  }

  BugColor _weightedColorFor(
    BoardState board,
    int column,
    List<BugColor> palette,
  ) {
    final demand = _bigDemandByColor(board);
    final normalCounts = _normalCountsByColor(board);
    final options = <BugColor>[];

    for (final color in palette) {
      var weight = 6;
      weight += min(8, (demand[color] ?? 0) * 4);
      if ((normalCounts[color] ?? 0) < 2) {
        weight += 3;
      }
      if (board.colorAt(column, 0) == color) {
        weight += 2;
      }
      for (var i = 0; i < weight; i += 1) {
        options.add(color);
      }
    }

    return options[_random.nextInt(options.length)];
  }

  void _placeLoosePair(
    BoardState board,
    List<BugColor> colors,
    List<BugColor> palette,
  ) {
    final starts = List<int>.generate(
      BoardState.columnCount - 1,
      (index) => index,
    )..shuffle(_random);
    final demand = _bigDemandByColor(board);
    final pairColors = palette.toList()
      ..sort((a, b) => (demand[b] ?? 0).compareTo(demand[a] ?? 0));

    for (final start in starts) {
      for (final color in pairColors) {
        final previousLeft = colors[start];
        final previousRight = colors[start + 1];
        colors[start] = color;
        colors[start + 1] = color;
        final createsBig = _immediatePromotionCount(board, colors) > 0;
        final createsRun =
            _hasHorizontalRun(colors, color, start) ||
            _hasHorizontalRun(colors, color, start + 1);
        if (!createsBig && !createsRun) {
          return;
        }
        colors[start] = previousLeft;
        colors[start + 1] = previousRight;
      }
    }
  }

  void _tryPlaceBigSetup(
    BoardState board,
    List<BugColor> colors,
    List<BugColor> palette,
  ) {
    final starts = List<int>.generate(
      BoardState.columnCount - 1,
      (index) => index,
    )..shuffle(_random);
    for (final start in starts) {
      final left = board.pieceAt(start, 0);
      final right = board.pieceAt(start + 1, 0);
      if (left == null || right == null || left.isBig || right.isBig) {
        continue;
      }
      if (left.color != right.color || !palette.contains(left.color)) {
        continue;
      }
      colors[start] = left.color;
      colors[start + 1] = left.color;
      return;
    }
  }

  void _breakLongRuns(List<BugColor> colors, List<BugColor> palette) {
    for (var column = 2; column < colors.length; column += 1) {
      if (colors[column] != colors[column - 1] ||
          colors[column] != colors[column - 2]) {
        continue;
      }
      final options = palette
          .where((color) => color != colors[column])
          .toList();
      colors[column] = options[_random.nextInt(options.length)];
    }
  }

  bool _hasHorizontalRun(List<BugColor> colors, BugColor color, int column) {
    final start = max(0, column - 2);
    final end = min(colors.length - 1, column + 2);
    var run = 0;
    for (var index = start; index <= end; index += 1) {
      if (colors[index] == color) {
        run += 1;
        if (run >= 3) {
          return true;
        }
      } else {
        run = 0;
      }
    }
    return false;
  }

  int _scoreCandidate(
    BoardState board,
    List<BugColor> colors,
    _PressureTuning tuning,
    bool wantsBigSetup,
  ) {
    final immediatePromotions = _immediatePromotionCount(board, colors);
    final existingBigs = _bigAnchorCount(board);
    var score = _random.nextInt(4);

    if (existingBigs >= tuning.maxBigBugs && immediatePromotions > 0) {
      score -= 1000;
    }
    if (immediatePromotions > tuning.maxImmediatePromotions) {
      score -= 700 * (immediatePromotions - tuning.maxImmediatePromotions);
    }
    if (immediatePromotions > 0) {
      score += wantsBigSetup ? 24 : -18;
    }

    final demand = _bigDemandByColor(board);
    final uniqueColors = colors.toSet().length;
    score += uniqueColors * 5;

    for (var column = 0; column < colors.length; column += 1) {
      final color = colors[column];
      if ((demand[color] ?? 0) > 0) {
        score += 6;
      }
      if (board.colorAt(column, 0) == color) {
        score += 2;
      }
      if (column > 0 && colors[column - 1] == color) {
        score += 3;
      }
    }

    for (var column = 2; column < colors.length; column += 1) {
      if (colors[column] == colors[column - 1] &&
          colors[column] == colors[column - 2]) {
        score -= 40;
      }
    }

    return score;
  }

  int _immediatePromotionCount(BoardState board, List<BugColor> colors) {
    final copy = board.copy();
    copy.insertTopRow([for (final color in colors) BoardPiece(color)]);
    return _matchSystem.findBigPromotions(copy).length;
  }

  int _bigAnchorCount(BoardState board) {
    var count = 0;
    for (final column in board.columns) {
      for (final piece in column) {
        if (piece.isBigAnchor) {
          count += 1;
        }
      }
    }
    return count;
  }

  Map<BugColor, int> _bigDemandByColor(BoardState board) {
    final demand = <BugColor, int>{};
    for (final column in board.columns) {
      for (final piece in column) {
        if (piece.isBigAnchor) {
          demand[piece.color] = (demand[piece.color] ?? 0) + 1;
        }
      }
    }
    return demand;
  }

  Map<BugColor, int> _normalCountsByColor(BoardState board) {
    final counts = <BugColor, int>{};
    for (final column in board.columns) {
      for (final piece in column) {
        if (!piece.isBig && !piece.charged) {
          counts[piece.color] = (counts[piece.color] ?? 0) + 1;
        }
      }
    }
    return counts;
  }
}

class _PressureTuning {
  const _PressureTuning({
    required this.unlockedColors,
    required this.pairChance,
    required this.bigSetupChance,
    required this.maxBigBugs,
    required this.maxImmediatePromotions,
    required this.candidateAttempts,
  });

  final List<BugColor> unlockedColors;
  final double pairChance;
  final double bigSetupChance;
  final int maxBigBugs;
  final int maxImmediatePromotions;
  final int candidateAttempts;

  factory _PressureTuning.forLevel(int level) {
    if (level <= 1) {
      return const _PressureTuning(
        unlockedColors: [BugColor.red, BugColor.blue, BugColor.yellow],
        pairChance: 0.22,
        bigSetupChance: 0,
        maxBigBugs: 0,
        maxImmediatePromotions: 0,
        candidateAttempts: 36,
      );
    }
    if (level == 2) {
      return const _PressureTuning(
        unlockedColors: [
          BugColor.red,
          BugColor.blue,
          BugColor.yellow,
          BugColor.orange,
        ],
        pairChance: 0.28,
        bigSetupChance: 0.08,
        maxBigBugs: 1,
        maxImmediatePromotions: 1,
        candidateAttempts: 42,
      );
    }
    if (level == 3) {
      return const _PressureTuning(
        unlockedColors: BugColor.active,
        pairChance: 0.34,
        bigSetupChance: 0.14,
        maxBigBugs: 2,
        maxImmediatePromotions: 1,
        candidateAttempts: 48,
      );
    }
    if (level == 4) {
      return const _PressureTuning(
        unlockedColors: BugColor.active,
        pairChance: 0.40,
        bigSetupChance: 0.20,
        maxBigBugs: 3,
        maxImmediatePromotions: 1,
        candidateAttempts: 54,
      );
    }
    return _PressureTuning(
      unlockedColors: BugColor.active,
      pairChance: min(0.52, 0.42 + (level - 5) * 0.025),
      bigSetupChance: min(0.34, 0.24 + (level - 5) * 0.02),
      maxBigBugs: min(6, 4 + ((level - 5) ~/ 2)),
      maxImmediatePromotions: 1,
      candidateAttempts: 60,
    );
  }
}
