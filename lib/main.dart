import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adventure_map_definition.dart';
import 'adventure_screen.dart';
import 'game/chameleon_puzzle_game.dart';
import 'game/game_save_store.dart';
import 'game/game_hud_state.dart';
import 'game/levels/demo_levels.dart';
import 'game/models/game_save.dart';
import 'game/models/game_mode.dart';
import 'game/models/level_definition.dart';
import 'game/models/level_set_id.dart';
import 'game/models/player_progress.dart';
import 'game/models/power_up.dart';
import 'game/player_progress_store.dart';
import 'ncl_intro_screen.dart';
import 'title_screen.dart';
import 'tutorial_modal_title.dart';

const _darkScreenSystemUiStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.light,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(_darkScreenSystemUiStyle);
  runApp(const ChameleonDemoApp());
}

class ChameleonDemoApp extends StatelessWidget {
  const ChameleonDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _darkScreenSystemUiStyle,
      child: MaterialApp(
        title: 'Chameleon Puzzle Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3BAA68)),
          appBarTheme: const AppBarTheme(
            systemOverlayStyle: _darkScreenSystemUiStyle,
          ),
          useMaterial3: true,
        ),
        home: const NclIntroScreen(
          nextScreen: TitleScreen(gameBuilder: _buildGameScreen),
        ),
      ),
    );
  }
}

Widget _buildGameScreen(
  GameSave? save,
  GameMode mode, {
  LevelSetId? initialLevelSetId,
  int? initialLevelIndex,
}) {
  return ChameleonGameScreen(
    initialSave: save,
    mode: mode,
    initialLevelSetId: initialLevelSetId,
    initialLevelIndex: initialLevelIndex,
  );
}

enum _LevelCompletePrimaryAction { next, map }

class _LevelCompleteResult {
  const _LevelCompleteResult({
    required this.levelIndex,
    required this.levelNumber,
    required this.levelName,
    required this.earnedStars,
    required this.progress,
    required this.primaryAction,
  });

  final int levelIndex;
  final int levelNumber;
  final String levelName;
  final int earnedStars;
  final PlayerProgress progress;
  final _LevelCompletePrimaryAction primaryAction;
}

class ChameleonGameScreen extends StatefulWidget {
  const ChameleonGameScreen({
    this.initialSave,
    this.mode = GameMode.adventure,
    this.initialLevelSetId,
    this.initialLevelIndex,
    super.key,
  });

  final GameSave? initialSave;
  final GameMode mode;
  final LevelSetId? initialLevelSetId;
  final int? initialLevelIndex;

  @override
  State<ChameleonGameScreen> createState() => _ChameleonGameScreenState();
}

