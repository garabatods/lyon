import 'bug_color.dart';

enum ObjectiveType { clearColor, clearTotal, reachCascade, clearAll }

class Objective {
  const Objective._({required this.type, required this.target, this.color});

  factory Objective.clearColor(BugColor color, int target) {
    return Objective._(
      type: ObjectiveType.clearColor,
      color: color,
      target: target,
    );
  }

  factory Objective.clearTotal(int target) {
    return Objective._(type: ObjectiveType.clearTotal, target: target);
  }

  factory Objective.reachCascade(int target) {
    return Objective._(type: ObjectiveType.reachCascade, target: target);
  }

  factory Objective.clearAll() {
    return const Objective._(type: ObjectiveType.clearAll, target: 1);
  }

  final ObjectiveType type;
  final BugColor? color;
  final int target;

  String describe() {
    return switch (type) {
      ObjectiveType.clearColor => 'Clear $target ${color!.label}',
      ObjectiveType.clearTotal => 'Clear $target total',
      ObjectiveType.reachCascade => 'Reach Cascade x$target',
      ObjectiveType.clearAll => 'Clear the board',
    };
  }
}
