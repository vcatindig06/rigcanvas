import 'package:material_ui/material_ui.dart';

import '../models/effect_block.dart';
import '../models/rig_asset.dart';
import '../models/rig_grid.dart';
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

  RigAsset? _assetFor(EffectBlock block) {
    if (block.assetId == null) return null;
    final expected = switch (block.family) {
      EffectFamily.amplifier => RigAssetKind.ampCapture,
      EffectFamily.cabinet => RigAssetKind.cabinetIr,
      _ => null,
    };
    if (expected == null) return null;
    for (final asset in assetController.assets) {
      if (asset.id == block.assetId && asset.kind == expected) return asset;
    }
    return null;
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _message('Could not save workspace: $error');
    }
  }

  Future<void> _edit(EffectBlock block) async {
    final updated = await showDialog<EffectBlock>(
      context: context,
      builder: (context) => EffectBlockEditorDialog(
        block: block,
        assets: assetController.assets,
      ),
    );
    if (updated != null) await _mutate(() => controller.updateBlock(updated));
  }

  Future<void> _remove(EffectBlock block) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove block?'),
        content: Text('Remove "${block.name}" from this preset and its saved scenes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _mutate(() => controller.removeBlock(block.id));
  }

  Future<void> _captureScene() async {
    final input = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Capture scene'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Scene name',
            hintText: 'e.g. Chorus, Ambient Intro',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, input.text.trim()),
            child: const Text('Capture'),
          ),
        ],
      ),
    );
    input.dispose();
    if (name != null) await _mutate(() => controller.captureScene(name: name));
  }

  Future<void> _toggle(EffectBlock block) => _mutate(
    () => controller.updateBlock(block.copyWith(enabled: !block.enabled)),
  );

  String get _description => switch (_mode) {
    WorkspaceMode.preset => 'Edit the loaded rig. Drag blocks between slots or add a new block.',
    WorkspaceMode.scene => 'Recall a saved snapshot of this preset. Grid layout and block settings are restored together.',
    WorkspaceMode.stomp => 'A–H toggle the first eight blocks in preset order. These are local controls only.',
    WorkspaceMode.hybrid => 'A–D recall scenes. E–H toggle the first four blocks in preset order.',
  };

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
        final blocksById = <String, EffectBlock>{
          for (final block in preset.blocks) block.id: block,
        };
        final active = preset.blocks.where((block) => block.enabled).length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            return SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WorkspaceHeader(
                    preset: preset,
                    presets: controller.presets,
                    activeBlocks: active,
                    onSelectPreset: controller.selectPreset,
                  ),
                  const SizedBox(height: 14),
                  _ModeSelector(
                    mode: _mode,
                    onChanged: (mode) => setState(() => _mode = mode),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _description,
                    style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 12),
                  ),
                  const SizedBox(height: 11),
                  const _SafetyNotice(),
                  if (_mode == WorkspaceMode.scene) ...[
                    const SizedBox(height: 14),
                    _ScenePads(
                      scenes: preset.scenes,
                      padCount: 8,
                      onApply: (id) => _mutate(() => controller.applyScene(id)),
                      onCapture: _captureScene,
                      onDelete: (id) => _mutate(() => controller.deleteScene(id)),
                    ),
                  ],
                  if (_mode == WorkspaceMode.stomp) ...[
                    const SizedBox(height: 14),
                    _StompPads(
                      title: 'STOMP ASSIGNMENTS · A–H',
                      blocks: preset.blocks.take(8).toList(),
                      startIndex: 0,
                      count: 8,
                      onToggle: _toggle,
                    ),
                  ],
                  if (_mode == WorkspaceMode.hybrid) ...[
                    const SizedBox(height: 14),
                    _ScenePads(
                      scenes: preset.scenes.take(4).toList(),
                      padCount: 4,
                      onApply: (id) => _mutate(() => controller.applyScene(id)),
                      onCapture: _captureScene,
                      onDelete: (id) => _mutate(() => controller.deleteScene(id)),
                      title: 'SCENES · A–D',
                    ),
                    const SizedBox(height: 10),
                    _StompPads(
                      title: 'STOMP ASSIGNMENTS · E–H',
                      blocks: preset.blocks.take(4).toList(),
                      startIndex: 4,
                      count: 4,
                      onToggle: _toggle,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'GRID WORKSPACE',
                          style: TextStyle(
                            color: Color(0xFFADB6C2),
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _InfoPill(label: '${preset.grid.blockCount}/32 SLOTS'),
                      if (_mode == WorkspaceMode.preset) ...[
                        const SizedBox(width: 8),
                        PopupMenuButton<EffectFamily>(
                          tooltip: 'Add effect block',
                          onSelected: (family) => _mutate(() => controller.addBlock(family)),
                          itemBuilder: (context) => EffectFamily.values
                              .map((family) => PopupMenuItem<EffectFamily>(
                                    value: family,
                                    child: Row(
                                      children: [
                                        Icon(family.icon, size: 18),
                                        const SizedBox(width: 9),
                                        Text(family.label),
                                      ],
                                    ),
                                  ))
                              .toList(),
                          child: const _AddBlockButton(),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  _GridBoard(
                    grid: preset.grid,
                    blocksById: blocksById,
                    mode: _mode,
                    assetFor: _assetFor,
                    onEdit: _edit,
                    onRemove: _remove,
                    onToggle: _toggle,
                    onAdd: (row, family) => _mutate(
                      () => controller.addBlock(family, preferredRow: row),
                    ),
                    onMove: (id, row, column) => _mutate(
                      () => controller.moveBlockToSlot(id, row, column),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _GridRoutingNote(),
                  const SizedBox(height: 12),
                  const Text(
                    'Local preset editor · Changes are saved on this device. Nothing is sent to the KPT Pro.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF788391)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.preset,
    required this.presets,
    required this.activeBlocks,
    required this.onSelectPreset,
  });

  final RigPreset preset;
  final List<RigPreset> presets;
  final int activeBlocks;
  final ValueChanged<String> onSelectPreset;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Signal Workspace', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(preset.name, style: const TextStyle(color: Color(0xFF9AA4B2))),
          ],
        ),
        const SizedBox(width: 4),
        _InfoPill(label: '${preset.blocks.length} BLOCKS'),
        _InfoPill(label: '$activeBlocks ACTIVE'),
        _InfoPill(label: '${preset.scenes.length} SCENES'),
        const _SimulationPill(),
        PopupMenuButton<String>(
          tooltip: 'Select preset',
          onSelected: onSelectPreset,
          itemBuilder: (context) => presets
              .map((item) => PopupMenuItem<String>(
                    value: item.id,
                    child: Row(
                      children: [
                        Icon(item.id == preset.id ? Icons.check : Icons.circle_outlined, size: 15),
                        const SizedBox(width: 8),
                        Flexible(child: Text(item.name)),
                      ],
                    ),
                  ))
              .toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF171C23),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF303844)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.library_music_outlined, size: 16),
                SizedBox(width: 6),
                Text('Presets', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                Icon(Icons.expand_more, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});
  final WorkspaceMode mode;
  final ValueChanged<WorkspaceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<WorkspaceMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: WorkspaceMode.preset, icon: Icon(Icons.tune), label: Text('Preset')),
          ButtonSegment(value: WorkspaceMode.scene, icon: Icon(Icons.layers_outlined), label: Text('Scene')),
          ButtonSegment(value: WorkspaceMode.stomp, icon: Icon(Icons.toggle_on_outlined), label: Text('Stomp')),
          ButtonSegment(value: WorkspaceMode.hybrid, icon: Icon(Icons.dashboard_customize_outlined), label: Text('Hybrid')),
        ],
        selected: {mode},
        onSelectionChanged: (value) {
          if (value.isNotEmpty) onChanged(value.first);
        },
      ),
    );
  }
}

