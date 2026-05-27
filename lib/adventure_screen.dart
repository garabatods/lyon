import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'adventure_map_definition.dart';
import 'game/game_save_store.dart';
import 'game/levels/demo_levels.dart';
import 'game/models/game_mode.dart';
import 'game/models/game_save.dart';
import 'game/models/level_definition.dart';
import 'game/models/level_set_id.dart';
import 'game/models/objective.dart';
import 'game/models/player_progress.dart';

typedef AdventureGameBuilder =
    Widget Function(
      GameSave? initialSave,
      GameMode mode, {
      LevelSetId? initialLevelSetId,
      int? initialLevelIndex,
    });

const _adventureRoot = 'assets/images/adventure';
const _selectedMapViewportFraction = 0.86;
const _peekCardSpacingFactor = 0.64;
const _inactiveMapScale = 0.70;
const _inactiveMapOpacity = 0.82;

class AdventureScreen extends StatefulWidget {
  const AdventureScreen({
    required this.activeSave,
    required this.progress,
    required this.gameBuilder,
    required this.homeBuilder,
    this.openLevelSelector = false,
    super.key,
  });

  final GameSave? activeSave;
  final PlayerProgress progress;
  final AdventureGameBuilder gameBuilder;
  final WidgetBuilder homeBuilder;
  final bool openLevelSelector;

  @override
  State<AdventureScreen> createState() => _AdventureScreenState();
}

class _AdventureScreenState extends State<AdventureScreen> {
  final _saveStore = GameSaveStore();
  late final PageController _mapController;
  bool _launching = false;
  bool _showLevelSelector = false;
  int _selectedMapIndex = 0;
  late int _selectedLevelIndex;

