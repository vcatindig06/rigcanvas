import 'package:material_ui/material_ui.dart';

import '../audio/rigcanvas_dsp_engine.dart';
import '../models/effect_block.dart';
import '../models/rig_preset.dart';
import '../state/preset_controller.dart';

class AudioEngineScreen extends StatefulWidget {
  const AudioEngineScreen({required this.controller, super.key});

  final PresetController controller;

  @override
  State<AudioEngineScreen> createState() => _AudioEngineScreenState();
}

class _AudioEngineScreenState extends State<AudioEngineScreen> {
  bool _isRunning = false;
  DspProcessMetrics? _metrics;
  String? _error;
  String? _testedPresetId;
  List<String> _skippedBlocks = const [];

  List<EffectBlock> _orderedBlocks(RigPreset preset) {
    final byId = {for (final block in preset.blocks) block.id: block};
    final placements = [...preset.grid.placements]
      ..sort((a, b) {
        final row = a.row.compareTo(b.row);
        return row != 0 ? row : a.column.compareTo(b.column);
      });
    final result = <EffectBlock>[];
    for (final placement in placements) {
      final block = byId[placement.blockId];
      if (block != null) result.add(block);
    }
    return result;
  }

  DspProcessMetrics _processPreset(RigPreset preset) {
    final engine = RigCanvasDspEngine();
    final skipped = <String>[];
    try {
      for (final block in _orderedBlocks(preset)) {
        if (!block.enabled) continue;

        switch (block.family) {
          case EffectFamily.gate:
            final isGate =
                block.modelId.contains('gate') ||
                block.modelId == 'kpt.fx.ai_gate';
            final node = engine.addNode(
              DspNodeType.dynamics,
              dynamicsMode: isGate
                  ? DspDynamicsMode.gate
                  : DspDynamicsMode.compressor,
            );
            engine.setParameter(node, 0, block.parameters['threshold'] ?? -48);
            engine.setParameter(node, 1, block.parameters['ratio'] ?? 3);
            engine.setParameter(node, 2, block.parameters['attack'] ?? 10);
            engine.setParameter(node, 3, block.parameters['release'] ?? 120);
            engine.setParameter(node, 4, block.parameters['makeup'] ?? 0);
            engine.setParameter(node, 5, (block.parameters['mix'] ?? 100) / 100);
            break;
          case EffectFamily.drive:
            final node = engine.addNode(DspNodeType.drive);
            engine.setParameter(node, 0, (block.parameters['gain'] ?? 35) * 0.24);
            engine.setParameter(node, 1, (block.parameters['tone'] ?? 55) / 100);
            engine.setParameter(
              node,
              2,
              ((block.parameters['level'] ?? 65) - 50) * 0.24,
            );
            engine.setParameter(node, 3, (block.parameters['blend'] ?? 100) / 100);
            break;
          case EffectFamily.amplifier:
            final node = engine.addNode(DspNodeType.amplifier);
            engine.setParameter(node, 0, (block.parameters['gain'] ?? 48) * 0.24);
            engine.setParameter(
              node,
              1,
              ((block.parameters['bass'] ?? 50) - 50) * 0.24,
            );
            engine.setParameter(
              node,
              2,
              ((block.parameters['mid'] ?? 58) - 50) * 0.24,
            );
            engine.setParameter(
              node,
              3,
              ((block.parameters['treble'] ?? 52) - 50) * 0.24,
            );
            engine.setParameter(
              node,
              4,
              ((block.parameters['presence'] ?? 45) - 50) * 0.24,
            );
            engine.setParameter(
              node,
              5,
              ((block.parameters['master'] ?? 70) - 50) * 0.24,
            );
            break;
          case EffectFamily.cabinet:
            final node = engine.addNode(DspNodeType.cabinet);
            // The assigned WAV file is not decoded or loaded yet. Keep this
            // node transparent instead of pretending its local IR is active.
            engine.setParameter(node, 0, 0);
            engine.setParameter(node, 1, block.parameters['level'] ?? 0);
            break;
          case EffectFamily.modulation:
          case EffectFamily.delay:
          case EffectFamily.reverb:
          case EffectFamily.eq:
          case EffectFamily.pitch:
          case EffectFamily.expression:
            skipped.add(block.name);
            break;
        }
      }

      final metrics = engine.runTestTone();
      _skippedBlocks = List.unmodifiable(skipped);
      return metrics;
    } finally {
      engine.dispose();
    }
  }

