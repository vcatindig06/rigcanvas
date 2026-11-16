import 'package:material_ui/material_ui.dart';

import '../audio/rigcanvas_dsp_engine.dart';
import '../audio/wav_ir_decoder.dart';
import '../models/effect_block.dart';
import '../models/rig_preset.dart';
import '../state/asset_controller.dart';
import '../state/preset_controller.dart';

class AudioEngineScreen extends StatefulWidget {
  const AudioEngineScreen({
    required this.controller,
    required this.assetController,
    super.key,
  });

  final PresetController controller;
  final AssetController assetController;

  @override
  State<AudioEngineScreen> createState() => _AudioEngineScreenState();
}

class _AudioEngineScreenState extends State<AudioEngineScreen> {
  bool _isRunning = false;
  DspProcessMetrics? _metrics;
  String? _error;
  String? _testedPresetId;
  List<String> _skippedBlocks = const [];
  List<String> _assetNotes = const [];

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

  bool _supportsModel(EffectBlock block) {
    switch (block.family) {
      case EffectFamily.gate:
      case EffectFamily.drive:
      case EffectFamily.amplifier:
      case EffectFamily.cabinet:
      case EffectFamily.reverb:
      case EffectFamily.eq:
        return true;
      case EffectFamily.modulation:
        return ![
          'phaser',
          'autofilter',
          'wah',
          'univibe',
          'rotary',
          'ring_mod',
          'micro_pitch',
        ].any((fragment) => block.modelId.contains(fragment));
      case EffectFamily.delay:
        return ![
          'duck',
          'reverse',
          'tape',
          'lofi',
          'multi_tap',
          'dual',
          'granular',
        ].any((fragment) => block.modelId.contains(fragment));
      case EffectFamily.pitch:
      case EffectFamily.expression:
        return false;
    }
  }

