import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Parses Android BTSnoop HCI UART (H4) logs without replaying or transmitting
/// any captured packet. Correlates ATT attribute handles with the GATT service
/// and characteristic declarations observed on each individual connection.
class BtsnoopCaptureParser {
  BtsnoopCaptureParser._();

  static const List<int> _magic = <int>[
    0x62, 0x74, 0x73, 0x6E, 0x6F, 0x6F, 0x70, 0x00,
  ];
  static const int _headerLength = 16;
  static const int _recordHeaderLength = 24;
  static const int _androidHciUartH4 = 1002;
  static const int _maxRecords = 250000;
  static const int _maxPacketLength = 16 * 1024 * 1024;

  static KptProHciCapture parse(Uint8List bytes) {
    if (bytes.length < _headerLength) {
      throw const FormatException('The file is too short to be a BTSnoop capture.');
    }
    for (var index = 0; index < _magic.length; index++) {
      if (bytes[index] != _magic[index]) {
        throw const FormatException('BTSnoop header not found. Select the extracted btsnoop_hci.log file, not the bug-report ZIP.');
      }
    }

    final header = ByteData.sublistView(bytes, 8, 16);
    final version = header.getUint32(0, Endian.big);
    final dataLinkType = header.getUint32(4, Endian.big);
    if (version != 1) {
      throw FormatException('Unsupported BTSnoop version $version. Expected version 1.');
    }
    if (dataLinkType != _androidHciUartH4) {
      throw FormatException(
        'Unsupported BTSnoop data-link type $dataLinkType. This importer currently accepts Android HCI UART (H4), type 1002.',
      );
    }

    final parser = _BtsnoopParserState(version, dataLinkType);
    var offset = _headerLength;
    var recordNumber = 0;
    int? firstTimestamp;
    while (offset < bytes.length) {
      if (recordNumber >= _maxRecords) {
        throw const FormatException('Capture exceeds the 250,000-record safety limit.');
      }
      if (bytes.length - offset < _recordHeaderLength) {
        throw const FormatException('BTSnoop record header is truncated.');
      }
      final record = ByteData.sublistView(bytes, offset, offset + _recordHeaderLength);
      final originalLength = record.getUint32(0, Endian.big);
      final includedLength = record.getUint32(4, Endian.big);
      final flags = record.getUint32(8, Endian.big);
      final timestamp = record.getUint64(16, Endian.big);

      if (includedLength > originalLength || includedLength > _maxPacketLength) {
        throw FormatException('Invalid packet length in BTSnoop record ${recordNumber + 1}.');
      }
      offset += _recordHeaderLength;
      if (includedLength > bytes.length - offset) {
        throw FormatException('BTSnoop packet ${recordNumber + 1} is truncated.');
      }

      firstTimestamp ??= timestamp;
      final packet = Uint8List.sublistView(bytes, offset, offset + includedLength);
      parser.consume(
        packet,
        frameNumber: recordNumber,
        relativeTimestampMicros: timestamp - firstTimestamp,
        direction: (flags & 1) == 1
            ? BtsnoopDirection.controllerToHost
            : BtsnoopDirection.hostToController,
      );
      offset += includedLength;
      recordNumber++;
    }

    return parser.finish(recordCount: recordNumber);
  }
}

enum BtsnoopDirection { hostToController, controllerToHost }

extension BtsnoopDirectionLabel on BtsnoopDirection {
  String get label => switch (this) {
    BtsnoopDirection.hostToController => 'Phone → pedal',
    BtsnoopDirection.controllerToHost => 'Pedal → phone',
  };
}

@immutable
class KptBlePeripheralObservation {
  const KptBlePeripheralObservation({
    required this.address,
    required this.addressType,
    this.name,
    this.lastRssi,
  });

  final String address;
  final int addressType;
  final String? name;
  final int? lastRssi;

  bool get looksLikeKptPro =>
      (name ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').contains('kptpro');

  String get maskedAddress {
    final parts = address.split(':');
    if (parts.length != 6) return 'redacted';
    return '**:**:**:**:${parts[4]}:${parts[5]}';
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'address': maskedAddress,
    'addressType': addressType,
    'lastRssiDbm': lastRssi,
  };
}

@immutable
class KptBleConnectionSession {
  const KptBleConnectionSession({
    required this.id,
    required this.connectionHandle,
    required this.peerAddress,
    required this.peerAddressType,
    required this.deviceName,
    required this.startFrame,
    required this.startTimestampMicros,
    this.endFrame,
    this.endTimestampMicros,
    this.disconnectStatus,
    this.disconnectReason,
    required this.attEventCount,
  });

  final int id;
  final int connectionHandle;
  final String peerAddress;
  final int peerAddressType;
  final String? deviceName;
  final int startFrame;
  final int startTimestampMicros;
  final int? endFrame;
  final int? endTimestampMicros;
  final int? disconnectStatus;
  final int? disconnectReason;
  final int attEventCount;

