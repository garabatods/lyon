import 'models/bug_color.dart';
import 'models/game_mode.dart';
import 'models/power_up.dart';

class ObjectiveHudRow {
  const ObjectiveHudRow({
    required this.key,
    required this.label,
    required this.value,
    required this.target,
    required this.complete,
  });

  final String key;
  final String label;
  final int value;
  final int target;
  final bool complete;
}

class GameHudState {
  const GameHudState({
    required this.mode,
    required this.score,
    required this.timeRemaining,
    required this.heldColor,
    required this.heldCharged,
    required this.highestCascade,
    required this.currentLevel,
    required this.nextLevelScore,
    required this.combo,
    required this.comboRemaining,
    required this.danger,
    required this.maxDanger,
    required this.objectiveText,
    required this.objectiveProgress,
    required this.objectiveTarget,
    required this.objectiveComplete,
    required this.objectiveRows,
    required this.objectiveChecklistText,
    required this.statusText,
    required this.gameOver,
    required this.paused,
    required this.powerSlots,
  });

  final GameMode mode;
  final int score;
  final double timeRemaining;
  final BugColor? heldColor;
  final bool heldCharged;
  final int highestCascade;
  final int currentLevel;
  final int nextLevelScore;
  final int combo;
  final double comboRemaining;
  final int danger;
  final int maxDanger;
  final String objectiveText;
  final int objectiveProgress;
  final int objectiveTarget;
  final bool objectiveComplete;
  final List<ObjectiveHudRow> objectiveRows;
  final String objectiveChecklistText;
  final String statusText;
  final bool gameOver;
  final bool paused;
  final List<PowerUpSlotState> powerSlots;

  static const empty = GameHudState(
    mode: GameMode.adventure,
    score: 0,
    timeRemaining: 150,
    heldColor: null,
    heldCharged: false,
    highestCascade: 0,
    currentLevel: 1,
    nextLevelScore: 800,
    combo: 0,
    comboRemaining: 0,
    danger: 0,
    maxDanger: 5,
    objectiveText: '',
    objectiveProgress: 0,
    objectiveTarget: 1,
    objectiveComplete: false,
    objectiveRows: <ObjectiveHudRow>[],
    objectiveChecklistText: '',
    statusText: '',
    gameOver: false,
    paused: false,
    powerSlots: <PowerUpSlotState>[
      PowerUpSlotState(
        type: PowerUpType.water,
        count: 0,
        locked: false,
        selected: false,
      ),
      PowerUpSlotState(
        type: PowerUpType.bloom,
        count: 0,
        locked: false,
        selected: false,
      ),
      PowerUpSlotState(
        type: PowerUpType.berry,
        count: 0,
        locked: false,
        selected: false,
      ),
    ],
  );
}
