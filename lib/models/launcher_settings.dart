class LauncherSettings {
  const LauncherSettings({this.launchAtStartup = true});

  static const defaults = LauncherSettings();

  final bool launchAtStartup;

  LauncherSettings copyWith({bool? launchAtStartup}) {
    return LauncherSettings(
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
    );
  }
}
