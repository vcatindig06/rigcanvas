import 'package:material_ui/material_ui.dart';

import '../audio/rigcanvas_dsp_engine.dart';
import '../audio/wav_ir_decoder.dart';
import '../models/effect_block.dart';
import '../models/rig_asset.dart';
import '../models/rig_preset.dart';
import '../state/asset_controller.dart';
import '../state/preset_controller.dart';

/// A live control/readback surface for the shared native software DSP graph.
/// It does not communicate with the physical KPT Pro.
class DspControlSurface extends StatefulWidget {
  const DspControlSurface({
    required this.preset,
    required this.controller,
    required this.assetController,
    super.key,
  });

  final RigPreset preset;
  final PresetController controller;
  final AssetController assetController;

  @override
  State<DspControlSurface> createState() => _DspControlSurfaceState();
}

class _DspControlSurfaceState extends State<DspControlSurface> {
  RigCanvasDspEngine? _engine;
  List<_DspNodeBinding> _nodes = const [];
  Map<String, Map<String, double>> _readback = const {};
  Map<String, bool> _enabled = const {};
  bool _loading = true;
  String? _error;
  String? _assetNotice;
  int _loadGeneration = 0;

  String _signature(RigPreset preset) {
    final blockSignature = preset.blocks.map((block) {
      final values = block.parameters.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return [
        block.id,
        block.modelId,
        block.enabled,
        block.assetId ?? '',
        for (final value in values) '${value.key}=${value.value}',
      ].join(':');
    }).join('|');
    final gridSignature = preset.grid.placements
        .map((placement) => '${placement.blockId}:${placement.row}:${placement.column}')
        .join('|');
    return '${preset.id}|$blockSignature|$gridSignature';
  }

  @override
  void initState() {
    super.initState();
    _loadGraph();
  }

  @override
  void didUpdateWidget(covariant DspControlSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_signature(oldWidget.preset) != _signature(widget.preset)) {
      _loadGraph();
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _engine?.dispose();
    super.dispose();
  }

  List<EffectBlock> _orderedBlocks(RigPreset preset) {
    final byId = {for (final block in preset.blocks) block.id: block};
    final placements = [...preset.grid.placements]
      ..sort((a, b) {
        final row = a.row.compareTo(b.row);
        return row != 0 ? row : a.column.compareTo(b.column);
      });
    return [
      for (final placement in placements)
        if (byId[placement.blockId] != null) byId[placement.blockId]!,
    ];
  }

