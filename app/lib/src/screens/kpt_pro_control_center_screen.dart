import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../device/kpt_pro_native_file_inspector.dart';
import '../device/kpt_pro_write_plan.dart';
import '../state/preset_controller.dart';

class KptProControlCenterScreen extends StatefulWidget {
  const KptProControlCenterScreen({
    required this.presetController,
    super.key,
  });

  final PresetController presetController;

  @override
  State<KptProControlCenterScreen> createState() =>
      _KptProControlCenterScreenState();
}

class _KptProControlCenterScreenState
    extends State<KptProControlCenterScreen> {
  bool _exporting = false;
  bool _inspectingFile = false;
  String? _inspectionError;
  KptProNativeFileInspection? _fileInspection;

  Future<void> _inspectNativeExport() async {
    setState(() {
      _inspectingFile = true;
      _inspectionError = null;
      _fileInspection = null;
    });
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      if (file.size < 1 ||
          file.size > maximumNativePatchFileInspectionBytes) {
        throw const FormatException(
          'Choose a non-empty file that is 64 MiB or smaller.',
        );
      }
      final bytes = await file.readAsBytes();
      final result = KptProNativeFileInspection.inspect(
        filename: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _fileInspection = result);
    } catch (error) {
      if (mounted) setState(() => _inspectionError = error.toString());
    } finally {
      if (mounted) setState(() => _inspectingFile = false);
    }
  }

  Future<void> _copyFileInspectionReport() async {
    final inspection = _fileInspection;
    if (inspection == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert(inspection.toJson()),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File inspection report copied.')),
    );
  }

  Future<void> _exportLocalBackup() async {
    setState(() => _exporting = true);
    try {
      final source = widget.presetController.exportPresetLibraryBackupJson();
      final stamp = DateTime.now().toUtc().toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final result = await FilePicker.saveFile(
        fileName: 'rigcanvas-preset-library-$stamp.json',
        bytes: Uint8List.fromList(utf8.encode(source)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result == null
              ? 'Local backup export cancelled.'
              : 'Local preset-library backup exported.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup export failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.presetController,
      builder: (context, _) {
        final preset = widget.presetController.activePreset;
        final plan = preset == null
            ? null
            : const KptProWritePlanner().prepare(preset);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            const Text(
              'KPT Pro Control Center',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Prepare, review, and protect patches before any future device transfer.',
              style: TextStyle(color: Color(0xFF9AA4B2), height: 1.45),
            ),
            const SizedBox(height: 16),
            const _StatusCard(),
            const SizedBox(height: 12),
            _LocalPresetCard(
              presetName: preset?.name ?? 'No local preset loaded',
              blockCount: preset?.blocks.length ?? 0,
              sceneCount: preset?.scenes.length ?? 0,
              target: preset?.target ?? '—',
              exporting: _exporting,
              onExport: preset == null || _exporting ? null : _exportLocalBackup,
            ),
            const SizedBox(height: 12),
            _NativeFileInspectionCard(
              inspection: _fileInspection,
              busy: _inspectingFile,
              error: _inspectionError,
              onInspect: _inspectingFile ? null : _inspectNativeExport,
              onCopyReport: _fileInspection == null
                  ? null
                  : _copyFileInspectionReport,
            ),
            if (plan != null) ...[
              const SizedBox(height: 12),
              _WriteReadinessCard(plan: plan),
            ],
            const SizedBox(height: 12),
            const _ReferenceCard(),
            const SizedBox(height: 12),
            const _AlternativeRoutesCard(),
          ],
        );
      },
    );
  }
}

class _NativeFileInspectionCard extends StatelessWidget {
  const _NativeFileInspectionCard({
    required this.inspection,
    required this.busy,
    required this.error,
    required this.onInspect,
    required this.onCopyReport,
  });

