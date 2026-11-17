import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/device/btsnoop_capture.dart';

void main() {
  group('BtsnoopCaptureParser', () {
    test('identifies KPT Pro advertising and filters ATT traffic by connection', () {
      final bytes = _capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([
          0x11, 0x06, // Read By Group Type Response, 6-byte entries.
          0x20, 0x00, // Service start handle.
          0x30, 0x00, // Service end handle.
          0x40, 0xAE, // Service UUID 0xAE40.
        ]), flags: 1, timestamp: 1150),
        _record(_aclPacket([
          0x09, 0x07, // Read By Type Response, 7-byte entries.
          0x22, 0x00, // AE41 declaration handle.
          0x04,       // Write Without Response.
          0x25, 0x00, // AE41 value handle.
          0x41, 0xAE, // Characteristic UUID AE41.
          0x26, 0x00, // AE42 declaration handle.
          0x10,       // Notify.
          0x27, 0x00, // AE42 value handle.
          0x42, 0xAE, // Characteristic UUID AE42.
          0x28, 0x00, // Extra declaration to test retained discovery.
          0x02,       // Read.
          0x29, 0x00, // Extra value handle.
          0x43, 0xAE, // Characteristic UUID AE43.
        ]), flags: 1, timestamp: 1200),
        _record(_aclPacket([
          0x52, 0x25, 0x00, 0xAA, 0xBB,
        ]), flags: 0, timestamp: 1300),
        _record(_aclPacket([
          0x1B, 0x27, 0x00, 0x01, 0x02,
        ]), flags: 1, timestamp: 1400),
        _record(_disconnectComplete(), flags: 1, timestamp: 1500),
      ]);

      final capture = BtsnoopCaptureParser.parse(bytes);

      expect(capture.packetCount, 7);
      expect(capture.connectionSessions, hasLength(1));
      final session = capture.connectionSessions.single;
      expect(session.deviceName, 'KPTPRO_BLE');
      expect(session.looksLikeKptPro, isTrue);
      expect(capture.suggestedKptProSessionId(), session.id);
      expect(session.peerAddress, 'A1:B2:C3:D4:E5:F6');
      expect(session.maskedAddress, '**:**:**:**:E5:F6');

      final events = capture.eventsForSession(session.id);
      expect(events, hasLength(4));
      expect(events[0].opcodeName, 'Read By Group Type Response');
      expect(events[1].opcodeName, 'Read By Type Response');
      expect(events[2].opcodeName, 'Write Command');
      expect(events[2].direction, BtsnoopDirection.hostToController);
      expect(events[2].attributeHandle, 0x25);
      expect(events[2].attributeUuid, '0000ae41-0000-1000-8000-00805f9b34fb');
      expect(events[2].serviceUuid, '0000ae40-0000-1000-8000-00805f9b34fb');
      expect(events[2].characteristicProperties, 0x04);
      expect(events[2].valueHex, 'AA BB');

      final filtered = capture.toJson(
        sessionId: session.id,
        includePayload: true,
      );
      final characteristicMap =
          filtered['characteristicDiscovery'] as Map<String, Object?>;
      final ae41 = characteristicMap['0x0025'] as Map<String, Object?>;
      expect(ae41['serviceUuid'], '0000ae40-0000-1000-8000-00805f9b34fb');
      expect(ae41['characteristicUuid'], '0000ae41-0000-1000-8000-00805f9b34fb');
      expect(ae41['properties'], 0x04);
      final ae42 = characteristicMap['0x0027'] as Map<String, Object?>;
      expect(ae42['characteristicUuid'], '0000ae42-0000-1000-8000-00805f9b34fb');
      expect(ae42['propertyNames'], ['notify']);
      final discoveredWithoutTraffic =
          characteristicMap['0x0029'] as Map<String, Object?>;
      expect(
        discoveredWithoutTraffic['characteristicUuid'],
        '0000ae43-0000-1000-8000-00805f9b34fb',
      );
      expect(events[3].opcodeName, 'Handle Value Notification');
      expect(events[3].direction, BtsnoopDirection.controllerToHost);
      expect(events[3].attributeUuid, '0000ae42-0000-1000-8000-00805f9b34fb');
      expect(events[3].serviceUuid, '0000ae40-0000-1000-8000-00805f9b34fb');
      expect(events[3].characteristicProperties, 0x10);
      expect(events[3].valueHex, '01 02');
      expect(capture.writeCount, 1);
      expect(capture.notificationCount, 1);
    });

    test('maps a 128-bit BLE-MIDI characteristic to its service with canonical UUID casing', () {
      const midiService =
          '03b80e5a-ede8-4b33-a751-6ce34ec4c700';
      const midiCharacteristic =
          '7772e5db-3868-4112-a1a9-f2669d106bf3';
      final serviceUuidBytes = _uuid128Bytes(midiService);
      final characteristicUuidBytes = _uuid128Bytes(midiCharacteristic);
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([
          0x11, 0x14, // Read By Group Type Response, 20-byte entries.
          0x40, 0x00, // Service start handle.
          0x50, 0x00, // Service end handle.
          ...serviceUuidBytes,
        ]), flags: 1, timestamp: 1200),
        _record(_aclPacket([
          0x09, 0x15, // Read By Type Response, 21-byte entries.
          0x41, 0x00, // Characteristic declaration handle.
          0x1C,       // Read, write without response, notify.
          0x42, 0x00, // Characteristic value handle.
          ...characteristicUuidBytes,
        ]), flags: 1, timestamp: 1300),
        _record(_aclPacket([
          0x52, 0x42, 0x00, 0x80, 0x80, 0x90,
        ]), flags: 0, timestamp: 1400),
      ]));

      final event = capture.attEvents.last;
      expect(event.attributeUuid, midiCharacteristic);
      expect(event.serviceUuid, midiService);
      expect(event.attributeUuid, matches(RegExp(r'^[0-9a-f-]{36}    });

    test('keeps ATT payloads from other Bluetooth devices out of the selected session', () {
      final otherAddress = <int>[0x10, 0x20, 0x30, 0x40, 0x50, 0x60];
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(
          _advertisement(name: 'HEADPHONES', address: otherAddress),
          flags: 1,
          timestamp: 1200,
        ),
        _record(
          _connectionComplete(handle: 12, address: otherAddress),
          flags: 1,
          timestamp: 1300,
        ),
        _record(
          _aclPacket([0x52, 0x25, 0x00, 0xAA], connectionHandle: 11),
          flags: 0,
          timestamp: 1400,
        ),
        _record(
          _aclPacket([0x52, 0x26, 0x00, 0xDE, 0xAD], connectionHandle: 12),
          flags: 0,
          timestamp: 1500,
        ),
      ]));

      expect(capture.connectionSessions, hasLength(2));
      final kptSession = capture.connectionSessions.firstWhere(
        (session) => session.looksLikeKptPro,
      );
      final otherSession = capture.connectionSessions.firstWhere(
        (session) => !session.looksLikeKptPro,
      );
      expect(capture.eventsForSession(kptSession.id), hasLength(1));
      expect(capture.eventsForSession(otherSession.id), hasLength(1));

      final filtered = jsonEncode(capture.toJson(
        sessionId: kptSession.id,
        includePayload: true,
      ));
      expect(filtered, contains('AA'));
      expect(filtered, isNot(contains('DE AD')));
      expect(filtered, isNot(contains('HEADPHONES')));
    });

    test('exports only the selected connection and redacts peer address', () {
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([0x52, 0x25, 0x00, 0xDE, 0xAD]), flags: 0, timestamp: 1200),
      ]));

      final session = capture.connectionSessions.single;
      final withoutPayload = capture.toJson(
        sessionId: session.id,
        includePayload: false,
      );
      final encodedWithoutPayload = jsonEncode(withoutPayload);
      expect(encodedWithoutPayload, contains('peerAddressRedacted'));
      expect(encodedWithoutPayload, contains('otherBluetoothConnectionsExcluded'));
      expect(encodedWithoutPayload, isNot(contains('DE AD')));
      expect(encodedWithoutPayload, contains('**:**:**:**:E5:F6'));

      final withPayload = capture.toJson(
        sessionId: session.id,
        includePayload: true,
      );
      expect(jsonEncode(withPayload), contains('DE AD'));
      expect(
        () => capture.toJson(sessionId: 99, includePayload: false),
        throwsArgumentError,
      );
    });

    test('accepts an empty valid capture', () {
      final capture = BtsnoopCaptureParser.parse(_capture(const []));
      expect(capture.packetCount, 0);
      expect(capture.connectionSessions, isEmpty);
      expect(capture.attEvents, isEmpty);
    });

    test('rejects invalid magic, unsupported data-link type and truncated records', () {
      expect(
        () => BtsnoopCaptureParser.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );

      final wrongType = _capture(const [], dataLinkType: 1003);
      expect(() => BtsnoopCaptureParser.parse(wrongType), throwsFormatException);

      final truncated = Uint8List.fromList([
        ..._capture(const []),
        0x00,
        0x01,
      ]);
      expect(() => BtsnoopCaptureParser.parse(truncated), throwsFormatException);
    });

    test('tracks a fragmented L2CAP ATT packet across ACL records', () {
      final pdu = <int>[0x52, 0x25, 0x00, 0x01, 0x02, 0x03, 0x04];
      final l2cap = <int>[pdu.length, 0x00, 0x04, 0x00, ...pdu];
      final first = _aclPacketRaw(
        l2cap.sublist(0, 7),
        packetBoundary: 2,
      );
      final continuation = _aclContinuation(l2cap.sublist(7));
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(first, flags: 0, timestamp: 1200),
        _record(continuation, flags: 0, timestamp: 1300),
      ]));

      expect(capture.attEvents, hasLength(1));
      expect(capture.attEvents.single.valueHex, '01 02 03 04');
    });
  });
}

Uint8List _capture(
  List<_BtsnoopRecord> records, {
  int dataLinkType = 1002,
}) {
  final length = 16 + records.fold<int>(
    0,
    (sum, record) => sum + 24 + record.packet.length,
  );
  final bytes = Uint8List(length);
  const magic = [0x62, 0x74, 0x73, 0x6E, 0x6F, 0x6F, 0x70, 0x00];
  bytes.setRange(0, 8, magic);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 1, Endian.big);
  data.setUint32(12, dataLinkType, Endian.big);
  var offset = 16;
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final packet = record.packet;
    data.setUint32(offset, packet.length, Endian.big);
    data.setUint32(offset + 4, packet.length, Endian.big);
    data.setUint32(offset + 8, record.flags, Endian.big);
    data.setUint32(offset + 12, 0, Endian.big);
    data.setUint64(offset + 16, record.timestamp, Endian.big);
    offset += 24;
    bytes.setRange(offset, offset + packet.length, packet);
    offset += packet.length;
  }
  return bytes;
}

class _BtsnoopRecord {
  const _BtsnoopRecord(this.packet, this.flags, this.timestamp);
  final Uint8List packet;
  final int flags;
  final int timestamp;
}

_BtsnoopRecord _record(
  List<int> packet, {
  required int flags,
  required int timestamp,
}) => _BtsnoopRecord(Uint8List.fromList(packet), flags, timestamp);