  @override
  void initState() {
    super.initState();
    final initialMap = _mapIndexForSave(widget.activeSave);
    _selectedMapIndex = initialMap
        .clamp(0, adventureMapCards.length - 1)
        .toInt();
    _selectedLevelIndex = _initialLevelIndexForMap(adventureMap01);
    _showLevelSelector = widget.openLevelSelector && _selectedMapIndex == 0;
    _mapController = PageController(
      initialPage: _selectedMapIndex,
      viewportFraction: _selectedMapViewportFraction,
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showLevelSelector) {
      return _buildLevelSelector();
    }

    final earnedMapStars = _earnedMapStars(widget.progress);
    final selectedMap = adventureMapCards[_selectedMapIndex];
    final selectedMapUnlocked = isAdventureMapCardUnlocked(
      map: selectedMap,
      earnedStars: earnedMapStars,
    );
    final starProgress = _starProgressForMap(widget.progress, selectedMap);

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, outerConstraints) {
          final safePadding = MediaQuery.paddingOf(context);
          final titleScale = outerConstraints.maxWidth / 853;
          final mapScale =
              outerConstraints.maxWidth / adventureMap01.canvasSize.width;
          final headerTop = math.max(81 * mapScale, safePadding.top + 8);
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                '$_adventureRoot/adventure_map_background.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(color: Color(0x8C000000)),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final contentWidth = math.min(constraints.maxWidth, 430.0);
                    return Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: _AdventureMapSelector(
                          controller: _mapController,
                          maps: adventureMapCards,
                          selectedMapIndex: _selectedMapIndex,
                          earnedMapStars: earnedMapStars,
                          completed: starProgress.completed,
                          total: starProgress.total,
                          selectedMapUnlocked: selectedMapUnlocked,
                          launching: _launching,
                          onPageChanged: (index) {
                            setState(() => _selectedMapIndex = index);
                          },
                          onPlay: _launchSelectedMap,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 235 * titleScale,
                top: headerTop,
                child: _AdventureTitlePlaque(scale: titleScale),
              ),
              Positioned(
                left: 28 * mapScale,
                top: headerTop,
                child: _ImageTapButton(
                  asset: '$_adventureRoot/back_cta.png',
                  onTap: _returnHome,
                  size: 159 * mapScale,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLevelSelector() {
    return _AdventureLevelSelectorScreen(
      map: adventureMap01,
      levels: map01Levels,
      progress: widget.progress,
      selectedLevelIndex: _selectedLevelIndex,
      launching: _launching,
      onBack: () {
        if (_launching) {
          return;
        }
        setState(() => _showLevelSelector = false);
      },
      onLevelSelected: (index) => setState(() => _selectedLevelIndex = index),
      onPlay: _handleSelectedLevelCta,
    );
  }

  Future<void> _returnHome() async {
    if (_launching) {
      return;
    }
    await Navigator.of(
      context,
    ).pushReplacement(_fadeRoute(widget.homeBuilder(context), durationMs: 180));
  }

  Future<void> _launchSelectedMap() async {
    if (_launching) {
      return;
    }
    final selectedMap = adventureMapCards[_selectedMapIndex];
    final action = adventureMapCardAction(
      map: selectedMap,
      earnedStars: _earnedMapStars(widget.progress),
    );
    switch (action) {
      case AdventureMapCardAction.locked:
        return;
      case AdventureMapCardAction.comingSoon:
        _showComingSoon();
        return;
      case AdventureMapCardAction.playable:
        break;
    }
    setState(() {
      _selectedLevelIndex = _initialLevelIndexForMap(adventureMap01);
      _showLevelSelector = true;
    });
  }

  Future<void> _handleSelectedLevelCta() async {
    if (_launching) {
      return;
    }
    final locked = !isAdventureLevelUnlocked(
      progress: widget.progress,
      levels: map01Levels,
      levelIndex: _selectedLevelIndex,
    );
    if (locked) {
      _showLockedLevelMessage();
      return;
    }

    final save = _activeMapSave(adventureMap01);
    if (save == null) {
      await _launchFreshLevel(_selectedLevelIndex);
      return;
    }

    final sameLevel = save.levelIndex == _selectedLevelIndex;
    final choice = await _showSaveChoiceDialog(sameLevel: sameLevel);
    if (!mounted || choice == null) {
      return;
    }
    switch (choice) {
      case _SavedRunChoice.continueSavedRun:
        await _continueSavedRun(save);
      case _SavedRunChoice.startSelectedLevel:
        await _launchFreshLevel(_selectedLevelIndex);
    }
  }

  Future<void> _continueSavedRun(GameSave save) async {
    setState(() => _launching = true);
    await _replaceWith(widget.gameBuilder(save, GameMode.adventure));
  }

  Future<void> _launchFreshLevel(int levelIndex) async {
    setState(() => _launching = true);
    await _saveStore.clear();
    await _replaceWith(
      widget.gameBuilder(
        null,
        GameMode.adventure,
        initialLevelSetId: LevelSetId.map01,
        initialLevelIndex: levelIndex,
      ),
    );
  }

  GameSave? _activeMapSave(AdventureMapDefinition map) {
    final save = widget.activeSave;
    if (save == null ||
        save.mode != GameMode.adventure ||
        save.levelSetId != map.levelSetId) {
      return null;
    }
    return save;
  }

  int _initialLevelIndexForMap(AdventureMapDefinition map) {
    final save = _activeMapSave(map);
    if (save != null) {
      return save.levelIndex.clamp(0, map01Levels.length - 1).toInt();
    }
    return firstAdventureLevelIndex(
      progress: widget.progress,
      levels: map01Levels,
    );
  }

  Future<_SavedRunChoice?> _showSaveChoiceDialog({required bool sameLevel}) {
    return showDialog<_SavedRunChoice>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _SaveChoiceDialog(
          sameLevel: sameLevel,
          selectedLevelNumber: _selectedLevelIndex + 1,
        );
      },
    );
  }

  void _showLockedLevelMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Complete the previous level to unlock this one'),
          duration: Duration(milliseconds: 1100),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Coming soon'),
          duration: Duration(milliseconds: 950),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _replaceWith(Widget screen) async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(_fadeRoute(screen));
  }
}

