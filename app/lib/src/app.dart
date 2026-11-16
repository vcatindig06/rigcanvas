import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'data/preset_repository.dart';
import 'data/setlist_repository.dart';
import 'screens/feature_placeholder_screen.dart';
import 'screens/gig_view_screen.dart';
import 'screens/preset_library_screen.dart';
import 'screens/workspace_screen.dart';
import 'state/preset_controller.dart';
import 'state/setlist_controller.dart';

class RigCanvasApp extends StatefulWidget {
  const RigCanvasApp({
    this.repository,
    this.setlistRepository,
    super.key,
  });

  final PresetRepository? repository;
  final SetlistRepository? setlistRepository;

  @override
  State<RigCanvasApp> createState() => _RigCanvasAppState();
}

class _RigCanvasAppState extends State<RigCanvasApp> {
  late final PresetController _presetController;
  late final SetlistController _setlistController;

  @override
  void initState() {
    super.initState();
    _presetController = PresetController(
      widget.repository ?? JsonFilePresetRepository(),
    );
    _setlistController = SetlistController(
      widget.setlistRepository ?? JsonFileSetlistRepository(),
    );
    unawaited(_presetController.initialize());
    unawaited(_setlistController.initialize());
  }

  @override
  void dispose() {
    _presetController.dispose();
    _setlistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF7956);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'RigCanvas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF0B0D10),
        cardTheme: CardThemeData(
          color: const Color(0xFF15191F),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF292F38)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0D10),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
      ),
      home: RigCanvasShell(
        presetController: _presetController,
        setlistController: _setlistController,
      ),
    );
  }
}

class RigCanvasShell extends StatefulWidget {
  const RigCanvasShell({
    required this.presetController,
    required this.setlistController,
    super.key,
  });

  final PresetController presetController;
  final SetlistController setlistController;

  @override
  State<RigCanvasShell> createState() => _RigCanvasShellState();
}

class _RigCanvasShellState extends State<RigCanvasShell> {
  int _selectedIndex = 0;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.queue_music_outlined),
      selectedIcon: Icon(Icons.queue_music),
      label: 'Gig',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_tree_outlined),
      selectedIcon: Icon(Icons.account_tree),
      label: 'Workspace',
    ),
    NavigationDestination(
      icon: Icon(Icons.library_music_outlined),
      selectedIcon: Icon(Icons.library_music),
      label: 'Presets',
    ),
    NavigationDestination(
      icon: Icon(Icons.folder_open_outlined),
      selectedIcon: Icon(Icons.folder_open),
      label: 'Assets',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  Widget _pageForIndex() {
    switch (_selectedIndex) {
      case 0:
        return GigViewScreen(
          key: const ValueKey('gig'),
          controller: widget.setlistController,
          presetController: widget.presetController,
        );
      case 1:
        return WorkspaceScreen(
          key: const ValueKey('workspace'),
          controller: widget.presetController,
        );
      case 2:
        return PresetLibraryScreen(
          key: const ValueKey('presets'),
          controller: widget.presetController,
        );
      case 3:
        return const FeaturePlaceholderScreen(
          key: ValueKey('assets'),
          title: 'Asset Library',
          description:
              'Manage compatible AMP/AM2 captures and cabinet IR files. Compatibility checks will be added before import.',
          icon: Icons.folder_open_outlined,
        );
      default:
        return const FeaturePlaceholderScreen(
          key: ValueKey('settings'),
          title: 'Settings',
          description:
              'Connection preferences, audio settings, appearance, and diagnostics will live here.',
          icon: Icons.settings_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 20,
            title: Row(
              children: [
                const Icon(Icons.graphic_eq, color: Color(0xFFFF7956)),
                const SizedBox(width: 10),
                const Text(
                  'RigCanvas',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 14),
                if (isWide)
                  const Text(
                    'GUITAR RIG WORKSPACE',
                    style: TextStyle(
                      color: Color(0xFF8993A1),
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16),
                child: _ConnectionStatus(),
              ),
            ],
          ),
          body: Row(
            children: [
              if (isWide) ...[
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: _destinations
                      .map(
                        (destination) => NavigationRailDestination(
                          icon: destination.icon,
                          selectedIcon: destination.selectedIcon,
                          label: Text(destination.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1, color: Color(0xFF252B34)),
              ],
              Expanded(
                child: SafeArea(
                  top: false,
                  child: _pageForIndex(),
                ),
              ),
            ],
          ),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  destinations: _destinations,
                ),
        );
      },
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF251A18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF63372D)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off, size: 14, color: Color(0xFFFF987B)),
          SizedBox(width: 7),
          Text(
            'KPT Pro · Disconnected',
            style: TextStyle(
              color: Color(0xFFFFB29D),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
