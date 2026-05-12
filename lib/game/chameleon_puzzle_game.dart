import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'assets/game_assets.dart';
import 'board_layout.dart';
import 'components/background_component.dart';
import 'components/board_cell_shade_component.dart';
import 'components/board_component.dart';
import 'components/chameleon_component.dart';
import 'components/column_warning_component.dart';
import 'components/floating_text_component.dart';
import 'components/fx_component.dart';
import 'components/ladybug_component.dart';
import 'components/level_banner_component.dart';
import 'components/power_target_component.dart';
import 'game_hud_state.dart';
import 'levels/demo_levels.dart';
import 'models/board_cell.dart';
import 'models/board_piece.dart';
import 'models/board_state.dart';
import 'models/bug_color.dart';
import 'models/chameleon_state.dart';
import 'models/game_save.dart';
import 'models/level_definition.dart';
import 'models/power_up.dart';
import 'systems/match_system.dart';
import 'systems/power_up_system.dart';
import 'systems/pressure_row_generator.dart';

enum _QueuedAction { swallow, spit }

class _BugDrag {
  _BugDrag({
    required this.originColumn,
    required this.piece,
    required this.component,
  });

  final int originColumn;
  final BoardPiece piece;
  final LadybugComponent component;
}

class ChameleonPuzzleGame extends FlameGame
    with PanDetector, MultiTouchTapDetector {
  ChameleonPuzzleGame({GameSave? initialSave}) : _initialSave = initialSave;

  static const double roundSeconds = 150;
  static const double chainTimeBonusSeconds = 4;
  static const double maxTimeSeconds = 180;
  static const double comboWindowBaseSeconds = 2.0;
  static const double comboWindowBigClearBonus = 0.75;
  static const double comboWindowCascadeBonus = 0.35;
  static const int maxDanger = 5;

  final hud = ValueNotifier<GameHudState>(GameHudState.empty);

  final _matchSystem = MatchSystem();
  final _powerUpSystem = PowerUpSystem();
  final _pressureRowGenerator = PressureRowGenerator();
  final _ladybugs = <LadybugComponent>[];
  final _cellShades = <BoardCellShadeComponent>[];
  final _columnWarnings = <ColumnWarningComponent>[];
  final _powerTargets = <PowerTargetComponent>[];
  final _random = Random();

  BoardState board = demoLevels[0].createBoard();
  ChameleonState chameleon = ChameleonState(
    columnIndex: demoLevels[0].startColumn,
  );
  LevelDefinition level = demoLevels[0];
  late BoardLayout layout;

  BackgroundComponent? _background;
  BoardComponent? _boardFrame;
  ChameleonComponent? _chameleonComponent;

  int levelIndex = 0;
  int score = 0;
  int highestCascade = 0;
  int currentArcadeLevel = 1;
  int nextLevelScore = 800;
  int combo = 0;
  int danger = 0;
  final powerCounts = <PowerUpType, int>{};
  double comboRemaining = 0;
  double timeRemaining = roundSeconds;
  double _refillTimer = 5.0;
  String statusText = 'Score as much as you can.';
  bool gameOver = false;
  bool _paused = false;
  bool _busy = false;
  bool _assetsReady = false;
  bool _facingRight = false;
  bool _hudUpdateScheduled = false;
  int _gameOverToken = 0;
  int _levelAdvanceToken = 0;
  int _nextBigBugId = 1;
  _QueuedAction? _queuedAction;
  _BugDrag? _drag;
  PowerUpType? selectedPowerUp;
  bool _levelComplete = false;
  BoardCell? _previewTargetCell;
  Vector2? _lastDragPosition;
  GameHudState? _pendingHudState;
  final GameSave? _initialSave;

  @override
  void update(double dt) {
    if (_paused) {
      return;
    }
    super.update(dt);
    if (!_assetsReady || gameOver) {
      return;
    }

    timeRemaining = (timeRemaining - dt).clamp(0, roundSeconds);
    if (comboRemaining > 0) {
      comboRemaining = (comboRemaining - dt).clamp(0, comboRemaining);
      if (comboRemaining <= 0) {
        combo = 0;
      }
    }

    if (!_busy) {
      if (level.pressureEnabled &&
          _totalBugCount < _minimumBugCountForLevel()) {
        _refillTimer = min(_refillTimer, 0.25);
      }
      if (level.pressureEnabled) {
        _refillTimer -= dt;
      }
      if (level.pressureEnabled && _refillTimer <= 0) {
        _refillTimer = _currentRefillInterval();
        unawaited(_timedRefill());
      }
    }

    if (timeRemaining <= 0) {
      _endGame();
    } else {
      _updateHud();
    }
  }

  @override
  Color backgroundColor() => const Color(0xFF10281D);

  @override
  Future<void> onLoad() async {
    await images.loadAll(GameAssets.allImages());
    _assetsReady = true;
    layout = BoardLayout(size);

    _background = BackgroundComponent(sprite: _sprite(GameAssets.background));
    _boardFrame = BoardComponent(sprite: _sprite(GameAssets.board));
    _chameleonComponent = ChameleonComponent(
      spriteFactory: _sprite,
      center: Vector2.zero(),
      chameleonSize: 96,
    );

    await addAll([_background!, _boardFrame!, _chameleonComponent!]);
    _syncLayout();
    final save = _initialSave;
    if (save == null) {
      loadLevel(0);
    } else {
      _restoreSave(save);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x <= 0 || size.y <= 0) {
      return;
    }
    layout = BoardLayout(size);
    _syncLayout();
    if (_assetsReady) {
      _refreshBoardComponents();
    }
  }

  Sprite _sprite(String path) => Sprite(images.fromCache(path));

  SpriteAnimation _ladybugAnimation(BugColor color) {
    return SpriteAnimation.spriteList([
      _sprite(GameAssets.ladybugFrame(color, 1)),
      _sprite(GameAssets.ladybugFrame(color, 2)),
      _sprite(GameAssets.ladybugFrame(color, 1)),
      _sprite(GameAssets.ladybugFrame(color, 3)),
    ], stepTime: 0.2);
  }

  void _syncLayout() {
    _background
      ?..position = Vector2.zero()
      ..size = size;

    _boardFrame
      ?..position = layout.boardPosition
      ..size = layout.boardSize;

    final chameleonComponent = _chameleonComponent;
    if (chameleonComponent != null) {
      chameleonComponent
        ..position = layout.chameleonCenter(chameleon.columnIndex)
        ..size = Vector2.all(layout.chameleonSize);
      chameleonComponent.setFacingRight(_facingRight);
    }
  }

  void loadLevel(int index) {
    levelIndex = index.clamp(0, demoLevels.length - 1);
    level = demoLevels[levelIndex];
    board = level.createBoard();
    chameleon = ChameleonState(columnIndex: level.startColumn);
    score = 0;
    highestCascade = 0;
    currentArcadeLevel = levelIndex + 1;
    nextLevelScore = level.scoreTarget;
    combo = 0;
    comboRemaining = 0;
    danger = 0;
    powerCounts
      ..clear()
      ..addAll(_startingPowerCountsFor(level));
    timeRemaining = roundSeconds;
    _refillTimer = _currentRefillInterval();
    statusText = level.tutorialText.isEmpty ? level.name : level.tutorialText;
    gameOver = false;
    _paused = false;
    _gameOverToken += 1;
    _levelAdvanceToken += 1;
    _nextBigBugId = 1;
    _queuedAction = null;
    selectedPowerUp = null;
    _previewTargetCell = null;
    _clearPowerPreview();
    _drag?.component.removeFromParent();
    _drag = null;
    _lastDragPosition = null;
    _busy = false;
    _levelComplete = false;
    _facingRight = false;
    _chameleonComponent?.playIdle(null);
    _syncLayout();
    _refreshBoardComponents();
    _updateHud();
  }

  void resetLevel() {
    loadLevel(levelIndex);
  }

  void startNewGame() {
    loadLevel(0);
  }

  Map<PowerUpType, int> _startingPowerCountsFor(LevelDefinition definition) {
    return {
      for (final slot in definition.powerSlots)
        if (!slot.locked && slot.type != null) slot.type!: max(0, slot.count),
    };
  }

  bool get canSaveActiveRun {
    return _assetsReady && !gameOver && _drag == null && timeRemaining > 0;
  }

  GameSave? snapshotForSave() {
    if (!canSaveActiveRun) {
      return null;
    }
    return GameSave(
      levelIndex: levelIndex,
      columns: [
        for (final column in board.columns) [for (final piece in column) piece],
      ],
      chameleon: ChameleonState(
        columnIndex: chameleon.columnIndex,
        heldColor: chameleon.heldColor,
        heldCharged: chameleon.heldCharged,
        swallowedCount: chameleon.swallowedCount,
      ),
      score: score,
      highestCascade: highestCascade,
      currentArcadeLevel: currentArcadeLevel,
      nextLevelScore: nextLevelScore,
      combo: combo,
      comboRemaining: comboRemaining,
      danger: danger,
      powerCounts: Map<PowerUpType, int>.from(powerCounts),
      timeRemaining: timeRemaining,
      refillTimer: _refillTimer,
      facingRight: _facingRight,
      nextBigBugId: _nextBigBugId,
    );
  }

  void _restoreSave(GameSave save) {
    levelIndex = save.levelIndex.clamp(0, demoLevels.length - 1);
    level = demoLevels[levelIndex];
    board = save.toBoardState();
    chameleon = ChameleonState(
      columnIndex: save.chameleon.columnIndex,
      heldColor: save.chameleon.heldColor,
      heldCharged: save.chameleon.heldCharged,
      swallowedCount: save.chameleon.swallowedCount,
    );
    score = save.score;
    highestCascade = save.highestCascade;
    currentArcadeLevel = levelIndex + 1;
    nextLevelScore = level.scoreTarget;
    combo = save.combo;
    comboRemaining = save.comboRemaining;
    danger = save.danger.clamp(0, maxDanger).toInt();
    powerCounts
      ..clear()
      ..addAll(save.powerCounts);
    timeRemaining = save.timeRemaining.clamp(1, maxTimeSeconds).toDouble();
    _refillTimer = save.refillTimer;
    statusText = 'Welcome back';
    gameOver = false;
    _paused = false;
    _gameOverToken += 1;
    _nextBigBugId = save.nextBigBugId;
    _queuedAction = null;
    selectedPowerUp = null;
    _previewTargetCell = null;
    _clearPowerPreview();
    _drag?.component.removeFromParent();
    _drag = null;
    _lastDragPosition = null;
    _busy = false;
    _levelComplete = false;
    _facingRight = save.facingRight;
    _chameleonComponent?.playIdle(chameleon.heldColor);
    _syncLayout();
    _refreshBoardComponents();
    _updateHud();
  }

  void togglePaused() {
    if (gameOver) {
      return;
    }
    _paused = !_paused;
    if (_paused) {
      statusText = 'Paused';
      _drag?.component.removeFromParent();
      _drag = null;
      _clearPowerPreview();
      _busy = false;
    } else {
      statusText = selectedPowerUp == null
          ? 'Back to the jungle'
          : 'Choose a target';
    }
    _updateHud();
  }

  void selectPowerUp(PowerUpType type) {
    if (gameOver || _paused || _levelComplete) {
      return;
    }
    final count = powerCounts[type] ?? 0;
    if (count <= 0) {
      selectedPowerUp = null;
      _clearPowerPreview();
      statusText = '${type.label} is empty';
      _updateHud();
      return;
    }
    if (type == PowerUpType.firefly) {
      selectedPowerUp = null;
      _clearPowerPreview();
      unawaited(_applyImmediatePowerUp(type));
      return;
    }
    selectedPowerUp = selectedPowerUp == type ? null : type;
    _clearPowerPreview();
    statusText = selectedPowerUp == null
        ? 'Power canceled'
        : '${type.label}: choose a target';
    _updateHud();
  }

  void moveLeft() {
    _moveBy(-1);
  }

  void moveRight() {
    _moveBy(1);
  }

  void moveToColumn(int column) {
    if (gameOver || _paused || _levelComplete || _drag != null) {
      return;
    }
    _moveToColumn(column.clamp(0, BoardState.columnCount - 1));
  }

  void _moveBy(int delta) {
    if (gameOver || _paused || _levelComplete || _drag != null) {
      return;
    }
    final next = (chameleon.columnIndex + delta).clamp(
      0,
      BoardState.columnCount - 1,
    );
    if (next == chameleon.columnIndex) {
      return;
    }
    _moveToColumn(next);
  }

  void _moveToColumn(int next) {
    if (next == chameleon.columnIndex) {
      return;
    }
    final delta = next - chameleon.columnIndex;
    chameleon.columnIndex = next;
    _facingRight = delta > 0;
    statusText = 'Column ${next + 1}';
    _chameleonComponent
      ?..position = layout.chameleonCenter(next)
      ..setFacingRight(_facingRight)
      ..playWalk(chameleon.heldColor);
    _updateHud();
    unawaited(_returnToIdleAfter(const Duration(milliseconds: 120)));
  }

  Future<void> swallow() async {
    if (gameOver || _paused || _levelComplete) {
      return;
    }
    if (_busy) {
      _queuedAction = _QueuedAction.swallow;
      return;
    }
    final column = chameleon.columnIndex;
    if (board.isColumnEmpty(column)) {
      statusText = 'Nothing to swallow!';
      _updateHud();
      return;
    }
    final swallowedRow = board.columns[column].length - 1;
    final swallowedPiece = board.columns[column].last;
    if (!swallowedPiece.canSwallow) {
      statusText = 'BIG bugs won\'t fit!';
      _updateHud();
      return;
    }
    final swallowed = swallowedPiece.color;
    final held = chameleon.heldColor;
    if (!chameleon.canSwallow) {
      statusText = 'Spit first!';
      _updateHud();
      return;
    }

    if (held != null && held != swallowed) {
      statusText = 'Same color only!';
      _updateHud();
      return;
    }

    _busy = true;
    final fallStarts = _fallStartPositions({BoardCell(column, swallowedRow)});
    board.removeBottom(column);
    if (held == null) {
      chameleon.holdFirst(swallowed, charged: swallowedPiece.charged);
    } else {
      chameleon.holdSecond(swallowed, charged: true);
    }
    statusText = held == null
        ? chameleon.heldCharged
              ? 'Holding Glowing ${swallowed.label}'
              : 'Holding ${swallowed.label}'
        : chameleon.heldCharged
        ? 'Glowing ${swallowed.label}'
        : 'Holding ${swallowed.label}';
    _refreshBoardComponents(fallStarts: fallStarts);
    _chameleonComponent?.playSwallow(swallowed);
    _updateHud();
    await Future<void>.delayed(const Duration(milliseconds: 290));
    _chameleonComponent?.playIdle(chameleon.heldColor);
    await _resolveCascades(playerDriven: true);
    _finishBusy();
  }

  Future<void> spit() async {
    if (gameOver || _paused || _levelComplete) {
      return;
    }
    if (_busy) {
      _queuedAction = _QueuedAction.spit;
      return;
    }
    final spitColor = chameleon.heldColor;
    final spitCharged = chameleon.heldCharged;
    if (spitColor == null) {
      statusText = 'Nothing to spit!';
      _updateHud();
      return;
    }
    final column = chameleon.columnIndex;
    _busy = true;
    final overloaded = board.isColumnFull(column);
    board.insertPieceBottom(
      column,
      BoardPiece(spitColor, charged: spitCharged),
    );
    if (board.columns[column].length > BoardState.rowCount) {
      board.clearCells({BoardCell(column, 0)});
    }
    if (overloaded) {
      _addDanger(column);
    }

    chameleon.clearMouth();
    if (!overloaded) {
      statusText = spitCharged
          ? 'Spat Charged ${spitColor.label}'
          : 'Spat ${spitColor.label}';
    }
    _refreshBoardComponents();
    _chameleonComponent?.playSpit(spitColor);
    _updateHud();
    await Future<void>.delayed(const Duration(milliseconds: 290));
    _chameleonComponent?.playIdle(null);
    final cleared = await _resolveCascades(playerDriven: true);
    if (danger >= maxDanger) {
      _endGame(status: 'Danger maxed!');
      return;
    }
    if (!gameOver) {
      if (cleared) {
        _refillTimer = max(_refillTimer, combo >= 3 ? 5.0 : 3.25);
        statusText = combo >= 3 ? 'Combo breather' : 'Clear!';
      }
      _checkNoMoves();
    }
    _finishBusy();
  }

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    final powerUp = selectedPowerUp;
    if (powerUp == null) {
      return;
    }
    _lastDragPosition = info.eventPosition.widget;
    _previewPowerTarget(info.eventPosition.widget, powerUp);
  }

  @override
  void onTapUp(int pointerId, TapUpInfo info) {
    final powerUp = selectedPowerUp;
    if (powerUp == null) {
      return;
    }
    _lastDragPosition = null;
    _clearPowerPreview();
    unawaited(_applySelectedPowerUp(info.eventPosition.widget, powerUp));
  }

  @override
  void onTapCancel(int pointerId) {
    _clearPowerPreview();
  }

  @override
  void onPanStart(DragStartInfo info) {
    final position = info.eventPosition.widget;
    final powerUp = selectedPowerUp;
    if (powerUp != null) {
      _lastDragPosition = position;
      _previewPowerTarget(position, powerUp);
      return;
    }
    _lastDragPosition = position;
    startBugDrag(position);
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    final position = info.eventPosition.widget;
    _lastDragPosition = position;
    final powerUp = selectedPowerUp;
    if (powerUp != null) {
      _previewPowerTarget(position, powerUp);
      return;
    }
    updateBugDrag(position);
  }

  @override
  void onPanEnd(DragEndInfo info) {
    final position = _lastDragPosition;
    _lastDragPosition = null;
    final powerUp = selectedPowerUp;
    if (powerUp != null) {
      _clearPowerPreview();
      if (position != null) {
        unawaited(_applySelectedPowerUp(position, powerUp));
      }
      return;
    }
    if (position == null) {
      cancelBugDrag();
      return;
    }
    unawaited(endBugDrag(position));
  }

  @override
  void onPanCancel() {
    _lastDragPosition = null;
    _clearPowerPreview();
    cancelBugDrag();
  }

  void startBugDrag(Vector2 position) {
    if (gameOver ||
        _paused ||
        _busy ||
        _levelComplete ||
        !_assetsReady ||
        selectedPowerUp != null) {
      return;
    }
    final cell = layout.cellAtPosition(position);
    if (cell == null) {
      return;
    }
    final column = cell.column;
    if (board.isColumnEmpty(column)) {
      return;
    }
    final bottomRow = board.columns[column].length - 1;
    if (cell.row != bottomRow) {
      statusText = 'Drag the lowest bug';
      _updateHud();
      return;
    }
    final piece = board.pieceAt(column, bottomRow);
    if (piece == null || !piece.canSwallow) {
      statusText = 'BIG bugs won\'t move!';
      _updateHud();
      return;
    }

    _busy = true;
    board.removeBottom(column);
    final component = LadybugComponent(
      animation: _ladybugAnimation(piece.color),
      color: piece.color,
      charged: piece.charged,
      center: position,
      bugSize: layout.bugSize * 1.08,
    )..priority = 80;
    _drag = _BugDrag(originColumn: column, piece: piece, component: component);
    add(component);
    statusText = 'Moving ${piece.color.label}';
    _refreshBoardComponents();
    _updateHud();
  }

  void updateBugDrag(Vector2 position) {
    final drag = _drag;
    if (drag == null) {
      return;
    }
    drag.component.position = position;
  }

  Future<void> endBugDrag(Vector2 position) async {
    final drag = _drag;
    if (drag == null) {
      return;
    }

    final dropCell = layout.cellAtPosition(position);
    final destination = dropCell?.column;
    final valid = destination != null;

    drag.component.removeFromParent();
    _drag = null;

    if (!valid) {
      _restoreDraggedBug(drag, status: 'Move canceled');
      _finishBusy();
      return;
    }

    final targetRow = board.columns[destination].length - 1;
    final target = targetRow >= 0
        ? board.pieceAt(destination, targetRow)
        : null;
    final droppedOnLowestBug = dropCell!.row == targetRow;
    final merged =
        droppedOnLowestBug &&
        target != null &&
        target.canSwallow &&
        !target.charged &&
        !drag.piece.charged &&
        target.color == drag.piece.color;

    if (destination == drag.originColumn && !merged) {
      _restoreDraggedBug(drag, status: 'Move canceled');
      _finishBusy();
      return;
    }

    if (merged) {
      board.setPiece(
        destination,
        targetRow,
        BoardPiece(drag.piece.color, charged: true),
      );
      statusText = 'Glowing ${drag.piece.color.label}!';
      _spawnFloatingText(
        'GLOW!',
        layout.cellCenter(destination, targetRow),
        const Color(0xFFFFF2B2),
        fontSize: 27,
      );
    } else {
      final overloaded = board.isColumnFull(destination);
      board.insertPieceBottom(destination, drag.piece);
      if (board.columns[destination].length > BoardState.rowCount) {
        board.clearCells({BoardCell(destination, 0)});
      }
      if (overloaded) {
        _addDanger(destination);
      }
      if (!overloaded) {
        statusText = 'Moved ${drag.piece.color.label}';
      }
    }

    _refreshBoardComponents();
    _updateHud();
    await _resolveCascades(playerDriven: true);
    if (!gameOver) {
      if (danger >= maxDanger) {
        _endGame(status: 'Danger maxed!');
        return;
      }
      _checkNoMoves();
    }
    _finishBusy();
  }

  void cancelBugDrag() {
    final drag = _drag;
    if (drag == null) {
      return;
    }
    drag.component.removeFromParent();
    _drag = null;
    _restoreDraggedBug(drag, status: 'Move canceled');
    _finishBusy();
  }

  void _previewPowerTarget(Vector2 position, PowerUpType type) {
    if (gameOver || _paused || _busy || _levelComplete || !_assetsReady) {
      return;
    }
    final target = layout.cellAtPosition(position);
    if (target == null || target == _previewTargetCell) {
      if (target == null) {
        _previewTargetCell = null;
        _clearPowerPreview();
      }
      return;
    }

    _previewTargetCell = target;
    _clearPowerPreview(resetTarget: false);
    final color = _targetColorFor(type);
    final cells = _previewCellsFor(type, target);
    for (final cell in cells) {
      final component = PowerTargetComponent(
        center: layout.cellCenter(cell.column, cell.row),
        size: Vector2(layout.cellWidth * 0.88, layout.cellHeight * 0.88),
        color: color,
      );
      _powerTargets.add(component);
      add(component);
    }

    final reticle = PowerTargetComponent(
      center: layout.cellCenter(target.column, target.row),
      size: Vector2(layout.cellWidth * 1.04, layout.cellHeight * 1.04),
      color: color,
      reticle: true,
    );
    _powerTargets.add(reticle);
    add(reticle);
  }

  Set<BoardCell> _previewCellsFor(PowerUpType type, BoardCell target) {
    return switch (type) {
      PowerUpType.berry => {
        for (var row = 0; row < board.columns[target.column].length; row += 1)
          BoardCell(target.column, row),
      },
      PowerUpType.bloom => {
        for (var column = 0; column < BoardState.columnCount; column += 1)
          if (board.pieceAt(column, target.row) != null)
            BoardCell(column, target.row),
      },
      PowerUpType.pollen => {
        for (
          var column = max(0, target.column - 1);
          column <= min(BoardState.columnCount - 1, target.column + 1);
          column += 1
        )
          for (
            var row = max(0, target.row - 1);
            row <= min(BoardState.rowCount - 1, target.row + 1);
            row += 1
          )
            BoardCell(column, row),
      },
      PowerUpType.water => _waterPreviewCells(target),
      PowerUpType.firefly => const <BoardCell>{},
    };
  }

  Set<BoardCell> _waterPreviewCells(BoardCell target) {
    final color = board.colorAt(target.column, target.row);
    if (color == null) {
      return const <BoardCell>{};
    }
    return {
      for (var column = 0; column < BoardState.columnCount; column += 1)
        for (var row = 0; row < board.columns[column].length; row += 1)
          if (board.colorAt(column, row) == color) BoardCell(column, row),
    };
  }

  Color _targetColorFor(PowerUpType type) {
    return switch (type.rarity) {
      PowerUpRarity.common => const Color(0xFFBDF77E),
      PowerUpRarity.uncommon => const Color(0xFF61D9FF),
      PowerUpRarity.rare => const Color(0xFFFFE35C),
      PowerUpRarity.ultraRare => const Color(0xFFFF7CFF),
    };
  }

  void _clearPowerPreview({bool resetTarget = true}) {
    for (final target in _powerTargets) {
      target.removeFromParent();
    }
    _powerTargets.clear();
    if (resetTarget) {
      _previewTargetCell = null;
    }
  }

  Future<void> _applyImmediatePowerUp(PowerUpType type) async {
    if (gameOver || _paused || _busy || _levelComplete || !_assetsReady) {
      return;
    }
    _busy = true;
    final applied = await _applyPowerUp(type, const BoardCell(0, 0));
    if (applied) {
      powerCounts[type] = max(0, (powerCounts[type] ?? 0) - 1);
      selectedPowerUp = null;
    }
    _finishBusy();
  }

  Future<void> _applySelectedPowerUp(Vector2 position, PowerUpType type) async {
    if (gameOver || _paused || _busy || _levelComplete || !_assetsReady) {
      return;
    }
    final target = layout.cellAtPosition(position);
    if (target == null) {
      statusText = '${type.label}: choose the board';
      _updateHud();
      return;
    }

    _busy = true;
    final applied = await _applyPowerUp(type, target);
    if (applied) {
      powerCounts[type] = max(0, (powerCounts[type] ?? 0) - 1);
      selectedPowerUp = null;
    }
    _finishBusy();
  }

  Future<bool> _applyPowerUp(PowerUpType type, BoardCell target) async {
    return switch (type) {
      PowerUpType.berry => _applyBerry(target),
      PowerUpType.bloom => _applyBloom(target),
      PowerUpType.pollen => _applyScoringPower(
        _powerUpSystem.pollenCells(board, target),
        status: 'Pollen burst!',
      ),
      PowerUpType.water => _applyScoringPower(
        _powerUpSystem.waterCells(board, target),
        status: 'Water drop!',
      ),
      PowerUpType.firefly => _applyScoringPower(
        _powerUpSystem.fireflyCells(board),
        status: 'Firefly swarm!',
      ),
    };
  }

  Future<bool> _applyBerry(BoardCell target) async {
    final cells = _powerUpSystem.berryCells(board, target);
    if (cells.isEmpty) {
      statusText = 'Berry needs a small bug';
      _updateHud();
      return false;
    }

    final fallStarts = _fallStartPositions(cells);
    final clearColors = {
      for (final cell in cells) cell: board.colorAt(cell.column, cell.row),
    };
    board.clearCells(cells);
    _spawnClearFx(cells, clearColors, 1, includedBig: false);
    _spawnFloatingText(
      'SPACE!',
      _clearCenter(cells),
      const Color(0xFFBDF77E),
      fontSize: 27,
    );
    statusText = 'Berry cleared space';
    _refreshBoardComponents(fallStarts: fallStarts);
    _updateHud();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    return true;
  }

  Future<bool> _applyBloom(BoardCell target) async {
    final changes = _powerUpSystem.bloomChanges(board, target);
    if (changes.isEmpty) {
      statusText = 'Bloom needs a small bug';
      _updateHud();
      return false;
    }

    for (final entry in changes.entries) {
      board.setPiece(entry.key.column, entry.key.row, entry.value);
    }
    for (final cell in changes.keys) {
      add(
        FxComponent(
          sprite: _sprite(GameAssets.fxSparkle),
          center: layout.cellCenter(cell.column, cell.row),
          size: layout.bugSize * 1.1,
          lifeSeconds: 0.42,
        ),
      );
    }
    _spawnFloatingText(
      'BLOOM!',
      _clearCenter(changes.keys.toSet()),
      const Color(0xFFFFF2B2),
      fontSize: 28,
    );
    statusText = 'Bloom set up a row';
    _refreshBoardComponents();
    _updateHud();
    await Future<void>.delayed(const Duration(milliseconds: 240));
    return true;
  }

  Future<bool> _applyScoringPower(
    Set<BoardCell> cells, {
    required String status,
  }) async {
    if (cells.isEmpty) {
      statusText = 'Choose a small bug';
      _updateHud();
      return false;
    }

    final fallStarts = _fallStartPositions(cells);
    final clearColors = {
      for (final cell in cells) cell: board.colorAt(cell.column, cell.row),
    };
    final removed = board.clearCells(cells);
    _registerCombo(includedBig: false);
    final points = _trackRemoved(removed, 1, superClear: false);
    _spawnClearFx(cells, clearColors, 1, includedBig: false);
    _spawnFloatingText(
      '+$points',
      _clearCenter(cells),
      const Color(0xFFF4F7DC),
      fontSize: 24,
    );
    statusText = status;
    _refreshBoardComponents(fallStarts: fallStarts);
    _updateHud();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    await _resolveCascades(playerDriven: false);
    return true;
  }

  void _restoreDraggedBug(_BugDrag drag, {required String status}) {
    board.insertPieceBottom(drag.originColumn, drag.piece);
    statusText = status;
    _refreshBoardComponents();
    _updateHud();
  }

  Future<bool> _resolveCascades({required bool playerDriven}) async {
    var cascadeCount = 0;
    var clearedAny = false;
    var promotedAny = false;

    while (true) {
      final promotions = _matchSystem.findBigPromotions(board);
      if (promotions.isNotEmpty) {
        promotedAny = true;
        _applyBigPromotions(promotions);
        _spawnBigPromotionFx(promotions);
        statusText = promotions.length == 1
            ? 'BIG ${promotions.single.color.label}!'
            : 'BIG bugs!';
        _refreshBoardComponents();
        _updateHud();
        await Future<void>.delayed(const Duration(milliseconds: 280));
        continue;
      }

      final groups = _matchSystem.findDetonations(board);
      if (groups.isEmpty) {
        if (cascadeCount == 0 && playerDriven && !promotedAny) {
          statusText = 'No explosion';
          _updateHud();
        }
        if (clearedAny && cascadeCount >= 3 && danger > 0) {
          danger -= 1;
          _spawnFloatingText(
            'Danger -1',
            layout.boardPosition + Vector2(layout.boardSize.x * 0.5, 32),
            const Color(0xFFBDF77E),
            fontSize: 19,
          );
        }
        return clearedAny;
      }

      clearedAny = true;
      cascadeCount += 1;
      highestCascade = highestCascade < cascadeCount
          ? cascadeCount
          : highestCascade;

      final cells = groups.expand((group) => group).toSet();
      final clearColors = {
        for (final cell in cells) cell: board.colorAt(cell.column, cell.row),
      };
      final superGroups = groups
          .where(
            (group) => group.every(
              (cell) => board.pieceAt(cell.column, cell.row)?.charged ?? false,
            ),
          )
          .toList();
      final superClear = superGroups.isNotEmpty;
      final fallStarts = _fallStartPositions(cells);
      final removed = board.clearCells(cells);
      final includedBig = removed.any((piece) => piece.isBig);
      if (playerDriven && cascadeCount == 1) {
        _registerCombo(includedBig: includedBig);
      } else if (playerDriven && includedBig) {
        comboRemaining += comboWindowBigClearBonus;
      }
      if (playerDriven && cascadeCount >= 2) {
        comboRemaining += comboWindowCascadeBonus;
        _addChainTimeBonus(cascadeCount);
      }
      _spawnClearFx(cells, clearColors, cascadeCount, includedBig: includedBig);
      if (superClear) {
        _spawnSuperClearFx(superGroups);
      }
      if (includedBig) {
        _spawnBigClearFx(cells);
      }
      final points = _trackRemoved(
        removed,
        cascadeCount,
        superClear: superClear,
      );
      _spawnFloatingText(
        '+$points',
        _clearCenter(cells),
        superClear
            ? const Color(0xFFFFFFFF)
            : includedBig
            ? const Color(0xFFFFD76A)
            : const Color(0xFFF4F7DC),
        fontSize: superClear
            ? 32
            : includedBig
            ? 26
            : 22,
      );
      if (superClear) {
        _spawnFloatingText(
          'SUPER GLOW!',
          layout.boardPosition + Vector2(layout.boardSize.x * 0.5, 92),
          const Color(0xFFFFF2B2),
          fontSize: 34,
          lifeSeconds: 1.18,
          floatSpeed: 42,
        );
      }
      if (cascadeCount >= 2) {
        _spawnFloatingText(
          'CHAIN x$cascadeCount',
          layout.boardPosition + layout.boardSize / 2,
          const Color(0xFFFFF2B2),
          fontSize: 30,
          lifeSeconds: 1.05,
          floatSpeed: 46,
        );
      }
      statusText = 'Cascade x$cascadeCount';
      _refreshBoardComponents(fallStarts: fallStarts);
      _updateHud();

      await Future<void>.delayed(const Duration(milliseconds: 360));
    }
  }

  void _addChainTimeBonus(int cascadeCount) {
    final bonus = chainTimeBonusSeconds * (cascadeCount - 1);
    timeRemaining = min(maxTimeSeconds, timeRemaining + bonus);
    _spawnFloatingText(
      '+${bonus.round()}s',
      layout.boardPosition + Vector2(layout.boardSize.x * 0.5, 132),
      const Color(0xFFBDF77E),
      fontSize: 25,
      lifeSeconds: 0.95,
      floatSpeed: 42,
    );
  }

  void _applyBigPromotions(List<BigBugPromotion> promotions) {
    for (final promotion in promotions) {
      board.promoteBigBlock(
        column: promotion.column,
        row: promotion.row,
        bigId: _nextBigBugId,
      );
      _nextBigBugId += 1;
    }
  }

  void _spawnBigPromotionFx(List<BigBugPromotion> promotions) {
    for (final promotion in promotions) {
      final center =
          (layout.cellCenter(promotion.column, promotion.row) +
              layout.cellCenter(promotion.column + 1, promotion.row + 1)) /
          2;
      add(
        FxComponent(
          sprite: _sprite(GameAssets.fxComboBurst),
          center: center,
          size: layout.bugSize * 2.35,
          lifeSeconds: 0.48,
        ),
      );
      _spawnFloatingText(
        'BIG!',
        center,
        const Color(0xFFFFF2B2),
        fontSize: 27,
        lifeSeconds: 0.9,
      );
    }
  }

  void _spawnClearFx(
    Set<BoardCell> cells,
    Map<BoardCell, BugColor?> clearColors,
    int cascadeCount, {
    required bool includedBig,
  }) {
    for (final cell in cells) {
      final color = clearColors[cell];
      final spritePath = switch (color) {
        BugColor.red ||
        BugColor.blue ||
        BugColor.yellow => GameAssets.colorSplash(color!),
        _ => GameAssets.fxPop,
      };
      add(
        FxComponent(
          sprite: _sprite(spritePath),
          center: layout.cellCenter(cell.column, cell.row),
          size: layout.bugSize * 1.15,
        ),
      );
    }

    if (cascadeCount >= 2 || includedBig) {
      add(
        FxComponent(
          sprite: _sprite(GameAssets.fxComboBurst),
          center: layout.boardPosition + layout.boardSize / 2,
          size: layout.boardSize.x * 0.42,
          lifeSeconds: 0.45,
        ),
      );
    }
  }

  void _spawnBigClearFx(Set<BoardCell> cells) {
    final center = _clearCenter(cells);
    add(
      FxComponent(
        sprite: _sprite(GameAssets.fxComboBurst),
        center: center,
        size: layout.boardSize.x * 0.64,
        lifeSeconds: 0.62,
      ),
    );
    for (var i = 0; i < 10; i += 1) {
      final offset = Vector2(
        (_random.nextDouble() - 0.5) * layout.bugSize * 2.2,
        (_random.nextDouble() - 0.5) * layout.bugSize * 2.2,
      );
      add(
        FxComponent(
          sprite: _sprite(GameAssets.fxSparkle),
          center: center + offset,
          size: layout.bugSize * (0.95 + _random.nextDouble() * 0.85),
          lifeSeconds: 0.46 + _random.nextDouble() * 0.24,
        ),
      );
    }
  }

  void _spawnSuperClearFx(List<Set<BoardCell>> groups) {
    for (final group in groups) {
      add(
        FxComponent(
          sprite: _sprite(GameAssets.fxComboBurst),
          center: _clearCenter(group),
          size: layout.boardSize.x * 0.58,
          lifeSeconds: 0.62,
        ),
      );
      for (final cell in group) {
        add(
          FxComponent(
            sprite: _sprite(GameAssets.fxSparkle),
            center: layout.cellCenter(cell.column, cell.row),
            size: layout.bugSize * 1.45,
            lifeSeconds: 0.54,
          ),
        );
      }
    }
  }

  int _trackRemoved(
    List<BoardPiece> removed,
    int cascadeCount, {
    required bool superClear,
  }) {
    var points = 0;
    final comboMultiplier = combo <= 1 ? 1.0 : 1 + ((combo - 1) * 0.10);
    final cascadeMultiplier = 1 + ((cascadeCount - 1) * 0.25);
    final superMultiplier = superClear ? 1.75 : 1.0;
    for (final piece in removed) {
      points +=
          (_scoreFor(piece) *
                  cascadeMultiplier *
                  comboMultiplier *
                  superMultiplier)
              .round();
    }
    score += points;
    _checkLevelProgress();
    return points;
  }

  int _scoreFor(BoardPiece piece) {
    if (piece.isBigAnchor) {
      return 280;
    }
    if (piece.isBigPart) {
      return 0;
    }
    if (piece.charged) {
      return 75;
    }
    return 35;
  }

  Future<void> _timedRefill() async {
    if (_busy || gameOver) {
      return;
    }
    _busy = true;
    final count = _pressureWaveSize();
    await _refillBoard(spawnCount: count, status: 'Pressure wave');
    if (danger >= maxDanger) {
      _endGame(status: 'Danger maxed!');
      return;
    }
    _finishBusy();
  }

  void _finishBusy() {
    _busy = false;
    final queuedAction = _queuedAction;
    _queuedAction = null;
    if (queuedAction == null || gameOver) {
      return;
    }
    scheduleMicrotask(() {
      if (queuedAction == _QueuedAction.swallow) {
        unawaited(swallow());
      } else {
        unawaited(spit());
      }
    });
  }

  Future<void> _refillBoard({
    required int spawnCount,
    required String status,
  }) async {
    final fallStarts = <BoardCell, Vector2>{};
    final rowCount = spawnCount.clamp(1, 2);

    for (var pressureRow = 0; pressureRow < rowCount; pressureRow += 1) {
      for (var column = 0; column < BoardState.columnCount; column += 1) {
        final oldLength = board.columns[column].length;
        for (var row = 0; row < oldLength; row += 1) {
          final destination = row + 1;
          if (destination < BoardState.rowCount) {
            fallStarts[BoardCell(column, destination)] = layout.cellCenter(
              column,
              row,
            );
          }
        }
      }

      board.insertTopRow(_spawnPressureRow());
      _trimBottomOverflow();

      for (var column = 0; column < BoardState.columnCount; column += 1) {
        fallStarts[BoardCell(column, 0)] =
            layout.cellCenter(column, 0) -
            Vector2(0, layout.cellHeight * (1.8 + pressureRow));
      }
    }

    statusText = danger >= maxDanger ? 'Danger maxed!' : status;
    _refreshBoardComponents(fallStarts: fallStarts);
    _updateHud();
    await Future<void>.delayed(const Duration(milliseconds: 360));
    if (danger < maxDanger) {
      await _resolveCascades(playerDriven: false);
    }
  }

  List<BoardPiece> _spawnPressureRow() {
    return _pressureRowGenerator.spawnRow(
      board: board,
      arcadeLevel: currentArcadeLevel,
    );
  }

  void _trimBottomOverflow() {
    final overflowCells = <BoardCell>{};
    final dangerColumns = <int>{};

    for (var column = 0; column < BoardState.columnCount; column += 1) {
      if (board.columns[column].length <= BoardState.rowCount) {
        continue;
      }
      final overflowRow = board.columns[column].length - 1;
      final overflow = board.pieceAt(column, overflowRow);
      dangerColumns.add(column);
      final bigId = overflow?.bigId;
      if (bigId == null) {
        overflowCells.add(BoardCell(column, overflowRow));
      } else {
        overflowCells.addAll(board.cellsForBig(bigId));
      }
    }

    if (overflowCells.isEmpty) {
      return;
    }
    board.clearCells(overflowCells);
    for (final column in dangerColumns) {
      _addDanger(column);
    }
  }

  double _currentRefillInterval() {
    if (!level.pressureEnabled) {
      return roundSeconds;
    }
    final elapsed = roundSeconds - timeRemaining;
    final pressureRamp = min(1.6, (currentArcadeLevel - 1) * 0.12);
    if (elapsed < 30) {
      return max(6.5, level.refillIntervalSeconds - pressureRamp);
    }
    if (elapsed < 60) {
      return max(5.6, level.refillIntervalSeconds - 0.75 - pressureRamp);
    }
    return max(4.8, level.refillIntervalSeconds - 1.25 - pressureRamp);
  }

  int _pressureWaveSize() {
    final elapsed = roundSeconds - timeRemaining;
    if (currentArcadeLevel >= 9 && elapsed > 85) {
      return 2;
    }
    return 1;
  }

  int _minimumBugCountForLevel() => min(
    BoardState.columnCount * BoardState.rowCount - 3,
    level.minimumBugCount,
  );

  int get _totalBugCount =>
      board.columns.fold<int>(0, (total, column) => total + column.length);

  void _checkLevelProgress() {
    if (_levelComplete || score < nextLevelScore) {
      return;
    }

    _levelComplete = true;
    _queuedAction = null;
    selectedPowerUp = null;
    _clearPowerPreview();
    final lastLevel = levelIndex >= demoLevels.length - 1;
    statusText = lastLevel ? 'Campaign complete!' : '${level.name} complete!';
    _spawnLevelUpFx(
      lastLevel ? 'CAMPAIGN COMPLETE' : 'LEVEL ${levelIndex + 1} COMPLETE',
    );
    _updateHud();
    unawaited(_advanceAfterLevelComplete(++_levelAdvanceToken));
  }

  Future<void> _advanceAfterLevelComplete(int token) async {
    await Future<void>.delayed(const Duration(milliseconds: 1450));
    if (!_levelComplete || gameOver || token != _levelAdvanceToken) {
      return;
    }
    if (levelIndex >= demoLevels.length - 1) {
      _endGame(status: 'Campaign complete!');
      return;
    }
    loadLevel(levelIndex + 1);
  }

  void _spawnLevelUpFx(String text) {
    add(LevelBannerComponent(text: text, gameSize: size));
    add(
      FxComponent(
        sprite: _sprite(GameAssets.fxComboBurst),
        center: layout.boardPosition + layout.boardSize / 2,
        size: layout.boardSize.x * 0.72,
        lifeSeconds: 0.70,
      ),
    );
    for (var i = 0; i < 12; i += 1) {
      final offset = Vector2(
        (_random.nextDouble() - 0.5) * layout.boardSize.x * 0.78,
        (_random.nextDouble() - 0.5) * layout.boardSize.y * 0.48,
      );
      add(
        FxComponent(
          sprite: _sprite(GameAssets.fxSparkle),
          center: layout.boardPosition + layout.boardSize / 2 + offset,
          size: layout.bugSize * (0.8 + _random.nextDouble() * 0.75),
          lifeSeconds: 0.55 + _random.nextDouble() * 0.32,
        ),
      );
    }
  }

  void _registerCombo({required bool includedBig}) {
    if (combo > 0 && comboRemaining > 0) {
      combo += 1;
    } else {
      combo = 1;
    }
    comboRemaining = comboWindowBaseSeconds;
    if (includedBig) {
      comboRemaining += comboWindowBigClearBonus;
    }
    if (combo >= 2) {
      _spawnFloatingText(
        'COMBO x$combo',
        layout.boardPosition + Vector2(layout.boardSize.x * 0.5, 68),
        const Color(0xFFFFF2B2),
        fontSize: 31,
        lifeSeconds: 1.05,
        floatSpeed: 48,
      );
    }
  }

  void _addDanger(int column) {
    danger = min(maxDanger, danger + 1);
    statusText = 'Overflow! Danger +1';
    add(
      FxComponent(
        sprite: _sprite(GameAssets.fxComboBurst),
        center: layout.cellCenter(column, BoardState.rowCount - 1),
        size: layout.cellWidth * 1.5,
        lifeSeconds: 0.42,
      ),
    );
    _spawnFloatingText(
      danger >= maxDanger ? 'OVERFLOW!' : 'Danger +1',
      layout.cellCenter(column, BoardState.rowCount - 1),
      const Color(0xFFFF7D5B),
      fontSize: danger >= maxDanger ? 28 : 22,
      lifeSeconds: 1.0,
    );
  }

  Vector2 _clearCenter(Set<BoardCell> cells) {
    final total = cells.fold<Vector2>(
      Vector2.zero(),
      (sum, cell) => sum + layout.cellCenter(cell.column, cell.row),
    );
    return total / cells.length.toDouble();
  }

  void _spawnFloatingText(
    String text,
    Vector2 position,
    Color color, {
    double fontSize = 24,
    double lifeSeconds = 0.85,
    double floatSpeed = 54,
  }) {
    add(
      FloatingTextComponent(
        text: text,
        position: position,
        color: color,
        fontSize: fontSize,
        lifeSeconds: lifeSeconds,
        floatSpeed: floatSpeed,
      ),
    );
  }

  void _checkNoMoves() {
    final boardFull = board.columns.every(
      (column) => column.length >= BoardState.rowCount,
    );
    final mouthBlocked = chameleon.heldColor != null && !chameleon.canSwallow;
    if (boardFull && mouthBlocked) {
      danger = maxDanger;
      _endGame(status: 'Danger maxed!');
    }
  }

  void _endGame({String status = 'Time!'}) {
    if (gameOver) {
      return;
    }
    gameOver = true;
    _paused = false;
    _busy = false;
    _queuedAction = null;
    selectedPowerUp = null;
    _clearPowerPreview();
    timeRemaining = 0;
    statusText = status;
    final token = ++_gameOverToken;
    _updateHud();
    if (status != 'Campaign complete!') {
      unawaited(_restartAfterFinalScore(token));
    }
  }

  Future<void> _restartAfterFinalScore(int token) async {
    await Future<void>.delayed(const Duration(seconds: 4));
    if (gameOver && _gameOverToken == token) {
      startNewGame();
    }
  }

  Map<BoardCell, Vector2> _fallStartPositions(Set<BoardCell> clearedCells) {
    final starts = <BoardCell, Vector2>{};

    for (var column = 0; column < board.columns.length; column += 1) {
      var destinationRow = 0;
      for (var oldRow = 0; oldRow < board.columns[column].length; oldRow += 1) {
        final oldCell = BoardCell(column, oldRow);
        if (clearedCells.contains(oldCell)) {
          continue;
        }
        starts[BoardCell(column, destinationRow)] = layout.cellCenter(
          column,
          oldRow,
        );
        destinationRow += 1;
      }
    }

    return starts;
  }

  void _refreshBoardComponents({Map<BoardCell, Vector2>? fallStarts}) {
    for (final ladybug in _ladybugs) {
      ladybug.removeFromParent();
    }
    _ladybugs.clear();
    for (final shade in _cellShades) {
      shade.removeFromParent();
    }
    _cellShades.clear();
    for (final warning in _columnWarnings) {
      warning.removeFromParent();
    }
    _columnWarnings.clear();

    _refreshColumnWarnings();
    _refreshCellShades();

    for (var column = 0; column < board.columns.length; column += 1) {
      for (var row = 0; row < board.columns[column].length; row += 1) {
        final piece = board.columns[column][row];
        if (piece.isBigPart) {
          continue;
        }
        final color = piece.color;
        final center = piece.isBigAnchor
            ? (layout.cellCenter(column, row) +
                      layout.cellCenter(
                        min(column + 1, BoardState.columnCount - 1),
                        min(row + 1, BoardState.rowCount - 1),
                      )) /
                  2
            : layout.cellCenter(column, row);
        final start = fallStarts?[BoardCell(column, row)];
        final ladybug = LadybugComponent(
          animation: _ladybugAnimation(color),
          color: color,
          charged: piece.charged,
          center: start ?? center,
          bugSize: piece.isBigAnchor ? layout.bugSize * 1.95 : layout.bugSize,
          big: piece.isBigAnchor,
        );
        if (start != null && start.distanceTo(center) > 1) {
          ladybug.fallTo(center);
        }
        _ladybugs.add(ladybug);
        add(ladybug);
      }
    }
  }

  void _refreshCellShades() {
    for (var column = 0; column < board.columns.length; column += 1) {
      final movableRow = board.columns[column].length - 1;
      for (var row = 0; row < board.columns[column].length; row += 1) {
        final piece = board.columns[column][row];
        final movable = row == movableRow && piece.canSwallow;
        if (movable) {
          continue;
        }
        final shade = BoardCellShadeComponent(
          center: layout.cellCenter(column, row),
          size: Vector2(layout.cellWidth * 0.88, layout.cellHeight * 0.88),
        );
        _cellShades.add(shade);
        add(shade);
      }
    }
  }

  void _refreshColumnWarnings() {
    for (var column = 0; column < board.columns.length; column += 1) {
      final count = board.columns[column].length;
      if (count < BoardState.rowCount - 1) {
        continue;
      }

      final full = count >= BoardState.rowCount;
      final center = full
          ? _columnCenter(column)
          : layout.cellCenter(column, BoardState.rowCount - 1);
      final size = full
          ? Vector2(
              layout.cellWidth * 0.92,
              layout.cellHeight * (BoardState.rowCount + 0.08),
            )
          : Vector2(layout.cellWidth * 0.9, layout.cellHeight * 0.92);
      final warning = ColumnWarningComponent(
        full: full,
        center: center,
        size: size,
        badgeRadius: layout.cellWidth * 0.18,
      );
      _columnWarnings.add(warning);
      add(warning);
    }
  }

  Vector2 _columnCenter(int column) {
    var total = Vector2.zero();
    for (var row = 0; row < BoardState.rowCount; row += 1) {
      total += layout.cellCenter(column, row);
    }
    return total / BoardState.rowCount.toDouble();
  }

  Future<void> _returnToIdleAfter(Duration delay) async {
    await Future<void>.delayed(delay);
    if (!_busy) {
      _chameleonComponent?.playIdle(chameleon.heldColor);
    }
  }

  void _updateHud() {
    final held = chameleon.heldColor;
    _pendingHudState = GameHudState(
      score: score,
      timeRemaining: timeRemaining,
      heldColor: held,
      heldCharged: chameleon.heldCharged,
      highestCascade: highestCascade,
      currentLevel: currentArcadeLevel,
      nextLevelScore: nextLevelScore,
      combo: combo,
      comboRemaining: comboRemaining,
      danger: danger,
      maxDanger: maxDanger,
      statusText: statusText,
      gameOver: gameOver,
      paused: _paused,
      powerSlots: _powerSlotStates(),
    );
    if (_hudUpdateScheduled) {
      return;
    }
    _hudUpdateScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _hudUpdateScheduled = false;
      final pending = _pendingHudState;
      if (pending != null) {
        hud.value = pending;
      }
    });
  }

  List<PowerUpSlotState> _powerSlotStates() {
    final visibleSlots = level.powerSlots.length >= 3
        ? level.powerSlots.take(3)
        : [
            ...level.powerSlots,
            for (var i = level.powerSlots.length; i < 3; i += 1)
              const LevelPowerSlot(locked: true),
          ];
    return [
      for (final slot in visibleSlots)
        PowerUpSlotState(
          type: slot.type,
          count: slot.type == null ? 0 : powerCounts[slot.type] ?? 0,
          locked: slot.locked,
          selected: selectedPowerUp == slot.type,
        ),
    ];
  }
}