_MapStarProgress _starProgressForMap(
  PlayerProgress progress,
  AdventureMapCardDefinition map,
) {
  if (map.id != adventureMap01.id) {
    return const _MapStarProgress(completed: '?', total: '?');
  }
  final levelIds = map01Levels.map((level) => level.id);
  return _MapStarProgress(
    completed: '${progress.totalStarsForLevelIds(levelIds)}',
    total: '${levelIds.length * 3}',
  );
}

int _earnedMapStars(PlayerProgress progress) {
  return progress.totalStarsForLevelIds(map01Levels.map((level) => level.id));
}

int _mapIndexForSave(GameSave? save) {
  if (save?.levelSetId == LevelSetId.map01) {
    return 0;
  }
  return 0;
}

class _MapStarProgress {
  const _MapStarProgress({required this.completed, required this.total});

  final String completed;
  final String total;
}

enum _SavedRunChoice { continueSavedRun, startSelectedLevel }

PageRouteBuilder<void> _fadeRoute(Widget screen, {int durationMs = 240}) {
  return PageRouteBuilder<void>(
    pageBuilder: (_, _, _) => screen,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    transitionDuration: Duration(milliseconds: durationMs),
    reverseTransitionDuration: Duration.zero,
  );
}

class _AdventureLevelSelectorScreen extends StatefulWidget {
  const _AdventureLevelSelectorScreen({
    required this.map,
    required this.levels,
    required this.progress,
    required this.selectedLevelIndex,
    required this.launching,
    required this.onBack,
    required this.onLevelSelected,
    required this.onPlay,
  });

  final AdventureMapDefinition map;
  final List<LevelDefinition> levels;
  final PlayerProgress progress;
  final int selectedLevelIndex;
  final bool launching;
  final VoidCallback onBack;
  final ValueChanged<int> onLevelSelected;
  final VoidCallback onPlay;

  @override
  State<_AdventureLevelSelectorScreen> createState() =>
      _AdventureLevelSelectorScreenState();
}

