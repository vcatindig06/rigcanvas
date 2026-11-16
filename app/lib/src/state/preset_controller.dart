import 'package:flutter/foundation.dart';

import '../data/preset_repository.dart';
import '../models/effect_block.dart';
import '../models/rig_preset.dart';
import '../models/rig_grid.dart';

class PresetController extends ChangeNotifier {
  PresetController(this._repository);

  final PresetRepository _repository;

  List<RigPreset> _presets = <RigPreset>[];
  String? _activePresetId;
  bool _isLoading = true;
  String? _errorMessage;

  List<RigPreset> get presets => List.unmodifiable(_presets);
  String? get activePresetId => _activePresetId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  RigPreset? get activePreset {
    for (final preset in _presets) {
      if (preset.id == _activePresetId) return preset;
    }
    return _presets.isEmpty ? null : _presets.first;
  }

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      var loaded = await _repository.loadPresets();
      if (loaded.isEmpty) {
        loaded = [RigPreset.starter()];
        await _repository.savePresets(loaded);
      }
      _presets = loaded;
      _activePresetId = loaded.first.id;
    } catch (error) {
      _errorMessage = 'Unable to load local presets: $error';
      _presets = <RigPreset>[];
      _activePresetId = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectPreset(String id) {
    if (!_presets.any((preset) => preset.id == id)) return;
    _activePresetId = id;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> createPreset({String? name}) async {
    final now = DateTime.now().toUtc();
    final active = activePreset;
    final activeBlocks = active?.blocks ?? EffectBlock.demoChain();
    final preset = RigPreset(
      id: _newId('preset'),
      name: (name ?? 'New Preset').trim(),
      description: 'Created in RigCanvas.',
      createdAt: now,
      updatedAt: now,
      blocks: List<EffectBlock>.from(activeBlocks),
      grid: active?.grid ?? RigGrid.fromBlockIds(activeBlocks.map((block) => block.id)),
    );
    await _commit([..._presets, preset], activeId: preset.id);
  }

  Future<void> duplicatePreset(String id) async {
    final source = _findPreset(id);
    if (source == null) return;
    final now = DateTime.now().toUtc();
    final copy = RigPreset(
      id: _newId('preset'),
      name: '${source.name} Copy',
      description: source.description,
      createdAt: now,
      updatedAt: now,
      blocks: List<EffectBlock>.from(source.blocks),
      scenes: List<RigScene>.from(source.scenes),
      grid: source.grid,
      target: source.target,
    );
    await _commit([..._presets, copy], activeId: copy.id);
  }

  Future<void> renamePreset(String id, String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 80) {
      throw const FormatException('Preset name must contain 1–80 characters.');
    }
    final next = _presets
        .map(
          (preset) => preset.id == id
              ? preset.copyWith(name: cleanName)
              : preset,
        )
        .toList();
    await _commit(next, activeId: _activePresetId);
  }

  Future<void> deletePreset(String id) async {
    final next = _presets.where((preset) => preset.id != id).toList();
    if (next.length == _presets.length) return;

    if (next.isEmpty) {
      next.add(RigPreset.starter());
    }
    final nextActive = _activePresetId == id
        ? next.first.id
        : _activePresetId;
    await _commit(next, activeId: nextActive);
  }

  Future<void> addBlock(EffectFamily family, {int preferredRow = 0}) async {
    final current = activePreset;
    if (current == null) return;
    if (current.blocks.length >= maximumPresetBlocks) {
      throw const FormatException(
        'This workspace has reached the maximum number of effect blocks.',
      );
    }
    final block = EffectBlock.create(
      id: _newId('block'),
      family: family,
    );
    final nextBlocks = [...current.blocks, block];
    await _replaceActivePreset(
      current.copyWith(
        blocks: nextBlocks,
        grid: current.grid.withAddedBlock(block.id, preferredRow: preferredRow),
      ),
    );
  }

  Future<void> moveBlockToSlot(String blockId, int row, int column) async {
    final current = activePreset;
    if (current == null) return;
    final nextGrid = current.grid.moveBlockToSlot(blockId, row, column);
    await _replaceActivePreset(current.copyWith(grid: nextGrid));
  }

  Future<void> removeBlock(String blockId) async {
    final current = activePreset;
    if (current == null) return;
    final nextBlocks = current.blocks.where((block) => block.id != blockId).toList();
    if (nextBlocks.length == current.blocks.length) return;
    final nextScenes = current.scenes.map((scene) {
      final sceneBlocks = scene.blocks.where((block) => block.id != blockId).toList();
      return scene.copyWith(
        blocks: sceneBlocks,
        grid: scene.grid.withoutBlock(blockId),
      );
    }).toList();
    await _replaceActivePreset(
      current.copyWith(
        blocks: nextBlocks,
        scenes: nextScenes,
        grid: current.grid.withoutBlock(blockId),
      ),
    );
  }

  Future<void> updateBlock(EffectBlock updatedBlock) async {
    final current = activePreset;
    if (current == null) return;
    final nextBlocks = current.blocks
        .map((block) => block.id == updatedBlock.id ? updatedBlock : block)
        .toList();
    await _replaceActiveBlocks(nextBlocks);
  }

  Future<void> reorderActiveBlocks(int oldIndex, int newIndex) async {
    final current = activePreset;
    if (current == null ||
        oldIndex < 0 ||
        oldIndex >= current.blocks.length ||
        newIndex < 0 ||
        newIndex >= current.blocks.length) {
      return;
    }
    final nextBlocks = List<EffectBlock>.from(current.blocks);
    final block = nextBlocks.removeAt(oldIndex);
    nextBlocks.insert(newIndex, block);
    await _replaceActiveBlocks(nextBlocks);
  }

  Future<void> captureScene({required String name}) async {
    final current = activePreset;
    if (current == null) return;

    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 80) {
      throw const FormatException('Scene name must contain 1–80 characters.');
    }
    if (current.scenes.length >= maximumPresetScenes) {
      throw const FormatException(
        'This preset has reached the maximum number of scenes.',
      );
    }

    final snapshot = RigScene(
      id: _newId('scene'),
      name: cleanName,
      createdAt: DateTime.now().toUtc(),
      blocks: current.blocks
          .map(
            (block) => block.copyWith(
              parameters: Map<String, double>.from(block.parameters),
            ),
          )
          .toList(),
      grid: current.grid,
    );
    await _replaceActiveScenes([...current.scenes, snapshot]);
  }

  Future<void> applyScene(String sceneId) async {
    final current = activePreset;
    if (current == null) return;
    RigScene? selected;
    for (final scene in current.scenes) {
      if (scene.id == sceneId) {
        selected = scene;
        break;
      }
    }
    if (selected == null) return;

    final restoredBlocks = selected.blocks
        .map(
          (block) => block.copyWith(
            parameters: Map<String, double>.from(block.parameters),
          ),
        )
        .toList();
    await _replaceActivePreset(
      current.copyWith(blocks: restoredBlocks, grid: selected.grid),
    );
  }

  Future<void> deleteScene(String sceneId) async {
    final current = activePreset;
    if (current == null) return;
    final nextScenes = current.scenes
        .where((scene) => scene.id != sceneId)
        .toList();
    if (nextScenes.length == current.scenes.length) return;
    await _replaceActiveScenes(nextScenes);
  }

  Future<void> importPresetJson(String source) async {
    final imported = PresetCodec.decode(source);
    final duplicateId = _presets.any((preset) => preset.id == imported.id);
    final nextPreset = duplicateId
        ? imported.copyWith(id: _newId('preset'))
        : imported;
    await _commit([..._presets, nextPreset], activeId: nextPreset.id);
  }

  String exportActivePresetJson() {
    final current = activePreset;
    if (current == null) {
      throw const FormatException('There is no active preset to export.');
    }
    return PresetCodec.encode(current);
  }

  Future<void> _replaceActivePreset(RigPreset updatedPreset) async {
    final next = _presets
        .map((preset) => preset.id == updatedPreset.id ? updatedPreset : preset)
        .toList();
    await _commit(next, activeId: updatedPreset.id);
  }

  Future<void> _replaceActiveBlocks(List<EffectBlock> blocks) async {
    final current = activePreset;
    if (current == null) return;
    await _replaceActivePreset(current.copyWith(blocks: blocks));
  }

  Future<void> _replaceActiveScenes(List<RigScene> scenes) async {
    final current = activePreset;
    if (current == null) return;
    final next = _presets
        .map(
          (preset) => preset.id == current.id
              ? preset.copyWith(scenes: scenes)
              : preset,
        )
        .toList();
    await _commit(next, activeId: current.id);
  }

  RigPreset? _findPreset(String id) {
    for (final preset in _presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  Future<void> _commit(List<RigPreset> next, {String? activeId}) async {
    _errorMessage = null;
    await _repository.savePresets(next);
    _presets = next;
    _activePresetId = activeId ??
        (_presets.any((preset) => preset.id == _activePresetId)
            ? _activePresetId
            : (_presets.isEmpty ? null : _presets.first.id));
    notifyListeners();
  }

  String _newId(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    var candidate = '$prefix-$timestamp';
    var suffix = 0;
    while (_presets.any(
      (preset) =>
          preset.id == candidate ||
          preset.scenes.any((scene) => scene.id == candidate),
    )) {
      suffix++;
      candidate = '$prefix-$timestamp-$suffix';
    }
    return candidate;
  }
}
