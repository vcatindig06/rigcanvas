import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../data/asset_inspector.dart';
import '../models/rig_asset.dart';
import '../state/asset_controller.dart';

enum _AssetFilter { all, captures, cabinetIrs, favorites }

class AssetLibraryScreen extends StatefulWidget {
  const AssetLibraryScreen({
    required this.controller,
    super.key,
  });

  final AssetController controller;

  @override
  State<AssetLibraryScreen> createState() => _AssetLibraryScreenState();
}

class _AssetLibraryScreenState extends State<AssetLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  _AssetFilter _filter = _AssetFilter.all;

  AssetController get controller => widget.controller;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _importAsset(RigAssetKind kind) async {
    final extensions = kind == RigAssetKind.ampCapture
        ? AssetInspector.ampCaptureExtensions
        : AssetInspector.cabinetIrExtensions;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: extensions,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      final inspection = AssetInspector.inspect(
        kind: kind,
        filename: file.name,
        bytes: bytes,
      );
      final draft = await _showMetadataDialog(
        title: 'Add asset',
        initialTitle: inspection.suggestedTitle ??
            file.name.substring(0, file.name.lastIndexOf('.')),
        initialManufacturer: inspection.manufacturer ?? '',
        initialModel: inspection.model ?? '',
      );
      if (draft == null) return;

      await controller.importAsset(
        kind: kind,
        filename: file.name,
        bytes: bytes,
        inspection: inspection,
        title: draft.title,
        manufacturer: draft.manufacturer,
        model: draft.model,
        tags: draft.tags,
        notes: draft.notes,
      );
      _showMessage('Asset imported into local storage.');
    } catch (error) {
      _showMessage('Unable to import asset: $error');
    }
  }

  Future<_AssetMetadataDraft?> _showMetadataDialog({
    required String title,
    required String initialTitle,
    required String initialManufacturer,
    required String initialModel,
    String initialTags = '',
    String initialNotes = '',
  }) {
    return showDialog<_AssetMetadataDraft>(
      context: context,
      builder: (_) => _AssetMetadataDialog(
        title: title,
        initialTitle: initialTitle,
        initialManufacturer: initialManufacturer,
        initialModel: initialModel,
        initialTags: initialTags,
        initialNotes: initialNotes,
      ),
    );
  }

  Future<void> _editAsset(RigAsset asset) async {
    final draft = await _showMetadataDialog(
      title: 'Edit asset details',
      initialTitle: asset.title,
      initialManufacturer: asset.manufacturer,
      initialModel: asset.model,
      initialTags: asset.tags.join(', '),
      initialNotes: asset.notes,
    );
    if (draft == null) return;
    try {
      await controller.updateMetadata(
        assetId: asset.id,
        title: draft.title,
        manufacturer: draft.manufacturer,
        model: draft.model,
        tags: draft.tags,
        notes: draft.notes,
      );
      _showMessage('Asset details updated.');
    } catch (error) {
      _showMessage('Unable to update asset: $error');
    }
  }

  Future<void> _deleteAsset(RigAsset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete asset?'),
        content: Text(
          'Delete "${asset.title}" and its locally stored file from this device?',
        ),
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
      await controller.deleteAsset(asset.id);
      _showMessage('Asset deleted.');
    } catch (error) {
      _showMessage('Unable to delete asset: $error');
    }
  }

  List<RigAsset> _visibleAssets() {
    final query = _searchController.text.trim().toLowerCase();
    return controller.assets.where((asset) {
      final matchesFilter = switch (_filter) {
        _AssetFilter.all => true,
        _AssetFilter.captures => asset.kind == RigAssetKind.ampCapture,
        _AssetFilter.cabinetIrs => asset.kind == RigAssetKind.cabinetIr,
        _AssetFilter.favorites => asset.isFavorite,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      final searchable = [
        asset.title,
        asset.originalFilename,
        asset.manufacturer,
        asset.model,
        asset.notes,
        ...asset.tags,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final assets = _visibleAssets();
        final captureCount = controller.assets
            .where((asset) => asset.kind == RigAssetKind.ampCapture)
            .length;
        final irCount = controller.assets
            .where((asset) => asset.kind == RigAssetKind.cabinetIr)
            .length;

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
                        'Asset Library',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Keep amp captures and cabinet IRs organized on this device.',
                        style: TextStyle(color: Color(0xFF9AA4B2)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: () => _importAsset(RigAssetKind.ampCapture),
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Import capture'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _importAsset(RigAssetKind.cabinetIr),
                    icon: const Icon(Icons.audio_file_outlined),
                    label: const Text('Import cabinet IR'),
                  ),
                ],
              ),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 12),
                _AssetNotice(
                  message: controller.errorMessage!,
                  warning: true,
                ),
              ],
              const SizedBox(height: 14),
              Text(
                '${controller.assets.length} assets  ·  $captureCount captures  ·  $irCount cabinet IRs',
                style: const TextStyle(
                  color: Color(0xFF9AA4B2),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by name, model, or tag',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('All', _AssetFilter.all),
                    _filterChip('Captures', _AssetFilter.captures),
                    _filterChip('Cabinet IRs', _AssetFilter.cabinetIrs),
                    _filterChip('Favorites', _AssetFilter.favorites),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const _AssetNotice(
                message:
                    'NAM and WAV files receive structure checks. AM2/AMP files are preserved unchanged and remain unverified. No KPT Pro compatibility or hardware loading is claimed.',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: assets.isEmpty
                    ? _AssetEmptyState(
                        hasAssets: controller.assets.isNotEmpty,
                        onImportCapture: () => _importAsset(RigAssetKind.ampCapture),
                        onImportIr: () => _importAsset(RigAssetKind.cabinetIr),
                      )
                    : ListView.separated(
                        itemCount: assets.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _AssetCard(
                              asset: assets[index],
                              onFavorite: () => controller.toggleFavorite(assets[index].id),
                              onEdit: () => _editAsset(assets[index]),
                              onDelete: () => _deleteAsset(assets[index]),
                            ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, _AssetFilter filter) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _filter == filter,
        onSelected: (_) => setState(() => _filter = filter),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.onFavorite,
    required this.onEdit,
    required this.onDelete,
  });

  final RigAsset asset;
  final VoidCallback onFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCapture = asset.kind == RigAssetKind.ampCapture;
    final subtitle = [
      if (asset.manufacturer.isNotEmpty) asset.manufacturer,
      if (asset.model.isNotEmpty) asset.model,
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF39231F),
                  child: Icon(
                    isCapture ? Icons.electric_bolt : Icons.graphic_eq,
                    color: const Color(0xFFFF987B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle.isEmpty ? asset.originalFilename : subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9AA4B2),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: asset.isFavorite ? 'Remove favorite' : 'Add favorite',
                  onPressed: onFavorite,
                  icon: Icon(
                    asset.isFavorite ? Icons.star : Icons.star_border,
                    color: asset.isFavorite
                        ? const Color(0xFFFFC078)
                        : const Color(0xFF8993A1),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Asset actions',
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit details')),
                    PopupMenuItem(value: 'delete', child: Text('Delete asset')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _AssetTag(label: isCapture ? 'AMP CAPTURE' : 'CABINET IR'),
                _AssetTag(label: asset.extension.toUpperCase()),
                _AssetTag(
                  label: asset.validation == RigAssetValidation.validated
                      ? 'STRUCTURE CHECKED'
                      : 'UNVERIFIED',
                  warning: asset.validation == RigAssetValidation.unverified,
                ),
                _AssetTag(label: _formatBytes(asset.fileSizeBytes)),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              asset.formatSummary,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFADB6C2),
                height: 1.4,
              ),
            ),
            if (asset.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: asset.tags.take(8).map((tag) {
                  return Chip(
                    label: Text(tag),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    labelStyle: const TextStyle(fontSize: 10),
                  );
                }).toList(),
              ),
            ],
            if (asset.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                asset.notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8993A1),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KiB';
  }
}