Uint8List _advertisement({
  String name = 'KPTPRO_BLE',
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final nameBytes = utf8.encode(name);
  final ad = <int>[nameBytes.length + 1, 0x09, ...nameBytes];
  final params = <int>[
    0x02, // LE Advertising Report subevent.
    0x01, // One report.
    0x00, // Connectable undirected advertising.
    0x01, // Random address.
    ...address,
    ad.length,
    ...ad,
    0xC9, // -55 dBm.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

Uint8List _connectionComplete({
  int handle = 11,
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final params = <int>[
    0x01, // LE Connection Complete subevent.
    0x00, // Success.
    handle & 0xFF,
    (handle >> 8) & 0xFF,
    0x00, // Central role.
    0x01, // Random peer address.
    ...address,
    0x18, 0x00, // Connection interval.
    0x00, 0x00, // Peripheral latency.
    0xC8, 0x00, // Supervision timeout.
    0x00, // Clock accuracy.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

List<int> _uuid128Bytes(String uuid) {
  final hex = uuid.replaceAll('-', '').toLowerCase();
  return List<int>.generate(
    16,
    (index) => int.parse(
      hex.substring((15 - index) * 2, (15 - index) * 2 + 2),
      radix: 16,
    ),
  );
}

Uint8List _disconnectComplete({int handle = 11}) => Uint8List.fromList([
  0x04,
  0x05,
  0x04,
  0x00,
  handle & 0xFF,
  (handle >> 8) & 0xFF,
  0x13,
]);

Uint8List _aclPacket(List<int> attPdu, {int connectionHandle = 11}) {
  final l2cap = <int>[attPdu.length, 0x00, 0x04, 0x00, ...attPdu];
  return _aclPacketRaw(
    l2cap,
    packetBoundary: 2,
    connectionHandle: connectionHandle,
  );
}

Uint8List _aclPacketRaw(
  List<int> payload, {
  required int packetBoundary,
  int connectionHandle = 11,
}) {
  final flags = (connectionHandle & 0x0FFF) | (packetBoundary << 12);
  return Uint8List.fromList([
    0x02,
    flags & 0xFF,
    (flags >> 8) & 0xFF,
    payload.length & 0xFF,
    (payload.length >> 8) & 0xFF,
    ...payload,
  ]);
}

Uint8List _aclContinuation(List<int> payload) =>
    _aclPacketRaw(payload, packetBoundary: 1);
)));
      expect(event.serviceUuid, matches(RegExp(r'^[0-9a-f-]{36}
      expect(event.characteristicProperties, 0x1C);
    });

    test('keeps ATT payloads from other Bluetooth devices out of the selected session', () {
      final otherAddress = <int>[0x10, 0x20, 0x30, 0x40, 0x50, 0x60];
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(
          _advertisement(name: 'HEADPHONES', address: otherAddress),
          flags: 1,
          timestamp: 1200,
        ),
        _record(
          _connectionComplete(handle: 12, address: otherAddress),
          flags: 1,
          timestamp: 1300,
        ),
        _record(
          _aclPacket([0x52, 0x25, 0x00, 0xAA], connectionHandle: 11),
          flags: 0,
          timestamp: 1400,
        ),
        _record(
          _aclPacket([0x52, 0x26, 0x00, 0xDE, 0xAD], connectionHandle: 12),
          flags: 0,
          timestamp: 1500,
        ),
      ]));

      expect(capture.connectionSessions, hasLength(2));
      final kptSession = capture.connectionSessions.firstWhere(
        (session) => session.looksLikeKptPro,
      );
      final otherSession = capture.connectionSessions.firstWhere(
        (session) => !session.looksLikeKptPro,
      );
      expect(capture.eventsForSession(kptSession.id), hasLength(1));
      expect(capture.eventsForSession(otherSession.id), hasLength(1));

      final filtered = jsonEncode(capture.toJson(
        sessionId: kptSession.id,
        includePayload: true,
      ));
      expect(filtered, contains('AA'));
      expect(filtered, isNot(contains('DE AD')));
      expect(filtered, isNot(contains('HEADPHONES')));
    });

    test('exports only the selected connection and redacts peer address', () {
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([0x52, 0x25, 0x00, 0xDE, 0xAD]), flags: 0, timestamp: 1200),
      ]));

      final session = capture.connectionSessions.single;
      final withoutPayload = capture.toJson(
        sessionId: session.id,
        includePayload: false,
      );
      final encodedWithoutPayload = jsonEncode(withoutPayload);
      expect(encodedWithoutPayload, contains('peerAddressRedacted'));
      expect(encodedWithoutPayload, contains('otherBluetoothConnectionsExcluded'));
      expect(encodedWithoutPayload, isNot(contains('DE AD')));
      expect(encodedWithoutPayload, contains('**:**:**:**:E5:F6'));

      final withPayload = capture.toJson(
        sessionId: session.id,
        includePayload: true,
      );
      expect(jsonEncode(withPayload), contains('DE AD'));
      expect(
        () => capture.toJson(sessionId: 99, includePayload: false),
        throwsArgumentError,
      );
    });

    test('accepts an empty valid capture', () {
      final capture = BtsnoopCaptureParser.parse(_capture(const []));
      expect(capture.packetCount, 0);
      expect(capture.connectionSessions, isEmpty);
      expect(capture.attEvents, isEmpty);
    });

    test('rejects invalid magic, unsupported data-link type and truncated records', () {
      expect(
        () => BtsnoopCaptureParser.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );

      final wrongType = _capture(const [], dataLinkType: 1003);
      expect(() => BtsnoopCaptureParser.parse(wrongType), throwsFormatException);

      final truncated = Uint8List.fromList([
        ..._capture(const []),
        0x00,
        0x01,
      ]);
      expect(() => BtsnoopCaptureParser.parse(truncated), throwsFormatException);
    });

    test('tracks a fragmented L2CAP ATT packet across ACL records', () {
      final pdu = <int>[0x52, 0x25, 0x00, 0x01, 0x02, 0x03, 0x04];
      final l2cap = <int>[pdu.length, 0x00, 0x04, 0x00, ...pdu];
      final first = _aclPacketRaw(
        l2cap.sublist(0, 7),
        packetBoundary: 2,
      );
      final continuation = _aclContinuation(l2cap.sublist(7));
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(first, flags: 0, timestamp: 1200),
        _record(continuation, flags: 0, timestamp: 1300),
      ]));

      expect(capture.attEvents, hasLength(1));
      expect(capture.attEvents.single.valueHex, '01 02 03 04');
    });
  });
}

Uint8List _capture(
  List<_BtsnoopRecord> records, {
  int dataLinkType = 1002,
}) {
  final length = 16 + records.fold<int>(
    0,
    (sum, record) => sum + 24 + record.packet.length,
  );
  final bytes = Uint8List(length);
  const magic = [0x62, 0x74, 0x73, 0x6E, 0x6F, 0x6F, 0x70, 0x00];
  bytes.setRange(0, 8, magic);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 1, Endian.big);
  data.setUint32(12, dataLinkType, Endian.big);
  var offset = 16;
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final packet = record.packet;
    data.setUint32(offset, packet.length, Endian.big);
    data.setUint32(offset + 4, packet.length, Endian.big);
    data.setUint32(offset + 8, record.flags, Endian.big);
    data.setUint32(offset + 12, 0, Endian.big);
    data.setUint64(offset + 16, record.timestamp, Endian.big);
    offset += 24;
    bytes.setRange(offset, offset + packet.length, packet);
    offset += packet.length;
  }
  return bytes;
}

class _BtsnoopRecord {
  const _BtsnoopRecord(this.packet, this.flags, this.timestamp);
  final Uint8List packet;
  final int flags;
  final int timestamp;
}

_BtsnoopRecord _record(
  List<int> packet, {
  required int flags,
  required int timestamp,
}) => _BtsnoopRecord(Uint8List.fromList(packet), flags, timestamp);

Uint8List _advertisement({
  String name = 'KPTPRO_BLE',
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final nameBytes = utf8.encode(name);
  final ad = <int>[nameBytes.length + 1, 0x09, ...nameBytes];
  final params = <int>[
    0x02, // LE Advertising Report subevent.
    0x01, // One report.
    0x00, // Connectable undirected advertising.
    0x01, // Random address.
    ...address,
    ad.length,
    ...ad,
    0xC9, // -55 dBm.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

Uint8List _connectionComplete({
  int handle = 11,
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final params = <int>[
    0x01, // LE Connection Complete subevent.
    0x00, // Success.
    handle & 0xFF,
    (handle >> 8) & 0xFF,
    0x00, // Central role.
    0x01, // Random peer address.
    ...address,
    0x18, 0x00, // Connection interval.
    0x00, 0x00, // Peripheral latency.
    0xC8, 0x00, // Supervision timeout.
    0x00, // Clock accuracy.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

List<int> _uuid128Bytes(String uuid) {
  final hex = uuid.replaceAll('-', '').toLowerCase();
  return List<int>.generate(
    16,
    (index) => int.parse(
      hex.substring((15 - index) * 2, (15 - index) * 2 + 2),
      radix: 16,
    ),
  );
}

Uint8List _aclPacket(List<int> attPdu, {int connectionHandle = 11}) {
  final l2cap = <int>[attPdu.length, 0x00, 0x04, 0x00, ...attPdu];
  return _aclPacketRaw(
    l2cap,
    packetBoundary: 2,
    connectionHandle: connectionHandle,
  );
}

Uint8List _aclPacketRaw(
  List<int> payload, {
  required int packetBoundary,
  int connectionHandle = 11,
}) {
  final flags = (connectionHandle & 0x0FFF) | (packetBoundary << 12);
  return Uint8List.fromList([
    0x02,
    flags & 0xFF,
    (flags >> 8) & 0xFF,
    payload.length & 0xFF,
    (payload.length >> 8) & 0xFF,
    ...payload,
  ]);
}

Uint8List _aclContinuation(List<int> payload) =>
    _aclPacketRaw(payload, packetBoundary: 1);
)));
      expect(event.characteristicProperties, 0x1C);
    });

    test('keeps ATT payloads from other Bluetooth devices out of the selected session', () {
      final otherAddress = <int>[0x10, 0x20, 0x30, 0x40, 0x50, 0x60];
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(
          _advertisement(name: 'HEADPHONES', address: otherAddress),
          flags: 1,
          timestamp: 1200,
        ),
        _record(
          _connectionComplete(handle: 12, address: otherAddress),
          flags: 1,
          timestamp: 1300,
        ),
        _record(
          _aclPacket([0x52, 0x25, 0x00, 0xAA], connectionHandle: 11),
          flags: 0,
          timestamp: 1400,
        ),
        _record(
          _aclPacket([0x52, 0x26, 0x00, 0xDE, 0xAD], connectionHandle: 12),
          flags: 0,
          timestamp: 1500,
        ),
      ]));

      expect(capture.connectionSessions, hasLength(2));
      final kptSession = capture.connectionSessions.firstWhere(
        (session) => session.looksLikeKptPro,
      );
      final otherSession = capture.connectionSessions.firstWhere(
        (session) => !session.looksLikeKptPro,
      );
      expect(capture.eventsForSession(kptSession.id), hasLength(1));
      expect(capture.eventsForSession(otherSession.id), hasLength(1));

      final filtered = jsonEncode(capture.toJson(
        sessionId: kptSession.id,
        includePayload: true,
      ));
      expect(filtered, contains('AA'));
      expect(filtered, isNot(contains('DE AD')));
      expect(filtered, isNot(contains('HEADPHONES')));
    });

    test('exports only the selected connection and redacts peer address', () {
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([0x52, 0x25, 0x00, 0xDE, 0xAD]), flags: 0, timestamp: 1200),
      ]));

      final session = capture.connectionSessions.single;
      final withoutPayload = capture.toJson(
        sessionId: session.id,
        includePayload: false,
      );
      final encodedWithoutPayload = jsonEncode(withoutPayload);
      expect(encodedWithoutPayload, contains('peerAddressRedacted'));
      expect(encodedWithoutPayload, contains('otherBluetoothConnectionsExcluded'));
      expect(encodedWithoutPayload, isNot(contains('DE AD')));
      expect(encodedWithoutPayload, contains('**:**:**:**:E5:F6'));

      final withPayload = capture.toJson(
        sessionId: session.id,
        includePayload: true,
      );
      expect(jsonEncode(withPayload), contains('DE AD'));
      expect(
        () => capture.toJson(sessionId: 99, includePayload: false),
        throwsArgumentError,
      );
    });

    test('accepts an empty valid capture', () {
      final capture = BtsnoopCaptureParser.parse(_capture(const []));
      expect(capture.packetCount, 0);
      expect(capture.connectionSessions, isEmpty);
      expect(capture.attEvents, isEmpty);
    });

    test('rejects invalid magic, unsupported data-link type and truncated records', () {
      expect(
        () => BtsnoopCaptureParser.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );

      final wrongType = _capture(const [], dataLinkType: 1003);
      expect(() => BtsnoopCaptureParser.parse(wrongType), throwsFormatException);

      final truncated = Uint8List.fromList([
        ..._capture(const []),
        0x00,
        0x01,
      ]);
      expect(() => BtsnoopCaptureParser.parse(truncated), throwsFormatException);
    });

    test('tracks a fragmented L2CAP ATT packet across ACL records', () {
      final pdu = <int>[0x52, 0x25, 0x00, 0x01, 0x02, 0x03, 0x04];
      final l2cap = <int>[pdu.length, 0x00, 0x04, 0x00, ...pdu];
      final first = _aclPacketRaw(
        l2cap.sublist(0, 7),
        packetBoundary: 2,
      );
      final continuation = _aclContinuation(l2cap.sublist(7));
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(first, flags: 0, timestamp: 1200),
        _record(continuation, flags: 0, timestamp: 1300),
      ]));

      expect(capture.attEvents, hasLength(1));
      expect(capture.attEvents.single.valueHex, '01 02 03 04');
    });
  });
}

