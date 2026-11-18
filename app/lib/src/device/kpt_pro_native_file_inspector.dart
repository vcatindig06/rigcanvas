import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const int maximumNativePatchFileInspectionBytes = 64 * 1024 * 1024;
const int _maximumEntropySampleBytes = 64 * 1024;
const int _maximumJsonInspectionBytes = 4 * 1024 * 1024;

/// A local, format-agnostic inspection of an M-EFCS-exported candidate file.
///
/// It identifies generic container signatures and metadata only. It does not
/// claim a KPT Pro schema, decode a patch, create device commands, or retain
/// the source bytes after inspection.
class KptProNativeFileInspection {
  const KptProNativeFileInspection({
    required this.filename,
    required this.extension,
    required this.fileSizeBytes,
    required this.sha256,
    required this.signature,
    required this.formatNote,
    required this.hexPreview,
    required this.printableStrings,
    required this.sampleEntropyBitsPerByte,
    required this.jsonRootKeys,
    required this.isValidJson,
  });

  final String filename;
  final String extension;
  final int fileSizeBytes;
  final String sha256;
  final String signature;
  final String formatNote;
  final String hexPreview;
  final List<String> printableStrings;
  final double sampleEntropyBitsPerByte;
  final List<String> jsonRootKeys;
  final bool isValidJson;

  String get fileSizeLabel {
    if (fileSizeBytes >= 1024 * 1024) {
      return (fileSizeBytes / (1024 * 1024)).toStringAsFixed(2) + ' MiB';
    }
    if (fileSizeBytes >= 1024) {
      return (fileSizeBytes / 1024).toStringAsFixed(1) + ' KiB';
    }
    return fileSizeBytes.toString() + ' bytes';
  }

  Map<String, Object?> toJson() => {
        'reportType': 'RigCanvas generic native-file inspection',
        'inspectionVersion': 1,
        'filename': filename,
        'extension': extension,
        'fileSizeBytes': fileSizeBytes,
        'sha256': sha256,
        'signature': signature,
        'formatNote': formatNote,
        'hexPreviewFirst48Bytes': hexPreview,
        'sampleEntropyBitsPerByte': double.parse(
          sampleEntropyBitsPerByte.toStringAsFixed(4),
        ),
        'validJson': isValidJson,
        'jsonRootKeys': jsonRootKeys,
        'printableStrings': printableStrings,
        'sourceBytesIncluded': false,
        'deviceConnected': false,
        'vendorCommandsSent': false,
        'hardwareWritten': false,
        'kptProSchemaConfirmed': false,
      };

  static KptProNativeFileInspection inspect({
    required String filename,
    required Uint8List bytes,
  }) {
    if (bytes.isEmpty) {
      throw const FormatException('The selected file is empty.');
    }
    if (bytes.length > maximumNativePatchFileInspectionBytes) {
      throw const FormatException(
        'Files larger than 64 MiB are not supported by this inspector.',
      );
    }

    final cleanName = filename.split('/').last.split(r'\').last;
    final dot = cleanName.lastIndexOf('.');
    final extension = dot > 0 && dot < cleanName.length - 1
        ? cleanName.substring(dot).toLowerCase()
        : '';

    final signature = _identifySignature(bytes);
    final jsonInspection = _inspectJson(bytes, signature);
    final note = _formatNote(
      signature: signature,
      extension: extension,
      validJson: jsonInspection.$1,
    );

    return KptProNativeFileInspection(
      filename: cleanName,
      extension: extension,
      fileSizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      signature: signature,
      formatNote: note,
      hexPreview: bytes
          .take(48)
          .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' '),
      printableStrings: _extractPrintableStrings(bytes),
      sampleEntropyBitsPerByte: _sampleEntropy(bytes),
      isValidJson: jsonInspection.$1,
      jsonRootKeys: jsonInspection.$2,
    );
  }

