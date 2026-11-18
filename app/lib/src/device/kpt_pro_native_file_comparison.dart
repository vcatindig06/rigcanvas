import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

const int maximumNativeFileComparisonTotalBytes = 64 * 1024 * 1024;
const int _maximumStoredDifferenceRanges = 64;
const int _maximumDifferenceSamples = 48;
const int _maximumRangePreviewBytes = 16;

/// Local, bounded byte comparison. This reports offsets, not patch semantics.
class KptProNativeFileComparison {
  const KptProNativeFileComparison({
    required this.firstFilename,
    required this.secondFilename,
    required this.firstSizeBytes,
    required this.secondSizeBytes,
    required this.firstSha256,
    required this.secondSha256,
    required this.comparedLength,
    required this.changedByteCount,
    required this.unchangedByteCount,
    required this.commonPrefixBytes,
    required this.commonSuffixBytes,
    required this.differenceRanges,
    required this.omittedDifferenceRangeCount,
    required this.differenceSamples,
  });

  final String firstFilename;
  final String secondFilename;
  final int firstSizeBytes;
  final int secondSizeBytes;
  final String firstSha256;
  final String secondSha256;
  final int comparedLength;
  final int changedByteCount;
  final int unchangedByteCount;
  final int commonPrefixBytes;
  final int commonSuffixBytes;
  final List<KptProDifferenceRange> differenceRanges;
  final int omittedDifferenceRangeCount;
  final List<KptProDifferenceSample> differenceSamples;

  bool get sameLength => firstSizeBytes == secondSizeBytes;
  bool get isIdentical => sameLength && changedByteCount == 0;
  int get sizeDeltaBytes => secondSizeBytes - firstSizeBytes;
  double get changedPercent =>
      comparedLength == 0 ? 0 : changedByteCount * 100 / comparedLength;

  Map<String, Object?> toJson() => {
        'reportType': 'RigCanvas local native-file byte comparison',
        'comparisonVersion': 1,
        'firstFile': {
          'filename': firstFilename,
          'sizeBytes': firstSizeBytes,
          'sha256': firstSha256,
        },
        'secondFile': {
          'filename': secondFilename,
          'sizeBytes': secondSizeBytes,
          'sha256': secondSha256,
        },
        'sameLength': sameLength,
        'identicalBytes': isIdentical,
        'sizeDeltaBytes': sizeDeltaBytes,
        'comparedLength': comparedLength,
        'changedByteCount': changedByteCount,
        'unchangedByteCount': unchangedByteCount,
        'changedPercent': double.parse(changedPercent.toStringAsFixed(6)),
        'commonPrefixBytes': commonPrefixBytes,
        'commonSuffixBytes': commonSuffixBytes,
        'differenceRanges': differenceRanges.map((item) => item.toJson()).toList(),
        'omittedDifferenceRangeCount': omittedDifferenceRangeCount,
        'differenceSamples': differenceSamples.map((item) => item.toJson()).toList(),
        'sourceBytesIncluded': false,
        'deviceConnected': false,
        'vendorCommandsSent': false,
        'hardwareWritten': false,
        'kptProSchemaConfirmed': false,
        'byteMeaningDecoded': false,
      };

