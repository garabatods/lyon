import 'dart:convert';
import 'dart:io';

const _roundSeconds = 150;
const _sourcePath = 'data/levels/map01.json';
const _outputPath = 'lib/game/levels/map01_levels.g.dart';
const _colors = {
  'r': 'BugColor.red',
  'b': 'BugColor.blue',
  'y': 'BugColor.yellow',
  'o': 'BugColor.orange',
  'p': 'BugColor.purple',
};
const _colorNames = {
  'red': 'BugColor.red',
  'blue': 'BugColor.blue',
  'yellow': 'BugColor.yellow',
  'orange': 'BugColor.orange',
  'purple': 'BugColor.purple',
};

void main() {
  final source = File(_sourcePath);
  if (!source.existsSync()) {
    _fail('Missing $_sourcePath');
  }

  final root = jsonDecode(source.readAsStringSync());
  if (root is! Map<String, dynamic>) {
    _fail('Root JSON must be an object.');
  }
  if (root['id'] != 'map01') {
    _fail('Only map01 generation is supported.');
  }
  final levels = root['levels'];
  if (levels is! List || levels.isEmpty) {
    _fail('Map01 must define at least one level.');
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Generated from $_sourcePath by tool/generate_levels.dart.')
    ..writeln()
    ..writeln("import '../models/bug_color.dart';")
    ..writeln("import '../models/level_definition.dart';")
    ..writeln("import '../models/objective.dart';")
    ..writeln()
    ..writeln('const _lockedSlots = <LevelPowerSlot>[')
    ..writeln('  LevelPowerSlot(locked: true),')
    ..writeln('  LevelPowerSlot(locked: true),')
    ..writeln('  LevelPowerSlot(locked: true),')
    ..writeln('];')
    ..writeln()
    ..writeln('final map01Levels = <LevelDefinition>[');

  for (var index = 0; index < levels.length; index += 1) {
    final level = levels[index];
    if (level is! Map<String, dynamic>) {
      _fail('Level ${index + 1} must be an object.');
    }
    _writeLevel(buffer, level, index);
  }

  buffer.writeln('];');

  File(_outputPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());
  final format = Process.runSync(Platform.resolvedExecutable, [
    'format',
    _outputPath,
  ]);
  if (format.exitCode != 0) {
    _fail(format.stderr.toString());
  }
}

void _writeLevel(StringBuffer buffer, Map<String, dynamic> level, int index) {
  final id = _requiredString(level, 'id', index);
  if (!id.startsWith('map01_')) {
    _fail('Level ${index + 1} id must start with map01_.');
  }
  final name = _requiredString(level, 'name', index);
  final startColumn = _requiredInt(level, 'startColumn', index);
  if (startColumn < 0 || startColumn > 5) {
    _fail('$id startColumn must be between 0 and 5.');
  }
  final columns = level['columns'];
  if (columns is! List || columns.length != 6) {
    _fail('$id must have exactly six columns.');
  }
  final pressure = level['pressure'];
  if (pressure is! Map<String, dynamic>) {
    _fail('$id pressure must be an object.');
  }
  final pressureEnabled = pressure['enabled'];
  if (pressureEnabled is! bool) {
    _fail('$id pressure.enabled must be a bool.');
  }
  final refillInterval = _optionalNum(
    pressure,
    'refillIntervalSeconds',
    defaultValue: 9,
    levelId: id,
  );
  final minimumBugCount = _requiredInt(pressure, 'minimumBugCount', index);
  if (minimumBugCount < 0 || minimumBugCount > 45) {
    _fail('$id pressure.minimumBugCount must be between 0 and 45.');
  }
  final objectives = level['objectives'];
  if (objectives is! List || objectives.isEmpty) {
    _fail('$id must define at least one objective.');
  }
  final scoreTarget = _requiredInt(level, 'scoreTarget', index);
  final solverMaxMoves = _optionalInt(
    level,
    'solverMaxMoves',
    defaultValue: 20,
    levelId: id,
  );
  final designTags = _optionalStringList(level, 'designTags', levelId: id);
  final stars = level['stars'];
  if (stars is! Map<String, dynamic>) {
    _fail('$id stars must be an object.');
  }
  final threeStarElapsed = _requiredInt(stars, 'threeStarElapsed', index);
  final twoStarElapsed = _requiredInt(stars, 'twoStarElapsed', index);
  if (threeStarElapsed <= 0 ||
      twoStarElapsed <= threeStarElapsed ||
      twoStarElapsed >= _roundSeconds) {
    _fail(
      '$id stars must satisfy 0 < threeStarElapsed < twoStarElapsed < 150.',
    );
  }

  buffer
    ..writeln('  LevelDefinition(')
    ..writeln("    id: '$id',")
    ..writeln("    name: '$name',")
    ..writeln('    startColumn: $startColumn,')
    ..writeln('    scoreTarget: $scoreTarget,')
    ..writeln('    pressureEnabled: $pressureEnabled,')
    ..writeln('    refillIntervalSeconds: $refillInterval,')
    ..writeln('    minimumBugCount: $minimumBugCount,')
    ..writeln('    stuckHelpEnabled: true,')
    ..writeln('    powerSlots: _lockedSlots,')
    ..writeln("    tutorialText: '',")
    ..writeln('    columns: [');
  for (final column in columns) {
    if (column is! String || column.length > 8) {
      _fail('$id columns must be strings with at most eight colors.');
    }
    final colors = <String>[];
    for (final codeUnit in column.codeUnits) {
      final color = _colors[String.fromCharCode(codeUnit)];
      if (color == null) {
        _fail('$id uses an unknown column color.');
      }
      colors.add(color);
    }
    buffer.writeln('      [${colors.join(', ')}],');
  }
  buffer
    ..writeln('    ],')
    ..writeln('    objective: ${_objective(objectives.first, id)},')
    ..writeln('    objectives: [');
  for (final objective in objectives) {
    buffer.writeln('      ${_objective(objective, id)},');
  }
  buffer
    ..writeln('    ],')
    ..writeln('    solverMaxMoves: $solverMaxMoves,')
    ..writeln(
      '    designTags: [${designTags.map((tag) => "'$tag'").join(', ')}],',
    )
    ..writeln('    starThresholds: const LevelStarThresholds(')
    ..writeln(
      '      twoStarSecondsRemaining: ${_roundSeconds - twoStarElapsed},',
    )
    ..writeln(
      '      threeStarSecondsRemaining: ${_roundSeconds - threeStarElapsed},',
    )
    ..writeln('    ),')
    ..writeln('  ),');
}

String _objective(Object? json, String levelId) {
  if (json is! Map<String, dynamic>) {
    _fail('$levelId objective must be an object.');
  }
  final type = json['type'];
  if (type is! String) {
    _fail('$levelId objective.type must be a string.');
  }
  int target() => _requiredInt(json, 'target', 0);
  return switch (type) {
    'makeGlow' => 'Objective.makeGlow(${target()})',
    'moveBug' => 'Objective.moveBug(${target()})',
    'clearTotal' => 'Objective.clearTotal(${target()})',
    'clearBig' => 'Objective.clearBig(${target()})',
    'splitBig' => 'Objective.splitBig(${target()})',
    'reachCascade' => 'Objective.reachCascade(${target()})',
    'reachDanger' => 'Objective.reachDanger(${target()})',
    'surviveSeconds' => 'Objective.surviveSeconds(${target()})',
    'clearAll' => 'Objective.clearAll()',
    'clearColor' => _clearColorObjective(json, levelId),
    _ => _fail('$levelId unknown objective type $type.'),
  };
}

String _clearColorObjective(Map<String, dynamic> json, String levelId) {
  final colorName = json['color'];
  final color = _colorNames[colorName];
  if (color == null) {
    _fail('$levelId clearColor must use a known color name.');
  }
  return 'Objective.clearColor($color, ${_requiredInt(json, 'target', 0)})';
}

String _requiredString(Map<String, dynamic> json, String key, int index) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value.replaceAll("'", r"\'");
  }
  _fail('Level ${index + 1} $key must be a non-empty string.');
}

