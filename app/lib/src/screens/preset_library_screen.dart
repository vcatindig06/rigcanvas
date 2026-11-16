import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/rig_preset.dart';
import '../state/preset_controller.dart';

class PresetLibraryScreen extends StatefulWidget {
  const PresetLibraryScreen({
    required this.controller,
    super.key,
  });

  final PresetController controller;

  @override
  State<PresetLibraryScreen> createState() => _PresetLibraryScreenState();
}

class _PresetLibraryScreenState extends State<PresetLibraryScreen> {
  PresetController get controller => widget.controller;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _importPreset() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final source = utf8.decode(bytes);
      await controller.importPresetJson(source);
      _showMessage('Preset imported successfully.');
    } catch (error) {
      _showMessage('Import failed: $error');
    }
  }

  Future<void> _exportPreset(RigPreset preset) async {
    try {
      final source = PresetCodec.encode(preset);
      final safeName = preset.name
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      final fileName = '${safeName.isEmpty ? 'rigcanvas-preset' : safeName}.rigcanvas.json';
      final uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(source)),
      );
      if (uri != null) _showMessage('Preset exported.');
    } catch (error) {
      _showMessage('Export failed: $error');
    }
  }

  Future<void> _createPreset() async {
    final name = await _nameDialog(title: 'Create preset', initialValue: 'New Preset');
    if (name == null) return;
    try {
      await controller.createPreset(name: name);
      _showMessage('Preset created.');
    } catch (error) {
      _showMessage('Unable to create preset: $error');
    }
  }

  Future<void> _renamePreset(RigPreset preset) async {
    final name = await _nameDialog(
      title: 'Rename preset',
      initialValue: preset.name,
    );
    if (name == null) return;
    try {
      await controller.renamePreset(preset.id, name);
      _showMessage('Preset renamed.');
    } catch (error) {
      _showMessage('Unable to rename preset: $error');
    }
  }

  Future<String?> _nameDialog({
    required String title,
    required String initialValue,
  }) async {
    final textController = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Preset name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(textController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    textController.dispose();
    return result;
  }

  Future<void> _deletePreset(RigPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete preset?'),
        content: Text('Delete "${preset.name}" from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9B3D34),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.deletePreset(preset.id);
      _showMessage('Preset deleted.');
    } catch (error) {
      _showMessage('Unable to delete preset: $error');
    }
  }

  Future<void> _handleAction(String action, RigPreset preset) async {
    switch (action) {
      case 'rename':
        await _renamePreset(preset);
        break;
      case 'duplicate':
        try {
          await controller.duplicatePreset(preset.id);
          _showMessage('Preset duplicated.');
        } catch (error) {
          _showMessage('Unable to duplicate preset: $error');
        }
        break;
      case 'export':
        await _exportPreset(preset);
        break;
      case 'delete':
        await _deletePreset(preset);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preset Library',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your presets are saved locally on this device.',
                        style: TextStyle(color: Color(0xFF9AA4B2)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: _importPreset,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Import'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _createPreset,
                    icon: const Icon(Icons.add),
                    label: const Text('New preset'),
                  ),
                ],
              ),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 14),
                _ErrorBanner(message: controller.errorMessage!),
              ],
              const SizedBox(height: 18),
              Expanded(
                child: controller.presets.isEmpty
                    ? const Center(
                        child: Text(
                          'No presets are available. Resolve the storage issue, then restart the app.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: controller.presets.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final preset = controller.presets[index];
                          final selected =
                              preset.id == controller.activePresetId;
                          return Card(
                            child: ListTile(
                              onTap: () => controller.selectPreset(preset.id),
                              leading: CircleAvatar(
                                backgroundColor: selected
                                    ? const Color(0xFF39231F)
                                    : const Color(0xFF252B34),
                                child: Icon(
                                  Icons.graphic_eq,
                                  color: selected
                                      ? const Color(0xFFFF987B)
                                      : const Color(0xFF9AA4B2),
                                ),
                              ),
                              title: Text(
                                preset.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${preset.blocks.length} blocks · Updated ${_formatDate(preset.updatedAt)}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) =>
                                    _handleAction(action, preset),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Rename'),
                                  ),
                                  PopupMenuItem(
                                    value: 'duplicate',
                                    child: Text('Duplicate'),
                                  ),
                                  PopupMenuItem(
                                    value: 'export',
                                    child: Text('Export JSON'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              const Text(
                'RigCanvas preset files are not device preset files. Hardware synchronization is not enabled.',
                style: TextStyle(fontSize: 11, color: Color(0xFF788391)),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF311E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF75403A)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFFFB3A6), fontSize: 12),
      ),
    );
  }
}