Uint8List _capture(
  List<_BtsnoopRecord> records, {
  int dataLinkType = 1002,
}) {
  final length = 16 + records.fold<int>(
    0,
    (sum, record) => sum + 24 + record.packet.length,
  );
  final bytes = Uint8List(length);
  const magic = [0x62, 0x74, 0x73, 0x6E, 0x6F, 0x6F, 0x70, 0x00];
  bytes.setRange(0, 8, magic);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 1, Endian.big);
  data.setUint32(12, dataLinkType, Endian.big);
  var offset = 16;
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final packet = record.packet;
    data.setUint32(offset, packet.length, Endian.big);
    data.setUint32(offset + 4, packet.length, Endian.big);
    data.setUint32(offset + 8, record.flags, Endian.big);
    data.setUint32(offset + 12, 0, Endian.big);
    data.setUint64(offset + 16, record.timestamp, Endian.big);
    offset += 24;
    bytes.setRange(offset, offset + packet.length, packet);
    offset += packet.length;
  }
  return bytes;
}

class _BtsnoopRecord {
  const _BtsnoopRecord(this.packet, this.flags, this.timestamp);
  final Uint8List packet;
  final int flags;
  final int timestamp;
}

_BtsnoopRecord _record(
  List<int> packet, {
  required int flags,
  required int timestamp,
}) => _BtsnoopRecord(Uint8List.fromList(packet), flags, timestamp);

Uint8List _advertisement({
  String name = 'KPTPRO_BLE',
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final nameBytes = utf8.encode(name);
  final ad = <int>[nameBytes.length + 1, 0x09, ...nameBytes];
  final params = <int>[
    0x02, // LE Advertising Report subevent.
    0x01, // One report.
    0x00, // Connectable undirected advertising.
    0x01, // Random address.
    ...address,
    ad.length,
    ...ad,
    0xC9, // -55 dBm.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

Uint8List _connectionComplete({
  int handle = 11,
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final params = <int>[
    0x01, // LE Connection Complete subevent.
    0x00, // Success.
    handle & 0xFF,
    (handle >> 8) & 0xFF,
    0x00, // Central role.
    0x01, // Random peer address.
    ...address,
    0x18, 0x00, // Connection interval.
    0x00, 0x00, // Peripheral latency.
    0xC8, 0x00, // Supervision timeout.
    0x00, // Clock accuracy.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

List<int> _uuid128Bytes(String uuid) {
  final hex = uuid.replaceAll('-', '').toLowerCase();
  return List<int>.generate(
    16,
    (index) => int.parse(
      hex.substring((15 - index) * 2, (15 - index) * 2 + 2),
      radix: 16,
    ),
  );
}

Uint8List _aclPacket(List<int> attPdu, {int connectionHandle = 11}) {
  final l2cap = <int>[attPdu.length, 0x00, 0x04, 0x00, ...attPdu];
  return _aclPacketRaw(
    l2cap,
    packetBoundary: 2,
    connectionHandle: connectionHandle,
  );
}

Uint8List _aclPacketRaw(
  List<int> payload, {
  required int packetBoundary,
  int connectionHandle = 11,
}) {
  final flags = (connectionHandle & 0x0FFF) | (packetBoundary << 12);
  return Uint8List.fromList([
    0x02,
    flags & 0xFF,
    (flags >> 8) & 0xFF,
    payload.length & 0xFF,
    (payload.length >> 8) & 0xFF,
    ...payload,
  ]);
}

Uint8List _aclContinuation(List<int> payload) =>
    _aclPacketRaw(payload, packetBoundary: 1);
)));
      expect(event.characteristicProperties, 0x1C);
    });

    test('keeps ATT payloads from other Bluetooth devices out of the selected session', () {
      final otherAddress = <int>[0x10, 0x20, 0x30, 0x40, 0x50, 0x60];
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(
          _advertisement(name: 'HEADPHONES', address: otherAddress),
          flags: 1,
          timestamp: 1200,
        ),
        _record(
          _connectionComplete(handle: 12, address: otherAddress),
          flags: 1,
          timestamp: 1300,
        ),
        _record(
          _aclPacket([0x52, 0x25, 0x00, 0xAA], connectionHandle: 11),
          flags: 0,
          timestamp: 1400,
        ),
        _record(
          _aclPacket([0x52, 0x26, 0x00, 0xDE, 0xAD], connectionHandle: 12),
          flags: 0,
          timestamp: 1500,
        ),
      ]));

      expect(capture.connectionSessions, hasLength(2));
      final kptSession = capture.connectionSessions.firstWhere(
        (session) => session.looksLikeKptPro,
      );
      final otherSession = capture.connectionSessions.firstWhere(
        (session) => !session.looksLikeKptPro,
      );
      expect(capture.eventsForSession(kptSession.id), hasLength(1));
      expect(capture.eventsForSession(otherSession.id), hasLength(1));

      final filtered = jsonEncode(capture.toJson(
        sessionId: kptSession.id,
        includePayload: true,
      ));
      expect(filtered, contains('AA'));
      expect(filtered, isNot(contains('DE AD')));
      expect(filtered, isNot(contains('HEADPHONES')));
    });

    test('exports only the selected connection and redacts peer address', () {
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([0x52, 0x25, 0x00, 0xDE, 0xAD]), flags: 0, timestamp: 1200),
      ]));

      final session = capture.connectionSessions.single;
      final withoutPayload = capture.toJson(
        sessionId: session.id,
        includePayload: false,
      );
      final encodedWithoutPayload = jsonEncode(withoutPayload);
      expect(encodedWithoutPayload, contains('peerAddressRedacted'));
      expect(encodedWithoutPayload, contains('otherBluetoothConnectionsExcluded'));
      expect(encodedWithoutPayload, isNot(contains('DE AD')));
      expect(encodedWithoutPayload, contains('**:**:**:**:E5:F6'));

      final withPayload = capture.toJson(
        sessionId: session.id,
        includePayload: true,
      );
      expect(jsonEncode(withPayload), contains('DE AD'));
      expect(
        () => capture.toJson(sessionId: 99, includePayload: false),
        throwsArgumentError,
      );
    });

    test('accepts an empty valid capture', () {
      final capture = BtsnoopCaptureParser.parse(_capture(const []));
      expect(capture.packetCount, 0);
      expect(capture.connectionSessions, isEmpty);
      expect(capture.attEvents, isEmpty);
    });

    test('rejects invalid magic, unsupported data-link type and truncated records', () {
      expect(
        () => BtsnoopCaptureParser.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );

      final wrongType = _capture(const [], dataLinkType: 1003);
      expect(() => BtsnoopCaptureParser.parse(wrongType), throwsFormatException);

      final truncated = Uint8List.fromList([
        ..._capture(const []),
        0x00,
        0x01,
      ]);
      expect(() => BtsnoopCaptureParser.parse(truncated), throwsFormatException);
    });

    test('tracks a fragmented L2CAP ATT packet across ACL records', () {
      final pdu = <int>[0x52, 0x25, 0x00, 0x01, 0x02, 0x03, 0x04];
      final l2cap = <int>[pdu.length, 0x00, 0x04, 0x00, ...pdu];
      final first = _aclPacketRaw(
        l2cap.sublist(0, 7),
        packetBoundary: 2,
      );
      final continuation = _aclContinuation(l2cap.sublist(7));
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(first, flags: 0, timestamp: 1200),
        _record(continuation, flags: 0, timestamp: 1300),
      ]));

      expect(capture.attEvents, hasLength(1));
      expect(capture.attEvents.single.valueHex, '01 02 03 04');
    });
  });
}

Uint8List _capture(
  List<_BtsnoopRecord> records, {
  int dataLinkType = 1002,
}) {
  final length = 16 + records.fold<int>(
    0,
    (sum, record) => sum + 24 + record.packet.length,
  );
  final bytes = Uint8List(length);
  const magic = [0x62, 0x74, 0x73, 0x6E, 0x6F, 0x6F, 0x70, 0x00];
  bytes.setRange(0, 8, magic);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 1, Endian.big);
  data.setUint32(12, dataLinkType, Endian.big);
  var offset = 16;
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final packet = record.packet;
    data.setUint32(offset, packet.length, Endian.big);
    data.setUint32(offset + 4, packet.length, Endian.big);
    data.setUint32(offset + 8, record.flags, Endian.big);
    data.setUint32(offset + 12, 0, Endian.big);
    data.setUint64(offset + 16, record.timestamp, Endian.big);
    offset += 24;
    bytes.setRange(offset, offset + packet.length, packet);
    offset += packet.length;
  }
  return bytes;
}

class _BtsnoopRecord {
  const _BtsnoopRecord(this.packet, this.flags, this.timestamp);
  final Uint8List packet;
  final int flags;
  final int timestamp;
}

_BtsnoopRecord _record(
  List<int> packet, {
  required int flags,
  required int timestamp,
}) => _BtsnoopRecord(Uint8List.fromList(packet), flags, timestamp);

