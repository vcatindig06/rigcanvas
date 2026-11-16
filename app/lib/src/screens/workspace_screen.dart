import 'package:material_ui/material_ui.dart';

import '../models/effect_block.dart';
import '../models/rig_asset.dart';
import '../models/rig_preset.dart';
import '../state/asset_controller.dart';
import '../state/preset_controller.dart';
import 'effect_block_editor_dialog.dart';

enum WorkspaceMode { preset, scene, stomp, hybrid }

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    required this.controller,
    required this.assetController,
    super.key,
  });

  final PresetController controller;
  final AssetController assetController;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  PresetController get controller => widget.controller;
  AssetController get assetController => widget.assetController;
  WorkspaceMode _mode = WorkspaceMode.preset;

  RigAssetKind? _expectedAssetKind(EffectFamily family) {
    switch (family) {
      case EffectFamily.amplifier:
        return RigAssetKind.ampCapture;
      case EffectFamily.cabinet:
        return RigAssetKind.cabinetIr;
      default:
        return null;
    }
  }

  RigAsset? _assetFor(String? assetId, EffectFamily family) {
    if (assetId == null) return null;
    final expectedKind = _expectedAssetKind(family);
    if (expectedKind == null) return null;
    for (final asset in assetController.assets) {
      if (asset.id == assetId && asset.kind == expectedKind) return asset;
    }
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _showMessage('Could not save workspace: $error');
    }
  }

  Future<void> _editBlock(EffectBlock block) async {
    final updated = await showDialog<EffectBlock>(
      context: context,
      builder: (context) => EffectBlockEditorDialog(
        block: block,
        assets: assetController.assets,
      ),
    );
    if (updated == null) return;
    await _runMutation(() => controller.updateBlock(updated));
  }

  Future<void> _captureScene() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Capture scene'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Scene name',
            hintText: 'e.g. Chorus, Ambient Intro',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) =>
              Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(nameController.text.trim()),
            child: const Text('Capture'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null) return;
    await _runMutation(() => controller.captureScene(name: name));
  }

  String get _modeDescription {
    switch (_mode) {
      case WorkspaceMode.preset:
        return 'Edit the complete local preset and its signal chain.';
      case WorkspaceMode.scene:
        return 'Capture and recall snapshots of this preset’s block states and parameters.';
      case WorkspaceMode.stomp:
        return 'Toggle individual local effect blocks like a virtual pedalboard.';
      case WorkspaceMode.hybrid:
        return 'Recall a saved scene, then make individual stomp changes.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, assetController]),
      builder: (context, _) {
        if (controller.isLoading || assetController.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final preset = controller.activePreset;
        if (preset == null) {
          return Center(
            child: Text(
              controller.errorMessage ?? 'No local preset is available.',
              textAlign: TextAlign.center,
            ),
          );
        }
        final blocks = preset.blocks;
        final enabledCount = blocks.where((block) => block.enabled).length;
        final showScenes =
            _mode == WorkspaceMode.scene || _mode == WorkspaceMode.hybrid;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Signal Workspace',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.name,
                        style: const TextStyle(color: Color(0xFF9AA4B2)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  _MetricPill(label: '${blocks.length} BLOCKS'),
                  _MetricPill(label: '$enabledCount ACTIVE'),
                  _MetricPill(label: '${preset.scenes.length} SCENES'),
                  const _SimulationPill(),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<WorkspaceMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: WorkspaceMode.preset,
                      icon: Icon(Icons.tune),
                      label: Text('Preset'),
                    ),
                    ButtonSegment(
                      value: WorkspaceMode.scene,
                      icon: Icon(Icons.layers_outlined),
                      label: Text('Scene'),
                    ),
                    ButtonSegment(
                      value: WorkspaceMode.stomp,
                      icon: Icon(Icons.toggle_on_outlined),
                      label: Text('Stomp'),
                    ),
                    ButtonSegment(
                      value: WorkspaceMode.hybrid,
                      icon: Icon(Icons.dashboard_customize_outlined),
                      label: Text('Hybrid'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      setState(() => _mode = selection.first);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _modeDescription,
                style: const TextStyle(
                  color: Color(0xFF9AA4B2),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              const _SafetyNotice(),
              if (showScenes) ...[
                const SizedBox(height: 12),
                _SceneManager(
                  scenes: preset.scenes,
                  onCapture: _captureScene,
                  onApply: (sceneId) => _runMutation(
                    () => controller.applyScene(sceneId),
                  ),
                  onDelete: (sceneId) => _runMutation(
                    () => controller.deleteScene(sceneId),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    _mode == WorkspaceMode.stomp ? 'STOMP BLOCKS' : 'EFFECT CHAIN',
                    style: const TextStyle(
                      color: Color(0xFF9AA4B2),
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<EffectFamily>(
                    tooltip: 'Add effect block',
                    onSelected: (family) => _runMutation(
                      () => controller.addBlock(family),
                    ),
                    itemBuilder: (context) => EffectFamily.values
                        .map(
                          (family) => PopupMenuItem<EffectFamily>(
                            value: family,
                            child: Row(
                              children: [
                                Icon(family.icon, size: 18),
                                const SizedBox(width: 10),
                                Text(family.label),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A241F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF714234)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 18, color: Color(0xFFFFA083)),
                          SizedBox(width: 7),
                          Text(
                            'Add block',
                            style: TextStyle(
                              color: Color(0xFFFFB29D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: blocks.isEmpty
                    ? const Center(
                        child: Text('Add an effect block to start your chain.'),
                      )
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: blocks.length,
                        onReorderItem: (oldIndex, newIndex) {
                          if (_mode == WorkspaceMode.stomp) return;
                          _runMutation(
                            () => controller.reorderActiveBlocks(
                              oldIndex,
                              newIndex,
                            ),
                          );
                        },
                        itemBuilder: (context, index) {
                          final block = blocks[index];
                          return _EffectBlockTile(
                            key: ValueKey(block.id),
                            index: index,
                            block: block,
                            linkedAsset: _assetFor(block.assetId, block.family),
                            canReorder: _mode != WorkspaceMode.stomp,
                            onTap: () => _editBlock(block),
                            onToggle: (enabled) => _runMutation(
                              () => controller.updateBlock(
                                block.copyWith(enabled: enabled),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Local preset editor · Changes are saved on this device. Nothing is sent to the KPT Pro.',
                style: TextStyle(fontSize: 11, color: Color(0xFF788391)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SceneManager extends StatelessWidget {
  const _SceneManager({
    required this.scenes,
    required this.onCapture,
    required this.onApply,
    required this.onDelete,
  });

  final List<RigScene> scenes;
  final VoidCallback onCapture;
  final ValueChanged<String> onApply;
  final ValueChanged<String> onDelete;

  String _date(DateTime value) {
    final date = value.toLocal();
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'SCENE SNAPSHOTS',
              style: TextStyle(
                color: Color(0xFF9AA4B2),
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Capture scene'),
            ),
          ],
        ),
        if (scenes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF15191F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF292F38)),
            ),
            child: const Text(
              'No scenes yet. Set your block switches and parameters, then capture a scene.',
              style: TextStyle(
                color: Color(0xFF9AA4B2),
                fontSize: 11,
              ),
            ),
          )
        else
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: scenes.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final scene = scenes[index];
                final activeCount =
                    scene.blocks.where((block) => block.enabled).length;
                return SizedBox(
                  width: 190,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => onApply(scene.id),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    scene.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$activeCount active · ${_date(scene.createdAt)}',
                                    style: const TextStyle(
                                      color: Color(0xFF9AA4B2),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete scene',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onDelete(scene.id),
                            icon: const Icon(Icons.close, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _EffectBlockTile extends StatelessWidget {
  const _EffectBlockTile({
    required super.key,
    required this.index,
    required this.block,
    required this.linkedAsset,
    required this.canReorder,
    required this.onTap,
    required this.onToggle,
  });

  final int index;
  final EffectBlock block;
  final RigAsset? linkedAsset;
  final bool canReorder;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final muted = !block.enabled;
    final specs = effectParameterSpecs[block.family] ?? <EffectParameterSpec>[];
    final summary = specs.take(3).map((spec) {
      final value = block.parameters[spec.key] ?? spec.initial;
      final shown = value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
      return '${spec.label}: $shown${spec.unit}';
    }).join('  ·  ');

    final linkedAssetSummary = linkedAsset == null
        ? (block.assetId == null ? null : 'Linked asset missing or incompatible with this block')
        : '${block.family == EffectFamily.amplifier ? 'Capture' : 'Cabinet IR'}: '
            '${linkedAsset!.title} · '
            '${linkedAsset!.validation == RigAssetValidation.validated ? 'format checked' : 'format unverified'}';
    final subtitle = [
      if (summary.isNotEmpty) summary,
      block.description,
      if (linkedAssetSummary != null) linkedAssetSummary,
    ].join('\n');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 5,
          ),
          leading: CircleAvatar(
            backgroundColor: muted
                ? const Color(0xFF282E37)
                : const Color(0xFF39231F),
            child: Icon(
              block.family.icon,
              color: muted ? const Color(0xFF788391) : const Color(0xFFFF987B),
            ),
          ),
          title: Text(
            block.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: muted ? const Color(0xFF8993A1) : Colors.white,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8993A1)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: block.enabled, onChanged: onToggle),
              if (canReorder)
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator, color: Color(0xFF8993A1)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF171C23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF303844)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 0.8,
          color: Color(0xFFADB6C2),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SimulationPill extends StatelessWidget {
  const _SimulationPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF202B25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF385844)),
      ),
      child: const Text(
        'SIMULATION',
        style: TextStyle(
          color: Color(0xFF9BDBAC),
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF211B18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF5B3B30)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFFFA083), size: 19),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Local simulation workspace. Nothing on this screen is sent to the KPT Pro. Device support will be enabled only after its exact protocol and firmware compatibility are verified.',
              style: TextStyle(
                color: Color(0xFFE3B8A9),
                height: 1.4,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
