import 'package:flutter/material.dart';

import '../models/effect_block.dart';
import '../state/preset_controller.dart';
import 'effect_block_editor_dialog.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    required this.controller,
    super.key,
  });

  final PresetController controller;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  PresetController get controller => widget.controller;

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
      builder: (context) => EffectBlockEditorDialog(block: block),
    );
    if (updated == null) return;
    await _runMutation(() => controller.updateBlock(updated));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
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
                  const _SimulationPill(),
                ],
              ),
              const SizedBox(height: 18),
              const _SafetyNotice(),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text(
                    'EFFECT CHAIN',
                    style: TextStyle(
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
                        onReorder: (oldIndex, newIndex) => _runMutation(
                          () => controller.reorderActiveBlocks(
                            oldIndex,
                            newIndex,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final block = blocks[index];
                          return _EffectBlockTile(
                            key: ValueKey(block.id),
                            index: index,
                            block: block,
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

class _EffectBlockTile extends StatelessWidget {
  const _EffectBlockTile({
    required super.key,
    required this.index,
    required this.block,
    required this.onTap,
    required this.onToggle,
  });

  final int index;
  final EffectBlock block;
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
            summary.isEmpty
                ? block.description
                : '$summary\n${block.description}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8993A1)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: block.enabled, onChanged: onToggle),
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
