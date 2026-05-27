import 'board_cell.dart';
import 'bug_color.dart';
import 'board_piece.dart';

class BoardBigSplit {
  const BoardBigSplit({required this.bigId, required this.cells});

  final int bigId;
  final Set<BoardCell> cells;
}

class BoardClearResult {
  const BoardClearResult({required this.removed, required this.bigSplits});

  final List<BoardPiece> removed;
  final List<BoardBigSplit> bigSplits;
}

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

  BoardPiece removePieceAt(int column, int row) =>
      columns[column].removeAt(row);

  void insertPieceAt(int column, int row, BoardPiece piece) {
    final targetRow = row.clamp(0, columns[column].length).toInt();
    columns[column].insert(targetRow, piece);
  }

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
    return clearCellsWithResult(cells).removed;
  }

  BoardClearResult clearCellsWithResult(Iterable<BoardCell> cells) {
    final removed = <BoardPiece>[];
    final byColumn = <int, List<int>>{};
    final clearSet = cells.toSet();
    final bigCells = _collectBigCells();
    final directBigIds = _directBigIdsFor(clearSet);
    final bigSplits = _splitBigsThreatenedBy(clearSet, bigCells, directBigIds);
    final expandedCells = _expandCellsForDirectBigClears(clearSet, bigCells);

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

    return BoardClearResult(removed: removed, bigSplits: bigSplits);
  }

  Map<int, Set<BoardCell>> _collectBigCells() {
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

    return bigCells;
  }

  Set<int> _directBigIdsFor(Set<BoardCell> cells) {
    final directBigIds = <int>{};
    for (final cell in cells) {
      final piece = pieceAt(cell.column, cell.row);
      final bigId = piece?.bigId;
      if (bigId != null) {
        directBigIds.add(bigId);
      }
    }
    return directBigIds;
  }

  List<BoardBigSplit> _splitBigsThreatenedBy(
    Set<BoardCell> cells,
    Map<int, Set<BoardCell>> bigCells,
    Set<int> directBigIds,
  ) {
    final bigSplits = <BoardBigSplit>[];
    for (final entry in bigCells.entries) {
      if (directBigIds.contains(entry.key)) {
        continue;
      }
      final big = entry.value;
      final wouldShiftOneSide = cells.any((cell) {
        return big.any(
          (bigCell) => cell.column == bigCell.column && cell.row < bigCell.row,
        );
      });
      if (wouldShiftOneSide) {
        bigSplits.add(BoardBigSplit(bigId: entry.key, cells: Set.of(big)));
        for (final cell in big) {
          final piece = pieceAt(cell.column, cell.row);
          if (piece != null) {
            setPiece(cell.column, cell.row, BoardPiece(piece.color));
          }
        }
      }
    }
    return bigSplits;
  }

  Set<BoardCell> _expandCellsForDirectBigClears(
    Set<BoardCell> cells,
    Map<int, Set<BoardCell>> bigCells,
  ) {
    final expanded = Set<BoardCell>.from(cells);
    for (final bigId in _directBigIdsFor(cells)) {
      expanded.addAll(bigCells[bigId] ?? const <BoardCell>{});
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

  bool canDragPieceAt(int column, int row) {
    final piece = pieceAt(column, row);
    if (piece == null || !piece.canSwallow) {
      return false;
    }
    if (_wouldShiftBigBugBelow(column, row)) {
      return false;
    }
    if (row == columns[column].length - 1) {
      return true;
    }
    return _hasOpenHorizontalSide(column, row);
  }

  bool hasGlowMergeMove() {
    for (var sourceColumn = 0; sourceColumn < columnCount; sourceColumn += 1) {
      for (
        var sourceRow = 0;
        sourceRow < columns[sourceColumn].length;
        sourceRow += 1
      ) {
        final source = pieceAt(sourceColumn, sourceRow);
        if (source == null ||
            source.charged ||
            !canDragPieceAt(sourceColumn, sourceRow)) {
          continue;
        }

        for (
          var targetColumn = 0;
          targetColumn < columnCount;
          targetColumn += 1
        ) {
          if (targetColumn == sourceColumn || columns[targetColumn].isEmpty) {
            continue;
          }
          final targetRow = columns[targetColumn].length - 1;
          final target = pieceAt(targetColumn, targetRow);
          if (target != null &&
              target.canSwallow &&
              !target.charged &&
              target.color == source.color) {
            return true;
          }
        }
      }
    }

    return false;
  }

  void mergePieceAt({
    required int sourceColumn,
    required int sourceRow,
    required int targetColumn,
    required int targetRow,
  }) {
    final source = removePieceAt(sourceColumn, sourceRow);
    final adjustedTargetRow =
        sourceColumn == targetColumn && sourceRow < targetRow
        ? targetRow - 1
        : targetRow;
    setPiece(
      targetColumn,
      adjustedTargetRow,
      BoardPiece(source.color, charged: true),
    );
  }

  bool _hasOpenHorizontalSide(int column, int row) {
    final leftOpen = column > 0 && pieceAt(column - 1, row) == null;
    final rightOpen =
        column < columnCount - 1 && pieceAt(column + 1, row) == null;
    return leftOpen || rightOpen;
  }

  bool _wouldShiftBigBugBelow(int column, int row) {
    for (var below = row + 1; below < columns[column].length; below += 1) {
      if (columns[column][below].isBig) {
        return true;
      }
    }
    return false;
  }

  bool get isEmpty => columns.every((column) => column.isEmpty);
}