  final KptProNativeFileInspection? inspection;
  final bool busy;
  final String? error;
  final VoidCallback? onInspect;
  final VoidCallback? onCopyReport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(
              icon: Icons.find_in_page_outlined,
              title: 'Native file inspection',
            ),
            const SizedBox(height: 7),
            const Text(
              'Select the exact file exported by M-EFCS. RigCanvas inspects it locally, calculates a SHA-256 fingerprint, identifies generic container signatures, and lists readable metadata. It does not upload, alter, decode into a patch, or send the file to the pedal.',
              style: TextStyle(
                color: Color(0xFF9AA4B2),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onInspect,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_open_outlined),
                label: Text(
                  busy ? 'Inspecting file…' : 'Inspect M-EFCS export',
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: const TextStyle(
                  color: Color(0xFFFFA38F),
                  fontSize: 12,
                ),
              ),
            ],
            if (inspection != null) ...[
              const Divider(height: 22),
              _InspectionRow(label: 'File', value: inspection!.filename),
              _InspectionRow(
                label: 'Size',
                value: inspection!.fileSizeLabel,
              ),
              _InspectionRow(
                label: 'Detected signature',
                value: inspection!.signature,
              ),
              _InspectionRow(
                label: 'Extension',
                value: inspection!.extension.isEmpty
                    ? 'No extension'
                    : inspection!.extension,
              ),
              _InspectionRow(
                label: 'SHA-256',
                value: inspection!.sha256,
                selectable: true,
              ),
              _InspectionRow(
                label: 'Sample entropy',
                value: inspection!.sampleEntropyBitsPerByte
                    .toStringAsFixed(3) + ' bits/byte',
              ),
              const SizedBox(height: 7),
              Text(
                inspection!.formatNote,
                style: const TextStyle(
                  color: Color(0xFFFFC078),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              if (inspection!.jsonRootKeys.isNotEmpty) ...[
                const SizedBox(height: 9),
                const Text(
                  'JSON root keys',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  inspection!.jsonRootKeys.join(' · '),
                  style: const TextStyle(
                    color: Color(0xFFADB6C2),
                    fontSize: 11,
                  ),
                ),
              ],
              if (inspection!.printableStrings.isNotEmpty) ...[
                const SizedBox(height: 9),
                const Text(
                  'Readable strings (sample)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 4),
                for (final value in inspection!.printableStrings.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFADB6C2),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 9),
              const Text(
                'First 48 bytes',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 4),
              SelectableText(
                inspection!.hexPreview,
                style: const TextStyle(
                  color: Color(0xFFADB6C2),
                  fontFamily: 'monospace',
                  fontSize: 10,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 11),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: onCopyReport,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy metadata report'),
                ),
              ),
              const Text(
                'This report identifies a generic file container only. It does not confirm that the file is a KPT Pro patch or establish any write command.',
                style: TextStyle(
                  color: Color(0xFFFFB49B),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InspectionRow extends StatelessWidget {
  const _InspectionRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8993A1),
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: selectable
                ? SelectableText(
                    value,
                    style: const TextStyle(
                      color: Color(0xFFADB6C2),
                      fontSize: 11,
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFFADB6C2),
                      fontSize: 11,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF271D19),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF70402F)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: Color(0xFFFFA27F), size: 20),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'HARDWARE WRITE LOCKED',
                  style: TextStyle(
                    color: Color(0xFFFFB49B),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 9),
          Text(
            'RigCanvas can inspect the connection and prepare local patch data, but it cannot yet read, edit, save, or import a native KPT Pro patch.',
            style: TextStyle(color: Color(0xFFE5D1C8), height: 1.45),
          ),
          SizedBox(height: 10),
          Text(
            'Owner-reported baseline: KPT Pro firmware v8 · M-EFCS Android v3.10.2311. This is not a live identity or protocol verification.',
            style: TextStyle(color: Color(0xFFB9A69E), fontSize: 11, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _LocalPresetCard extends StatelessWidget {
  const _LocalPresetCard({
    required this.presetName,
    required this.blockCount,
    required this.sceneCount,
    required this.target,
    required this.exporting,
    required this.onExport,
  });

  final String presetName;
  final int blockCount;
  final int sceneCount;
  final String target;
  final bool exporting;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(
              icon: Icons.library_music_outlined,
              title: 'Local preset preparation',
            ),
            const SizedBox(height: 11),
            Text(presetName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip('$blockCount blocks'),
                _InfoChip('$sceneCount scenes'),
                _InfoChip(target),
                const _InfoChip('RigCanvas format'),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Export a safety copy of every local preset, scene, and Grid layout. Asset IDs are retained, but NAM/AM2/IR asset files are not embedded.',
              style: TextStyle(color: Color(0xFF9AA4B2), height: 1.45, fontSize: 12),
            ),
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onExport,
                icon: exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_alt),
                label: Text(exporting
                    ? 'Exporting backup…'
                    : 'Export local preset-library backup'),
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'This is a RigCanvas backup only. It is not a backup read from the pedal and cannot be imported into M-EFCS as a native tone file.',
              style: TextStyle(color: Color(0xFFFFB49B), fontSize: 11, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _WriteReadinessCard extends StatelessWidget {
  const _WriteReadinessCard({required this.plan});

  final KptProWritePlan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(
              icon: Icons.rule_folder_outlined,
              title: 'Transfer readiness',
            ),
            const SizedBox(height: 9),
            Text('Preview for: ${plan.presetName}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Metadata-only plan. It does not create a vendor payload or contact the pedal.',
              style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 11),
            for (final blocker in plan.blockers)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.block, color: Color(0xFFFF9276), size: 17),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(blocker.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 3),
                          Text(blocker.detail,
                              style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 11, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(color: Color(0xFF343B45)),
            const Row(
              children: [
                Icon(Icons.lock, color: Color(0xFFFF9276), size: 17),
                SizedBox(width: 8),
                Text(
                  'Write disabled · No transfer bytes generated',
                  style: TextStyle(color: Color(0xFFFFB49B), fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(
              icon: Icons.menu_book_outlined,
              title: 'KPT Pro manual reference',
            ),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip('120 documented preset tones'),
                _InfoChip('7 named effect modules'),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'The manual names FX, AMP, MOD, DLY, REV, CAB, and EXT modules. These are documentation references, not a confirmed slot map or a verified RigCanvas-to-pedal mapping.',
              style: TextStyle(color: Color(0xFF9AA4B2), height: 1.45, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlternativeRoutesCard extends StatelessWidget {
  const _AlternativeRoutesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(
              icon: Icons.route_outlined,
              title: 'Capture-free investigation routes',
            ),
            const SizedBox(height: 11),
            const _RouteItem(
              number: '01',
              title: 'Passive BLE notification monitor',
              detail: 'Settings → Devices → connect → start the opt-in monitor. It collects unsolicited pedal notifications without sending a vendor request; it cannot retrieve data that the pedal only sends after a request.',
            ),
            const _RouteItem(
              number: '02',
              title: 'Official M-EFCS package inspection',
              detail: 'Inspect an owner-provided or official M-EFCS APK/desktop package for device IDs, model tables, resource names, file extensions, and protocol call structure. No package has been analyzed in this milestone.',
            ),
            const _RouteItem(
              number: '03',
              title: 'Native exported patch-file analysis',
              detail: 'A genuine M-EFCS whole-patch export can be examined without an HCI capture. Preserve its original extension and bytes. AM2 AMP data and cabinet IRs are separate from full patches.',
            ),
            const _RouteItem(
              number: '04',
              title: 'M-EFCS UI parameter inventory',
              detail: 'Record module order, model names, parameter labels, units, and displayed ranges manually. This informs the editor but does not reveal command IDs or prove write support.',
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteItem extends StatelessWidget {
  const _RouteItem({
    required this.number,
    required this.title,
    required this.detail,
  });

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 31,
            height: 31,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF30231F),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(number,
                style: const TextStyle(color: Color(0xFFFFA27F), fontWeight: FontWeight.w800, fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(detail,
                    style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 11, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF987B), size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      visualDensity: VisualDensity.compact,
      side: const BorderSide(color: Color(0xFF3B444F)),
      backgroundColor: const Color(0xFF20262E),
    );
  }
}