class _AdventureLevelSelectorScreenState
    extends State<_AdventureLevelSelectorScreen> {
  final _scrollController = ScrollController();
  int? _lastAutoScrolledLevel;

  @override
  void didUpdateWidget(covariant _AdventureLevelSelectorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLevelIndex != widget.selectedLevelIndex) {
      _lastAutoScrolledLevel = null;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth;
          final scale = contentWidth / widget.map.canvasSize.width;
          final mapHeight = widget.map.canvasSize.height * scale;
          final nodeSize = 180 * scale;
          final selectedLevel = widget.levels[widget.selectedLevelIndex];
          final selectedStars = widget.progress.starsForLevel(selectedLevel.id);
          final selectedLocked = !isAdventureLevelUnlocked(
            progress: widget.progress,
            levels: widget.levels,
            levelIndex: widget.selectedLevelIndex,
          );
          final plaqueHeight = 467 * scale;

          _scheduleSelectedScroll(
            scale: scale,
            viewportHeight: constraints.maxHeight,
            bottomPanelHeight: plaqueHeight,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: contentWidth,
                    height: mapHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          width: contentWidth,
                          height: mapHeight,
                          child: Image.asset(
                            widget.map.backgroundAsset,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.none,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 115 * scale,
                          width: contentWidth,
                          height: 2429 * scale,
                          child: const IgnorePointer(
                            child: ColoredBox(color: Color(0x2B000000)),
                          ),
                        ),
                        for (final node in widget.map.nodes)
                          _PositionedAdventureLevelNode(
                            node: node,
                            nodeSize: nodeSize,
                            scale: scale,
                            selected:
                                node.levelIndex == widget.selectedLevelIndex,
                            state: adventureLevelNodeState(
                              progress: widget.progress,
                              levels: widget.levels,
                              levelIndex: node.levelIndex,
                              currentLevelIndex: firstAdventureLevelIndex(
                                progress: widget.progress,
                                levels: widget.levels,
                              ),
                            ),
                            onTap: () {
                              widget.onLevelSelected(node.levelIndex);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: plaqueHeight,
                child: _AdventureBottomPlaque(
                  scale: scale,
                  locked: selectedLocked,
                  level: selectedLevel,
                  levelNumber: widget.selectedLevelIndex + 1,
                  stars: selectedStars,
                  onTap: widget.onPlay,
                ),
              ),
              Positioned(
                left: 28 * scale,
                top: math.max(81 * scale, safePadding.top + 8),
                child: _ImageTapButton(
                  asset: '$_adventureRoot/back_cta.png',
                  onTap: widget.onBack,
                  size: 159 * scale,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _scheduleSelectedScroll({
    required double scale,
    required double viewportHeight,
    required double bottomPanelHeight,
  }) {
    if (_lastAutoScrolledLevel == widget.selectedLevelIndex) {
      return;
    }
    _lastAutoScrolledLevel = widget.selectedLevelIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final node = widget.map.nodes.firstWhere(
        (candidate) => candidate.levelIndex == widget.selectedLevelIndex,
        orElse: () => widget.map.nodes.first,
      );
      final visibleHeight = math.max(120.0, viewportHeight - bottomPanelHeight);
      final target = node.center.dy * scale - (visibleHeight * 0.48);
      final maxScroll = _scrollController.position.maxScrollExtent;
      final clamped = target.clamp(0.0, maxScroll).toDouble();
      if ((_scrollController.offset - clamped).abs() < 3) {
        return;
      }
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _PositionedAdventureLevelNode extends StatelessWidget {
  const _PositionedAdventureLevelNode({
    required this.node,
    required this.nodeSize,
    required this.scale,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  final AdventureLevelNodeDefinition node;
  final double nodeSize;
  final double scale;
  final bool selected;
  final AdventureLevelNodeState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final left = (node.center.dx * scale) - (nodeSize / 2);
    final top = (node.center.dy * scale) - (nodeSize / 2);

    return Positioned(
      left: left,
      top: top,
      width: nodeSize,
      height: nodeSize,
      child: _AdventureLevelNodeButton(
        asset: _assetForNodeState(state),
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}

class _AdventureLevelNodeButton extends StatefulWidget {
  const _AdventureLevelNodeButton({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AdventureLevelNodeButton> createState() =>
      _AdventureLevelNodeButtonState();
}

class _AdventureLevelNodeButtonState extends State<_AdventureLevelNodeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerCancel: (_) => setState(() => _pressed = false),
      onPointerUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 70),
        scale: _pressed ? 0.94 : 1,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                widget.asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ),
            if (widget.selected)
              Positioned(
                left: 0,
                right: 0,
                top: -40,
                height: 118,
                child: const IgnorePointer(child: _SelectedNodeChameleon()),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedNodeChameleon extends StatefulWidget {
  const _SelectedNodeChameleon();

  @override
  State<_SelectedNodeChameleon> createState() => _SelectedNodeChameleonState();
}

class _SelectedNodeChameleonState extends State<_SelectedNodeChameleon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final frame = _controller.value < 0.5 ? 1 : 2;
        return Image.asset(
          'assets/images/chameleon/neutral/chameleon_idle0$frame.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        );
      },
    );
  }
}

class _AdventureBottomPlaque extends StatelessWidget {
  const _AdventureBottomPlaque({
    required this.scale,
    required this.locked,
    required this.level,
    required this.levelNumber,
    required this.stars,
    required this.onTap,
  });

  final double scale;
  final bool locked;
  final LevelDefinition level;
  final int levelNumber;
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Image.asset(
              '$_adventureRoot/scrim_black.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
        Positioned(
          left: 27 * scale,
          top: 81 * scale,
          width: 770 * scale,
          height: 370 * scale,
          child: IgnorePointer(
            child: Image.asset(
              '$_adventureRoot/adventure_MAP_level_frame.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
              color: locked ? const Color(0xDD000000) : null,
              colorBlendMode: locked ? BlendMode.srcATop : null,
            ),
          ),
        ),
        Positioned(
          left: 142 * scale,
          top: 170 * scale,
          width: 360 * scale,
          height: 48 * scale,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: _PixelText(
              level.name.toUpperCase(),
              fontSize: 34 * scale,
              color: locked ? const Color(0xFF706A57) : const Color(0xFFFFE733),
            ),
          ),
        ),
        Positioned(
          left: 142 * scale,
          top: 218 * scale,
          width: 350 * scale,
          height: 32 * scale,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: _PixelText(
              _objectiveText(level),
              fontSize: 24 * scale,
              color: locked ? const Color(0xFF5F5A4A) : const Color(0xFFF4F7DC),
            ),
          ),
        ),
        Positioned(
          right: 164 * scale,
          top: 171 * scale,
          width: 132 * scale,
          height: 84 * scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: _PixelText(
                  'LEVEL $levelNumber',
                  fontSize: 23 * scale,
                  color: locked
                      ? const Color(0xFF706A57)
                      : const Color(0xFFF4F7DC),
                ),
              ),
              SizedBox(height: 7 * scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PixelText(
                    '$stars/3',
                    fontSize: 32 * scale,
                    color: locked
                        ? const Color(0xFF706A57)
                        : const Color(0xFFFFE733),
                  ),
                  SizedBox(width: 6 * scale),
                  Image.asset(
                    '$_adventureRoot/star_icon.png',
                    width: 28 * scale,
                    height: 28 * scale,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    color: locked ? const Color(0xFF706A57) : null,
                    colorBlendMode: locked ? BlendMode.srcATop : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 203 * scale,
          top: 286 * scale,
          width: 418 * scale,
          height: 120 * scale,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
          ),
        ),
        if (locked)
          Positioned(
            left: 352 * scale,
            top: 274 * scale,
            width: 120 * scale,
            height: 120 * scale,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/btn_locked.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
      ],
    );
  }
}

class _WideAdventureButton extends StatefulWidget {
  const _WideAdventureButton({
    required this.text,
    required this.launching,
    required this.disabled,
    required this.onTap,
    this.width = 226,
    this.height = 58,
  });

  final String text;
  final bool launching;
  final bool disabled;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  State<_WideAdventureButton> createState() => _WideAdventureButtonState();
}

class _WideAdventureButtonState extends State<_WideAdventureButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.launching && !widget.disabled;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerCancel: (_) => setState(() => _pressed = false),
      onPointerUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: enabled ? 1 : 0.62,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 70),
          scale: _pressed ? 0.96 : 1,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    '$_adventureRoot/play_wideCTA.png',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.none,
                  ),
                ),
                Positioned(
                  left: 56,
                  right: 30,
                  top: 13,
                  height: 30,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _PixelText(
                      widget.text,
                      fontSize: 24,
                      color: const Color(0xFFF4F7DC),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveChoiceDialog extends StatelessWidget {
  const _SaveChoiceDialog({
    required this.sameLevel,
    required this.selectedLevelNumber,
  });

  final bool sameLevel;
  final int selectedLevelNumber;

  @override
  Widget build(BuildContext context) {
    final title = sameLevel ? 'SAVED RUN' : 'SAVE ACTIVE';
    final body = sameLevel
        ? 'Continue where you left off or restart this level.'
        : 'Continue your saved run or start Level $selectedLevelNumber fresh.';
    final restartText = sameLevel ? 'RESTART' : 'START';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          color: const Color(0xEF1E1308),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD6A94E), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0xAA000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PixelText(title, fontSize: 25, color: const Color(0xFFFFE733)),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: _pixelTextStyle(
                fontSize: 15,
                color: const Color(0xFFF4F7DC),
              ).copyWith(height: 1.18),
            ),
            const SizedBox(height: 18),
            _WideAdventureButton(
              text: 'CONTINUE',
              launching: false,
              disabled: false,
              width: 236,
              height: 60,
              onTap: () =>
                  Navigator.of(context).pop(_SavedRunChoice.continueSavedRun),
            ),
            const SizedBox(height: 10),
            _WideAdventureButton(
              text: restartText,
              launching: false,
              disabled: false,
              width: 236,
              height: 60,
              onTap: () =>
                  Navigator.of(context).pop(_SavedRunChoice.startSelectedLevel),
            ),
          ],
        ),
      ),
    );
  }
}