class _ChameleonGameScreenState extends State<ChameleonGameScreen>
    with WidgetsBindingObserver {
  late final ChameleonPuzzleGame _game;
  final _saveStore = GameSaveStore();
  final _progressStore = PlayerProgressStore();
  final _focusNode = FocusNode();
  Timer? _saveTimer;
  Timer? _tutorialTransitionTimer;
  Timer? _levelCompleteResultTimer;
  Timer? _objectiveToastTimer;
  bool _lastGameOver = false;
  bool _saveInFlight = false;
  bool _saveAgain = false;
  bool _tutorialCompletedOnEntry = false;
  bool _replayingTutorial = false;
  bool _holdLevelAdvanceForUnlock = false;
  bool _holdLevelAdvanceForTutorialCard = false;
  bool _holdLevelAdvanceForCompletionResult = false;
  bool _discardActiveRunSaves = false;
  bool _showModesUnlocked = false;
  bool _showTutorialHowTo = false;
  bool _showLevelBrief = false;
  bool _levelBriefTransitioning = false;
  int _tutorialHowToLevelIndex = 0;
  int? _pendingTutorialLevelIndex;
  String? _levelBriefKey;
  bool _skipInitialLevelBrief = false;
  String? _objectiveToastLevelKey;
  _LevelCompleteResult? _levelCompleteResult;
  List<ObjectiveHudRow> _lastObjectiveRows = const <ObjectiveHudRow>[];
  List<ObjectiveHudRow> _objectiveToastRows = const <ObjectiveHudRow>[];
  Set<String> _newlyCompletedObjectiveKeys = const <String>{};
  bool _showObjectiveToast = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = ChameleonPuzzleGame(
      initialSave: widget.initialSave,
      mode: widget.mode,
      initialLevelSetId: widget.initialLevelSetId,
      initialLevelIndex: widget.initialLevelIndex,
      onAdventureLevelComplete: _handleAdventureLevelCompleted,
      shouldHoldAfterAdventureLevelComplete: _shouldHoldAfterLevelComplete,
    );
    _game.hud.addListener(_handleHudChanged);
    _skipInitialLevelBrief = widget.initialSave != null;
    _saveTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_saveActiveRun()),
    );
    unawaited(_saveAfterInitialLoad());
    unawaited(_loadPlayerProgress());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _tutorialTransitionTimer?.cancel();
    _levelCompleteResultTimer?.cancel();
    _objectiveToastTimer?.cancel();
    _game.hud.removeListener(_handleHudChanged);
    if (!_discardActiveRunSaves) {
      unawaited(_saveActiveRun());
    }
    _focusNode.dispose();
    _game.hud.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_saveActiveRun());
    }
  }

  Future<void> _saveAfterInitialLoad() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      await _saveActiveRun();
    }
  }

  Future<void> _loadPlayerProgress() async {
    final progress = await _progressStore.load();
    _tutorialCompletedOnEntry = progress.tutorialCompleted;
    final startsInTutorial =
        widget.mode == GameMode.adventure &&
        widget.initialSave == null &&
        (widget.initialLevelSetId ?? LevelSetId.tutorial) ==
            LevelSetId.tutorial &&
        (widget.initialLevelIndex ?? 0) < PlayerProgress.requiredTutorialLevels;
    if (!mounted || progress.tutorialCompleted || !startsInTutorial) {
      return;
    }
    _game.setPaused(true, status: 'Tutorial');
    setState(() {
      _tutorialHowToLevelIndex = widget.initialLevelIndex ?? 0;
      _showTutorialHowTo = true;
    });
  }

  void _handleAdventureLevelCompleted(
    LevelSetId levelSetId,
    int levelIndex,
    double timeRemaining,
  ) {
    final completedLevel = levelIndex + 1;
    if (levelSetId == LevelSetId.map01) {
      _holdLevelAdvanceForCompletionResult = true;
    }
    final activeTutorialRun =
        levelSetId == LevelSetId.tutorial &&
        (!_tutorialCompletedOnEntry || _replayingTutorial);
    if (activeTutorialRun &&
        completedLevel >= PlayerProgress.requiredTutorialLevels) {
      _holdLevelAdvanceForUnlock = true;
    }
    if (activeTutorialRun &&
        completedLevel < PlayerProgress.requiredTutorialLevels) {
      _holdLevelAdvanceForTutorialCard = true;
      _pendingTutorialLevelIndex = levelIndex + 1;
    }
    unawaited(
      _recordAdventureLevelComplete(levelSetId, levelIndex, timeRemaining),
    );
  }

  Future<void> _recordAdventureLevelComplete(
    LevelSetId levelSetId,
    int levelIndex,
    double timeRemaining,
  ) async {
    final completedLevel = levelIndex + 1;
    final level = _game.level;
    final earnedStars = level.starThresholds.starsForCompletion(timeRemaining);
    final progress = await _progressStore.load();
    final completionAction = levelSetId == LevelSetId.map01
        ? completionActionForAdventureLevel(
            progress: progress,
            levels: map01Levels,
            levelIndex: levelIndex,
          )
        : null;
    final updated =
        (levelSetId == LevelSetId.tutorial
                ? progress.completeTutorialLevel(completedLevel)
                : progress)
            .recordLevelStars(level.id, earnedStars);
    await _progressStore.save(updated);
    if (mounted && levelSetId == LevelSetId.map01) {
      await _clearSavedActiveRun();
      _scheduleLevelCompleteResult(
        _LevelCompleteResult(
          levelIndex: levelIndex,
          levelNumber: completedLevel,
          levelName: level.name,
          earnedStars: earnedStars,
          progress: updated,
          primaryAction: completionAction == AdventureCompletionAction.map
              ? _LevelCompletePrimaryAction.map
              : _LevelCompletePrimaryAction.next,
        ),
      );
    }

    final justUnlocked =
        levelSetId == LevelSetId.tutorial &&
        (_replayingTutorial ||
            (!progress.tutorialCompleted && updated.tutorialCompleted)) &&
        completedLevel >= PlayerProgress.requiredTutorialLevels;
    final shouldShowNextTutorialCard =
        levelSetId == LevelSetId.tutorial &&
        (_replayingTutorial || !progress.tutorialCompleted) &&
        completedLevel < PlayerProgress.requiredTutorialLevels;
    if (mounted && !_tutorialCompletedOnEntry && shouldShowNextTutorialCard) {
      _scheduleNextTutorialCard(levelIndex + 1);
    }
    if (!mounted ||
        (!_replayingTutorial && _tutorialCompletedOnEntry) ||
        !justUnlocked) {
      _tutorialCompletedOnEntry = updated.tutorialCompleted;
      return;
    }

    _holdLevelAdvanceForUnlock = true;
    _scheduleTutorialCompleteModal();
  }

  bool _shouldHoldAfterLevelComplete(LevelSetId levelSetId, int levelIndex) {
    if (levelSetId == LevelSetId.map01 &&
        _holdLevelAdvanceForCompletionResult) {
      return true;
    }
    if (levelSetId != LevelSetId.tutorial) {
      return false;
    }
    if (_holdLevelAdvanceForTutorialCard &&
        levelIndex + 1 < PlayerProgress.requiredTutorialLevels) {
      return true;
    }
    return _holdLevelAdvanceForUnlock &&
        levelIndex + 1 >= PlayerProgress.requiredTutorialLevels;
  }

  bool get _levelCompleteResultPending =>
      _levelCompleteResultTimer?.isActive ?? false;

  void _scheduleLevelCompleteResult(_LevelCompleteResult result) {
    _cancelLevelCompleteResultTimer();
    _hideObjectiveToast(clearRows: true);
    _levelCompleteResultTimer = Timer(const Duration(milliseconds: 2000), () {
      _levelCompleteResultTimer = null;
      if (!mounted || !_holdLevelAdvanceForCompletionResult) {
        return;
      }
      setState(() => _levelCompleteResult = result);
    });
  }

  void _cancelLevelCompleteResultTimer() {
    _levelCompleteResultTimer?.cancel();
    _levelCompleteResultTimer = null;
  }

  Future<void> _returnToAdventureMap(PlayerProgress progress) async {
    _focusNode.requestFocus();
    _cancelLevelCompleteResultTimer();
    _holdLevelAdvanceForCompletionResult = false;
    _levelCompleteResult = null;
    await _discardSavedActiveRun();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) {
          return AdventureScreen(
            activeSave: null,
            progress: progress,
            gameBuilder: _buildGameScreen,
            homeBuilder: (_) =>
                const TitleScreen(gameBuilder: _buildGameScreen),
            openLevelSelector: true,
          );
        },
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _scheduleNextTutorialCard(int nextTutorialLevelIndex) {
    _tutorialTransitionTimer?.cancel();
    _tutorialTransitionTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted || _pendingTutorialLevelIndex != nextTutorialLevelIndex) {
        return;
      }
      _pendingTutorialLevelIndex = null;
      _holdLevelAdvanceForTutorialCard = false;
      _game.loadLevel(nextTutorialLevelIndex, levelSet: LevelSetId.tutorial);
      _game.setPaused(true, status: 'Tutorial');
      setState(() {
        _tutorialHowToLevelIndex = nextTutorialLevelIndex;
        _showTutorialHowTo = true;
      });
      unawaited(_saveActiveRun());
    });
  }

  void _scheduleTutorialCompleteModal() {
    _tutorialTransitionTimer?.cancel();
    _tutorialTransitionTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showModesUnlocked = true;
        _tutorialCompletedOnEntry = true;
      });
    });
  }

  void _handleHudChanged() {
    final hud = _game.hud.value;
    if (hud.gameOver && !_lastGameOver) {
      _lastGameOver = true;
      unawaited(_saveStore.clear());
    } else if (!hud.gameOver) {
      _lastGameOver = false;
      unawaited(_saveActiveRun());
    }
    _maybeShowLevelBrief(hud);
    _handleObjectiveProgressToast(hud);
  }

  void _handleObjectiveProgressToast(GameHudState hud) {
    final levelKey =
        '${_game.levelSetId.name}:${_game.levelIndex}:${_game.level.id}';
    if (_objectiveToastLevelKey != levelKey) {
      _objectiveToastLevelKey = levelKey;
      _lastObjectiveRows = hud.objectiveRows;
      _hideObjectiveToast(clearRows: true);
      return;
    }

    final previousRows = {for (final row in _lastObjectiveRows) row.key: row};
    final changedRows = <ObjectiveHudRow>[];
    final newlyCompleteKeys = <String>{};
    for (final row in hud.objectiveRows) {
      final previous = previousRows[row.key];
      if (previous == null) {
        continue;
      }
      if (previous.value != row.value || previous.complete != row.complete) {
        changedRows.add(row);
        if (!previous.complete && row.complete) {
          newlyCompleteKeys.add(row.key);
        }
      }
    }
    _lastObjectiveRows = hud.objectiveRows;

    if (changedRows.isEmpty || newlyCompleteKeys.isEmpty) {
      return;
    }
    if (hud.paused ||
        hud.gameOver ||
        _showTutorialHowTo ||
        _showModesUnlocked ||
        _showLevelBrief ||
        _holdLevelAdvanceForCompletionResult ||
        _levelCompleteResultPending ||
        _levelCompleteResult != null ||
        _hasSelectedPowerUp(hud)) {
      _hideObjectiveToast(clearRows: true);
      return;
    }

    _objectiveToastTimer?.cancel();
    setState(() {
      _objectiveToastRows = hud.objectiveRows;
      _newlyCompletedObjectiveKeys = newlyCompleteKeys;
      _showObjectiveToast = true;
    });
    _objectiveToastTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) {
        _hideObjectiveToast();
      }
    });
  }

  void _hideObjectiveToast({bool clearRows = false}) {
    _objectiveToastTimer?.cancel();
    if (!_showObjectiveToast && (!clearRows || _objectiveToastRows.isEmpty)) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _showObjectiveToast = false;
      _newlyCompletedObjectiveKeys = const <String>{};
      if (clearRows) {
        _objectiveToastRows = const <ObjectiveHudRow>[];
      }
    });
  }

  void _maybeShowLevelBrief(GameHudState hud) {
    if (_levelBriefTransitioning ||
        _showLevelBrief ||
        _showTutorialHowTo ||
        _showModesUnlocked ||
        hud.gameOver ||
        _game.mode != GameMode.adventure ||
        _game.levelSetId != LevelSetId.map01) {
      return;
    }

    final key =
        '${_game.levelSetId.name}:${_game.levelIndex}:${_game.level.id}';
    if (_levelBriefKey == key) {
      return;
    }
    _levelBriefKey = key;

    if (_skipInitialLevelBrief) {
      _skipInitialLevelBrief = false;
      return;
    }

    if (!mounted) {
      return;
    }
    _levelBriefTransitioning = true;
    setState(() => _showLevelBrief = true);
    _game.setPaused(true, status: 'Level Goals');
    _levelBriefTransitioning = false;
  }

  Future<void> _saveActiveRun() async {
    if (_discardActiveRunSaves) {
      return;
    }
    if (_saveInFlight) {
      _saveAgain = true;
      return;
    }
    final save = _game.snapshotForSave();
    if (save != null) {
      if (_discardActiveRunSaves) {
        return;
      }
      _saveInFlight = true;
      try {
        await _saveStore.save(save);
      } finally {
        _saveInFlight = false;
      }
      if (_saveAgain) {
        _saveAgain = false;
        await _saveActiveRun();
      }
    }
  }

  Future<void> _discardSavedActiveRun() async {
    _discardActiveRunSaves = true;
    _saveAgain = false;
    while (_saveInFlight) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await _saveStore.clear();
  }

  Future<void> _clearSavedActiveRun() async {
    _saveAgain = false;
    while (_saveInFlight) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await _saveStore.clear();
  }

  void _startNewGame() {
    _focusNode.requestFocus();
    _tutorialTransitionTimer?.cancel();
    _cancelLevelCompleteResultTimer();
    _replayingTutorial = false;
    _holdLevelAdvanceForUnlock = false;
    _holdLevelAdvanceForTutorialCard = false;
    _holdLevelAdvanceForCompletionResult = false;
    _pendingTutorialLevelIndex = null;
    _tutorialHowToLevelIndex = 0;
    _showModesUnlocked = false;
    _showTutorialHowTo = false;
    _showLevelBrief = false;
    _levelCompleteResult = null;
    _levelBriefKey = null;
    _skipInitialLevelBrief = false;
    _objectiveToastLevelKey = null;
    _lastObjectiveRows = const <ObjectiveHudRow>[];
    _hideObjectiveToast(clearRows: true);
    _game.startNewGame();
    unawaited(_saveActiveRun());
  }

  void _restartCurrentLevel() {
    _focusNode.requestFocus();
    _tutorialTransitionTimer?.cancel();
    _cancelLevelCompleteResultTimer();
    _replayingTutorial = false;
    _holdLevelAdvanceForUnlock = false;
    _holdLevelAdvanceForTutorialCard = false;
    _holdLevelAdvanceForCompletionResult = false;
    _pendingTutorialLevelIndex = null;
    _showModesUnlocked = false;
    _showTutorialHowTo = false;
    _showLevelBrief = false;
    _levelCompleteResult = null;
    _hideObjectiveToast(clearRows: true);
    _game.resetLevel();
    unawaited(_saveActiveRun());
  }

  void _closeTutorialHowTo() {
    _focusNode.requestFocus();
    final nextTutorialLevel = _pendingTutorialLevelIndex;
    if (nextTutorialLevel != null) {
      _pendingTutorialLevelIndex = null;
      _holdLevelAdvanceForTutorialCard = false;
      _game.loadLevel(nextTutorialLevel, levelSet: LevelSetId.tutorial);
    }
    _game.setPaused(false);
    setState(() => _showTutorialHowTo = false);
    unawaited(_saveActiveRun());
  }

  void _closeLevelBrief() {
    _focusNode.requestFocus();
    _levelBriefTransitioning = true;
    _game.setPaused(false);
    setState(() => _showLevelBrief = false);
    _levelBriefTransitioning = false;
    unawaited(_saveActiveRun());
  }

  void _handleLevelCompletePrimaryAction() {
    final result = _levelCompleteResult;
    if (result == null) {
      return;
    }
    switch (result.primaryAction) {
      case _LevelCompletePrimaryAction.next:
        _continueToNextLevelAfterResult(result);
      case _LevelCompletePrimaryAction.map:
        unawaited(_returnToAdventureMap(result.progress));
    }
  }

  void _continueToNextLevelAfterResult(_LevelCompleteResult result) {
    _focusNode.requestFocus();
    _cancelLevelCompleteResultTimer();
    _holdLevelAdvanceForCompletionResult = false;
    _hideObjectiveToast(clearRows: true);
    setState(() {
      _levelCompleteResult = null;
      _showLevelBrief = false;
      _showTutorialHowTo = false;
      _showModesUnlocked = false;
    });
    _game.loadLevel(result.levelIndex + 1, levelSet: LevelSetId.map01);
    unawaited(_saveActiveRun());
  }

  Future<void> _continueAfterModesUnlocked() async {
    _focusNode.requestFocus();
    _tutorialTransitionTimer?.cancel();
    _cancelLevelCompleteResultTimer();
    _replayingTutorial = false;
    setState(() {
      _holdLevelAdvanceForUnlock = false;
      _holdLevelAdvanceForTutorialCard = false;
      _holdLevelAdvanceForCompletionResult = false;
      _pendingTutorialLevelIndex = null;
      _showModesUnlocked = false;
      _levelCompleteResult = null;
    });
    await _discardSavedActiveRun();
    final progress = await _progressStore.load();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) {
          return AdventureScreen(
            activeSave: null,
            progress: progress,
            gameBuilder: _buildGameScreen,
            homeBuilder: (_) =>
                const TitleScreen(gameBuilder: _buildGameScreen),
            openLevelSelector: true,
          );
        },
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> _tryTutorialAgain() async {
    _focusNode.requestFocus();
    _tutorialTransitionTimer?.cancel();
    _cancelLevelCompleteResultTimer();
    await _saveStore.clear();
    _replayingTutorial = true;
    _tutorialCompletedOnEntry = false;
    _holdLevelAdvanceForUnlock = false;
    _holdLevelAdvanceForTutorialCard = false;
    _holdLevelAdvanceForCompletionResult = false;
    _pendingTutorialLevelIndex = null;
    _levelCompleteResult = null;
    _game.loadLevel(0, levelSet: LevelSetId.tutorial);
    _game.setPaused(true, status: 'Tutorial');
    setState(() {
      _showModesUnlocked = false;
      _tutorialHowToLevelIndex = 0;
      _showTutorialHowTo = true;
    });
    unawaited(_saveActiveRun());
  }

  Future<void> _closeToHome() async {
    _focusNode.requestFocus();
    if (_game.mode == GameMode.adventure &&
        _game.levelSetId == LevelSetId.map01) {
      final progress = await _progressStore.load();
      if (!mounted) {
        return;
      }
      await _returnToAdventureMap(progress);
      return;
    }
    _tutorialTransitionTimer?.cancel();
    _cancelLevelCompleteResultTimer();
    _holdLevelAdvanceForCompletionResult = false;
    _levelCompleteResult = null;
    await _discardSavedActiveRun();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) {
          return const TitleScreen(gameBuilder: _buildGameScreen);
        },
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final hudTop = safeTop > 12 ? safeTop - 6 : 6.0;

    return Scaffold(
      backgroundColor: const Color(0xFF10281D),
      body: SafeArea(
        top: false,
        bottom: false,
        child: KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Stack(
            children: [
              GameWidget(game: _game),
              Positioned(
                left: 12,
                right: 12,
                top: hudTop,
                child: ValueListenableBuilder<GameHudState>(
                  valueListenable: _game.hud,
                  builder: (context, hud, _) => _HudPanel(hud: hud),
                ),
              ),
              ValueListenableBuilder<GameHudState>(
                valueListenable: _game.hud,
                builder: (context, hud, _) {
                  final powerTargeting = hud.powerSlots.any(
                    (slot) => slot.selected,
                  );
                  if (_showLevelBrief) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: powerTargeting ? 34 : 28,
                    right: powerTargeting ? 34 : 28,
                    top: powerTargeting ? null : hudTop + 96,
                    bottom: powerTargeting ? safeBottom + 144 : null,
                    child: _StatusRibbon(
                      hud: hud,
                      prominent: powerTargeting,
                      objectiveRows: _showObjectiveToast
                          ? _objectiveToastRows
                          : const <ObjectiveHudRow>[],
                      newlyCompletedObjectiveKeys: _newlyCompletedObjectiveKeys,
                    ),
                  );
                },
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: safeBottom + 8,
                child: ValueListenableBuilder<GameHudState>(
                  valueListenable: _game.hud,
                  builder: (context, hud, _) => _PowerBar(
                    hud: hud,
                    onFocus: _focusNode.requestFocus,
                    onPowerPressed: _game.selectPowerUp,
                    onPause: _game.togglePaused,
                  ),
                ),
              ),
              ValueListenableBuilder<GameHudState>(
                valueListenable: _game.hud,
                builder: (context, hud, _) {
                  if (!hud.paused ||
                      _showTutorialHowTo ||
                      _showLevelBrief ||
                      _levelBriefTransitioning) {
                    return const SizedBox.shrink();
                  }
                  return _PausePanel(
                    hud: hud,
                    onResume: () {
                      _focusNode.requestFocus();
                      _game.togglePaused();
                    },
                    onReplay: _restartCurrentLevel,
                    onHome: () => unawaited(_closeToHome()),
                  );
                },
              ),
              ValueListenableBuilder<GameHudState>(
                valueListenable: _game.hud,
                builder: (context, hud, _) {
                  if (!hud.gameOver) {
                    return const SizedBox.shrink();
                  }
                  return _GameOverPanel(hud: hud, onNewGame: _startNewGame);
                },
              ),
              if (_showTutorialHowTo)
                _TutorialHowToPanel(
                  levelIndex: _tutorialHowToLevelIndex,
                  onStart: _closeTutorialHowTo,
                ),
              if (_showLevelBrief)
                _LevelBriefPanel(
                  level: _game.level,
                  levelNumber: _game.levelIndex + 1,
                  onStart: _closeLevelBrief,
                ),
              if (_showModesUnlocked)
                _ModesUnlockedPanel(
                  onContinue: () => unawaited(_continueAfterModesUnlocked()),
                  onTryAgain: () => unawaited(_tryTutorialAgain()),
                ),
              if (_levelCompleteResult != null)
                _LevelCompletePanel(
                  result: _levelCompleteResult!,
                  onPrimary: _handleLevelCompletePrimaryAction,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      _game.moveLeft();
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      _game.moveRight();
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.keyJ) {
      unawaited(_game.swallow());
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.keyK) {
      unawaited(_game.spit());
    } else if (key == LogicalKeyboardKey.keyP ||
        key == LogicalKeyboardKey.escape) {
      _game.togglePaused();
    } else if (key == LogicalKeyboardKey.keyR) {
      _game.resetLevel();
    } else {
      final digit = _levelDigitForKey(key);
      if (digit != null && digit >= 1 && digit <= _game.levelCount) {
        _game.loadLevel(digit - 1);
      }
    }
  }

  int? _levelDigitForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.digit0) return 10;
    if (key == LogicalKeyboardKey.digit1) return 1;
    if (key == LogicalKeyboardKey.digit2) return 2;
    if (key == LogicalKeyboardKey.digit3) return 3;
    if (key == LogicalKeyboardKey.digit4) return 4;
    if (key == LogicalKeyboardKey.digit5) return 5;
    if (key == LogicalKeyboardKey.digit6) return 6;
    if (key == LogicalKeyboardKey.digit7) return 7;
    if (key == LogicalKeyboardKey.digit8) return 8;
    if (key == LogicalKeyboardKey.digit9) return 9;
    return null;
  }
}

