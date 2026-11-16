import 'package:material_ui/material_ui.dart';

import '../models/effect_block.dart';

class EffectBlockEditorDialog extends StatefulWidget {
  const EffectBlockEditorDialog({
    required this.block,
    super.key,
  });

  final EffectBlock block;

  @override
  State<EffectBlockEditorDialog> createState() =>
      _EffectBlockEditorDialogState();
}

class _EffectBlockEditorDialogState extends State<EffectBlockEditorDialog> {
  late final TextEditingController _nameController;
  late Map<String, double> _parameters;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.block.name);
    _parameters = Map<String, double>.from(widget.block.parameters);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final specs = effectParameterSpecs[widget.block.family] ??
        <EffectParameterSpec>[];

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
              TextField(
                controller: _nameController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Block name',
                  border: OutlineInputBorder(),
                ),
              ),
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
              const Text(
                'These are local workspace values. Their names and ranges are generic editor parameters, not verified KPT Pro firmware controls.',
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
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              widget.block.copyWith(
                name: name,
                parameters: Map<String, double>.from(_parameters),
              ),
            );
          },
          child: const Text('Save changes'),
        ),
      ],
    );
  }
}
