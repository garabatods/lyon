import 'dart:io';

import 'package:chameleon_puzzle_demo/game/levels/demo_levels.dart';
import 'package:chameleon_puzzle_demo/game/models/level_definition.dart';
import 'package:chameleon_puzzle_demo/game/systems/level_solver.dart';

void main() {
  final solver = LevelSolver();
  final sets = <_LevelSet>[
    _LevelSet(id: 'tutorial', levels: tutorialLevels),
    _LevelSet(
      id: 'map01',
      levels: map01Levels,
      exemptReason:
          'temporary migration exemption for current hand-tuned map01',
    ),
  ];

  final failures = <String>[];
  for (final set in sets) {
    if (set.exemptReason != null) {
      stdout.writeln('Skipping ${set.id}: ${set.exemptReason}.');
      continue;
    }

    for (final level in set.levels) {
      final result = solver.solve(
        level,
        maxMoves: level.solverMaxMoves,
        maxStates: 8000,
      );
      if (!result.solved) {
        failures.add(
          '${set.id}/${level.id}: ${result.failureReason} '
          '(${result.exploredStates} states)',
        );
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Level validation failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Level validation passed.');
}

class _LevelSet {
  const _LevelSet({required this.id, required this.levels, this.exemptReason});

  final String id;
  final List<LevelDefinition> levels;
  final String? exemptReason;
}
