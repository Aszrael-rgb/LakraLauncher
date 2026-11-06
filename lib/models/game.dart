enum GamePlatform { steam, epic, ea, gog, battleNet, rockstar, custom, emulator }

extension GamePlatformLabel on GamePlatform {
  String get label => switch (this) {
    GamePlatform.steam => 'Steam',
    GamePlatform.epic => 'Epic Games',
    GamePlatform.ea => 'EA app',
    GamePlatform.gog => 'GOG',
    GamePlatform.battleNet => 'Battle.net',
    GamePlatform.rockstar => 'Rockstar Games',
    GamePlatform.custom => 'Lakra',
    GamePlatform.emulator => 'Emulador',
  };
}

class Game {
  const Game({
    required this.id,
    required this.name,
    required this.platform,
    required this.launchTarget,
    this.isManual = false,
    this.displayNameOverride,
    this.coverPath,
    this.coverUrl,
    this.description = '',
    this.tags = const [],
    this.playTimeSeconds = 0,
    this.isFavorite = false,
    this.steamName,
    this.steamAppId,
    this.emulatorPath,
    this.emulatorArguments = '',
  });

  final String id;
  final String name;
  final GamePlatform platform;
  final String launchTarget;
  final bool isManual;
  final String? displayNameOverride;
  final String? coverPath;
  final String? coverUrl;
  final String description;
  final List<String> tags;
  final int playTimeSeconds;
  final bool isFavorite;
  final String? steamName;
  final int? steamAppId;
  final String? emulatorPath;

  /// Optional command-line arguments. `{rom}` is replaced with the ROM path.
  final String emulatorArguments;

  String get displayName {
    if (displayNameOverride?.trim().isNotEmpty == true) {
      return displayNameOverride!.trim();
    }
    return steamName?.trim().isNotEmpty == true ? steamName!.trim() : name;
  }

  String? get automaticCoverUrl {
    if (coverUrl != null && coverUrl!.isNotEmpty) return coverUrl;
    if (platform == GamePlatform.steam && int.tryParse(launchTarget) != null) {
      return 'https://cdn.akamai.steamstatic.com/steam/apps/$launchTarget/library_600x900.jpg';
    }
    return null;
  }

  Game withPresentation({
    String? displayNameOverride,
    String? coverPath,
    String? coverUrl,
    String? description,
    List<String>? tags,
    int? playTimeSeconds,
    bool? isFavorite,
    String? steamName,
    int? steamAppId,
  }) {
    return Game(
      id: id,
      name: name,
      platform: platform,
      launchTarget: launchTarget,
      isManual: isManual,
      displayNameOverride: displayNameOverride ?? this.displayNameOverride,
      coverPath: coverPath ?? this.coverPath,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      playTimeSeconds: playTimeSeconds ?? this.playTimeSeconds,
      isFavorite: isFavorite ?? this.isFavorite,
      steamName: steamName ?? this.steamName,
      steamAppId: steamAppId ?? this.steamAppId,
      emulatorPath: emulatorPath,
      emulatorArguments: emulatorArguments,
    );
  }
}
