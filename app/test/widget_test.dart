import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show FilledButton, MaterialApp, NavigationBar, NavigationRail, Scaffold, Scrollable, TextField, TextFormField;
import 'package:rigcanvas/src/app.dart';
import 'package:rigcanvas/src/data/asset_repository.dart';
import 'package:rigcanvas/src/state/asset_controller.dart';
import 'package:rigcanvas/src/state/preset_controller.dart';
import 'package:rigcanvas/src/screens/workspace_screen.dart';
import 'package:rigcanvas/src/data/preset_repository.dart';
import 'package:rigcanvas/src/data/setlist_repository.dart';
import 'package:rigcanvas/src/models/effect_block.dart';
import 'package:rigcanvas/src/models/rig_asset.dart';
import 'package:rigcanvas/src/models/rig_preset.dart';
import 'package:rigcanvas/src/models/rig_setlist.dart';

class MemoryPresetRepository implements PresetRepository {
  List<RigPreset> stored = <RigPreset>[];

  @override
  Future<List<RigPreset>> loadPresets() async => List.of(stored);

  @override
  Future<void> savePresets(List<RigPreset> presets) async {
    stored = List.of(presets);
  }
}

class MemorySetlistRepository implements SetlistRepository {
  List<RigSetlist> stored = <RigSetlist>[];

  @override
  Future<List<RigSetlist>> loadSetlists() async => List.of(stored);

  @override
  Future<void> saveSetlists(List<RigSetlist> setlists) async {
    stored = List.of(setlists);
  }
}

class MemoryAssetRepository implements AssetRepository {
  MemoryAssetRepository({List<RigAsset> assets = const <RigAsset>[]})
    : stored = List.of(assets);

  List<RigAsset> stored;

  @override
  Future<List<RigAsset>> loadAssets() async => List.of(stored);

  @override
  Future<void> saveAssets(List<RigAsset> assets) async {
    stored = List.of(assets);
  }

  @override
  Future<void> storeAssetFile(String filename, Uint8List bytes) async {}

  @override
  Future<void> deleteAssetFile(String filename) async {}
}

