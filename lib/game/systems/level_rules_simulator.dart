import '../models/board_cell.dart';
import '../models/board_piece.dart';
import '../models/board_state.dart';
import '../models/bug_color.dart';
import '../models/level_definition.dart';
import '../models/objective.dart';
import '../models/objective_progress.dart';
import 'match_system.dart';

enum SimulatedMoveKind { move, merge }

class SimulatedMove {
  const SimulatedMove._({
    required this.kind,
    required this.sourceColumn,
    required this.sourceRow,
    required this.targetColumn,
    this.targetRow,
    required this.color,
  });

  factory SimulatedMove.move({
    required int sourceColumn,
    required int sourceRow,
    required int targetColumn,
    required BugColor color,
  }) {
    return SimulatedMove._(
      kind: SimulatedMoveKind.move,
      sourceColumn: sourceColumn,
      sourceRow: sourceRow,
      targetColumn: targetColumn,
      color: color,
    );
  }

  factory SimulatedMove.merge({
    required int sourceColumn,
    required int sourceRow,
    required int targetColumn,
    required int targetRow,
    required BugColor color,
  }) {
    return SimulatedMove._(
      kind: SimulatedMoveKind.merge,
      sourceColumn: sourceColumn,
      sourceRow: sourceRow,
      targetColumn: targetColumn,
      targetRow: targetRow,
      color: color,
    );
  }

  final SimulatedMoveKind kind;
  final int sourceColumn;
  final int sourceRow;
  final int targetColumn;
  final int? targetRow;
  final BugColor color;

  bool get isMerge => kind == SimulatedMoveKind.merge;

  String get label {
    final target = targetRow == null
        ? '$targetColumn'
        : '$targetColumn:$targetRow';
    return '${kind.name} ${color.name} $sourceColumn:$sourceRow->$target';
  }
}

class SimulationResult {
  const SimulationResult({
    required this.board,
    required this.progress,
    required this.danger,
    required this.cascadeCount,
    required this.clearedAny,
    required this.promotedAny,
  });

  final BoardState board;
  final ObjectiveProgress progress;
  final int danger;
  final int cascadeCount;
  final bool clearedAny;
  final bool promotedAny;
}

class LevelRulesSimulator {
  LevelRulesSimulator({MatchSystem? matchSystem})
    : _matchSystem = matchSystem ?? MatchSystem();

  static const int maxDanger = 5;

  final MatchSystem _matchSystem;

  List<SimulatedMove> legalMoves(BoardState board) {
    final moves = <SimulatedMove>[];

    for (
      var sourceColumn = 0;
      sourceColumn < BoardState.columnCount;
      sourceColumn += 1
    ) {
      for (
        var sourceRow = 0;
        sourceRow < board.columns[sourceColumn].length;
        sourceRow += 1
      ) {
        final source = board.pieceAt(sourceColumn, sourceRow);
        if (source == null || !board.canDragPieceAt(sourceColumn, sourceRow)) {
          continue;
        }

        moves.addAll(
          _legalMergeMoves(
            board,
            source: source,
            sourceColumn: sourceColumn,
            sourceRow: sourceRow,
          ),
        );

        for (
          var targetColumn = 0;
          targetColumn < BoardState.columnCount;
          targetColumn += 1
        ) {
          if (targetColumn == sourceColumn) {
            continue;
          }
          moves.add(
            SimulatedMove.move(
              sourceColumn: sourceColumn,
              sourceRow: sourceRow,
              targetColumn: targetColumn,
              color: source.color,
            ),
          );
        }
      }
    }

    moves.sort((a, b) => a.label.compareTo(b.label));
    return moves;
  }

  bool hasAnyLegalMove(BoardState board) => legalMoves(board).isNotEmpty;

  bool hasObjectiveProgressMove({
    required LevelDefinition level,
    required BoardState board,
    required ObjectiveProgress progress,
    int danger = 0,
  }) {
    final objectives = solvableObjectives(level);
    if (objectives.every(progress.isComplete)) {
      return false;
    }

    for (final move in legalMoves(board)) {
      final result = applyMove(
        board: board,
        move: move,
        progress: progress,
        danger: danger,
      );
      if (_advancesAnyObjective(
        objectives: objectives,
        before: progress,
        after: result.progress,
      )) {
        return true;
      }
    }

    return false;
  }

