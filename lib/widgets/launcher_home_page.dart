import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../models/game.dart';
import '../providers/launcher_settings_provider.dart';
import '../providers/library_providers.dart';
import 'neon_cover.dart';

const _background = Color(0xFF070A12);
const _panel = Color(0xFF0C101D);
const _panelBorder = Color(0xFF161E31);
const _cyan = Color(0xFF00F2FE);
const _gold = Color(0xFFFFB703);
const _muted = Color(0xFF9CA3AF);

class LauncherHomePage extends ConsumerStatefulWidget {
  const LauncherHomePage({super.key});

  @override
  ConsumerState<LauncherHomePage> createState() => _LauncherHomePageState();
}

class _LauncherHomePageState extends ConsumerState<LauncherHomePage> {
  static const _sources = ['TODO', 'STEAM RIP', 'PIVIGAMES', 'ELAMIGOS'];
  static const _defaultGenres = ['Acción', 'Aventura', 'Estrategia'];
  String _selectedSource = 'TODO';
  String _selectedSection = 'GAME MARKET';
  bool _listView = false;
  bool _maximized = false;

  @override
  Widget build(BuildContext context) {
    final gamesState = ref.watch(filteredGamesProvider);
    ref.watch(presentedGamesProvider);
    final selectedTag = ref.watch(selectedTagProvider);

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _panelBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x6600F2FE),
                  blurRadius: 32,
                  spreadRadius: -26,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildSourceFilters(),
                            Expanded(
                              child: gamesState.when(
                                loading: () => const Center(
                                  child: CircularProgressIndicator(
                                    color: _cyan,
                                  ),
                                ),
                                error: (error, stack) => _ErrorPanel(
                                  message:
                                      'No se pudo cargar la biblioteca: $error',
                                  onRetry: () =>
                                      ref.invalidate(presentedGamesProvider),
                                ),
                                data: _buildGameGrid,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildSidebar(selectedTag),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _panelBorder)),
      ),
      child: DragToMoveArea(
        child: Row(
          children: [
            const _BrandMark(),
            const SizedBox(width: 50),
            _navButton('MI BIBLIOTECA'),
            const SizedBox(width: 12),
            _navButton('GAME MARKET'),
            const SizedBox(width: 12),
            _navButton('AJUSTES'),
            const Spacer(),
            _WindowButton(
              icon: Icons.minimize_rounded,
              tooltip: 'Minimizar',
              onPressed: () => windowManager.minimize(),
            ),
            const SizedBox(width: 7),
            _WindowButton(
              icon: _maximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              tooltip: _maximized ? 'Restaurar' : 'Maximizar',
              onPressed: _toggleMaximized,
            ),
            const SizedBox(width: 7),
            _WindowButton(
              icon: Icons.close_rounded,
              tooltip: 'Ocultar',
              isClose: true,
              onPressed: () => windowManager.hide(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navButton(String label) {
    final active = _selectedSection == label;
    return _ActionButton(
      label: label,
      selected: active,
      onPressed: () => setState(() => _selectedSection = label),
      compact: true,
    );
  }

  Future<void> _toggleMaximized() async {
    if (_maximized) {
      await windowManager.restore();
    } else {
      await windowManager.maximize();
    }
    if (mounted) setState(() => _maximized = !_maximized);
  }

  Widget _buildSourceFilters() {
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Row(
          children: [
            Text(
              'FUENTES',
              style: _eyebrowStyle.copyWith(color: _muted, fontSize: 10),
            ),
            const SizedBox(width: 18),
            for (final source in _sources) ...[
              _SourceChip(
                label: source,
                selected: source == _selectedSource,
                accent: source == 'PIVIGAMES' || source == 'ELAMIGOS'
                    ? _gold
                    : _cyan,
                onPressed: () => setState(() => _selectedSource = source),
              ),
              const SizedBox(width: 9),
            ],
            const Spacer(),
            Text(
              _selectedSection == 'AJUSTES'
                  ? 'PREFERENCIAS'
                  : _selectedSection == 'MI BIBLIOTECA'
                  ? 'TU COLECCIÓN'
                  : 'CATÁLOGO DE JUEGOS',
              style: _eyebrowStyle.copyWith(color: _muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameGrid(List<Game> filteredGames) {
    if (_selectedSection == 'AJUSTES') return _buildSettings();

    final games = _filterBySource(filteredGames);
    if (games.isEmpty) {
      return _EmptyGames(
        hasFilter:
            _selectedSource != 'TODO' ||
            ref.read(searchQueryProvider).trim().isNotEmpty ||
            ref.read(selectedTagProvider) != 'All',
        onClear: () {
          setState(() => _selectedSource = 'TODO');
          ref.read(searchQueryProvider.notifier).state = '';
          ref.read(selectedTagProvider.notifier).state = 'All';
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _listView
            ? 1
            : constraints.maxWidth > 1050
            ? 4
            : constraints.maxWidth > 680
            ? 3
            : 2;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: GridView.builder(
            key: ValueKey('${_listView}_$columns'),
            padding: const EdgeInsets.fromLTRB(25, 4, 25, 26),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 18,
              mainAxisSpacing: 24,
              mainAxisExtent: _listView ? 142 : 320,
            ),
            itemCount: games.length,
            itemBuilder: (context, index) => _GameCard(
              game: games[index],
              accent: _gameAccent(games[index]),
              listView: _listView,
              onDetails: () => _showGameDetails(games[index]),
              onLaunch: () => _launchGame(games[index]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebar(String selectedTag) {
    return Container(
      width: 286,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _panelBorder)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 25, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(label: 'BÚSQUEDA REACTIVA'),
            const SizedBox(height: 13),
            TextField(
              onChanged: (value) =>
                  ref.read(searchQueryProvider.notifier).state = value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Búsqueda reactiva',
                hintStyle: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                ),
                suffixIcon: const Icon(
                  Icons.search_rounded,
                  color: _cyan,
                  size: 19,
                ),
                filled: true,
                fillColor: const Color(0xFF080C16),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(color: _cyan.withValues(alpha: 0.48)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: const BorderSide(color: _cyan, width: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const _SectionHeading(label: 'GÉNEROS'),
            const SizedBox(height: 13),
            Wrap(
              spacing: 7,
              runSpacing: 8,
              children: [
                for (final genre in _availableGenres(
                  ref.read(presentedGamesProvider).valueOrNull ?? const [],
                ))
                  _GenreChip(
                    label: genre,
                    selected: selectedTag.toLowerCase() == genre.toLowerCase(),
                    onPressed: () {
                      ref.read(selectedTagProvider.notifier).state =
                          selectedTag.toLowerCase() == genre.toLowerCase()
                          ? 'All'
                          : genre;
                    },
                  ),
              ],
            ),
            const SizedBox(height: 30),
            const _SectionHeading(label: 'DISEÑO VISUAL'),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _ViewModeButton(
                    label: 'Cuadrícula',
                    icon: Icons.grid_view_rounded,
                    selected: !_listView,
                    onPressed: () => setState(() => _listView = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ViewModeButton(
                    label: 'Lista',
                    icon: Icons.view_list_rounded,
                    selected: _listView,
                    onPressed: () => setState(() => _listView = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const _SectionHeading(label: 'PLATAFORMAS'),
            const SizedBox(height: 13),
            _PlatformLegend(label: 'Steam', accent: _cyan),
            const SizedBox(height: 9),
            _PlatformLegend(label: 'Otras plataformas', accent: _gold),
          ],
        ),
      ),
    );
  }

  Widget _buildSettings() {
    final settings = ref.watch(launcherSettingsProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E19),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _panelBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AJUSTES DEL LAUNCHER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Personaliza el comportamiento de Lakra Launcher.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              settings.when(
                loading: () => const LinearProgressIndicator(color: _cyan),
                error: (error, stack) => _ErrorPanel(
                  message: 'No se pudieron cargar los ajustes: $error',
                  onRetry: () => ref.invalidate(launcherSettingsProvider),
                  compact: true,
                ),
                data: (value) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Iniciar con Windows',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Abrir Lakra al iniciar sesión.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  value: value.launchAtStartup,
                  activeThumbColor: _cyan,
                  onChanged: (enabled) async {
                    try {
                      await ref
                          .read(launcherSettingsProvider.notifier)
                          .setLaunchAtStartup(enabled);
                    } catch (error) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No se pudo guardar el ajuste: $error'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Game> _filterBySource(List<Game> games) {
    if (_selectedSource == 'TODO') return games;
    final source = _selectedSource.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return games
        .where((game) {
          return game.tags.any(
            (tag) => tag
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]'), '')
                .contains(source),
          );
        })
        .toList(growable: false);
  }

  List<String> _availableGenres(List<Game> games) {
    final tags =
        games
            .expand((game) => game.tags)
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final genres = tags
        .where(
          (tag) => !const {
            'steamrip',
            'pivigames',
            'elamigos',
          }.contains(tag.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')),
        )
        .toList();
    return genres.isEmpty ? _defaultGenres : genres.take(12).toList();
  }

  Color _gameAccent(Game game) =>
      game.platform == GamePlatform.steam ? _cyan : _gold;

  Future<void> _showGameDetails(Game game) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF0C101D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _panelBorder),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.displayName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  game.description.isEmpty
                      ? 'Sin descripción disponible.'
                      : game.description,
                  style: const TextStyle(color: _muted, height: 1.5),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _TagPill(label: game.platform.label),
                    for (final tag in game.tags) _TagPill(label: tag),
                  ],
                ),
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerRight,
                  child: _ActionButton(
                    label: 'CERRAR',
                    onPressed: () => Navigator.pop(dialogContext),
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchGame(Game game) async {
    try {
      await ref.read(gameLauncherProvider).launch(game);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo iniciar ${game.displayName}: $error'),
          ),
        );
      }
    }
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 173,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'LAKRA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            height: 0.95,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
            shadows: [Shadow(color: _cyan, blurRadius: 15)],
          ),
        ),
        SizedBox(height: 5),
        Text(
          'LAUNCHER',
          style: TextStyle(
            color: _gold,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 4.2,
            shadows: [Shadow(color: _gold, blurRadius: 9)],
          ),
        ),
      ],
    ),
  );
}

class _GameCard extends StatefulWidget {
  const _GameCard({
    required this.game,
    required this.accent,
    required this.listView,
    required this.onDetails,
    required this.onLaunch,
  });

  final Game game;
  final Color accent;
  final bool listView;
  final VoidCallback onDetails;
  final VoidCallback onLaunch;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E19),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _hovered ? widget.accent : _panelBorder),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.2),
                    blurRadius: 20,
                  ),
                ]
              : const [],
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.listView ? _buildListCard(game) : _buildGridCard(game),
      ),
    );
  }

  Widget _buildGridCard(Game game) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AnimatedScale(
              scale: _hovered ? 1.04 : 1,
              duration: const Duration(milliseconds: 300),
              child: NeonCover(
                accent: widget.accent,
                glowRadius: _hovered ? 22 : 14,
                child: _GameArtwork(game: game, accent: widget.accent),
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: Text(
                  game.displayName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.55,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              _SourceBadge(
                label: game.platform.label.toUpperCase(),
                accent: widget.accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 22,
            child: game.tags.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'JUEGO INSTALADO',
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                  )
                : ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final tag in game.tags.take(4)) ...[
                        _TagPill(label: tag),
                        const SizedBox(width: 5),
                      ],
                    ],
                  ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  label: 'VER DETALLES',
                  onPressed: widget.onDetails,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardAction(
                  label: 'INICIAR',
                  filled: true,
                  onPressed: widget.onLaunch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(Game game) {
    return Row(
      children: [
        SizedBox(
          width: 174,
          height: double.infinity,
          child: NeonCover(
            accent: widget.accent,
            borderRadius: 0,
            glowRadius: _hovered ? 20 : 10,
            child: _GameArtwork(game: game, accent: widget.accent),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                game.displayName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                children: [
                  _SourceBadge(
                    label: game.platform.label.toUpperCase(),
                    accent: widget.accent,
                  ),
                  for (final tag in game.tags.take(3)) _TagPill(label: tag),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _CardAction(label: 'DETALLES', onPressed: widget.onDetails),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _CardAction(
            label: 'INICIAR',
            filled: true,
            onPressed: widget.onLaunch,
          ),
        ),
      ],
    );
  }
}

class _GameArtwork extends StatelessWidget {
  const _GameArtwork({required this.game, required this.accent});

  final Game game;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final localPath = game.coverPath;
    final imageUrl = game.automaticCoverUrl;
    Widget image;
    if (localPath != null && localPath.isNotEmpty) {
      image = Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _ArtworkFallback(game: game, accent: accent),
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      image = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _ArtworkFallback(game: game, accent: accent),
      );
    } else {
      image = _ArtworkFallback(game: game, accent: accent);
    }
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xAA050812)],
                stops: [0.35, 1],
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: Text(
              game.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black, blurRadius: 8)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.game, required this.accent});

  final Game game;
  final Color accent;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.22),
          const Color(0xFF151B2A),
          const Color(0xFF080B14),
        ],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.sports_esports_rounded,
        color: accent.withValues(alpha: 0.68),
        size: 42,
      ),
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(compact ? 8 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: _gold, size: 30),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 14),
          _ActionButton(label: 'REINTENTAR', onPressed: onRetry, compact: true),
        ],
      ),
    ),
  );
}