Uint8List _advertisement({
  String name = 'KPTPRO_BLE',
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final nameBytes = utf8.encode(name);
  final ad = <int>[nameBytes.length + 1, 0x09, ...nameBytes];
  final params = <int>[
    0x02, // LE Advertising Report subevent.
    0x01, // One report.
    0x00, // Connectable undirected advertising.
    0x01, // Random address.
    ...address,
    ad.length,
    ...ad,
    0xC9, // -55 dBm.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

Uint8List _connectionComplete({
  int handle = 11,
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final params = <int>[
    0x01, // LE Connection Complete subevent.
    0x00, // Success.
    handle & 0xFF,
    (handle >> 8) & 0xFF,
    0x00, // Central role.
    0x01, // Random peer address.
    ...address,
    0x18, 0x00, // Connection interval.
    0x00, 0x00, // Peripheral latency.
    0xC8, 0x00, // Supervision timeout.
    0x00, // Clock accuracy.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

List<int> _uuid128Bytes(String uuid) {
  final hex = uuid.replaceAll('-', '').toLowerCase();
  return List<int>.generate(
    16,
    (index) => int.parse(
      hex.substring((15 - index) * 2, (15 - index) * 2 + 2),
      radix: 16,
    ),
  );
}

Uint8List _aclPacket(List<int> attPdu, {int connectionHandle = 11}) {
  final l2cap = <int>[attPdu.length, 0x00, 0x04, 0x00, ...attPdu];
  return _aclPacketRaw(
    l2cap,
    packetBoundary: 2,
    connectionHandle: connectionHandle,
  );
}

Uint8List _aclPacketRaw(
  List<int> payload, {
  required int packetBoundary,
  int connectionHandle = 11,
}) {
  final flags = (connectionHandle & 0x0FFF) | (packetBoundary << 12);
  return Uint8List.fromList([
    0x02,
    flags & 0xFF,
    (flags >> 8) & 0xFF,
    payload.length & 0xFF,
    (payload.length >> 8) & 0xFF,
    ...payload,
  ]);
}

Uint8List _aclContinuation(List<int> payload) =>
    _aclPacketRaw(payload, packetBoundary: 1);
)));
      expect(event.serviceUuid, matches(RegExp(r'^[0-9a-f-]{36}
      expect(event.characteristicProperties, 0x1C);
    });

    test('keeps ATT payloads from other Bluetooth devices out of the selected session', () {
      final otherAddress = <int>[0x10, 0x20, 0x30, 0x40, 0x50, 0x60];
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(
          _advertisement(name: 'HEADPHONES', address: otherAddress),
          flags: 1,
          timestamp: 1200,
        ),
        _record(
          _connectionComplete(handle: 12, address: otherAddress),
          flags: 1,
          timestamp: 1300,
        ),
        _record(
          _aclPacket([0x52, 0x25, 0x00, 0xAA], connectionHandle: 11),
          flags: 0,
          timestamp: 1400,
        ),
        _record(
          _aclPacket([0x52, 0x26, 0x00, 0xDE, 0xAD], connectionHandle: 12),
          flags: 0,
          timestamp: 1500,
        ),
      ]));

      expect(capture.connectionSessions, hasLength(2));
      final kptSession = capture.connectionSessions.firstWhere(
        (session) => session.looksLikeKptPro,
      );
      final otherSession = capture.connectionSessions.firstWhere(
        (session) => !session.looksLikeKptPro,
      );
      expect(capture.eventsForSession(kptSession.id), hasLength(1));
      expect(capture.eventsForSession(otherSession.id), hasLength(1));

      final filtered = jsonEncode(capture.toJson(
        sessionId: kptSession.id,
        includePayload: true,
      ));
      expect(filtered, contains('AA'));
      expect(filtered, isNot(contains('DE AD')));
      expect(filtered, isNot(contains('HEADPHONES')));
    });

    test('exports only the selected connection and redacts peer address', () {
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([0x52, 0x25, 0x00, 0xDE, 0xAD]), flags: 0, timestamp: 1200),
      ]));

      final session = capture.connectionSessions.single;
      final withoutPayload = capture.toJson(
        sessionId: session.id,
        includePayload: false,
      );
      final encodedWithoutPayload = jsonEncode(withoutPayload);
      expect(encodedWithoutPayload, contains('peerAddressRedacted'));
      expect(encodedWithoutPayload, contains('otherBluetoothConnectionsExcluded'));
      expect(encodedWithoutPayload, isNot(contains('DE AD')));
      expect(encodedWithoutPayload, contains('**:**:**:**:E5:F6'));

      final withPayload = capture.toJson(
        sessionId: session.id,
        includePayload: true,
      );
      expect(jsonEncode(withPayload), contains('DE AD'));
      expect(
        () => capture.toJson(sessionId: 99, includePayload: false),
        throwsArgumentError,
      );
    });

    test('accepts an empty valid capture', () {
      final capture = BtsnoopCaptureParser.parse(_capture(const []));
      expect(capture.packetCount, 0);
      expect(capture.connectionSessions, isEmpty);
      expect(capture.attEvents, isEmpty);
    });

    test('rejects invalid magic, unsupported data-link type and truncated records', () {
      expect(
        () => BtsnoopCaptureParser.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );

      final wrongType = _capture(const [], dataLinkType: 1003);
      expect(() => BtsnoopCaptureParser.parse(wrongType), throwsFormatException);

      final truncated = Uint8List.fromList([
        ..._capture(const []),
        0x00,
        0x01,
      ]);
      expect(() => BtsnoopCaptureParser.parse(truncated), throwsFormatException);
    });

    test('tracks a fragmented L2CAP ATT packet across ACL records', () {
      final pdu = <int>[0x52, 0x25, 0x00, 0x01, 0x02, 0x03, 0x04];
      final l2cap = <int>[pdu.length, 0x00, 0x04, 0x00, ...pdu];
      final first = _aclPacketRaw(
        l2cap.sublist(0, 7),
        packetBoundary: 2,
      );
      final continuation = _aclContinuation(l2cap.sublist(7));
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(first, flags: 0, timestamp: 1200),
        _record(continuation, flags: 0, timestamp: 1300),
      ]));

      expect(capture.attEvents, hasLength(1));
      expect(capture.attEvents.single.valueHex, '01 02 03 04');
    });
  });
}

Uint8List _capture(
  List<_BtsnoopRecord> records, {
  int dataLinkType = 1002,
}) {
  final length = 16 + records.fold<int>(
    0,
    (sum, record) => sum + 24 + record.packet.length,
  );
  final bytes = Uint8List(length);
  const magic = [0x62, 0x74, 0x73, 0x6E, 0x6F, 0x6F, 0x70, 0x00];
  bytes.setRange(0, 8, magic);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 1, Endian.big);
  data.setUint32(12, dataLinkType, Endian.big);
  var offset = 16;
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final packet = record.packet;
    data.setUint32(offset, packet.length, Endian.big);
    data.setUint32(offset + 4, packet.length, Endian.big);
    data.setUint32(offset + 8, record.flags, Endian.big);
    data.setUint32(offset + 12, 0, Endian.big);
    data.setUint64(offset + 16, record.timestamp, Endian.big);
    offset += 24;
    bytes.setRange(offset, offset + packet.length, packet);
    offset += packet.length;
  }
  return bytes;
}

class _BtsnoopRecord {
  const _BtsnoopRecord(this.packet, this.flags, this.timestamp);
  final Uint8List packet;
  final int flags;
  final int timestamp;
}

_BtsnoopRecord _record(
  List<int> packet, {
  required int flags,
  required int timestamp,
}) => _BtsnoopRecord(Uint8List.fromList(packet), flags, timestamp);

Uint8List _advertisement({
  String name = 'KPTPRO_BLE',
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final nameBytes = utf8.encode(name);
  final ad = <int>[nameBytes.length + 1, 0x09, ...nameBytes];
  final params = <int>[
    0x02, // LE Advertising Report subevent.
    0x01, // One report.
    0x00, // Connectable undirected advertising.
    0x01, // Random address.
    ...address,
    ad.length,
    ...ad,
    0xC9, // -55 dBm.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

Uint8List _connectionComplete({
  int handle = 11,
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final params = <int>[
    0x01, // LE Connection Complete subevent.
    0x00, // Success.
    handle & 0xFF,
    (handle >> 8) & 0xFF,
    0x00, // Central role.
    0x01, // Random peer address.
    ...address,
    0x18, 0x00, // Connection interval.
    0x00, 0x00, // Peripheral latency.
    0xC8, 0x00, // Supervision timeout.
    0x00, // Clock accuracy.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

List<int> _uuid128Bytes(String uuid) {
  final hex = uuid.replaceAll('-', '').toLowerCase();
  return List<int>.generate(
    16,
    (index) => int.parse(
      hex.substring((15 - index) * 2, (15 - index) * 2 + 2),
      radix: 16,
    ),
  );
}

Uint8List _aclPacket(List<int> attPdu, {int connectionHandle = 11}) {
  final l2cap = <int>[attPdu.length, 0x00, 0x04, 0x00, ...attPdu];
  return _aclPacketRaw(
    l2cap,
    packetBoundary: 2,
    connectionHandle: connectionHandle,
  );
}

Uint8List _aclPacketRaw(
  List<int> payload, {
  required int packetBoundary,
  int connectionHandle = 11,
}) {
  final flags = (connectionHandle & 0x0FFF) | (packetBoundary << 12);
  return Uint8List.fromList([
    0x02,
    flags & 0xFF,
    (flags >> 8) & 0xFF,
    payload.length & 0xFF,
    (payload.length >> 8) & 0xFF,
    ...payload,
  ]);
}

Uint8List _aclContinuation(List<int> payload) =>
    _aclPacketRaw(payload, packetBoundary: 1);
)));
      expect(event.characteristicProperties, 0x1C);
    });

    test('keeps ATT payloads from other Bluetooth devices out of the selected session', () {
      final otherAddress = <int>[0x10, 0x20, 0x30, 0x40, 0x50, 0x60];
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(
          _advertisement(name: 'HEADPHONES', address: otherAddress),
          flags: 1,
          timestamp: 1200,
        ),
        _record(
          _connectionComplete(handle: 12, address: otherAddress),
          flags: 1,
          timestamp: 1300,
        ),
        _record(
          _aclPacket([0x52, 0x25, 0x00, 0xAA], connectionHandle: 11),
          flags: 0,
          timestamp: 1400,
        ),
        _record(
          _aclPacket([0x52, 0x26, 0x00, 0xDE, 0xAD], connectionHandle: 12),
          flags: 0,
          timestamp: 1500,
        ),
      ]));

      expect(capture.connectionSessions, hasLength(2));
      final kptSession = capture.connectionSessions.firstWhere(
        (session) => session.looksLikeKptPro,
      );
      final otherSession = capture.connectionSessions.firstWhere(
        (session) => !session.looksLikeKptPro,
      );
      expect(capture.eventsForSession(kptSession.id), hasLength(1));
      expect(capture.eventsForSession(otherSession.id), hasLength(1));

      final filtered = jsonEncode(capture.toJson(
        sessionId: kptSession.id,
        includePayload: true,
      ));
      expect(filtered, contains('AA'));
      expect(filtered, isNot(contains('DE AD')));
      expect(filtered, isNot(contains('HEADPHONES')));
    });

    test('exports only the selected connection and redacts peer address', () {
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([0x52, 0x25, 0x00, 0xDE, 0xAD]), flags: 0, timestamp: 1200),
      ]));

      final session = capture.connectionSessions.single;
      final withoutPayload = capture.toJson(
        sessionId: session.id,
        includePayload: false,
      );
      final encodedWithoutPayload = jsonEncode(withoutPayload);
      expect(encodedWithoutPayload, contains('peerAddressRedacted'));
      expect(encodedWithoutPayload, contains('otherBluetoothConnectionsExcluded'));
      expect(encodedWithoutPayload, isNot(contains('DE AD')));
      expect(encodedWithoutPayload, contains('**:**:**:**:E5:F6'));

      final withPayload = capture.toJson(
        sessionId: session.id,
        includePayload: true,
      );
      expect(jsonEncode(withPayload), contains('DE AD'));
      expect(
        () => capture.toJson(sessionId: 99, includePayload: false),
        throwsArgumentError,
      );
    });

    test('accepts an empty valid capture', () {
      final capture = BtsnoopCaptureParser.parse(_capture(const []));
      expect(capture.packetCount, 0);
      expect(capture.connectionSessions, isEmpty);
      expect(capture.attEvents, isEmpty);
    });

    test('rejects invalid magic, unsupported data-link type and truncated records', () {
      expect(
        () => BtsnoopCaptureParser.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );

      final wrongType = _capture(const [], dataLinkType: 1003);
      expect(() => BtsnoopCaptureParser.parse(wrongType), throwsFormatException);

      final truncated = Uint8List.fromList([
        ..._capture(const []),
        0x00,
        0x01,
      ]);
      expect(() => BtsnoopCaptureParser.parse(truncated), throwsFormatException);
    });

    test('tracks a fragmented L2CAP ATT packet across ACL records', () {
      final pdu = <int>[0x52, 0x25, 0x00, 0x01, 0x02, 0x03, 0x04];
      final l2cap = <int>[pdu.length, 0x00, 0x04, 0x00, ...pdu];
      final first = _aclPacketRaw(
        l2cap.sublist(0, 7),
        packetBoundary: 2,
      );
      final continuation = _aclContinuation(l2cap.sublist(7));
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(first, flags: 0, timestamp: 1200),
        _record(continuation, flags: 0, timestamp: 1300),
      ]));

      expect(capture.attEvents, hasLength(1));
      expect(capture.attEvents.single.valueHex, '01 02 03 04');
    });
  });
}

Uint8List _capture(
  List<_BtsnoopRecord> records, {
  int dataLinkType = 1002,
}) {
  final length = 16 + records.fold<int>(
    0,
    (sum, record) => sum + 24 + record.packet.length,
  );
  final bytes = Uint8List(length);
  const magic = [0x62, 0x74, 0x73, 0x6E, 0x6F, 0x6F, 0x70, 0x00];
  bytes.setRange(0, 8, magic);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 1, Endian.big);
  data.setUint32(12, dataLinkType, Endian.big);
  var offset = 16;
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final packet = record.packet;
    data.setUint32(offset, packet.length, Endian.big);
    data.setUint32(offset + 4, packet.length, Endian.big);
    data.setUint32(offset + 8, record.flags, Endian.big);
    data.setUint32(offset + 12, 0, Endian.big);
    data.setUint64(offset + 16, record.timestamp, Endian.big);
    offset += 24;
    bytes.setRange(offset, offset + packet.length, packet);
    offset += packet.length;
  }
  return bytes;
}

