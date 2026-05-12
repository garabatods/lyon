import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/chameleon_puzzle_game.dart';
import 'game/game_save_store.dart';
import 'game/game_hud_state.dart';
import 'game/levels/demo_levels.dart';
import 'game/models/game_save.dart';
import 'game/models/power_up.dart';
import 'ncl_intro_screen.dart';
import 'title_screen.dart';

void main() {
  runApp(const ChameleonDemoApp());
}

class ChameleonDemoApp extends StatelessWidget {
  const ChameleonDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chameleon Puzzle Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3BAA68)),
        useMaterial3: true,
      ),
      home: const NclIntroScreen(
        nextScreen: TitleScreen(gameBuilder: _buildGameScreen),
      ),
    );
  }
}

Widget _buildGameScreen(GameSave? save) {
  return ChameleonGameScreen(initialSave: save);
}

class ChameleonGameScreen extends StatefulWidget {
  const ChameleonGameScreen({this.initialSave, super.key});

  final GameSave? initialSave;

  @override
  State<ChameleonGameScreen> createState() => _ChameleonGameScreenState();
}

class _ChameleonGameScreenState extends State<ChameleonGameScreen>
    with WidgetsBindingObserver {
  late final ChameleonPuzzleGame _game;
  final _saveStore = GameSaveStore();
  final _focusNode = FocusNode();
  Timer? _saveTimer;
  bool _lastGameOver = false;
  bool _saveInFlight = false;
  bool _saveAgain = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = ChameleonPuzzleGame(initialSave: widget.initialSave);
    _game.hud.addListener(_handleHudChanged);
    _saveTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_saveActiveRun()),
    );
    unawaited(_saveAfterInitialLoad());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _game.hud.removeListener(_handleHudChanged);
    unawaited(_saveActiveRun());
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

  void _handleHudChanged() {
    final hud = _game.hud.value;
    if (hud.gameOver && !_lastGameOver) {
      _lastGameOver = true;
      unawaited(_saveStore.clear());
    } else if (!hud.gameOver) {
      _lastGameOver = false;
      unawaited(_saveActiveRun());
    }
  }

  Future<void> _saveActiveRun() async {
    if (_saveInFlight) {
      _saveAgain = true;
      return;
    }
    final save = _game.snapshotForSave();
    if (save != null) {
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

  void _startNewGame() {
    _focusNode.requestFocus();
    _game.startNewGame();
    unawaited(_saveActiveRun());
  }

  Future<void> _closeToHome() async {
    _focusNode.requestFocus();
    await _saveStore.clear();
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
              Positioned(
                left: 28,
                right: 28,
                top: hudTop + 96,
                child: ValueListenableBuilder<GameHudState>(
                  valueListenable: _game.hud,
                  builder: (context, hud, _) => _StatusRibbon(hud: hud),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: MediaQuery.paddingOf(context).bottom + 8,
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
                  if (!hud.paused) {
                    return const SizedBox.shrink();
                  }
                  return _PausePanel(
                    hud: hud,
                    onResume: () {
                      _focusNode.requestFocus();
                      _game.togglePaused();
                    },
                    onNewGame: _startNewGame,
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
      if (digit != null && digit >= 1 && digit <= demoLevels.length) {
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
  const _StatusRibbon({required this.hud});

  final GameHudState hud;

  @override
  Widget build(BuildContext context) {
    final text = hud.statusText.trim();
    if (text.isEmpty || hud.gameOver || hud.paused) {
      return const SizedBox.shrink();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC172B16),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x99FFF2B2), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF4F7DC),
                fontSize: 13,
                height: 1.15,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(color: Color(0xAA000000), offset: Offset(1, 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    final starCount = _starCountForProgress(progress);

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

class _PausePanel extends StatelessWidget {
  const _PausePanel({
    required this.hud,
    required this.onResume,
    required this.onNewGame,
    required this.onHome,
  });

  final GameHudState hud;
  final VoidCallback onResume;
  final VoidCallback onNewGame;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final progress = _levelProgress(hud);
    final starCount = _starCountForProgress(progress);

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
                              top: sy(168),
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
                            top: sy(259),
                            width: sx(291),
                            height: sy(24),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Paused',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFFFFFFF),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: sx(78),
                            top: sy(299),
                            width: sx(263),
                            child: Text(
                              _pauseTipFor(hud),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: const Color(0xFFF4F7DC),
                                fontSize: sy(16).clamp(12.0, 16.0),
                                height: 1.2,
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
                                  onPressed: onNewGame,
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
  if (status.isNotEmpty && status != 'Paused') {
    return '• $status';
  }
  return '• Fill the stars by scoring before you finish the level.';
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
