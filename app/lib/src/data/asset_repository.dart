import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/rig_asset.dart';
import 'preset_repository.dart';

abstract interface class AssetRepository {
  Future<List<RigAsset>> loadAssets();

  Future<void> saveAssets(List<RigAsset> assets);

  Future<void> storeAssetFile(String filename, Uint8List bytes);

  Future<void> deleteAssetFile(String filename);
}

class JsonFileAssetRepository implements AssetRepository {
  JsonFileAssetRepository({SupportDirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final SupportDirectoryProvider _directoryProvider;

  Future<Directory> _appDirectory() async {
    final supportDirectory = await _directoryProvider();
    final directory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}rigcanvas',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _indexFile() async {
    final directory = await _appDirectory();
    return File('${directory.path}${Platform.pathSeparator}assets.json');
  }

  Future<Directory> _assetDirectory() async {
    final directory = await _appDirectory();
    final assets = Directory(
      '${directory.path}${Platform.pathSeparator}assets',
    );
    await assets.create(recursive: true);
    return assets;
  }

  @override
  Future<List<RigAsset>> loadAssets() async {
    final file = await _indexFile();
    final backup = File('${file.path}.bak');
    final temporary = File('${file.path}.tmp');

    if (!await file.exists() && await backup.exists()) {
      await backup.rename(file.path);
    }
    if (await file.exists() && await backup.exists()) {
      await backup.delete();
    }
    if (await temporary.exists()) {
      await temporary.delete();
    }
    if (!await file.exists()) return <RigAsset>[];

    return AssetDocumentCodec.decode(await file.readAsString());
  }

  @override
  Future<void> saveAssets(List<RigAsset> assets) async {
    final file = await _indexFile();
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    final document = AssetDocumentCodec.encode(assets);

    await temporary.writeAsString(document, flush: true);
    if (await backup.exists()) await backup.delete();
    final hadOriginal = await file.exists();
    if (hadOriginal) await file.rename(backup.path);

    try {
      await temporary.rename(file.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (hadOriginal && await backup.exists() && !await file.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }

  @override
  Future<void> storeAssetFile(String filename, Uint8List bytes) async {
    _validateStorageFilename(filename);
    if (bytes.isEmpty || bytes.length > maximumAssetFileBytes) {
      throw const FormatException('Asset file size is invalid.');
    }
    final directory = await _assetDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  @override
  Future<void> deleteAssetFile(String filename) async {
    _validateStorageFilename(filename);
    final directory = await _assetDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    if (await file.exists()) await file.delete();
  }

  void _validateStorageFilename(String filename) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+[.][a-z0-9]{1,8}$').hasMatch(filename)) {
      throw const FormatException('Asset storage filename is invalid.');
    }
  }
}