  static String _identifySignature(Uint8List bytes) {
    bool starts(List<int> prefix) {
      if (bytes.length < prefix.length) return false;
      for (var index = 0; index < prefix.length; index++) {
        if (bytes[index] != prefix[index]) return false;
      }
      return true;
    }

    if (starts(const [0x50, 0x4B, 0x03, 0x04]) ||
        starts(const [0x50, 0x4B, 0x05, 0x06]) ||
        starts(const [0x50, 0x4B, 0x07, 0x08])) {
      return 'ZIP archive';
    }
    if (starts(const [0x1F, 0x8B])) return 'GZIP stream';
    if (starts(const [0x52, 0x49, 0x46, 0x46])) {
      if (bytes.length >= 12 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x41 &&
          bytes[10] == 0x56 &&
          bytes[11] == 0x45) {
        return 'RIFF/WAVE audio';
      }
      return 'RIFF container';
    }
    if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'PNG image';
    }
    if (starts(const [0xFF, 0xD8, 0xFF])) return 'JPEG image';
    if (starts(const [0x25, 0x50, 0x44, 0x46, 0x2D])) return 'PDF document';
    if (starts(const [0x53, 0x51, 0x4C, 0x69, 0x74, 0x65])) {
      return 'SQLite database';
    }
    if (starts(const [0x7F, 0x45, 0x4C, 0x46])) return 'ELF executable';
    if (starts(const [0x4D, 0x5A])) return 'Windows PE/DOS executable';
    if (starts(const [0x66, 0x4C, 0x61, 0x43])) return 'FLAC audio';
    if (starts(const [0x4F, 0x67, 0x67, 0x53])) return 'Ogg container';
    if (starts(const [0x49, 0x44, 0x33])) return 'MP3 audio (ID3 tag)';

    final first = _firstNonWhitespaceByte(bytes);
    if (first == 0x7B || first == 0x5B) return 'JSON document (candidate)';
    if (first == 0x3C) return 'XML/HTML text (candidate)';
    return 'Unknown binary/text container';
  }

  static int? _firstNonWhitespaceByte(Uint8List bytes) {
    var index = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      index = 3;
    }
    while (index < bytes.length) {
      final value = bytes[index];
      if (value != 0x20 &&
          value != 0x09 &&
          value != 0x0A &&
          value != 0x0D) {
        return value;
      }
      index++;
    }
    return null;
  }

  static (bool, List<String>) _inspectJson(
    Uint8List bytes,
    String signature,
  ) {
    if (signature != 'JSON document (candidate)' ||
        bytes.length > _maximumJsonInspectionBytes) {
      return (false, const <String>[]);
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) {
        return (
          true,
          decoded.keys.take(64).map((key) => key.toString()).toList(),
        );
      }
      if (decoded is List) return (true, const <String>[]);
    } on FormatException {
      return (false, const <String>[]);
    }
    return (false, const <String>[]);
  }

  static String _formatNote({
    required String signature,
    required String extension,
    required bool validJson,
  }) {
    if (signature == 'RIFF/WAVE audio') {
      return 'WAV audio container. This signature alone does not identify a whole-patch file; it may be an IR or another audio asset.';
    }
    if (signature == 'ZIP archive') {
      return 'ZIP container detected. Contents were not extracted. A ZIP signature does not identify a KPT Pro patch schema.';
    }
    if (signature == 'JSON document (candidate)') {
      return validJson
          ? 'Valid JSON container. Root keys are listed separately; no KPT Pro patch schema is assumed.'
          : 'JSON-like prefix, but the file did not pass the bounded JSON parse.';
    }
    if (extension == '.am2' || extension == '.amp') {
      return 'Proprietary-looking AMP/capture extension. The payload is preserved as unknown; this is not classified as a complete preset.';
    }
    return 'Generic signature only. No KPT Pro patch structure or device compatibility is established.';
  }

  static List<String> _extractPrintableStrings(Uint8List bytes) {
    final results = <String>[];
    final seen = <String>{};
    final current = StringBuffer();

    void finish() {
      final value = current.toString().trim();
      current.clear();
      if (value.length < 4 || results.length >= 30 || !seen.add(value)) return;
      results.add(value.length > 120 ? value.substring(0, 120) : value);
    }

    for (final byte in bytes) {
      if (byte >= 0x20 && byte <= 0x7E) {
        if (current.length < 240) current.writeCharCode(byte);
      } else {
        finish();
      }
      if (results.length >= 30) break;
    }
    finish();
    return List<String>.unmodifiable(results);
  }

  static double _sampleEntropy(Uint8List bytes) {
    final length = math.min(bytes.length, _maximumEntropySampleBytes);
    final counts = List<int>.filled(256, 0);
    for (var index = 0; index < length; index++) {
      counts[bytes[index]]++;
    }

    var entropy = 0.0;
    for (final count in counts) {
      if (count == 0) continue;
      final probability = count / length;
      entropy -= probability * (math.log(probability) / math.ln2);
    }
    return entropy;
  }
}
