import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show FilledButton, Scrollable, TextField, TextFormField;
import 'package:rigcanvas/src/app.dart';
import 'package:rigcanvas/src/data/asset_repository.dart';
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

    await tester.pumpWidget(
      RigCanvasApp(
        repository: presetRepository,
        setlistRepository: MemorySetlistRepository(),
        assetRepository: MemoryAssetRepository(assets: [capture]),
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
    await tester.tap(find.text('British Stack'));
    await tester.pumpAndSettle();

    expect(find.text('LINKED LIBRARY ASSET'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('asset-link-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Sunday Clean Capture').last);
    await tester.pumpAndSettle();

    expect(find.text('File structure checked'), findsOneWidget);
    expect(
      find.textContaining('This does not prove'),
      findsOneWidget,
    );

    final saveBeforeAcknowledgement = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    expect(saveBeforeAcknowledgement.onPressed, isNull);

    await tester.tap(
      find.text(
        'I understand this is a local reference only, not verified for playback or KPT Pro.',
      ),
    );
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
}