class _StatusRibbon extends StatelessWidget {
  const _StatusRibbon({
    required this.hud,
    this.prominent = false,
    this.objectiveRows = const <ObjectiveHudRow>[],
    this.newlyCompletedObjectiveKeys = const <String>{},
  });

  final GameHudState hud;
  final bool prominent;
  final List<ObjectiveHudRow> objectiveRows;
  final Set<String> newlyCompletedObjectiveKeys;

  @override
  Widget build(BuildContext context) {
    if (hud.gameOver || hud.paused) {
      return const SizedBox.shrink();
    }

    final selectedPowerUp = prominent ? _selectedPowerUpType(hud) : null;
    if (selectedPowerUp != null) {
      return Center(child: _PowerInfoBox(type: selectedPowerUp));
    }
    if (objectiveRows.isNotEmpty) {
      return Center(
        child: _ObjectiveProgressToast(
          rows: objectiveRows,
          newlyCompletedKeys: newlyCompletedObjectiveKeys,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

bool _hasSelectedPowerUp(GameHudState hud) => _selectedPowerUpType(hud) != null;

PowerUpType? _selectedPowerUpType(GameHudState hud) {
  for (final slot in hud.powerSlots) {
    if (slot.selected) {
      return slot.type;
    }
  }
  return null;
}

class _ObjectiveProgressToast extends StatelessWidget {
  const _ObjectiveProgressToast({
    required this.rows,
    required this.newlyCompletedKeys,
  });

  final List<ObjectiveHudRow> rows;
  final Set<String> newlyCompletedKeys;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE51B1208),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFB98A2C), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in rows)
                _ObjectiveToastRow(
                  row: row,
                  newlyCompleted: newlyCompletedKeys.contains(row.key),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObjectiveToastRow extends StatelessWidget {
  const _ObjectiveToastRow({required this.row, required this.newlyCompleted});

  final ObjectiveHudRow row;
  final bool newlyCompleted;

  @override
  Widget build(BuildContext context) {
    final complete = row.complete;
    final iconColor = newlyCompleted
        ? const Color(0xFFFFE733)
        : complete
        ? const Color(0xFF8FE36A)
        : const Color(0xFFEAD9AC);
    final textColor = complete
        ? const Color(0xFFFFF2B2)
        : const Color(0xFFEAD9AC);
    final progressText = complete && newlyCompleted
        ? 'COMPLETE!'
        : '${row.value}/${row.target}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: newlyCompleted ? const Color(0x33479F39) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle : Icons.radio_button_unchecked,
            size: newlyCompleted ? 22 : 19,
            color: iconColor,
            shadows: const [
              Shadow(color: Color(0xAA000000), offset: Offset(1, 1)),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                height: 1,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(color: Color(0xAA000000), offset: Offset(1, 1)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            progressText,
            maxLines: 1,
            style: TextStyle(
              color: newlyCompleted
                  ? const Color(0xFFFFE733)
                  : const Color(0xFFFFF2B2),
              fontSize: newlyCompleted ? 14 : 15,
              height: 1,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: Color(0xAA000000), offset: Offset(1, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PowerInfoBox extends StatelessWidget {
  const _PowerInfoBox({required this.type});

  final PowerUpType type;

  @override
  Widget build(BuildContext context) {
    final prompt = _powerInfoPrompt(type);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 466),
      child: AspectRatio(
        aspectRatio: 466 / 127,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/Info_box.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 18, 36, 19),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    prompt.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFE733),
                      fontSize: 19,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Color(0xCC000000),
                          offset: Offset(1.3, 1.8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    prompt.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 13.5,
                      height: 1.14,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: Color(0xCC000000),
                          offset: Offset(1, 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

({String title, String description}) _powerInfoPrompt(PowerUpType type) {
  return switch (type) {
    PowerUpType.berry => (
      title: 'BERRY',
      description: 'Tap a ladybug to clear the column',
    ),
    PowerUpType.bloom => (
      title: 'BLOOM',
      description: 'Tap a ladybug to recolor the row',
    ),
    PowerUpType.pollen => (
      title: 'POLLEN',
      description: 'Tap a spot for a 3x3 burst',
    ),
    PowerUpType.water => (
      title: 'WATER DROP',
      description: 'Tap a ladybug to clear that color',
    ),
    PowerUpType.firefly => (
      title: 'FIREFLY',
      description: 'Tap to call the swarm',
    ),
  };
}

class _PowerBar extends StatelessWidget {
  const _PowerBar({
    required this.hud,
    required this.onFocus,
    required this.onPowerPressed,
    required this.onPause,
  });

  final GameHudState hud;
  final VoidCallback onFocus;
  final ValueChanged<PowerUpType> onPowerPressed;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotSize = ((constraints.maxWidth - 50) / 4).clamp(68.0, 92.0);
        final pauseSize = (slotSize * 0.78).clamp(54.0, 72.0);

        return SizedBox(
          height: slotSize,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final slot in hud.powerSlots)
                _PowerSlotButton(
                  slot: slot,
                  size: slotSize,
                  onFocus: onFocus,
                  onPressed: onPowerPressed,
                ),
              _PauseButton(
                size: pauseSize,
                paused: hud.paused,
                onFocus: onFocus,
                onPressed: onPause,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PowerSlotButton extends StatefulWidget {
  const _PowerSlotButton({
    required this.slot,
    required this.size,
    required this.onFocus,
    required this.onPressed,
  });

  final PowerUpSlotState slot;
  final double size;
  final VoidCallback onFocus;
  final ValueChanged<PowerUpType> onPressed;

  @override
  State<_PowerSlotButton> createState() => _PowerSlotButtonState();
}

class _PowerSlotButtonState extends State<_PowerSlotButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _syncGlow();
  }

  @override
  void didUpdateWidget(covariant _PowerSlotButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncGlow();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.slot.type;
    final enabled = widget.slot.enabled;
    final frame = widget.slot.locked || type == null
        ? 'assets/images/power_btns/power_btn_locked.png'
        : !enabled
        ? 'assets/images/power_btns/power_btn_disabled.png'
        : _pressed || widget.slot.selected
        ? type.pressedFrameAsset
        : type.frameAsset;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: enabled
          ? (_) {
              widget.onFocus();
              setState(() => _pressed = true);
            }
          : null,
      onPointerUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed(type!);
            }
          : null,
      onPointerCancel: (_) {
        if (mounted) {
          setState(() => _pressed = false);
        }
      },
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          final glowStrength = widget.slot.selected
              ? 0.45 + _glowController.value * 0.55
              : 0.0;
          final glowColor = type == null
              ? const Color(0x00000000)
              : _glowColorFor(type);
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.size * 0.18),
              boxShadow: glowStrength <= 0
                  ? const []
                  : [
                      BoxShadow(
                        color: glowColor.withValues(alpha: glowStrength),
                        blurRadius: 16 + glowStrength * 12,
                        spreadRadius: 2 + glowStrength * 5,
                      ),
                      BoxShadow(
                        color: const Color(
                          0xFFFFF2B2,
                        ).withValues(alpha: glowStrength * 0.45),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
            ),
            child: child,
          );
        },
        child: AnimatedScale(
          duration: const Duration(milliseconds: 55),
          scale: _pressed ? 0.94 : 1,
          child: SizedBox.square(
            dimension: widget.size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    frame,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                ),
                if (type != null && !widget.slot.locked)
                  Positioned.fill(
                    child: Opacity(
                      opacity: enabled ? 1 : 0.38,
                      child: Image.asset(
                        type.iconAsset,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                if (type != null && !widget.slot.locked)
                  Positioned(
                    right: widget.size * 0.05,
                    bottom: widget.size * 0.04,
                    child: _CountBadge(count: widget.slot.count),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _syncGlow() {
    if (widget.slot.selected && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!widget.slot.selected && _glowController.isAnimating) {
      _glowController
        ..stop()
        ..value = 0;
    }
  }
}

Color _glowColorFor(PowerUpType type) {
  return switch (type.rarity) {
    PowerUpRarity.common => const Color(0xFFBDF77E),
    PowerUpRarity.uncommon => const Color(0xFF61D9FF),
    PowerUpRarity.rare => const Color(0xFFFFE35C),
    PowerUpRarity.ultraRare => const Color(0xFFFF7CFF),
  };
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: count > 0 ? const Color(0xFF172B16) : const Color(0xFF4B4B4B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE35C), width: 2),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 14,
          height: 1.0,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Color(0xAA000000), offset: Offset(1, 1))],
        ),
      ),
    );
  }
}

class _PauseButton extends StatefulWidget {
  const _PauseButton({
    required this.size,
    required this.paused,
    required this.onFocus,
    required this.onPressed,
  });

  final double size;
  final bool paused;
  final VoidCallback onFocus;
  final VoidCallback onPressed;

  @override
  State<_PauseButton> createState() => _PauseButtonState();
}

class _PauseButtonState extends State<_PauseButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        widget.onFocus();
        setState(() => _pressed = true);
      },
      onPointerUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onPointerCancel: (_) {
        if (mounted) {
          setState(() => _pressed = false);
        }
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 55),
        scale: _pressed ? 0.94 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.size * 0.18),
            boxShadow: widget.paused
                ? const [
                    BoxShadow(
                      color: Color(0xAAFFF2B2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Image.asset(
            'assets/images/puase_btn.png',
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }
}

class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.hud});

  final GameHudState hud;

  @override
  Widget build(BuildContext context) {
    final progress = _levelProgress(hud);
    final starCount = _starCountForProgress(_scoreProgress(hud));

    return AspectRatio(
      aspectRatio: 1191 / 280,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          double sx(double value) => size.width * value / 1191;
          double sy(double value) => size.height * value / 280;

          final barRect = Rect.fromLTWH(sx(379), sy(196), sx(388), sy(30));
          final starSize = sy(72);
          final starTop = sy(198);
          final starCenters = [sx(485), sx(596), sx(707)];

          return DefaultTextStyle(
            style: const TextStyle(
              color: Color(0xFFF4F7DC),
              height: 1.0,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Color(0xAA000000),
                  offset: Offset(1.5, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/hud_top_frame.png',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.none,
                  ),
                ),
                Positioned.fromRect(
                  rect: barRect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(sy(18)),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: barRect.width * progress,
                        height: barRect.height,
                        child: Image.asset(
                          'assets/images/progress_fill.png',
                          width: barRect.width,
                          height: barRect.height,
                          fit: BoxFit.fill,
                          alignment: Alignment.centerLeft,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: sx(92),
                  top: sy(62),
                  width: sx(204),
                  height: sy(36),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'TIME',
                      style: TextStyle(color: Color(0xFFEAD9AC)),
                    ),
                  ),
                ),
                Positioned(
                  left: sx(84),
                  top: sy(128),
                  width: sx(220),
                  height: sy(66),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatTime(hud.timeRemaining),
                      style: const TextStyle(
                        color: Color(0xFFF4F7DC),
                        fontSize: 54,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: sx(424),
                  top: sy(42),
                  width: sx(330),
                  height: sy(42),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'SCORE',
                      style: TextStyle(color: Color(0xFFEAD9AC)),
                    ),
                  ),
                ),
                Positioned(
                  left: sx(396),
                  top: sy(86),
                  width: sx(350),
                  height: sy(76),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatScore(hud.score),
                      style: const TextStyle(
                        color: Color(0xFFFFE35C),
                        fontSize: 58,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: sx(848),
                  top: sy(58),
                  width: sx(220),
                  height: sy(42),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'LEVEL',
                      style: TextStyle(color: Color(0xFFEAD9AC)),
                    ),
                  ),
                ),
                Positioned(
                  left: sx(848),
                  top: sy(120),
                  width: sx(220),
                  height: sy(78),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${hud.currentLevel}',
                      style: const TextStyle(
                        color: Color(0xFFFFE35C),
                        fontSize: 58,
                      ),
                    ),
                  ),
                ),
                for (var index = 0; index < 3; index += 1)
                  Positioned(
                    left: starCenters[index] - starSize / 2,
                    top: starTop,
                    width: starSize,
                    height: starSize,
                    child: Image.asset(
                      index < starCount
                          ? 'assets/images/star_filled.png'
                          : 'assets/images/star_empty.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LevelBriefPanel extends StatelessWidget {
  const _LevelBriefPanel({
    required this.level,
    required this.levelNumber,
    required this.onStart,
  });

  final LevelDefinition level;
  final int levelNumber;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final goals = level.activeObjectives
        .map((objective) => '• ${objective.describe()}')
        .join('\n');
    final title = _levelBriefTitle(level.name);

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: const Color(0xB0000000),
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 18).clamp(300.0, 419.0);
                return SizedBox(
                  width: width,
                  child: AspectRatio(
                    aspectRatio: 419 / 570,
                    child: LayoutBuilder(
                      builder: (context, modalConstraints) {
                        final size = Size(
                          modalConstraints.maxWidth,
                          modalConstraints.maxHeight,
                        );
                        double sx(double value) => size.width * value / 419;
                        double sy(double value) => size.height * value / 570;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/tutorial/tutorial_modal_frame.png',
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                            TutorialModalTitle(
                              text: 'LEVEL $levelNumber',
                              modalSize: size,
                            ),
                            TutorialModalBodyTitle(
                              text: title,
                              modalSize: size,
                              rect: const Rect.fromLTWH(64, 138, 291, 104),
                            ),
                            Positioned(
                              left: sx(100),
                              top: sy(260),
                              width: sx(235),
                              child: Text(
                                goals,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  color: const Color(0xFFFFF2B2),
                                  fontSize: sy(21.5).clamp(17.5, 21.5),
                                  height: 1.2,
                                  fontWeight: FontWeight.w900,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xAA000000),
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            TutorialModalDescription(
                              text: 'Finish these goals before time runs out.',
                              modalSize: size,
                              rect: const Rect.fromLTWH(64, 405, 291, 0),
                              maxLines: 2,
                            ),
                            Positioned(
                              left: sx(172),
                              top: sy(474),
                              width: sx(75),
                              height: sy(72),
                              child: _ModalCtaButton(
                                asset: 'assets/images/play_cta.png',
                                onPressed: onStart,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelCompletePanel extends StatefulWidget {
  const _LevelCompletePanel({required this.result, required this.onPrimary});

  final _LevelCompleteResult result;
  final VoidCallback onPrimary;

  @override
  State<_LevelCompletePanel> createState() => _LevelCompletePanelState();
}

class _LevelCompletePanelState extends State<_LevelCompletePanel> {
  Timer? _starRevealTimer;
  int _revealedStarSlots = 0;

  @override
  void initState() {
    super.initState();
    _startStarReveal();
  }

  @override
  void didUpdateWidget(covariant _LevelCompletePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.levelIndex != widget.result.levelIndex ||
        oldWidget.result.earnedStars != widget.result.earnedStars) {
      _startStarReveal();
    }
  }

  @override
  void dispose() {
    _starRevealTimer?.cancel();
    super.dispose();
  }

  void _startStarReveal() {
    _starRevealTimer?.cancel();
    _revealedStarSlots = 0;
    _starRevealTimer = Timer.periodic(const Duration(milliseconds: 320), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _revealedStarSlots += 1;
      });
      if (_revealedStarSlots >= 3) {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryText =
        widget.result.primaryAction == _LevelCompletePrimaryAction.next
        ? 'NEXT'
        : 'MAP';
    final ctaReady = _revealedStarSlots >= 3;
    final title = _levelBriefTitle(widget.result.levelName);

    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(scale: 0.96 + (0.04 * value), child: child),
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: ColoredBox(
            color: const Color(0xB8000000),
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 18).clamp(300.0, 419.0);
                  return SizedBox(
                    width: width,
                    child: AspectRatio(
                      aspectRatio: 419 / 570,
                      child: LayoutBuilder(
                        builder: (context, modalConstraints) {
                          final size = Size(
                            modalConstraints.maxWidth,
                            modalConstraints.maxHeight,
                          );
                          double sx(double value) => size.width * value / 419;
                          double sy(double value) => size.height * value / 570;

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/tutorial/tutorial_modal_frame.png',
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.none,
                                ),
                              ),
                              _LevelCompleteHeader(
                                text: 'COMPLETED',
                                modalSize: size,
                              ),
                              TutorialModalBodyTitle(
                                text: title,
                                modalSize: size,
                                rect: const Rect.fromLTWH(54, 142, 311, 92),
                              ),
                              for (var index = 0; index < 3; index += 1)
                                Positioned(
                                  left: sx(72 + index * 92),
                                  top: sy(260),
                                  width: sx(90),
                                  height: sy(90),
                                  child: _RevealedResultStar(
                                    filled:
                                        index < widget.result.earnedStars &&
                                        index < _revealedStarSlots,
                                    revealed: index < _revealedStarSlots,
                                  ),
                                ),
                              Positioned(
                                left: sx(64),
                                top: sy(374),
                                width: sx(291),
                                child: Text(
                                  '${widget.result.earnedStars}/3 STARS',
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFFFFF2B2),
                                    fontSize: sy(24).clamp(19.0, 24.0),
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    shadows: const [
                                      Shadow(
                                        color: Color(0xAA000000),
                                        offset: Offset(1.2, 1.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: sx(82),
                                top: sy(456),
                                width: sx(255),
                                height: sy(70),
                                child: _LevelCompletePrimaryButton(
                                  text: primaryText,
                                  enabled: ctaReady,
                                  onPressed: widget.onPrimary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelCompleteHeader extends StatelessWidget {
  const _LevelCompleteHeader({required this.text, required this.modalSize});

  final String text;
  final Size modalSize;

  @override
  Widget build(BuildContext context) {
    double sx(double value) => modalSize.width * value / 419;
    double sy(double value) => modalSize.height * value / 570;

    return Positioned(
      left: sx(58),
      top: sy(50),
      width: sx(303),
      height: sy(58),
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: TextStyle(
            color: const Color(0xFFF4F7DC),
            fontSize: sy(25).clamp(20.0, 25.0),
            height: 1,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(color: Color(0xFF000000), offset: Offset(1.6, 2.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevealedResultStar extends StatelessWidget {
  const _RevealedResultStar({required this.filled, required this.revealed});

  final bool filled;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
      scale: revealed ? 1 : 0.72,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: revealed ? 1 : 0.36,
        child: Image.asset(
          filled
              ? 'assets/images/star_filled.png'
              : 'assets/images/star_empty.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}

class _LevelCompletePrimaryButton extends StatefulWidget {
  const _LevelCompletePrimaryButton({
    required this.text,
    required this.enabled,
    required this.onPressed,
  });

  final String text;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_LevelCompletePrimaryButton> createState() =>
      _LevelCompletePrimaryButtonState();
}

class _LevelCompletePrimaryButtonState
    extends State<_LevelCompletePrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: widget.enabled
          ? (_) => setState(() => _pressed = true)
          : null,
      onPointerUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed();
            }
          : null,
      onPointerCancel: (_) {
        if (mounted) {
          setState(() => _pressed = false);
        }
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: widget.enabled ? 1 : 0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 55),
          scale: _pressed ? 0.96 : 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/adventure/play_wideCTA.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
              Positioned.fill(
                left: 78,
                right: 38,
                child: Center(
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Color(0xCC000000),
                          offset: Offset(1.8, 2.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _levelBriefTitle(String name) {
  final words = name
      .trim()
      .toUpperCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return '';
  }
  if (words.length == 1 || words.join(' ').length <= 12) {
    return words.join(' ');
  }

  var bestBreak = 1;
  var bestBalance = double.infinity;
  for (var index = 1; index < words.length; index += 1) {
    final first = words.take(index).join(' ');
    final second = words.skip(index).join(' ');
    final balance = (first.length - second.length).abs().toDouble();
    if (balance < bestBalance) {
      bestBreak = index;
      bestBalance = balance;
    }
  }

  return '${words.take(bestBreak).join(' ')}\n'
      '${words.skip(bestBreak).join(' ')}';
}

class _TutorialHowToPanel extends StatelessWidget {
  const _TutorialHowToPanel({required this.levelIndex, required this.onStart});

  final int levelIndex;
  final VoidCallback onStart;

  static const _pages = [
    _TutorialHowToPage(
      title: 'DRAG\nBUGS',
      body: 'Move bugs into matching groups.',
      asset: 'assets/images/tutorial/tutorial_step_drag.png',
    ),
    _TutorialHowToPage(
      title: 'MAKE GLOW\nBUGS',
      body: 'Match pairs to create glowing bugs.',
      asset: 'assets/images/tutorial/tutorial_step_glow.png',
    ),
    _TutorialHowToPage(
      title: 'MATCH\nBUGS',
      body: 'Connect three same-color bugs to clear.',
      asset: 'assets/images/tutorial/tutorial_step_match.png',
    ),
    _TutorialHowToPage(
      title: 'CHAIN\nREACTIONS',
      body: 'Clear one group so the next chain drops in.',
      asset: 'assets/images/tutorial/tutorial_step_chain.png',
    ),
    _TutorialHowToPage(
      title: 'BIG\nBUGS',
      body: 'Place a matching glow beside the BIG bug.',
      asset: 'assets/images/tutorial/tutorial_step_big.png',
    ),
    _TutorialHowToPage(
      title: 'BEAT\nDANGER',
      body: 'Full columns overflow. Clear space to stay safe.',
      asset: 'assets/images/tutorial/tutorial_step_pressure.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final page = _pages[levelIndex.clamp(0, _pages.length - 1).toInt()];

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: const Color(0xB0000000),
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 18).clamp(300.0, 419.0);
                return SizedBox(
                  width: width,
                  child: AspectRatio(
                    aspectRatio: 419 / 570,
                    child: LayoutBuilder(
                      builder: (context, modalConstraints) {
                        final size = Size(
                          modalConstraints.maxWidth,
                          modalConstraints.maxHeight,
                        );
                        double sx(double value) => size.width * value / 419;
                        double sy(double value) => size.height * value / 570;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/tutorial/tutorial_modal_frame.png',
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                            TutorialModalTitle(
                              text: 'HOW TO PLAY',
                              modalSize: size,
                            ),
                            TutorialModalBodyTitle(
                              text: page.title,
                              modalSize: size,
                              rect: const Rect.fromLTWH(48, 146, 323, 96),
                            ),
                            Positioned(
                              left: sx(119),
                              top: sy(235),
                              width: sx(181),
                              height: sy(181),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 160),
                                child: Image.asset(
                                  page.asset,
                                  key: ValueKey(page.asset),
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.none,
                                ),
                              ),
                            ),
                            TutorialModalDescription(
                              text: page.body,
                              modalSize: size,
                              rect: const Rect.fromLTWH(64, 418, 291, 0),
                              maxLines: 2,
                            ),
                            Positioned(
                              left: sx(172),
                              top: sy(474),
                              width: sx(75),
                              height: sy(72),
                              child: _ModalCtaButton(
                                asset: 'assets/images/play_cta.png',
                                onPressed: onStart,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialHowToPage {
  const _TutorialHowToPage({
    required this.title,
    required this.body,
    required this.asset,
  });

  final String title;
  final String body;
  final String asset;
}

class _ModalCtaButton extends StatefulWidget {
  const _ModalCtaButton({required this.asset, required this.onPressed});

  final String asset;
  final VoidCallback onPressed;

  @override
  State<_ModalCtaButton> createState() => _ModalCtaButtonState();
}

class _ModalCtaButtonState extends State<_ModalCtaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onPointerCancel: (_) {
        if (mounted) {
          setState(() => _pressed = false);
        }
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 55),
        scale: _pressed ? 0.94 : 1,
        child: Image.asset(
          widget.asset,
          width: 64,
          height: 62,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}

class _GameOverPanel extends StatelessWidget {
  const _GameOverPanel({required this.hud, required this.onNewGame});

  final GameHudState hud;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x88000000),
        child: Center(
          child: SizedBox(
            width: 310,
            child: _PanelFrame(
              assetPath: 'assets/images/ui_panel_wide.png',
              sourceSize: const Size(217, 100),
              padding: const EdgeInsets.fromLTRB(30, 26, 30, 28),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Color(0xFFF4F7DC),
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hud.statusText == 'Campaign complete!'
                          ? 'Complete!'
                          : 'Time!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Final Score',
                      style: TextStyle(color: Color(0xFFE9D29D), fontSize: 14),
                    ),
                    Text(
                      '${hud.score}',
                      style: const TextStyle(
                        color: Color(0xFFFFF2B2),
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Best Cascade x${hud.highestCascade}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: onNewGame,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5D8E2D),
                        foregroundColor: const Color(0xFFFFFFFF),
                      ),
                      child: const Text('New Game'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModesUnlockedPanel extends StatelessWidget {
  const _ModesUnlockedPanel({
    required this.onContinue,
    required this.onTryAgain,
  });

  final VoidCallback onContinue;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: const Color(0xAA000000),
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 18).clamp(300.0, 419.0);
                return SizedBox(
                  width: width,
                  child: AspectRatio(
                    aspectRatio: 419 / 570,
                    child: LayoutBuilder(
                      builder: (context, modalConstraints) {
                        final size = Size(
                          modalConstraints.maxWidth,
                          modalConstraints.maxHeight,
                        );
                        double sx(double value) => size.width * value / 419;
                        double sy(double value) => size.height * value / 570;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/tutorial/modes_unlocked_modal_frame.png',
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                            Positioned(
                              left: sx(88),
                              top: sy(58),
                              width: sx(243),
                              height: sy(72),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'TUTORIAL\nCOMPLETE',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFFFE733),
                                    fontWeight: FontWeight.w900,
                                    height: 0.92,
                                    shadows: [
                                      Shadow(
                                        color: Color(0xFF000000),
                                        offset: Offset(1.8, 2.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: sx(70),
                              top: sy(334),
                              width: sx(279),
                              child: Text(
                                'Great work! Adventure and Time Trial are ready.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFF4F7DC),
                                  fontSize: sy(15).clamp(12.0, 15.0),
                                  height: 1.12,
                                  fontWeight: FontWeight.w800,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xAA000000),
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: sx(70),
                              top: sy(386),
                              width: sx(279),
                              child: Text(
                                'Continue to Map 01 or replay the tutorial.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFEAD9AC),
                                  fontSize: sy(12).clamp(10.0, 12.0),
                                  height: 1.12,
                                  fontWeight: FontWeight.w800,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xAA000000),
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: sx(118),
                              top: sy(456),
                              width: sx(75),
                              height: sy(72),
                              child: _PauseCtaButton(
                                asset: 'assets/images/replay_cta.png',
                                onPressed: onTryAgain,
                              ),
                            ),
                            Positioned(
                              left: sx(226),
                              top: sy(456),
                              width: sx(75),
                              height: sy(72),
                              child: _PauseCtaButton(
                                asset: 'assets/images/play_cta.png',
                                onPressed: onContinue,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PausePanel extends StatelessWidget {
  const _PausePanel({
    required this.hud,
    required this.onResume,
    required this.onReplay,
    required this.onHome,
  });

  final GameHudState hud;
  final VoidCallback onResume;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final starCount = _starCountForProgress(_scoreProgress(hud));

    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x99000000),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 18).clamp(300.0, 419.0);
              return SizedBox(
                width: width,
                child: AspectRatio(
                  aspectRatio: 419 / 570,
                  child: LayoutBuilder(
                    builder: (context, modalConstraints) {
                      final size = Size(
                        modalConstraints.maxWidth,
                        modalConstraints.maxHeight,
                      );
                      double sx(double value) => size.width * value / 419;
                      double sy(double value) => size.height * value / 570;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/Pause_menu_modal.png',
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.none,
                            ),
                          ),
                          Positioned(
                            left: sx(92),
                            top: sy(130),
                            width: sx(235),
                            height: sy(26),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'LEVEL ${hud.currentLevel}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFFFE733),
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xAA000000),
                                      offset: Offset(1.2, 1.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          for (var index = 0; index < 3; index += 1)
                            Positioned(
                              left: sx(84 + index * 82),
                              top: sy(150),
                              width: sx(73),
                              height: sy(73),
                              child: Image.asset(
                                index < starCount
                                    ? 'assets/images/star_filled.png'
                                    : 'assets/images/star_empty.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                          Positioned(
                            left: sx(64),
                            top: sy(264),
                            width: sx(291),
                            height: sy(88),
                            child: _PauseObjectiveList(
                              hud: hud,
                              fontSize: sy(18.2).clamp(15.5, 18.2),
                            ),
                          ),
                          if (_pauseTipFor(hud).isNotEmpty)
                            Positioned(
                              left: sx(78),
                              top: sy(356),
                              width: sx(263),
                              child: Text(
                                _pauseTipFor(hud),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFF4F7DC),
                                  fontSize: sy(13).clamp(11.0, 13.0),
                                  height: 1.18,
                                  fontWeight: FontWeight.w800,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xAA000000),
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Positioned(
                            left: sx(58),
                            top: sy(421),
                            width: sx(302),
                            height: sy(72),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _PauseCtaButton(
                                  asset: 'assets/images/music_cta.png',
                                  onPressed: () {},
                                ),
                                _PauseCtaButton(
                                  asset: 'assets/images/play_cta.png',
                                  onPressed: onResume,
                                ),
                                _PauseCtaButton(
                                  asset: 'assets/images/replay_cta.png',
                                  onPressed: onReplay,
                                ),
                                _PauseCtaButton(
                                  asset: 'assets/images/close_cta.png',
                                  onPressed: onHome,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PauseCtaButton extends StatefulWidget {
  const _PauseCtaButton({required this.asset, required this.onPressed});

  final String asset;
  final VoidCallback onPressed;

  @override
  State<_PauseCtaButton> createState() => _PauseCtaButtonState();
}

class _PauseCtaButtonState extends State<_PauseCtaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onPointerCancel: (_) {
        if (mounted) {
          setState(() => _pressed = false);
        }
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 55),
        scale: _pressed ? 0.94 : 1,
        child: Image.asset(
          widget.asset,
          width: 64,
          height: 62,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}

String _pauseTipFor(GameHudState hud) {
  final status = hud.statusText.trim();
  if (status.isNotEmpty && status != 'Paused' && status != 'Tutorial') {
    return status;
  }
  return '';
}

class _PauseObjectiveList extends StatelessWidget {
  const _PauseObjectiveList({required this.hud, required this.fontSize});

  final GameHudState hud;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final rows = hud.objectiveRows;
    if (rows.isEmpty) {
      return _PauseObjectiveText(
        text: _pauseObjectiveFor(hud),
        fontSize: fontSize,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in rows)
                  _PauseObjectiveRow(row: row, fontSize: fontSize),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PauseObjectiveRow extends StatelessWidget {
  const _PauseObjectiveRow({required this.row, required this.fontSize});

  final ObjectiveHudRow row;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final iconColor = row.complete
        ? const Color(0xFF8FE36A)
        : const Color(0xFFEAD9AC);
    final textColor = row.complete
        ? const Color(0xFFFFF2B2)
        : const Color(0xFFEAD9AC);
    final progressColor = row.complete
        ? const Color(0xFFFFE733)
        : const Color(0xFFFFF2B2);
    final progressText = row.complete
        ? 'COMPLETE!'
        : '${row.value}/${row.target}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: row.complete ? const Color(0x332D6D25) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            row.complete ? Icons.check_circle : Icons.radio_button_unchecked,
            color: iconColor,
            size: fontSize + 2,
            shadows: const [
              Shadow(color: Color(0xAA000000), offset: Offset(1, 1)),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                height: 1,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(color: Color(0xAA000000), offset: Offset(1, 1)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            progressText,
            maxLines: 1,
            style: TextStyle(
              color: progressColor,
              fontSize: row.complete ? fontSize * 0.82 : fontSize,
              height: 1,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: Color(0xAA000000), offset: Offset(1, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseObjectiveText extends StatelessWidget {
  const _PauseObjectiveText({required this.text, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xFFFFF2B2),
        fontSize: fontSize,
        height: 1.18,
        fontWeight: FontWeight.w900,
        shadows: const [Shadow(color: Color(0xAA000000), offset: Offset(1, 1))],
      ),
    );
  }
}

String _pauseObjectiveFor(GameHudState hud) {
  final checklist = hud.objectiveChecklistText.trim();
  if (checklist.isNotEmpty) {
    return checklist;
  }
  if (hud.objectiveText.isNotEmpty) {
    return '${hud.objectiveText}: ${hud.objectiveProgress}/${hud.objectiveTarget}';
  }
  return 'Score before time runs out.';
}

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({
    required this.assetPath,
    required this.sourceSize,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final String assetPath;
  final Size sourceSize;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(assetPath),
          fit: BoxFit.fill,
          centerSlice: Rect.fromLTRB(
            sourceSize.width * 0.27,
            sourceSize.height * 0.34,
            sourceSize.width * 0.73,
            sourceSize.height * 0.66,
          ),
          filterQuality: FilterQuality.none,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

String _formatTime(double seconds) {
  final wholeSeconds = seconds.ceil();
  final minutes = wholeSeconds ~/ 60;
  final remainder = wholeSeconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

String _formatScore(int score) {
  return score.clamp(0, 9999999).toString().padLeft(7, '0');
}

double _levelProgress(GameHudState hud) {
  if (hud.mode == GameMode.adventure) {
    if (hud.objectiveTarget <= 0) {
      return hud.objectiveComplete ? 1 : 0;
    }
    return (hud.objectiveProgress / hud.objectiveTarget).clamp(0.0, 1.0);
  }
  if (hud.nextLevelScore <= 0) {
    return 1;
  }
  return (hud.score / hud.nextLevelScore).clamp(0.0, 1.0);
}

double _scoreProgress(GameHudState hud) {
  if (hud.nextLevelScore <= 0) {
    return 1;
  }
  return (hud.score / hud.nextLevelScore).clamp(0.0, 1.0);
}

int _starCountForProgress(double progress) {
  if (progress >= 0.9) {
    return 3;
  }
  if (progress >= 0.6) {
    return 2;
  }
  if (progress >= 0.3) {
    return 1;
  }
  return 0;
}
