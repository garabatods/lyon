import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

class LevelBannerComponent extends PositionComponent {
  LevelBannerComponent({required String text, required Vector2 gameSize})
    : _gameSize = gameSize,
      _lines = _bannerLines(text),
      super(
        position: Vector2(-gameSize.x * 0.42, gameSize.y * 0.45),
        size: Vector2(gameSize.x * 0.86, 122),
        anchor: Anchor.center,
        priority: 95,
      );

  final Vector2 _gameSize;
  final ({String title, String? subtitle}) _lines;
  double _age = 0;
  double _alpha = 0;
  static const _lifeSeconds = 1.65;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    final progress = (_age / _lifeSeconds).clamp(0.0, 1.0);
    final xProgress = progress < 0.28
        ? _easeOut(progress / 0.28)
        : progress > 0.72
        ? 1 + _easeIn((progress - 0.72) / 0.28)
        : 1.0;
    position.x = -_gameSize.x * 0.42 + xProgress * _gameSize.x * 0.92;
    scale = Vector2.all(
      1.0 + (1 - (progress - 0.5).abs() * 2).clamp(0, 1) * 0.07,
    );
    _alpha = progress < 0.18
        ? progress / 0.18
        : progress > 0.82
        ? 1 - ((progress - 0.82) / 0.18)
        : 1;
    if (_age >= _lifeSeconds) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final alpha = _alpha.clamp(0.0, 1.0);
    if (alpha <= 0) {
      return;
    }

    final subtitle = _lines.subtitle;
    final titleSize = subtitle == null ? 40.0 : 35.0;
    final subtitleSize = 31.0;
    final maxWidth = size.x - 20;
    final titlePainter = _textPainter(
      _lines.title,
      _fitFontSize(_lines.title, titleSize, maxWidth),
      alpha,
      glow: true,
    );
    final subtitlePainter = subtitle == null
        ? null
        : _textPainter(
            subtitle,
            _fitFontSize(subtitle, subtitleSize, maxWidth),
            alpha,
            glow: false,
          );

    final gap = subtitlePainter == null ? 0.0 : 3.0;
    final totalHeight =
        titlePainter.height + gap + (subtitlePainter?.height ?? 0);
    var y = (size.y - totalHeight) / 2;
    _paintCentered(canvas, titlePainter, y);
    if (subtitlePainter != null) {
      y += titlePainter.height + gap;
      _paintCentered(canvas, subtitlePainter, y);
    }
  }

  static ({String title, String? subtitle}) _bannerLines(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final levelComplete = RegExp(
      r'^(LEVEL\s+\d+)\s+COMPLETE$',
    ).firstMatch(normalized);
    if (levelComplete != null) {
      return (title: levelComplete.group(1)!, subtitle: 'COMPLETE');
    }
    if (normalized == 'CAMPAIGN COMPLETE') {
      return (title: 'CAMPAIGN', subtitle: 'COMPLETE');
    }
    return (title: normalized, subtitle: null);
  }

  TextPainter _textPainter(
    String text,
    double fontSize,
    double alpha, {
    required bool glow,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFFFFF2B2).withValues(alpha: alpha),
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 0.94,
          shadows: [
            Shadow(
              color: const Color(0xEE000000).withValues(alpha: alpha),
              blurRadius: 8,
              offset: const Offset(2, 3),
            ),
            if (glow)
              Shadow(
                color: const Color(0xFFFF7D5B).withValues(alpha: alpha),
                blurRadius: 12,
              ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);
  }

  double _fitFontSize(String text, double baseSize, double maxWidth) {
    final estimatedWidth = text.length * baseSize * 0.62;
    if (estimatedWidth <= maxWidth) {
      return baseSize;
    }
    return (baseSize * maxWidth / estimatedWidth).clamp(24.0, baseSize);
  }

  void _paintCentered(Canvas canvas, TextPainter painter, double y) {
    painter.paint(canvas, Offset((size.x - painter.width) / 2, y));
  }

  double _easeOut(double t) => 1 - (1 - t) * (1 - t) * (1 - t);

  double _easeIn(double t) => t * t * t;
}