class _GridBoard extends StatelessWidget {
  const _GridBoard({
    required this.grid,
    required this.blocksById,
    required this.mode,
    required this.assetFor,
    required this.onEdit,
    required this.onRemove,
    required this.onToggle,
    required this.onAdd,
    required this.onMove,
  });

  final RigGrid grid;
  final Map<String, EffectBlock> blocksById;
  final WorkspaceMode mode;
  final RigAsset? Function(EffectBlock) assetFor;
  final ValueChanged<EffectBlock> onEdit;
  final ValueChanged<EffectBlock> onRemove;
  final ValueChanged<EffectBlock> onToggle;
  final void Function(int, EffectFamily) onAdd;
  final void Function(String, int, int) onMove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101419),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF303844)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1040,
          child: Column(
            children: [
              for (var row = 0; row < rigGridRowCount; row++) ...[
                _GridLane(
                  row: row,
                  grid: grid,
                  blocksById: blocksById,
                  mode: mode,
                  assetFor: assetFor,
                  onEdit: onEdit,
                  onRemove: onRemove,
                  onToggle: onToggle,
                  onAdd: onAdd,
                  onMove: onMove,
                ),
                if (row < rigGridRowCount - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(height: 1, color: Color(0xFF252D36)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GridLane extends StatelessWidget {
  const _GridLane({
    required this.row,
    required this.grid,
    required this.blocksById,
    required this.mode,
    required this.assetFor,
    required this.onEdit,
    required this.onRemove,
    required this.onToggle,
    required this.onAdd,
    required this.onMove,
  });

  final int row;
  final RigGrid grid;
  final Map<String, EffectBlock> blocksById;
  final WorkspaceMode mode;
  final RigAsset? Function(EffectBlock) assetFor;
  final ValueChanged<EffectBlock> onEdit;
  final ValueChanged<EffectBlock> onRemove;
  final ValueChanged<EffectBlock> onToggle;
  final void Function(int, EffectFamily) onAdd;
  final void Function(String, int, int) onMove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 98,
      child: Row(
        children: [
          _LanePort(label: 'IN ${row + 1}', input: true),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < rigGridColumnCount; column++) ...[
                  Expanded(
                    child: _GridSlot(
                      row: row,
                      column: column,
                      block: _blockAt(column),
                      asset: _assetAt(column),
                      mode: mode,
                      onEdit: onEdit,
                      onRemove: onRemove,
                      onToggle: onToggle,
                      onAdd: onAdd,
                      onMove: onMove,
                    ),
                  ),
                  if (column < rigGridColumnCount - 1)
                    Container(width: 8, height: 2, color: const Color(0xFF69727E)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _LanePort(label: 'OUT ${row + 1}', input: false),
        ],
      ),
    );
  }

  EffectBlock? _blockAt(int column) {
    final placement = grid.blockAt(row, column);
    return placement == null ? null : blocksById[placement.blockId];
  }

  RigAsset? _assetAt(int column) {
    final block = _blockAt(column);
    return block == null ? null : assetFor(block);
  }
}

class _GridSlot extends StatelessWidget {
  const _GridSlot({
    required this.row,
    required this.column,
    required this.block,
    required this.asset,
    required this.mode,
    required this.onEdit,
    required this.onRemove,
    required this.onToggle,
    required this.onAdd,
    required this.onMove,
  });

  final int row;
  final int column;
  final EffectBlock? block;
  final RigAsset? asset;
  final WorkspaceMode mode;
  final ValueChanged<EffectBlock> onEdit;
  final ValueChanged<EffectBlock> onRemove;
  final ValueChanged<EffectBlock> onToggle;
  final void Function(int, EffectFamily) onAdd;
  final void Function(String, int, int) onMove;

  @override
  Widget build(BuildContext context) {
    final editable = mode == WorkspaceMode.preset;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => editable && details.data != block?.id,
      onAcceptWithDetails: (details) {
        if (editable) onMove(details.data, row, column);
      },
      builder: (context, candidates, rejected) {
        final highlighted = candidates.isNotEmpty;
        if (block == null) {
          return _EmptySlot(
            row: row,
            column: column,
            highlighted: highlighted,
            enabled: editable,
            onAdd: onAdd,
          );
        }
        final card = _GridEffectCard(
          block: block!,
          asset: asset,
          highlighted: highlighted,
          allowEdit: editable,
          showToggle: mode == WorkspaceMode.stomp || mode == WorkspaceMode.hybrid,
          onTap: () {
            if (mode == WorkspaceMode.stomp || mode == WorkspaceMode.hybrid) {
              onToggle(block!);
            } else if (editable) {
              onEdit(block!);
            }
          },
          onEdit: () => onEdit(block!),
          onRemove: () => onRemove(block!),
        );
        if (!editable) return card;
        return LongPressDraggable<String>(
          data: block!.id,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: 112, child: card),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: card),
          child: card,
        );
      },
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({
    required this.row,
    required this.column,
    required this.highlighted,
    required this.enabled,
    required this.onAdd,
  });

  final int row;
  final int column;
  final bool highlighted;
  final bool enabled;
  final void Function(int, EffectFamily) onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('grid-slot-$row-$column'),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFF263B32) : const Color(0xFF171D24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? const Color(0xFF44D18A) : const Color(0xFF39434F),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: enabled
          ? PopupMenuButton<EffectFamily>(
              tooltip: 'Add block to row ${row + 1}, slot ${column + 1}',
              onSelected: (family) => onAdd(row, family),
              itemBuilder: (context) => EffectFamily.values
                  .map((family) => PopupMenuItem<EffectFamily>(
                        value: family,
                        child: Row(
                          children: [
                            Icon(family.icon, size: 17),
                            const SizedBox(width: 9),
                            Text(family.label),
                          ],
                        ),
                      ))
                  .toList(),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Color(0xFF9AA4B2), size: 22),
                    SizedBox(height: 3),
                    Text('ADD', style: TextStyle(
                      color: Color(0xFF8993A1),
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    )),
                  ],
                ),
              ),
            )
          : const Center(child: Icon(Icons.more_horiz, color: Color(0xFF515B67))),
    );
  }
}