String _assetForNodeState(AdventureLevelNodeState state) {
  return switch (state) {
    AdventureLevelNodeState.locked => '$_adventureRoot/level_node_locked.png',
    AdventureLevelNodeState.unlocked =>
      '$_adventureRoot/level_node_unlocked.png',
    AdventureLevelNodeState.current => '$_adventureRoot/level_node_current.png',
    AdventureLevelNodeState.oneStar => '$_adventureRoot/level_node_1stars_.png',
    AdventureLevelNodeState.twoStar => '$_adventureRoot/level_node_2stars_.png',
    AdventureLevelNodeState.complete =>
      '$_adventureRoot/level_node_complete.png',
  };
}

String _objectiveText(LevelDefinition level) {
  final objective = level.activeObjectives.firstWhere(
    (candidate) => candidate.type != ObjectiveType.clearAll,
    orElse: () => level.activeObjectives.first,
  );
  return objective.describe();
}

class _AdventureMapSelector extends StatelessWidget {
  const _AdventureMapSelector({
    required this.controller,
    required this.maps,
    required this.selectedMapIndex,
    required this.earnedMapStars,
    required this.completed,
    required this.total,
    required this.selectedMapUnlocked,
    required this.launching,
    required this.onPageChanged,
    required this.onPlay,
  });

