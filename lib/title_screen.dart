import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'adventure_map_definition.dart';
import 'adventure_screen.dart';
import 'game/game_save_store.dart';
import 'game/levels/demo_levels.dart';
import 'game/models/game_save.dart';
import 'game/models/game_mode.dart';
import 'game/models/level_set_id.dart';
import 'game/models/player_progress.dart';
import 'game/player_progress_store.dart';
import 'tutorial_modal_title.dart';

typedef TitleGameBuilder =
    Widget Function(
      GameSave? initialSave,
      GameMode mode, {
      LevelSetId? initialLevelSetId,
      int? initialLevelIndex,
    });

const _titleRoot = 'assets/images/title_screen';
const _designSize = Size(822, 1786);

class TitleScreen extends StatefulWidget {
  const TitleScreen({required this.gameBuilder, super.key});

  final TitleGameBuilder gameBuilder;

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with TickerProviderStateMixin {
  final _saveStore = GameSaveStore();
  final _progressStore = PlayerProgressStore();
  late final AnimationController _introController;
  late final AnimationController _ambientController;

  GameSave? _save;
  PlayerProgress _progress = PlayerProgress.initial;
  bool _loadingSave = true;
  bool _launching = false;
  bool _showTutorialIntro = false;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4300),
    )..forward();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    unawaited(_loadSave());
  }

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skipIntro,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: Listenable.merge([_introController, _ambientController]),
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final placement = _CoverPlacement.fromSize(
                  Size(constraints.maxWidth, constraints.maxHeight),
                );
                final intro = _introController.value;
                final menu = _interval(intro, 0.56, 0.82, Curves.easeOutCubic);
                final tutorialLocked =
                    !_loadingSave && !_progress.tutorialCompleted;
                final continueSave = _continueSave;
                final canContinue =
                    continueSave != null &&
                    !_loadingSave &&
                    _progress.tutorialCompleted;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      '$_titleRoot/title_background.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.none,
                    ),
                    _BackgroundVignette(progress: intro),
                    ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.45 * menu)),
                    ..._introFx(placement, intro),
                    _LogoLayer(
                      placement: placement,
                      intro: intro,
                      ambient: _ambientController.value,
                      menuProgress: menu,
                    ),
                    _MenuLayer(
                      placement: placement,
                      progress: menu,
                      canContinue: canContinue,
                      tutorialLocked: tutorialLocked,
                      launching: _launching,
                      onPlay: tutorialLocked
                          ? _openTutorialIntro
                          : () => _launchGame(),
                      onAdventure: tutorialLocked
                          ? _openTutorialIntro
                          : _openAdventureScreen,
                      onTimeTrial: tutorialLocked
                          ? _openTutorialIntro
                          : () => _launchGame(mode: GameMode.timeTrial),
                      onComingSoon: _showComingSoon,
                      onLocked: _openTutorialIntro,
                      onSettings: _debugResetProgress,
                    ),
                    if (_showTutorialIntro)
                      _TutorialIntroModal(
                        progress: menu,
                        onStart: _startTutorial,
                      ),
                    _FooterCredit(placement: placement, progress: 1 - menu),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<Widget> _introFx(_CoverPlacement placement, double intro) {
    final pulse = math.sin(_ambientController.value * math.pi * 2);
    return [
      _AssetRect(
        placement: placement,
        rect: const Rect.fromLTWH(328, 340, 184, 184),
        opacity:
            _interval(intro, 0.20, 0.42, Curves.easeOut) *
            (0.36 + pulse.abs() * 0.18),
        child: Image.asset(
          'assets/images/fx_combo_burst.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
      _FxSprite(
        placement: placement,
        asset: 'assets/images/fx_sparkle.png',
        x: 166,
        y: 276,
        size: 96,
        delay: 0.30,
        intro: intro,
        ambient: _ambientController.value,
      ),
      _FxSprite(
        placement: placement,
        asset: 'assets/images/fx_color_splash_yellow.png',
        x: 588,
        y: 442,
        size: 78,
        delay: 0.40,
        intro: intro,
        ambient: (_ambientController.value + 0.37) % 1,
      ),
      _FxSprite(
        placement: placement,
        asset: 'assets/images/fx_sparkle.png',
        x: 616,
        y: 646,
        size: 74,
        delay: 0.46,
        intro: intro,
        ambient: (_ambientController.value + 0.72) % 1,
      ),
    ];
  }

  Future<void> _loadSave() async {
    final save = await _saveStore.load();
    final progress = await _progressStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _save = save;
      _progress = progress;
      _loadingSave = false;
    });
  }

  void _skipIntro() {
    if (_introController.value >= 0.82 || _introController.isAnimating) {
      if (_introController.value < 1) {
        _introController.animateTo(
          1,
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  Future<void> _launchGame({GameMode? mode, LevelSetId? levelSetId}) async {
    if (_launching || _loadingSave) {
      return;
    }
    setState(() => _launching = true);

    final save = mode == null ? _continueSave : null;
    final nextMode = mode ?? save?.mode ?? GameMode.adventure;
    final nextLevelSetId =
        levelSetId ??
        (nextMode == GameMode.timeTrial || save == null
            ? LevelSetId.map01
            : null);
    final nextLevelIndex =
        save == null &&
            nextMode == GameMode.adventure &&
            nextLevelSetId == LevelSetId.map01
        ? _latestMap01LevelIndex
        : null;
    if (save == null) {
      await _saveStore.clear();
    }

    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) {
          return widget.gameBuilder(
            save,
            nextMode,
            initialLevelSetId: nextLevelSetId,
            initialLevelIndex: nextLevelIndex,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  GameSave? get _continueSave {
    final save = _save;
    if (save == null) {
      return null;
    }
    if (save.mode != GameMode.adventure ||
        save.levelSetId != LevelSetId.map01) {
      return null;
    }
    final latestLevelIndex = _latestMap01LevelIndex;
    if (save.levelIndex < latestLevelIndex) {
      return null;
    }
    return save;
  }

  int get _latestMap01LevelIndex {
    return firstAdventureLevelIndex(progress: _progress, levels: map01Levels);
  }

  Future<void> _openAdventureScreen() async {
    if (_launching || _loadingSave) {
      return;
    }
    setState(() => _launching = true);
    final adventureSave = _continueSave;

    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) {
          return AdventureScreen(
            activeSave: adventureSave,
            progress: _progress,
            gameBuilder: widget.gameBuilder,
            homeBuilder: (_) => TitleScreen(gameBuilder: widget.gameBuilder),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> _startTutorial() async {
    if (_launching || _loadingSave) {
      return;
    }
    await _progressStore.save(_progress.markTutorialIntroSeen());
    if (!mounted) {
      return;
    }
    await _launchGame(
      mode: GameMode.adventure,
      levelSetId: LevelSetId.tutorial,
    );
  }

  Future<void> _debugResetProgress() async {
    if (_launching || _loadingSave) {
      return;
    }
    await _saveStore.clear();
    await _progressStore.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _save = null;
      _progress = PlayerProgress.initial;
      _showTutorialIntro = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Debug reset: tutorial and saves cleared'),
          duration: Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openTutorialIntro() {
    if (_launching || _loadingSave) {
      return;
    }
    setState(() => _showTutorialIntro = true);
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
}

class _MenuLayer extends StatelessWidget {
  const _MenuLayer({
    required this.placement,
    required this.progress,
    required this.canContinue,
    required this.tutorialLocked,
    required this.launching,
    required this.onPlay,
    required this.onAdventure,
    required this.onTimeTrial,
    required this.onComingSoon,
    required this.onLocked,
    required this.onSettings,
  });

  final _CoverPlacement placement;
  final double progress;
  final bool canContinue;
  final bool tutorialLocked;
  final bool launching;
  final VoidCallback onPlay;
  final VoidCallback onAdventure;
  final VoidCallback onTimeTrial;
  final VoidCallback onComingSoon;
  final VoidCallback onLocked;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final slide = 28 * (1 - progress);
    return IgnorePointer(
      ignoring: progress < 0.98 || launching,
      child: Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, slide),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _TitleImageButton(
                placement: placement,
                rect: const Rect.fromLTWH(28, 82, 304, 131),
                asset: '$_titleRoot/title_coins_currency.png',
                onTap: onComingSoon,
              ),
              _TitleImageButton(
                placement: placement,
                rect: const Rect.fromLTWH(356, 82, 304, 131),
                asset: '$_titleRoot/title_diamons_currency.png',
                onTap: onComingSoon,
              ),
              _TitleImageButton(
                placement: placement,
                rect: const Rect.fromLTWH(674, 82, 132, 130),
                asset: '$_titleRoot/title_settings.png',
                onTap: onSettings,
              ),
              _TitleImageButton(
                placement: placement,
                rect: Rect.fromLTWH(
                  94,
                  canContinue ? 912 : 968,
                  634,
                  canContinue ? 331 : 235,
                ),
                asset: canContinue
                    ? '$_titleRoot/title_play_continue.png'
                    : '$_titleRoot/title_play.png',
                caption: canContinue ? 'CONTINUE' : null,
                onTap: onPlay,
              ),
              _TitleImageButton(
                placement: placement,
                rect: const Rect.fromLTWH(116, 1246, 284, 216),
                asset: '$_titleRoot/adventure.png',
                onTap: onAdventure,
                locked: tutorialLocked,
              ),
              _TitleImageButton(
                placement: placement,
                rect: const Rect.fromLTWH(422, 1246, 284, 216),
                asset: '$_titleRoot/time_trial.png',
                onTap: onTimeTrial,
                locked: tutorialLocked,
              ),
              _TitleImageButton(
                placement: placement,
                rect: const Rect.fromLTWH(116, 1488, 285, 216),
                asset: '$_titleRoot/achievements.png',
                onTap: tutorialLocked ? onLocked : onComingSoon,
                locked: tutorialLocked,
              ),
              _TitleImageButton(
                placement: placement,
                rect: const Rect.fromLTWH(419, 1488, 291, 216),
                asset: '$_titleRoot/daily.png',
                onTap: tutorialLocked ? onLocked : onComingSoon,
                locked: tutorialLocked,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoLayer extends StatelessWidget {
  const _LogoLayer({
    required this.placement,
    required this.intro,
    required this.ambient,
    required this.menuProgress,
  });

  final _CoverPlacement placement;
  final double intro;
  final double ambient;
  final double menuProgress;

  @override
  Widget build(BuildContext context) {
    final entrance = _interval(intro, 0.04, 0.44, Curves.easeOutBack);
    final introY = -250 + entrance * 510;
    final finalY = 258.0;
    final y = _lerpDouble(introY, finalY, menuProgress);
    final scale =
        0.86 + entrance * 0.14 + math.sin(ambient * math.pi * 2) * 0.01;
    final glow =
        _interval(intro, 0.18, 0.50, Curves.easeOut) *
        (0.28 + math.sin(ambient * math.pi * 2).abs() * 0.18);
    final rect = Rect.fromLTWH(66, y, 689, 367);

    return _AssetRect(
      placement: placement,
      rect: rect,
      opacity: _interval(intro, 0.02, 0.18, Curves.easeOut),
      child: Transform.scale(
        scale: scale,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (glow > 0)
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Color.fromRGBO(255, 230, 106, glow),
                  BlendMode.srcATop,
                ),
                child: Image.asset(
                  '$_titleRoot/title_screen_LOGO.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
              ),
            Image.asset(
              '$_titleRoot/title_screen_LOGO.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
            ClipRect(
              child: CustomPaint(
                painter: _LogoGlarePainter(
                  progress: _interval(intro, 0.30, 0.58, Curves.easeInOut),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialIntroModal extends StatelessWidget {
  const _TutorialIntroModal({required this.progress, required this.onStart});

  final double progress;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: Color.fromRGBO(0, 0, 0, 0.68 * progress.clamp(0, 1)),
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
                              text: 'TUTORIAL',
                              modalSize: size,
                            ),
                            TutorialModalBodyTitle(
                              text: 'LEARN\nTHE BASICS',
                              modalSize: size,
                              rect: const Rect.fromLTWH(48, 162, 323, 138),
                            ),
                            TutorialModalDescription(
                              text:
                                  'You will play six short tutorial levels first. After that, Adventure and Time Trial unlock.',
                              modalSize: size,
                              rect: const Rect.fromLTWH(64, 318, 291, 0),
                              maxLines: 4,
                            ),
                            TutorialModalDescription(
                              text:
                                  'Finish Level 6 to unlock Adventure and Time Trial.',
                              modalSize: size,
                              rect: const Rect.fromLTWH(60, 424, 299, 0),
                              maxLines: 2,
                            ),
                            Positioned(
                              left: sx(172),
                              top: sy(492),
                              width: sx(75),
                              height: sy(72),
                              child: _TitleModalCtaButton(
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

class _TitleModalCtaButton extends StatefulWidget {
  const _TitleModalCtaButton({required this.asset, required this.onPressed});

  final String asset;
  final VoidCallback onPressed;

  @override
  State<_TitleModalCtaButton> createState() => _TitleModalCtaButtonState();
}

class _TitleModalCtaButtonState extends State<_TitleModalCtaButton> {
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
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}

class _FxSprite extends StatelessWidget {
  const _FxSprite({
    required this.placement,
    required this.asset,
    required this.x,
    required this.y,
    required this.size,
    required this.delay,
    required this.intro,
    required this.ambient,
  });

  final _CoverPlacement placement;
  final String asset;
  final double x;
  final double y;
  final double size;
  final double delay;
  final double intro;
  final double ambient;

  @override
  Widget build(BuildContext context) {
    final enter = _interval(intro, delay, delay + 0.18, Curves.easeOut);
    final fade = 1 - _interval(intro, 0.76, 0.96, Curves.easeIn);
    final twinkle = 0.4 + math.sin(ambient * math.pi * 2).abs() * 0.6;
    final scale = 0.82 + enter * 0.18 + twinkle * 0.08;
    return _AssetRect(
      placement: placement,
      rect: Rect.fromLTWH(x, y, size, size),
      opacity: enter * fade * twinkle * 0.68,
      child: Transform.rotate(
        angle: ambient * math.pi * 2,
        child: Transform.scale(
          scale: scale,
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }
}

class _TitleImageButton extends StatefulWidget {
  const _TitleImageButton({
    required this.placement,
    required this.rect,
    required this.asset,
    required this.onTap,
    this.caption,
    this.locked = false,
  });

  final _CoverPlacement placement;
  final Rect rect;
  final String asset;
  final VoidCallback onTap;
  final String? caption;
  final bool locked;

  @override
  State<_TitleImageButton> createState() => _TitleImageButtonState();
}

class _TitleImageButtonState extends State<_TitleImageButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return _AssetRect(
      placement: widget.placement,
      rect: widget.rect,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerCancel: (_) => setState(() => _pressed = false),
        onPointerUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        child: AnimatedScale(
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOut,
          scale: _pressed ? 0.96 : 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    widget.asset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                  if (widget.locked)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(
                            constraints.maxWidth * 0.14,
                          ),
                        ),
                      ),
                    ),
                  if (widget.locked)
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox.square(
                        dimension:
                            math.min(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ) *
                            0.48,
                        child: Image.asset(
                          'assets/images/tutorial/tutorial_lock_badge.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                  if (widget.caption != null)
                    Positioned(
                      left: constraints.maxWidth * 0.22,
                      right: constraints.maxWidth * 0.22,
                      top: constraints.maxHeight * 0.69,
                      height: constraints.maxHeight * 0.16,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.caption!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFF4F7DC),
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: Color(0xFF000000),
                                offset: Offset(2.5, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FooterCredit extends StatelessWidget {
  const _FooterCredit({required this.placement, required this.progress});

  final _CoverPlacement placement;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return _AssetRect(
      placement: placement,
      rect: const Rect.fromLTWH(150, 1670, 522, 42),
      opacity: progress.clamp(0, 1).toDouble(),
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'NEON CARTRIDGE LABS @2026',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 22,
            height: 1,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Color(0xFF000000), offset: Offset(2, 2))],
          ),
        ),
      ),
    );
  }
}

class _BackgroundVignette extends StatelessWidget {
  const _BackgroundVignette({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VignettePainter(
        strength: 0.18 + _interval(progress, 0.58, 0.86, Curves.easeOut) * 0.32,
      ),
    );
  }
}

class _VignettePainter extends CustomPainter {
  const _VignettePainter({required this.strength});

  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = RadialGradient(
      colors: [const Color(0x00000000), Color.fromRGBO(0, 0, 0, strength)],
      stops: const [0.45, 1],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _VignettePainter oldDelegate) {
    return oldDelegate.strength != strength;
  }
}

class _LogoGlarePainter extends CustomPainter {
  const _LogoGlarePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) {
      return;
    }

    final centerX = -size.width * 0.25 + progress * size.width * 1.5;
    final rect = Rect.fromCenter(
      center: Offset(centerX, size.height * 0.48),
      width: size.width * 0.18,
      height: size.height * 1.5,
    );
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(-0.34);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    final shader = const LinearGradient(
      colors: [
        Color(0x00FFFFFF),
        Color(0x66FFFFFF),
        Color(0xCCFFF5B8),
        Color(0x55FFFFFF),
        Color(0x00FFFFFF),
      ],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoGlarePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _AssetRect extends StatelessWidget {
  const _AssetRect({
    required this.placement,
    required this.rect,
    required this.child,
    this.opacity = 1,
  });

  final _CoverPlacement placement;
  final Rect rect;
  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final placed = placement.rectFor(rect);
    return Positioned.fromRect(
      rect: placed,
      child: opacity >= 1
          ? child
          : Opacity(opacity: opacity.clamp(0, 1).toDouble(), child: child),
    );
  }
}

class _CoverPlacement {
  const _CoverPlacement({
    required this.scale,
    required this.dx,
    required this.dy,
  });

  factory _CoverPlacement.fromSize(Size viewport) {
    final scale = math.min(
      viewport.width / _designSize.width,
      viewport.height / _designSize.height,
    );
    final width = _designSize.width * scale;
    final height = _designSize.height * scale;
    return _CoverPlacement(
      scale: scale,
      dx: (viewport.width - width) / 2,
      dy: (viewport.height - height) / 2,
    );
  }

  final double scale;
  final double dx;
  final double dy;

  Rect rectFor(Rect source) {
    return Rect.fromLTWH(
      dx + source.left * scale,
      dy + source.top * scale,
      source.width * scale,
      source.height * scale,
    );
  }
}

double _interval(double t, double start, double end, Curve curve) {
  if (t <= start) {
    return 0;
  }
  if (t >= end) {
    return 1;
  }
  return curve.transform((t - start) / (end - start));
}

double _lerpDouble(double a, double b, double t) {
  return a + (b - a) * t.clamp(0, 1).toDouble();
}
