import 'bug_color.dart';

enum BoardPieceType { normal, bigAnchor, bigPart }

class BoardPiece {
  const BoardPiece(
    this.color, {
    this.charged = false,
    this.type = BoardPieceType.normal,
    this.bigId,
  });

  final BugColor color;
  final bool charged;
  final BoardPieceType type;
  final int? bigId;

  bool get isBig => type != BoardPieceType.normal;
  bool get isBigAnchor => type == BoardPieceType.bigAnchor;
  bool get isBigPart => type == BoardPieceType.bigPart;
  bool get canSwallow => !isBig;

  int get clearValue {
    if (isBigAnchor) {
      return 8;
    }
    if (isBigPart) {
      return 0;
    }
    return charged ? 2 : 1;
  }
}
