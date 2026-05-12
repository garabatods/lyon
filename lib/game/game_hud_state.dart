import 'models/bug_color.dart';
import 'models/power_up.dart';

class GameHudState {
  const GameHudState({
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
    required this.statusText,
    required this.gameOver,
    required this.paused,
    required this.powerSlots,
  });

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
  final String statusText;
  final bool gameOver;
  final bool paused;
  final List<PowerUpSlotState> powerSlots;

  static const empty = GameHudState(
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
