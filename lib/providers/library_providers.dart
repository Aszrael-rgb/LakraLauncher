import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../services/game_launcher.dart';
import '../services/game_presentation_store.dart';
import '../services/manual_game_store.dart';
import '../services/game_scanner.dart';
import '../services/steam_metadata_service.dart';

final manualGameStoreProvider = Provider<ManualGameStore>(
  (ref) => ManualGameStore(),
);
final gameScannerProvider = Provider<GameScanner>(
  (ref) => GameScanner(ref.watch(manualGameStoreProvider)),
);
final gameLauncherProvider = Provider<GameLauncher>((ref) => GameLauncher());
final gamePresentationStoreProvider = Provider<GamePresentationStore>(
  (ref) => GamePresentationStore(),
);
final steamMetadataServiceProvider = Provider<SteamMetadataService>((ref) {
  final service = SteamMetadataService();
  ref.onDispose(service.close);
  return service;
});

final gamesProvider = FutureProvider<List<Game>>((ref) {
  return ref.watch(gameScannerProvider).scanInstalledGames();
});

final presentedGamesProvider = FutureProvider<List<Game>>((ref) async {
  final games = await ref.watch(gamesProvider.future);
  final metadata = await ref.watch(gamePresentationStoreProvider).loadAll();
  return [
    for (final game in games)
      if (metadata[game.id] case final override?)
        game.withPresentation(
          displayNameOverride: override.displayName,
          coverPath: override.coverPath,
          coverUrl: override.coverUrl,
          description: override.description,
          tags: override.tags,
          playTimeSeconds: override.playTimeSeconds,
          isFavorite: override.isFavorite,
          steamName: override.steamName,
          steamAppId: override.steamAppId,
        )
      else
        game,
  ];
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedTagProvider = StateProvider<String>((ref) => 'All');

final filteredGamesProvider = Provider<AsyncValue<List<Game>>>((ref) {
  final games = ref.watch(presentedGamesProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final selectedTag = ref.watch(selectedTagProvider).trim();

  return games.whenData((items) {
    var filtered = items;
    if (selectedTag.isNotEmpty && selectedTag.toLowerCase() != 'all') {
      final normalizedTag = selectedTag.toLowerCase();
      filtered = items.where((game) {
        final tags = game.tags.map((tag) => tag.toLowerCase());
        return tags.any(
          (tag) => tag == normalizedTag || tag.contains(normalizedTag),
        );
      }).toList();
    }

    if (query.isEmpty) {
      return [...filtered]..sort((left, right) {
        if (left.isFavorite == right.isFavorite) return 0;
        return left.isFavorite ? -1 : 1;
      });
    }

    final matches =
        filtered
            .map(
              (game) => (
                game,
                [game.displayName, ...game.tags]
                    .map((text) => _matchScore(text, query))
                    .reduce((a, b) => a < b ? a : b),
              ),
            )
            .where((entry) => entry.$2 < 1.0)
            .toList()
          ..sort((left, right) {
            if (left.$1.isFavorite != right.$1.isFavorite) {
              return left.$1.isFavorite ? -1 : 1;
            }
            return left.$2.compareTo(right.$2);
          });
    return matches.map((entry) => entry.$1).toList();
  });
});

double _matchScore(String name, String query) {
  final normalized = name.toLowerCase();
  if (normalized == query) return 0;
  if (normalized.startsWith(query)) return 0.1;
  if (normalized.contains(query)) return 0.2;

  var queryIndex = 0;
  final queryRunes = query.runes.toList();
  for (final character in normalized.runes) {
    if (character == queryRunes[queryIndex]) {
      queryIndex++;
      if (queryIndex == query.length) return 0.6;
    }
  }
  return 1.0;
}
