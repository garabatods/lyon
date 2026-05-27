enum GameMode { adventure, timeTrial }

extension GameModeDetails on GameMode {
  String get label {
    return switch (this) {
      GameMode.adventure => 'Adventure',
      GameMode.timeTrial => 'Time Trial',
    };
  }
}
