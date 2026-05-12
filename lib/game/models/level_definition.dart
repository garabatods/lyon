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

class LevelDefinition {
  const LevelDefinition({
    required this.id,
    required this.name,
    required this.columns,
    required this.objective,
    required this.scoreTarget,
    this.startColumn = 1,
    this.tutorialText = '',
    this.pressureEnabled = true,
    this.refillIntervalSeconds = 9,
    this.minimumBugCount = 10,
    this.powerSlots = const [
      LevelPowerSlot(locked: true),
      LevelPowerSlot(locked: true),
      LevelPowerSlot(locked: true),
    ],
  });

  final String id;
  final String name;
  final List<List<BugColor>> columns;
  final Objective objective;
  final int scoreTarget;
  final int startColumn;
  final String tutorialText;
  final bool pressureEnabled;
  final double refillIntervalSeconds;
  final int minimumBugCount;
  final List<LevelPowerSlot> powerSlots;

  BoardState createBoard() => BoardState(columns);
}
