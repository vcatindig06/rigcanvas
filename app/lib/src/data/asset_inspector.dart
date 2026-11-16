import 'dart:convert';
import 'dart:typed_data';

import '../models/rig_asset.dart';

class AssetInspection {
  const AssetInspection({
    required this.kind,
    required this.extension,
    required this.validation,
    required this.formatSummary,
    this.suggestedTitle,
    this.manufacturer,
    this.model,
    this.sampleRateHz,
    this.channelCount,
    this.bitDepth,
  });

  final RigAssetKind kind;
  final String extension;
  final RigAssetValidation validation;
  final String formatSummary;
  final String? suggestedTitle;
  final String? manufacturer;
  final String? model;
  final int? sampleRateHz;
  final int? channelCount;
  final int? bitDepth;
}

class AssetInspector {
  const AssetInspector._();

  static const List<String> ampCaptureExtensions = ['nam', 'am2', 'amp'];
  static const List<String> cabinetIrExtensions = ['wav', 'wave'];

  static AssetInspection inspect({
    required RigAssetKind kind,
    required String filename,
    required Uint8List bytes,
  }) {
    if (bytes.isEmpty) {
      throw const FormatException('The selected file is empty.');
    }
    if (bytes.length > maximumAssetFileBytes) {
      throw const FormatException('Asset files must be 64 MiB or smaller.');
    }

    final cleanName = filename.split(RegExp(r'[/\\]')).last;
    final dot = cleanName.lastIndexOf('.');
    if (dot <= 0 || dot == cleanName.length - 1) {
      throw const FormatException('The selected file has no supported extension.');
    }
    final extension = cleanName.substring(dot).toLowerCase();

    if (kind == RigAssetKind.ampCapture) {
      if (!ampCaptureExtensions.contains(extension.substring(1))) {
        throw const FormatException(
          'Capture files must use .nam, .am2, or .amp extensions.',
        );
      }
      if (extension == '.nam') {
        return _inspectNam(extension, bytes);
      }
      return AssetInspection(
        kind: kind,
        extension: extension,
        validation: RigAssetValidation.unverified,
        formatSummary:
            'Stored unchanged · proprietary capture structure and device compatibility are not verified.',
        suggestedTitle: cleanName.substring(0, dot),
      );
    }

    if (!cabinetIrExtensions.contains(extension.substring(1))) {
      throw const FormatException(
        'Cabinet impulse responses must be WAV files (.wav or .wave).',
      );
    }
    return _inspectWav(extension, bytes, cleanName.substring(0, dot));
  }

  static AssetInspection _inspectNam(
    String extension,
    Uint8List bytes,
  ) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const FormatException('NAM file is not valid UTF-8 JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('NAM file must contain a JSON object.');
    }

    final version = decoded['version'];
    final architecture = decoded['architecture'];
    final config = decoded['config'];
    final weights = decoded['weights'];
    if (version is! String ||
        version.trim().isEmpty ||
        architecture is! String ||
        architecture.trim().isEmpty ||
        config is! Map<String, dynamic> ||
        weights is! List) {
      throw const FormatException(
        'NAM file is missing its required version, architecture, config, or weights fields.',
      );
    }
    for (final weight in weights) {
      if (weight is! num || !weight.isFinite) {
        throw const FormatException('NAM weights must contain finite numbers.');
      }
    }

    final rawSampleRate = decoded['sample_rate'];
    int? sampleRate;
    if (rawSampleRate != null) {
      if (rawSampleRate is! num ||
          !rawSampleRate.isFinite ||
          rawSampleRate < 8000 ||
          rawSampleRate > 192000) {
        throw const FormatException('NAM sample rate is outside the supported inspection range.');
      }
      sampleRate = rawSampleRate.round();
    }

