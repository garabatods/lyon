import '../models/board_cell.dart';
import '../models/board_piece.dart';
import '../models/board_state.dart';
import '../models/bug_color.dart';

class BigBugPromotion {
  const BigBugPromotion({
    required this.column,
    required this.row,
    required this.color,
  });

  final int column;
  final int row;
  final BugColor color;

  Set<BoardCell> get cells => {
    BoardCell(column, row),
    BoardCell(column + 1, row),
    BoardCell(column, row + 1),
    BoardCell(column + 1, row + 1),
  };
}

class MatchSystem {
  static const int minimumDetonationGroupSize = 3;

  List<Set<BoardCell>> findConnectedGroups(BoardState board) {
    final visited = <BoardCell>{};
    final groups = <Set<BoardCell>>[];

    for (var column = 0; column < BoardState.columnCount; column += 1) {
      for (var row = 0; row < BoardState.rowCount; row += 1) {
        final start = BoardCell(column, row);
        final color = board.colorAt(column, row);
        if (color == null || visited.contains(start)) {
          continue;
        }

        final group = <BoardCell>{};
        final stack = <BoardCell>[start];
        visited.add(start);

        while (stack.isNotEmpty) {
          final cell = stack.removeLast();
          group.add(cell);

          for (final next in _neighbors(cell)) {
            if (visited.contains(next)) {
              continue;
            }
            if (board.colorAt(next.column, next.row) == color) {
              visited.add(next);
              stack.add(next);
            }
          }
        }

        groups.add(group);
      }
    }

    return groups;
  }

  List<Set<BoardCell>> findDetonations(BoardState board) {
    return findConnectedGroups(board).where((group) {
      if (group.length < minimumDetonationGroupSize) {
        return false;
      }
      return group.any(
        (cell) => board.pieceAt(cell.column, cell.row)?.charged ?? false,
      );
    }).toList();
  }

  bool hasProgressMove(BoardState board) {
    if (findDetonations(board).isNotEmpty) {
      return true;
    }
    if (board.hasGlowMergeMove()) {
      return true;
    }
    return _hasDetonatingDragMove(board);
  }

  bool _hasDetonatingDragMove(BoardState board) {
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

        for (
          var destination = 0;
          destination < BoardState.columnCount;
          destination += 1
        ) {
          if (destination == sourceColumn) {
            continue;
          }
          if (_dragWouldDetonate(
            board,
            source: source,
            sourceColumn: sourceColumn,
            sourceRow: sourceRow,
            destination: destination,
          )) {
            return true;
          }
        }
      }
    }

    return false;
  }

  bool _dragWouldDetonate(
    BoardState board, {
    required BoardPiece source,
    required int sourceColumn,
    required int sourceRow,
    required int destination,
  }) {
    final mergeTargetRow = board.columns[destination].length - 1;
    final mergeTarget = board.pieceAt(destination, mergeTargetRow);
    final canMerge =
        mergeTarget != null &&
        mergeTarget.canSwallow &&
        !mergeTarget.charged &&
        !source.charged &&
        mergeTarget.color == source.color;

    final candidate = board.copy();
    if (canMerge) {
      candidate.mergePieceAt(
        sourceColumn: sourceColumn,
        sourceRow: sourceRow,
        targetColumn: destination,
        targetRow: mergeTargetRow,
      );
    } else {
      final moved = candidate.removePieceAt(sourceColumn, sourceRow);
      candidate.insertPieceBottom(destination, moved);
      if (candidate.columns[destination].length > BoardState.rowCount) {
        candidate.clearCells({BoardCell(destination, 0)});
      }
    }

    return findDetonations(candidate).isNotEmpty;
  }

  List<BigBugPromotion> findBigPromotions(BoardState board) {
    final promotions = <BigBugPromotion>[];
    final reserved = <BoardCell>{};

    for (var column = 0; column < BoardState.columnCount - 1; column += 1) {
      for (var row = 0; row < BoardState.rowCount - 1; row += 1) {
        final cells = {
          BoardCell(column, row),
          BoardCell(column + 1, row),
          BoardCell(column, row + 1),
          BoardCell(column + 1, row + 1),
        };
        if (cells.any(reserved.contains)) {
          continue;
        }

        final pieces = [
          for (final cell in cells) board.pieceAt(cell.column, cell.row),
        ];
        if (pieces.any((piece) => piece == null)) {
          continue;
        }

        final first = pieces.first!;
        if (first.charged || first.isBig) {
          continue;
        }
        if (pieces.any(
          (piece) =>
              piece!.color != first.color || piece.charged || piece.isBig,
        )) {
          continue;
        }

        promotions.add(
          BigBugPromotion(column: column, row: row, color: first.color),
        );
        reserved.addAll(cells);
      }
    }

    return promotions;
  }

  Iterable<BoardCell> _neighbors(BoardCell cell) sync* {
    yield BoardCell(cell.column - 1, cell.row);
    yield BoardCell(cell.column + 1, cell.row);
    yield BoardCell(cell.column, cell.row - 1);
    yield BoardCell(cell.column, cell.row + 1);
  }
}
