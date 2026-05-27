import 'dart:math';

import '../models/board_piece.dart';
import '../models/board_state.dart';
import '../models/bug_color.dart';
import '../models/level_definition.dart';
import '../models/objective.dart';
import '../models/objective_progress.dart';
import 'level_rules_simulator.dart';
import 'level_solver.dart';
import 'match_system.dart';

class RescueBug {
  const RescueBug({required this.column, required this.color});

  final int column;
  final BugColor color;
}

class RescuePlan {
  const RescuePlan._({
    required this.bugs,
    required this.reason,
    required this.solverProven,
  });

  factory RescuePlan.none(String reason) {
    return RescuePlan._(
      bugs: const <RescueBug>[],
      reason: reason,
      solverProven: true,
    );
  }

  factory RescuePlan.add({
    required List<RescueBug> bugs,
    required String reason,
    required bool solverProven,
  }) {
    return RescuePlan._(
      bugs: List.unmodifiable(bugs),
      reason: reason,
      solverProven: solverProven,
    );
  }

  final List<RescueBug> bugs;
  final String reason;
  final bool solverProven;

  bool get isEmpty => bugs.isEmpty;
}

class ObjectiveAwareRescuePlanner {
  ObjectiveAwareRescuePlanner({
    LevelRulesSimulator? simulator,
    LevelSolver? solver,
    MatchSystem? matchSystem,
  }) : simulator = simulator ?? LevelRulesSimulator(),
       solver = solver ?? LevelSolver(simulator: simulator),
       _matchSystem = matchSystem ?? MatchSystem();

  final LevelRulesSimulator simulator;
  final LevelSolver solver;
  final MatchSystem _matchSystem;

  bool hasExistingProgressPath({
    required LevelDefinition level,
    required BoardState board,
    required ObjectiveProgress progress,
    int danger = 0,
    int solverMoveBudget = 4,
    int solverStateBudget = 600,
  }) {
    if (simulator.objectivesComplete(level: level, progress: progress)) {
      return true;
    }
    if (simulator.hasObjectiveProgressMove(
      level: level,
      board: board,
      progress: progress,
      danger: danger,
    )) {
      return true;
    }
    if (!simulator.hasAnyLegalMove(board)) {
      return false;
    }

    return solver
        .solve(
          level,
          initialBoard: board,
          initialProgress: progress,
          initialDanger: danger,
          maxMoves: solverMoveBudget,
          maxStates: solverStateBudget,
        )
        .solved;
  }

  RescuePlan plan({
    required LevelDefinition level,
    required BoardState board,
    required ObjectiveProgress progress,
    int danger = 0,
    int existingMoveBudget = 4,
    int rescueMoveBudget = 8,
    int solverStateBudget = 1800,
    int maxCandidateChecks = 80,
    bool proveWithSolver = true,
  }) {
    if (proveWithSolver &&
        hasExistingProgressPath(
          level: level,
          board: board,
          progress: progress,
          danger: danger,
          solverMoveBudget: existingMoveBudget,
          solverStateBudget: min(700, solverStateBudget),
        )) {
      return RescuePlan.none('Existing player path found.');
    }

    final colors = _candidateColors(level, board, progress);
    final columns = _candidateColumns(board);
    if (colors.isEmpty || columns.isEmpty) {
      return RescuePlan.none('No safe rescue placement is available.');
    }

    if (!proveWithSolver) {
      return RescuePlan.add(
        bugs: _nonInstantFallback(board, columns, colors),
        reason: 'Deterministic live rescue.',
        solverProven: false,
      );
    }

    var checkedCandidates = 0;
    for (var bugCount = 1; bugCount <= 2; bugCount += 1) {
      for (final color in colors) {
        for (final bugs in _candidateBugGroups(
          board,
          columns,
          color,
          bugCount,
        )) {
          checkedCandidates += 1;
          if (checkedCandidates > maxCandidateChecks) {
            break;
          }
          final candidate = _boardWithRescue(board, bugs);
          if (_createsImmediateDetonation(candidate)) {
            continue;
          }
          final result = solver.solve(
            level,
            initialBoard: candidate,
            initialProgress: progress,
            initialDanger: danger,
            maxMoves: rescueMoveBudget,
            maxStates: solverStateBudget,
          );
          if (result.solved) {
            return RescuePlan.add(
              bugs: bugs,
              reason: 'Solver-proven ${color.label} rescue.',
              solverProven: true,
            );
          }
        }
        if (checkedCandidates > maxCandidateChecks) {
          break;
        }
      }
      if (checkedCandidates > maxCandidateChecks) {
        break;
      }
    }

    return RescuePlan.add(
      bugs: _nonInstantFallback(board, columns, colors),
      reason: 'Deterministic material rescue.',
      solverProven: false,
    );
  }