  Future<void> _runTest() async {
    if (_isRunning) return;
    final preset = widget.controller.activePreset;
    if (preset == null) {
      setState(() => _error = 'There is no active preset to test.');
      return;
    }
    setState(() {
      _isRunning = true;
      _error = null;
      _metrics = null;
      _testedPresetId = preset.id;
      _skippedBlocks = const [];
    });

    try {
      final result = _processPreset(preset);
      if (!mounted) return;
      setState(() => _metrics = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'DSP test failed: $error');
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  String _db(double value) => '${value.toStringAsFixed(1)} dBFS';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final preset = widget.controller.activePreset;
        final ordered = preset == null ? <EffectBlock>[] : _orderedBlocks(preset);
        final enabled = ordered.where((block) => block.enabled).toList();
        final supported = enabled.where((block) {
          return switch (block.family) {
            EffectFamily.gate ||
            EffectFamily.drive ||
            EffectFamily.amplifier ||
            EffectFamily.cabinet => true,
            _ => false,
          };
        }).length;
        final testedPresetChanged =
            _testedPresetId != null && preset?.id != _testedPresetId;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Software Audio Engine',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Shared native DSP core · Android + Windows',
                    style: TextStyle(color: Color(0xFF9AA4B2)),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.graphic_eq,
                                color: Color(0xFFFF987B),
                                size: 25,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'NATIVE DSP CORE',
                                  style: TextStyle(
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Chip(
                                avatar: Icon(Icons.check_circle, size: 15),
                                label: Text('Available'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'One C++ processing engine is compiled for both platforms and called through Dart FFI. This milestone tests offline audio blocks; it does not open an audio device.',
                            style: TextStyle(
                              color: Color(0xFFB5BEC9),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'IMPLEMENTED DSP BLOCKS',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.1,
                              color: Color(0xFF9AA4B2),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 9),
                          const Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text('Noise gate')),
                              Chip(label: Text('Compressor')),
                              Chip(label: Text('Overdrive')),
                              Chip(label: Text('Amp preamp / tone stack')),
                              Chip(label: Text('FIR cabinet convolution')),
                            ],
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Cabinet convolution accepts mono IR sample buffers, but imported WAV files are not yet decoded and loaded into the engine.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9AA4B2),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACTIVE PRESET TEST',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.1,
                              color: Color(0xFF9AA4B2),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            preset?.name ?? 'No preset loaded',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '$supported supported blocks · ${enabled.length - supported} enabled blocks not yet implemented',
                            style: const TextStyle(
                              color: Color(0xFF9AA4B2),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const ValueKey('run-dsp-test'),
                              onPressed: _isRunning || preset == null ? null : _runTest,
                              icon: _isRunning
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.play_arrow),
                              label: Text(
                                _isRunning
                                    ? 'Processing test signal…'
                                    : 'Run 440 Hz Test Signal',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'The test tone is generated inside the engine (48 kHz stereo, 250 ms). It is not captured from your guitar or microphone and is not played through your speakers.',
                            style: TextStyle(
                              color: Color(0xFF9AA4B2),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFFFF9C8C)),
                            ),
                          ],
                          if (_metrics != null) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'DSP TEST COMPLETE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_metrics!.durationMilliseconds} ms',
                                  style: const TextStyle(color: Color(0xFF9AA4B2)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _MetricGrid(
                              values: {
                                'Input RMS': _db(_metrics!.inputRmsDb),
                                'Output RMS': _db(_metrics!.outputRmsDb),
                                'Input peak': _db(_metrics!.inputPeakDb),
                                'Output peak': _db(_metrics!.outputPeakDb),
                                'Processed frames': '${_metrics!.processedFrames}',
                                'Active DSP nodes': '${_metrics!.enabledNodeCount}',
                              },
                            ),
                            if (_skippedBlocks.isNotEmpty) ...[
                              const SizedBox(height: 13),
                              const Text(
                                'NOT YET PROCESSED',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFB08E),
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _skippedBlocks.join(' · '),
                                style: const TextStyle(
                                  color: Color(0xFFB5BEC9),
                                  height: 1.4,
                                ),
                              ),
                            ],
                            if (testedPresetChanged) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'The active preset changed after this test. Run it again to refresh the results.',
                                style: TextStyle(
                                  color: Color(0xFFFFB08E),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NOT AVAILABLE YET',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9AA4B2),
                            ),
                          ),
                          SizedBox(height: 10),
                          _NotReadyLine('Live guitar / microphone input'),
                          _NotReadyLine('Audio interface and device selection'),
                          _NotReadyLine('Real-time speaker / headphone output'),
                          _NotReadyLine('Low-latency monitoring and routing'),
                          _NotReadyLine('NAM amp-capture playback'),
                          _NotReadyLine('Automatic loading of imported WAV IRs'),
                          _NotReadyLine('Modulation, delay, reverb, pitch and EQ DSP'),
                          _NotReadyLine('KPT Pro control or preset writes'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.values});
  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 2 : 3;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in values.entries)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101419),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0xFF303844)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9AA4B2),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        entry.value,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NotReadyLine extends StatelessWidget {
  const _NotReadyLine(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          const Icon(
            Icons.radio_button_unchecked,
            size: 15,
            color: Color(0xFF7D8795),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFFB5BEC9)),
            ),
          ),
        ],
      ),
    );
  }
}
