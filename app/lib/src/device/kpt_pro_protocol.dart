import 'dart:typed_data';

/// One KPT Pro vendor-protocol frame decoded from captured bytes.
///
/// The current format definition is based on the owner's KPT Pro BLE trace
/// (2026-11-17). This class only parses incoming/captured bytes. It deliberately
/// provides no frame encoder, command builder, BLE transport, or write API.
class KptProProtocolFrame {
  KptProProtocolFrame._({
    required this.commandId,
    required this.reservedByte,
    required this.bodyBytes,
    required this.checksum,
    required this.rawBytes,
  });

  static const int magic0 = 0x00;
  static const int magic1 = 0x59;
  static const int headerLength = 6;
  static const int minimumFrameLength = 7;

  /// Parses exactly one complete frame and validates its observed checksum.
  ///
  /// Captured frames use:
  /// 00 59 | command | body length (u16 LE) | reserved | body | checksum.
  /// The checksum is the 8-bit complement of the body-byte sum.
  ///
  /// [maxBodyLength] is a defensive limit for untrusted capture/notification
  /// data. The largest complete KPT Pro body in the supplied trace was 848
  /// bytes; the default leaves headroom without accepting a 64 KiB allocation.
  static KptProProtocolFrame parse(
    List<int> bytes, {
    int maxBodyLength = 8192,
  }) {
    if (maxBodyLength < 0 || maxBodyLength > 0xFFFF) {
      throw ArgumentError.value(
        maxBodyLength,
        'maxBodyLength',
        'Must be between 0 and 65535.',
      );
    }
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] < 0 || bytes[i] > 0xFF) {
        throw FormatException('Byte at offset $i is outside the 0–255 range.');
      }
    }
    if (bytes.length < minimumFrameLength) {
      throw FormatException(
        'KPT Pro frame is truncated: at least $minimumFrameLength bytes are required.',
      );
    }
    if (bytes[0] != magic0 || bytes[1] != magic1) {
      throw const FormatException('KPT Pro frame magic must be 00 59.');
    }

    final bodyLength = bytes[3] | (bytes[4] << 8);
    if (bodyLength > maxBodyLength) {
      throw FormatException(
        'KPT Pro frame body length $bodyLength exceeds the configured limit $maxBodyLength.',
      );
    }

    final expectedLength = minimumFrameLength + bodyLength;
    if (bytes.length != expectedLength) {
      throw FormatException(
        'KPT Pro frame length mismatch: header declares $expectedLength bytes, '
        'but ${bytes.length} bytes were supplied.',
      );
    }

    final body = List<int>.unmodifiable(bytes.sublist(headerLength, headerLength + bodyLength));
    final checksum = bytes[headerLength + bodyLength];
    final expectedChecksum = _checksumForBody(body);
    if (checksum != expectedChecksum) {
      throw FormatException(
        'KPT Pro frame checksum mismatch: received 0x${_hex(checksum)}, '
        'expected 0x${_hex(expectedChecksum)}.',
      );
    }

    return KptProProtocolFrame._(
      commandId: bytes[2],
      reservedByte: bytes[5],
      bodyBytes: body,
      checksum: checksum,
      rawBytes: List<int>.unmodifiable(bytes),
    );
  }

  /// Observed command byte. Its semantic meaning is not decoded here.
  final int commandId;

  /// Byte 5 in the observed frame header. Captures currently show 0x00.
  /// It is preserved rather than interpreted or forced to a constant.
  final int reservedByte;

  final List<int> bodyBytes;
  final int checksum;

  /// Original complete frame, including header and checksum.
  final List<int> rawBytes;

  int get bodyLength => bodyBytes.length;
  int get frameLength => rawBytes.length;

  /// Always true for successfully parsed frames; the parser rejects invalid
  /// checksums instead of returning a partly trusted frame.
  bool get checksumValid => true;

  static int _checksumForBody(List<int> body) {
    var sum = 0;
    for (final byte in body) {
      sum = (sum + byte) & 0xFF;
    }
    return (0xFF - sum) & 0xFF;
  }

  static String _hex(int value) => value.toRadixString(16).padLeft(2, '0').toUpperCase();
}

/// Reassembles KPT Pro frames split across BLE value notifications.
///
/// Notifications that do not start a KPT Pro frame are ignored while idle.
/// Once a frame header is detected, later notification payloads are appended
/// until the declared frame length is reached. This is a byte-stream utility;
/// it does not subscribe to BLE notifications or send data to a pedal.
class KptProNotificationFrameReassembler {
  KptProNotificationFrameReassembler({this.maxBodyLength = 8192}) {
    if (maxBodyLength < 0 || maxBodyLength > 0xFFFF) {
      throw ArgumentError.value(
        maxBodyLength,
        'maxBodyLength',
        'Must be between 0 and 65535.',
      );
    }
  }

  final int maxBodyLength;
  final List<int> _pending = <int>[];

  bool get hasPendingFrame => _pending.isNotEmpty;
  int get bufferedByteCount => _pending.length;

  /// Adds one notification payload and returns every complete frame produced.
  ///
  /// A one-byte 00 prefix is retained so a frame magic sequence split
  /// between notifications is handled. Unknown notifications are not buffered.
  List<KptProProtocolFrame> addNotification(List<int> notification) {
    if (notification.isEmpty) return const <KptProProtocolFrame>[];

    for (var i = 0; i < notification.length; i++) {
      if (notification[i] < 0 || notification[i] > 0xFF) {
        throw FormatException(
          'Notification byte at offset $i is outside the 0–255 range.',
        );
      }
    }

    if (_pending.isEmpty) {
      if (notification[0] != KptProProtocolFrame.magic0) {
        return const <KptProProtocolFrame>[];
      }
      if (notification.length == 1) {
        _pending.add(notification[0]);
        return const <KptProProtocolFrame>[];
      }
      if (notification[1] != KptProProtocolFrame.magic1) {
        return const <KptProProtocolFrame>[];
      }
    } else if (_pending.length == 1 &&
        _pending[0] == KptProProtocolFrame.magic0 &&
        notification[0] != KptProProtocolFrame.magic1) {
      _pending.clear();
      return addNotification(notification);
    }

    _pending.addAll(notification);
    final frames = <KptProProtocolFrame>[];

    try {
      while (_pending.length >= 2) {
        if (_pending[0] != KptProProtocolFrame.magic0 ||
            _pending[1] != KptProProtocolFrame.magic1) {
          throw const FormatException(
            'Unexpected bytes after a KPT Pro frame; notification stream is not aligned.',
          );
        }
        if (_pending.length < 5) break;

        final bodyLength = _pending[3] | (_pending[4] << 8);
        if (bodyLength > maxBodyLength) {
          throw FormatException(
            'KPT Pro frame body length $bodyLength exceeds the configured limit $maxBodyLength.',
          );
        }

        final expectedLength = KptProProtocolFrame.minimumFrameLength + bodyLength;
        if (_pending.length < expectedLength) break;

        final frameBytes = _pending.sublist(0, expectedLength);
        frames.add(KptProProtocolFrame.parse(
          frameBytes,
          maxBodyLength: maxBodyLength,
        ));
        _pending.removeRange(0, expectedLength);
      }
    } on FormatException {
      _pending.clear();
      rethrow;
    }

    return List<KptProProtocolFrame>.unmodifiable(frames);
  }

  /// Discards any incomplete frame, for example when the BLE connection drops.
  void reset() => _pending.clear();
}
