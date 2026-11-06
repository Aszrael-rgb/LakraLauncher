import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GamePresentationMetadata {
  const GamePresentationMetadata({
    this.displayName,
    this.coverPath,
    this.coverUrl,
    this.description,
    this.tags = const [],
    this.playTimeSeconds = 0,
    this.isFavorite = false,
    this.steamName,
    this.steamAppId,
  });

  final String? displayName;
  final String? coverPath;
  final String? coverUrl;
  final String? description;
  final List<String> tags;
  final int playTimeSeconds;
  final bool isFavorite;
  final String? steamName;
  final int? steamAppId;

  factory GamePresentationMetadata.fromJson(Map<String, dynamic> json) {
    return GamePresentationMetadata(
      displayName: json['displayName'] as String?,
      coverPath: json['coverPath'] as String?,
      coverUrl: json['coverUrl'] as String?,
      description: json['description'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      playTimeSeconds: json['playTimeSeconds'] as int? ?? 0,
      isFavorite: json['isFavorite'] as bool? ?? false,
      steamName: json['steamName'] as String?,
      steamAppId: json['steamAppId'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'displayName': ?displayName,
    'coverPath': ?coverPath,
    'coverUrl': ?coverUrl,
    'description': ?description,
    if (tags.isNotEmpty) 'tags': tags,
    if (playTimeSeconds != 0) 'playTimeSeconds': playTimeSeconds,
    if (isFavorite) 'isFavorite': true,
    'steamName': ?steamName,
    'steamAppId': ?steamAppId,
  };
}

class GamePresentationStore {
  static const _storageKey = 'game_presentation_overrides_v1';
  static const _supportedExtensions = {'png', 'jpg', 'jpeg', 'webp'};

  Future<Map<String, GamePresentationMetadata>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null) return const {};

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: GamePresentationMetadata.fromJson(
              entry.value as Map<String, dynamic>,
            ),
      };
    } on FormatException {
      return const {};
    }
  }

  Future<void> setDisplayName(String gameId, String value) async {
    final metadata = await loadAll();
    final current = metadata[gameId] ?? const GamePresentationMetadata();
    final trimmed = value.trim();
    await _save(
      metadata,
      gameId,
      GamePresentationMetadata(
        displayName: trimmed.isEmpty ? null : trimmed,
        coverPath: current.coverPath,
        coverUrl: current.coverUrl,
        description: current.description,
        tags: current.tags,
        playTimeSeconds: current.playTimeSeconds,
        isFavorite: current.isFavorite,
        steamName: current.steamName,
        steamAppId: current.steamAppId,
      ),
    );
  }

  Future<void> setCover(String gameId, String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException(
        'No existe la portada seleccionada',
        sourcePath,
      );
    }
    final extension = sourcePath.split('.').last.toLowerCase();
    if (!_supportedExtensions.contains(extension)) {
      throw const FormatException('Formato de portada no compatible');
    }

    final directory = await getApplicationSupportDirectory();
    final coversDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}game_covers',
    );
    await coversDirectory.create(recursive: true);
    final safeId = base64Url.encode(utf8.encode(gameId)).replaceAll('=', '');
    final destination = File(
      '${coversDirectory.path}${Platform.pathSeparator}$safeId.$extension',
    );
    await source.copy(destination.path);

    final metadata = await loadAll();
    final current = metadata[gameId] ?? const GamePresentationMetadata();
    await _save(
      metadata,
      gameId,
      GamePresentationMetadata(
        displayName: current.displayName,
        coverPath: destination.path,
        coverUrl: current.coverUrl,
        description: current.description,
        tags: current.tags,
        playTimeSeconds: current.playTimeSeconds,
        isFavorite: current.isFavorite,
        steamName: current.steamName,
        steamAppId: current.steamAppId,
      ),
    );
    if (current.coverPath != null && current.coverPath != destination.path) {
      await _deleteFile(current.coverPath!);
    }
  }

  Future<void> clearCover(String gameId) async {
    final metadata = await loadAll();
    final current = metadata[gameId];
    if (current == null) return;
    await _save(
      metadata,
      gameId,
      GamePresentationMetadata(
        displayName: current.displayName,
        coverUrl: current.coverUrl,
        description: current.description,
        tags: current.tags,
        playTimeSeconds: current.playTimeSeconds,
        isFavorite: current.isFavorite,
        steamName: current.steamName,
        steamAppId: current.steamAppId,
      ),
    );
    if (current.coverPath != null) await _deleteFile(current.coverPath!);
  }

  Future<void> setSteamMetadata(
    String gameId, {
    required String steamName,
    required int steamAppId,
    required String coverUrl,
  }) async {
    final metadata = await loadAll();
    final current = metadata[gameId] ?? const GamePresentationMetadata();
    await _save(
      metadata,
      gameId,
      GamePresentationMetadata(
        displayName: current.displayName,
        coverPath: current.coverPath,
        coverUrl: coverUrl,
        description: current.description,
        tags: current.tags,
        playTimeSeconds: current.playTimeSeconds,
        isFavorite: current.isFavorite,
        steamName: steamName,
        steamAppId: steamAppId,
      ),
    );
  }

  Future<void> addPlayedTime(String gameId, Duration elapsed) async {
    if (elapsed.inSeconds <= 0) return;
    final metadata = await loadAll();
    final current = metadata[gameId] ?? const GamePresentationMetadata();
    await _save(
      metadata,
      gameId,
      GamePresentationMetadata(
        displayName: current.displayName,
        coverPath: current.coverPath,
        coverUrl: current.coverUrl,
        description: current.description,
        tags: current.tags,
        playTimeSeconds: current.playTimeSeconds + elapsed.inSeconds,
        isFavorite: current.isFavorite,
        steamName: current.steamName,
        steamAppId: current.steamAppId,
      ),
    );
  }

  Future<void> setFavorite(String gameId, bool isFavorite) async {
    final metadata = await loadAll();
    final current = metadata[gameId] ?? const GamePresentationMetadata();
    await _save(
      metadata,
      gameId,
      GamePresentationMetadata(
        displayName: current.displayName,
        coverPath: current.coverPath,
        coverUrl: current.coverUrl,
        description: current.description,
        tags: current.tags,
        playTimeSeconds: current.playTimeSeconds,
        isFavorite: isFavorite,
        steamName: current.steamName,
        steamAppId: current.steamAppId,
      ),
    );
  }

  Future<void> _save(
    Map<String, GamePresentationMetadata> current,
    String gameId,
    GamePresentationMetadata value,
  ) async {
    final updated = Map<String, GamePresentationMetadata>.of(current);
    if (value.displayName == null &&
        value.coverPath == null &&
        value.coverUrl == null &&
        value.description == null &&
        value.tags.isEmpty &&
        value.playTimeSeconds == 0 &&
        !value.isFavorite &&
        value.steamName == null &&
        value.steamAppId == null) {
      updated.remove(gameId);
    } else {
      updated[gameId] = value;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode({
        for (final entry in updated.entries) entry.key: entry.value.toJson(),
      }),
    );
  }

  Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
