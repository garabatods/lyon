import 'package:flutter/material.dart';

class TutorialModalTitle extends StatelessWidget {
  const TutorialModalTitle({
    required this.text,
    required this.modalSize,
    super.key,
  });

  static const designSize = Size(419, 570);
  static const double fontSize = 24;
  static const Rect titleRect = Rect.fromLTWH(72, 52, 275, 48);

  final String text;
  final Size modalSize;

  @override
  Widget build(BuildContext context) {
    double sx(double value) => modalSize.width * value / designSize.width;
    double sy(double value) => modalSize.height * value / designSize.height;

    return Positioned(
      left: sx(titleRect.left),
      top: sy(titleRect.top),
      width: sx(titleRect.width),
      height: sy(titleRect.height),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF4F7DC),
            fontSize: TutorialModalTitle.fontSize,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Color(0xFF000000), offset: Offset(2, 3))],
          ),
        ),
      ),
    );
  }
}

class TutorialModalBodyTitle extends StatelessWidget {
  const TutorialModalBodyTitle({
    required this.text,
    required this.modalSize,
    required this.rect,
    super.key,
  });

  static const double fontSize = 32;

  final String text;
  final Size modalSize;
  final Rect rect;

  @override
  Widget build(BuildContext context) {
    final scaled = _ScaledModalRect(modalSize, rect);

    return Positioned(
      left: scaled.left,
      top: scaled.top,
      width: scaled.width,
      height: scaled.height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFFFE733),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 0.95,
            shadows: [
              Shadow(color: Color(0xAA000000), offset: Offset(1.4, 1.8)),
            ],
          ),
        ),
      ),
    );
  }
}

class TutorialModalDescription extends StatelessWidget {
  const TutorialModalDescription({
    required this.text,
    required this.modalSize,
    required this.rect,
    this.maxLines = 4,
    super.key,
  });

  static const double fontSize = 18.2;
  static const double minFontSize = 15.5;

  final String text;
  final Size modalSize;
  final Rect rect;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final scaled = _ScaledModalRect(modalSize, rect);
    final scale = modalSize.height / TutorialModalTitle.designSize.height;

    return Positioned(
      left: scaled.left,
      top: scaled.top,
      width: scaled.width,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: const Color(0xFFEAD9AC),
          fontSize: (fontSize * scale).clamp(minFontSize, fontSize),
          height: 1.18,
          fontWeight: FontWeight.w800,
          shadows: const [
            Shadow(color: Color(0xAA000000), offset: Offset(1, 1)),
          ],
        ),
      ),
    );
  }
}

class _ScaledModalRect {
  const _ScaledModalRect(this.modalSize, this.rect);

  final Size modalSize;
  final Rect rect;

  double get left =>
      modalSize.width * rect.left / TutorialModalTitle.designSize.width;
  double get top =>
      modalSize.height * rect.top / TutorialModalTitle.designSize.height;
  double get width =>
      modalSize.width * rect.width / TutorialModalTitle.designSize.width;
  double get height =>
      modalSize.height * rect.height / TutorialModalTitle.designSize.height;
}
