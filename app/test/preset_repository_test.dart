import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/data/preset_repository.dart';
import 'package:rigcanvas/src/models/rig_preset.dart';

void main() {
  late Directory temporaryDirectory;
  late JsonFilePresetRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('rigcanvas-test-');
    repository = JsonFilePresetRepository(
      directoryProvider: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('starts with an empty preset store and persists data', () async {
    expect(await repository.loadPresets(), isEmpty);

    final preset = RigPreset.starter();
    await repository.savePresets([preset]);

    final restored = await repository.loadPresets();
    expect(restored, hasLength(1));
    expect(restored.single.id, preset.id);
    expect(restored.single.name, preset.name);
    expect(restored.single.blocks.length, preset.blocks.length);
  });

  test('rejects a corrupted local preset document', () async {
    final folder = Directory('${temporaryDirectory.path}${Platform.pathSeparator}rigcanvas');
    await folder.create(recursive: true);
    final file = File('${folder.path}${Platform.pathSeparator}presets.json');
    await file.writeAsString('not-json');

    await expectLater(repository.loadPresets(), throwsFormatException);
  });
}