  SimulationResult applyMove({
    required BoardState board,
    required SimulatedMove move,
    ObjectiveProgress progress = ObjectiveProgress.empty,
    int danger = 0,
  }) {
    final nextBoard = board.copy();
    var nextProgress = progress;
    var nextDanger = danger;

    switch (move.kind) {
      case SimulatedMoveKind.merge:
        nextBoard.mergePieceAt(
          sourceColumn: move.sourceColumn,
          sourceRow: move.sourceRow,
          targetColumn: move.targetColumn,
          targetRow: move.targetRow!,
        );
        nextProgress = nextProgress.registerGlowCreated();
      case SimulatedMoveKind.move:
        final moved = nextBoard.removePieceAt(
          move.sourceColumn,
          move.sourceRow,
        );
        final overloaded = nextBoard.isColumnFull(move.targetColumn);
        nextBoard.insertPieceBottom(move.targetColumn, moved);
        if (nextBoard.columns[move.targetColumn].length > BoardState.rowCount) {
          nextBoard.clearCells({BoardCell(move.targetColumn, 0)});
        }
        if (overloaded) {
          nextDanger = (nextDanger + 1).clamp(0, maxDanger).toInt();
          nextProgress = nextProgress.registerDanger(nextDanger);
        }
        nextProgress = nextProgress.registerBugMoved();
    }

    return resolveBoard(
      board: nextBoard,
      progress: nextProgress,
      danger: nextDanger,
    );
  }

  SimulationResult resolveBoard({
    required BoardState board,
    ObjectiveProgress progress = ObjectiveProgress.empty,
    int danger = 0,
  }) {
    var nextProgress = progress;
    var cascadeCount = 0;
    var clearedAny = false;
    var promotedAny = false;
    var nextBigId = _nextBigId(board);

    for (var iteration = 0; iteration < 64; iteration += 1) {
      final promotions = _matchSystem.findBigPromotions(board);
      if (promotions.isNotEmpty) {
        promotedAny = true;
        for (final promotion in promotions) {
          board.promoteBigBlock(
            column: promotion.column,
            row: promotion.row,
            bigId: nextBigId,
          );
          nextBigId += 1;
        }
        continue;
      }

      final groups = _matchSystem.findDetonations(board);
      if (groups.isEmpty) {
        return SimulationResult(
          board: board,
          progress: nextProgress,
          danger: danger,
          cascadeCount: cascadeCount,
          clearedAny: clearedAny,
          promotedAny: promotedAny,
        );
      }

      clearedAny = true;
      cascadeCount += 1;
      final cells = groups.expand((group) => group).toSet();
      final clearResult = board.clearCellsWithResult(cells);
      nextProgress = nextProgress.registerClear(
        clearResult.removed,
        cascadeCount: cascadeCount,
        boardCleared: board.isEmpty,
        bigSplitCount: clearResult.bigSplits.length,
      );
    }

    return SimulationResult(
      board: board,
      progress: nextProgress,
      danger: danger,
      cascadeCount: cascadeCount,
      clearedAny: clearedAny,
      promotedAny: promotedAny,
    );
  }

  List<Objective> solvableObjectives(LevelDefinition level) {
    return level.activeObjectives
        .where((objective) => objective.type != ObjectiveType.surviveSeconds)
        .toList(growable: false);
  }

  bool objectivesComplete({
    required LevelDefinition level,
    required ObjectiveProgress progress,
  }) {
    final objectives = solvableObjectives(level);
    return objectives.isEmpty || objectives.every(progress.isComplete);
  }

  List<SimulatedMove> _legalMergeMoves(
    BoardState board, {
    required BoardPiece source,
    required int sourceColumn,
    required int sourceRow,
  }) {
    if (source.charged) {
      return const <SimulatedMove>[];
    }

    final moves = <SimulatedMove>[];
    for (
      var targetColumn = 0;
      targetColumn < BoardState.columnCount;
      targetColumn += 1
    ) {
      for (
        var targetRow = 0;
        targetRow < board.columns[targetColumn].length;
        targetRow += 1
      ) {
        if (targetColumn == sourceColumn && targetRow == sourceRow) {
          continue;
        }
        final target = board.pieceAt(targetColumn, targetRow);
        if (target == null ||
            !target.canSwallow ||
            target.charged ||
            target.color != source.color) {
          continue;
        }
        moves.add(
          SimulatedMove.merge(
            sourceColumn: sourceColumn,
            sourceRow: sourceRow,
            targetColumn: targetColumn,
            targetRow: targetRow,
            color: source.color,
          ),
        );
      }
    }
    return moves;
  }

  bool _advancesAnyObjective({
    required List<Objective> objectives,
    required ObjectiveProgress before,
    required ObjectiveProgress after,
  }) {
    for (final objective in objectives) {
      if (after.valueFor(objective) > before.valueFor(objective)) {
        return true;
      }
      if (!before.isComplete(objective) && after.isComplete(objective)) {
        return true;
      }
    }
    return false;
  }

  int _nextBigId(BoardState board) {
    var next = 1;
    for (final column in board.columns) {
      for (final piece in column) {
        final bigId = piece.bigId;
        if (bigId != null && bigId >= next) {
          next = bigId + 1;
        }
      }
    }
    return next;
  }
}
