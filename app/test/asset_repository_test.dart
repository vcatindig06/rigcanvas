import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/data/asset_repository.dart';
import 'package:rigcanvas/src/models/rig_asset.dart';

void main() {
  late Directory temporaryDirectory;
  late JsonFileAssetRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('rigcanvas-assets-');
    repository = JsonFileAssetRepository(
      directoryProvider: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('persists asset metadata and copies the original file bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    final asset = RigAsset(
      id: 'asset-test',
      title: 'Test Capture',
      kind: RigAssetKind.ampCapture,
      originalFilename: 'capture.am2',
      storedFilename: 'asset-test.am2',
      extension: '.am2',
      fileSizeBytes: bytes.length,
      importedAt: DateTime.utc(2026, 1, 1),
      validation: RigAssetValidation.unverified,
      formatSummary: 'Stored unchanged · unverified.',
    );

    await repository.storeAssetFile(asset.storedFilename, bytes);
    await repository.saveAssets([asset]);

    final restored = await repository.loadAssets();
    expect(restored, hasLength(1));
    expect(restored.single.title, 'Test Capture');

    final storedFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}rigcanvas'
      '${Platform.pathSeparator}assets${Platform.pathSeparator}asset-test.am2',
    );
    expect(await storedFile.readAsBytes(), bytes);
    expect(await repository.readAssetFile(asset.storedFilename), bytes);

    await repository.deleteAssetFile(asset.storedFilename);
    expect(await storedFile.exists(), isFalse);
  });

  test('rejects storage filenames that could escape the asset directory', () async {
    await expectLater(
      repository.storeAssetFile('../outside.wav', Uint8List.fromList([1])),
      throwsFormatException,
    );
  });
}