void main() {
  testWidgets('keeps the same features available in compact and wide layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      RigCanvasApp(
        repository: MemoryPresetRepository(),
        setlistRepository: MemorySetlistRepository(),
        assetRepository: MemoryAssetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.text('Workspace'));
    await tester.pumpAndSettle();
    expect(find.text('Signal Workspace'), findsOneWidget);

    await tester.tap(find.text('Assets'));
    await tester.pumpAndSettle();
    expect(find.text('Asset Library'), findsOneWidget);

    await tester.tap(find.text('Presets'));
    await tester.pumpAndSettle();
    expect(find.text('Preset Library'), findsOneWidget);

    await tester.tap(find.text('Gig'));
    await tester.pumpAndSettle();
    expect(find.text('Gig View'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Connection preferences, audio settings, appearance, and diagnostics will live here.'), findsOneWidget);

    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Workspace'));
    await tester.pumpAndSettle();
    expect(find.text('Signal Workspace'), findsOneWidget);

    await tester.tap(find.text('Assets'));
    await tester.pumpAndSettle();
    expect(find.text('Asset Library'), findsOneWidget);

    await tester.tap(find.text('Presets'));
    await tester.pumpAndSettle();
    expect(find.text('Preset Library'), findsOneWidget);

    await tester.tap(find.text('Gig'));
    await tester.pumpAndSettle();
    expect(find.text('Gig View'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Connection preferences, audio settings, appearance, and diagnostics will live here.'), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('shows the RigCanvas local simulation workspace', (tester) async {
    await tester.pumpWidget(
      RigCanvasApp(
        repository: MemoryPresetRepository(),
        setlistRepository: MemorySetlistRepository(),
        assetRepository: MemoryAssetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workspace'));
    await tester.pumpAndSettle();

    expect(find.text('RigCanvas'), findsOneWidget);
    expect(find.text('Signal Workspace'), findsOneWidget);
    expect(find.text('GRID WORKSPACE'), findsOneWidget);
    expect(find.text('IN 1'), findsOneWidget);
    expect(find.text('OUT 4'), findsOneWidget);
    expect(find.byKey(const ValueKey('grid-slot-3-7')), findsOneWidget);
    expect(find.text('KPT Pro · Disconnected'), findsOneWidget);
    expect(find.text('SIMULATION'), findsOneWidget);
    expect(find.text('Input Gate'), findsOneWidget);
  });

  testWidgets('creates a setlist and adds a song in Gig View', (tester) async {
    await tester.pumpWidget(
      RigCanvasApp(
        repository: MemoryPresetRepository(),
        setlistRepository: MemorySetlistRepository(),
        assetRepository: MemoryAssetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gig View'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-setlist-empty')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Sunday Gathering');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Sunday Gathering'), findsOneWidget);
    await tester.tap(find.text('Add song'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Oceans');
    await tester.enterText(find.byType(TextFormField).at(1), 'D');
    await tester.tap(find.text('Save song'));
    await tester.pumpAndSettle();

    expect(find.text('Oceans'), findsOneWidget);
    expect(find.textContaining('Key D'), findsOneWidget);
  });

  testWidgets('keeps Preset, Scene, Stomp and Hybrid on one Grid', (tester) async {
    await tester.pumpWidget(
      RigCanvasApp(
        repository: MemoryPresetRepository(),
        setlistRepository: MemorySetlistRepository(),
        assetRepository: MemoryAssetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workspace'));
    await tester.pumpAndSettle();

    expect(find.text('GRID WORKSPACE'), findsOneWidget);
    expect(find.text('British Stack'), findsOneWidget);

    await tester.tap(find.text('Scene').last);
    await tester.pumpAndSettle();
    expect(find.text('SCENES · A–H'), findsOneWidget);
    expect(find.text('GRID WORKSPACE'), findsOneWidget);

    await tester.tap(find.text('Stomp').last);
    await tester.pumpAndSettle();
    expect(find.text('STOMP ASSIGNMENTS · A–H'), findsOneWidget);
    expect(find.text('GRID WORKSPACE'), findsOneWidget);

    await tester.tap(find.text('Hybrid').last);
    await tester.pumpAndSettle();
    expect(find.text('SCENES · A–D'), findsOneWidget);
    expect(find.text('STOMP ASSIGNMENTS · E–H'), findsOneWidget);
    expect(find.text('GRID WORKSPACE'), findsOneWidget);
  });

  testWidgets('adds a fixed catalog model from the searchable picker', (tester) async {
    final repository = MemoryPresetRepository();
    await tester.pumpWidget(
      RigCanvasApp(
        repository: repository,
        setlistRepository: MemorySetlistRepository(),
        assetRepository: MemoryAssetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workspace'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Add block'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add block').last);
    await tester.pumpAndSettle();

    expect(find.text('Add effect block'), findsOneWidget);
    expect(find.byKey(const ValueKey('effect-family-filter')), findsOneWidget);
    expect(find.byKey(const ValueKey('effect-model-search')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('effect-family-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drive').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('effect-model-search')),
      'Mid-Hump Overdrive',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mid-Hump Overdrive').last);
    await tester.pumpAndSettle();

    expect(find.text('Mid-Hump Overdrive'), findsOneWidget);
    final added = repository.stored.single.blocks.singleWhere(
      (block) => block.modelId == 'drive.mid_hump',
    );
    expect(added.name, 'Mid-Hump Overdrive');
    expect(added.model.source, EffectModelSource.rigcanvasExpanded);
  });

  testWidgets('edits an effect by selecting a model instead of custom naming', (tester) async {
    final repository = MemoryPresetRepository();
    await tester.pumpWidget(
      RigCanvasApp(
        repository: repository,
        setlistRepository: MemorySetlistRepository(),
        assetRepository: MemoryAssetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workspace'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('British Stack'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('British Stack'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('effect-model-change')), findsOneWidget);
    expect(find.text('Block name'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('effect-model-change')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('effect-model-search')),
      'British Modern Stack',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('British Modern Stack').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('British Modern Stack'), findsOneWidget);
    final amplifier = repository.stored.single.blocks.singleWhere(
      (block) => block.family == EffectFamily.amplifier,
    );
    expect(amplifier.modelId, 'amp.british_modern');
  });

  testWidgets('opens the local preset library', (tester) async {
    await tester.pumpWidget(
      RigCanvasApp(
        repository: MemoryPresetRepository(),
        setlistRepository: MemorySetlistRepository(),
        assetRepository: MemoryAssetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Presets'));
    await tester.pumpAndSettle();

    expect(find.text('Preset Library'), findsOneWidget);
    expect(find.text('New preset'), findsOneWidget);
  });


  testWidgets('assigns a library capture to an amplifier block with a warning', (
    tester,
  ) async {
    final capture = RigAsset(
      id: 'asset-clean-capture',
      title: 'Sunday Clean Capture',
      kind: RigAssetKind.ampCapture,
      originalFilename: 'sunday-clean.nam',
      storedFilename: 'asset-clean-capture.nam',
      extension: '.nam',
      fileSizeBytes: 64,
      importedAt: DateTime.utc(2026, 11, 16),
      validation: RigAssetValidation.validated,
      formatSummary: 'NAM JSON structure checked.',
    );
    final presetRepository = MemoryPresetRepository();
    final presetController = PresetController(presetRepository);
    final assetController = AssetController(
      MemoryAssetRepository(assets: [capture]),
    );
    await presetController.initialize();
    await assetController.initialize();
    addTearDown(presetController.dispose);
    addTearDown(assetController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceScreen(
            controller: presetController,
            assetController: assetController,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('British Stack'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('British Stack'));
    await tester.pumpAndSettle();

    expect(find.text('LINKED LIBRARY ASSET'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('asset-link-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Sunday Clean Capture').last);
    await tester.pumpAndSettle();

    expect(find.text('File structure checked'), findsOneWidget);
    expect(find.textContaining('This does not prove'), findsOneWidget);

    final saveBeforeAcknowledgement = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    expect(saveBeforeAcknowledgement.onPressed, isNull);

    final acknowledgement = find.text(
      'I understand playback and device compatibility are unverified and this only saves a local reference.',
    );
    await tester.ensureVisible(acknowledgement);
    await tester.pumpAndSettle();
    await tester.tap(acknowledgement);
    await tester.pumpAndSettle();

    final saveAfterAcknowledgement = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    expect(saveAfterAcknowledgement.onPressed, isNotNull);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final amplifier = presetRepository.stored.single.blocks.singleWhere(
      (block) => block.family == EffectFamily.amplifier,
    );
    expect(amplifier.assetId, 'asset-clean-capture');
    expect(find.textContaining('Capture: Sunday Clean Capture'), findsOneWidget);
  });


  testWidgets('assigns a cabinet IR to a cabinet block with a warning', (
    tester,
  ) async {
    final cabinetIr = RigAsset(
      id: 'asset-v30-ir',
      title: 'Vintage 30 Close Mic',
      kind: RigAssetKind.cabinetIr,
      originalFilename: 'v30.wav',
      storedFilename: 'asset-v30-ir.wav',
      extension: '.wav',
      fileSizeBytes: 512,
      importedAt: DateTime.utc(2026, 11, 16),
      validation: RigAssetValidation.validated,
      formatSummary: 'WAV PCM · mono · 48000 Hz · 24-bit · 0.25 ms',
      sampleRateHz: 48000,
      channelCount: 1,
      bitDepth: 24,
    );
    final presetRepository = MemoryPresetRepository();
    final presetController = PresetController(presetRepository);
    final assetController = AssetController(
      MemoryAssetRepository(assets: [cabinetIr]),
    );
    await presetController.initialize();
    await assetController.initialize();
    addTearDown(presetController.dispose);
    addTearDown(assetController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceScreen(
            controller: presetController,
            assetController: assetController,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('4×12 Cabinet'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('4×12 Cabinet'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('asset-link-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Vintage 30 Close Mic').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('WAV metadata detected: WAV PCM'),
      findsOneWidget,
    );
    expect(find.textContaining('no audio engine yet'), findsOneWidget);

    final saveBeforeAcknowledgement = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    expect(saveBeforeAcknowledgement.onPressed, isNull);

    final acknowledgement = find.text(
      'I understand playback and device compatibility are unverified and this only saves a local reference.',
    );
    await tester.ensureVisible(acknowledgement);
    await tester.pumpAndSettle();
    await tester.tap(acknowledgement);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final savedBlocks = presetRepository.stored.single.blocks;
    final cabinet = savedBlocks.singleWhere(
      (block) => block.family == EffectFamily.cabinet,
    );
    final amplifier = savedBlocks.singleWhere(
      (block) => block.family == EffectFamily.amplifier,
    );
    expect(cabinet.assetId, 'asset-v30-ir');
    expect(amplifier.assetId, isNull);
  });

  testWidgets('requires clearing a missing or wrong-family asset reference', (
    tester,
  ) async {
    final wrongFamilyIr = RigAsset(
      id: 'asset-cabinet-ir',
      title: 'Cabinet IR Not For Amp',
      kind: RigAssetKind.cabinetIr,
      originalFilename: 'cabinet.wav',
      storedFilename: 'asset-cabinet-ir.wav',
      extension: '.wav',
      fileSizeBytes: 512,
      importedAt: DateTime.utc(2026, 11, 16),
      validation: RigAssetValidation.validated,
      formatSummary: 'WAV PCM · mono · 48000 Hz · 24-bit',
      sampleRateHz: 48000,
      channelCount: 1,
      bitDepth: 24,
    );
    final presetRepository = MemoryPresetRepository();
    final presetController = PresetController(presetRepository);
    final assetController = AssetController(
      MemoryAssetRepository(assets: [wrongFamilyIr]),
    );
    await presetController.initialize();
    await assetController.initialize();
    addTearDown(presetController.dispose);
    addTearDown(assetController.dispose);

    final amplifier = presetController.activePreset!.blocks.singleWhere(
      (block) => block.family == EffectFamily.amplifier,
    );
    await presetController.updateBlock(
      amplifier.copyWith(assetId: wrongFamilyIr.id),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceScreen(
            controller: presetController,
            assetController: assetController,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('British Stack'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('British Stack'));
    await tester.pumpAndSettle();

    expect(find.text('Missing asset reference'), findsOneWidget);
    expect(
      find.textContaining('Linked asset missing or incompatible with this block'),
      findsOneWidget,
    );
    final saveWithInvalidReference = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    expect(saveWithInvalidReference.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('asset-link-dropdown')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Cabinet IR Not For Amp'),
      findsNothing,
    );
    await tester.tap(find.text('No asset linked').last);
    await tester.pumpAndSettle();

    final saveAfterClearing = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    expect(saveAfterClearing.onPressed, isNotNull);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final savedAmplifier = presetRepository.stored.single.blocks.singleWhere(
      (block) => block.family == EffectFamily.amplifier,
    );
    expect(savedAmplifier.assetId, isNull);
  });

  testWidgets('opens the functional local asset library', (tester) async {
    await tester.pumpWidget(
      RigCanvasApp(
        repository: MemoryPresetRepository(),
        setlistRepository: MemorySetlistRepository(),
        assetRepository: MemoryAssetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assets'));
    await tester.pumpAndSettle();

    expect(find.text('Asset Library'), findsOneWidget);
    expect(find.text('Import capture'), findsOneWidget);
    expect(find.text('Import cabinet IR'), findsOneWidget);
    expect(find.textContaining('AM2/AMP files are preserved unchanged'), findsOneWidget);
  });
  testWidgets('runs the shared native DSP test signal from Audio on both layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      RigCanvasApp(
        repository: MemoryPresetRepository(),
        setlistRepository: MemorySetlistRepository(),
        assetRepository: MemoryAssetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();

    expect(find.text('Software Audio Engine'), findsOneWidget);
    expect(find.text('Shared native DSP core · Android + Windows'), findsOneWidget);
    expect(find.byKey(const ValueKey('run-dsp-test')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('run-dsp-test')));
    await tester.pumpAndSettle();

    expect(find.text('DSP TEST COMPLETE'), findsOneWidget);
    expect(find.text('Processed frames'), findsOneWidget);
    expect(find.textContaining('generated inside the engine'), findsOneWidget);
    expect(find.textContaining('DSP test failed'), findsNothing);
  });

}
