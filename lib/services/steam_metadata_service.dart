import 'dart:convert';

import 'package:http/http.dart' as http;

class SteamGameMetadata {
  const SteamGameMetadata({
    required this.appId,
    required this.name,
    required this.headerImage,
  });

  final int appId;
  final String name;
  final Uri headerImage;
}

class SteamMetadataService {
  SteamMetadataService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _searchEndpoint = Uri.https(
    'store.steampowered.com',
    '/api/storesearch/',
  );

  final http.Client _client;

  Future<SteamGameMetadata?> searchGame(String query) async {
    final term = query.trim();
    if (term.isEmpty) return null;

    final searchUri = _searchEndpoint.replace(
      queryParameters: {'term': term, 'l': 'spanish', 'cc': 'ES'},
    );
    final response = await _client
        .get(searchUri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'La búsqueda de Steam respondió ${response.statusCode}',
        searchUri,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
      throw const FormatException('Respuesta de búsqueda de Steam no válida');
    }

    for (final item in decoded['items'] as List) {
      if (item is! Map<String, dynamic>) continue;
      final appId = item['id'];
      final name = item['name'];
      if (appId is! int || name is! String || name.trim().isEmpty) continue;

      final metadata = await _fetchAppDetails(appId);
      if (metadata != null) {
        return SteamGameMetadata(
          appId: appId,
          name: name.trim(),
          headerImage: metadata,
        );
      }
    }
    return null;
  }

  Future<Uri?> _fetchAppDetails(int appId) async {
    final uri = Uri.https(
      'store.steampowered.com',
      '/api/appdetails',
      {'appids': '$appId', 'l': 'spanish', 'cc': 'ES'},
    );
    final response = await _client.get(uri).timeout(
      const Duration(seconds: 15),
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Los detalles de Steam respondieron ${response.statusCode}',
        uri,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Detalles de Steam no válidos');
    }
    final app = decoded['$appId'];
    if (app is! Map<String, dynamic> || app['success'] != true) return null;
    final data = app['data'];
    if (data is! Map<String, dynamic>) return null;
    final image = data['header_image'];
    if (image is! String) return null;
    final uriValue = Uri.tryParse(image);
    if (uriValue == null || uriValue.scheme != 'https') return null;
    return uriValue;
  }

  void close() => _client.close();
}
