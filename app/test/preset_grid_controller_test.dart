import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/data/preset_repository.dart';
import 'package:rigcanvas/src/models/rig_preset.dart';
import 'package:rigcanvas/src/state/preset_controller.dart';

class MemoryPresetRepository implements PresetRepository {
  List<RigPreset> stored = <RigPreset>[];

  @override
  Future<List<RigPreset>> loadPresets() async => List.of(stored);

  @override
  Future<void> savePresets(List<RigPreset> presets) async {
    stored = List.of(presets);
  }
}

void main() {
  test('scene recall restores its saved Grid layout after a block move', () async {
    final repository = MemoryPresetRepository();
    final controller = PresetController(repository);
    await controller.initialize();
    addTearDown(controller.dispose);

    final original = controller.activePreset!;
    final firstBlockId = original.blocks.first.id;
    await controller.captureScene(name: 'Before move');
    final sceneId = controller.activePreset!.scenes.single.id;

    await controller.moveBlockToSlot(firstBlockId, 3, 7);
    expect(controller.activePreset!.grid.positionOf(firstBlockId)?.row, 3);
    expect(controller.activePreset!.grid.positionOf(firstBlockId)?.column, 7);

    await controller.applyScene(sceneId);
    expect(controller.activePreset!.grid.positionOf(firstBlockId)?.row, 0);
    expect(controller.activePreset!.grid.positionOf(firstBlockId)?.column, 0);

    final reloaded = PresetController(repository);
    await reloaded.initialize();
    addTearDown(reloaded.dispose);
    expect(reloaded.activePreset!.grid.positionOf(firstBlockId)?.row, 0);
    expect(reloaded.activePreset!.grid.positionOf(firstBlockId)?.column, 0);
  });

  test('removing a block also removes it from saved scene references', () async {
    final repository = MemoryPresetRepository();
    final controller = PresetController(repository);
    await controller.initialize();
    addTearDown(controller.dispose);

    final blockId = controller.activePreset!.blocks.first.id;
    await controller.captureScene(name: 'Before removal');
    await controller.removeBlock(blockId);

    final preset = controller.activePreset!;
    expect(preset.grid.positionOf(blockId), isNull);
    expect(preset.blocks.any((block) => block.id == blockId), isFalse);
    expect(preset.scenes.single.grid.positionOf(blockId), isNull);
    expect(preset.scenes.single.blocks.any((block) => block.id == blockId), isFalse);
  });
}