  List<_DspControlSpec>? _controlsFor(EffectBlock block) {
    const unit = _DspControlSpec.new;
    switch (block.family) {
      case EffectFamily.gate:
        if (block.modelId.contains('gate') || block.modelId == 'kpt.fx.ai_gate') {
          return [
            unit('threshold', 'Threshold', 0, -80, 0, -48),
            unit('ratio', 'Ratio', 1, 1, 20, 3),
            unit('attack', 'Attack', 2, 0.1, 1000, 10),
            unit('release', 'Release', 3, 5, 3000, 120),
            unit('makeup', 'Makeup', 4, -24, 24, 0),
            unit('mix', 'Mix', 5, 0, 100, 100, scale: 0.01),
          ];
        }
        return [
          unit('threshold', 'Threshold', 0, -80, 0, -24),
          unit('ratio', 'Ratio', 1, 1, 20, 3),
          unit('attack', 'Attack', 2, 0.1, 1000, 10),
          unit('release', 'Release', 3, 5, 3000, 120),
          unit('makeup', 'Makeup', 4, -24, 24, 0),
          unit('mix', 'Mix', 5, 0, 100, 100, scale: 0.01),
        ];
      case EffectFamily.drive:
        return [
          unit('gain', 'Gain', 0, 0, 100, 35, scale: 0.24),
          unit('tone', 'Tone', 1, 0, 100, 55, scale: 0.01),
          unit('level', 'Level', 2, 0, 100, 65, scale: 0.24, offset: -12),
          unit('blend', 'Blend', 3, 0, 100, 100, scale: 0.01),
        ];
      case EffectFamily.amplifier:
        return [
          unit('gain', 'Gain', 0, 0, 100, 48, scale: 0.24),
          unit('bass', 'Bass', 1, 0, 100, 50, scale: 0.24, offset: -12),
          unit('mid', 'Middle', 2, 0, 100, 58, scale: 0.24, offset: -12),
          unit('treble', 'Treble', 3, 0, 100, 52, scale: 0.24, offset: -12),
          unit('presence', 'Presence', 4, 0, 100, 45, scale: 0.24, offset: -12),
          unit('master', 'Master', 5, 0, 100, 70, scale: 0.24, offset: -12),
        ];
      case EffectFamily.cabinet:
        return [
          unit('irMix', 'IR Mix', 0, 0, 100, block.assetId == null ? 0 : 100, scale: 0.01),
          unit('level', 'Level', 1, -24, 12, 0),
          unit('lowCut', 'Low Cut', 2, 20, 500, 80),
          unit('highCut', 'High Cut', 3, 2000, 20000, 11000),
        ];
      case EffectFamily.modulation:
        if (block.modelId.contains('phaser')) {
          return [
            unit('rate', 'Rate', 0, 0.1, 10, 0.8),
            unit('depth', 'Depth', 1, 0, 100, 65),
            unit('feedback', 'Feedback', 2, 0, 85, 35),
            unit('mix', 'Mix', 3, 0, 100, 45),
          ];
        }
        if (['autofilter', 'wah', 'sense_wah'].any(block.modelId.contains)) {
          return [
            unit('sensitivity', 'Sensitivity', 0, 0.1, 10, 2.5),
            unit('depth', 'Depth', 1, 0, 100, 78),
            unit('resonance', 'Resonance', 2, 0, 100, 68),
            unit('mix', 'Mix', 3, 0, 100, 60),
          ];
        }
        if (block.modelId.contains('rotary')) {
          return [
            unit('speed', 'Speed', 0, 0.1, 10, 1.5),
            unit('depth', 'Depth', 1, 0, 100, 60),
            unit('tone', 'Tone', 2, 0, 100, 58),
            unit('mix', 'Mix', 3, 0, 100, 75),
          ];
        }
        if (['univibe', 'ring_mod', 'micro_pitch'].any(block.modelId.contains)) {
          return null;
        }
        return [
          unit('rate', 'Rate', 0, 0.1, 10, 1.2),
          unit('depth', 'Depth', 1, 0, 100, 45),
          unit('tone', 'Tone', 2, 0, 100, 55),
          unit('mix', 'Mix', 3, 0, 100, 25),
        ];
      case EffectFamily.delay:
        if (['duck', 'reverse', 'tape', 'lofi', 'multi_tap', 'dual', 'granular']
            .any(block.modelId.contains)) return null;
        return [
          unit('time', 'Time', 0, 1, 2000, 480),
          unit('feedback', 'Feedback', 1, 0, 95, 32),
          unit('highCut', 'High Cut', 2, 1000, 20000, 9000),
          unit('mix', 'Mix', 3, 0, 100, 24),
        ];
      case EffectFamily.reverb:
        return [
          unit('decay', 'Decay', 0, 0.1, 60, 5.5),
          unit('predelay', 'Pre-delay', 1, 0, 250, 25),
          unit('tone', 'Tone', 2, 0, 100, 55),
          unit('mix', 'Mix', 3, 0, 100, 30),
        ];
      case EffectFamily.eq:
        return [
          unit('lowGain', 'Low', 0, -18, 18, 0),
          unit('lowMidGain', 'Low Mid', 1, -18, 18, 0),
          unit('highMidGain', 'High Mid', 2, -18, 18, 0),
          unit('highGain', 'High', 3, -18, 18, 0),
          unit('output', 'Output', 4, -24, 12, 0),
        ];
      case EffectFamily.pitch:
      case EffectFamily.expression:
        return null;
    }
  }

  DspNodeType? _nodeTypeFor(EffectBlock block) {
    switch (block.family) {
      case EffectFamily.gate:
        return DspNodeType.dynamics;
      case EffectFamily.drive:
        return DspNodeType.drive;
      case EffectFamily.amplifier:
        return DspNodeType.amplifier;
      case EffectFamily.cabinet:
        return DspNodeType.cabinet;
      case EffectFamily.modulation:
        return DspNodeType.modulation;
      case EffectFamily.delay:
        return DspNodeType.delay;
      case EffectFamily.reverb:
        return DspNodeType.reverb;
      case EffectFamily.eq:
        return DspNodeType.equalizer;
      case EffectFamily.pitch:
      case EffectFamily.expression:
        return null;
    }
  }

