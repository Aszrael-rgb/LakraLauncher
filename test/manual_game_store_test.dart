import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakra_launcher/services/manual_game_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory temporaryDirectory;
  late ManualGameStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporaryDirectory = await Directory.systemTemp.createTemp('lakra-manual-');
    store = ManualGameStore();
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'persists supported games, skips duplicates, and removes entries',
    () async {
      final executable = File('${temporaryDirectory.path}/Standalone.exe');
      final shortcut = File('${temporaryDirectory.path}/Shortcut.lnk');
      final internetShortcut = File('${temporaryDirectory.path}/Web Game.url');
      final batchFile = File('${temporaryDirectory.path}/Setup.bat');
      final commandFile = File('${temporaryDirectory.path}/Launch.cmd');
      final unsupported = File('${temporaryDirectory.path}/notes.txt');
      for (final file in [
        executable,
        shortcut,
        internetShortcut,
        batchFile,
        commandFile,
        unsupported,
      ]) {
        await file.writeAsString('placeholder');
      }

      expect(
        await store.addFiles([
          executable.path,
          shortcut.path,
          internetShortcut.path,
          batchFile.path,
          commandFile.path,
          unsupported.path,
        ]),
        5,
      );
      expect(await store.addFiles([executable.path]), 0);

      final games = await store.loadGames();
      expect(games.map((game) => game.name), [
        'Standalone',
        'Shortcut',
        'Web Game',
        'Setup',
        'Launch',
      ]);
      expect(games.every((game) => game.isManual), isTrue);

      await store.remove(shortcut.path);
      expect((await store.loadGames()).map((game) => game.name), [
        'Standalone',
        'Web Game',
        'Setup',
        'Launch',
      ]);
    },
  );

  test('persists emulator and ROM as a launchable library entry', () async {
    final emulator = File('${temporaryDirectory.path}/Emulator.exe');
    final rom = File('${temporaryDirectory.path}/Game.gba');
    await emulator.writeAsString('emulator');
    await rom.writeAsString('rom');

    expect(
      await store.addEmulatedGame(
        emulatorPath: emulator.path,
        romPath: rom.path,
      ),
      isTrue,
    );
    expect(
      await store.addEmulatedGame(
        emulatorPath: emulator.path,
        romPath: rom.path,
      ),
      isFalse,
    );

    final games = await store.loadGames();
    expect(games, hasLength(1));
    expect(games.single.platform.name, 'emulator');
    expect(games.single.emulatorPath, emulator.absolute.path);
    expect(games.single.launchTarget, rom.absolute.path);
  });
}
