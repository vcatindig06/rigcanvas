import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../data/asset_inspector.dart';
import '../data/asset_repository.dart';
import '../models/rig_asset.dart';

class AssetController extends ChangeNotifier {
  AssetController(this._repository);

  final AssetRepository _repository;

  List<RigAsset> _assets = <RigAsset>[];
  bool _isLoading = true;
  String? _errorMessage;

  List<RigAsset> get assets => List.unmodifiable(_assets);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _assets = await _repository.loadAssets();
    } catch (error) {
      _assets = <RigAsset>[];
      _errorMessage = 'Unable to load the local asset library: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> importAsset({
    required RigAssetKind kind,
    required String filename,
    required Uint8List bytes,
    required AssetInspection inspection,
    String? title,
    String? manufacturer,
    String? model,
    List<String> tags = const <String>[],
    String notes = '',
  }) async {
    if (_assets.length >= maximumLibraryAssets) {
      throw const FormatException('The asset library is limited to 500 files.');
    }
    if (inspection.kind != kind) {
      throw const FormatException('Asset inspection type does not match the import type.');
    }
    if (bytes.isEmpty || bytes.length > maximumAssetFileBytes) {
      throw const FormatException('Asset files must be between 1 byte and 64 MiB.');
    }
    final cleanFilename = filename.split(RegExp(r'[/\\]')).last;
    final dot = cleanFilename.lastIndexOf('.');
    if (dot <= 0 ||
        cleanFilename.substring(dot).toLowerCase() != inspection.extension) {
      throw const FormatException('Inspected asset extension does not match the selected file.');
    }
    if (title != null && title.trim().isEmpty) {
      throw const FormatException('Asset title cannot be empty.');
    }
    final cleanTitle = title == null
        ? (inspection.suggestedTitle ?? _filenameWithoutExtension(filename))
        : title.trim();
    final cleanManufacturer = (manufacturer ?? inspection.manufacturer ?? '').trim();
    final cleanModel = (model ?? inspection.model ?? '').trim();
    _validateMetadata(cleanTitle, cleanManufacturer, cleanModel, tags, notes);

    final id = _newId();
    final storedFilename = '$id${inspection.extension}';
    final asset = RigAsset(
      id: id,
      title: cleanTitle,
      kind: kind,
      originalFilename: cleanFilename,
      storedFilename: storedFilename,
      extension: inspection.extension,
      fileSizeBytes: bytes.length,
      importedAt: DateTime.now().toUtc(),
      validation: inspection.validation,
      formatSummary: inspection.formatSummary,
      manufacturer: cleanManufacturer,
      model: cleanModel,
      tags: _cleanTags(tags),
      notes: notes.trim(),
      sampleRateHz: inspection.sampleRateHz,
      channelCount: inspection.channelCount,
      bitDepth: inspection.bitDepth,
    );

    await _repository.storeAssetFile(storedFilename, bytes);
    try {
      await _commit([..._assets, asset]);
    } catch (_) {
      try {
        await _repository.deleteAssetFile(storedFilename);
      } catch (_) {
        // The catalog remains unchanged; a leftover file is harmless and can
        // be removed by a future storage-maintenance pass.
      }
      rethrow;
    }
  }

  Future<void> updateMetadata({
    required String assetId,
    required String title,
    required String manufacturer,
    required String model,
    required List<String> tags,
    required String notes,
  }) async {
    _validateMetadata(title.trim(), manufacturer.trim(), model.trim(), tags, notes);
    final next = _assets.map((asset) {
      if (asset.id != assetId) return asset;
      return asset.copyWith(
        title: title.trim(),
        manufacturer: manufacturer.trim(),
        model: model.trim(),
        tags: _cleanTags(tags),
        notes: notes.trim(),
      );
    }).toList();
    if (next.every((asset) => asset.id != assetId)) return;
    await _commit(next);
  }

  Future<void> toggleFavorite(String assetId) async {
    final next = _assets.map((asset) {
      return asset.id == assetId
          ? asset.copyWith(isFavorite: !asset.isFavorite)
          : asset;
    }).toList();
    if (next.every((asset) => asset.id != assetId)) return;
    await _commit(next);
  }

  Future<void> deleteAsset(String assetId) async {
    RigAsset? asset;
    for (final item in _assets) {
      if (item.id == assetId) {
        asset = item;
        break;
      }
    }
    if (asset == null) return;
    final next = _assets.where((item) => item.id != assetId).toList();
    await _commit(next);
    try {
      await _repository.deleteAssetFile(asset.storedFilename);
    } catch (error) {
      _errorMessage = 'Asset removed from the library, but its stored file could not be cleaned up: $error';
      notifyListeners();
    }
  }

  Future<void> _commit(List<RigAsset> next) async {
    _errorMessage = null;
    await _repository.saveAssets(next);
    _assets = next;
    notifyListeners();
  }

  String _newId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    var candidate = 'asset-$timestamp';
    var suffix = 0;
    while (_assets.any((asset) => asset.id == candidate)) {
      suffix++;
      candidate = 'asset-$timestamp-$suffix';
    }
    return candidate;
  }

  static String _filenameWithoutExtension(String filename) {
    final clean = filename.split(RegExp(r'[/\\]')).last;
    final dot = clean.lastIndexOf('.');
    return dot > 0 ? clean.substring(0, dot) : clean;
  }

  static List<String> _cleanTags(List<String> tags) {
    final clean = <String>[];
    final seen = <String>{};
    for (final tag in tags) {
      final value = tag.trim();
      if (value.isEmpty) continue;
      final normalized = value.toLowerCase();
      if (seen.add(normalized)) clean.add(value);
    }
    return clean;
  }

  static void _validateMetadata(
    String title,
    String manufacturer,
    String model,
    List<String> tags,
    String notes,
  ) {
    if (title.trim().isEmpty || title.length > 100) {
      throw const FormatException('Asset title must contain 1–100 characters.');
    }
    if (manufacturer.length > 80 || model.length > 100 || notes.length > 500) {
      throw const FormatException('Asset metadata exceeds the allowed length.');
    }
    if (tags.length > 20 ||
        tags.any((tag) => tag.trim().length > 24)) {
      throw const FormatException('Use up to 20 tags, with 24 characters per tag.');
    }
  }
}
