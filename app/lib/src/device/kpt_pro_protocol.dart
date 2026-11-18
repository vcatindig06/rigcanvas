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

  static int _checksumForBody(List<int> body) {
    var sum = 0;
    for (final byte in body) {
      sum = (sum + byte) & 0xFF;
    }
    return (0xFF - sum) & 0xFF;
  }

  static String _hex(int value) => value.toRadixString(16).padLeft(2, '0').toUpperCase();
}

/// Comparison-only f1/f2 field slicing for observed 8-byte KPT Pro 0x23 bodies.
///
/// The split and bit positions mirror a separately reverse-engineered Tank-G
/// frame-family hypothesis. A structural match is not proof that KPT Pro uses
/// the same memory map or command semantics. In particular, this class does
/// not identify a read, preset, slot, write, or commit operation.
class KptProF1F2LayoutCandidate {
  const KptProF1F2LayoutCandidate({
    required this.firstWordLittleEndian,
    required this.secondWordLittleEndian,
    required this.memoryIdCandidate,
    required this.addressCandidate,
    required this.lengthCandidate,
    required this.spaceCandidate,
    required this.reservedLowNibbleCandidate,
    required this.upper16BitsCandidate,
    required this.rawBodyBytes,
  });

  /// Returns a candidate only for the exact observed CMD 0x23 / 8-byte shape.
  /// All extracted values remain labelled as candidates.
  static KptProF1F2LayoutCandidate? tryParse(KptProProtocolFrame frame) {
    if (frame.commandId != 0x23 || frame.bodyLength != 8) return null;

    final body = frame.bodyBytes;
    final firstWord = _readUint32LittleEndian(body, 0);
    final secondWord = _readUint32LittleEndian(body, 4);
    return KptProF1F2LayoutCandidate(
      firstWordLittleEndian: firstWord,
      secondWordLittleEndian: secondWord,
      memoryIdCandidate: firstWord & 0xFF,
      addressCandidate: (firstWord >> 8) & 0xFFFFFF,
      lengthCandidate: (secondWord >> 8) & 0xFF,
      spaceCandidate: (secondWord >> 4) & 0x0F,
      reservedLowNibbleCandidate: secondWord & 0x0F,
      upper16BitsCandidate: (secondWord >> 16) & 0xFFFF,
      rawBodyBytes: List<int>.unmodifiable(body),
    );
  }

  /// Raw first 32-bit word, interpreted as little-endian for comparison only.
  final int firstWordLittleEndian;

  /// Raw second 32-bit word, interpreted as little-endian for comparison only.
  final int secondWordLittleEndian;

  /// Candidate low-byte field under the Tank-G-style f1 split.
  final int memoryIdCandidate;

  /// Candidate 24-bit field under the Tank-G-style f1 split.
  final int addressCandidate;

  /// Candidate byte field under the Tank-G-style f2 split.
  final int lengthCandidate;

  /// Candidate nibble field under the Tank-G-style f2 split.
  final int spaceCandidate;

  /// Preserved low nibble; zero in the two recurring observed examples.
  final int reservedLowNibbleCandidate;

  /// Preserved high 16 bits; zero in the two recurring observed examples.
  final int upper16BitsCandidate;

  /// Original eight body bytes, retained unchanged.
  final List<int> rawBodyBytes;

  String get firstWordHex => _hex32(firstWordLittleEndian);
  String get secondWordHex => _hex32(secondWordLittleEndian);
  String get addressCandidateHex =>
      '0x${addressCandidate.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  String get rawBodyHex => rawBodyBytes.map(_hex8).join(' ');

  Map<String, Object?> toJson() => {
    'hypothesisOnly': true,
    'layout': 'Tank-G-style f1/f2 comparison; not confirmed for KPT Pro',
    'firstWordLittleEndian': firstWordHex,
    'secondWordLittleEndian': secondWordHex,
    'memoryIdCandidate': memoryIdCandidate,
    'addressCandidate': addressCandidateHex,
    'lengthCandidate': lengthCandidate,
    'spaceCandidate': spaceCandidate,
    'reservedLowNibbleCandidate': reservedLowNibbleCandidate,
    'upper16BitsCandidate': upper16BitsCandidate,
    'rawBodyHex': rawBodyHex,
  };

  static int _readUint32LittleEndian(List<int> bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);

  static String _hex32(int value) =>
      '0x${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  static String _hex8(int value) =>
      value.toRadixString(16).padLeft(2, '0').toUpperCase();
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
      if (_pending.length == 1 && _pending.single != KptProProtocolFrame.magic0) {
        throw const FormatException(
          'Unexpected trailing byte after a KPT Pro frame.',
        );
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
