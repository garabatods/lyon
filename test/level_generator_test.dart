import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('map01 JSON source satisfies generator constraints', () {
    final json = jsonDecode(File('data/levels/map01.json').readAsStringSync());

    expect(json, isA<Map<String, dynamic>>());
    final levels = (json as Map<String, dynamic>)['levels'];
    expect(levels, isA<List>());
    expect(levels as List, hasLength(9));

    for (final entry in levels) {
      expect(entry, isA<Map<String, dynamic>>());
      final level = entry as Map<String, dynamic>;
      expect(level['id'], isA<String>());
      expect(level['id'] as String, startsWith('map01_'));
      expect(level['columns'], isA<List>());
      expect(level['columns'] as List, hasLength(6));
      for (final column in level['columns'] as List) {
        expect(column, isA<String>());
        expect((column as String).length, lessThanOrEqualTo(8));
        expect(column, matches(RegExp(r'^[rbyop]*$')));
      }
      final stars = level['stars'] as Map<String, dynamic>;
      expect(stars['threeStarElapsed'], lessThan(stars['twoStarElapsed']));
      expect(stars['twoStarElapsed'], lessThan(150));
      expect(level['solverMaxMoves'], isA<int>());
      expect(level['solverMaxMoves'] as int, greaterThan(0));
      expect(level['designTags'], isA<List>());
      final tags = level['designTags'] as List;
      expect(tags, isNotEmpty);
      expect(tags, contains('pattern'));
      final objectives = level['objectives'] as List;
      expect(
        objectives.any(
          (objective) =>
              objective is Map<String, dynamic> &&
              objective['type'] == 'surviveSeconds',
        ),
        isFalse,
        reason: 'Map01 levels should reward active puzzle goals, not waiting.',
      );
      final objectiveTypes = {
        for (final objective in objectives)
          if (objective is Map<String, dynamic>) objective['type'],
      };
      expect(
        objectiveTypes.contains('clearTotal') &&
            objectiveTypes.contains('clearAll'),
        isFalse,
        reason:
            'Map01 levels should avoid redundant clearTotal + clearAll goals.',
      );
      expect(level.containsKey('powerSlots'), isFalse);
    }
  });

  test('level generator completes successfully', () {
    final result = Process.runSync('dart', [
      'run',
      'tool/generate_levels.dart',
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File('lib/game/levels/map01_levels.g.dart').existsSync(), isTrue);
  });
}
