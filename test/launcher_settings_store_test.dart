import 'package:flutter_test/flutter_test.dart';
import 'package:lakra_launcher/models/launcher_settings.dart';
import 'package:lakra_launcher/services/launcher_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LauncherSettingsStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = LauncherSettingsStore();
  });

  test(
    'defaults to launching with Windows and persists the preference',
    () async {
      expect((await store.load()).launchAtStartup, isTrue);

      await store.save(const LauncherSettings(launchAtStartup: false));

      expect((await store.load()).launchAtStartup, isFalse);
    },
  );
}