class _BtsnoopRecord {
  const _BtsnoopRecord(this.packet, this.flags, this.timestamp);
  final Uint8List packet;
  final int flags;
  final int timestamp;
}

_BtsnoopRecord _record(
  List<int> packet, {
  required int flags,
  required int timestamp,
}) => _BtsnoopRecord(Uint8List.fromList(packet), flags, timestamp);

Uint8List _advertisement({
  String name = 'KPTPRO_BLE',
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final nameBytes = utf8.encode(name);
  final ad = <int>[nameBytes.length + 1, 0x09, ...nameBytes];
  final params = <int>[
    0x02, // LE Advertising Report subevent.
    0x01, // One report.
    0x00, // Connectable undirected advertising.
    0x01, // Random address.
    ...address,
    ad.length,
    ...ad,
    0xC9, // -55 dBm.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

Uint8List _connectionComplete({
  int handle = 11,
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final params = <int>[
    0x01, // LE Connection Complete subevent.
    0x00, // Success.
    handle & 0xFF,
    (handle >> 8) & 0xFF,
    0x00, // Central role.
    0x01, // Random peer address.
    ...address,
    0x18, 0x00, // Connection interval.
    0x00, 0x00, // Peripheral latency.
    0xC8, 0x00, // Supervision timeout.
    0x00, // Clock accuracy.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

List<int> _uuid128Bytes(String uuid) {
  final hex = uuid.replaceAll('-', '').toLowerCase();
  return List<int>.generate(
    16,
    (index) => int.parse(
      hex.substring((15 - index) * 2, (15 - index) * 2 + 2),
      radix: 16,
    ),
  );
}

Uint8List _aclPacket(List<int> attPdu, {int connectionHandle = 11}) {
  final l2cap = <int>[attPdu.length, 0x00, 0x04, 0x00, ...attPdu];
  return _aclPacketRaw(
    l2cap,
    packetBoundary: 2,
    connectionHandle: connectionHandle,
  );
}

Uint8List _aclPacketRaw(
  List<int> payload, {
  required int packetBoundary,
  int connectionHandle = 11,
}) {
  final flags = (connectionHandle & 0x0FFF) | (packetBoundary << 12);
  return Uint8List.fromList([
    0x02,
    flags & 0xFF,
    (flags >> 8) & 0xFF,
    payload.length & 0xFF,
    (payload.length >> 8) & 0xFF,
    ...payload,
  ]);
}

Uint8List _aclContinuation(List<int> payload) =>
    _aclPacketRaw(payload, packetBoundary: 1);
)));
    });

    test('keeps ATT payloads from other Bluetooth devices out of the selected session', () {
      final otherAddress = <int>[0x10, 0x20, 0x30, 0x40, 0x50, 0x60];
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(
          _advertisement(name: 'HEADPHONES', address: otherAddress),
          flags: 1,
          timestamp: 1200,
        ),
        _record(
          _connectionComplete(handle: 12, address: otherAddress),
          flags: 1,
          timestamp: 1300,
        ),
        _record(
          _aclPacket([0x52, 0x25, 0x00, 0xAA], connectionHandle: 11),
          flags: 0,
          timestamp: 1400,
        ),
        _record(
          _aclPacket([0x52, 0x26, 0x00, 0xDE, 0xAD], connectionHandle: 12),
          flags: 0,
          timestamp: 1500,
        ),
      ]));

      expect(capture.connectionSessions, hasLength(2));
      final kptSession = capture.connectionSessions.firstWhere(
        (session) => session.looksLikeKptPro,
      );
      final otherSession = capture.connectionSessions.firstWhere(
        (session) => !session.looksLikeKptPro,
      );
      expect(capture.eventsForSession(kptSession.id), hasLength(1));
      expect(capture.eventsForSession(otherSession.id), hasLength(1));

      final filtered = jsonEncode(capture.toJson(
        sessionId: kptSession.id,
        includePayload: true,
      ));
      expect(filtered, contains('AA'));
      expect(filtered, isNot(contains('DE AD')));
      expect(filtered, isNot(contains('HEADPHONES')));
    });

    test('exports only the selected connection and redacts peer address', () {
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([0x52, 0x25, 0x00, 0xDE, 0xAD]), flags: 0, timestamp: 1200),
      ]));

      final session = capture.connectionSessions.single;
      final withoutPayload = capture.toJson(
        sessionId: session.id,
        includePayload: false,
      );
      final encodedWithoutPayload = jsonEncode(withoutPayload);
      expect(encodedWithoutPayload, contains('peerAddressRedacted'));
      expect(encodedWithoutPayload, contains('otherBluetoothConnectionsExcluded'));
      expect(encodedWithoutPayload, isNot(contains('DE AD')));
      expect(encodedWithoutPayload, contains('**:**:**:**:E5:F6'));

      final withPayload = capture.toJson(
        sessionId: session.id,
        includePayload: true,
      );
      expect(jsonEncode(withPayload), contains('DE AD'));
      expect(
        () => capture.toJson(sessionId: 99, includePayload: false),
        throwsArgumentError,
      );
    });

    test('accepts an empty valid capture', () {
      final capture = BtsnoopCaptureParser.parse(_capture(const []));
      expect(capture.packetCount, 0);
      expect(capture.connectionSessions, isEmpty);
      expect(capture.attEvents, isEmpty);
    });

    test('rejects invalid magic, unsupported data-link type and truncated records', () {
      expect(
        () => BtsnoopCaptureParser.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );

      final wrongType = _capture(const [], dataLinkType: 1003);
      expect(() => BtsnoopCaptureParser.parse(wrongType), throwsFormatException);

      final truncated = Uint8List.fromList([
        ..._capture(const []),
        0x00,
        0x01,
      ]);
      expect(() => BtsnoopCaptureParser.parse(truncated), throwsFormatException);
    });

    test('tracks a fragmented L2CAP ATT packet across ACL records', () {
      final pdu = <int>[0x52, 0x25, 0x00, 0x01, 0x02, 0x03, 0x04];
      final l2cap = <int>[pdu.length, 0x00, 0x04, 0x00, ...pdu];
      final first = _aclPacketRaw(
        l2cap.sublist(0, 7),
        packetBoundary: 2,
      );
      final continuation = _aclContinuation(l2cap.sublist(7));
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(first, flags: 0, timestamp: 1200),
        _record(continuation, flags: 0, timestamp: 1300),
      ]));

      expect(capture.attEvents, hasLength(1));
      expect(capture.attEvents.single.valueHex, '01 02 03 04');
    });
  });
}

Uint8List _capture(
  List<_BtsnoopRecord> records, {
  int dataLinkType = 1002,
}) {
  final length = 16 + records.fold<int>(
    0,
    (sum, record) => sum + 24 + record.packet.length,
  );
  final bytes = Uint8List(length);
  const magic = [0x62, 0x74, 0x73, 0x6E, 0x6F, 0x6F, 0x70, 0x00];
  bytes.setRange(0, 8, magic);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 1, Endian.big);
  data.setUint32(12, dataLinkType, Endian.big);
  var offset = 16;
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final packet = record.packet;
    data.setUint32(offset, packet.length, Endian.big);
    data.setUint32(offset + 4, packet.length, Endian.big);
    data.setUint32(offset + 8, record.flags, Endian.big);
    data.setUint32(offset + 12, 0, Endian.big);
    data.setUint64(offset + 16, record.timestamp, Endian.big);
    offset += 24;
    bytes.setRange(offset, offset + packet.length, packet);
    offset += packet.length;
  }
  return bytes;
}

class _BtsnoopRecord {
  const _BtsnoopRecord(this.packet, this.flags, this.timestamp);
  final Uint8List packet;
  final int flags;
  final int timestamp;
}

_BtsnoopRecord _record(
  List<int> packet, {
  required int flags,
  required int timestamp,
}) => _BtsnoopRecord(Uint8List.fromList(packet), flags, timestamp);

Uint8List _advertisement({
  String name = 'KPTPRO_BLE',
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final nameBytes = utf8.encode(name);
  final ad = <int>[nameBytes.length + 1, 0x09, ...nameBytes];
  final params = <int>[
    0x02, // LE Advertising Report subevent.
    0x01, // One report.
    0x00, // Connectable undirected advertising.
    0x01, // Random address.
    ...address,
    ad.length,
    ...ad,
    0xC9, // -55 dBm.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

Uint8List _connectionComplete({
  int handle = 11,
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final params = <int>[
    0x01, // LE Connection Complete subevent.
    0x00, // Success.
    handle & 0xFF,
    (handle >> 8) & 0xFF,
    0x00, // Central role.
    0x01, // Random peer address.
    ...address,
    0x18, 0x00, // Connection interval.
    0x00, 0x00, // Peripheral latency.
    0xC8, 0x00, // Supervision timeout.
    0x00, // Clock accuracy.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

List<int> _uuid128Bytes(String uuid) {
  final hex = uuid.replaceAll('-', '').toLowerCase();
  return List<int>.generate(
    16,
    (index) => int.parse(
      hex.substring((15 - index) * 2, (15 - index) * 2 + 2),
      radix: 16,
    ),
  );
}

Uint8List _disconnectComplete({int handle = 11}) => Uint8List.fromList([
  0x04,
  0x05,
  0x04,
  0x00,
  handle & 0xFF,
  (handle >> 8) & 0xFF,
  0x13,
]);

Uint8List _aclPacket(List<int> attPdu, {int connectionHandle = 11}) {
  final l2cap = <int>[attPdu.length, 0x00, 0x04, 0x00, ...attPdu];
  return _aclPacketRaw(
    l2cap,
    packetBoundary: 2,
    connectionHandle: connectionHandle,
  );
}

Uint8List _aclPacketRaw(
  List<int> payload, {
  required int packetBoundary,
  int connectionHandle = 11,
}) {
  final flags = (connectionHandle & 0x0FFF) | (packetBoundary << 12);
  return Uint8List.fromList([
    0x02,
    flags & 0xFF,
    (flags >> 8) & 0xFF,
    payload.length & 0xFF,
    (payload.length >> 8) & 0xFF,
    ...payload,
  ]);
}

Uint8List _aclContinuation(List<int> payload) =>
    _aclPacketRaw(payload, packetBoundary: 1);
)));
      expect(event.serviceUuid, matches(RegExp(r'^[0-9a-f-]{36}
      expect(event.characteristicProperties, 0x1C);
    });

    test('keeps ATT payloads from other Bluetooth devices out of the selected session', () {
      final otherAddress = <int>[0x10, 0x20, 0x30, 0x40, 0x50, 0x60];
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(
          _advertisement(name: 'HEADPHONES', address: otherAddress),
          flags: 1,
          timestamp: 1200,
        ),
        _record(
          _connectionComplete(handle: 12, address: otherAddress),
          flags: 1,
          timestamp: 1300,
        ),
        _record(
          _aclPacket([0x52, 0x25, 0x00, 0xAA], connectionHandle: 11),
          flags: 0,
          timestamp: 1400,
        ),
        _record(
          _aclPacket([0x52, 0x26, 0x00, 0xDE, 0xAD], connectionHandle: 12),
          flags: 0,
          timestamp: 1500,
        ),
      ]));

      expect(capture.connectionSessions, hasLength(2));
      final kptSession = capture.connectionSessions.firstWhere(
        (session) => session.looksLikeKptPro,
      );
      final otherSession = capture.connectionSessions.firstWhere(
        (session) => !session.looksLikeKptPro,
      );
      expect(capture.eventsForSession(kptSession.id), hasLength(1));
      expect(capture.eventsForSession(otherSession.id), hasLength(1));

      final filtered = jsonEncode(capture.toJson(
        sessionId: kptSession.id,
        includePayload: true,
      ));
      expect(filtered, contains('AA'));
      expect(filtered, isNot(contains('DE AD')));
      expect(filtered, isNot(contains('HEADPHONES')));
    });

    test('exports only the selected connection and redacts peer address', () {
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([0x52, 0x25, 0x00, 0xDE, 0xAD]), flags: 0, timestamp: 1200),
      ]));

      final session = capture.connectionSessions.single;
      final withoutPayload = capture.toJson(
        sessionId: session.id,
        includePayload: false,
      );
      final encodedWithoutPayload = jsonEncode(withoutPayload);
      expect(encodedWithoutPayload, contains('peerAddressRedacted'));
      expect(encodedWithoutPayload, contains('otherBluetoothConnectionsExcluded'));
      expect(encodedWithoutPayload, isNot(contains('DE AD')));
      expect(encodedWithoutPayload, contains('**:**:**:**:E5:F6'));

      final withPayload = capture.toJson(
        sessionId: session.id,
        includePayload: true,
      );
      expect(jsonEncode(withPayload), contains('DE AD'));
      expect(
        () => capture.toJson(sessionId: 99, includePayload: false),
        throwsArgumentError,
      );
    });

    test('accepts an empty valid capture', () {
      final capture = BtsnoopCaptureParser.parse(_capture(const []));
      expect(capture.packetCount, 0);
      expect(capture.connectionSessions, isEmpty);
      expect(capture.attEvents, isEmpty);
    });

    test('rejects invalid magic, unsupported data-link type and truncated records', () {
      expect(
        () => BtsnoopCaptureParser.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );

      final wrongType = _capture(const [], dataLinkType: 1003);
      expect(() => BtsnoopCaptureParser.parse(wrongType), throwsFormatException);

      final truncated = Uint8List.fromList([
        ..._capture(const []),
        0x00,
        0x01,
      ]);
      expect(() => BtsnoopCaptureParser.parse(truncated), throwsFormatException);
    });

    test('tracks a fragmented L2CAP ATT packet across ACL records', () {
      final pdu = <int>[0x52, 0x25, 0x00, 0x01, 0x02, 0x03, 0x04];
      final l2cap = <int>[pdu.length, 0x00, 0x04, 0x00, ...pdu];
      final first = _aclPacketRaw(
        l2cap.sublist(0, 7),
        packetBoundary: 2,
      );
      final continuation = _aclContinuation(l2cap.sublist(7));
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(first, flags: 0, timestamp: 1200),
        _record(continuation, flags: 0, timestamp: 1300),
      ]));

      expect(capture.attEvents, hasLength(1));
      expect(capture.attEvents.single.valueHex, '01 02 03 04');
    });
  });
}