  final PageController controller;
  final List<AdventureMapCardDefinition> maps;
  final int selectedMapIndex;
  final int earnedMapStars;
  final String completed;
  final String total;
  final bool selectedMapUnlocked;
  final bool launching;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / 402,
          constraints.maxHeight / 820,
        );
        double sy(double value) => value * scale;
        final selectedMap = maps[selectedMapIndex];
        final remainingStars = adventureMapCardStarsNeeded(
          map: selectedMap,
          earnedStars: earnedMapStars,
        );

        return Column(
          children: [
            SizedBox(height: sy(4)),
            SizedBox(height: sy(96)),
            SizedBox(height: sy(26)),
            SizedBox(
              height: sy(30),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: _PixelText(
                  'CHOOSE YOUR MAP',
                  fontSize: 22,
                  color: Color(0xFFF4F7DC),
                ),
              ),
            ),
            SizedBox(height: sy(8)),
            SizedBox(
              height: sy(420),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  _MapCarouselViewport(
                    controller: controller,
                    maps: maps,
                    selectedMapIndex: selectedMapIndex,
                    earnedMapStars: earnedMapStars,
                  ),
                  PageView.builder(
                    controller: controller,
                    clipBehavior: Clip.none,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: onPageChanged,
                    itemCount: maps.length,
                    itemBuilder: (context, index) => const SizedBox.expand(),
                  ),
                ],
              ),
            ),
            SizedBox(height: sy(10)),
            if (selectedMapUnlocked)
              _PlayMapButton(launching: launching, onTap: onPlay, scale: scale)
            else
              SizedBox(height: sy(69)),
            SizedBox(height: sy(16)),
            if (selectedMapUnlocked)
              _AdventureRewardPanel(
                completed: completed,
                total: total,
                scale: scale,
              )
            else
              _AdventureUnlockPanel(starsNeeded: remainingStars, scale: scale),
            SizedBox(height: sy(8)),
          ],
        );
      },
    );
  }
}

