import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/data/asset_inspector.dart';
import 'package:rigcanvas/src/data/asset_repository.dart';
import 'package:rigcanvas/src/models/rig_asset.dart';
import 'package:rigcanvas/src/state/asset_controller.dart';

class MemoryAssetRepository implements AssetRepository {
  List<RigAsset> storedAssets = <RigAsset>[];
  final Map<String, Uint8List> storedFiles = <String, Uint8List>{};

  @override
  Future<List<RigAsset>> loadAssets() async => List.of(storedAssets);

  @override
  Future<void> saveAssets(List<RigAsset> assets) async {
    storedAssets = List.of(assets);
  }

  @override
  Future<void> storeAssetFile(String filename, Uint8List bytes) async {
    storedFiles[filename] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List> readAssetFile(String filename) async {
    final bytes = storedFiles[filename];
    if (bytes == null) throw const FormatException('Missing asset file.');
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> deleteAssetFile(String filename) async {
    storedFiles.remove(filename);
  }
}

void main() {
  test('imports, updates metadata, favorites, and deletes an asset', () async {
    final repository = MemoryAssetRepository();
    final controller = AssetController(repository);
    await controller.initialize();

    final source = jsonEncode({
      'version': '0.5.4',
      'architecture': 'WaveNet',
      'config': <String, Object?>{},
      'weights': [0.1, 0.2],
    });
    final bytes = Uint8List.fromList(utf8.encode(source));
    final inspection = AssetInspector.inspect(
      kind: RigAssetKind.ampCapture,
      filename: 'clean.nam',
      bytes: bytes,
    );

    await controller.importAsset(
      kind: RigAssetKind.ampCapture,
      filename: 'clean.nam',
      bytes: bytes,
      inspection: inspection,
      title: 'Clean Capture',
      manufacturer: 'Test Maker',
      model: 'Studio Amp',
      tags: ['clean', 'worship'],
      notes: 'Main Sunday clean tone.',
    );

    expect(controller.assets, hasLength(1));
    final imported = controller.assets.single;
    expect(imported.title, 'Clean Capture');
    expect(imported.manufacturer, 'Test Maker');
    expect(repository.storedFiles, contains(imported.storedFilename));

    await controller.toggleFavorite(imported.id);
    expect(controller.assets.single.isFavorite, isTrue);

    await controller.updateMetadata(
      assetId: imported.id,
      title: 'Warm Clean',
      manufacturer: 'Test Maker',
      model: 'Studio Amp',
      tags: ['clean', 'Clean', 'ambient'],
      notes: 'Updated note.',
    );
    expect(controller.assets.single.title, 'Warm Clean');
    expect(controller.assets.single.tags, ['clean', 'ambient']);

    await controller.deleteAsset(imported.id);
    expect(controller.assets, isEmpty);
    expect(repository.storedFiles, isEmpty);
    expect(repository.storedAssets, isEmpty);
    controller.dispose();
  });

  test('rejects metadata with an empty title before writing the file', () async {
    final repository = MemoryAssetRepository();
    final controller = AssetController(repository);
    await controller.initialize();
    final bytes = Uint8List.fromList(utf8.encode('{"version":"1","architecture":"X","config":{},"weights":[]}'));
    final inspection = AssetInspector.inspect(
      kind: RigAssetKind.ampCapture,
      filename: 'capture.nam',
      bytes: bytes,
    );

    await expectLater(
      controller.importAsset(
        kind: RigAssetKind.ampCapture,
        filename: 'capture.nam',
        bytes: bytes,
        inspection: inspection,
        title: ' ',
      ),
      throwsFormatException,
    );
    expect(repository.storedFiles, isEmpty);
    expect(controller.assets, isEmpty);
    controller.dispose();
  });

  test('reads the original file bytes for a linked cabinet IR', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
    final asset = RigAsset(
      id: 'asset-cab-ir',
      title: 'Stereo Cabinet IR',
      kind: RigAssetKind.cabinetIr,
      originalFilename: 'stereo.wav',
      storedFilename: 'asset-cab-ir.wav',
      extension: '.wav',
      fileSizeBytes: bytes.length,
      importedAt: DateTime.utc(2026, 11, 16),
      validation: RigAssetValidation.validated,
      formatSummary: 'WAV PCM · stereo · 48000 Hz · 16-bit',
      sampleRateHz: 48000,
      channelCount: 2,
      bitDepth: 16,
    );
    final repository = MemoryAssetRepository()
      ..storedAssets = [asset]
      ..storedFiles[asset.storedFilename] = Uint8List.fromList(bytes);
    final controller = AssetController(repository);
    await controller.initialize();

    expect(await controller.readAssetBytes(asset.id), bytes);
    await expectLater(
      controller.readAssetBytes('missing-asset'),
      throwsFormatException,
    );
    controller.dispose();
  });

}