int _requiredInt(Map<String, dynamic> json, String key, int index) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  _fail('Level ${index + 1} $key must be an integer.');
}

int _optionalInt(
  Map<String, dynamic> json,
  String key, {
  required int defaultValue,
  required String levelId,
}) {
  final value = json[key];
  if (value == null) {
    return defaultValue;
  }
  if (value is int && value > 0) {
    return value;
  }
  _fail('$levelId $key must be a positive integer.');
}

List<String> _optionalStringList(
  Map<String, dynamic> json,
  String key, {
  required String levelId,
}) {
  final value = json[key];
  if (value == null) {
    return const <String>[];
  }
  if (value is! List) {
    _fail('$levelId $key must be a list of strings.');
  }
  return [
    for (final entry in value)
      if (entry is String && entry.isNotEmpty)
        entry.replaceAll("'", r"\'")
      else
        _fail('$levelId $key entries must be non-empty strings.'),
  ];
}

num _optionalNum(
  Map<String, dynamic> json,
  String key, {
  required num defaultValue,
  required String levelId,
}) {
  final value = json[key] ?? defaultValue;
  if (value is num) {
    return value;
  }
  _fail('$levelId $key must be numeric.');
}

Never _fail(String message) {
  stderr.writeln(message);
  exitCode = 1;
  throw StateError(message);
}
