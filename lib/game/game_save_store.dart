import 'package:shared_preferences/shared_preferences.dart';

import 'models/game_save.dart';

class GameSaveStore {
  static const key = 'lyon.activeGame.v1';

  final _prefs = SharedPreferencesAsync();

  Future<GameSave?> load() async {
    final encoded = await _prefs.getString(key);
    if (encoded == null) {
      return null;
    }

    final save = GameSave.decode(encoded);
    if (save == null) {
      await _prefs.remove(key);
    }
    return save;
  }

  Future<void> save(GameSave save) async {
    await _prefs.setString(key, save.encode());
  }

  Future<void> clear() async {
    await _prefs.remove(key);
  }
}
