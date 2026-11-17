import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/audio/rigcanvas_dsp_engine.dart';

void main() {
  test('native DSP parameters can be written and read back', () {
    final engine = RigCanvasDspEngine();
    addTearDown(engine.dispose);

    final drive = engine.addNode(DspNodeType.drive);
    engine.setParameter(drive, 0, 11.5);

    expect(engine.getParameter(drive, 0), closeTo(11.5, 0.0001));
    expect(engine.nodeCount, 1);
    expect(engine.nodeTypeAt(0), DspNodeType.drive);
  });

  test('native DSP supports per-node bypass control and readback', () {
    final engine = RigCanvasDspEngine();
    addTearDown(engine.dispose);

    final delay = engine.addNode(DspNodeType.delay);
    expect(engine.isNodeEnabled(delay), isTrue);

    engine.setNodeEnabled(delay, false);
    expect(engine.isNodeEnabled(delay), isFalse);

    engine.setNodeEnabled(delay, true);
    expect(engine.isNodeEnabled(delay), isTrue);
  });

  test('native DSP graph nodes can be reordered and removed', () {
    final engine = RigCanvasDspEngine();
    addTearDown(engine.dispose);

    engine.addNode(DspNodeType.drive);
    engine.addNode(DspNodeType.delay);
    engine.addNode(DspNodeType.reverb);

    engine.moveNode(0, 2);
    expect(engine.nodeTypeAt(0), DspNodeType.delay);
    expect(engine.nodeTypeAt(1), DspNodeType.reverb);
    expect(engine.nodeTypeAt(2), DspNodeType.drive);

    engine.removeNode(1);
    expect(engine.nodeCount, 2);
    expect(engine.nodeTypeAt(0), DspNodeType.delay);
    expect(engine.nodeTypeAt(1), DspNodeType.drive);
  });

  test('native DSP rejects invalid read and graph indices', () {
    final engine = RigCanvasDspEngine();
    addTearDown(engine.dispose);

    expect(() => engine.getParameter(0, 0), throwsA(isA<RangeError>()));
    expect(() => engine.setNodeEnabled(0, false), throwsA(isA<RangeError>()));
    expect(() => engine.moveNode(0, 1), throwsA(isA<RangeError>()));
    expect(() => engine.removeNode(0), throwsA(isA<RangeError>()));
  });
}
