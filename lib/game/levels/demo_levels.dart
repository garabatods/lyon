import '../models/board_cell.dart';
import '../models/bug_color.dart';
import '../models/level_definition.dart';
import '../models/objective.dart';
import 'map01_levels.g.dart';

export 'map01_levels.g.dart';

const _lockedSlots = <LevelPowerSlot>[
  LevelPowerSlot(locked: true),
  LevelPowerSlot(locked: true),
  LevelPowerSlot(locked: true),
];

final tutorialLevels = <LevelDefinition>[
  LevelDefinition(
    id: 'tutorial_move_bug',
    name: 'Move a Bug',
    startColumn: 0,
    scoreTarget: 60,
    pressureEnabled: false,
    minimumBugCount: 0,
    stuckHelpEnabled: true,
    powerSlots: _lockedSlots,
    tutorialText: 'Move the red bug right, left, then onto a stack.',
    columns: [
      [BugColor.red],
      [],
      [],
      [BugColor.blue],
      [],
      [],
    ],
    objective: Objective.moveBug(3),
    tutorialDragSteps: const [
      TutorialDragStep(
        source: BoardCell(0, 0),
        target: BoardCell(2, 0),
        message: 'Move the red bug to the right.',
      ),
      TutorialDragStep(
        source: BoardCell(2, 0),
        target: BoardCell(1, 0),
        message: 'Now move it back to the left.',
      ),
      TutorialDragStep(
        source: BoardCell(1, 0),
        target: BoardCell(3, 1),
        message: 'Now move it onto the stack.',
      ),
    ],
    starThresholds: LevelStarThresholds(
      twoStarSecondsRemaining: 120,
      threeStarSecondsRemaining: 140,
    ),
  ),
  LevelDefinition(
    id: 'tutorial_make_glow',
    name: 'Make a Glow',
    startColumn: 2,
    scoreTarget: 120,
    pressureEnabled: false,
    minimumBugCount: 0,
    stuckHelpEnabled: true,
    powerSlots: _lockedSlots,
    tutorialText: 'Make three glows. Glows wait for a matching group.',
    columns: [
      [BugColor.red],
      [BugColor.red],
      [BugColor.blue],
      [BugColor.blue],
      [BugColor.yellow],
      [BugColor.yellow],
    ],
    objective: Objective.makeGlow(3),
    tutorialDragSteps: const [
      TutorialDragStep(
        source: BoardCell(1, 0),
        target: BoardCell(0, 0),
        message: 'Match two reds to make a glow.',
      ),
      TutorialDragStep(
        source: BoardCell(3, 0),
        target: BoardCell(2, 0),
        message: 'Now make a blue glow.',
      ),
      TutorialDragStep(
        source: BoardCell(5, 0),
        target: BoardCell(4, 0),
        message: 'Make one more yellow glow.',
      ),
    ],
    starThresholds: LevelStarThresholds(
      twoStarSecondsRemaining: 115,
      threeStarSecondsRemaining: 135,
    ),
  ),
  LevelDefinition(
    id: 'tutorial_match_bugs',
    name: 'Match Bugs',
    startColumn: 3,
    scoreTarget: 300,
    pressureEnabled: false,
    minimumBugCount: 0,
    stuckHelpEnabled: true,
    powerSlots: _lockedSlots,
    tutorialText:
        'Clear red, blue, and yellow by connecting each glow to three.',
    columns: [
      [BugColor.yellow, BugColor.blue, BugColor.red],
      [BugColor.yellow, BugColor.blue, BugColor.red],
      [BugColor.yellow, BugColor.blue, BugColor.red],
      [BugColor.yellow, BugColor.blue, BugColor.red],
      [],
      [],
    ],
    objective: Objective.clearTotal(12),
    objectives: [Objective.makeGlow(3), Objective.clearTotal(12)],
    tutorialDragSteps: const [
      TutorialDragStep(
        source: BoardCell(2, 2),
        target: BoardCell(1, 2),
        message: 'First make a red glow.',
      ),
      TutorialDragStep(
        source: BoardCell(3, 2),
        target: BoardCell(2, 2),
        message: 'Now connect a third red to clear the match.',
      ),
      TutorialDragStep(
        source: BoardCell(2, 1),
        target: BoardCell(1, 1),
        message: 'Make a blue glow next.',
      ),
      TutorialDragStep(
        source: BoardCell(3, 1),
        target: BoardCell(2, 1),
        message: 'Connect blue to clear another match.',
      ),
      TutorialDragStep(
        source: BoardCell(2, 0),
        target: BoardCell(1, 0),
        message: 'Make one more yellow glow.',
      ),
      TutorialDragStep(
        source: BoardCell(3, 0),
        target: BoardCell(2, 0),
        message: 'Connect yellow to finish the lesson.',
      ),
    ],
    starThresholds: LevelStarThresholds(
      twoStarSecondsRemaining: 115,
      threeStarSecondsRemaining: 135,
    ),
  ),
  LevelDefinition(
    id: 'tutorial_chain_drop',
    name: 'Chain Drop',
    startColumn: 3,
    scoreTarget: 280,
    pressureEnabled: false,
    refillIntervalSeconds: 9,
    minimumBugCount: 0,
    stuckHelpEnabled: true,
    powerSlots: _lockedSlots,
    tutorialText: 'Set up yellow and blue glows, then clear red to chain.',
    columns: [
      [
        BugColor.yellow,
        BugColor.blue,
        BugColor.red,
        BugColor.blue,
        BugColor.blue,
        BugColor.yellow,
      ],
      [BugColor.yellow, BugColor.purple, BugColor.red],
      [BugColor.orange, BugColor.orange, BugColor.red],
      [BugColor.red],
      [BugColor.blue],
      [BugColor.yellow],
    ],
    objective: Objective.makeGlow(3),
    objectives: [Objective.makeGlow(3), Objective.reachCascade(3)],
    tutorialDragSteps: const [
      TutorialDragStep(
        source: BoardCell(5, 0),
        target: BoardCell(1, 0),
        message: 'Make a yellow glow first. It will finish the chain later.',
      ),
      TutorialDragStep(
        source: BoardCell(4, 0),
        target: BoardCell(0, 4),
        message: 'Now make a blue glow under the red bridge.',
      ),
      TutorialDragStep(
        source: BoardCell(3, 0),
        target: BoardCell(2, 2),
        message: 'Clear red to drop blue, then yellow.',
      ),
    ],
    starThresholds: LevelStarThresholds(
      twoStarSecondsRemaining: 105,
      threeStarSecondsRemaining: 130,
    ),
  ),
  LevelDefinition(
    id: 'tutorial_big_bug',
    name: 'BIG Bug Basics',
    startColumn: 5,
    scoreTarget: 300,
    pressureEnabled: false,
    minimumBugCount: 0,
    stuckHelpEnabled: true,
    powerSlots: _lockedSlots,
    tutorialText: 'Make a glow, then place it next to the BIG bug.',
    columns: [
      [BugColor.orange, BugColor.orange],
      [BugColor.orange],
      [],
      [BugColor.orange],
      [BugColor.orange],
      [BugColor.orange],
    ],
    objective: Objective.clearBig(1),
    objectives: [
      Objective.moveBug(2),
      Objective.makeGlow(1),
      Objective.clearBig(1),
    ],
    tutorialDragSteps: const [
      TutorialDragStep(
        source: BoardCell(5, 0),
        target: BoardCell(1, 1),
        message: 'Move orange into the square to make a BIG bug.',
      ),
      TutorialDragStep(
        source: BoardCell(4, 0),
        target: BoardCell(3, 0),
        message: 'Make an orange glow away from the BIG bug.',
      ),
      TutorialDragStep(
        source: BoardCell(3, 0),
        target: BoardCell(1, 2),
        message: 'Now drag the glow below the BIG bug.',
      ),
    ],
    starThresholds: LevelStarThresholds(
      twoStarSecondsRemaining: 105,
      threeStarSecondsRemaining: 130,
    ),
  ),
  LevelDefinition(
    id: 'tutorial_danger_pressure',
    name: 'Danger Pressure',
    startColumn: 4,
    scoreTarget: 180,
    pressureEnabled: true,
    refillIntervalSeconds: 12,
    minimumBugCount: 0,
    stuckHelpEnabled: true,
    powerSlots: _lockedSlots,
    tutorialText: 'Make a glow, then use it to clear space from a full column.',
    columns: [
      [
        BugColor.blue,
        BugColor.yellow,
        BugColor.purple,
        BugColor.orange,
        BugColor.blue,
        BugColor.yellow,
        BugColor.purple,
        BugColor.red,
      ],
      [
        BugColor.purple,
        BugColor.orange,
        BugColor.blue,
        BugColor.yellow,
        BugColor.purple,
        BugColor.orange,
        BugColor.blue,
        BugColor.red,
      ],
      [
        BugColor.orange,
        BugColor.blue,
        BugColor.yellow,
        BugColor.purple,
        BugColor.orange,
        BugColor.blue,
        BugColor.yellow,
        BugColor.red,
      ],
      [],
      [BugColor.red],
      [BugColor.red],
    ],
    objective: Objective.reachDanger(1),
    objectives: [
      Objective.makeGlow(1),
      Objective.reachDanger(1),
      Objective.clearTotal(4),
    ],
    tutorialDragSteps: const [
      TutorialDragStep(
        source: BoardCell(5, 0),
        target: BoardCell(4, 0),
        message: 'Make a red glow first.',
      ),
      TutorialDragStep(
        source: BoardCell(4, 0),
        target: BoardCell(0, 7),
        message: 'Drag the red glow onto the red full column.',
      ),
    ],
    starThresholds: LevelStarThresholds(
      twoStarSecondsRemaining: 105,
      threeStarSecondsRemaining: 130,
    ),
  ),
];

final demoLevels = <LevelDefinition>[...tutorialLevels, ...map01Levels];
