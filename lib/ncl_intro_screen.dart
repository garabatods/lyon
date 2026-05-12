import 'dart:math' as math;

import 'package:flutter/material.dart';

const _assetRoot = 'assets/images/NLC_intro';

class NclIntroScreen extends StatefulWidget {
  const NclIntroScreen({required this.nextScreen, super.key});

  final Widget nextScreen;

  @override
  State<NclIntroScreen> createState() => _NclIntroScreenState();
}

class _NclIntroScreenState extends State<NclIntroScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _robotController;
  late final AnimationController _fadeOutController;

  bool _isLeaving = false;

  static const _robotFrames = [
    '$_assetRoot/robot_01.png',
    '$_assetRoot/robot_02.png',
    '$_assetRoot/robot_03.png',
    '$_assetRoot/robot_04.png',
  ];

  static const _sparkFrames = [
    '$_assetRoot/spark_01.png',
    '$_assetRoot/spark_02.png',
    '$_assetRoot/spark_03.png',
  ];

  @override
  void initState() {
    super.initState();
    _introController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 4000),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _leaveIntro();
          }
        });
    _robotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _introController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _robotController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _leaveIntro,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: Listenable.merge([
            _introController,
            _robotController,
            _fadeOutController,
          ]),
          builder: (context, _) {
            final t = _introController.value;
            final fadeOut = _fadeOutController.value;

            return Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: _interval(t, 0.02, 0.24, Curves.easeOut),
                  child: Image.asset(
                    '$_assetRoot/bg_stars.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.none,
                  ),
                ),
                CustomPaint(
                  painter: _CrtOverlayPainter(
                    progress: t,
                    flicker: _robotController.value,
                  ),
                ),
                Center(
                  child: FractionalTranslation(
                    translation: const Offset(0, 0.08),
                    child: _LogoComposition(
                      progress: t,
                      robotProgress: _robotController.value,
                      robotFrames: _robotFrames,
                      sparkFrames: _sparkFrames,
                    ),
                  ),
                ),
                IgnorePointer(
                  child: ColoredBox(color: Color.fromRGBO(0, 0, 0, fadeOut)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _leaveIntro() async {
    if (_isLeaving) {
      return;
    }
    _isLeaving = true;
    _introController.stop();
    await _fadeOutController.forward(from: 0);

    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (routeContext, animation, secondaryAnimation) {
          return widget.nextScreen;
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}

class _LogoComposition extends StatelessWidget {
  const _LogoComposition({
    required this.progress,
    required this.robotProgress,
    required this.robotFrames,
    required this.sparkFrames,
  });

  final double progress;
  final double robotProgress;
  final List<String> robotFrames;
  final List<String> sparkFrames;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth * 0.80, 390.0);
        final baseLogoWidth = width * 0.74;
        final baseLogoHeight = baseLogoWidth * 159 / 349;
        final baseUnderlineWidth = baseLogoWidth * 335 / 349;
        final baseUnderlineHeight = baseUnderlineWidth * 21 / 335;
        final baseSubtitleWidth = baseLogoWidth * 324 / 349;
        final baseSubtitleHeight = baseSubtitleWidth * 21 / 324;
        final baseLogoLeft = width * 0.30;
        final baseLogoTop = width * 0.04;
        final baseLogoCenter = baseLogoLeft + baseLogoWidth / 2;
        final baseLogoGroupHeight =
            baseLogoHeight + baseUnderlineHeight + baseSubtitleHeight + 2;
        final logoWidth = baseLogoWidth * 0.70;
        final logoHeight = logoWidth * 159 / 349;
        final underlineWidth = logoWidth * 335 / 349;
        final underlineHeight = underlineWidth * 21 / 335;
        final subtitleWidth = logoWidth * 324 / 349;
        final subtitleHeight = subtitleWidth * 21 / 324;
        final robotSize = width * 0.31;
        final logoLeft = baseLogoCenter - logoWidth / 2;
        final logoGroupHeight =
            logoHeight + underlineHeight + subtitleHeight + 2;
        final logoTop =
            baseLogoTop + (baseLogoGroupHeight - logoGroupHeight) / 2;
        final compositionHeight =
            baseLogoTop +
            baseLogoHeight +
            baseUnderlineHeight +
            baseSubtitleHeight +
            22;
        final robotFrame =
            (robotProgress * robotFrames.length).floor() % robotFrames.length;
        final bob = math.sin(robotProgress * math.pi * 2) * 3;

        return SizedBox(
          width: width,
          height: compositionHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: width * 0.06,
                top:
                    baseLogoTop +
                    baseLogoHeight +
                    baseUnderlineHeight -
                    robotSize -
                    2 +
                    bob,
                width: robotSize,
                height: robotSize,
                child: Opacity(
                  opacity: _interval(progress, 0.30, 0.50, Curves.easeOut),
                  child: Image.asset(
                    robotFrames[robotFrame],
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
              Positioned(
                left: logoLeft,
                top: logoTop,
                width: logoWidth,
                height: logoHeight,
                child: Opacity(
                  opacity: _interval(progress, 0.22, 0.46, Curves.easeOut),
                  child: Transform.translate(
                    offset: Offset(_glitchOffset(progress), 0),
                    child: Transform.scale(
                      scale: _logoScale(progress),
                      child: Image.asset(
                        '$_assetRoot/logo_games.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: logoLeft + (logoWidth - underlineWidth) / 2,
                top: logoTop + logoHeight - 6,
                width: underlineWidth,
                height: underlineHeight,
                child: Opacity(
                  opacity: _interval(progress, 0.42, 0.58, Curves.easeOut),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: _interval(
                        progress,
                        0.43,
                        0.56,
                        Curves.easeOutCubic,
                      ),
                      child: Image.asset(
                        '$_assetRoot/logo_underline.png',
                        width: underlineWidth,
                        height: underlineHeight,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: logoLeft + (logoWidth - subtitleWidth) / 2,
                top: logoTop + logoHeight + underlineHeight + 2,
                width: subtitleWidth,
                height: subtitleHeight,
                child: Opacity(
                  opacity: _interval(progress, 0.58, 0.76, Curves.easeOut),
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      8 * (1 - _interval(progress, 0.58, 0.76, Curves.easeOut)),
                    ),
                    child: Image.asset(
                      '$_assetRoot/logo_subtitle.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
              _Spark(
                progress: progress,
                robotProgress: robotProgress,
                frames: sparkFrames,
                left: logoLeft + logoWidth * 0.80,
                top: logoTop + logoHeight * 0.08,
                size: width * 0.06,
                delay: 0.48,
              ),
              _Spark(
                progress: progress,
                robotProgress: (robotProgress + 0.34) % 1,
                frames: sparkFrames,
                left: logoLeft + logoWidth * 0.58,
                top: logoTop + logoHeight * 0.76,
                size: width * 0.045,
                delay: 0.62,
              ),
              _Spark(
                progress: progress,
                robotProgress: (robotProgress + 0.68) % 1,
                frames: sparkFrames,
                left: logoLeft + logoWidth * 0.10,
                top: logoTop + logoHeight * 0.18,
                size: width * 0.04,
                delay: 0.70,
              ),
            ],
          ),
        );
      },
    );
  }

  double _logoScale(double t) {
    final settle = _interval(t, 0.22, 0.50, Curves.easeOutBack);
    return 0.9 + settle * 0.1;
  }

  double _glitchOffset(double t) {
    if (t < 0.36 || t > 0.48) {
      return 0;
    }
    final pulse = math.sin(t * 220);
    return pulse > 0 ? 1.5 : -1.5;
  }
}

class _Spark extends StatelessWidget {
  const _Spark({
    required this.progress,
    required this.robotProgress,
    required this.frames,
    required this.left,
    required this.top,
    required this.size,
    required this.delay,
  });

  final double progress;
  final double robotProgress;
  final List<String> frames;
  final double left;
  final double top;
  final double size;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final entrance = _interval(progress, delay, delay + 0.12, Curves.easeOut);
    final blink = math.sin((robotProgress + delay) * math.pi * 2);
    final opacity = entrance * (blink > 0.24 ? 0.72 : 0.0);
    final frame = (robotProgress * frames.length).floor() % frames.length;

    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Image.asset(
            frames[frame],
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }
}

class _CrtOverlayPainter extends CustomPainter {
  const _CrtOverlayPainter({required this.progress, required this.flicker});

  final double progress;
  final double flicker;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayStrength = _interval(progress, 0.12, 0.42, Curves.easeOut);
    if (overlayStrength <= 0) {
      return;
    }

    final scanlinePaint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, 0.035 * overlayStrength)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }

    final flickerOpacity =
        (0.025 + math.sin(flicker * math.pi * 2) * 0.012) * overlayStrength;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(255, 255, 255, flickerOpacity),
    );

    final vignette = RadialGradient(
      colors: [
        const Color(0x00000000),
        Color.fromRGBO(0, 0, 0, 0.55 * overlayStrength),
      ],
      stops: const [0.58, 1],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..shader = vignette);
  }

  @override
  bool shouldRepaint(_CrtOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.flicker != flicker;
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