class _AssetTag extends StatelessWidget {
  const _AssetTag({required this.label, this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFF2D251D) : const Color(0xFF202630),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: warning ? const Color(0xFF6A5030) : const Color(0xFF343D49),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
          color: warning ? const Color(0xFFFFC078) : const Color(0xFFB3BCC8),
        ),
      ),
    );
  }
}

class _AssetNotice extends StatelessWidget {
  const _AssetNotice({required this.message, this.warning = false});

  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFF211B18) : const Color(0xFF171D24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warning ? const Color(0xFF5B3B30) : const Color(0xFF303844),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_outlined : Icons.info_outline,
            size: 17,
            color: warning ? const Color(0xFFFFA083) : const Color(0xFF9AA4B2),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: warning ? const Color(0xFFE3B8A9) : const Color(0xFFADB6C2),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetEmptyState extends StatelessWidget {
  const _AssetEmptyState({
    required this.hasAssets,
    required this.onImportCapture,
    required this.onImportIr,
  });

  final bool hasAssets;
  final VoidCallback onImportCapture;
  final VoidCallback onImportIr;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_open_outlined,
                size: 40,
                color: Color(0xFF788391),
              ),
              const SizedBox(height: 12),
              Text(
                hasAssets ? 'No matching assets' : 'Your library is empty',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const SizedBox(height: 7),
              Text(
                hasAssets
                    ? 'Try another search or filter.'
                    : 'Import a capture or cabinet impulse response to start building your local library.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF9AA4B2), height: 1.4),
              ),
              if (!hasAssets) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onImportCapture,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Add first capture'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onImportIr,
                      icon: const Icon(Icons.audio_file_outlined),
                      label: const Text('Add first IR'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetMetadataDraft {
  const _AssetMetadataDraft({
    required this.title,
    required this.manufacturer,
    required this.model,
    required this.tags,
    required this.notes,
  });

  final String title;
  final String manufacturer;
  final String model;
  final List<String> tags;
  final String notes;
}

class _AssetMetadataDialog extends StatefulWidget {
  const _AssetMetadataDialog({
    required this.title,
    required this.initialTitle,
    required this.initialManufacturer,
    required this.initialModel,
    required this.initialTags,
    required this.initialNotes,
  });

  final String title;
  final String initialTitle;
  final String initialManufacturer;
  final String initialModel;
  final String initialTags;
  final String initialNotes;

  @override
  State<_AssetMetadataDialog> createState() => _AssetMetadataDialogState();
}

class _AssetMetadataDialogState extends State<_AssetMetadataDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _manufacturerController;
  late final TextEditingController _modelController;
  late final TextEditingController _tagsController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _manufacturerController = TextEditingController(
      text: widget.initialManufacturer,
    );
    _modelController = TextEditingController(text: widget.initialModel);
    _tagsController = TextEditingController(text: widget.initialTags);
    _notesController = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      _AssetMetadataDraft(
        title: title,
        manufacturer: _manufacturerController.text.trim(),
        model: _modelController.text.trim(),
        tags: _tagsController.text.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(),
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Asset name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _manufacturerController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Manufacturer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _modelController,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Gear / model',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tagsController,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'clean, edge-of-breakup, worship',
                helperText: 'Separate tags with commas (up to 20 tags).',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save asset'),
        ),
      ],
    );
  }
}