class _GridEffectCard extends StatelessWidget {
  const _GridEffectCard({
    required this.block,
    required this.asset,
    required this.highlighted,
    required this.allowEdit,
    required this.showToggle,
    required this.onTap,
    required this.onEdit,
    required this.onRemove,
  });

  final EffectBlock block;
  final RigAsset? asset;
  final bool highlighted;
  final bool allowEdit;
  final bool showToggle;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  Color get _familyColor => switch (block.family) {
    EffectFamily.gate => const Color(0xFF087CDA),
    EffectFamily.drive => const Color(0xFFFF8A24),
    EffectFamily.amplifier => const Color(0xFFEF4258),
    EffectFamily.cabinet => const Color(0xFF8B70E9),
    EffectFamily.modulation => const Color(0xFF27C98A),
    EffectFamily.delay => const Color(0xFF00C8D5),
    EffectFamily.reverb => const Color(0xFF00AFA8),
  };

  @override
  Widget build(BuildContext context) {
    final enabled = block.enabled;
    final tint = _familyColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        key: ValueKey('grid-block-${block.id}'),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.fromLTRB(6, 5, 4, 5),
        decoration: BoxDecoration(
          color: enabled
              ? Color.lerp(tint, const Color(0xFF14191F), 0.72)
              : const Color(0xFF242931),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted
                ? const Color(0xFF44D18A)
                : enabled
                    ? tint
                    : const Color(0xFF4A515B),
            width: highlighted ? 2 : 1.3,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(block.family.icon, size: 16, color: enabled ? tint : const Color(0xFF8993A1)),
                const Spacer(),
                if (showToggle)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: enabled ? const Color(0xFF57E59B) : const Color(0xFF626B77),
                    ),
                  )
                else if (allowEdit)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 130),
                    iconSize: 16,
                    tooltip: 'Block options',
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'remove') onRemove();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit block')),
                      PopupMenuItem(value: 'remove', child: Text('Remove block')),
                    ],
                    child: const Icon(Icons.more_horiz, size: 17, color: Color(0xFFADB6C2)),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              block.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: enabled ? Colors.white : const Color(0xFFA1A8B2),
                fontSize: 10.5,
                height: 1.12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (asset != null)
              Text(
                block.family == EffectFamily.amplifier
                    ? 'Capture: ${asset!.title}'
                    : 'Cabinet IR: ${asset!.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFB7C4D1), fontSize: 7),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanePort extends StatelessWidget {
  const _LanePort({required this.label, required this.input});
  final String label;
  final bool input;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF20262E),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF3B4551)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(input ? Icons.login : Icons.logout, size: 13, color: const Color(0xFF9BA6B3)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(
            color: Color(0xFFBAC3CD),
            fontSize: 8,
            fontWeight: FontWeight.w800,
          )),
        ],
      ),
    );
  }
}