  bool get looksLikeKptPro =>
      (deviceName ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').contains('kptpro');

  String get maskedAddress {
    final parts = peerAddress.split(':');
    if (parts.length != 6) return 'redacted';
    return '**:**:**:**:${parts[4]}:${parts[5]}';
  }

  Map<String, Object?> toJson() => {
    'connectionHandle': '0x${connectionHandle.toRadixString(16).padLeft(4, '0')}',
    'deviceName': deviceName,
    'peerAddress': maskedAddress,
    'startFrame': startFrame,
    'startTimeFromCaptureStartMicros': startTimestampMicros,
    'endFrame': endFrame,
    'endTimeFromCaptureStartMicros': endTimestampMicros,
    'disconnectStatus': disconnectStatus,
    'disconnectReason': disconnectReason == null
        ? null
        : '0x${disconnectReason!.toRadixString(16).padLeft(2, '0')}',
    'disconnectReasonName': disconnectReason == null
        ? null
        : _hciDisconnectReasonName(disconnectReason!),
    'attEventCount': attEventCount,
    'identifiedAsKptProByAdvertisementName': looksLikeKptPro,
  };
}

@immutable
class KptBleAttEvent {
  const KptBleAttEvent({
    required this.frameNumber,
    required this.relativeTimestampMicros,
    required this.sessionId,
    required this.connectionHandle,
    required this.direction,
    required this.opcode,
    required this.opcodeName,
    this.attributeHandle,
    this.attributeUuid,
    this.serviceUuid,
    this.characteristicProperties,
    this.protocolDetails,
    this.value = const <int>[],
    required this.pdu,
  });

  final int frameNumber;
  final int relativeTimestampMicros;
  final int? sessionId;
  final int connectionHandle;
  final BtsnoopDirection direction;
  final int opcode;
  final String opcodeName;
  final int? attributeHandle;
  final String? attributeUuid;
  final String? serviceUuid;
  final int? characteristicProperties;
  final Map<String, Object?>? protocolDetails;
  final List<int> value;
  final List<int> pdu;

  bool get isWrite => opcode == 0x12 || opcode == 0x52 || opcode == 0x16 || opcode == 0x18;
  bool get isNotification => opcode == 0x1B || opcode == 0x1D;

  String get valueHex => value.map(_hexByte).join(' ');
  String get pduHex => pdu.map(_hexByte).join(' ');

  Map<String, Object?> toJson({required bool includePayload}) => {
    'frame': frameNumber,
    'timeFromCaptureStartMicros': relativeTimestampMicros,
    'connectionHandle': '0x${connectionHandle.toRadixString(16).padLeft(4, '0')}',
    'direction': direction.label,
    'attOpcode': '0x${opcode.toRadixString(16).padLeft(2, '0')}',
    'operation': opcodeName,
    'attributeHandle': attributeHandle == null
        ? null
        : '0x${attributeHandle!.toRadixString(16).padLeft(4, '0')}',
    'serviceUuid': serviceUuid,
    'characteristicUuid': attributeUuid,
    'characteristicProperties': characteristicProperties,
    if (protocolDetails != null) 'protocolDetails': protocolDetails,
    if (includePayload) 'valueHex': valueHex,
    if (includePayload) 'attPduHex': pduHex,
  };
}

@immutable
class KptProHciCapture {
  const KptProHciCapture({
    required this.version,
    required this.dataLinkType,
    required this.packetCount,
    required this.connectionSessions,
    required this.peripherals,
    required this.attEvents,
    required this.characteristicDiscoveryBySession,
    required this.descriptorDiscoveryBySession,
    required this.malformedHciPacketCount,
    required this.nonAttAclPacketCount,
  });

  final int version;
  final int dataLinkType;
  final int packetCount;
  final List<KptBleConnectionSession> connectionSessions;
  final List<KptBlePeripheralObservation> peripherals;
  final List<KptBleAttEvent> attEvents;
  final Map<int, Map<String, Object?>> characteristicDiscoveryBySession;
  final Map<int, Map<String, Object?>> descriptorDiscoveryBySession;
  final int malformedHciPacketCount;
  final int nonAttAclPacketCount;

  int get writeCount => attEvents.where((event) => event.isWrite).length;
  int get notificationCount =>
      attEvents.where((event) => event.isNotification).length;
  int get readCount =>
      attEvents.where((event) => event.opcode == 0x0A || event.opcode == 0x0B).length;