  Future<void> _loadGraph() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _assetNotice = null;
      });
    }
    final previousEngine = _engine;
    _engine = null;
    previousEngine?.dispose();
    final nextEngine = RigCanvasDspEngine();
    final nextNodes = <_DspNodeBinding>[];
    final assetNotices = <String>[];
    try {
      for (final block in _orderedBlocks(widget.preset)) {
        final controls = _controlsFor(block);
        final type = _nodeTypeFor(block);
        if (controls == null || type == null) continue;

        final dynamicsMode = block.modelId.contains('gate') ||
                block.modelId == 'kpt.fx.ai_gate'
            ? DspDynamicsMode.gate : DspDynamicsMode.compressor;
        final modulationMode = block.modelId.contains('phaser')
            ? DspModulationMode.phaser
            : ['autofilter', 'wah', 'sense_wah'].any(block.modelId.contains)
                ? DspModulationMode.autoWah
                : block.modelId.contains('rotary')
                    ? DspModulationMode.rotary
                    : block.modelId.contains('tremolo')
                        ? DspModulationMode.tremolo
                        : block.modelId.contains('flanger')
                            ? DspModulationMode.flanger
                            : block.modelId.contains('vibrato')
                                ? DspModulationMode.vibrato
                                : DspModulationMode.chorus;
        final delayMode = block.modelId.contains('ping_pong')
            ? DspDelayMode.pingPong : DspDelayMode.standard;
        final nodeIndex = nextEngine.addNode(
          type,
          dynamicsMode: dynamicsMode,
          modulationMode: modulationMode,
          delayMode: delayMode,
          enabled: block.enabled,
        );

        for (final control in controls) {
          final displayValue = block.parameters[control.key] ?? control.initial;
          nextEngine.setParameter(
            nodeIndex,
            control.parameterIndex,
            control.toNative(displayValue),
          );
        }

        if (block.family == EffectFamily.cabinet && block.assetId != null) {
          try {
            final bytes = await widget.assetController.readAssetBytes(block.assetId!);
            final decoded = WavIrDecoder.decode(bytes, targetSampleRateHz: nextEngine.sampleRate);
            nextEngine.setCabinetImpulseResponse(
              nodeIndex,
              decoded.samplesInterleaved,
              irChannels: decoded.channelCount,
            );
          } catch (error) {
            // Keep the block controllable but bypass its IR blend until the asset is readable.
            nextEngine.setParameter(nodeIndex, 0, 0);
            assetNotices.add('${block.name}: IR unavailable for DSP control preview — $error');
          }
        }
        nextNodes.add(_DspNodeBinding(block: block, nodeIndex: nodeIndex, controls: controls));
      }

      if (!mounted || generation != _loadGeneration) {
        nextEngine.dispose();
        return;
      }
      _engine?.dispose();
      _engine = nextEngine;
      _nodes = List.unmodifiable(nextNodes);
      _assetNotice = assetNotices.isEmpty ? null : assetNotices.join('\n');
      _refreshReadback(notify: false);
      setState(() => _loading = false);
    } catch (error) {
      nextEngine.dispose();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = 'Could not prepare native DSP controls: $error';
        _loading = false;
      });
    }
  }

  void _refreshReadback({bool notify = true}) {
    final engine = _engine;
    if (engine == null) return;
    final values = <String, Map<String, double>>{};
    final enabled = <String, bool>{};
    for (final node in _nodes) {
      values[node.block.id] = {
        for (final spec in node.controls)
          spec.key: spec.fromNative(engine.getParameter(node.nodeIndex, spec.parameterIndex)),
      };
      enabled[node.block.id] = engine.isNodeEnabled(node.nodeIndex);
    }
    if (notify && mounted) {
      setState(() {
        _readback = values;
        _enabled = enabled;
      });
    } else {
      _readback = values;
      _enabled = enabled;
    }
  }

  Future<void> _persistParameter(_DspNodeBinding node, _DspControlSpec spec, double value) async {
    try {
      final current = widget.preset.blocks.firstWhere((block) => block.id == node.block.id);
      final parameters = Map<String, double>.from(current.parameters)..[spec.key] = value;
      await widget.controller.updateBlock(current.copyWith(parameters: parameters));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save DSP parameter: $error')),
      );
    }
  }

  Future<void> _setEnabled(_DspNodeBinding node, bool enabled) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      engine.setNodeEnabled(node.nodeIndex, enabled);
      final actual = engine.isNodeEnabled(node.nodeIndex);
      setState(() => _enabled = {..._enabled, node.block.id: actual});
      final current = widget.preset.blocks.firstWhere((block) => block.id == node.block.id);
      await widget.controller.updateBlock(current.copyWith(enabled: actual));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not control DSP block: $error')),
      );
    }
  }

  void _setParameter(_DspNodeBinding node, _DspControlSpec spec, double value) {
    final engine = _engine;
    if (engine == null) return;
    try {
      engine.setParameter(node.nodeIndex, spec.parameterIndex, spec.toNative(value));
      final actual = spec.fromNative(engine.getParameter(node.nodeIndex, spec.parameterIndex));
      setState(() => _readback = {
        ..._readback,
        node.block.id: {...?_readback[node.block.id], spec.key: actual},
      });
    } catch (error) {
      setState(() => _error = 'DSP control rejected value: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'SOFTWARE MULTI-FX CONTROL',
                    style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('read-dsp-state'),
                  onPressed: _loading || _engine == null ? null : () => _refreshReadback(),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Read DSP state'),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'Controls write directly to the shared native DSP graph. Read DSP state fetches the values back from the native engine. This is the software rack, not the physical KPT Pro.',
              style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 12, height: 1.4),
            ),
            if (_loading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              const Text('Preparing DSP graph…', style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 11)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFFF987B), fontSize: 12)),
            ],
            if (_assetNotice != null) ...[
              const SizedBox(height: 10),
              Text(_assetNotice!, style: const TextStyle(color: Color(0xFFFFB08E), fontSize: 11)),
            ],
            if (!_loading && _nodes.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'This preset has no currently implemented DSP blocks. Unsupported models remain in the preset and are not silently substituted.',
                style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 12),
              ),
            ],
            for (final node in _nodes) ...[
              const Divider(height: 20),
              ExpansionTile(
                key: ValueKey('dsp-node-${node.block.id}'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 10),
                title: Text(node.block.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${_enabled[node.block.id] == true ? 'ACTIVE' : 'BYPASSED'} · ${node.block.family.label}',
                  style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 10, letterSpacing: 0.5),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('On', style: TextStyle(fontSize: 11, color: Color(0xFF9AA4B2))),
                    Switch(
                      value: _enabled[node.block.id] ?? node.block.enabled,
                      onChanged: _loading ? null : (value) => _setEnabled(node, value),
                    ),
                  ],
                ),
                children: [
                  for (final spec in node.controls)
                    _DspParameterSlider(
                      spec: spec,
                      value: _readback[node.block.id]?[spec.key] ?? spec.initial,
                      onChanged: (value) => _setParameter(node, spec, value),
                      onChangeEnd: (value) => _persistParameter(node, spec, value),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DspNodeBinding {
  const _DspNodeBinding({
    required this.block,
    required this.nodeIndex,
    required this.controls,
  });
  final EffectBlock block;
  final int nodeIndex;
  final List<_DspControlSpec> controls;
}

class _DspControlSpec {
  const _DspControlSpec(
    this.key,
    this.label,
    this.parameterIndex,
    this.minimum,
    this.maximum,
    this.initial, {
    this.scale = 1,
    this.offset = 0,
  });

  final String key;
  final String label;
  final int parameterIndex;
  final double minimum;
  final double maximum;
  final double initial;
  final double scale;
  final double offset;

  double toNative(double value) => value * scale + offset;
  double fromNative(double value) => (value - offset) / scale;
}

class _DspParameterSlider extends StatelessWidget {
  const _DspParameterSlider({
    required this.spec,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final _DspControlSpec spec;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  String _format(double value) =>
      value.abs() >= 100 ? value.toStringAsFixed(0) :
      value.abs() >= 10 ? value.toStringAsFixed(1) :
      value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(spec.minimum, spec.maximum).toDouble();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(spec.label, style: const TextStyle(fontSize: 12))),
              Text(_format(safeValue), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            min: spec.minimum,
            max: spec.maximum,
            value: safeValue,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}
