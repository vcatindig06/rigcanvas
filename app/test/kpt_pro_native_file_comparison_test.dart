import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/device/kpt_pro_native_file_comparison.dart';

void main() {
  group('KptProNativeFileComparison', () {
    test('reports changed offsets as contiguous ranges', () {
      final result = KptProNativeFileComparison.compare(
        firstFilename: 'baseline.tone',
        firstBytes: Uint8List.fromList([1, 2, 3, 4, 5, 6]),
        secondFilename: 'edited.tone',
        secondBytes: Uint8List.fromList([1, 255, 3, 4, 170, 6]),
      );

      expect(result.changedByteCount, 2);
      expect(result.unchangedByteCount, 4);
      expect(result.commonPrefixBytes, 1);
      expect(result.commonSuffixBytes, 1);
      expect(result.differenceRanges, hasLength(2));
      expect(result.differenceRanges[0].startOffset, 1);
      expect(result.differenceRanges[1].startOffset, 4);
      expect(result.differenceSamples.map((item) => item.offset), [1, 4]);
      expect(result.differenceSamples.first.firstValue, '02');
      expect(result.differenceSamples.first.secondValue, 'FF');
      expect(result.toJson()['sourceBytesIncluded'], isFalse);
      expect(result.toJson()['kptProSchemaConfirmed'], isFalse);
      expect(result.toJson()['hardwareWritten'], isFalse);
    });

    test('reports a longer second-file tail as changed bytes', () {
      final result = KptProNativeFileComparison.compare(
        firstFilename: 'short.tone',
        firstBytes: Uint8List.fromList([16, 32]),
        secondFilename: 'long.tone',
        secondBytes: Uint8List.fromList([16, 32, 48, 64]),
      );

      expect(result.sameLength, isFalse);
      expect(result.sizeDeltaBytes, 2);
      expect(result.commonPrefixBytes, 2);
      expect(result.changedByteCount, 2);
      expect(result.differenceRanges.single.startOffset, 2);
      expect(result.differenceRanges.single.length, 2);
      expect(result.differenceSamples.first.firstValue, '--');
      expect(result.differenceSamples.first.secondValue, '30');
    });

    test('recognizes byte-identical files', () {
      final result = KptProNativeFileComparison.compare(
        firstFilename: 'first.bin',
        firstBytes: Uint8List.fromList([1, 2, 3]),
        secondFilename: 'copy.bin',
        secondBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(result.isIdentical, isTrue);
      expect(result.changedByteCount, 0);
      expect(result.differenceRanges, isEmpty);
      expect(result.commonPrefixBytes, 3);
      expect(result.commonSuffixBytes, 0);
      expect(result.firstSha256, result.secondSha256);
    });

    test('rejects empty inputs and combined sizes above the bound', () {
      expect(
        () => KptProNativeFileComparison.compare(
          firstFilename: 'empty.bin',
          firstBytes: Uint8List(0),
          secondFilename: 'valid.bin',
          secondBytes: Uint8List.fromList([1]),
        ),
        throwsFormatException,
      );
      expect(
        () => KptProNativeFileComparison.compare(
          firstFilename: 'large-a.bin',
          firstBytes: Uint8List(maximumNativeFileComparisonTotalBytes ~/ 2),
          secondFilename: 'large-b.bin',
          secondBytes: Uint8List(maximumNativeFileComparisonTotalBytes ~/ 2 + 1),
        ),
        throwsFormatException,
      );
    });
  });
}
