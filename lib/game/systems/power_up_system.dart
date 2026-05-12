import 'dart:math';

import '../models/board_cell.dart';
import '../models/board_piece.dart';
import '../models/board_state.dart';

class PowerUpSystem {
  PowerUpSystem({Random? random}) : _random = random ?? Random();

  final Random _random;

  Set<BoardCell> berryCells(BoardState board, BoardCell target) {
    final piece = board.pieceAt(target.column, target.row);
    if (piece == null || piece.isBig) {
      return const <BoardCell>{};
    }

    return _safeSmallCells(board, {
      for (var row = 0; row < board.columns[target.column].length; row += 1)
        BoardCell(target.column, row),
    });
  }

  Map<BoardCell, BoardPiece> bloomChanges(BoardState board, BoardCell target) {
    final targetPiece = board.pieceAt(target.column, target.row);
    if (targetPiece == null || targetPiece.isBig) {
      return const <BoardCell, BoardPiece>{};
    }

    final changes = <BoardCell, BoardPiece>{};
    for (var column = 0; column < BoardState.columnCount; column += 1) {
      final piece = board.pieceAt(column, target.row);
      if (piece == null || piece.isBig || piece.color == targetPiece.color) {
        continue;
      }
      changes[BoardCell(column, target.row)] = BoardPiece(
        targetPiece.color,
        charged: piece.charged,
      );
    }
    return changes;
  }

  Set<BoardCell> pollenCells(BoardState board, BoardCell target) {
    final cells = <BoardCell>{};
    for (
      var column = target.column - 1;
      column <= target.column + 1;
      column++
    ) {
      for (var row = target.row - 1; row <= target.row + 1; row++) {
        if (column < 0 ||
            column >= BoardState.columnCount ||
            row < 0 ||
            row >= BoardState.rowCount) {
          continue;
        }
        cells.add(BoardCell(column, row));
      }
    }
    return _safeSmallCells(board, cells);
  }

  Set<BoardCell> waterCells(BoardState board, BoardCell target) {
    final piece = board.pieceAt(target.column, target.row);
    if (piece == null || piece.isBig) {
      return const <BoardCell>{};
    }
    final cells = <BoardCell>{};
    for (var column = 0; column < BoardState.columnCount; column += 1) {
      for (var row = 0; row < board.columns[column].length; row += 1) {
        if (board.colorAt(column, row) == piece.color) {
          cells.add(BoardCell(column, row));
        }
      }
    }
    return _safeSmallCells(board, cells);
  }

  Set<BoardCell> fireflyCells(BoardState board) {
    final smallCells = <BoardCell>[];
    for (var column = 0; column < BoardState.columnCount; column += 1) {
      for (var row = 0; row < board.columns[column].length; row += 1) {
        final piece = board.pieceAt(column, row);
        if (piece != null && !piece.isBig) {
          smallCells.add(BoardCell(column, row));
        }
      }
    }
    if (smallCells.isEmpty) {
      return const <BoardCell>{};
    }

    smallCells.shuffle(_random);
    final clearCount = max(1, (smallCells.length / 2).floor());
    return _safeSmallCells(board, smallCells.take(clearCount).toSet());
  }

  Set<BoardCell> _safeSmallCells(BoardState board, Set<BoardCell> cells) {
    return {
      for (final cell in cells)
        if (_canClearWithoutSplittingBig(board, cell)) cell,
    };
  }

  bool _canClearWithoutSplittingBig(BoardState board, BoardCell cell) {
    final piece = board.pieceAt(cell.column, cell.row);
    if (piece == null || piece.isBig) {
      return false;
    }

    for (
      var row = cell.row + 1;
      row < board.columns[cell.column].length;
      row++
    ) {
      if (board.pieceAt(cell.column, row)?.isBig ?? false) {
        return false;
      }
    }
    return true;
  }
}
