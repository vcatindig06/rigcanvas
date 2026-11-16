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
  });
}
