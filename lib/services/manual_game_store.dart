import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game.dart';

class ManualGameStore {
  static const _storageKey = 'manual_game_paths';
  static const _emulatedStorageKey = 'emulated_games_v1';
  static const _supportedExtensions = {'exe', 'lnk', 'url', 'bat', 'cmd'};

  Future<List<Game>> loadGames() async {
    final preferences = await SharedPreferences.getInstance();
    final paths = preferences.getStringList(_storageKey) ?? const <String>[];
    final games = <Game>[];

    for (final path in paths) {
      if (!await File(path).exists()) continue;
      games.add(
        Game(
          id: _idFor(path),
          name: _displayName(path),
          platform: GamePlatform.custom,
          launchTarget: path,
          isManual: true,
        ),
      );
    }

    final emulatedJson = preferences.getString(_emulatedStorageKey);
    if (emulatedJson != null) {
      try {
        final entries = jsonDecode(emulatedJson);
        if (entries is List) {
          for (final entry in entries.whereType<Map<String, dynamic>>()) {
            final rom = entry['rom'] as String?;
            final emulator = entry['emulator'] as String?;
            if (rom == null ||
                emulator == null ||
                !await File(rom).exists() ||
                !await File(emulator).exists()) {
              continue;
            }
            games.add(
              Game(
                id: _emulatedIdFor(rom),
                name: _displayName(rom),
                platform: GamePlatform.emulator,
                launchTarget: rom,
                isManual: true,
                emulatorPath: emulator,
                emulatorArguments: entry['arguments'] as String? ?? '',
              ),
            );
          }
        }
      } on FormatException {
        // Ignore damaged optional emulator entries and keep the rest of the library.
      }
    }
    return games;
  }

  Future<bool> addEmulatedGame({
    required String romPath,
    required String emulatorPath,
    String arguments = '',
  }) async {
    final rom = File(romPath).absolute.path;
    final emulator = File(emulatorPath).absolute.path;
    if (!await File(rom).exists() || !await File(emulator).exists()) {
      throw const FileSystemException('No se encuentra la ROM o el emulador.');
    }
    final preferences = await SharedPreferences.getInstance();
    final saved = <Map<String, dynamic>>[];
    final encoded = preferences.getString(_emulatedStorageKey);
    if (encoded != null) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          saved.addAll(decoded.whereType<Map<String, dynamic>>());
        }
      } on FormatException {
        // Replace invalid serialized data with the newly supplied valid entry.
      }
    }
    if (saved.any(
      (entry) => (entry['rom'] as String?)?.toLowerCase() == rom.toLowerCase(),
    )) {
      return false;
    }
    saved.add({
      'rom': rom,
      'emulator': emulator,
      'arguments': arguments.trim(),
    });
    await preferences.setString(_emulatedStorageKey, jsonEncode(saved));
    return true;
  }

  Future<int> addFiles(Iterable<String> paths) async {
    final preferences = await SharedPreferences.getInstance();
    final savedPaths = preferences.getStringList(_storageKey) ?? <String>[];
    final knownPaths = savedPaths.map((path) => path.toLowerCase()).toSet();
    var added = 0;

    for (final path in paths) {
      final normalizedPath = File(path).absolute.path;
      final extension = _extension(normalizedPath);
      if (!_supportedExtensions.contains(extension) ||
          knownPaths.contains(normalizedPath.toLowerCase()) ||
          !await File(normalizedPath).exists()) {
        continue;
      }
      savedPaths.add(normalizedPath);
      knownPaths.add(normalizedPath.toLowerCase());
      added++;
    }

    if (added > 0) await preferences.setStringList(_storageKey, savedPaths);
    return added;
  }

  Future<void> remove(String path) async {
    final preferences = await SharedPreferences.getInstance();
    final savedPaths = preferences.getStringList(_storageKey) ?? <String>[];
    savedPaths.removeWhere(
      (savedPath) => savedPath.toLowerCase() == path.toLowerCase(),
    );
    await preferences.setStringList(_storageKey, savedPaths);
    final encoded = preferences.getString(_emulatedStorageKey);
    if (encoded != null) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          decoded.removeWhere(
            (entry) =>
                entry is Map<String, dynamic> &&
                (entry['rom'] as String?)?.toLowerCase() == path.toLowerCase(),
          );
          await preferences.setString(_emulatedStorageKey, jsonEncode(decoded));
        }
      } on FormatException {
        await preferences.remove(_emulatedStorageKey);
      }
    }
  }

  String _idFor(String path) => 'custom:${path.toLowerCase()}';
  String _emulatedIdFor(String path) => 'emulator:${path.toLowerCase()}';

  String _extension(String path) => path.split('.').last.toLowerCase();

  String _displayName(String path) {
    final fileName = path.split(RegExp(r'[/\\]')).last;
    return fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
  }
}
