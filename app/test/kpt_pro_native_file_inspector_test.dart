import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/device/kpt_pro_native_file_inspector.dart';

void main() {
  group('KptProNativeFileInspector', () {
    test('fingerprints a JSON file and reports root keys without assuming schema', () {
      final bytes = Uint8List.fromList(
        utf8.encode('{"version":1,"name":"Test Tone","parameters":[]}'),
      );

      final result = KptProNativeFileInspection.inspect(
        filename: 'tone-export.json',
        bytes: bytes,
      );

      expect(result.signature, 'JSON document (candidate)');
      expect(result.isValidJson, isTrue);
      expect(result.jsonRootKeys, ['version', 'name', 'parameters']);
      expect(result.sha256, isNotEmpty);
      expect(result.extension, '.json');
      expect(result.toJson()['kptProSchemaConfirmed'], isFalse);
      expect(result.toJson()['sourceBytesIncluded'], isFalse);
    });

    test('recognizes ZIP containers but does not claim a KPT patch schema', () {
      final result = KptProNativeFileInspection.inspect(
        filename: 'mystery.am2',
        bytes: Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x00]),
      );

      expect(result.signature, 'ZIP archive');
      expect(result.formatNote, contains('ZIP container'));
      expect(result.formatNote, contains('does not identify'));
    });

    test('recognizes WAV as audio rather than a whole-patch export', () {
      final result = KptProNativeFileInspection.inspect(
        filename: 'cabinet.wav',
        bytes: Uint8List.fromList([
          0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00,
          0x57, 0x41, 0x56, 0x45,
        ]),
      );

      expect(result.signature, 'RIFF/WAVE audio');
      expect(result.formatNote, contains('not a whole-patch file'));
    });

    test('extracts readable metadata strings from unknown binary data', () {
      final result = KptProNativeFileInspection.inspect(
        filename: 'sample.unknown',
        bytes: Uint8List.fromList([
          0x00, ...utf8.encode('KPTPRO_008'), 0x00,
          ...utf8.encode('CL-UweTwins'),
        ]),
      );

      expect(result.signature, 'Unknown binary/text container');
      expect(result.printableStrings, contains('KPTPRO_008'));
      expect(result.printableStrings, contains('CL-UweTwins'));
    });

    test('rejects empty and oversized files', () {
      expect(
        () => KptProNativeFileInspection.inspect(
          filename: 'empty.bin',
          bytes: Uint8List(0),
        ),
        throwsFormatException,
      );
      expect(
        () => KptProNativeFileInspection.inspect(
          filename: 'large.bin',
          bytes: Uint8List(maximumNativePatchFileInspectionBytes + 1),
        ),
        throwsFormatException,
      );
    });
  });
}
