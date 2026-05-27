import 'bug_color.dart';

enum ObjectiveType {
  makeGlow,
  moveBug,
  clearColor,
  clearTotal,
  clearBig,
  splitBig,
  reachCascade,
  reachDanger,
  clearAll,
  surviveSeconds,
}

class Objective {
  const Objective._({required this.type, required this.target, this.color});

  factory Objective.makeGlow(int target) {
    return Objective._(type: ObjectiveType.makeGlow, target: target);
  }

  factory Objective.moveBug(int target) {
    return Objective._(type: ObjectiveType.moveBug, target: target);
  }

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

  factory Objective.clearBig(int target) {
    return Objective._(type: ObjectiveType.clearBig, target: target);
  }

  factory Objective.splitBig(int target) {
    return Objective._(type: ObjectiveType.splitBig, target: target);
  }

  factory Objective.reachCascade(int target) {
    return Objective._(type: ObjectiveType.reachCascade, target: target);
  }

  factory Objective.reachDanger(int target) {
    return Objective._(type: ObjectiveType.reachDanger, target: target);
  }

  factory Objective.clearAll() {
    return const Objective._(type: ObjectiveType.clearAll, target: 1);
  }

  factory Objective.surviveSeconds(int target) {
    return Objective._(type: ObjectiveType.surviveSeconds, target: target);
  }

  final ObjectiveType type;
  final BugColor? color;
  final int target;

  /// Short UI label used in level briefs, pause objectives, and toasts.
  ///
  /// Keep these labels compact. If an objective needs more explanation, add a
  /// separate smaller help line instead of lengthening this label.
  String describe() {
    return switch (type) {
      ObjectiveType.makeGlow => 'Make $target Glow',
      ObjectiveType.moveBug => 'Move $target',
      ObjectiveType.clearColor => 'Clear $target ${color!.label}',
      ObjectiveType.clearTotal => 'Clear $target',
      ObjectiveType.clearBig => 'Clear $target BIG',
      ObjectiveType.splitBig => 'Split $target BIG',
      ObjectiveType.reachCascade => 'Cascade x$target',
      ObjectiveType.reachDanger => 'Danger x$target',
      ObjectiveType.clearAll => 'Clear Board',
      ObjectiveType.surviveSeconds => 'Survive ${target}s',
    };
  }
}
