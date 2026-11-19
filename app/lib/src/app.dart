import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:rigcanvas_usb_inventory/rigcanvas_usb_inventory.dart';

import 'device/kpt_pro_ble_gateway.dart';

import 'data/asset_repository.dart';
import 'data/preset_repository.dart';
import 'data/setlist_repository.dart';
import 'screens/asset_library_screen.dart';
import 'screens/gig_view_screen.dart';
import 'screens/preset_library_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/workspace_screen.dart';
import 'state/asset_controller.dart';
import 'state/preset_controller.dart';
import 'state/setlist_controller.dart';

class RigCanvasApp extends StatefulWidget {
  const RigCanvasApp({
    this.repository,
    this.setlistRepository,
    this.assetRepository,
    this.usbInventory = const UsbDeviceInventory(),
    this.hardwareGateway = const SimulationKptProHardwareGateway(),
    super.key,
  });

  final PresetRepository? repository;
  final SetlistRepository? setlistRepository;
  final AssetRepository? assetRepository;
  final UsbDeviceInventoryClient usbInventory;
  final KptProHardwareGateway hardwareGateway;

  @override
  State<RigCanvasApp> createState() => _RigCanvasAppState();
}

class _RigCanvasAppState extends State<RigCanvasApp> {
  late final PresetController _presetController;
  late final SetlistController _setlistController;
  late final AssetController _assetController;

  @override
  void initState() {
    super.initState();
    _presetController = PresetController(
      widget.repository ?? JsonFilePresetRepository(),
    );
    _setlistController = SetlistController(
      widget.setlistRepository ?? JsonFileSetlistRepository(),
    );
    _assetController = AssetController(
      widget.assetRepository ?? JsonFileAssetRepository(),
    );
    unawaited(_presetController.initialize());
    unawaited(_setlistController.initialize());
    unawaited(_assetController.initialize());
  }

  @override
  void dispose() {
    unawaited(widget.hardwareGateway.dispose());
    _presetController.dispose();
    _setlistController.dispose();
    _assetController.dispose();
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
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF11161C),
          indicatorColor: const Color(0xFF263A33),
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
            (states) => const IconThemeData(color: Color(0xFFFF7956), size: 22),
          ),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          selectedIconTheme: IconThemeData(color: Color(0xFFFF7956)),
          unselectedIconTheme: IconThemeData(color: Color(0xFFFF7956)),
        ),
      ),
      home: RigCanvasShell(
        presetController: _presetController,
        setlistController: _setlistController,
        assetController: _assetController,
        usbInventory: widget.usbInventory,
        hardwareGateway: widget.hardwareGateway,
      ),
    );
  }
}

class RigCanvasShell extends StatefulWidget {
  const RigCanvasShell({
    required this.presetController,
    required this.setlistController,
    required this.assetController,
    required this.usbInventory,
    required this.hardwareGateway,
    super.key,
  });

  final PresetController presetController;
  final SetlistController setlistController;
  final AssetController assetController;
  final UsbDeviceInventoryClient usbInventory;
  final KptProHardwareGateway hardwareGateway;

  @override
  State<RigCanvasShell> createState() => _RigCanvasShellState();
}

class _RigCanvasShellState extends State<RigCanvasShell> {
  int _selectedIndex = 0;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.queue_music), selectedIcon: Icon(Icons.queue_music), label: 'Gig'),
    NavigationDestination(icon: Icon(Icons.account_tree), selectedIcon: Icon(Icons.account_tree), label: 'Workspace'),
    NavigationDestination(icon: Icon(Icons.library_music), selectedIcon: Icon(Icons.library_music), label: 'Presets'),
    NavigationDestination(icon: Icon(Icons.folder), selectedIcon: Icon(Icons.folder), label: 'Assets'),
    NavigationDestination(icon: Icon(Icons.settings), selectedIcon: Icon(Icons.settings), label: 'Settings'),
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
          assetController: widget.assetController,
        );
      case 2:
        return PresetLibraryScreen(
          key: const ValueKey('presets'),
          controller: widget.presetController,
        );
      case 3:
        return AssetLibraryScreen(
          key: const ValueKey('assets'),
          controller: widget.assetController,
        );
      case 4:
        return SettingsScreen(
          key: const ValueKey('settings'),
          presetController: widget.presetController,
          assetController: widget.assetController,
          usbInventory: widget.usbInventory,
          hardwareGateway: widget.hardwareGateway,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: AppBar(
            leadingWidth: 44,
            leading: const Padding(
              padding: EdgeInsets.only(left: 20),
              child: Icon(Icons.graphic_eq, color: Color(0xFFFF7956)),
            ),
            titleSpacing: 8,
            title: const Text(
              'RigCanvas',
              style: TextStyle(fontWeight: FontWeight.w700),
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
