import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/device/kpt_pro_protocol.dart';

void main() {
  group('KptProProtocolFrame', () {
    test('parses captured KPT Pro identity response without interpreting it', () {
      final frame = KptProProtocolFrame.parse(_bytes(
        '00 59 11 1B 00 00 '
        '4B 50 54 50 52 4F 5F 30 30 38 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 '
        '28',
      ));

      expect(frame.commandId, 0x11);
      expect(frame.reservedByte, 0x00);
      expect(frame.bodyLength, 27);
      expect(String.fromCharCodes(frame.bodyBytes.take(10)), 'KPTPRO_008');
      expect(frame.checksum, 0x28);
      expect(frame.rawBytes.length, 34);
    });

    test('parses a captured phone-to-pedal request frame', () {
      final frame = KptProProtocolFrame.parse(_bytes(
        '00 59 23 08 00 00 05 00 00 00 D0 20 00 00 0A',
      ));

      expect(frame.commandId, 0x23);
      expect(frame.bodyLength, 8);
      expect(frame.bodyBytes, [0x05, 0x00, 0x00, 0x00, 0xD0, 0x20, 0x00, 0x00]);
      expect(frame.checksum, 0x0A);
    });

    test('parses a captured response frame and preserves unknown bytes', () {
      final raw = _bytes(
        '00 59 23 12 00 00 '
        '04 00 00 00 60 70 0A 00 00 00 64 00 00 00 5A 00 01 02 '
        '3F',
      );
      final frame = KptProProtocolFrame.parse(raw);

      expect(frame.commandId, 0x23);
      expect(frame.bodyLength, 18);
      expect(frame.bodyBytes, raw.sublist(6, 24));
      expect(frame.rawBytes, raw);
    });

    test('rejects wrong magic, truncated frames and extra bytes', () {
      expect(
        () => KptProProtocolFrame.parse([0x01, 0x59, 0x11, 0, 0, 0, 0xFF]),
        throwsFormatException,
      );
      expect(
        () => KptProProtocolFrame.parse([0x00, 0x59, 0x11, 0, 0, 0]),
        throwsFormatException,
      );
      expect(
        () => KptProProtocolFrame.parse([
          ..._bytes('00 59 11 00 00 00 FF'),
          0x00,
        ]),
        throwsFormatException,
      );
    });

    test('rejects invalid checksum and body lengths above the configured cap', () {
      final badChecksum = _bytes('00 59 11 00 00 00 FE');
      expect(
        () => KptProProtocolFrame.parse(badChecksum),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('checksum mismatch'),
        )),
      );

      expect(
        () => KptProProtocolFrame.parse(
          [0x00, 0x59, 0x23, 0x20, 0x00, 0x00],
          maxBodyLength: 16,
        ),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('exceeds the configured limit'),
        )),
      );
    });

    test('rejects bytes outside the unsigned byte range', () {
      expect(
        () => KptProProtocolFrame.parse([0, 0x59, 0x11, 0, 0, 0, 256]),
        throwsFormatException,
      );
    });
  });

  group('KptProNotificationFrameReassembler', () {
    test('ignores unrelated notifications when no frame is pending', () {
      final reassembler = KptProNotificationFrameReassembler();

      expect(reassembler.addNotification([0x01, 0x02, 0x03]), isEmpty);
      expect(reassembler.hasPendingFrame, isFalse);
      expect(reassembler.bufferedByteCount, 0);
    });

    test('handles the two-byte frame magic split across notifications', () {
      final reassembler = KptProNotificationFrameReassembler();

      expect(reassembler.addNotification([0x00]), isEmpty);
      expect(reassembler.hasPendingFrame, isTrue);
      final frames = reassembler.addNotification(
        _bytes('59 11 00 00 00 FF'),
      );

      expect(frames, hasLength(1));
      expect(frames.single.commandId, 0x11);
      expect(frames.single.bodyBytes, isEmpty);
      expect(reassembler.hasPendingFrame, isFalse);
    });

    test('reassembles a long frame split across BLE notifications', () {
      final body = List<int>.generate(848, (index) => (index * 17) & 0xFF);
      final raw = _makeFrame(0x23, body);
      final reassembler = KptProNotificationFrameReassembler();
      final notifications = <List<int>>[];

      for (var offset = 0; offset < raw.length; offset += 180) {
        final end = (offset + 180 < raw.length) ? offset + 180 : raw.length;
        notifications.add(raw.sublist(offset, end));
      }

      final completed = <KptProProtocolFrame>[];
      for (final notification in notifications) {
        completed.addAll(reassembler.addNotification(notification));
      }

      expect(notifications.length, greaterThan(1));
      expect(completed, hasLength(1));
      expect(completed.single.commandId, 0x23);
      expect(completed.single.bodyLength, 848);
      expect(completed.single.bodyBytes, body);
      expect(completed.single.rawBytes, raw);
      expect(reassembler.hasPendingFrame, isFalse);
    });

    test('returns multiple complete frames from one notification', () {
      final first = _makeFrame(0x11, <int>[]);
      final second = _makeFrame(0x23, [1, 2, 3, 4]);
      final reassembler = KptProNotificationFrameReassembler();

      final frames = reassembler.addNotification([...first, ...second]);

      expect(frames, hasLength(2));
      expect(frames.map((frame) => frame.commandId), [0x11, 0x23]);
      expect(frames.last.bodyBytes, [1, 2, 3, 4]);
      expect(reassembler.hasPendingFrame, isFalse);
    });

    test('retains incomplete data until reset, then discards it', () {
      final raw = _makeFrame(0x23, [10, 20, 30, 40]);
      final reassembler = KptProNotificationFrameReassembler();

      expect(reassembler.addNotification(raw.sublist(0, 8)), isEmpty);
      expect(reassembler.hasPendingFrame, isTrue);
      reassembler.reset();
      expect(reassembler.hasPendingFrame, isFalse);
      expect(reassembler.bufferedByteCount, 0);
      expect(reassembler.addNotification(raw.sublist(8)), isEmpty);
    });

    test('clears a failed frame after checksum validation fails', () {
      final badFrame = _makeFrame(0x23, [1, 2, 3])..[9] ^= 0x01;
      final reassembler = KptProNotificationFrameReassembler();

      expect(
        () => reassembler.addNotification(badFrame),
        throwsFormatException,
      );
      expect(reassembler.hasPendingFrame, isFalse);
    });
  });
}

List<int> _bytes(String hex) =>
    hex.trim().split(RegExp(r'\s+')).map((byte) => int.parse(byte, radix: 16)).toList();

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
