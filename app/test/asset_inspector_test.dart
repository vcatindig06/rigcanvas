import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/data/asset_inspector.dart';
import 'package:rigcanvas/src/models/rig_asset.dart';

void main() {
  test('validates a NAM JSON envelope and reads available metadata', () {
    final source = jsonEncode({
      'version': '0.5.4',
      'architecture': 'WaveNet',
      'config': <String, Object?>{},
      'weights': [0.1, -0.2, 0.3],
      'sample_rate': 48000,
      'metadata': {
        'name': 'Deluxe Clean',
        'gear_make': 'Fender',
        'gear_model': 'Deluxe Reverb',
      },
    });

    final result = AssetInspector.inspect(
      kind: RigAssetKind.ampCapture,
      filename: 'deluxe.nam',
      bytes: Uint8List.fromList(utf8.encode(source)),
    );

    expect(result.validation, RigAssetValidation.validated);
    expect(result.suggestedTitle, 'Deluxe Clean');
    expect(result.manufacturer, 'Fender');
    expect(result.model, 'Deluxe Reverb');
    expect(result.sampleRateHz, 48000);
    expect(result.formatSummary, contains('WaveNet'));
  });

  test('stores AM2 captures as unverified rather than claiming compatibility', () {
    final result = AssetInspector.inspect(
      kind: RigAssetKind.ampCapture,
      filename: 'custom-capture.am2',
      bytes: Uint8List.fromList([0x01, 0x02, 0x03, 0x04]),
    );

    expect(result.validation, RigAssetValidation.unverified);
    expect(result.formatSummary, contains('not verified'));
  });

  test('validates WAV cabinet IR header and technical metadata', () {
    final result = AssetInspector.inspect(
      kind: RigAssetKind.cabinetIr,
      filename: 'v30.wav',
      bytes: _wavBytes(),
    );

    expect(result.validation, RigAssetValidation.validated);
    expect(result.sampleRateHz, 48000);
    expect(result.channelCount, 1);
    expect(result.bitDepth, 24);
    expect(result.formatSummary, contains('PCM'));
    expect(result.formatSummary, contains('mono'));
  });

  test('rejects unsupported or malformed files', () {
    expect(
      () => AssetInspector.inspect(
        kind: RigAssetKind.ampCapture,
        filename: 'model.wav',
        bytes: _wavBytes(),
      ),
      throwsFormatException,
    );
    expect(
      () => AssetInspector.inspect(
        kind: RigAssetKind.cabinetIr,
        filename: 'broken.wav',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
      throwsFormatException,
    );
    expect(
      () => AssetInspector.inspect(
        kind: RigAssetKind.ampCapture,
        filename: 'invalid.nam',
        bytes: Uint8List.fromList(utf8.encode('{"architecture":"WaveNet"}')),
      ),
      throwsFormatException,
    );
  });
}

Uint8List _wavBytes() {
  const channels = 1;
  const sampleRate = 48000;
  const bitDepth = 24;
  const dataLength = 12;
  const blockAlign = channels * (bitDepth ~/ 8);
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.sublistView(bytes);
  void writeText(int offset, String value) {
    bytes.setRange(offset, offset + value.length, ascii.encode(value));
  }

  writeText(0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  writeText(8, 'WAVE');
  writeText(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * blockAlign, Endian.little);
  data.setUint16(32, blockAlign, Endian.little);
  data.setUint16(34, bitDepth, Endian.little);
  writeText(36, 'data');
  data.setUint32(40, dataLength, Endian.little);
  return bytes;
}
