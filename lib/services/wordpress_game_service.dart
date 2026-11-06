import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pivi_game.dart';

class WordPressGameService {
  WordPressGameService({required String siteBaseUrl, http.Client? client})
    : _siteBaseUrl = siteBaseUrl,
      _client = client ?? http.Client();

  final String _siteBaseUrl;
  final http.Client _client;

  Future<List<PiviGame>> fetchPosts({String search = ''}) async {
    final rawSite = _siteBaseUrl.trim();
    // Steamunlocked.net redirects to steamunlocked.org
    final normalizedBase = rawSite.contains('steamunlocked.net')
        ? 'https://steamunlocked.org'
        : rawSite;

    final site = Uri.tryParse(normalizedBase);
    if (site == null || !site.hasScheme || !site.hasAuthority) {
      throw const FormatException(
        'Configura una URL válida para el sitio de juegos.',
      );
    }

    // First try HTML search if it's SteamUnlocked
    if (normalizedBase.contains('steamunlocked')) {
      final searchTerm = search.trim().isEmpty ? 'a' : search.trim();
      final searchUri = site.replace(
        path: '/',
        queryParameters: {'s': searchTerm},
      );

      try {
        final response = await _client
            .get(
              searchUri,
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              },
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final games = _parseSteamUnlockedHtml(response.body);
          if (games.isNotEmpty) return games;
        }
      } catch (_) {
        // Fall through to WP-JSON REST API attempt
      }
    }

    // WP-JSON REST API (Ideal for SteamRip, ElAmigos, or WordPress fallbacks)
    final query = <String, String>{
      'per_page': '20',
      '_embed': 'true',
      if (search.trim().isNotEmpty) 'search': search.trim(),
    };
    final apiUri = site.replace(
      path: '/wp-json/wp/v2/posts',
      queryParameters: query,
    );

    final response = await _client
        .get(
          apiUri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw http.ClientException(
        'El servidor respondió HTTP ${response.statusCode}',
        apiUri,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException(
        'La API de WordPress devolvió un formato no válido.',
      );
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PiviGame.fromJson)
        .toList(growable: false);
  }

  List<PiviGame> _parseSteamUnlockedHtml(String html) {
    final cardRegex = RegExp(
      r'<a\s+[^>]*class="[^"]*su-cat__card[^"]*"[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>',
      caseSensitive: false,
    );

    final matches = cardRegex.allMatches(html);
    final games = <PiviGame>[];

    for (final match in matches) {
      final linkStr = match.group(1) ?? '';
      final innerHtml = match.group(2) ?? '';
      final linkUri = Uri.tryParse(linkStr);
      if (linkUri == null || !linkUri.hasScheme) continue;

      final imgMatch = RegExp(
        r'<img\s+[^>]*src="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(innerHtml);
      final altMatch = RegExp(
        r'<img\s+[^>]*alt="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(innerHtml);

      final imgStr = imgMatch?.group(1);
      final featuredImgUri = imgStr != null ? Uri.tryParse(imgStr) : null;

      var rawTitle = altMatch?.group(1) ?? '';
      rawTitle = rawTitle
          .replaceAll(
            RegExp(
              r'\s*-\s*PC Game on SteamUnlocked.*$',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      rawTitle = rawTitle
          .replaceAll(
            RegExp(r'\s*Free Download.*$', caseSensitive: false),
            '',
          )
          .trim();
      final title = decodeHtmlEntities(rawTitle);

      games.add(
        PiviGame(
          title: title.isEmpty ? 'Juego sin título' : title,
          link: linkUri,
          featuredImageUrl: featuredImgUri,
        ),
      );
    }

    return games;
  }

  void close() => _client.close();
}