  Future<DspProcessMetrics> _processPreset(RigPreset preset) async {
    final engine = RigCanvasDspEngine();
    final skipped = <String>[];
    final assetNotes = <String>[];
    try {
      for (final block in _orderedBlocks(preset)) {
        if (!block.enabled) continue;
        if (!_supportsModel(block)) {
          skipped.add(block.name);
          continue;
        }

        switch (block.family) {
          case EffectFamily.gate:
            final isGate =
                block.modelId.contains('gate') ||
                block.modelId == 'kpt.fx.ai_gate';
            final node = engine.addNode(
              DspNodeType.dynamics,
              dynamicsMode:
                  isGate ? DspDynamicsMode.gate : DspDynamicsMode.compressor,
            );
            engine.setParameter(node, 0, block.parameters['threshold'] ?? -48);
            engine.setParameter(node, 1, block.parameters['ratio'] ?? 3);
            engine.setParameter(node, 2, block.parameters['attack'] ?? 10);
            engine.setParameter(node, 3, block.parameters['release'] ?? 120);
            engine.setParameter(node, 4, block.parameters['makeup'] ?? 0);
            engine.setParameter(
              node,
              5,
              (block.parameters['mix'] ?? 100) / 100,
            );
            break;

          case EffectFamily.drive:
            final node = engine.addNode(DspNodeType.drive);
            engine.setParameter(
              node,
              0,
              (block.parameters['gain'] ?? 35) * 0.24,
            );
            engine.setParameter(
              node,
              1,
              (block.parameters['tone'] ?? 55) / 100,
            );
            engine.setParameter(
              node,
              2,
              ((block.parameters['level'] ?? 65) - 50) * 0.24,
            );
            engine.setParameter(
              node,
              3,
              (block.parameters['blend'] ?? 100) / 100,
            );
            break;

          case EffectFamily.amplifier:
            final node = engine.addNode(DspNodeType.amplifier);
            engine.setParameter(
              node,
              0,
              (block.parameters['gain'] ?? 48) * 0.24,
            );
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
            engine.setParameter(
              node,
              0,
              block.assetId == null ? 0 : 1,
            );
            engine.setParameter(node, 1, block.parameters['level'] ?? 0);
            engine.setParameter(node, 2, block.parameters['lowCut'] ?? 80);
            engine.setParameter(node, 3, block.parameters['highCut'] ?? 11000);

            final assetId = block.assetId;
            if (assetId == null) {
              assetNotes.add(
                '${block.name}: no IR is linked; cabinet filtering and level only.',
              );
              break;
            }
            try {
              final bytes = await widget.assetController.readAssetBytes(assetId);
              final decoded = WavIrDecoder.decode(
                bytes,
                targetSampleRateHz: engine.sampleRate,
              );
              engine.setCabinetImpulseResponse(
                node,
                decoded.samplesInterleaved,
                irChannels: decoded.channelCount,
              );
              final channelLabel =
                  decoded.channelCount == 1 ? 'mono' : 'stereo';
              final resampleLabel = decoded.wasResampled
                  ? ' · resampled ${decoded.sourceSampleRateHz}→${decoded.sampleRateHz} Hz'
                  : '';
              final trimLabel = decoded.wasTrimmed
                  ? ' · trimmed to ${decoded.framesUsed} frames/channel'
                  : '';
              assetNotes.add(
                '${block.name}: ${channelLabel.toUpperCase()} IR loaded · ${decoded.framesUsed} frames/channel$resampleLabel$trimLabel.',
              );
            } catch (error) {
              assetNotes.add('${block.name}: linked IR could not be loaded — $error');
              skipped.add('${block.name} cabinet IR');
              engine.setParameter(node, 0, 0);
            }
            break;

          case EffectFamily.modulation:
            final modelId = block.modelId;
            final modulationMode = modelId.contains('tremolo')
                ? DspModulationMode.tremolo
                : modelId.contains('flanger')
                ? DspModulationMode.flanger
                : modelId.contains('vibrato')
                ? DspModulationMode.vibrato
                : DspModulationMode.chorus;
            final node = engine.addNode(
              DspNodeType.modulation,
              modulationMode: modulationMode,
            );
            engine.setParameter(node, 0, block.parameters['rate'] ?? 1.2);
            engine.setParameter(node, 1, block.parameters['depth'] ?? 45);
            engine.setParameter(node, 2, block.parameters['tone'] ?? 55);
            engine.setParameter(node, 3, block.parameters['mix'] ?? 25);
            break;

          case EffectFamily.delay:
            final delayMode = block.modelId == 'delay.ping_pong'
                ? DspDelayMode.pingPong
                : DspDelayMode.standard;
            final node = engine.addNode(
              DspNodeType.delay,
              delayMode: delayMode,
            );
            engine.setParameter(node, 0, block.parameters['time'] ?? 480);
            engine.setParameter(
              node,
              1,
              block.parameters['feedback'] ?? 32,
            );
            engine.setParameter(
              node,
              2,
              block.parameters['highCut'] ?? 9000,
            );
            engine.setParameter(node, 3, block.parameters['mix'] ?? 24);
            break;

          case EffectFamily.reverb:
            final node = engine.addNode(DspNodeType.reverb);
            engine.setParameter(node, 0, block.parameters['decay'] ?? 5.5);
            engine.setParameter(
              node,
              1,
              block.parameters['predelay'] ?? 25,
            );
            engine.setParameter(node, 2, block.parameters['tone'] ?? 55);
            engine.setParameter(node, 3, block.parameters['mix'] ?? 30);
            break;

          case EffectFamily.eq:
            final node = engine.addNode(DspNodeType.equalizer);
            engine.setParameter(
              node,
              0,
              block.parameters['lowGain'] ?? 0,
            );
            engine.setParameter(
              node,
              1,
              block.parameters['lowMidGain'] ?? 0,
            );
            engine.setParameter(
              node,
              2,
              block.parameters['highMidGain'] ?? 0,
            );
            engine.setParameter(
              node,
              3,
              block.parameters['highGain'] ?? 0,
            );
            engine.setParameter(node, 4, block.parameters['output'] ?? 0);
            break;

          case EffectFamily.pitch:
          case EffectFamily.expression:
            skipped.add(block.name);
            break;
        }
      }

      final metrics = engine.runTestTone(durationMilliseconds: 500);
      _skippedBlocks = List.unmodifiable(skipped);
      _assetNotes = List.unmodifiable(assetNotes);
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
      _assetNotes = const [];
    });

    try {
      final result = await _processPreset(preset);
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
        final supported = enabled.where(_supportsModel).length;
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
                              Chip(label: Text('Mono / stereo FIR cabinet')),
                              Chip(label: Text('Chorus / tremolo / flanger')),
                              Chip(label: Text('Stereo / ping-pong delay')),
                              Chip(label: Text('Room-style reverb')),
                              Chip(label: Text('Four-band EQ')),
                            ],
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'These are generic RigCanvas prototypes, not exact KPT Pro, Fractal, Quad Cortex, Helix, or Kemper algorithms. Manufacturer-specific model names remain catalog labels. Cabinet mic-distance metadata is not applied by this FIR prototype.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFFB08E),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Imported PCM / IEEE-float mono or stereo WAV IRs are decoded, resampled to 48 kHz, and loaded into the FIR cabinet node. Each IR is limited to 4,096 frames per channel for this offline prototype.',
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
                            'The test tone is generated inside the engine (48 kHz stereo, 500 ms). It is not captured from your guitar or microphone and is not played through your speakers.',
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
                            if (_assetNotes.isNotEmpty) ...[
                              const SizedBox(height: 13),
                              const Text(
                                'CABINET IR STATUS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9CC8B0),
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _assetNotes.join('\n'),
                                style: const TextStyle(
                                  color: Color(0xFFB5BEC9),
                                  height: 1.4,
                                ),
                              ),
                            ],
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
                          _NotReadyLine('Phaser, wah, rotary, pitch and expression DSP'),
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
