class BoardCell {
  const BoardCell(this.column, this.row);

  final int column;
  final int row;

  @override
  bool operator ==(Object other) {
    return other is BoardCell && other.column == column && other.row == row;
  }

  @override
  int get hashCode => Object.hash(column, row);
}
