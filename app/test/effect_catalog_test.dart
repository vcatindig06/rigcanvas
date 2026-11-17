import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rigcanvas/src/data/preset_repository.dart';
import 'package:rigcanvas/src/models/effect_block.dart';
import 'package:rigcanvas/src/models/effect_catalog.dart';
import 'package:rigcanvas/src/models/rig_preset.dart';
import 'package:rigcanvas/src/screens/effect_catalog_picker_dialog.dart';
import 'package:rigcanvas/src/state/preset_controller.dart';

class MemoryCatalogPresetRepository implements PresetRepository {
  List<RigPreset> stored = <RigPreset>[];

  @override
  Future<List<RigPreset>> loadPresets() async => List.of(stored);

  @override
  Future<void> savePresets(List<RigPreset> presets) async {
    stored = List.of(presets);
  }
}

void main() {
  test('catalogue IDs are unique and sources remain separate', () {
    final entries = [
      ...rigCanvasSoftwareCatalog,
      ...kptProManualCatalog,
    ];
    final ids = entries.map((entry) => entry.id).toSet();

    expect(ids.length, entries.length);
    expect(
      rigCanvasSoftwareCatalog.every(
        (entry) => entry.source == EffectCatalogSource.rigCanvasSoftware,
      ),
      isTrue,
    );
    expect(
      kptProManualCatalog.every(
        (entry) => entry.source == EffectCatalogSource.kptProManual,
      ),
      isTrue,
    );
    expect(
      kptProManualCatalog.any((entry) => entry.name == 'AI Gate'),
      isTrue,
    );
    expect(
      kptProManualCatalog.any(
        (entry) => entry.name == 'Tube Screamer-style Drive',
      ),
      isFalse,
    );
  });

  test('catalogue model identity survives preset JSON round-trip', () async {
    final repository = MemoryCatalogPresetRepository();
    final controller = PresetController(repository);
    await controller.initialize();
    addTearDown(controller.dispose);

    final entry = rigCanvasSoftwareCatalog.singleWhere(
      (entry) => entry.id == 'rigcanvas.drive.tube-screamer-style',
    );
    await controller.addCatalogBlock(entry);

    final added = controller.activePreset!.blocks.last;
    expect(added.name, 'Tube Screamer-style Drive');
    expect(added.catalogId, entry.id);
    expect(added.catalogSource, EffectCatalogSource.rigCanvasSoftware);

    final decoded = PresetCodec.decode(
      PresetCodec.encode(controller.activePreset!),
    );
    final restored = decoded.blocks.last;
    expect(restored.catalogId, entry.id);
    expect(restored.catalogSource, EffectCatalogSource.rigCanvasSoftware);
    expect(restored.name, entry.name);
  });

  testWidgets('catalogue picker searches and returns a named model', (
    tester,
  ) async {
    EffectCatalogEntry? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selected = await showDialog<EffectCatalogEntry>(
                  context: context,
                  builder: (_) => const EffectCatalogPickerDialog(),
                );
              },
              child: const Text('Open catalogue'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open catalogue'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an effect model'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('effect-catalog-search')),
      'Tube Screamer',
    );
    await tester.pumpAndSettle();
    expect(find.text('Tube Screamer-style Drive'), findsOneWidget);
    expect(find.text('Klon-style Overdrive'), findsNothing);

    await tester.tap(find.text('Tube Screamer-style Drive'));
    await tester.pumpAndSettle();
    expect(selected?.id, 'rigcanvas.drive.tube-screamer-style');
    expect(selected?.source, EffectCatalogSource.rigCanvasSoftware);
  });
}