class _EmptyGames extends StatelessWidget {
  const _EmptyGames({required this.hasFilter, required this.onClear});

  final bool hasFilter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videogame_asset_off_rounded, color: _cyan, size: 42),
          const SizedBox(height: 14),
          Text(
            hasFilter
                ? 'NO HAY JUEGOS PARA ESTE FILTRO'
                : 'TU BIBLIOTECA ESTÁ VACÍA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Los juegos instalados aparecerán aquí automáticamente.',
            style: TextStyle(color: _muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          if (hasFilter) ...[
            const SizedBox(height: 16),
            _ActionButton(
              label: 'LIMPIAR FILTROS',
              onPressed: onClear,
              compact: true,
            ),
          ],
        ],
      ),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? _cyan.withValues(alpha: 0.12) : Colors.transparent,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: compact ? 35 : 40,
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: selected ? Border.all(color: _cyan) : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _cyan.withValues(alpha: 0.25),
                    blurRadius: 13,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    ),
  );
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 31,
        height: 30,
        decoration: BoxDecoration(
          color: isClose ? const Color(0xFF2A101A) : const Color(0xFF141A28),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 15,
          color: isClose ? const Color(0xFFFF667D) : _muted,
        ),
      ),
    ),
  );
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? accent.withValues(alpha: 0.1) : const Color(0xFF1E293B),
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? accent : const Color(0xFF303A4D),
            width: selected ? 1.3 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 11,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: _eyebrowStyle.copyWith(color: Colors.white, fontSize: 10),
  );
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(11),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: selected
            ? _cyan.withValues(alpha: 0.08)
            : const Color(0xFF0A0E19),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: selected ? _cyan : _panelBorder),
        boxShadow: selected
            ? [BoxShadow(color: _cyan.withValues(alpha: 0.18), blurRadius: 12)]
            : null,
      ),
      child: Column(
        children: [
          Icon(icon, color: selected ? _cyan : _muted, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    ),
  );
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? _cyan.withValues(alpha: 0.12)
            : const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? _cyan : Colors.transparent),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? _cyan : const Color(0xFFD1D5DB),
          fontSize: 10,
        ),
      ),
    ),
  );
}

class _PlatformLegend extends StatelessWidget {
  const _PlatformLegend({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
      ),
      const SizedBox(width: 9),
      Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
    ],
  );
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: accent.withValues(alpha: 0.65)),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: accent,
        fontSize: 8,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    ),
  );
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF1F2937),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 9),
    ),
  );
}

const _eyebrowStyle = TextStyle(
  fontWeight: FontWeight.w800,
  letterSpacing: 1.2,
);

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 31,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: filled
            ? _cyan.withValues(alpha: 0.2)
            : Colors.transparent,
        foregroundColor: filled ? Colors.white : _cyan,
        side: const BorderSide(color: _cyan, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 31),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}
