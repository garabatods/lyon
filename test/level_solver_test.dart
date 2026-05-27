import 'package:flutter_test/flutter_test.dart';

import 'package:chameleon_puzzle_demo/game/models/board_piece.dart';
import 'package:chameleon_puzzle_demo/game/models/board_state.dart';
import 'package:chameleon_puzzle_demo/game/models/bug_color.dart';
import 'package:chameleon_puzzle_demo/game/models/level_definition.dart';
import 'package:chameleon_puzzle_demo/game/models/objective.dart';
import 'package:chameleon_puzzle_demo/game/models/objective_progress.dart';
import 'package:chameleon_puzzle_demo/game/systems/level_rules_simulator.dart';
import 'package:chameleon_puzzle_demo/game/systems/level_solver.dart';
import 'package:chameleon_puzzle_demo/game/systems/objective_rescue_planner.dart';

void main() {
  group('LevelSolver', () {
    test('solves a simple glow creation objective', () {
      final level = _level(
        columns: [
          [BugColor.red],
          [BugColor.red],
          [],
          [],
          [],
          [],
        ],
        objectives: [Objective.makeGlow(1)],
        solverMaxMoves: 1,
      );

      final result = LevelSolver().solve(level);

      expect(result.solved, isTrue);
      expect(result.moves, hasLength(1));
      expect(result.moves.single.kind, SimulatedMoveKind.merge);
    });

    test('solves by dragging a glow into a same-color pair', () {
      final level = _level(
        columns: const <List<BugColor>>[[], [], [], [], [], []],
        objectives: [Objective.clearTotal(4)],
        solverMaxMoves: 1,
      );
      final board = BoardState.fromPieces([
        [const BoardPiece(BugColor.blue, charged: true)],
        [const BoardPiece(BugColor.red), const BoardPiece(BugColor.blue)],
        [const BoardPiece(BugColor.blue)],
        [],
        [],
        [],
      ]);

      final result = LevelSolver().solve(level, initialBoard: board);

      expect(result.solved, isTrue);
      expect(result.moves.single.kind, SimulatedMoveKind.move);
    });

    test('solves a BIG bug clear path', () {
      final level = _level(
        columns: const <List<BugColor>>[[], [], [], [], [], []],
        objectives: [Objective.clearBig(1)],
        solverMaxMoves: 1,
      );
      final board = BoardState.fromPieces([
        [const BoardPiece(BugColor.red), const BoardPiece(BugColor.red)],
        [const BoardPiece(BugColor.red), const BoardPiece(BugColor.red)],
        [const BoardPiece(BugColor.red)],
        [],
        [const BoardPiece(BugColor.red, charged: true)],
        [],
      ])..promoteBigBlock(column: 0, row: 0, bigId: 1);

      final result = LevelSolver().solve(level, initialBoard: board);

      expect(result.solved, isTrue);
      expect(result.moves.single.kind, SimulatedMoveKind.move);
    });

    test('solves a cascade objective path', () {
      final level = _level(
        columns: const <List<BugColor>>[[], [], [], [], [], []],
        objectives: [Objective.reachCascade(2)],
        solverMaxMoves: 1,
      );
      final board = BoardState.fromPieces([
        [
          const BoardPiece(BugColor.blue),
          const BoardPiece(BugColor.blue),
          const BoardPiece(BugColor.red),
          const BoardPiece(BugColor.blue, charged: true),
        ],
        [
          const BoardPiece(BugColor.yellow),
          const BoardPiece(BugColor.yellow),
          const BoardPiece(BugColor.red),
        ],
        [
          const BoardPiece(BugColor.orange),
          const BoardPiece(BugColor.orange),
          const BoardPiece(BugColor.red, charged: true),
        ],
        [const BoardPiece(BugColor.purple)],
        [],
        [],
      ]);

      final result = LevelSolver().solve(level, initialBoard: board);

      expect(result.solved, isTrue);
    });
  });

  group('ObjectiveAwareRescuePlanner', () {
    test('selects deterministic objective-colored rescue bugs', () {
      final level = _level(
        columns: const <List<BugColor>>[[], [], [], [], [], []],
        objectives: [Objective.clearColor(BugColor.red, 3)],
        solverMaxMoves: 4,
      );
      final board = BoardState([
        [BugColor.red],
        [BugColor.red],
        [],
        [],
        [],
        [],
      ]);
      final planner = ObjectiveAwareRescuePlanner();

      final first = planner.plan(
        level: level,
        board: board,
        progress: ObjectiveProgress.empty,
      );
      final second = planner.plan(
        level: level,
        board: board,
        progress: ObjectiveProgress.empty,
      );

      expect(first.isEmpty, isFalse);
      expect(first.solverProven, isTrue);
      expect(first.bugs.map((bug) => bug.color), everyElement(BugColor.red));
      expect(
        first.bugs.map((bug) => bug.column),
        second.bugs.map((bug) => bug.column),
      );
      expect(
        first.bugs.map((bug) => bug.color),
        second.bugs.map((bug) => bug.color),
      );
    });

    test('does not rescue when the orange glow still has a progress path', () {
      final level = _level(
        columns: const <List<BugColor>>[[], [], [], [], [], []],
        objectives: [Objective.clearTotal(4)],
        solverMaxMoves: 2,
      );
      final board = BoardState.fromPieces([
        [const BoardPiece(BugColor.red)],
        [const BoardPiece(BugColor.blue)],
        [const BoardPiece(BugColor.orange, charged: true)],
        [const BoardPiece(BugColor.yellow)],
        [const BoardPiece(BugColor.orange), const BoardPiece(BugColor.orange)],
        [const BoardPiece(BugColor.purple)],
      ]);
      final planner = ObjectiveAwareRescuePlanner();

      final plan = planner.plan(
        level: level,
        board: board,
        progress: ObjectiveProgress.empty,
      );

      expect(plan.isEmpty, isTrue);
    });

    test(
      'runtime rescue adds help for a low-inventory map01-style dead end',
      () {
        final level = _level(
          columns: const <List<BugColor>>[[], [], [], [], [], []],
          objectives: [Objective.clearTotal(24), Objective.clearAll()],
          solverMaxMoves: 6,
        );
        final board = BoardState.fromPieces([
          [const BoardPiece(BugColor.red, charged: true)],
          [const BoardPiece(BugColor.yellow, charged: true)],
          [const BoardPiece(BugColor.blue)],
          [],
          [const BoardPiece(BugColor.red, charged: true)],
          [],
        ]);
        final planner = ObjectiveAwareRescuePlanner();

        final plan = planner.plan(
          level: level,
          board: board,
          progress: const ObjectiveProgress(clearedTotal: 20),
          proveWithSolver: false,
        );

        expect(plan.isEmpty, isFalse);
        expect(plan.solverProven, isFalse);
        expect(plan.bugs, hasLength(3));
      },
    );
  });
}

LevelDefinition _level({
  required List<List<BugColor>> columns,
  required List<Objective> objectives,
  required int solverMaxMoves,
}) {
  return LevelDefinition(
    id: 'solver_fixture',
    name: 'Solver Fixture',
    columns: columns,
    objective: objectives.first,
    objectives: objectives,
    scoreTarget: 0,
    pressureEnabled: false,
    minimumBugCount: 0,
    solverMaxMoves: solverMaxMoves,
    designTags: const ['test'],
    starThresholds: const LevelStarThresholds(
      twoStarSecondsRemaining: 30,
      threeStarSecondsRemaining: 60,
    ),
  );
}