class _AdventureTitlePlaque extends StatelessWidget {
  const _AdventureTitlePlaque({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 558 * scale,
      height: 179 * scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              '$_adventureRoot/adventure_title_plaque.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
          Positioned(
            left: 128 * scale,
            right: 122 * scale,
            top: 61 * scale,
            height: 38 * scale,
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: _PixelText(
                'ADVENTURE',
                fontSize: 26,
                color: Color(0xFFFFE733),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCarouselViewport extends StatelessWidget {
  const _MapCarouselViewport({
    required this.controller,
    required this.maps,
    required this.selectedMapIndex,
    required this.earnedMapStars,
  });

  final PageController controller;
  final List<AdventureMapCardDefinition> maps;
  final int selectedMapIndex;
  final int earnedMapStars;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameWidth = constraints.maxWidth * _selectedMapViewportFraction;
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final currentPage = controller.hasClients
                ? controller.page ?? selectedMapIndex.toDouble()
                : selectedMapIndex.toDouble();
            final nearestPage = currentPage
                .round()
                .clamp(0, maps.length - 1)
                .toInt();
            final orderedIndexes =
                List<int>.generate(maps.length, (index) {
                  return index;
                })..sort((a, b) {
                  final aDistance = (a - currentPage).abs();
                  final bDistance = (b - currentPage).abs();
                  return bDistance.compareTo(aDistance);
                });

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                for (final index in orderedIndexes)
                  _PositionedMapCard(
                    map: maps[index],
                    distanceFromPage: index - currentPage,
                    frameWidth: frameWidth,
                    frameHeight: constraints.maxHeight,
                    selected: index == nearestPage,
                    earnedMapStars: earnedMapStars,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PositionedMapCard extends StatelessWidget {
  const _PositionedMapCard({
    required this.map,
    required this.distanceFromPage,
    required this.frameWidth,
    required this.frameHeight,
    required this.selected,
    required this.earnedMapStars,
  });

  final AdventureMapCardDefinition map;
  final double distanceFromPage;
  final double frameWidth;
  final double frameHeight;
  final bool selected;
  final int earnedMapStars;

  @override
  Widget build(BuildContext context) {
    final clampedDistance = distanceFromPage.abs().clamp(0.0, 1.0);
    final scale = 1 - ((1 - _inactiveMapScale) * clampedDistance);
    final opacity = 1 - ((1 - _inactiveMapOpacity) * clampedDistance);
    final xOffset = distanceFromPage * frameWidth * _peekCardSpacingFactor;

    return Transform.translate(
      offset: Offset(xOffset, 0),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: SizedBox(
            width: frameWidth,
            height: frameHeight,
            child: _MapCardVisual(
              map: map,
              selected: selected,
              locked:
                  selected &&
                  !isAdventureMapCardUnlocked(
                    map: map,
                    earnedStars: earnedMapStars,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapCardVisual extends StatelessWidget {
  const _MapCardVisual({
    required this.map,
    required this.selected,
    required this.locked,
  });

  final AdventureMapCardDefinition map;
  final bool selected;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (selected && !locked)
          Positioned.fill(
            child: Image.asset(
              '$_adventureRoot/selection_focus_glow.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
        FractionallySizedBox(
          widthFactor: 0.886,
          heightFactor: 0.886,
          child: Center(
            child: Image.asset(
              map.asset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              color: locked ? const Color(0xCC000000) : null,
              colorBlendMode: locked ? BlendMode.srcATop : null,
            ),
          ),
        ),
        if (locked)
          FractionallySizedBox(
            widthFactor: 0.886,
            heightFactor: 0.886,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(33),
                  border: Border.all(color: const Color(0xFFFF1200), width: 6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x88FFFF33),
                      blurRadius: 22,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (locked)
          SizedBox(
            width: 130,
            height: 130,
            child: Image.asset(
              'assets/images/btn_locked.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
      ],
    );
  }
}

class _PlayMapButton extends StatefulWidget {
  const _PlayMapButton({
    required this.launching,
    required this.onTap,
    required this.scale,
  });

  final bool launching;
  final VoidCallback onTap;
  final double scale;

  @override
  State<_PlayMapButton> createState() => _PlayMapButtonState();
}

class _PlayMapButtonState extends State<_PlayMapButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: widget.launching
          ? null
          : (_) => setState(() => _pressed = true),
      onPointerCancel: (_) => setState(() => _pressed = false),
      onPointerUp: widget.launching
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 70),
        scale: _pressed ? 0.96 : 1,
        child: SizedBox(
          width: 266 * widget.scale,
          height: 69 * widget.scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  '$_adventureRoot/play_wideCTA.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
              Positioned(
                left: 72 * widget.scale,
                right: 36 * widget.scale,
                top: 16 * widget.scale,
                height: 38 * widget.scale,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _PixelText(
                    'PLAY',
                    fontSize: 34,
                    color: Color(0xFFF4F7DC),
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

class _AdventureRewardPanel extends StatelessWidget {
  const _AdventureRewardPanel({
    required this.completed,
    required this.total,
    required this.scale,
  });

  final String completed;
  final String total;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 274 * scale,
      height: 129 * scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              '$_adventureRoot/stars_container.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
          Positioned(
            left: 23 * scale,
            top: 29 * scale,
            width: 70 * scale,
            height: 70 * scale,
            child: Image.asset(
              '$_adventureRoot/star_icon.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
          Positioned(
            left: 102 * scale,
            top: 43 * scale,
            width: 96 * scale,
            height: 44 * scale,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RichText(
                maxLines: 1,
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: _pixelTextStyle(
                    fontSize: 30,
                    color: const Color(0xFFF4F7DC),
                  ),
                  children: [
                    TextSpan(text: '$completed/'),
                    TextSpan(
                      text: total,
                      style: _pixelTextStyle(
                        fontSize: 38,
                        color: const Color(0xFFF4F7DC),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 28 * scale,
            top: 33 * scale,
            width: 51 * scale,
            height: 61 * scale,
            child: Image.asset(
              '$_adventureRoot/badge_hide.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdventureUnlockPanel extends StatelessWidget {
  const _AdventureUnlockPanel({required this.starsNeeded, required this.scale});

  final int starsNeeded;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 274 * scale,
      height: 129 * scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              '$_adventureRoot/stars_container.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
          Positioned(
            left: 56 * scale,
            top: 31 * scale,
            width: 54 * scale,
            height: 54 * scale,
            child: Image.asset(
              '$_adventureRoot/star_icon.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
          Positioned(
            left: 114 * scale,
            top: 34 * scale,
            width: 82 * scale,
            height: 46 * scale,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _PixelText(
                '$starsNeeded',
                fontSize: 44,
                color: const Color(0xFFF4F7DC),
              ),
            ),
          ),
          Positioned(
            left: 58 * scale,
            right: 56 * scale,
            top: 76 * scale,
            height: 28 * scale,
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: _PixelText(
                'TO UNLOCK',
                fontSize: 26,
                color: Color(0xFFF4F7DC),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageTapButton extends StatefulWidget {
  const _ImageTapButton({
    required this.asset,
    required this.onTap,
    this.size = 50,
  });

  final String asset;
  final VoidCallback onTap;
  final double size;

  @override
  State<_ImageTapButton> createState() => _ImageTapButtonState();
}

class _ImageTapButtonState extends State<_ImageTapButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerCancel: (_) => setState(() => _pressed = false),
      onPointerUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 60),
        scale: _pressed ? 0.92 : 1,
        child: Image.asset(
          widget.asset,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}

class _PixelText extends StatelessWidget {
  const _PixelText(this.text, {required this.fontSize, required this.color});

  final String text;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        height: 1,
        fontWeight: FontWeight.w900,
        shadows: const [
          Shadow(color: Color(0xFF000000), offset: Offset(1.6, 2.0)),
        ],
      ),
    );
  }
}

TextStyle _pixelTextStyle({required double fontSize, required Color color}) {
  return TextStyle(
    color: color,
    fontSize: fontSize,
    height: 1,
    fontWeight: FontWeight.w900,
    shadows: const [Shadow(color: Color(0xFF000000), offset: Offset(1.6, 2.0))],
  );
}
