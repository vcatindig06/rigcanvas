import 'package:material_ui/material_ui.dart';

import '../models/effect_block.dart';
import '../models/effect_catalog.dart';

class EffectCatalogPickerDialog extends StatefulWidget {
  const EffectCatalogPickerDialog({super.key});

  @override
  State<EffectCatalogPickerDialog> createState() =>
      _EffectCatalogPickerDialogState();
}

class _EffectCatalogPickerDialogState
    extends State<EffectCatalogPickerDialog> {
  EffectCatalogSource _source = EffectCatalogSource.rigCanvasSoftware;
  EffectFamily? _family;
  String _query = '';

  List<EffectCatalogEntry> get _visibleEntries {
    final query = _query.trim().toLowerCase();
    return effectCatalogFor(_source).where((entry) {
      final familyMatches = _family == null || entry.family == _family;
      final queryMatches = query.isEmpty ||
          entry.name.toLowerCase().contains(query) ||
          entry.description.toLowerCase().contains(query);
      return familyMatches && queryMatches;
    }).toList(growable: false);
  }

  bool get _showKptAmpCabNotice =>
      _source == EffectCatalogSource.kptProManual &&
      (_family == null ||
          _family == EffectFamily.amplifier ||
          _family == EffectFamily.cabinet);

  @override
  Widget build(BuildContext context) {
    final entries = _visibleEntries;
    return AlertDialog(
      title: const Text('Choose an effect model'),
      content: SizedBox(
        width: 560,
        height: 570,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<EffectCatalogSource>(
              segments: const [
                ButtonSegment(
                  value: EffectCatalogSource.rigCanvasSoftware,
                  label: Text('RigCanvas software'),
                  icon: Icon(Icons.tune),
                ),
                ButtonSegment(
                  value: EffectCatalogSource.kptProManual,
                  label: Text('KPT PRO factory'),
                  icon: Icon(Icons.memory),
                ),
              ],
              selected: {_source},
              onSelectionChanged: (selection) {
                setState(() {
                  _source = selection.first;
                  _family = null;
                  _query = '';
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('effect-catalog-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search models',
                hintText: 'e.g. Tube Screamer, Tape Echo, Hall',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<EffectFamily?>(
              key: const ValueKey('effect-catalog-family-filter'),
              initialValue: _family,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<EffectFamily?>(
                  value: null,
                  child: Text('All categories'),
                ),
                for (final family in EffectFamily.values)
                  DropdownMenuItem<EffectFamily?>(
                    value: family,
                    child: Text(family.label),
                  ),
              ],
              onChanged: (value) => setState(() => _family = value),
            ),
            if (_source == EffectCatalogSource.kptProManual) ...[
              const SizedBox(height: 10),
              const Text(
                'Manual-documented KPT PRO choices. Firmware v15 control mapping is not yet device-verified.',
                style: TextStyle(
                  color: Color(0xFFFFB29D),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              const Text(
                'RigCanvas software templates. Audio processing is not implemented yet and these models are not KPT PRO factory entries.',
                style: TextStyle(
                  color: Color(0xFF9AA4B2),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
            if (_showKptAmpCabNotice) ...[
              const SizedBox(height: 8),
              const Text(
                'The KPT PRO manual reports 50 guitar + 10 bass AMP and CAB models, but does not publish their individual names. Those factory slots are intentionally not given invented names.',
                style: TextStyle(
                  color: Color(0xFFB8C0CC),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: Text(
                        'No named models match this category yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF9AA4B2)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          leading: Icon(
                            entry.family.icon,
                            color: entry.source ==
                                    EffectCatalogSource.kptProManual
                                ? const Color(0xFFFFB29D)
                                : const Color(0xFF9AA4B2),
                          ),
                          title: Text(entry.name),
                          subtitle: Text(
                            '${entry.family.label} · ${entry.description}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => Navigator.of(context).pop(entry),
                        );
                      },
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
      ],
    );
  }
}
