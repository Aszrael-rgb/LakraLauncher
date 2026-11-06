import 'package:shared_preferences/shared_preferences.dart';

import '../models/launcher_settings.dart';

class LauncherSettingsStore {
  static const _startupKey = 'settings_launch_at_startup';

  Future<LauncherSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!preferences.containsKey(_startupKey)) {
      await preferences.setBool(_startupKey, true);
    }

    return LauncherSettings(
      launchAtStartup: preferences.getBool(_startupKey) ?? true,
    );
  }

  Future<void> save(LauncherSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_startupKey, settings.launchAtStartup);
  }
}
