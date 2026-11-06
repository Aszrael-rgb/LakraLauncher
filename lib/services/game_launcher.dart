import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../models/game.dart';

class GameLauncher {
  Future<void> launch(Game game) async {
    switch (game.platform) {
      case GamePlatform.steam:
        await _launchUri(Uri.parse('steam://rungameid/${game.launchTarget}'));
      case GamePlatform.epic:
        final appName = Uri.encodeComponent(game.launchTarget);
        await _launchUri(
          Uri.parse(
            'com.epicgames.launcher://apps/$appName?action=launch&silent=true',
          ),
        );
      case GamePlatform.ea:
      case GamePlatform.gog:
      case GamePlatform.battleNet:
      case GamePlatform.rockstar:
        await _launchCustom(game.launchTarget);
      case GamePlatform.custom:
        await _launchCustom(game.launchTarget);
      case GamePlatform.emulator:
        await _launchEmulator(game);
    }
  }

  Future<void> _launchUri(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) throw StateError('Windows no pudo abrir $uri');
  }

  Future<void> _launchCustom(String target) async {
    final file = File(target);
    if (!await file.exists()) {
      throw FileSystemException('No existe el juego', target);
    }

    final extension = target.split('.').last.toLowerCase();
    if (extension == 'lnk' ||
        extension == 'url' ||
        extension == 'bat' ||
        extension == 'cmd') {
      await _launchUri(Uri.file(file.absolute.path));
      return;
    }

    await Process.start(
      file.absolute.path,
      const [],
      workingDirectory: file.parent.path,
      mode: ProcessStartMode.detached,
    );
  }

  Future<void> _launchEmulator(Game game) async {
    final emulatorPath = game.emulatorPath;
    if (emulatorPath == null || !await File(emulatorPath).exists()) {
      throw FileSystemException('No se encuentra el emulador', emulatorPath);
    }
    if (!await File(game.launchTarget).exists()) {
      throw FileSystemException('No se encuentra la ROM', game.launchTarget);
    }

    final arguments = _parseArguments(
      game.emulatorArguments,
      game.launchTarget,
    );
    if (!arguments.contains(game.launchTarget)) {
      arguments.add(game.launchTarget);
    }
    await Process.start(
      emulatorPath,
      arguments,
      workingDirectory: File(emulatorPath).parent.path,
      mode: ProcessStartMode.detached,
    );
  }

  List<String> _parseArguments(String template, String romPath) {
    final arguments = <String>[];
    final matches = RegExp(r'"([^"]*)"|(\S+)').allMatches(template);
    for (final match in matches) {
      final value = (match.group(1) ?? match.group(2) ?? '').replaceAll(
        '{rom}',
        romPath,
      );
      if (value.isNotEmpty) arguments.add(value);
    }
    return arguments;
  }
}