Uint8List _capture(
  List<_BtsnoopRecord> records, {
  int dataLinkType = 1002,
}) {
  final length = 16 + records.fold<int>(
    0,
    (sum, record) => sum + 24 + record.packet.length,
  );
  final bytes = Uint8List(length);
  const magic = [0x62, 0x74, 0x73, 0x6E, 0x6F, 0x6F, 0x70, 0x00];
  bytes.setRange(0, 8, magic);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 1, Endian.big);
  data.setUint32(12, dataLinkType, Endian.big);
  var offset = 16;
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final packet = record.packet;
    data.setUint32(offset, packet.length, Endian.big);
    data.setUint32(offset + 4, packet.length, Endian.big);
    data.setUint32(offset + 8, record.flags, Endian.big);
    data.setUint32(offset + 12, 0, Endian.big);
    data.setUint64(offset + 16, record.timestamp, Endian.big);
    offset += 24;
    bytes.setRange(offset, offset + packet.length, packet);
    offset += packet.length;
  }
  return bytes;
}

class _BtsnoopRecord {
  const _BtsnoopRecord(this.packet, this.flags, this.timestamp);
  final Uint8List packet;
  final int flags;
  final int timestamp;
}

_BtsnoopRecord _record(
  List<int> packet, {
  required int flags,
  required int timestamp,
}) => _BtsnoopRecord(Uint8List.fromList(packet), flags, timestamp);

Uint8List _advertisement({
  String name = 'KPTPRO_BLE',
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final nameBytes = utf8.encode(name);
  final ad = <int>[nameBytes.length + 1, 0x09, ...nameBytes];
  final params = <int>[
    0x02, // LE Advertising Report subevent.
    0x01, // One report.
    0x00, // Connectable undirected advertising.
    0x01, // Random address.
    ...address,
    ad.length,
    ...ad,
    0xC9, // -55 dBm.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

Uint8List _connectionComplete({
  int handle = 11,
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final params = <int>[
    0x01, // LE Connection Complete subevent.
    0x00, // Success.
    handle & 0xFF,
    (handle >> 8) & 0xFF,
    0x00, // Central role.
    0x01, // Random peer address.
    ...address,
    0x18, 0x00, // Connection interval.
    0x00, 0x00, // Peripheral latency.
    0xC8, 0x00, // Supervision timeout.
    0x00, // Clock accuracy.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

List<int> _uuid128Bytes(String uuid) {
  final hex = uuid.replaceAll('-', '').toLowerCase();
  return List<int>.generate(
    16,
    (index) => int.parse(
      hex.substring((15 - index) * 2, (15 - index) * 2 + 2),
      radix: 16,
    ),
  );
}

Uint8List _aclPacket(List<int> attPdu, {int connectionHandle = 11}) {
  final l2cap = <int>[attPdu.length, 0x00, 0x04, 0x00, ...attPdu];
  return _aclPacketRaw(
    l2cap,
    packetBoundary: 2,
    connectionHandle: connectionHandle,
  );
}

Uint8List _aclPacketRaw(
  List<int> payload, {
  required int packetBoundary,
  int connectionHandle = 11,
}) {
  final flags = (connectionHandle & 0x0FFF) | (packetBoundary << 12);
  return Uint8List.fromList([
    0x02,
    flags & 0xFF,
    (flags >> 8) & 0xFF,
    payload.length & 0xFF,
    (payload.length >> 8) & 0xFF,
    ...payload,
  ]);
}

Uint8List _aclContinuation(List<int> payload) =>
    _aclPacketRaw(payload, packetBoundary: 1);
)));
      expect(event.characteristicProperties, 0x1C);
    });

    test('keeps ATT payloads from other Bluetooth devices out of the selected session', () {
      final otherAddress = <int>[0x10, 0x20, 0x30, 0x40, 0x50, 0x60];
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(
          _advertisement(name: 'HEADPHONES', address: otherAddress),
          flags: 1,
          timestamp: 1200,
        ),
        _record(
          _connectionComplete(handle: 12, address: otherAddress),
          flags: 1,
          timestamp: 1300,
        ),
        _record(
          _aclPacket([0x52, 0x25, 0x00, 0xAA], connectionHandle: 11),
          flags: 0,
          timestamp: 1400,
        ),
        _record(
          _aclPacket([0x52, 0x26, 0x00, 0xDE, 0xAD], connectionHandle: 12),
          flags: 0,
          timestamp: 1500,
        ),
      ]));

      expect(capture.connectionSessions, hasLength(2));
      final kptSession = capture.connectionSessions.firstWhere(
        (session) => session.looksLikeKptPro,
      );
      final otherSession = capture.connectionSessions.firstWhere(
        (session) => !session.looksLikeKptPro,
      );
      expect(capture.eventsForSession(kptSession.id), hasLength(1));
      expect(capture.eventsForSession(otherSession.id), hasLength(1));

      final filtered = jsonEncode(capture.toJson(
        sessionId: kptSession.id,
        includePayload: true,
      ));
      expect(filtered, contains('AA'));
      expect(filtered, isNot(contains('DE AD')));
      expect(filtered, isNot(contains('HEADPHONES')));
    });

    test('exports only the selected connection and redacts peer address', () {
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([0x52, 0x25, 0x00, 0xDE, 0xAD]), flags: 0, timestamp: 1200),
      ]));

      final session = capture.connectionSessions.single;
      final withoutPayload = capture.toJson(
        sessionId: session.id,
        includePayload: false,
      );
      final encodedWithoutPayload = jsonEncode(withoutPayload);
      expect(encodedWithoutPayload, contains('peerAddressRedacted'));
      expect(encodedWithoutPayload, contains('otherBluetoothConnectionsExcluded'));
      expect(encodedWithoutPayload, isNot(contains('DE AD')));
      expect(encodedWithoutPayload, contains('**:**:**:**:E5:F6'));

      final withPayload = capture.toJson(
        sessionId: session.id,
        includePayload: true,
      );
      expect(jsonEncode(withPayload), contains('DE AD'));
      expect(
        () => capture.toJson(sessionId: 99, includePayload: false),
        throwsArgumentError,
      );
    });

    test('accepts an empty valid capture', () {
      final capture = BtsnoopCaptureParser.parse(_capture(const []));
      expect(capture.packetCount, 0);
      expect(capture.connectionSessions, isEmpty);
      expect(capture.attEvents, isEmpty);
    });

    test('rejects invalid magic, unsupported data-link type and truncated records', () {
      expect(
        () => BtsnoopCaptureParser.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );

      final wrongType = _capture(const [], dataLinkType: 1003);
      expect(() => BtsnoopCaptureParser.parse(wrongType), throwsFormatException);

      final truncated = Uint8List.fromList([
        ..._capture(const []),
        0x00,
        0x01,
      ]);
      expect(() => BtsnoopCaptureParser.parse(truncated), throwsFormatException);
    });

    test('tracks a fragmented L2CAP ATT packet across ACL records', () {
      final pdu = <int>[0x52, 0x25, 0x00, 0x01, 0x02, 0x03, 0x04];
      final l2cap = <int>[pdu.length, 0x00, 0x04, 0x00, ...pdu];
      final first = _aclPacketRaw(
        l2cap.sublist(0, 7),
        packetBoundary: 2,
      );
      final continuation = _aclContinuation(l2cap.sublist(7));
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(first, flags: 0, timestamp: 1200),
        _record(continuation, flags: 0, timestamp: 1300),
      ]));

      expect(capture.attEvents, hasLength(1));
      expect(capture.attEvents.single.valueHex, '01 02 03 04');
    });
  });
}

Uint8List _capture(
  List<_BtsnoopRecord> records, {
  int dataLinkType = 1002,
}) {
  final length = 16 + records.fold<int>(
    0,
    (sum, record) => sum + 24 + record.packet.length,
  );
  final bytes = Uint8List(length);
  const magic = [0x62, 0x74, 0x73, 0x6E, 0x6F, 0x6F, 0x70, 0x00];
  bytes.setRange(0, 8, magic);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 1, Endian.big);
  data.setUint32(12, dataLinkType, Endian.big);
  var offset = 16;
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final packet = record.packet;
    data.setUint32(offset, packet.length, Endian.big);
    data.setUint32(offset + 4, packet.length, Endian.big);
    data.setUint32(offset + 8, record.flags, Endian.big);
    data.setUint32(offset + 12, 0, Endian.big);
    data.setUint64(offset + 16, record.timestamp, Endian.big);
    offset += 24;
    bytes.setRange(offset, offset + packet.length, packet);
    offset += packet.length;
  }
  return bytes;
}

class _BtsnoopRecord {
  const _BtsnoopRecord(this.packet, this.flags, this.timestamp);
  final Uint8List packet;
  final int flags;
  final int timestamp;
}

_BtsnoopRecord _record(
  List<int> packet, {
  required int flags,
  required int timestamp,
}) => _BtsnoopRecord(Uint8List.fromList(packet), flags, timestamp);

