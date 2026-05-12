import '../models/board_cell.dart';
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
      if (group.length < 2) {
        return false;
      }
      return group.any(
        (cell) => board.pieceAt(cell.column, cell.row)?.charged ?? false,
      );
    }).toList();
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