    final metadata = decoded['metadata'];
    final metadataMap = metadata is Map<String, dynamic>
        ? metadata
        : const <String, dynamic>{};
    String? metadataString(String key) {
      final value = metadataMap[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final modelName = metadataString('name');
    final manufacturer = metadataString('gear_make');
    final model = metadataString('gear_model');
    final rateDescription = sampleRate == null
        ? '48 kHz default'
        : '${sampleRate} Hz';
    return AssetInspection(
      kind: RigAssetKind.ampCapture,
      extension: extension,
      validation: RigAssetValidation.validated,
      formatSummary: 'NAM v$version · $architecture · $rateDescription · JSON structure checked',
      suggestedTitle: modelName,
      manufacturer: manufacturer,
      model: model,
      sampleRateHz: sampleRate,
    );
  }

  static AssetInspection _inspectWav(
    String extension,
    Uint8List bytes,
    String suggestedTitle,
  ) {
    if (bytes.length < 44) {
      throw const FormatException('WAV file is too short to contain a valid header.');
    }
    final reader = ByteData.sublistView(bytes);
    String fourCc(int offset) => String.fromCharCodes(bytes.sublist(offset, offset + 4));

    if (fourCc(0) != 'RIFF' || fourCc(8) != 'WAVE') {
      throw const FormatException('File does not contain a RIFF/WAVE header.');
    }
    final riffLength = reader.getUint32(4, Endian.little) + 8;
    if (riffLength > bytes.length || riffLength < 44) {
      throw const FormatException('WAV RIFF length is invalid or truncated.');
    }

    int? encoding;
    int? channels;
    int? sampleRate;
    int? blockAlign;
    int? bitDepth;
    int? dataLength;
    var offset = 12;

    while (offset + 8 <= riffLength) {
      final chunkId = fourCc(offset);
      final chunkLength = reader.getUint32(offset + 4, Endian.little);
      final chunkStart = offset + 8;
      final chunkEnd = chunkStart + chunkLength;
      if (chunkEnd > riffLength) {
        throw const FormatException('WAV contains a truncated chunk.');
      }

      if (chunkId == 'fmt ') {
        if (chunkLength < 16) {
          throw const FormatException('WAV format chunk is incomplete.');
        }
        encoding = reader.getUint16(chunkStart, Endian.little);
        channels = reader.getUint16(chunkStart + 2, Endian.little);
        sampleRate = reader.getUint32(chunkStart + 4, Endian.little);
        blockAlign = reader.getUint16(chunkStart + 12, Endian.little);
        bitDepth = reader.getUint16(chunkStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataLength = chunkLength;
      }

      offset = chunkEnd + (chunkLength.isOdd ? 1 : 0);
    }

    if (encoding == null ||
        channels == null ||
        sampleRate == null ||
        blockAlign == null ||
        bitDepth == null ||
        dataLength == null) {
      throw const FormatException('WAV must contain both format and audio data chunks.');
    }
    if (encoding != 1 && encoding != 3) {
      throw const FormatException('WAV encoding must be PCM or IEEE floating point.');
    }
    if (channels! < 1 || channels! > 2) {
      throw const FormatException('Cabinet IR WAV files must be mono or stereo.');
    }
    if (sampleRate! < 8000 || sampleRate! > 192000) {
      throw const FormatException('WAV sample rate must be between 8 and 192 kHz.');
    }
    final validPcmDepth = [8, 16, 24, 32].contains(bitDepth);
    final validFloatDepth = [32, 64].contains(bitDepth);
    if ((encoding == 1 && !validPcmDepth) ||
        (encoding == 3 && !validFloatDepth)) {
      throw const FormatException('WAV bit depth is not supported for its encoding.');
    }
    final bytesPerSample = (bitDepth! + 7) ~/ 8;
    final expectedBlockAlign = channels! * bytesPerSample;
    if (blockAlign! != expectedBlockAlign ||
        dataLength! <= 0 ||
        dataLength! % blockAlign! != 0) {
      throw const FormatException('WAV block alignment or audio data length is invalid.');
    }

    final validChannels = channels!;
    final validSampleRate = sampleRate!;
    final validBlockAlign = blockAlign!;
    final validBitDepth = bitDepth!;
    final validDataLength = dataLength!;
    final frameCount = validDataLength ~/ validBlockAlign;
    final durationMs = frameCount * 1000 / validSampleRate;
    final channelLabel = validChannels == 1 ? 'mono' : 'stereo';
    final encodingLabel = encoding == 1 ? 'PCM' : 'IEEE float';
    final durationLabel = durationMs >= 1000
        ? '${(durationMs / 1000).toStringAsFixed(2)} s'
        : '${durationMs.toStringAsFixed(1)} ms';

    return AssetInspection(
      kind: RigAssetKind.cabinetIr,
      extension: extension,
      validation: RigAssetValidation.validated,
      formatSummary:
          'WAV $encodingLabel · $channelLabel · ${validSampleRate} Hz · $validBitDepth-bit · $durationLabel',
      suggestedTitle: suggestedTitle,
      sampleRateHz: validSampleRate,
      channelCount: validChannels,
      bitDepth: validBitDepth,
    );
  }
}