Uint8List _advertisement({
  String name = 'KPTPRO_BLE',
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final nameBytes = utf8.encode(name);
  final ad = <int>[nameBytes.length + 1, 0x09, ...nameBytes];
  final params = <int>[
    0x02, // LE Advertising Report subevent.
    0x01, // One report.
    0x00, // Connectable undirected advertising.
    0x01, // Random address.
    ...address,
    ad.length,
    ...ad,
    0xC9, // -55 dBm.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

Uint8List _connectionComplete({
  int handle = 11,
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final params = <int>[
    0x01, // LE Connection Complete subevent.
    0x00, // Success.
    handle & 0xFF,
    (handle >> 8) & 0xFF,
    0x00, // Central role.
    0x01, // Random peer address.
    ...address,
    0x18, 0x00, // Connection interval.
    0x00, 0x00, // Peripheral latency.
    0xC8, 0x00, // Supervision timeout.
    0x00, // Clock accuracy.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

List<int> _uuid128Bytes(String uuid) {
  final hex = uuid.replaceAll('-', '').toLowerCase();
  return List<int>.generate(
    16,
    (index) => int.parse(
      hex.substring((15 - index) * 2, (15 - index) * 2 + 2),
      radix: 16,
    ),
  );
}

Uint8List _aclPacket(List<int> attPdu, {int connectionHandle = 11}) {
  final l2cap = <int>[attPdu.length, 0x00, 0x04, 0x00, ...attPdu];
  return _aclPacketRaw(
    l2cap,
    packetBoundary: 2,
    connectionHandle: connectionHandle,
  );
}

Uint8List _aclPacketRaw(
  List<int> payload, {
  required int packetBoundary,
  int connectionHandle = 11,
}) {
  final flags = (connectionHandle & 0x0FFF) | (packetBoundary << 12);
  return Uint8List.fromList([
    0x02,
    flags & 0xFF,
    (flags >> 8) & 0xFF,
    payload.length & 0xFF,
    (payload.length >> 8) & 0xFF,
    ...payload,
  ]);
}

Uint8List _aclContinuation(List<int> payload) =>
    _aclPacketRaw(payload, packetBoundary: 1);
)));
      expect(event.characteristicProperties, 0x1C);
    });

    test('keeps ATT payloads from other Bluetooth devices out of the selected session', () {
      final otherAddress = <int>[0x10, 0x20, 0x30, 0x40, 0x50, 0x60];
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(
          _advertisement(name: 'HEADPHONES', address: otherAddress),
          flags: 1,
          timestamp: 1200,
        ),
        _record(
          _connectionComplete(handle: 12, address: otherAddress),
          flags: 1,
          timestamp: 1300,
        ),
        _record(
          _aclPacket([0x52, 0x25, 0x00, 0xAA], connectionHandle: 11),
          flags: 0,
          timestamp: 1400,
        ),
        _record(
          _aclPacket([0x52, 0x26, 0x00, 0xDE, 0xAD], connectionHandle: 12),
          flags: 0,
          timestamp: 1500,
        ),
      ]));

      expect(capture.connectionSessions, hasLength(2));
      final kptSession = capture.connectionSessions.firstWhere(
        (session) => session.looksLikeKptPro,
      );
      final otherSession = capture.connectionSessions.firstWhere(
        (session) => !session.looksLikeKptPro,
      );
      expect(capture.eventsForSession(kptSession.id), hasLength(1));
      expect(capture.eventsForSession(otherSession.id), hasLength(1));

      final filtered = jsonEncode(capture.toJson(
        sessionId: kptSession.id,
        includePayload: true,
      ));
      expect(filtered, contains('AA'));
      expect(filtered, isNot(contains('DE AD')));
      expect(filtered, isNot(contains('HEADPHONES')));
    });

    test('exports only the selected connection and redacts peer address', () {
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([0x52, 0x25, 0x00, 0xDE, 0xAD]), flags: 0, timestamp: 1200),
      ]));

      final session = capture.connectionSessions.single;
      final withoutPayload = capture.toJson(
        sessionId: session.id,
        includePayload: false,
      );
      final encodedWithoutPayload = jsonEncode(withoutPayload);
      expect(encodedWithoutPayload, contains('peerAddressRedacted'));
      expect(encodedWithoutPayload, contains('otherBluetoothConnectionsExcluded'));
      expect(encodedWithoutPayload, isNot(contains('DE AD')));
      expect(encodedWithoutPayload, contains('**:**:**:**:E5:F6'));

      final withPayload = capture.toJson(
        sessionId: session.id,
        includePayload: true,
      );
      expect(jsonEncode(withPayload), contains('DE AD'));
      expect(
        () => capture.toJson(sessionId: 99, includePayload: false),
        throwsArgumentError,
      );
    });

    test('accepts an empty valid capture', () {
      final capture = BtsnoopCaptureParser.parse(_capture(const []));
      expect(capture.packetCount, 0);
      expect(capture.connectionSessions, isEmpty);
      expect(capture.attEvents, isEmpty);
    });

    test('rejects invalid magic, unsupported data-link type and truncated records', () {
      expect(
        () => BtsnoopCaptureParser.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );

      final wrongType = _capture(const [], dataLinkType: 1003);
      expect(() => BtsnoopCaptureParser.parse(wrongType), throwsFormatException);

      final truncated = Uint8List.fromList([
        ..._capture(const []),
        0x00,
        0x01,
      ]);
      expect(() => BtsnoopCaptureParser.parse(truncated), throwsFormatException);
    });

    test('tracks a fragmented L2CAP ATT packet across ACL records', () {
      final pdu = <int>[0x52, 0x25, 0x00, 0x01, 0x02, 0x03, 0x04];
      final l2cap = <int>[pdu.length, 0x00, 0x04, 0x00, ...pdu];
      final first = _aclPacketRaw(
        l2cap.sublist(0, 7),
        packetBoundary: 2,
      );
      final continuation = _aclContinuation(l2cap.sublist(7));
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(first, flags: 0, timestamp: 1200),
        _record(continuation, flags: 0, timestamp: 1300),
      ]));

      expect(capture.attEvents, hasLength(1));
      expect(capture.attEvents.single.valueHex, '01 02 03 04');
    });
  });
}

Uint8List _capture(
  List<_BtsnoopRecord> records, {
  int dataLinkType = 1002,
}) {
  final length = 16 + records.fold<int>(
    0,
    (sum, record) => sum + 24 + record.packet.length,
  );
  final bytes = Uint8List(length);
  const magic = [0x62, 0x74, 0x73, 0x6E, 0x6F, 0x6F, 0x70, 0x00];
  bytes.setRange(0, 8, magic);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 1, Endian.big);
  data.setUint32(12, dataLinkType, Endian.big);
  var offset = 16;
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final packet = record.packet;
    data.setUint32(offset, packet.length, Endian.big);
    data.setUint32(offset + 4, packet.length, Endian.big);
    data.setUint32(offset + 8, record.flags, Endian.big);
    data.setUint32(offset + 12, 0, Endian.big);
    data.setUint64(offset + 16, record.timestamp, Endian.big);
    offset += 24;
    bytes.setRange(offset, offset + packet.length, packet);
    offset += packet.length;
  }
  return bytes;
}

class _BtsnoopRecord {
  const _BtsnoopRecord(this.packet, this.flags, this.timestamp);
  final Uint8List packet;
  final int flags;
  final int timestamp;
}

_BtsnoopRecord _record(
  List<int> packet, {
  required int flags,
  required int timestamp,
}) => _BtsnoopRecord(Uint8List.fromList(packet), flags, timestamp);

Uint8List _advertisement({
  String name = 'KPTPRO_BLE',
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final nameBytes = utf8.encode(name);
  final ad = <int>[nameBytes.length + 1, 0x09, ...nameBytes];
  final params = <int>[
    0x02, // LE Advertising Report subevent.
    0x01, // One report.
    0x00, // Connectable undirected advertising.
    0x01, // Random address.
    ...address,
    ad.length,
    ...ad,
    0xC9, // -55 dBm.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

Uint8List _connectionComplete({
  int handle = 11,
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final params = <int>[
    0x01, // LE Connection Complete subevent.
    0x00, // Success.
    handle & 0xFF,
    (handle >> 8) & 0xFF,
    0x00, // Central role.
    0x01, // Random peer address.
    ...address,
    0x18, 0x00, // Connection interval.
    0x00, 0x00, // Peripheral latency.
    0xC8, 0x00, // Supervision timeout.
    0x00, // Clock accuracy.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

List<int> _uuid128Bytes(String uuid) {
  final hex = uuid.replaceAll('-', '').toLowerCase();
  return List<int>.generate(
    16,
    (index) => int.parse(
      hex.substring((15 - index) * 2, (15 - index) * 2 + 2),
      radix: 16,
    ),
  );
}

Uint8List _aclPacket(List<int> attPdu, {int connectionHandle = 11}) {
  final l2cap = <int>[attPdu.length, 0x00, 0x04, 0x00, ...attPdu];
  return _aclPacketRaw(
    l2cap,
    packetBoundary: 2,
    connectionHandle: connectionHandle,
  );
}

Uint8List _aclPacketRaw(
  List<int> payload, {
  required int packetBoundary,
  int connectionHandle = 11,
}) {
  final flags = (connectionHandle & 0x0FFF) | (packetBoundary << 12);
  return Uint8List.fromList([
    0x02,
    flags & 0xFF,
    (flags >> 8) & 0xFF,
    payload.length & 0xFF,
    (payload.length >> 8) & 0xFF,
    ...payload,
  ]);
}

Uint8List _aclContinuation(List<int> payload) =>
    _aclPacketRaw(payload, packetBoundary: 1);
)));
      expect(event.serviceUuid, matches(RegExp(r'^[0-9a-f-]{36}
      expect(event.characteristicProperties, 0x1C);
    });

    test('keeps ATT payloads from other Bluetooth devices out of the selected session', () {
      final otherAddress = <int>[0x10, 0x20, 0x30, 0x40, 0x50, 0x60];
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(
          _advertisement(name: 'HEADPHONES', address: otherAddress),
          flags: 1,
          timestamp: 1200,
        ),
        _record(
          _connectionComplete(handle: 12, address: otherAddress),
          flags: 1,
          timestamp: 1300,
        ),
        _record(
          _aclPacket([0x52, 0x25, 0x00, 0xAA], connectionHandle: 11),
          flags: 0,
          timestamp: 1400,
        ),
        _record(
          _aclPacket([0x52, 0x26, 0x00, 0xDE, 0xAD], connectionHandle: 12),
          flags: 0,
          timestamp: 1500,
        ),
      ]));

      expect(capture.connectionSessions, hasLength(2));
      final kptSession = capture.connectionSessions.firstWhere(
        (session) => session.looksLikeKptPro,
      );
      final otherSession = capture.connectionSessions.firstWhere(
        (session) => !session.looksLikeKptPro,
      );
      expect(capture.eventsForSession(kptSession.id), hasLength(1));
      expect(capture.eventsForSession(otherSession.id), hasLength(1));

      final filtered = jsonEncode(capture.toJson(
        sessionId: kptSession.id,
        includePayload: true,
      ));
      expect(filtered, contains('AA'));
      expect(filtered, isNot(contains('DE AD')));
      expect(filtered, isNot(contains('HEADPHONES')));
    });

    test('exports only the selected connection and redacts peer address', () {
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([0x52, 0x25, 0x00, 0xDE, 0xAD]), flags: 0, timestamp: 1200),
      ]));

      final session = capture.connectionSessions.single;
      final withoutPayload = capture.toJson(
        sessionId: session.id,
        includePayload: false,
      );
      final encodedWithoutPayload = jsonEncode(withoutPayload);
      expect(encodedWithoutPayload, contains('peerAddressRedacted'));
      expect(encodedWithoutPayload, contains('otherBluetoothConnectionsExcluded'));
      expect(encodedWithoutPayload, isNot(contains('DE AD')));
      expect(encodedWithoutPayload, contains('**:**:**:**:E5:F6'));

      final withPayload = capture.toJson(
        sessionId: session.id,
        includePayload: true,
      );
      expect(jsonEncode(withPayload), contains('DE AD'));
      expect(
        () => capture.toJson(sessionId: 99, includePayload: false),
        throwsArgumentError,
      );
    });

    test('accepts an empty valid capture', () {
      final capture = BtsnoopCaptureParser.parse(_capture(const []));
      expect(capture.packetCount, 0);
      expect(capture.connectionSessions, isEmpty);
      expect(capture.attEvents, isEmpty);
    });

    test('rejects invalid magic, unsupported data-link type and truncated records', () {
      expect(
        () => BtsnoopCaptureParser.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );

      final wrongType = _capture(const [], dataLinkType: 1003);
      expect(() => BtsnoopCaptureParser.parse(wrongType), throwsFormatException);

      final truncated = Uint8List.fromList([
        ..._capture(const []),
        0x00,
        0x01,
      ]);
      expect(() => BtsnoopCaptureParser.parse(truncated), throwsFormatException);
    });

    test('tracks a fragmented L2CAP ATT packet across ACL records', () {
      final pdu = <int>[0x52, 0x25, 0x00, 0x01, 0x02, 0x03, 0x04];
      final l2cap = <int>[pdu.length, 0x00, 0x04, 0x00, ...pdu];
      final first = _aclPacketRaw(
        l2cap.sublist(0, 7),
        packetBoundary: 2,
      );
      final continuation = _aclContinuation(l2cap.sublist(7));
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(first, flags: 0, timestamp: 1200),
        _record(continuation, flags: 0, timestamp: 1300),
      ]));

      expect(capture.attEvents, hasLength(1));
      expect(capture.attEvents.single.valueHex, '01 02 03 04');
    });
  });
}