class _ScenePads extends StatelessWidget {
  const _ScenePads({
    required this.scenes,
    required this.padCount,
    required this.onApply,
    required this.onCapture,
    required this.onDelete,
    this.title = 'SCENES · A–H',
  });

  final List<RigScene> scenes;
  final int padCount;
  final ValueChanged<String> onApply;
  final VoidCallback onCapture;
  final ValueChanged<String> onDelete;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(
              color: Color(0xFFADB6C2),
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
            ))),
            TextButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Capture scene'),
            ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < padCount; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                _ScenePad(
                  letter: String.fromCharCode(65 + index),
                  scene: index < scenes.length ? scenes[index] : null,
                  onTap: index < scenes.length ? () => onApply(scenes[index].id) : onCapture,
                  onDelete: index < scenes.length ? () => onDelete(scenes[index].id) : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ScenePad extends StatelessWidget {
  const _ScenePad({
    required this.letter,
    required this.scene,
    required this.onTap,
    required this.onDelete,
  });

  final String letter;
  final RigScene? scene;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final activeCount = scene?.blocks.where((block) => block.enabled).length ?? 0;
    return SizedBox(
      width: 112,
      height: 68,
      child: Stack(
        children: [
          Positioned.fill(
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                backgroundColor: scene == null ? const Color(0xFF171D24) : const Color(0xFF183A31),
                side: BorderSide(color: scene == null ? const Color(0xFF3B4551) : const Color(0xFF31B77C)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(letter, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  Text(scene?.name ?? 'Capture', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9)),
                  if (scene != null)
                    Text('$activeCount active', style: const TextStyle(fontSize: 8, color: Color(0xFFB5C5BC))),
                ],
              ),
            ),
          ),
          if (onDelete != null)
            Positioned(
              right: 0,
              top: 0,
              child: SizedBox(
                width: 21,
                height: 21,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Delete ${scene!.name}',
                  onPressed: onDelete,
                  icon: const Icon(Icons.close, size: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StompPads extends StatelessWidget {
  const _StompPads({
    required this.title,
    required this.blocks,
    required this.startIndex,
    required this.count,
    required this.onToggle,
  });

  final String title;
  final List<EffectBlock> blocks;
  final int startIndex;
  final int count;
  final ValueChanged<EffectBlock> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(
          color: Color(0xFFADB6C2),
          fontSize: 10,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w800,
        )),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < count; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                _StompPad(
                  letter: String.fromCharCode(65 + startIndex + index),
                  block: index < blocks.length ? blocks[index] : null,
                  onTap: index < blocks.length ? () => onToggle(blocks[index]) : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StompPad extends StatelessWidget {
  const _StompPad({required this.letter, required this.block, required this.onTap});
  final String letter;
  final EffectBlock? block;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = block?.enabled ?? false;
    return SizedBox(
      width: 112,
      height: 65,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(7),
          backgroundColor: block == null
              ? const Color(0xFF171D24)
              : enabled
                  ? const Color(0xFF183A31)
                  : const Color(0xFF242931),
          side: BorderSide(color: block == null
              ? const Color(0xFF3B4551)
              : enabled
                  ? const Color(0xFF31B77C)
                  : const Color(0xFF59616B)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(letter, style: TextStyle(
              color: enabled ? const Color(0xFF5DE2A0) : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            )),
            Text(block?.name ?? 'Unassigned', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9)),
            if (block != null)
              Text(enabled ? 'ON' : 'OFF', style: const TextStyle(
                color: Color(0xFFB5C5BC),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              )),
          ],
        ),
      ),
    );
  }
}

class _AddBlockButton extends StatelessWidget {
  const _AddBlockButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3A241F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF714234)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 17, color: Color(0xFFFFA083)),
          SizedBox(width: 6),
          Text('Add block', style: TextStyle(
            color: Color(0xFFFFB29D),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          )),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF171C23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF303844)),
      ),
      child: Text(label, style: const TextStyle(
        fontSize: 9,
        letterSpacing: 0.6,
        color: Color(0xFFADB6C2),
        fontWeight: FontWeight.w800,
      )),
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
      child: const Text('SIMULATION', style: TextStyle(
        color: Color(0xFF9BDBAC),
        fontSize: 9,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w800,
      )),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF211B18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5B3B30)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFFFA083), size: 17),
          SizedBox(width: 9),
          Expanded(child: Text(
            'Local simulation only. Blocks, scenes and switches do not process audio or communicate with the KPT Pro.',
            style: TextStyle(color: Color(0xFFE3B8A9), height: 1.35, fontSize: 11),
          )),
        ],
      ),
    );
  }
}

class _GridRoutingNote extends StatelessWidget {
  const _GridRoutingNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF15191F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF303844)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.alt_route, size: 16, color: Color(0xFF9AA4B2)),
          SizedBox(width: 8),
          Expanded(child: Text(
            'Grid v1 saves four independent local lanes. Splitter, mixer, cross-lane routing and audio processing are not implemented yet.',
            style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 10, height: 1.4),
          )),
        ],
      ),
    );
  }
}
