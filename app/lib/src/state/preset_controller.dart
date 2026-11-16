import 'package:flutter/foundation.dart';

import '../data/preset_repository.dart';
import '../models/effect_block.dart';
import '../models/rig_preset.dart';

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

  Future<void> selectPreset(String id) async {
    if (!_presets.any((preset) => preset.id == id)) return;
    _activePresetId = id;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> createPreset({String? name}) async {
    final now = DateTime.now().toUtc();
    final activeBlocks = activePreset?.blocks ?? EffectBlock.demoChain();
    final preset = RigPreset(
      id: _newId('preset'),
      name: (name ?? 'New Preset').trim(),
      description: 'Created in RigCanvas.',
      createdAt: now,
      updatedAt: now,
      blocks: List<EffectBlock>.from(activeBlocks),
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

  Future<void> addBlock(EffectFamily family) async {
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
    await _replaceActiveBlocks(nextBlocks);
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
        newIndex > current.blocks.length) {
      return;
    }
    final nextBlocks = List<EffectBlock>.from(current.blocks);
    if (newIndex > oldIndex) newIndex -= 1;
    final block = nextBlocks.removeAt(oldIndex);
    nextBlocks.insert(newIndex, block);
    await _replaceActiveBlocks(nextBlocks);
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

  Future<void> _replaceActiveBlocks(List<EffectBlock> blocks) async {
    final current = activePreset;
    if (current == null) return;
    final next = _presets
        .map(
          (preset) => preset.id == current.id
              ? preset.copyWith(blocks: blocks)
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
            : _presets.firstOrNull?.id);
    notifyListeners();
  }

  String _newId(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    var candidate = '$prefix-$timestamp';
    var suffix = 0;
    while (_presets.any((preset) => preset.id == candidate)) {
      suffix++;
      candidate = '$prefix-$timestamp-$suffix';
    }
    return candidate;
  }
}
