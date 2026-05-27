import 'dart:collection';

import '../models/board_state.dart';
import '../models/level_definition.dart';
import '../models/objective_progress.dart';
import 'level_rules_simulator.dart';

class LevelSolverResult {
  const LevelSolverResult._({
    required this.solved,
    required this.moves,
    required this.failureReason,
    required this.exploredStates,
  });

  factory LevelSolverResult.solved({
    required List<SimulatedMove> moves,
    required int exploredStates,
  }) {
    return LevelSolverResult._(
      solved: true,
      moves: moves,
      failureReason: null,
      exploredStates: exploredStates,
    );
  }

  factory LevelSolverResult.failed({
    required String reason,
    required int exploredStates,
  }) {
    return LevelSolverResult._(
      solved: false,
      moves: const <SimulatedMove>[],
      failureReason: reason,
      exploredStates: exploredStates,
    );
  }

  final bool solved;
  final List<SimulatedMove> moves;
  final String? failureReason;
  final int exploredStates;
}

class LevelSolver {
  LevelSolver({LevelRulesSimulator? simulator})
    : simulator = simulator ?? LevelRulesSimulator();

  final LevelRulesSimulator simulator;

  LevelSolverResult solve(
    LevelDefinition level, {
    BoardState? initialBoard,
    ObjectiveProgress initialProgress = ObjectiveProgress.empty,
    int initialDanger = 0,
    int? maxMoves,
    int maxStates = 5000,
  }) {
    final depthLimit = maxMoves ?? level.solverMaxMoves;
    final start = _SolverNode(
      board: initialBoard?.copy() ?? level.createBoard(),
      progress: initialProgress,
      danger: initialDanger,
      moves: const <SimulatedMove>[],
    );

    if (simulator.objectivesComplete(level: level, progress: start.progress)) {
      return LevelSolverResult.solved(moves: start.moves, exploredStates: 1);
    }

    final queue = Queue<_SolverNode>()..add(start);
    final visited = <String>{_signature(level, start)};
    var explored = 0;

    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      explored += 1;

      if (node.moves.length >= depthLimit) {
        continue;
      }
      if (explored > maxStates) {
        return LevelSolverResult.failed(
          reason: 'State budget exceeded before a solution was found.',
          exploredStates: explored,
        );
      }

      final orderedMoves = simulator.legalMoves(node.board)
        ..sort(
          (a, b) =>
              _moveScore(level, node, b).compareTo(_moveScore(level, node, a)),
        );

      for (final move in orderedMoves) {
        final result = simulator.applyMove(
          board: node.board,
          move: move,
          progress: node.progress,
          danger: node.danger,
        );
        if (result.danger >= LevelRulesSimulator.maxDanger) {
          continue;
        }
        final child = _SolverNode(
          board: result.board,
          progress: result.progress,
          danger: result.danger,
          moves: [...node.moves, move],
        );
        final signature = _signature(level, child);
        if (!visited.add(signature)) {
          continue;
        }
        if (simulator.objectivesComplete(
          level: level,
          progress: child.progress,
        )) {
          return LevelSolverResult.solved(
            moves: child.moves,
            exploredStates: explored,
          );
        }
        queue.add(child);
      }
    }

    return LevelSolverResult.failed(
      reason: 'No solution found within $depthLimit moves.',
      exploredStates: explored,
    );
  }

  int _moveScore(LevelDefinition level, _SolverNode node, SimulatedMove move) {
    final result = simulator.applyMove(
      board: node.board,
      move: move,
      progress: node.progress,
      danger: node.danger,
    );
    var score = move.isMerge ? 8 : 1;
    if (result.clearedAny) {
      score += 18 + result.cascadeCount * 4;
    }
    if (result.promotedAny) {
      score += 6;
    }
    for (final objective in simulator.solvableObjectives(level)) {
      final before = node.progress.valueFor(objective);
      final after = result.progress.valueFor(objective);
      if (after > before) {
        score += (after - before).clamp(1, 99).toInt() * 12;
      }
      if (!node.progress.isComplete(objective) &&
          result.progress.isComplete(objective)) {
        score += 60;
      }
    }
    return score;
  }

  String _signature(LevelDefinition level, _SolverNode node) {
    return [
      _boardSignature(node.board),
      _progressSignature(level, node.progress),
      node.danger,
    ].join('|');
  }

  String _boardSignature(BoardState board) {
    final buffer = StringBuffer();
    for (var column = 0; column < BoardState.columnCount; column += 1) {
      if (column > 0) {
        buffer.write('/');
      }
      for (final piece in board.columns[column]) {
        buffer
          ..write(piece.color.index)
          ..write(piece.charged ? 'g' : 'n')
          ..write(piece.type.index)
          ..write(piece.bigId ?? 0)
          ..write(',');
      }
    }
    return buffer.toString();
  }

  String _progressSignature(LevelDefinition level, ObjectiveProgress progress) {
    final objectives = simulator.solvableObjectives(level);
    if (objectives.isEmpty) {
      return 'none';
    }
    return objectives.map(progress.valueFor).join(',');
  }
}

class _SolverNode {
  const _SolverNode({
    required this.board,
    required this.progress,
    required this.danger,
    required this.moves,
  });

  final BoardState board;
  final ObjectiveProgress progress;
  final int danger;
  final List<SimulatedMove> moves;
}