  static KptProNativeFileComparison compare({
    required String firstFilename,
    required Uint8List firstBytes,
    required String secondFilename,
    required Uint8List secondBytes,
  }) {
    if (firstBytes.isEmpty || secondBytes.isEmpty) {
      throw const FormatException('Both selected files must contain data.');
    }
    if (firstBytes.length + secondBytes.length >
        maximumNativeFileComparisonTotalBytes) {
      throw const FormatException('The two files together must not exceed 64 MiB.');
    }

    final length = firstBytes.length > secondBytes.length
        ? firstBytes.length
        : secondBytes.length;
    final overlap = firstBytes.length < secondBytes.length
        ? firstBytes.length
        : secondBytes.length;
    var prefix = 0;
    while (prefix < overlap && firstBytes[prefix] == secondBytes[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < overlap - prefix &&
        firstBytes[firstBytes.length - suffix - 1] ==
            secondBytes[secondBytes.length - suffix - 1]) {
      suffix++;
    }

    var changed = 0;
    var unchanged = 0;
    var rangeStart = -1;
    var omitted = 0;
    final ranges = <KptProDifferenceRange>[];
    final samples = <KptProDifferenceSample>[];

    void finishRange(int end) {
      if (rangeStart < 0) return;
      if (ranges.length < _maximumStoredDifferenceRanges) {
        final previewEnd = rangeStart + _maximumRangePreviewBytes;
        final endPreview = previewEnd < end ? previewEnd : end;
        ranges.add(KptProDifferenceRange(
          startOffset: rangeStart,
          endOffsetExclusive: end,
          firstHexPreview: _hex(firstBytes, rangeStart, endPreview),
          secondHexPreview: _hex(secondBytes, rangeStart, endPreview),
        ));
      } else {
        omitted++;
      }
      rangeStart = -1;
    }

    for (var offset = 0; offset < length; offset++) {
      final hasA = offset < firstBytes.length;
      final hasB = offset < secondBytes.length;
      final differs = !hasA || !hasB || firstBytes[offset] != secondBytes[offset];
      if (differs) {
        changed++;
        if (rangeStart < 0) rangeStart = offset;
        if (samples.length < _maximumDifferenceSamples) {
          samples.add(KptProDifferenceSample(
            offset: offset,
            firstByte: hasA ? firstBytes[offset] : null,
            secondByte: hasB ? secondBytes[offset] : null,
          ));
        }
      } else {
        unchanged++;
        finishRange(offset);
      }
    }
    finishRange(length);

    return KptProNativeFileComparison(
      firstFilename: _cleanName(firstFilename),
      secondFilename: _cleanName(secondFilename),
      firstSizeBytes: firstBytes.length,
      secondSizeBytes: secondBytes.length,
      firstSha256: crypto.sha256.convert(firstBytes).toString(),
      secondSha256: crypto.sha256.convert(secondBytes).toString(),
      comparedLength: length,
      changedByteCount: changed,
      unchangedByteCount: unchanged,
      commonPrefixBytes: prefix,
      commonSuffixBytes: suffix,
      differenceRanges: List.unmodifiable(ranges),
      omittedDifferenceRangeCount: omitted,
      differenceSamples: List.unmodifiable(samples),
    );
  }

  static String _cleanName(String path) =>
      path.split('/').last.split(r'\').last;

  static String _hex(Uint8List bytes, int start, int end) {
    if (start >= bytes.length || end <= start) return '';
    final limit = end < bytes.length ? end : bytes.length;
    return bytes.sublist(start, limit)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }
}

class KptProDifferenceRange {
  const KptProDifferenceRange({
    required this.startOffset,
    required this.endOffsetExclusive,
    required this.firstHexPreview,
    required this.secondHexPreview,
  });

  final int startOffset;
  final int endOffsetExclusive;
  final String firstHexPreview;
  final String secondHexPreview;

  int get length => endOffsetExclusive - startOffset;
  String get offsetLabel =>
      '0x${startOffset.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  Map<String, Object?> toJson() => {
        'startOffset': startOffset,
        'endOffsetExclusive': endOffsetExclusive,
        'length': length,
        'firstHexPreview': firstHexPreview,
        'secondHexPreview': secondHexPreview,
      };
}

class KptProDifferenceSample {
  const KptProDifferenceSample({
    required this.offset,
    required this.firstByte,
    required this.secondByte,
  });

  final int offset;
  final int? firstByte;
  final int? secondByte;

  String get offsetLabel =>
      '0x${offset.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  String get firstValue => _byteValue(firstByte);
  String get secondValue => _byteValue(secondByte);

  Map<String, Object?> toJson() => {
        'offset': offset,
        'firstByte': firstByte,
        'secondByte': secondByte,
      };

  static String _byteValue(int? byte) => byte == null
      ? '--'
      : byte.toRadixString(16).padLeft(2, '0').toUpperCase();
}
