import 'bug_color.dart';

class ChameleonState {
  ChameleonState({
    required this.columnIndex,
    this.heldColor,
    this.heldCharged = false,
    this.swallowedCount = 0,
  });

  int columnIndex;
  BugColor? heldColor;
  bool heldCharged;
  int swallowedCount;

  bool get canSwallow {
    if (heldColor == null) {
      return true;
    }
    return swallowedCount < 2 && !heldCharged;
  }

  void holdFirst(BugColor color, {bool charged = false}) {
    heldColor = color;
    heldCharged = charged;
    swallowedCount = charged ? 2 : 1;
  }

  void holdSecond(BugColor color, {bool charged = true}) {
    heldColor = color;
    heldCharged = charged;
    swallowedCount = 2;
  }

  void clearMouth() {
    heldColor = null;
    heldCharged = false;
    swallowedCount = 0;
  }
}
