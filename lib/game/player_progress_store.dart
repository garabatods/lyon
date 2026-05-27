import 'package:shared_preferences/shared_preferences.dart';

import 'models/player_progress.dart';

class PlayerProgressStore {
  static const key = 'lyon.playerProgress.v1';

  final _prefs = SharedPreferencesAsync();

  Future<PlayerProgress> load() async {
    final encoded = await _prefs.getString(key);
    if (encoded == null) {
      return PlayerProgress.initial;
    }

    final progress = PlayerProgress.decode(encoded);
    if (progress == null) {
      await _prefs.remove(key);
      return PlayerProgress.initial;
    }
    return progress;
  }

  Future<void> save(PlayerProgress progress) async {
    await _prefs.setString(key, progress.encode());
  }

  Future<void> clear() async {
    await _prefs.remove(key);
  }
}
