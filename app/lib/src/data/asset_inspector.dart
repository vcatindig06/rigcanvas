import 'dart:convert';
import 'dart:typed_data';

import '../audio/wav_ir_decoder.dart';
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
    final info = WavIrDecoder.inspect(bytes);
    final durationMs = info.frameCount * 1000 / info.sampleRateHz;
    final durationLabel = durationMs >= 1000
        ? '${(durationMs / 1000).toStringAsFixed(2)} s'
        : '${durationMs.toStringAsFixed(1)} ms';
    return AssetInspection(
      kind: RigAssetKind.cabinetIr,
      extension: extension,
      validation: RigAssetValidation.validated,
      formatSummary:
          'WAV ${info.encodingLabel} · ${info.channelLabel} · ${info.sampleRateHz} Hz · ${info.bitDepth}-bit · $durationLabel',
      suggestedTitle: suggestedTitle,
      sampleRateHz: info.sampleRateHz,
      channelCount: info.channels,
      bitDepth: info.bitDepth,
    );
  }
}
