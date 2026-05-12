import 'dart:math';

import 'package:flame/components.dart';

import 'models/board_cell.dart';
import 'models/board_state.dart';

class BoardLayout {
  static const double boardAssetWidth = 1191;
  static const double boardAssetHeight = 1473;
  static const double maxBoardWidth = 390;
  static const double boardWidthScreenRatio = 0.94;
  static const double minBoardTop = 150;
  static const double boardTopScreenRatio = 0.165;
  static const double gridInsetLeftRatio = 0.075;
  static const double gridInsetRightRatio = 0.072;
  static const double gridInsetTopRatio = 0.088;
  static const double gridInsetBottomRatio = 0.066;
  static const double bugCellScale = 0.86;
  static const double chameleonCellScale = 2.15;
  static const double chameleonVerticalOffsetScale = 0.56;

  BoardLayout(this.gameSize) {
    _calculate();
  }

  final Vector2 gameSize;

  late final Vector2 boardPosition;
  late final Vector2 boardSize;
  late final double cellWidth;
  late final double cellHeight;
  late final double bugSize;
  late final double chameleonSize;

  late final double _gridInsetLeft;
  late final double _gridInsetRight;
  late final double _gridInsetTop;
  late final double _gridInsetBottom;

  void _calculate() {
    final width = min(gameSize.x * boardWidthScreenRatio, maxBoardWidth);
    final height = width * (boardAssetHeight / boardAssetWidth);
    final top = max(minBoardTop, gameSize.y * boardTopScreenRatio);
    boardSize = Vector2(width, height);
    boardPosition = Vector2((gameSize.x - width) / 2, top);

    _gridInsetLeft = boardSize.x * gridInsetLeftRatio;
    _gridInsetRight = boardSize.x * gridInsetRightRatio;
    _gridInsetTop = boardSize.y * gridInsetTopRatio;
    _gridInsetBottom = boardSize.y * gridInsetBottomRatio;

    cellWidth =
        (boardSize.x - _gridInsetLeft - _gridInsetRight) /
        BoardState.columnCount;
    cellHeight =
        (boardSize.y - _gridInsetTop - _gridInsetBottom) / BoardState.rowCount;
    bugSize = min(cellWidth, cellHeight) * bugCellScale;
    chameleonSize = cellWidth * chameleonCellScale;
  }

  Vector2 cellCenter(int column, int row) {
    final visualRow = row;
    return Vector2(
      boardPosition.x + _gridInsetLeft + (column * cellWidth) + cellWidth / 2,
      boardPosition.y +
          _gridInsetTop +
          (visualRow * cellHeight) +
          cellHeight / 2,
    );
  }

  Vector2 chameleonCenter(int column) {
    return Vector2(
      cellCenter(column, 0).x,
      boardPosition.y +
          boardSize.y +
          chameleonSize * chameleonVerticalOffsetScale,
    );
  }

  BoardCell? cellAtPosition(Vector2 position) {
    final column = columnAtPosition(position);
    if (column == null) {
      return null;
    }
    final gridTop = boardPosition.y + _gridInsetTop;
    final gridBottom = boardPosition.y + boardSize.y - _gridInsetBottom;
    if (position.y < gridTop || position.y >= gridBottom) {
      return null;
    }
    final row = ((position.y - gridTop) / cellHeight).floor();
    if (row < 0 || row >= BoardState.rowCount) {
      return null;
    }
    return BoardCell(column, row);
  }

  int? columnAtPosition(Vector2 position, {bool includeVerticalBounds = true}) {
    final gridLeft = boardPosition.x + _gridInsetLeft;
    final gridRight = boardPosition.x + boardSize.x - _gridInsetRight;
    if (position.x < gridLeft || position.x >= gridRight) {
      return null;
    }
    if (includeVerticalBounds) {
      final gridTop = boardPosition.y + _gridInsetTop;
      final gridBottom = boardPosition.y + boardSize.y - _gridInsetBottom;
      if (position.y < gridTop || position.y >= gridBottom) {
        return null;
      }
    }
    final column = ((position.x - gridLeft) / cellWidth).floor();
    if (column < 0 || column >= BoardState.columnCount) {
      return null;
    }
    return column;
  }
}
