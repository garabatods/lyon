import 'board_cell.dart';
import 'board_state.dart';
import 'bug_color.dart';
import 'objective.dart';
import 'power_up.dart';

class LevelPowerSlot {
  const LevelPowerSlot({this.type, this.count = 0, this.locked = false});

  final PowerUpType? type;
  final int count;
  final bool locked;
}

class LevelStarThresholds {
  const LevelStarThresholds({
    required this.twoStarSecondsRemaining,
    required this.threeStarSecondsRemaining,
  });

  final double twoStarSecondsRemaining;
  final double threeStarSecondsRemaining;

  int starsForCompletion(double secondsRemaining) {
    if (secondsRemaining >= threeStarSecondsRemaining) {
      return 3;
    }
    if (secondsRemaining >= twoStarSecondsRemaining) {
      return 2;
    }
    return 1;
  }
}

class TutorialDragStep {
  const TutorialDragStep({
    required this.source,
    this.target,
    this.message = 'Try the highlighted move first.',
  });

  final BoardCell source;
  final BoardCell? target;
  final String message;
}

class LevelDefinition {
  const LevelDefinition({
    required this.id,
    required this.name,
    required this.columns,
    required this.objective,
    required this.scoreTarget,
    required this.starThresholds,
    this.startColumn = 1,
    this.tutorialText = '',
    this.pressureEnabled = true,
    this.refillIntervalSeconds = 9,
    this.minimumBugCount = 10,
    this.stuckHelpEnabled = false,
    this.powerSlots = const [
      LevelPowerSlot(locked: true),
      LevelPowerSlot(locked: true),
      LevelPowerSlot(locked: true),
    ],
    this.objectives = const <Objective>[],
    this.tutorialDragSteps = const <TutorialDragStep>[],
    this.solverMaxMoves = 20,
    this.designTags = const <String>[],
  });

  final String id;
  final String name;
  final List<List<BugColor>> columns;
  final Objective objective;
  final int scoreTarget;
  final LevelStarThresholds starThresholds;
  final int startColumn;
  final String tutorialText;
  final bool pressureEnabled;
  final double refillIntervalSeconds;
  final int minimumBugCount;
  final bool stuckHelpEnabled;
  final List<LevelPowerSlot> powerSlots;
  final List<Objective> objectives;
  final List<TutorialDragStep> tutorialDragSteps;

  /// Maximum move depth the validation solver should use for this level.
  ///
  /// New shipped levels should be solver-proven within this budget. Current
  /// map01 levels are temporarily exempt while they are migrated.
  final int solverMaxMoves;

  /// Compact design tags such as intro, chain, big, pressure, or color-focus.
  final List<String> designTags;

  List<Objective> get activeObjectives =>
      objectives.isEmpty ? [objective] : objectives;

  BoardState createBoard() => BoardState(columns);
}