  KptBleConnectionSession? sessionById(int id) {
    for (final session in connectionSessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  List<KptBleAttEvent> eventsForSession(int sessionId) =>
      attEvents.where((event) => event.sessionId == sessionId).toList(growable: false);

  int? suggestedKptProSessionId() {
    for (final session in connectionSessions) {
      if (session.looksLikeKptPro) return session.id;
    }
    return null;
  }

  Map<String, Object?> toJson({
    required int sessionId,
    required bool includePayload,
  }) {
    final session = sessionById(sessionId);
    if (session == null) {
      throw ArgumentError.value(sessionId, 'sessionId', 'No such connection session.');
    }
    final events = eventsForSession(sessionId);
    return {
      'reportType': 'RigCanvas filtered Android BTSnoop ATT analysis',
      'btsnoopVersion': version,
      'dataLinkType': dataLinkType,
      'packetCount': packetCount,
      'selectedConnection': session.toJson(),
      'privacy': {
        'peerAddressRedacted': true,
        'otherBluetoothConnectionsExcluded': true,
        'payloadBytesIncluded': includePayload,
        'warning': 'ATT payloads can contain proprietary commands and personal preset data. Share only if you are comfortable disclosing them.',
      },
      'summary': {
        'attEvents': events.length,
        'writeRequestsAndCommands': events.where((event) => event.isWrite).length,
        'notificationsAndIndications': events.where((event) => event.isNotification).length,
        'mtuExchangeRequests': events.where((event) => event.opcode == 0x02).length,
        'mtuExchangeResponses': events.where((event) => event.opcode == 0x03).length,
        'attributeValueReadRequestsAndResponses': events.where(
          (event) => const [0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F].contains(event.opcode),
        ).length,
        'gattDiscoveryRequestsAndResponses': events.where(
          (event) => const [0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x10, 0x11].contains(event.opcode),
        ).length,
        'attErrorResponses': events.where((event) => event.opcode == 0x01).length,
        'findInformationRequestsAndResponses': events.where(
          (event) => event.opcode == 0x04 || event.opcode == 0x05,
        ).length,
        'descriptorDiscoveryEntries':
            _descriptorMapForSession(sessionId).length,
        // Retained for compatibility with earlier report readers; this counts
        // only simple Read Request/Read Response pairs, not GATT discovery.
        'readRequestsAndResponses': events.where(
          (event) => event.opcode == 0x0A || event.opcode == 0x0B,
        ).length,
      },
      'protocolWarnings': [
        if (events.where((event) => event.opcode == 0x02).length > 1)
          'Multiple ATT Exchange MTU Requests were captured for one selected connection. Verify the HCI connection lifecycle and raw event sequence before interpreting MTU negotiation.',
      ],
      'characteristicDiscovery': _characteristicMapForSession(sessionId),
      'descriptorDiscovery': _descriptorMapForSession(sessionId),
      'attEvents': events.map(
        (event) => event.toJson(includePayload: includePayload),
      ).toList(growable: false),
      'safety': {
        'capturedTrafficReplayed': false,
        'deviceCommandsSentByRigCanvas': false,
        'firmwareOperationsPerformed': false,
      },
    };
  }

  Map<String, Object?> _characteristicMapForSession(int sessionId) =>
      characteristicDiscoveryBySession[sessionId] ?? const {};

  Map<String, Object?> _descriptorMapForSession(int sessionId) =>
      descriptorDiscoveryBySession[sessionId] ?? const {};
}

class _BtsnoopParserState {
  _BtsnoopParserState(this.version, this.dataLinkType);

  final int version;
  final int dataLinkType;
  final Map<String, KptBlePeripheralObservation> _peripherals = {};
  final Map<int, _MutableSession> _activeSessions = {};
  final List<_MutableSession> _sessions = [];
  final List<KptBleAttEvent> _attEvents = [];
  final Map<String, _PendingL2cap> _pendingL2cap = {};
  final Map<int, _ConnectionAttributeTable> _attributeTables = {};
  final Map<int, _ConnectionAttributeTable> _sessionAttributeTables = {};
  int malformedHciPacketCount = 0;
  int nonAttAclPacketCount = 0;

  void consume(
    Uint8List packet, {
    required int frameNumber,
    required int relativeTimestampMicros,
    required BtsnoopDirection direction,
  }) {
    if (packet.isEmpty) {
      malformedHciPacketCount++;
      return;
    }
    switch (packet[0]) {
      case 0x02:
        _consumeAcl(packet, frameNumber, relativeTimestampMicros, direction);
        break;
      case 0x04:
        _consumeEvent(packet, frameNumber, relativeTimestampMicros);
        break;
      default:
        // HCI commands and unrelated packet types are intentionally not
        // exported. We only need LE connection metadata and ATT data.
        break;
    }
  }

  void _consumeEvent(
    Uint8List packet,
    int frameNumber,
    int relativeTimestampMicros,
  ) {
    if (packet.length < 3 || packet[2] != packet.length - 3) {
      malformedHciPacketCount++;
      return;
    }
    final eventCode = packet[1];
    if (eventCode == 0x05) {
      if (packet.length < 7) {
        malformedHciPacketCount++;
        return;
      }
      final status = packet[3];
      if (status != 0) return;
      final handle = _u16le(packet, 4) & 0x0FFF;
      final reason = packet[6];
      final session = _activeSessions.remove(handle);
      if (session != null) {
        session.endFrame = frameNumber;
        session.endTimestampMicros = relativeTimestampMicros;
        session.disconnectStatus = status;
        session.disconnectReason = reason;
      }
      _attributeTables.remove(handle);
      _clearPendingL2capForHandle(handle);
      return;
    }
    if (eventCode != 0x3E || packet.length < 5) return;

    final subevent = packet[3];
    if (subevent == 0x02) {
      _consumeAdvertisingReports(packet);
    } else if (subevent == 0x01 || subevent == 0x0A) {
      _consumeConnectionComplete(packet, frameNumber, relativeTimestampMicros);
    }
  }

  void _consumeAdvertisingReports(Uint8List packet) {
    if (packet.length < 5) {
      malformedHciPacketCount++;
      return;
    }
    final count = packet[4];
    var offset = 5;
    for (var index = 0; index < count; index++) {
      if (packet.length - offset < 9) {
        malformedHciPacketCount++;
        return;
      }
      final addressType = packet[offset + 1];
      final address = _addressFromLittleEndian(packet, offset + 2);
      final dataLength = packet[offset + 8];
      final dataStart = offset + 9;
      final rssiOffset = dataStart + dataLength;
      if (rssiOffset >= packet.length) {
        malformedHciPacketCount++;
        return;
      }
      final name = _advertisedName(packet, dataStart, dataLength);
      final rssi = packet[rssiOffset] > 127 ? packet[rssiOffset] - 256 : packet[rssiOffset];
      final previous = _peripherals[address];
      _peripherals[address] = KptBlePeripheralObservation(
        address: address,
        addressType: addressType,
        name: name ?? previous?.name,
        lastRssi: rssi,
      );
      offset = rssiOffset + 1;
    }
  }

  void _consumeConnectionComplete(
    Uint8List packet,
    int frameNumber,
    int relativeTimestampMicros,
  ) {
    if (packet.length < 15) {
      malformedHciPacketCount++;
      return;
    }
    final status = packet[4];
    if (status != 0) return;
    final handle = _u16le(packet, 5) & 0x0FFF;
    final addressType = packet[8];
    final address = _addressFromLittleEndian(packet, 9);
    final observation = _peripherals[address];
    final oldSession = _activeSessions.remove(handle);
    if (oldSession != null) {
      oldSession.endFrame = frameNumber;
      oldSession.endTimestampMicros = relativeTimestampMicros;
    }
    _clearPendingL2capForHandle(handle);
    final session = _MutableSession(
      id: _sessions.length,
      connectionHandle: handle,
      peerAddress: address,
      peerAddressType: addressType,
      deviceName: observation?.name,
      startFrame: frameNumber,
      startTimestampMicros: relativeTimestampMicros,
    );
    _sessions.add(session);
    final table = _ConnectionAttributeTable();
    _attributeTables[handle] = table;
    _sessionAttributeTables[session.id] = table;
    _activeSessions[handle] = session;
  }

  void _clearPendingL2capForHandle(int handle) {
    final prefix = '$handle:';
    _pendingL2cap.removeWhere((key, _) => key.startsWith(prefix));
  }

  void _consumeAcl(
    Uint8List packet,
    int frameNumber,
    int relativeTimestampMicros,
    BtsnoopDirection direction,
  ) {
    if (packet.length < 5) {
      malformedHciPacketCount++;
      return;
    }
    final handleAndFlags = _u16le(packet, 1);
    final handle = handleAndFlags & 0x0FFF;
    final packetBoundary = (handleAndFlags >> 12) & 0x03;
    final aclLength = _u16le(packet, 3);
    if (aclLength != packet.length - 5) {
      malformedHciPacketCount++;
      return;
    }
    final payload = Uint8List.sublistView(packet, 5);
    final key = '$handle:${direction.index}';
    Uint8List? completeL2cap;

    if (packetBoundary == 1) {
      final pending = _pendingL2cap[key];
      if (pending == null) return;
      pending.bytes.addAll(payload);
      if (pending.bytes.length >= pending.expectedLength) {
        completeL2cap = Uint8List.fromList(
          pending.bytes.take(pending.expectedLength).toList(growable: false),
        );
        _pendingL2cap.remove(key);
      }
    } else {
      if (payload.length < 4) {
        malformedHciPacketCount++;
        return;
      }
      final l2capLength = _u16le(payload, 0);
      if (payload.length < 4 + l2capLength) {
        _pendingL2cap[key] = _PendingL2cap(
          expectedLength: 4 + l2capLength,
          bytes: List<int>.from(payload),
        );
        return;
      }
      completeL2cap = Uint8List.sublistView(payload, 0, 4 + l2capLength);
    }

    if (completeL2cap == null || completeL2cap.length < 5) return;
    final cid = _u16le(completeL2cap, 2);
    if (cid != 0x0004) {
      nonAttAclPacketCount++;
      return;
    }
    final attPdu = Uint8List.sublistView(completeL2cap, 4);
    _consumeAtt(
      attPdu,
      handle: handle,
      frameNumber: frameNumber,
      relativeTimestampMicros: relativeTimestampMicros,
      direction: direction,
    );
  }

  void _consumeAtt(
    Uint8List pdu, {
    required int handle,
    required int frameNumber,
    required int relativeTimestampMicros,
    required BtsnoopDirection direction,
  }) {
    if (pdu.isEmpty) {
      malformedHciPacketCount++;
      return;
    }
    final opcode = pdu[0];
    final table = _attributeTables.putIfAbsent(
      handle,
      _ConnectionAttributeTable.new,
    );
    if (opcode == 0x11) {
      table.readServiceDeclarations(pdu);
    } else if (opcode == 0x09) {
      table.readCharacteristicDeclarations(pdu);
    } else if (opcode == 0x05) {
      table.readFindInformationResponse(pdu);
    }
    final attributeHandle = switch (opcode) {
      0x12 || 0x52 || 0x1B || 0x1D || 0x0A || 0x0C || 0x0E || 0x16 =>
        pdu.length >= 3 ? _u16le(pdu, 1) : null,
      _ => null,
    };
    final value = switch (opcode) {
      0x12 || 0x52 || 0x1B || 0x1D || 0x16 =>
        pdu.length > 3 ? pdu.sublist(3) : const <int>[],
      0x0B => pdu.length > 1 ? pdu.sublist(1) : const <int>[],
      _ => const <int>[],
    };
    final metadata = attributeHandle == null
        ? null
        : table.characteristicsByValueHandle[attributeHandle];
    final session = _activeSessions[handle];
    if (session != null) session.attEventCount++;
    _attEvents.add(KptBleAttEvent(
      frameNumber: frameNumber,
      relativeTimestampMicros: relativeTimestampMicros,
      sessionId: session?.id,
      connectionHandle: handle,
      direction: direction,
      opcode: opcode,
      opcodeName: _attOpcodeName(opcode),
      attributeHandle: attributeHandle,
      attributeUuid: metadata?.uuid,
      serviceUuid: metadata?.serviceUuid(table.services),
      characteristicProperties: metadata?.properties,
      protocolDetails: _attProtocolDetails(pdu),
      value: List<int>.unmodifiable(value),
      pdu: List<int>.unmodifiable(pdu),
    ));
  }

  

  KptProHciCapture finish({required int recordCount}) {
    final sessions = _sessions.map((session) => session.freeze()).toList(growable: false);
    final characteristicDiscoveryBySession = <int, Map<String, Object?>>{
      for (final session in sessions)
        session.id: _sessionAttributeTables[session.id]?.toJson() ?? const {},
    };
    final descriptorDiscoveryBySession = <int, Map<String, Object?>>{
      for (final session in sessions)
        session.id: _sessionAttributeTables[session.id]?.descriptorJson() ?? const {},
    };
    final peripherals = _peripherals.values.toList(growable: false)
      ..sort((a, b) => (a.name ?? a.address).compareTo(b.name ?? b.address));
    return KptProHciCapture(
      version: version,
      dataLinkType: dataLinkType,
      packetCount: recordCount,
      connectionSessions: sessions,
      peripherals: peripherals,
      attEvents: List.unmodifiable(_attEvents),
      characteristicDiscoveryBySession: Map.unmodifiable(
        characteristicDiscoveryBySession,
      ),
      descriptorDiscoveryBySession: Map.unmodifiable(
        descriptorDiscoveryBySession,
      ),
      malformedHciPacketCount: malformedHciPacketCount,
      nonAttAclPacketCount: nonAttAclPacketCount,
    );
  }
}

class _GattServiceRange {
  const _GattServiceRange({
    required this.startHandle,
    required this.endHandle,
    required this.uuid,
  });

  final int startHandle;
  final int endHandle;
  final String uuid;
}

class _GattCharacteristicMetadata {
  const _GattCharacteristicMetadata({
    required this.declarationHandle,
    required this.valueHandle,
    required this.uuid,
    required this.properties,
  });

  final int declarationHandle;
  final int valueHandle;
  final String uuid;
  final int properties;

  String? serviceUuid(List<_GattServiceRange> services) {
    for (final service in services) {
      if (declarationHandle >= service.startHandle &&
          declarationHandle <= service.endHandle) {
        return service.uuid;
      }
    }
    return null;
  }

  Map<String, Object?> toJson(List<_GattServiceRange> services) => {
    'declarationHandle':
        '0x${declarationHandle.toRadixString(16).padLeft(4, '0')}',
    'valueHandle': '0x${valueHandle.toRadixString(16).padLeft(4, '0')}',
    'serviceUuid': serviceUuid(services),
    'characteristicUuid': uuid,
    'properties': properties,
    'propertyNames': [
      if ((properties & 0x01) != 0) 'broadcast',
      if ((properties & 0x02) != 0) 'read',
      if ((properties & 0x04) != 0) 'writeWithoutResponse',
      if ((properties & 0x08) != 0) 'write',
      if ((properties & 0x10) != 0) 'notify',
      if ((properties & 0x20) != 0) 'indicate',
      if ((properties & 0x40) != 0) 'authenticatedSignedWrites',
      if ((properties & 0x80) != 0) 'extendedProperties',
    ],
  };
}

class _ConnectionAttributeTable {
  final List<_GattServiceRange> services = [];
  final Map<int, _GattCharacteristicMetadata> characteristicsByValueHandle = {};
  final Map<int, String> attributesByHandle = {};

  /// ATT Find Information Response. Entries identify attribute UUIDs but are
  /// only classified as descriptors when their handles fall after a known
  /// characteristic value and before the next characteristic/service boundary.
  void readFindInformationResponse(Uint8List pdu) {
    if (pdu.length < 2) return;
    final format = pdu[1];
    final entryLength = switch (format) {
      0x01 => 4,
      0x02 => 18,
      _ => 0,
    };
    if (entryLength == 0 || (pdu.length - 2) % entryLength != 0) return;
    var offset = 2;
    while (offset + entryLength <= pdu.length) {
      final handle = _u16le(pdu, offset);
      final uuid = format == 0x01
          ? _uuid16(_u16le(pdu, offset + 2))
          : _uuid128LittleEndian(pdu, offset + 2);
      if (handle != 0) attributesByHandle[handle] = uuid;
      offset += entryLength;
    }
  }

  /// ATT Read By Group Type Response for primary/secondary service declarations.
  /// Entries are 6 bytes for 16-bit UUIDs or 20 bytes for 128-bit UUIDs.
  void readServiceDeclarations(Uint8List pdu) {
    if (pdu.length < 2) return;
    final entryLength = pdu[1];
    if (entryLength != 6 && entryLength != 20) return;
    var offset = 2;
    while (offset + entryLength <= pdu.length) {
      final startHandle = _u16le(pdu, offset);
      final endHandle = _u16le(pdu, offset + 2);
      final uuid = entryLength == 6
          ? _uuid16(_u16le(pdu, offset + 4))
          : _uuid128LittleEndian(pdu, offset + 4);
      if (startHandle != 0 && endHandle >= startHandle) {
        services.add(_GattServiceRange(
          startHandle: startHandle,
          endHandle: endHandle,
          uuid: uuid,
        ));
      }
      offset += entryLength;
    }
  }

  /// ATT Read By Type Response for characteristic declarations (UUID 0x2803).
  /// Entries are 7 bytes for 16-bit characteristic UUIDs or 21 for 128-bit.
  void readCharacteristicDeclarations(Uint8List pdu) {
    if (pdu.length < 2) return;
    final entryLength = pdu[1];
    if (entryLength != 7 && entryLength != 21) return;
    var offset = 2;
    while (offset + entryLength <= pdu.length) {
      final declarationHandle = _u16le(pdu, offset);
      final properties = pdu[offset + 2];
      final valueHandle = _u16le(pdu, offset + 3);
      final uuid = entryLength == 7
          ? _uuid16(_u16le(pdu, offset + 5))
          : _uuid128LittleEndian(pdu, offset + 5);
      if (declarationHandle != 0 && valueHandle > declarationHandle) {
        characteristicsByValueHandle[valueHandle] =
            _GattCharacteristicMetadata(
          declarationHandle: declarationHandle,
          valueHandle: valueHandle,
          uuid: uuid,
          properties: properties,
        );
      }
      offset += entryLength;
    }
  }

  Map<String, Object?> toJson() {
    final result = <String, Object?>{};
    final characteristics = characteristicsByValueHandle.values.toList()
      ..sort((a, b) => a.valueHandle.compareTo(b.valueHandle));
    for (final characteristic in characteristics) {
      result['0x${characteristic.valueHandle.toRadixString(16).padLeft(4, '0')}'] =
          characteristic.toJson(services);
    }
    return Map.unmodifiable(result);
  }

  Map<String, Object?> descriptorJson() {
    final result = <String, Object?>{};
    final characteristics = characteristicsByValueHandle.values.toList()
      ..sort((a, b) => a.declarationHandle.compareTo(b.declarationHandle));
    final attributes = attributesByHandle.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final attribute in attributes) {
      _GattCharacteristicMetadata? parent;
      for (final characteristic in characteristics) {
        if (attribute.key <= characteristic.valueHandle) continue;
        final service = services.where((item) =>
            characteristic.declarationHandle >= item.startHandle &&
            characteristic.declarationHandle <= item.endHandle).firstOrNull;
        final nextCharacteristic = characteristics.where((other) {
          if (other.declarationHandle <= characteristic.declarationHandle) {
            return false;
          }
          if (service == null) return true;
          return other.declarationHandle >= service.startHandle &&
              other.declarationHandle <= service.endHandle;
        }).firstOrNull;
        final endHandle = nextCharacteristic != null
            ? nextCharacteristic.declarationHandle - 1
            : service?.endHandle ?? 0xFFFF;
        if (attribute.key <= endHandle) {
          parent = characteristic;
          break;
        }
      }
      if (parent == null) continue;
      final uuid = attribute.value;
      result['0x${attribute.key.toRadixString(16).padLeft(4, '0')}'] = {
        'uuid': uuid,
        'descriptorType': _gattDescriptorTypeName(uuid),
        'serviceUuid': parent.serviceUuid(services),
        'characteristicValueHandle':
            '0x${parent.valueHandle.toRadixString(16).padLeft(4, '0')}',
        'characteristicUuid': parent.uuid,
      };
    }
    return Map.unmodifiable(result);
  }
}

class _MutableSession {
  _MutableSession({
    required this.id,
    required this.connectionHandle,
    required this.peerAddress,
    required this.peerAddressType,
    required this.deviceName,
    required this.startFrame,
    required this.startTimestampMicros,
  });

