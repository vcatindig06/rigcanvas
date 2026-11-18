import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/audio/rigcanvas_dsp_engine.dart';

void main() {
  group('RigCanvas native DSP engine', () {
    test('builds a graph and processes a generated test tone', () {
      final engine = RigCanvasDspEngine(sampleRate: 48000, channels: 2);
      try {
        final gate = engine.addNode(
          DspNodeType.dynamics,
          dynamicsMode: DspDynamicsMode.gate,
        );
        engine.setParameter(gate, 0, -48);
        engine.setParameter(gate, 2, 8);
        engine.setParameter(gate, 3, 120);

        final drive = engine.addNode(DspNodeType.drive);
        engine.setParameter(drive, 0, 9);
        engine.setParameter(drive, 1, 0.62);
        engine.setParameter(drive, 3, 0.9);

        final amp = engine.addNode(DspNodeType.amplifier);
        engine.setParameter(amp, 0, 8);
        engine.setParameter(amp, 2, 1.5);

        final metrics = engine.runTestTone();
        expect(metrics.sampleRate, 48000);
        expect(metrics.channels, 2);
        expect(metrics.processedFrames, 12000);
        expect(metrics.durationMilliseconds, 250);
        expect(metrics.enabledNodeCount, 3);
        expect(metrics.inputRmsDb.isFinite, isTrue);
        expect(metrics.outputRmsDb.isFinite, isTrue);
        expect(metrics.inputPeakDb, lessThan(0));
        expect(metrics.outputPeakDb, lessThan(6));
      } finally {
        engine.dispose();
      }
    });

    test('cabinet node copies a mono impulse response into native memory', () {
      final engine = RigCanvasDspEngine();
      try {
        final cabinet = engine.addNode(DspNodeType.cabinet);
        engine.setCabinetImpulseResponse(
          cabinet,
          Float32List.fromList([1.0, 0.5, 0.25, 0.125]),
        );
        engine.setParameter(cabinet, 0, 1.0);
        final metrics = engine.runTestTone();
        expect(metrics.enabledNodeCount, 1);
        expect(metrics.processedFrames, 12000);
        expect(metrics.outputRmsDb.isFinite, isTrue);
      } finally {
        engine.dispose();
      }
    });

    test('offline block processing preserves frame count and channel shape', () {
      final engine = RigCanvasDspEngine(sampleRate: 48000, channels: 2);
      try {
        engine.addNode(DspNodeType.drive);
        final input = Float32List.fromList([
          0.1, -0.1,
          0.2, -0.2,
          0.3, -0.3,
          0.4, -0.4,
        ]);
        final output = engine.processInterleaved(input);
        expect(output.length, input.length);
        expect(output.every((sample) => sample.isFinite), isTrue);
      } finally {
        engine.dispose();
      }
    });

    test('rejects use after disposal and invalid engine formats', () {
      final engine = RigCanvasDspEngine();
      engine.dispose();
      expect(engine.dispose, returnsNormally);
      expect(engine.runTestTone, throwsStateError);
      expect(
        () => RigCanvasDspEngine(sampleRate: 7000),
        throwsArgumentError,
      );
    });

    test('rejects stereo IRs when the native engine is mono', () {
      final engine = RigCanvasDspEngine(channels: 1);
      try {
        final cabinet = engine.addNode(DspNodeType.cabinet);
        expect(
          () => engine.setCabinetImpulseResponse(
            cabinet,
            Float32List.fromList([1.0, 0.5, 0.25, 0.125]),
            irChannels: 2,
          ),
          throwsArgumentError,
        );
      } finally {
        engine.dispose();
      }
    });

    test('validates buffer shape and IR length before native calls', () {
      final engine = RigCanvasDspEngine();
      try {
        expect(
          () => engine.processInterleaved(Float32List.fromList([0.1])),
          throwsArgumentError,
        );
        expect(
          () => engine.setCabinetImpulseResponse(0, Float32List(0)),
          throwsArgumentError,
        );
      } finally {
        engine.dispose();
      }
    });

    test('processes modulation, delay, reverb, and equalizer nodes', () {
      final engine = RigCanvasDspEngine(sampleRate: 48000, channels: 2);
      try {
        final chorus = engine.addNode(
          DspNodeType.modulation,
          modulationMode: DspModulationMode.chorus,
        );
        engine.setParameter(chorus, 0, 1.2);
        engine.setParameter(chorus, 1, 40);
        engine.setParameter(chorus, 2, 55);
        engine.setParameter(chorus, 3, 25);

        final delay = engine.addNode(
          DspNodeType.delay,
          delayMode: DspDelayMode.pingPong,
        );
        engine.setParameter(delay, 0, 420);
        engine.setParameter(delay, 1, 30);
        engine.setParameter(delay, 2, 8000);
        engine.setParameter(delay, 3, 22);

        final reverb = engine.addNode(DspNodeType.reverb);
        engine.setParameter(reverb, 0, 4.5);
        engine.setParameter(reverb, 1, 30);
        engine.setParameter(reverb, 2, 50);
        engine.setParameter(reverb, 3, 28);

        final eq = engine.addNode(DspNodeType.equalizer);
        engine.setParameter(eq, 0, 1.5);
        engine.setParameter(eq, 1, -1.0);
        engine.setParameter(eq, 2, 0.5);
        engine.setParameter(eq, 3, -0.5);
        engine.setParameter(eq, 4, 0);

        final metrics = engine.runTestTone(durationMilliseconds: 100);
        expect(metrics.processedFrames, 4800);
        expect(metrics.enabledNodeCount, 4);
        expect(metrics.outputRmsDb.isFinite, isTrue);
        expect(metrics.outputPeakDb, lessThan(6));
      } finally {
        engine.dispose();
      }
    });

    test('processes phaser, envelope wah, and rotary modulation modes', () {
      for (final mode in [
        DspModulationMode.phaser,
        DspModulationMode.autoWah,
        DspModulationMode.rotary,
      ]) {
        final engine = RigCanvasDspEngine(sampleRate: 48000, channels: 2);
        try {
          final node = engine.addNode(
            DspNodeType.modulation,
            modulationMode: mode,
          );
          final values = switch (mode) {
            DspModulationMode.phaser => [0.8, 65.0, 35.0, 45.0],
            DspModulationMode.autoWah => [2.5, 78.0, 68.0, 60.0],
            DspModulationMode.rotary => [1.5, 60.0, 58.0, 75.0],
            _ => throw StateError('Unexpected modulation mode: $mode'),
          };
          for (var i = 0; i < values.length; i++) {
            engine.setParameter(node, i, values[i]);
          }

          final input = Float32List(9600);
          for (var frame = 0; frame < 4800; frame++) {
            final envelope = 0.25 + 0.65 * (0.5 + 0.5 * math.sin(frame * 2 * math.pi / 2400));
            final signal = envelope * 0.35 * math.sin(2 * math.pi * 440 * frame / 48000);
            input[frame * 2] = signal;
            input[frame * 2 + 1] = signal;
          }

          final output = engine.processInterleaved(input);
          expect(output, hasLength(input.length));
          expect(output.every((sample) => sample.isFinite), isTrue);
          expect(
            List.generate(output.length, (i) => (output[i] - input[i]).abs())
                .fold<double>(0, (sum, difference) => sum + difference),
            greaterThan(0.01),
          );
          expect(engine.getParameter(node, 2), closeTo(values[2], 0.001));
        } finally {
          engine.dispose();
        }
      }
    });

    test('cabinet processing accepts a copied stereo impulse response', () {
      final engine = RigCanvasDspEngine();
      try {
        final cabinet = engine.addNode(DspNodeType.cabinet);
        engine.setCabinetImpulseResponse(
          cabinet,
          Float32List.fromList([
            1.0, 0.5,
            0.25, 0.125,
            0.0625, 0.03125,
          ]),
          irChannels: 2,
        );
        engine.setParameter(cabinet, 0, 1);
        final output = engine.processInterleaved(
          Float32List.fromList([
            0.5, 0.25,
            0.25, 0.125,
            0.1, 0.05,
            0, 0,
          ]),
        );
        expect(output, hasLength(8));
        expect(output.every((sample) => sample.isFinite), isTrue);
      } finally {
        engine.dispose();
      }
    });

  });
}
