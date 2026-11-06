import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lakra_launcher/services/game_presentation_store.dart';
import 'package:lakra_launcher/services/steam_metadata_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SteamMetadataService', () {
    test('searches Steam Store and returns the official header image', () async {
      final requests = <Uri>[];
      final service = SteamMetadataService(
        client: MockClient((request) async {
          requests.add(request.url);
          if (request.url.path == '/api/storesearch/') {
            return http.Response(
              jsonEncode({
                'items': [
                  {'id': 570, 'name': 'Dota 2'},
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              '570': {
                'success': true,
                'data': {
                  'header_image':
                      'https://cdn.akamai.steamstatic.com/store/apps/570/header.jpg',
                },
              },
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);

      final result = await service.searchGame(' Dota 2 ');

      expect(result?.appId, 570);
      expect(result?.name, 'Dota 2');
      expect(
        result?.headerImage.toString(),
        'https://cdn.akamai.steamstatic.com/store/apps/570/header.jpg',
      );
      expect(requests, hasLength(2));
      expect(requests.first.host, 'store.steampowered.com');
      expect(requests.first.path, '/api/storesearch/');
      expect(requests.first.queryParameters, {
        'term': 'Dota 2',
        'l': 'spanish',
        'cc': 'ES',
      });
      expect(requests.last.path, '/api/appdetails');
    });

    test(
      'skips invalid search results and games without a header image',
      () async {
        final service = SteamMetadataService(
          client: MockClient((request) async {
            if (request.url.path == '/api/storesearch/') {
              return http.Response(
                jsonEncode({
                  'items': [
                    {'id': 'invalid', 'name': 'Invalid ID'},
                    {'id': 1, 'name': 'No header'},
                    {'id': 2, 'name': 'Valid game'},
                  ],
                }),
                200,
              );
            }
            if (request.url.queryParameters['appids'] == '1') {
              return http.Response(
                jsonEncode({
                  '1': {'success': true, 'data': {}},
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                '2': {
                  'success': true,
                  'data': {
                    'header_image': 'https://cdn.steamstatic.com/header.jpg',
                  },
                },
              }),
              200,
            );
          }),
        );
        addTearDown(service.close);

        final result = await service.searchGame('Valid game');

        expect(result?.appId, 2);
        expect(result?.name, 'Valid game');
      },
    );

    test(
      'returns no match for an empty search without making a request',
      () async {
        var requestCount = 0;
        final service = SteamMetadataService(
          client: MockClient((_) async {
            requestCount++;
            return http.Response('{}', 200);
          }),
        );
        addTearDown(service.close);

        expect(await service.searchGame('  '), isNull);
        expect(requestCount, 0);
      },
    );

    test('reports unsuccessful HTTP responses', () async {
      final service = SteamMetadataService(
        client: MockClient((_) async => http.Response('Unavailable', 503)),
      );
      addTearDown(service.close);

      expect(
        () => service.searchGame('Dota 2'),
        throwsA(isA<http.ClientException>()),
      );
    });
  });

  test(
    'persists Steam metadata without replacing a custom display name',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = GamePresentationStore();

      await store.setDisplayName('custom:game', 'My custom title');
      await store.setSteamMetadata(
        'custom:game',
        steamName: 'Steam title',
        steamAppId: 42,
        coverUrl: 'https://cdn.steamstatic.com/header.jpg',
      );

      final saved = (await store.loadAll())['custom:game'];
      expect(saved?.displayName, 'My custom title');
      expect(saved?.steamName, 'Steam title');
      expect(saved?.steamAppId, 42);
      expect(saved?.coverUrl, 'https://cdn.steamstatic.com/header.jpg');
    },
  );
}