Uint8List _capture(
  List<_BtsnoopRecord> records, {
  int dataLinkType = 1002,
}) {
  final length = 16 + records.fold<int>(
    0,
    (sum, record) => sum + 24 + record.packet.length,
  );
  final bytes = Uint8List(length);
  const magic = [0x62, 0x74, 0x73, 0x6E, 0x6F, 0x6F, 0x70, 0x00];
  bytes.setRange(0, 8, magic);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 1, Endian.big);
  data.setUint32(12, dataLinkType, Endian.big);
  var offset = 16;
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final packet = record.packet;
    data.setUint32(offset, packet.length, Endian.big);
    data.setUint32(offset + 4, packet.length, Endian.big);
    data.setUint32(offset + 8, record.flags, Endian.big);
    data.setUint32(offset + 12, 0, Endian.big);
    data.setUint64(offset + 16, record.timestamp, Endian.big);
    offset += 24;
    bytes.setRange(offset, offset + packet.length, packet);
    offset += packet.length;
  }
  return bytes;
}

class _BtsnoopRecord {
  const _BtsnoopRecord(this.packet, this.flags, this.timestamp);
  final Uint8List packet;
  final int flags;
  final int timestamp;
}

_BtsnoopRecord _record(
  List<int> packet, {
  required int flags,
  required int timestamp,
}) => _BtsnoopRecord(Uint8List.fromList(packet), flags, timestamp);

Uint8List _advertisement({
  String name = 'KPTPRO_BLE',
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final nameBytes = utf8.encode(name);
  final ad = <int>[nameBytes.length + 1, 0x09, ...nameBytes];
  final params = <int>[
    0x02, // LE Advertising Report subevent.
    0x01, // One report.
    0x00, // Connectable undirected advertising.
    0x01, // Random address.
    ...address,
    ad.length,
    ...ad,
    0xC9, // -55 dBm.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

Uint8List _connectionComplete({
  int handle = 11,
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final params = <int>[
    0x01, // LE Connection Complete subevent.
    0x00, // Success.
    handle & 0xFF,
    (handle >> 8) & 0xFF,
    0x00, // Central role.
    0x01, // Random peer address.
    ...address,
    0x18, 0x00, // Connection interval.
    0x00, 0x00, // Peripheral latency.
    0xC8, 0x00, // Supervision timeout.
    0x00, // Clock accuracy.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

List<int> _uuid128Bytes(String uuid) {
  final hex = uuid.replaceAll('-', '').toLowerCase();
  return List<int>.generate(
    16,
    (index) => int.parse(
      hex.substring((15 - index) * 2, (15 - index) * 2 + 2),
      radix: 16,
    ),
  );
}

Uint8List _aclPacket(List<int> attPdu, {int connectionHandle = 11}) {
  final l2cap = <int>[attPdu.length, 0x00, 0x04, 0x00, ...attPdu];
  return _aclPacketRaw(
    l2cap,
    packetBoundary: 2,
    connectionHandle: connectionHandle,
  );
}

Uint8List _aclPacketRaw(
  List<int> payload, {
  required int packetBoundary,
  int connectionHandle = 11,
}) {
  final flags = (connectionHandle & 0x0FFF) | (packetBoundary << 12);
  return Uint8List.fromList([
    0x02,
    flags & 0xFF,
    (flags >> 8) & 0xFF,
    payload.length & 0xFF,
    (payload.length >> 8) & 0xFF,
    ...payload,
  ]);
}

Uint8List _aclContinuation(List<int> payload) =>
    _aclPacketRaw(payload, packetBoundary: 1);
)));
      expect(event.characteristicProperties, 0x1C);
    });

    test('keeps ATT payloads from other Bluetooth devices out of the selected session', () {
      final otherAddress = <int>[0x10, 0x20, 0x30, 0x40, 0x50, 0x60];
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(
          _advertisement(name: 'HEADPHONES', address: otherAddress),
          flags: 1,
          timestamp: 1200,
        ),
        _record(
          _connectionComplete(handle: 12, address: otherAddress),
          flags: 1,
          timestamp: 1300,
        ),
        _record(
          _aclPacket([0x52, 0x25, 0x00, 0xAA], connectionHandle: 11),
          flags: 0,
          timestamp: 1400,
        ),
        _record(
          _aclPacket([0x52, 0x26, 0x00, 0xDE, 0xAD], connectionHandle: 12),
          flags: 0,
          timestamp: 1500,
        ),
      ]));

      expect(capture.connectionSessions, hasLength(2));
      final kptSession = capture.connectionSessions.firstWhere(
        (session) => session.looksLikeKptPro,
      );
      final otherSession = capture.connectionSessions.firstWhere(
        (session) => !session.looksLikeKptPro,
      );
      expect(capture.eventsForSession(kptSession.id), hasLength(1));
      expect(capture.eventsForSession(otherSession.id), hasLength(1));

      final filtered = jsonEncode(capture.toJson(
        sessionId: kptSession.id,
        includePayload: true,
      ));
      expect(filtered, contains('AA'));
      expect(filtered, isNot(contains('DE AD')));
      expect(filtered, isNot(contains('HEADPHONES')));
    });

    test('exports only the selected connection and redacts peer address', () {
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(_aclPacket([0x52, 0x25, 0x00, 0xDE, 0xAD]), flags: 0, timestamp: 1200),
      ]));

      final session = capture.connectionSessions.single;
      final withoutPayload = capture.toJson(
        sessionId: session.id,
        includePayload: false,
      );
      final encodedWithoutPayload = jsonEncode(withoutPayload);
      expect(encodedWithoutPayload, contains('peerAddressRedacted'));
      expect(encodedWithoutPayload, contains('otherBluetoothConnectionsExcluded'));
      expect(encodedWithoutPayload, isNot(contains('DE AD')));
      expect(encodedWithoutPayload, contains('**:**:**:**:E5:F6'));

      final withPayload = capture.toJson(
        sessionId: session.id,
        includePayload: true,
      );
      expect(jsonEncode(withPayload), contains('DE AD'));
      expect(
        () => capture.toJson(sessionId: 99, includePayload: false),
        throwsArgumentError,
      );
    });

    test('accepts an empty valid capture', () {
      final capture = BtsnoopCaptureParser.parse(_capture(const []));
      expect(capture.packetCount, 0);
      expect(capture.connectionSessions, isEmpty);
      expect(capture.attEvents, isEmpty);
    });

    test('rejects invalid magic, unsupported data-link type and truncated records', () {
      expect(
        () => BtsnoopCaptureParser.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );

      final wrongType = _capture(const [], dataLinkType: 1003);
      expect(() => BtsnoopCaptureParser.parse(wrongType), throwsFormatException);

      final truncated = Uint8List.fromList([
        ..._capture(const []),
        0x00,
        0x01,
      ]);
      expect(() => BtsnoopCaptureParser.parse(truncated), throwsFormatException);
    });

    test('tracks a fragmented L2CAP ATT packet across ACL records', () {
      final pdu = <int>[0x52, 0x25, 0x00, 0x01, 0x02, 0x03, 0x04];
      final l2cap = <int>[pdu.length, 0x00, 0x04, 0x00, ...pdu];
      final first = _aclPacketRaw(
        l2cap.sublist(0, 7),
        packetBoundary: 2,
      );
      final continuation = _aclContinuation(l2cap.sublist(7));
      final capture = BtsnoopCaptureParser.parse(_capture([
        _record(_advertisement(), flags: 1, timestamp: 1000),
        _record(_connectionComplete(), flags: 1, timestamp: 1100),
        _record(first, flags: 0, timestamp: 1200),
        _record(continuation, flags: 0, timestamp: 1300),
      ]));

      expect(capture.attEvents, hasLength(1));
      expect(capture.attEvents.single.valueHex, '01 02 03 04');
    });
  });
}

Uint8List _capture(
  List<_BtsnoopRecord> records, {
  int dataLinkType = 1002,
}) {
  final length = 16 + records.fold<int>(
    0,
    (sum, record) => sum + 24 + record.packet.length,
  );
  final bytes = Uint8List(length);
  const magic = [0x62, 0x74, 0x73, 0x6E, 0x6F, 0x6F, 0x70, 0x00];
  bytes.setRange(0, 8, magic);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 1, Endian.big);
  data.setUint32(12, dataLinkType, Endian.big);
  var offset = 16;
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final packet = record.packet;
    data.setUint32(offset, packet.length, Endian.big);
    data.setUint32(offset + 4, packet.length, Endian.big);
    data.setUint32(offset + 8, record.flags, Endian.big);
    data.setUint32(offset + 12, 0, Endian.big);
    data.setUint64(offset + 16, record.timestamp, Endian.big);
    offset += 24;
    bytes.setRange(offset, offset + packet.length, packet);
    offset += packet.length;
  }
  return bytes;
}

class _BtsnoopRecord {
  const _BtsnoopRecord(this.packet, this.flags, this.timestamp);
  final Uint8List packet;
  final int flags;
  final int timestamp;
}

_BtsnoopRecord _record(
  List<int> packet, {
  required int flags,
  required int timestamp,
}) => _BtsnoopRecord(Uint8List.fromList(packet), flags, timestamp);

Uint8List _advertisement({
  String name = 'KPTPRO_BLE',
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final nameBytes = utf8.encode(name);
  final ad = <int>[nameBytes.length + 1, 0x09, ...nameBytes];
  final params = <int>[
    0x02, // LE Advertising Report subevent.
    0x01, // One report.
    0x00, // Connectable undirected advertising.
    0x01, // Random address.
    ...address,
    ad.length,
    ...ad,
    0xC9, // -55 dBm.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

Uint8List _connectionComplete({
  int handle = 11,
  List<int> address = const [0xF6, 0xE5, 0xD4, 0xC3, 0xB2, 0xA1],
}) {
  final params = <int>[
    0x01, // LE Connection Complete subevent.
    0x00, // Success.
    handle & 0xFF,
    (handle >> 8) & 0xFF,
    0x00, // Central role.
    0x01, // Random peer address.
    ...address,
    0x18, 0x00, // Connection interval.
    0x00, 0x00, // Peripheral latency.
    0xC8, 0x00, // Supervision timeout.
    0x00, // Clock accuracy.
  ];
  return Uint8List.fromList([0x04, 0x3E, params.length, ...params]);
}

List<int> _uuid128Bytes(String uuid) {
  final hex = uuid.replaceAll('-', '').toLowerCase();
  return List<int>.generate(
    16,
    (index) => int.parse(
      hex.substring((15 - index) * 2, (15 - index) * 2 + 2),
      radix: 16,
    ),
  );
}

Uint8List _aclPacket(List<int> attPdu, {int connectionHandle = 11}) {
  final l2cap = <int>[attPdu.length, 0x00, 0x04, 0x00, ...attPdu];
  return _aclPacketRaw(
    l2cap,
    packetBoundary: 2,
    connectionHandle: connectionHandle,
  );
}

Uint8List _aclPacketRaw(
  List<int> payload, {
  required int packetBoundary,
  int connectionHandle = 11,
}) {
  final flags = (connectionHandle & 0x0FFF) | (packetBoundary << 12);
  return Uint8List.fromList([
    0x02,
    flags & 0xFF,
    (flags >> 8) & 0xFF,
    payload.length & 0xFF,
    (payload.length >> 8) & 0xFF,
    ...payload,
  ]);
}

Uint8List _aclContinuation(List<int> payload) =>
    _aclPacketRaw(payload, packetBoundary: 1);
