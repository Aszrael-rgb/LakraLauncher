import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/launcher_settings_provider.dart';
import 'widgets/launcher_home_page.dart';

class LakraBackgroundRuntime extends ConsumerStatefulWidget {
  const LakraBackgroundRuntime({super.key});

  @override
  ConsumerState<LakraBackgroundRuntime> createState() =>
      _LakraBackgroundRuntimeState();
}

class _LakraBackgroundRuntimeState extends ConsumerState<LakraBackgroundRuntime>
    with TrayListener, WindowListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeRuntime());
    });
  }

  Future<void> _initializeRuntime() async {
    try {
      await ref.read(launcherSettingsProvider.future);
    } catch (error) {
      debugPrint('No se pudieron cargar los ajustes de inicio: $error');
    }
    try {
      await trayManager.setIcon('windows/runner/resources/app_icon.ico');
      await trayManager.setToolTip('Lakra Launcher');
      await trayManager.setContextMenu(
        Menu(
          items: [MenuItem(key: 'exit', label: 'Salir')],
        ),
      );
    } catch (error) {
      debugPrint('No se pudo inicializar el icono de bandeja: $error');
    }
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onWindowClose() {
    unawaited(windowManager.hide());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'exit') unawaited(windowManager.destroy());
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lakra Launcher',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF070A12),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00F2FE),
        secondary: Color(0xFFFFB703),
        surface: Color(0xFF0C101D),
      ),
      fontFamily: 'Segoe UI',
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFF00F2FE),
        selectionColor: Color(0x6600F2FE),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF161E31),
      ),
    ),
    home: const LauncherHomePage(),
  );
}