  final int id;
  final int connectionHandle;
  final String peerAddress;
  final int peerAddressType;
  final String? deviceName;
  final int startFrame;
  final int startTimestampMicros;
  int? endFrame;
  int? endTimestampMicros;
  int? disconnectStatus;
  int? disconnectReason;
  int attEventCount = 0;

  KptBleConnectionSession freeze() => KptBleConnectionSession(
    id: id,
    connectionHandle: connectionHandle,
    peerAddress: peerAddress,
    peerAddressType: peerAddressType,
    deviceName: deviceName,
    startFrame: startFrame,
    startTimestampMicros: startTimestampMicros,
    endFrame: endFrame,
    endTimestampMicros: endTimestampMicros,
    disconnectStatus: disconnectStatus,
    disconnectReason: disconnectReason,
    attEventCount: attEventCount,
  );
}

class _PendingL2cap {
  _PendingL2cap({required this.expectedLength, required this.bytes});

  final int expectedLength;
  final List<int> bytes;
}

String _attOpcodeName(int opcode) => switch (opcode) {
  0x01 => 'Error Response',
  0x02 => 'Exchange MTU Request',
  0x03 => 'Exchange MTU Response',
  0x04 => 'Find Information Request',
  0x05 => 'Find Information Response',
  0x06 => 'Find By Type Value Request',
  0x07 => 'Find By Type Value Response',
  0x08 => 'Read By Type Request',
  0x09 => 'Read By Type Response',
  0x0A => 'Read Request',
  0x0B => 'Read Response',
  0x0C => 'Read Blob Request',
  0x0D => 'Read Blob Response',
  0x0E => 'Read Multiple Request',
  0x0F => 'Read Multiple Response',
  0x10 => 'Read By Group Type Request',
  0x11 => 'Read By Group Type Response',
  0x12 => 'Write Request',
  0x13 => 'Write Response',
  0x16 => 'Prepare Write Request',
  0x17 => 'Prepare Write Response',
  0x18 => 'Execute Write Request',
  0x19 => 'Execute Write Response',
  0x1B => 'Handle Value Notification',
  0x1D => 'Handle Value Indication',
  0x1E => 'Handle Value Confirmation',
  0x52 => 'Write Command',
  0xD2 => 'Signed Write Command',
  _ => 'ATT opcode 0x${opcode.toRadixString(16).padLeft(2, '0')}',
};

Map<String, Object?>? _attProtocolDetails(Uint8List pdu) {
  if (pdu.isEmpty) return null;
  final opcode = pdu[0];
  switch (opcode) {
    case 0x04: // Find Information Request.
      if (pdu.length != 5) {
        return {
          'malformedPdu': true,
          'expectedLength': 5,
          'actualLength': pdu.length,
        };
      }
      return {
        'startHandle': '0x${_u16le(pdu, 1).toRadixString(16).padLeft(4, '0')}',
        'endHandle': '0x${_u16le(pdu, 3).toRadixString(16).padLeft(4, '0')}',
      };
    case 0x05: // Find Information Response.
      if (pdu.length < 2) {
        return {
          'malformedPdu': true,
          'expectedMinimumLength': 2,
          'actualLength': pdu.length,
        };
      }
      final format = pdu[1];
      final entryLength = switch (format) {
        0x01 => 4,
        0x02 => 18,
        _ => 0,
      };
      if (entryLength == 0 || (pdu.length - 2) % entryLength != 0) {
        return {
          'malformedPdu': true,
          'format': format,
          'actualLength': pdu.length,
        };
      }
      final entries = <Map<String, Object?>>[];
      var offset = 2;
      while (offset + entryLength <= pdu.length) {
        final handle = _u16le(pdu, offset);
        final uuid = format == 0x01
            ? _uuid16(_u16le(pdu, offset + 2))
            : _uuid128LittleEndian(pdu, offset + 2);
        entries.add({
          'handle': '0x${handle.toRadixString(16).padLeft(4, '0')}',
          'uuid': uuid,
          'descriptorType': _gattDescriptorTypeName(uuid),
        });
        offset += entryLength;
      }
      return {
        'format': format,
        'entryCount': entries.length,
        'entries': entries,
      };
    case 0x01: // Error Response.
      if (pdu.length < 5) {
        return {
          'malformedPdu': true,
          'expectedLength': 5,
          'actualLength': pdu.length,
        };
      }
      final requestOpcode = pdu[1];
      final errorCode = pdu[4];
      return {
        'requestOpcodeInError':
            '0x${requestOpcode.toRadixString(16).padLeft(2, '0')}',
        'requestOperation': _attOpcodeName(requestOpcode),
        'attributeHandleInError':
            '0x${_u16le(pdu, 2).toRadixString(16).padLeft(4, '0')}',
        'errorCode': '0x${errorCode.toRadixString(16).padLeft(2, '0')}',
        'error': _attErrorName(errorCode),
      };
    case 0x02: // Exchange MTU Request.
    case 0x03: // Exchange MTU Response.
      if (pdu.length < 3) {
        return {
          'malformedPdu': true,
          'expectedLength': 3,
          'actualLength': pdu.length,
        };
      }
      return {'receiveMtu': _u16le(pdu, 1)};
    case 0x08: // Read By Type Request.
    case 0x10: // Read By Group Type Request.
      if (pdu.length < 7 || (pdu.length != 7 && pdu.length != 21)) {
        return {
          'malformedPdu': true,
          'expectedLengths': const [7, 21],
          'actualLength': pdu.length,
        };
      }
      final uuid = pdu.length == 7
          ? _uuid16(_u16le(pdu, 5))
          : _uuid128LittleEndian(pdu, 5);
      return {
        'startHandle': '0x${_u16le(pdu, 1).toRadixString(16).padLeft(4, '0')}',
        'endHandle': '0x${_u16le(pdu, 3).toRadixString(16).padLeft(4, '0')}',
        opcode == 0x08 ? 'attributeTypeUuid' : 'groupTypeUuid': uuid,
      };
    default:
      return null;
  }
}

String _gattDescriptorTypeName(String uuid) => switch (uuid.toLowerCase()) {
  '00002900-0000-1000-8000-00805f9b34fb' => 'Characteristic Extended Properties',
  '00002901-0000-1000-8000-00805f9b34fb' => 'Characteristic User Description',
  '00002902-0000-1000-8000-00805f9b34fb' => 'Client Characteristic Configuration',
  '00002903-0000-1000-8000-00805f9b34fb' => 'Server Characteristic Configuration',
  '00002904-0000-1000-8000-00805f9b34fb' => 'Characteristic Presentation Format',
  '00002905-0000-1000-8000-00805f9b34fb' => 'Characteristic Aggregate Format',
  _ => 'Unknown or vendor-specific descriptor',
};

String _hciDisconnectReasonName(int reason) => switch (reason) {
  0x08 => 'Connection Timeout',
  0x13 => 'Remote User Terminated Connection',
  0x14 => 'Remote Device Terminated Connection due to Low Resources',
  0x15 => 'Remote Device Terminated Connection due to Power Off',
  0x16 => 'Connection Terminated by Local Host',
  0x22 => 'LMP Response Timeout',
  0x3B => 'Unacceptable Connection Parameters',
  _ => 'Unknown or other HCI disconnect reason',
};

String _attErrorName(int code) => switch (code) {
  0x01 => 'Invalid Handle',
  0x02 => 'Read Not Permitted',
  0x03 => 'Write Not Permitted',
  0x04 => 'Invalid PDU',
  0x05 => 'Insufficient Authentication',
  0x06 => 'Request Not Supported',
  0x07 => 'Invalid Offset',
  0x08 => 'Insufficient Authorization',
  0x09 => 'Prepare Queue Full',
  0x0A => 'Attribute Not Found',
  0x0B => 'Attribute Not Long',
  0x0C => 'Insufficient Encryption Key Size',
  0x0D => 'Invalid Attribute Value Length',
  0x0E => 'Unlikely Error',
  0x0F => 'Insufficient Encryption',
  0x10 => 'Unsupported Group Type',
  0x11 => 'Insufficient Resources',
  0x12 => 'Database Out of Sync',
  0x14 => 'MIC Length Too Short',
  _ when code >= 0x80 && code <= 0x9F => 'Application Error',
  _ when code >= 0xE0 && code <= 0xFF => 'Common Profile and Service Error',
  _ => 'Unknown ATT error',
};

int _u16le(List<int> bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

String _addressFromLittleEndian(List<int> bytes, int offset) =>
    List<String>.generate(
      6,
      (index) => bytes[offset + 5 - index].toRadixString(16).padLeft(2, '0'),
    ).join(':').toUpperCase();

String? _advertisedName(List<int> packet, int offset, int length) {
  final end = offset + length;
  while (offset < end) {
    final fieldLength = packet[offset];
    if (fieldLength == 0) break;
    if (offset + 1 + fieldLength > end) break;
    final type = packet[offset + 1];
    if (type == 0x08 || type == 0x09) {
      final value = utf8.decode(
        packet.sublist(offset + 2, offset + 1 + fieldLength),
        allowMalformed: true,
      ).trim();
      if (value.isNotEmpty) return value;
    }
    offset += fieldLength + 1;
  }
  return null;
}

String _uuid16(int value) =>
    '0000${value.toRadixString(16).padLeft(4, '0')}-0000-1000-8000-00805f9b34fb';

String _uuid128LittleEndian(List<int> bytes, int offset) {
  final reversed = List<int>.generate(16, (index) => bytes[offset + 15 - index]);
  final hex = reversed.map(_hexByte).join().toLowerCase();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}'.toLowerCase();
}

String _hexByte(int value) => value.toRadixString(16).padLeft(2, '0').toUpperCase();
