import 'package:material_ui/material_ui.dart';

import '../models/effect_block.dart';

class EffectModelPickerDialog extends StatefulWidget {
  const EffectModelPickerDialog({
    this.initialFamily,
    super.key,
  });

  final EffectFamily? initialFamily;

  @override
  State<EffectModelPickerDialog> createState() =>
      _EffectModelPickerDialogState();
}

class _EffectModelPickerDialogState extends State<EffectModelPickerDialog> {
  late EffectFamily _family;
  AmpModelType? _ampTypeFilter;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _family = widget.initialFamily ?? EffectFamily.gate;
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EffectModelDefinition> get _models {
    final query = _searchController.text.trim().toLowerCase();
    return EffectModelCatalog.forFamily(_family)
        .where((model) {
          final matchesAmpType = _family != EffectFamily.amplifier ||
              _ampTypeFilter == null ||
              model.ampType == _ampTypeFilter;
          final matchesQuery = query.isEmpty ||
              model.name.toLowerCase().contains(query) ||
              model.description.toLowerCase().contains(query) ||
              model.source.label.toLowerCase().contains(query);
          return matchesAmpType && matchesQuery;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final dialogWidth = (screen.width - 40).clamp(280.0, 540.0).toDouble();
    final dialogHeight = (screen.height - 160).clamp(320.0, 560.0).toDouble();
    final results = _models;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.library_add, color: Color(0xFFFF987B)),
          SizedBox(width: 10),
          Expanded(child: Text('Add effect block')),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<EffectFamily>(
              key: const ValueKey('effect-family-filter'),
              initialValue: _family,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Effect category',
                border: OutlineInputBorder(),
              ),
              items: EffectFamily.values
                  .map((family) => DropdownMenuItem<EffectFamily>(
                        value: family,
                        child: Row(
                          children: [
                            Icon(family.icon, size: 18),
                            const SizedBox(width: 9),
                            Text(family.label),
                            const Spacer(),
                            Text(
                              EffectModelCatalog.forFamily(family).length.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9AA4B2),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _family = value;
                  _ampTypeFilter = null;
                  _searchController.clear();
                });
              },
            ),
            if (_family == EffectFamily.amplifier) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<AmpModelType?>(
                key: const ValueKey('amp-type-filter'),
                initialValue: _ampTypeFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'AMP type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<AmpModelType?>(
                    value: null,
                    child: Text('All amp types'),
                  ),
                  ...AmpModelType.values.map(
                    (type) => DropdownMenuItem<AmpModelType?>(
                      value: type,
                      child: Text(type.labelWithCode),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _ampTypeFilter = value);
                },
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('effect-model-search'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search ' + _family.label.toLowerCase() + ' models',
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
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    results.length.toString() + ' available options',
                    style: const TextStyle(
                      color: Color(0xFF9AA4B2),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _SourceLegend(),
              ],
            ),
            const SizedBox(height: 5),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text(
                        'No models match this search.',
                        style: TextStyle(color: Color(0xFF9AA4B2)),
                      ),
                    )
                  : ListView.separated(
                      key: const ValueKey('effect-model-results'),
                      itemCount: results.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFF303844)),
                      itemBuilder: (context, index) {
                        final model = results[index];
                        return ListTile(
                          key: ValueKey('effect-model-' + model.id),
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          title: Text(
                            model.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            (model.ampTypeLabel == null
                                    ? ''
                                    : model.ampTypeLabel! + ' · ') +
                                model.instrumentLabel + ' · ' + model.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, height: 1.2),
                          ),
                          trailing: _ModelSourceTag(source: model.source),
                          onTap: () => Navigator.of(context).pop(model),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 5),
            const Text(
              'KPT Pro Factory entries reflect the documented factory catalog. RigCanvas Library entries are additional editor choices, not KPT Pro factory models.',
              style: TextStyle(
                color: Color(0xFF9AA4B2),
                fontSize: 10,
                height: 1.35,
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

class _SourceLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModelSourceTag(source: EffectModelSource.kptProFactory),
        SizedBox(width: 5),
        _ModelSourceTag(source: EffectModelSource.rigcanvasExpanded),
      ],
    );
  }
}

class _ModelSourceTag extends StatelessWidget {
  const _ModelSourceTag({required this.source});

  final EffectModelSource source;

  @override
  Widget build(BuildContext context) {
    final isKpt = source == EffectModelSource.kptProFactory;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isKpt ? const Color(0xFF33291D) : const Color(0xFF202832),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isKpt ? const Color(0xFF765532) : const Color(0xFF3D4C5B),
        ),
      ),
      child: Text(
        isKpt ? 'KPT PRO' : 'EXPANDED',
        style: TextStyle(
          color: isKpt ? const Color(0xFFFFC078) : const Color(0xFFB6C6D7),
          fontSize: 8,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
