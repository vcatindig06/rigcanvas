import 'package:material_ui/material_ui.dart';

import '../models/effect_block.dart';
import '../models/rig_asset.dart';
import 'effect_model_picker_dialog.dart';

class EffectBlockEditorDialog extends StatefulWidget {
  const EffectBlockEditorDialog({
    required this.block,
    required this.assets,
    super.key,
  });

  final EffectBlock block;
  final List<RigAsset> assets;

  @override
  State<EffectBlockEditorDialog> createState() =>
      _EffectBlockEditorDialogState();
}

class _EffectBlockEditorDialogState extends State<EffectBlockEditorDialog> {
  late String _modelId;
  late Map<String, double> _parameters;
  late String? _assetId;
  bool _assetLinkAcknowledged = false;

  RigAssetKind? get _assetKind {
    switch (widget.block.family) {
      case EffectFamily.amplifier:
        return RigAssetKind.ampCapture;
      case EffectFamily.cabinet:
        return RigAssetKind.cabinetIr;
      default:
        return null;
    }
  }

  List<RigAsset> get _compatibleAssets => widget.assets
      .where((asset) => asset.kind == _assetKind)
      .toList(growable: false);

  RigAsset? get _selectedAsset {
    for (final asset in _compatibleAssets) {
      if (asset.id == _assetId) return asset;
    }
    return null;
  }

  bool get _hasMissingLink =>
      _assetId != null && _selectedAsset == null;

  bool get _requiresAcknowledgement =>
      _assetId != null && _assetId != widget.block.assetId;

  bool get _canSave =>
      !_hasMissingLink &&
      (!_requiresAcknowledgement || _assetLinkAcknowledged);

