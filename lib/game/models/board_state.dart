import 'board_cell.dart';
import 'bug_color.dart';
import 'board_piece.dart';

class BoardState {
  BoardState(List<List<BugColor>> columns)
    : columns = _normalizeColorColumns(columns);

  BoardState.fromPieces(List<List<BoardPiece>> columns)
    : columns = _normalizePieceColumns(columns);

  static const int columnCount = 6;
  static const int rowCount = 8;

  final List<List<BoardPiece>> columns;

  static List<List<BoardPiece>> _normalizeColorColumns(
    List<List<BugColor>> columns,
  ) {
    return [
      for (var column = 0; column < columnCount; column += 1)
        if (column < columns.length)
          columns[column].map((color) => BoardPiece(color)).toList()
        else
          <BoardPiece>[],
    ];
  }

  static List<List<BoardPiece>> _normalizePieceColumns(
    List<List<BoardPiece>> columns,
  ) {
    return [
      for (var column = 0; column < columnCount; column += 1)
        if (column < columns.length)
          List<BoardPiece>.from(columns[column])
        else
          <BoardPiece>[],
    ];
  }

  BoardState copy() => BoardState.fromPieces(columns);

  bool isColumnEmpty(int column) => columns[column].isEmpty;

  bool isColumnFull(int column) => columns[column].length >= rowCount;

  BugColor? colorAt(int column, int row) {
    if (column < 0 || column >= columnCount) {
      return null;
    }
    if (row < 0 || row >= columns[column].length) {
      return null;
    }
    return columns[column][row].color;
  }

  BoardPiece? pieceAt(int column, int row) {
    if (column < 0 || column >= columnCount) {
      return null;
    }
    if (row < 0 || row >= columns[column].length) {
      return null;
    }
    return columns[column][row];
  }

  void setPiece(int column, int row, BoardPiece piece) {
    columns[column][row] = piece;
  }

  BoardPiece removeBottom(int column) => columns[column].removeLast();

  void insertBottom(int column, BugColor color) {
    insertPieceBottom(column, BoardPiece(color));
  }

  void insertPieceBottom(int column, BoardPiece piece) {
    columns[column].add(piece);
  }

  void insertPieceTop(int column, BoardPiece piece) {
    columns[column].insert(0, piece);
  }

  void insertTopRow(List<BoardPiece> pieces) {
    if (pieces.length != columnCount) {
      throw ArgumentError.value(pieces.length, 'pieces.length');
    }
    for (var column = 0; column < columnCount; column += 1) {
      insertPieceTop(column, pieces[column]);
    }
  }

  List<BoardPiece> clearCells(Iterable<BoardCell> cells) {
    final removed = <BoardPiece>[];
    final byColumn = <int, List<int>>{};
    final expandedCells = _expandCellsForBigSafety(cells.toSet());

    for (final cell in expandedCells) {
      byColumn.putIfAbsent(cell.column, () => <int>[]).add(cell.row);
    }

    for (final entry in byColumn.entries) {
      final rows = entry.value.toSet().toList()..sort((a, b) => b.compareTo(a));
      final column = columns[entry.key];
      for (final row in rows) {
        if (row >= 0 && row < column.length) {
          removed.add(column.removeAt(row));
        }
      }
    }

    return removed;
  }

  Set<BoardCell> _expandCellsForBigSafety(Set<BoardCell> cells) {
    final expanded = Set<BoardCell>.from(cells);
    final bigCells = <int, Set<BoardCell>>{};

    for (var column = 0; column < columns.length; column += 1) {
      for (var row = 0; row < columns[column].length; row += 1) {
        final bigId = columns[column][row].bigId;
        if (bigId != null) {
          bigCells
              .putIfAbsent(bigId, () => <BoardCell>{})
              .add(BoardCell(column, row));
        }
      }
    }

    for (final cell in cells) {
      final piece = pieceAt(cell.column, cell.row);
      final bigId = piece?.bigId;
      if (bigId != null) {
        expanded.addAll(bigCells[bigId] ?? const <BoardCell>{});
      }
    }

    for (final entry in bigCells.entries) {
      final big = entry.value;
      final wouldShiftOneSide = cells.any((cell) {
        return big.any(
          (bigCell) => cell.column == bigCell.column && cell.row < bigCell.row,
        );
      });
      if (wouldShiftOneSide) {
        expanded.addAll(big);
      }
    }

    return expanded;
  }

  void promoteBigBlock({
    required int column,
    required int row,
    required int bigId,
  }) {
    final color = columns[column][row].color;
    setPiece(
      column,
      row,
      BoardPiece(color, type: BoardPieceType.bigAnchor, bigId: bigId),
    );
    setPiece(
      column + 1,
      row,
      BoardPiece(color, type: BoardPieceType.bigPart, bigId: bigId),
    );
    setPiece(
      column,
      row + 1,
      BoardPiece(color, type: BoardPieceType.bigPart, bigId: bigId),
    );
    setPiece(
      column + 1,
      row + 1,
      BoardPiece(color, type: BoardPieceType.bigPart, bigId: bigId),
    );
  }

  Set<BoardCell> cellsForBig(int bigId) {
    final cells = <BoardCell>{};
    for (var column = 0; column < columns.length; column += 1) {
      for (var row = 0; row < columns[column].length; row += 1) {
        if (columns[column][row].bigId == bigId) {
          cells.add(BoardCell(column, row));
        }
      }
    }
    return cells;
  }

  bool get isEmpty => columns.every((column) => column.isEmpty);
}
