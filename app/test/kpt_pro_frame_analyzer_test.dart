import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/device/btsnoop_capture.dart';
import 'package:rigcanvas/src/device/kpt_pro_frame_analyzer.dart';

void main() {
  group('KptProFrameAnalyzer', () {
    test('recognizes a complete phone-to-pedal frame without naming its command', () {
      final raw = _makeFrame(0x23, [0x05, 0x00, 0x20, 0x38]);

      final analysis = KptProFrameAnalyzer.analyze([
        _event(
          frame: 10,
          timestampMicros: 1200,
          direction: BtsnoopDirection.hostToController,
          opcode: 0x52,
          handle: 0x0062,
          value: raw,
        ),
      ]);

      expect(analysis.completeFrameCount, 1);
      expect(analysis.invalidFrameCount, 0);
      expect(analysis.incompleteStreamCount, 0);
      expect(analysis.frames.single.commandId, 0x23);
      expect(analysis.frames.single.bodyLength, 4);
      expect(analysis.frames.single.firstFrameNumber, 10);
      expect(analysis.frames.single.lastFrameNumber, 10);
      expect(analysis.frames.single.fragmentCount, 1);
      expect(analysis.commandSummaries.single.commandIdHex, '0x23');
      expect(analysis.commandSummaries.single.count, 1);
      expect(
        analysis.toJson()['commandIdentifiersAreUninterpreted'],
        isTrue,
      );
    });

    test('reassembles fragmented pedal notifications and preserves capture offsets', () {
      final body = List<int>.generate(330, (index) => (index * 13) & 0xFF);
      final raw = _makeFrame(0x23, body);
      final events = <KptBleAttEvent>[];
      var index = 0;

      for (var offset = 0; offset < raw.length; offset += 100) {
        final end = (offset + 100 < raw.length) ? offset + 100 : raw.length;
        events.add(
          _event(
            frame: 200 + index,
            timestampMicros: 500000 + index * 20000,
            direction: BtsnoopDirection.controllerToHost,
            opcode: 0x1B,
            handle: 0x0064,
            value: raw.sublist(offset, end),
          ),
        );
        index++;
      }

      final analysis = KptProFrameAnalyzer.analyze(events);

      expect(analysis.completeFrameCount, 1);
      expect(analysis.invalidFrameCount, 0);
      expect(analysis.incompleteStreamCount, 0);
      expect(analysis.frames.single.bodyLength, 330);
      expect(analysis.frames.single.firstFrameNumber, 200);
      expect(analysis.frames.single.lastFrameNumber, 203);
      expect(analysis.frames.single.fragmentCount, 4);
      expect(analysis.frames.single.firstTimestampMicros, 500000);
      expect(analysis.frames.single.lastTimestampMicros, 560000);
      expect(analysis.frames.single.direction, BtsnoopDirection.controllerToHost);
    });

    test('handles frame magic split across two ATT values', () {
      final raw = _makeFrame(0x11, const []);
      final analysis = KptProFrameAnalyzer.analyze([
        _event(
          frame: 30,
          timestampMicros: 1000,
          direction: BtsnoopDirection.hostToController,
          opcode: 0x52,
          handle: 0x0062,
          value: [0x00],
        ),
        _event(
          frame: 31,
          timestampMicros: 2000,
          direction: BtsnoopDirection.hostToController,
          opcode: 0x52,
          handle: 0x0062,
          value: raw.sublist(1),
        ),
      ]);

      expect(analysis.completeFrameCount, 1);
      expect(analysis.frames.single.firstFrameNumber, 30);
      expect(analysis.frames.single.lastFrameNumber, 31);
      expect(analysis.frames.single.fragmentCount, 2);
      expect(analysis.frames.single.commandId, 0x11);
    });

    test('isolates direction and attribute streams instead of joining fragments', () {
      final partial = _makeFrame(0x23, [1, 2, 3, 4]).sublist(0, 8);
      final complete = _makeFrame(0x11, [9, 8]);

      final analysis = KptProFrameAnalyzer.analyze([
        _event(
          frame: 1,
          timestampMicros: 100,
          direction: BtsnoopDirection.hostToController,
          opcode: 0x52,
          handle: 0x0062,
          value: partial,
        ),
        _event(
          frame: 2,
          timestampMicros: 200,
          direction: BtsnoopDirection.controllerToHost,
          opcode: 0x1B,
          handle: 0x0064,
          value: complete,
        ),
      ]);

      expect(analysis.completeFrameCount, 1);
      expect(analysis.incompleteStreamCount, 1);
      expect(analysis.frames.single.commandId, 0x11);
      expect(analysis.frames.single.direction, BtsnoopDirection.controllerToHost);
    });

    test('counts invalid checksums and incomplete trailing streams', () {
      final invalid = _makeFrame(0x23, [1, 2, 3]);
      invalid[invalid.length - 1] ^= 0x01;
      final incomplete = _makeFrame(0x23, [4, 5, 6]).sublist(0, 8);

      final analysis = KptProFrameAnalyzer.analyze([
        _event(
          frame: 1,
          timestampMicros: 100,
          direction: BtsnoopDirection.hostToController,
          opcode: 0x52,
          handle: 0x0062,
          value: invalid,
        ),
        _event(
          frame: 2,
          timestampMicros: 200,
          direction: BtsnoopDirection.hostToController,
          opcode: 0x52,
          handle: 0x0062,
          value: incomplete,
        ),
      ]);

      expect(analysis.invalidFrameCount, 1);
      expect(analysis.completeFrameCount, 0);
      expect(analysis.incompleteStreamCount, 1);
    });

    test('ignores unrelated attribute values and ATT operations', () {
      final analysis = KptProFrameAnalyzer.analyze([
        _event(
          frame: 1,
          timestampMicros: 100,
          direction: BtsnoopDirection.hostToController,
          opcode: 0x52,
          handle: 0x0062,
          value: [0x01, 0x02, 0x03],
        ),
        _event(
          frame: 2,
          timestampMicros: 200,
          direction: BtsnoopDirection.controllerToHost,
          opcode: 0x0B,
          handle: 0x0064,
          value: _makeFrame(0x11, [1, 2]),
        ),
      ]);

      expect(analysis.completeFrameCount, 0);
      expect(analysis.invalidFrameCount, 0);
      expect(analysis.incompleteStreamCount, 0);
      expect(analysis.analyzedValueEventCount, 0);
    });

    test('keeps identical raw command IDs separate by direction and handle', () {
      final raw = _makeFrame(0x23, [1]);
      final analysis = KptProFrameAnalyzer.analyze([
        _event(
          frame: 1,
          timestampMicros: 100,
          direction: BtsnoopDirection.hostToController,
          opcode: 0x52,
          handle: 0x0062,
          value: raw,
        ),
        _event(
          frame: 2,
          timestampMicros: 200,
          direction: BtsnoopDirection.controllerToHost,
          opcode: 0x1B,
          handle: 0x0064,
          value: raw,
        ),
      ]);

      expect(analysis.commandSummaries, hasLength(2));
      expect(
        analysis.commandSummaries.map((item) => item.direction).toSet(),
        {
          BtsnoopDirection.hostToController,
          BtsnoopDirection.controllerToHost,
        },
      );
      expect(
        analysis.commandSummaries.map((item) => item.attributeHandle).toSet(),
        {0x0062, 0x0064},
      );
    });
    test('slices observed 0x23 eight-byte bodies as Tank-G-style candidates only', () {
      final firstBody = [0x04, 0x00, 0x00, 0x00, 0x20, 0x38, 0x00, 0x00];
      final secondBody = [0x04, 0x00, 0x00, 0x60, 0x70, 0x0A, 0x00, 0x00];
      final analysis = KptProFrameAnalyzer.analyze([
        _event(
          frame: 10,
          timestampMicros: 1000,
          direction: BtsnoopDirection.hostToController,
          opcode: 0x52,
          handle: 0x0062,
          value: _makeFrame(0x23, firstBody),
        ),
        _event(
          frame: 11,
          timestampMicros: 2000,
          direction: BtsnoopDirection.hostToController,
          opcode: 0x52,
          handle: 0x0062,
          value: _makeFrame(0x23, secondBody),
        ),
      ]);

      final first = analysis.frames[0].f1f2LayoutCandidate!;
      expect(first.firstWordLittleEndian, 0x00000004);
      expect(first.secondWordLittleEndian, 0x00003820);
      expect(first.memoryIdCandidate, 4);
      expect(first.addressCandidate, 0);
      expect(first.lengthCandidate, 0x38);
      expect(first.spaceCandidate, 2);
      expect(first.reservedLowNibbleCandidate, 0);
      expect(first.upper16BitsCandidate, 0);
      expect(first.rawBodyHex, '04 00 00 00 20 38 00 00');

      final second = analysis.frames[1].f1f2LayoutCandidate!;
      expect(second.firstWordLittleEndian, 0x60000004);
      expect(second.addressCandidate, 0x600000);
      expect(second.secondWordLittleEndian, 0x00000A70);
      expect(second.lengthCandidate, 0x0A);
      expect(second.spaceCandidate, 7);
      expect(analysis.f1f2CandidateSummaries, hasLength(2));
      expect(
        analysis.toJson()['f1f2FieldSliceComparisonOnly'],
        isA<Map<String, Object?>>()
            .having((value) => value['hypothesisOnly'], 'hypothesisOnly', isTrue)
            .having((value) => value['kptProLayoutConfirmed'], 'confirmed', isFalse),
      );
    });

    test('does not create f1/f2 candidates for other command IDs or body sizes', () {
      final analysis = KptProFrameAnalyzer.analyze([
        _event(
          frame: 1,
          timestampMicros: 100,
          direction: BtsnoopDirection.hostToController,
          opcode: 0x52,
          handle: 0x0062,
          value: _makeFrame(0x11, List<int>.filled(8, 0)),
        ),
        _event(
          frame: 2,
          timestampMicros: 200,
          direction: BtsnoopDirection.hostToController,
          opcode: 0x52,
          handle: 0x0062,
          value: _makeFrame(0x23, [1, 2, 3, 4]),
        ),
      ]);

      expect(analysis.frames, hasLength(2));
      expect(analysis.frames.every((frame) => frame.f1f2LayoutCandidate == null), isTrue);
      expect(analysis.f1f2CandidateSummaries, isEmpty);
    });
  });
}

KptBleAttEvent _event({
  required int frame,
  required int timestampMicros,
  required BtsnoopDirection direction,
  required int opcode,
  required int handle,
  required List<int> value,
}) {
  return KptBleAttEvent(
    frameNumber: frame,
    relativeTimestampMicros: timestampMicros,
    sessionId: 1,
    connectionHandle: 0x0200,
    direction: direction,
    opcode: opcode,
    opcodeName: 'test',
    attributeHandle: handle,
    value: value,
    pdu: const [],
  );
}

List<int> _makeFrame(int commandId, List<int> body) {
  var sum = 0;
  for (final byte in body) {
    sum = (sum + byte) & 0xFF;
  }
  final checksum = (0xFF - sum) & 0xFF;
  return [
    0x00,
    0x59,
    commandId,
    body.length & 0xFF,
    (body.length >> 8) & 0xFF,
    0x00,
    ...body,
    checksum,
  ];
}