  @override
  void initState() {
    super.initState();
    _modelId = widget.block.modelId;
    _parameters = Map<String, double>.from(widget.block.parameters);
    _assetId = widget.block.assetId;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _chooseModel() async {
    final selected = await showDialog<EffectModelDefinition>(
      context: context,
      builder: (context) => EffectModelPickerDialog(
        initialFamily: widget.block.family,
      ),
    );
    if (selected == null) return;
    setState(() => _modelId = selected.id);
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final specs = effectParameterSpecs[widget.block.family] ??
        <EffectParameterSpec>[];
    final assetLabel = widget.block.family == EffectFamily.amplifier
        ? 'Amp capture'
        : 'Cabinet impulse response';

    return AlertDialog(
      title: Row(
        children: [
          Icon(widget.block.family.icon, color: const Color(0xFFFF987B)),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.block.family.label)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MODEL CATALOG',
                style: TextStyle(
                  color: Color(0xFF9AA4B2),
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF171D24),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF39434F)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            EffectModelCatalog.byId(_modelId)?.name ?? 'Select model',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            EffectModelCatalog.byId(_modelId)?.source.label ?? '',
                            style: const TextStyle(
                              color: Color(0xFFFFC078),
                              fontSize: 9,
                              letterSpacing: 0.3,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('effect-model-change'),
                      onPressed: _chooseModel,
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Change'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                EffectModelCatalog.byId(_modelId)?.description ?? '',
                style: const TextStyle(
                  color: Color(0xFF9AA4B2),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              if (_assetKind != null) ...[
                const SizedBox(height: 18),
                const Text(
                  'LINKED LIBRARY ASSET',
                  style: TextStyle(
                    color: Color(0xFF9AA4B2),
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('asset-link-dropdown'),
                  initialValue: _assetId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: assetLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No asset linked'),
                    ),
                    for (final asset in _compatibleAssets)
                      DropdownMenuItem<String?>(
                        value: asset.id,
                        child: Text(
                          '${asset.title} · ${asset.extension.toUpperCase()} · '
                          '${asset.validation == RigAssetValidation.validated ? 'FORMAT CHECKED' : 'UNVERIFIED'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (_hasMissingLink)
                      DropdownMenuItem<String?>(
                        value: _assetId,
                        child: const Text('Missing asset reference'),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _assetId = value;
                      _assetLinkAcknowledged = false;
                    });
                  },
                ),
                if (_selectedAsset case final selectedAsset?) ...[
                  const SizedBox(height: 10),
                  _AssetAssignmentNotice(asset: selectedAsset),
                  if (_requiresAcknowledgement) ...[
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _assetLinkAcknowledged,
                      onChanged: (value) {
                        setState(
                          () => _assetLinkAcknowledged = value ?? false,
                        );
                      },
                      title: const Text(
                        'I understand playback and device compatibility are unverified and this only saves a local reference.',
                        style: TextStyle(fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ],
                if (_hasMissingLink) ...[
                  const SizedBox(height: 10),
                  const _MissingAssetNotice(),
                ],
              ],
              if (specs.isNotEmpty) ...[
                const SizedBox(height: 18),
                for (final spec in specs) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          spec.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${_formatValue(_parameters[spec.key] ?? spec.initial)} ${spec.unit}',
                        style: const TextStyle(
                          color: Color(0xFFFFB29D),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: (_parameters[spec.key] ?? spec.initial)
                        .clamp(spec.minimum, spec.maximum)
                        .toDouble(),
                    min: spec.minimum,
                    max: spec.maximum,
                    divisions: spec.divisions,
                    onChanged: (value) {
                      setState(() => _parameters[spec.key] = value);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              const Text(
                'Model selection chooses a catalog label and generic family DSP for the offline Audio test. It does not emulate the named factory algorithm or control the KPT Pro.',
                style: TextStyle(
                  color: Color(0xFF9AA4B2),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave
              ? () {
                  final selectedModel = EffectModelCatalog.byId(_modelId);
                  if (selectedModel == null) return;
                  Navigator.of(context).pop(
                    widget.block.copyWith(
                      modelId: selectedModel.id,
                      description: selectedModel.description,
                      parameters: Map<String, double>.from(_parameters),
                      assetId: _assetId,
                      clearAssetId: _assetId == null,
                    ),
                  );
                }
              : null,
          child: const Text('Save changes'),
        ),
      ],
    );
  }
}

class _AssetAssignmentNotice extends StatelessWidget {
  const _AssetAssignmentNotice({required this.asset});

  final RigAsset asset;

  @override
  Widget build(BuildContext context) {
    final structureChecked =
        asset.validation == RigAssetValidation.validated;
    final compatibilityDetail = asset.kind == RigAssetKind.ampCapture
        ? asset.extension == '.nam'
            ? 'NAM JSON structure checked. Supported model architecture, version, and playback-runtime compatibility are not confirmed.'
            : 'AM2/AMP capture bytes are stored unchanged. Their internal structure and playback-runtime compatibility are not confirmed.'
        : 'WAV metadata detected: ${asset.formatSummary}. The offline Audio test decodes supported PCM / IEEE-float mono or stereo WAV and resamples it to 48 kHz, but this does not establish manufacturer-model accuracy or KPT Pro compatibility.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF211B18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5B3B30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                structureChecked
                    ? Icons.fact_check_outlined
                    : Icons.warning_amber_outlined,
                size: 17,
                color: structureChecked
                    ? const Color(0xFF9BDBAC)
                    : const Color(0xFFFFC078),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  structureChecked
                      ? 'File structure checked'
                      : 'File format not verified',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            structureChecked
                ? 'The file passed a format check. The offline DSP test can load supported PCM / IEEE-float mono or stereo IRs, but that does not prove accurate cabinet modeling or KPT Pro support.'
                : 'This capture is stored unchanged. Its internal format has not been verified, so it must not be treated as loadable or compatible.',
            style: const TextStyle(
              color: Color(0xFFE3B8A9),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            compatibilityDetail,
            style: const TextStyle(
              color: Color(0xFFE3B8A9),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Assignment saves a local library reference. The Audio page can use a compatible Cabinet WAV in an offline test; live audio and hardware writes remain disabled.',
            style: TextStyle(
              color: Color(0xFFE3B8A9),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingAssetNotice extends StatelessWidget {
  const _MissingAssetNotice();

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
      child: const Text(
        'This block points to an asset that is missing or has the wrong asset type. Choose a matching asset or select “No asset linked”.',
        style: TextStyle(
          color: Color(0xFFE3B8A9),
          fontSize: 11,
          height: 1.4,
        ),
      ),
    );
  }
}
