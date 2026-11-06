import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/launcher_settings.dart';
import '../services/launcher_settings_store.dart';
import '../services/windows_startup_service.dart';

final launcherSettingsStoreProvider = Provider<LauncherSettingsStore>(
  (ref) => LauncherSettingsStore(),
);

final windowsStartupServiceProvider = Provider<WindowsStartupService>(
  (ref) => WindowsStartupService(),
);

final launcherSettingsProvider =
    AsyncNotifierProvider<LauncherSettingsNotifier, LauncherSettings>(
      LauncherSettingsNotifier.new,
    );

class LauncherSettingsNotifier extends AsyncNotifier<LauncherSettings> {
  @override
  Future<LauncherSettings> build() async {
    final settings = await ref.watch(launcherSettingsStoreProvider).load();
    await _removeDeprecatedMetadataCredentials();
    if (Platform.isWindows) {
      try {
        ref
            .watch(windowsStartupServiceProvider)
            .setEnabled(settings.launchAtStartup);
      } catch (error) {
        debugPrint('No se pudo configurar el inicio con Windows: $error');
      }
    }
    return settings;
  }

  Future<void> _removeDeprecatedMetadataCredentials() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await Future.wait([
        preferences.remove('igdb_client_id_v1'),
        preferences.remove('igdb_client_secret_v1'),
        preferences.remove('rawg_api_key_v1'),
      ]);
    } catch (error) {
      debugPrint('No se pudieron borrar claves de metadatos antiguas: $error');
    }
  }

  Future<void> setLaunchAtStartup(bool enabled) async {
    final settings = await future;
    if (Platform.isWindows) {
      ref.read(windowsStartupServiceProvider).setEnabled(enabled);
    }
    await _persist(settings.copyWith(launchAtStartup: enabled));
  }

  Future<void> _persist(LauncherSettings settings) async {
    await ref.read(launcherSettingsStoreProvider).save(settings);
    state = AsyncData(settings);
  }
}