  List<BugColor> _candidateColors(
    LevelDefinition level,
    BoardState board,
    ObjectiveProgress progress,
  ) {
    final colors = <BugColor>[];
    final unfinished = level.activeObjectives.where(
      (objective) => !progress.isComplete(objective),
    );

    void add(BugColor color) {
      if (!colors.contains(color)) {
        colors.add(color);
      }
    }

    for (final objective in unfinished) {
      if (objective.type == ObjectiveType.clearColor &&
          objective.color != null) {
        add(objective.color!);
      }
    }
    for (final objective in unfinished) {
      if (objective.type == ObjectiveType.clearBig) {
        for (final color in _bigAnchorColors(board)) {
          add(color);
        }
      }
    }
    for (final color in _colorsByUsefulness(board)) {
      add(color);
    }
    for (final color in BugColor.active) {
      add(color);
    }

    return colors;
  }

  List<BugColor> _colorsByUsefulness(BoardState board) {
    final scored = <({BugColor color, int score})>[
      for (final color in BugColor.active) (color: color, score: 0),
    ];

    for (var index = 0; index < scored.length; index += 1) {
      final color = scored[index].color;
      var count = 0;
      var charged = 0;
      var normal = 0;
      var largestGroup = 0;

      for (var column = 0; column < BoardState.columnCount; column += 1) {
        for (final piece in board.columns[column]) {
          if (piece.color != color) {
            continue;
          }
          count += 1;
          if (piece.charged) {
            charged += 1;
          } else if (!piece.isBig) {
            normal += 1;
          }
        }
      }

      for (final group in _matchSystem.findConnectedGroups(board)) {
        final first = group.first;
        if (board.colorAt(first.column, first.row) == color &&
            group.length > largestGroup) {
          largestGroup = group.length;
        }
      }

      scored[index] = (
        color: color,
        score: count + normal * 2 + charged * 7 + largestGroup * 4,
      );
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      return BugColor.active
          .indexOf(a.color)
          .compareTo(BugColor.active.indexOf(b.color));
    });

    return [
      for (final entry in scored)
        if (entry.score > 0) entry.color,
    ];
  }

  List<BugColor> _bigAnchorColors(BoardState board) {
    final colors = <BugColor>[];
    for (final column in board.columns) {
      for (final piece in column) {
        if (piece.isBigAnchor && !colors.contains(piece.color)) {
          colors.add(piece.color);
        }
      }
    }
    return colors;
  }

  List<int> _candidateColumns(BoardState board) {
    final columns = [
      for (var column = 0; column < BoardState.columnCount; column += 1)
        if (!board.isColumnFull(column)) column,
    ];
    final center = (BoardState.columnCount - 1) / 2;
    columns.sort((a, b) {
      final byHeight = board.columns[a].length.compareTo(
        board.columns[b].length,
      );
      if (byHeight != 0) {
        return byHeight;
      }
      final byCenter = (a - center).abs().compareTo((b - center).abs());
      if (byCenter != 0) {
        return byCenter;
      }
      return a.compareTo(b);
    });
    return columns;
  }

  Iterable<List<RescueBug>> _candidateBugGroups(
    BoardState board,
    List<int> columns,
    BugColor color,
    int bugCount,
  ) sync* {
    if (bugCount == 1) {
      for (final column in columns) {
        yield [RescueBug(column: column, color: color)];
      }
      return;
    }

    for (var first = 0; first < columns.length; first += 1) {
      for (var second = first + 1; second < columns.length; second += 1) {
        yield [
          RescueBug(column: columns[first], color: color),
          RescueBug(column: columns[second], color: color),
        ];
      }
      final column = columns[first];
      if (board.columns[column].length <= BoardState.rowCount - 2) {
        yield [
          RescueBug(column: column, color: color),
          RescueBug(column: column, color: color),
        ];
      }
    }
  }

  BoardState _boardWithRescue(BoardState board, List<RescueBug> bugs) {
    final candidate = board.copy();
    for (final bug in bugs) {
      candidate.insertPieceBottom(bug.column, BoardPiece(bug.color));
    }
    return candidate;
  }

  bool _createsImmediateDetonation(BoardState board) {
    return _matchSystem.findDetonations(board).isNotEmpty;
  }

  List<RescueBug> _fallbackBugs(
    BoardState board,
    List<int> columns,
    BugColor color,
  ) {
    final bugs = <RescueBug>[];
    final simulatedHeights = [
      for (final column in board.columns) column.length,
    ];

    for (var i = 0; i < 3; i += 1) {
      final column = columns.firstWhere(
        (candidate) => simulatedHeights[candidate] < BoardState.rowCount,
        orElse: () => columns.first,
      );
      bugs.add(RescueBug(column: column, color: color));
      simulatedHeights[column] += 1;
    }

    return bugs;
  }

  List<RescueBug> _nonInstantFallback(
    BoardState board,
    List<int> columns,
    List<BugColor> colors,
  ) {
    for (final color in colors) {
      final candidateBugs = _fallbackBugs(board, columns, color);
      if (!_createsImmediateDetonation(
        _boardWithRescue(board, candidateBugs),
      )) {
        return candidateBugs;
      }
    }
    return _fallbackBugs(board, columns, colors.first);
  }
}
