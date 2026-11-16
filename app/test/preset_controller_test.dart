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
  group('PresetController', () {
    late MemoryPresetRepository repository;
    late PresetController controller;

    setUp(() async {
      repository = MemoryPresetRepository();
      controller = PresetController(repository);
      await controller.initialize();
    });

    tearDown(() => controller.dispose());

    test('creates and persists a starter preset on first launch', () {
      expect(controller.presets, hasLength(1));
      expect(controller.activePreset?.name, 'Sunday Clean + Ambient');
      expect(repository.stored, hasLength(1));
    });

    test('creates, selects, duplicates and deletes presets', () async {
      await controller.createPreset(name: 'Chorus Drive');
      expect(controller.presets, hasLength(2));
      expect(controller.activePreset?.name, 'Chorus Drive');

      final duplicateId = controller.activePreset!.id;
      await controller.duplicatePreset(duplicateId);
      expect(controller.presets, hasLength(3));
      expect(controller.activePreset?.name, 'Chorus Drive Copy');

      await controller.deletePreset(controller.activePreset!.id);
      expect(controller.presets, hasLength(2));
    });

    test('updates a block and persists its parameters', () async {
      final drive = controller.activePreset!.blocks[1];
      final updated = drive.copyWith(
        parameters: {...drive.parameters, 'gain': 72},
      );

      await controller.updateBlock(updated);

      expect(controller.activePreset!.blocks[1].parameters['gain'], 72);
      expect(repository.stored.first.blocks[1].parameters['gain'], 72);
    });

    test('does not discard a preset when an imported file is invalid', () async {
      expect(
        () => controller.importPresetJson('{"format":"not-rigcanvas"}'),
        throwsFormatException,
      );
      expect(controller.presets, hasLength(1));
    });
  });
}
