import 'dart:convert';
import 'dart:io';

import '../models/game.dart';
import 'manual_game_store.dart';

class GameScanner {
  GameScanner(this._manualGameStore);

  final ManualGameStore _manualGameStore;

  Future<List<Game>> scanInstalledGames() async {
    if (!Platform.isWindows) return const [];

    final gamesById = <String, Game>{};
    for (final game in await _scanSteam()) {
      gamesById[game.id] = game;
    }
    for (final game in await _scanEpic()) {
      gamesById[game.id] = game;
    }
    for (final game in await _scanRegistryGames(
      GamePlatform.ea,
      const [
        r'HKLM\SOFTWARE\EA Games',
        r'HKLM\SOFTWARE\WOW6432Node\EA Games',
        r'HKLM\SOFTWARE\Origin Games',
        r'HKLM\SOFTWARE\WOW6432Node\Origin Games',
      ],
    )) {
      gamesById[game.id] = game;
    }
    for (final game in await _scanRegistryGames(
      GamePlatform.gog,
      const [
        r'HKLM\SOFTWARE\GOG.com\Games',
        r'HKLM\SOFTWARE\WOW6432Node\GOG.com\Games',
      ],
    )) {
      gamesById[game.id] = game;
    }
    for (final game in await _scanRegistryGames(
      GamePlatform.battleNet,
      const [
        r'HKLM\SOFTWARE\Blizzard Entertainment',
        r'HKLM\SOFTWARE\WOW6432Node\Blizzard Entertainment',
      ],
    )) {
      gamesById[game.id] = game;
    }
    for (final game in await _scanRegistryGames(
      GamePlatform.rockstar,
      const [
        r'HKLM\SOFTWARE\Rockstar Games',
        r'HKLM\SOFTWARE\WOW6432Node\Rockstar Games',
      ],
    )) {
      gamesById[game.id] = game;
    }
    for (final game in await _scanCustom()) {
      gamesById[game.id] = game;
    }
    for (final game in await _manualGameStore.loadGames()) {
      gamesById[game.id] = game;
    }

    final games = gamesById.values.toList()
      ..sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );
    return games;
  }

  Future<List<Game>> _scanSteam() async {
    final roots = <String>{
      if (Platform.environment['ProgramFiles(x86)'] case final root?)
        '$root\\Steam',
      if (Platform.environment['ProgramFiles'] case final root?) '$root\\Steam',
      if (Platform.environment['LOCALAPPDATA'] case final root?) '$root\\Steam',
    };
    final steamApps = <String>{};

    for (final root in roots) {
      final appsDirectory = Directory('$root\\steamapps');
      steamApps.add(appsDirectory.path);
      final librariesFile = File('${appsDirectory.path}\\libraryfolders.vdf');
      try {
        final contents = await librariesFile.readAsString();
        final pathPattern = RegExp(r'"path"\s+"((?:\\.|[^"])*)"');
        for (final match in pathPattern.allMatches(contents)) {
          final libraryPath = match.group(1)?.replaceAll('\\\\', '\\');
          if (libraryPath != null && libraryPath.isNotEmpty) {
            steamApps.add('$libraryPath\\steamapps');
          }
        }
      } on FileSystemException {
        continue;
      }
    }

    final games = <Game>[];
    for (final directoryPath in steamApps) {
      try {
        await for (final entry in Directory(
          directoryPath,
        ).list(followLinks: false)) {
          if (entry is! File || !entry.path.toLowerCase().endsWith('.acf')) {
            continue;
          }
          try {
            final contents = await entry.readAsString();
            final appId = _vdfValue(contents, 'appid');
            final name = _vdfValue(contents, 'name');
            if (appId == null ||
                name == null ||
                appId.isEmpty ||
                name.isEmpty) {
              continue;
            }
            games.add(
              Game(
                id: 'steam:$appId',
                name: name,
                platform: GamePlatform.steam,
                launchTarget: appId,
              ),
            );
          } on FileSystemException {
            continue;
          }
        }
      } on FileSystemException {
        continue;
      }
    }
    return games;
  }

  Future<List<Game>> _scanEpic() async {
    final programData = Platform.environment['PROGRAMDATA'];
    if (programData == null || programData.isEmpty) return const [];
    final manifests = Directory(
      '$programData\\Epic\\EpicGamesLauncher\\Data\\Manifests',
    );
    final games = <Game>[];

    try {
      await for (final entry in manifests.list(followLinks: false)) {
        if (entry is! File || !entry.path.toLowerCase().endsWith('.item')) {
          continue;
        }
        try {
          final decoded = jsonDecode(await entry.readAsString());
          if (decoded is! Map<String, dynamic>) continue;
          final appName = decoded['AppName'] as String?;
          final displayName = decoded['DisplayName'] as String?;
          if (appName == null || appName.isEmpty) continue;
          games.add(
            Game(
              id: 'epic:$appName',
              name: displayName?.isNotEmpty == true ? displayName! : appName,
              platform: GamePlatform.epic,
              launchTarget: appName,
            ),
          );
        } on FileSystemException {
          continue;
        } on FormatException {
          continue;
        }
      }
    } on FileSystemException {
      return const [];
    }
    return games;
  }

  Future<List<Game>> _scanCustom() async {
    final homeDirectory = Platform.environment['USERPROFILE'];
    final customPath =
        Platform.environment['LAKRA_CUSTOM_DIR'] ??
        (homeDirectory == null
            ? r'C:\LakraLauncher\Custom'
            : '$homeDirectory\\LakraLauncher\\Custom');
    final games = <Game>[];

    try {
      await for (final entry in Directory(
        customPath,
      ).list(followLinks: false)) {
        if (entry is! File) continue;
        final extension = entry.path.split('.').last.toLowerCase();
        if (extension != 'exe' &&
            extension != 'lnk' &&
            extension != 'url' &&
            extension != 'bat' &&
            extension != 'cmd') {
          continue;
        }
        final name = entry.uri.pathSegments.last.replaceAll(
          RegExp(r'\.[^.]+$'),
          '',
        );
        games.add(
          Game(
            id: 'custom:${entry.path.toLowerCase()}',
            name: name,
            platform: GamePlatform.custom,
            launchTarget: entry.path,
          ),
        );
      }
    } on FileSystemException {
      return const [];
    }
    return games;
  }

  Future<List<Game>> _scanRegistryGames(
    GamePlatform platform,
    List<String> registryRoots,
  ) async {
    final games = <Game>[];
    final knownExecutables = <String>{};
    for (final root in registryRoots) {
      late final ProcessResult result;
      try {
        result = await Process.run(
          'reg.exe',
          ['query', root, '/s'],
          runInShell: false,
        );
      } on ProcessException {
        continue;
      }
      if (result.exitCode != 0) continue;
      final entries = _parseRegistryOutput(result.stdout.toString());
      for (final entry in entries) {
        final values = entry.values;
        final name =
            _registryValue(values, const [
              'GameName',
              'DisplayName',
              'ProductName',
              'InstallName',
            ]) ??
            entry.key.split(r'\').last;
        if (_isRegistryContainer(name)) continue;
        final installPath = _expandEnvironmentVariables(
          _registryValue(values, const [
          'path',
          'Install Dir',
          'InstallDir',
          'InstallPath',
          'InstallLocation',
          'InstallFolder',
          ]),
        );
        final executableValue = _registryValue(values, const [
          'exe',
          'GameExe',
          'Executable',
          'LaunchExecutable',
          'Client',
        ]);
        final executable = await _resolveGameExecutable(
          installPath,
          executableValue,
          name,
          entry.key,
        );
        if (executable == null ||
            !knownExecutables.add(executable.toLowerCase())) {
          continue;
        }
        games.add(
          Game(
            id: '${platform.name}:${executable.toLowerCase()}',
            name: name,
            platform: platform,
            launchTarget: executable,
          ),
        );
      }
    }
    return games;
  }

  List<({String key, Map<String, String> values})> _parseRegistryOutput(
    String output,
  ) {
    final entries = <({String key, Map<String, String> values})>[];
    String? currentKey;
    Map<String, String>? currentValues;
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.startsWith('HKEY_')) {
        if (currentKey != null && currentValues != null) {
          entries.add((key: currentKey, values: currentValues));
        }
        currentKey = trimmed;
        currentValues = {};
        continue;
      }
      final match = RegExp(r'^(\S+)\s+REG_\w+\s+(.+)$').firstMatch(trimmed);
      if (match != null && currentValues != null) {
        currentValues[match.group(1)!.toLowerCase()] = match.group(2)!.trim();
      }
    }
    if (currentKey != null && currentValues != null) {
      entries.add((key: currentKey, values: currentValues));
    }
    return entries;
  }

  String? _registryValue(Map<String, String> values, List<String> names) {
    for (final name in names) {
      final value = values[name.toLowerCase()]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  bool _isRegistryContainer(String name) =>
      name.toLowerCase().contains('launcher') ||
      name.toLowerCase().contains('uninstall') ||
      name.toLowerCase() == 'games' ||
      name.toLowerCase() == 'ea games';

  Future<String?> _resolveGameExecutable(
    String? installPath,
    String? executableValue,
    String name,
    String registryKey,
  ) async {
    final candidates = <String>[];
    if (executableValue != null) {
      final normalized = executableValue.replaceAll('"', '').trim();
      if (normalized.toLowerCase().endsWith('.exe')) {
        final isAbsolute =
            RegExp(r'^[a-zA-Z]:\\').hasMatch(normalized) ||
            normalized.startsWith(r'\\');
        candidates.add(
          isAbsolute || installPath == null
              ? normalized
              : '$installPath\\$normalized',
        );
      }
    }
    if (installPath != null && installPath.toLowerCase().endsWith('.exe')) {
      candidates.add(installPath);
    }
    for (final candidate in candidates) {
      if (_executableScore(candidate, name, registryKey) < 1) continue;
      if (await File(candidate).exists()) return File(candidate).absolute.path;
    }

    final directories = <String>[];
    if (installPath != null && !installPath.toLowerCase().endsWith('.exe')) {
      directories.add(installPath.replaceAll('"', '').trim());
    }
    for (final directory in directories) {
      try {
        final executables = await Directory(directory)
            .list(followLinks: false)
            .where(
              (entry) =>
                  entry is File && entry.path.toLowerCase().endsWith('.exe'),
            )
            .map((entry) => entry.path)
            .toList();
        if (executables.isEmpty) continue;
        executables.sort((left, right) {
          final leftScore = _executableScore(left, name, registryKey);
          final rightScore = _executableScore(right, name, registryKey);
          return rightScore.compareTo(leftScore);
        });
        if (_executableScore(executables.first, name, registryKey) > 1) {
          return executables.first;
        }
      } on FileSystemException {
        continue;
      }
    }
    return null;
  }

  String? _expandEnvironmentVariables(String? value) {
    if (value == null) return null;
    return value.replaceAllMapped(RegExp(r'%([^%]+)%'), (match) {
      final variable = match.group(1)!.toLowerCase();
      for (final entry in Platform.environment.entries) {
        if (entry.key.toLowerCase() == variable) return entry.value;
      }
      return match.group(0)!;
    });
  }

  int _executableScore(String path, String name, String registryKey) {
    final file = path.split(RegExp(r'[/\\]')).last.toLowerCase();
    if (RegExp(
      r'^(unins|uninstall|setup|installer|crash|report|update|launcher|'
      r'battlenet|eaapp|rockstarservice)',
    ).hasMatch(file)) {
      return -1;
    }
    final normalizedName = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final normalizedFile = file.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normalizedName.isNotEmpty && normalizedFile.contains(normalizedName)) {
      return 3;
    }
    final productKey = registryKey.split(r'\').last.toLowerCase();
    if (productKey.length >= 2 &&
        normalizedFile.contains(productKey.replaceAll(RegExp(r'[^a-z0-9]'), ''))) {
      return 2;
    }
    return 1;
  }

  String? _vdfValue(String contents, String key) {
    final pattern = RegExp('"${RegExp.escape(key)}"\\s+"((?:\\\\.|[^"])*)"');
    final value = pattern.firstMatch(contents)?.group(1);
    return value?.replaceAll('\\\\"', '"').replaceAll('\\\\\\\\', '\\\\');
  }
}
