import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/audio/wav_ir_decoder.dart';

void main() {
  group('WAV cabinet IR decoder', () {
    test('decodes signed 24-bit PCM samples', () {
      final wav = _pcm24Wav(
        channels: 1,
        sampleRate: 48000,
        samples: [-8388608, 0, 4194304, 8388607],
      );

      final decoded = WavIrDecoder.decode(wav);

      expect(decoded.channelCount, 1);
      expect(decoded.sampleRateHz, 48000);
      expect(decoded.framesUsed, 4);
      expect(decoded.wasResampled, isFalse);
      expect(decoded.wasTrimmed, isFalse);
      expect(decoded.samplesInterleaved[0], -1.0);
      expect(decoded.samplesInterleaved[1], 0.0);
      expect(decoded.samplesInterleaved[2], closeTo(0.5, 0.000001));
      expect(decoded.samplesInterleaved[3], closeTo(1.0, 0.000001));
    });

    test('preserves left and right samples in stereo PCM', () {
      final wav = _pcm16Wav(
        channels: 2,
        sampleRate: 48000,
        samples: [-16384, 8192, 16384, -8192],
      );

      final decoded = WavIrDecoder.decode(wav);

      expect(decoded.channelCount, 2);
      expect(decoded.samplesInterleaved, hasLength(4));
      expect(decoded.samplesInterleaved[0], -0.5);
      expect(decoded.samplesInterleaved[1], 0.25);
      expect(decoded.samplesInterleaved[2], 0.5);
      expect(decoded.samplesInterleaved[3], -0.25);
    });

    test('resamples 96 kHz mono IR to the requested 48 kHz rate', () {
      final wav = _pcm16Wav(
        channels: 1,
        sampleRate: 96000,
        samples: List<int>.generate(8, (index) => index * 2000 - 7000),
      );

      final decoded = WavIrDecoder.decode(
        wav,
        targetSampleRateHz: 48000,
      );

      expect(decoded.sourceSampleRateHz, 96000);
      expect(decoded.sampleRateHz, 48000);
      expect(decoded.sourceFrameCount, 8);
      expect(decoded.resampledFrameCount, 4);
      expect(decoded.framesUsed, 4);
      expect(decoded.wasResampled, isTrue);
      expect(decoded.wasTrimmed, isFalse);
    });

    test('caps a long response at the configured maximum frames', () {
      final wav = _pcm16Wav(
        channels: 1,
        sampleRate: 48000,
        samples: List<int>.filled(5000, 5000),
      );

      final decoded = WavIrDecoder.decode(wav);

      expect(decoded.sourceFrameCount, 5000);
      expect(decoded.resampledFrameCount, 5000);
      expect(decoded.framesUsed, maximumCabinetIrFrames);
      expect(decoded.samplesInterleaved, hasLength(maximumCabinetIrFrames));
      expect(decoded.wasTrimmed, isTrue);
    });

    test('rejects non-finite IEEE float samples', () {
      final wav = _float32Wav(
        channels: 1,
        sampleRate: 48000,
        samples: [0.25, double.nan],
      );

      expect(() => WavIrDecoder.decode(wav), throwsFormatException);
    });

    test('rejects inconsistent byte rate and malformed RIFF data', () {
      final valid = _pcm16Wav(
        channels: 1,
        sampleRate: 48000,
        samples: [0, 1000],
      );
      final badByteRate = Uint8List.fromList(valid);
      ByteData.sublistView(badByteRate).setUint32(28, 1234, Endian.little);

      expect(() => WavIrDecoder.inspect(badByteRate), throwsFormatException);
      expect(
        () => WavIrDecoder.inspect(Uint8List.fromList([1, 2, 3, 4])),
        throwsFormatException,
      );
    });
  });
}

Uint8List _pcm16Wav({
  required int channels,
  required int sampleRate,
  required List<int> samples,
}) {
  final bytesPerSample = 2;
  final blockAlign = channels * bytesPerSample;
  final dataLength = samples.length * bytesPerSample;
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.sublistView(bytes);
  _writeText(bytes, 0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  _writeText(bytes, 8, 'WAVE');
  _writeFormat(data, bytes, channels, sampleRate, blockAlign, 16, 1, dataLength);
  for (var index = 0; index < samples.length; index++) {
    data.setInt16(44 + index * 2, samples[index], Endian.little);
  }
  return bytes;
}

Uint8List _pcm24Wav({
  required int channels,
  required int sampleRate,
  required List<int> samples,
}) {
  const bytesPerSample = 3;
  final blockAlign = channels * bytesPerSample;
  final dataLength = samples.length * bytesPerSample;
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.sublistView(bytes);
  _writeText(bytes, 0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  _writeText(bytes, 8, 'WAVE');
  _writeFormat(data, bytes, channels, sampleRate, blockAlign, 24, 1, dataLength);
  for (var index = 0; index < samples.length; index++) {
    final value = samples[index] & 0xFFFFFF;
    final offset = 44 + index * 3;
    bytes[offset] = value & 0xFF;
    bytes[offset + 1] = (value >> 8) & 0xFF;
    bytes[offset + 2] = (value >> 16) & 0xFF;
  }
  return bytes;
}

Uint8List _float32Wav({
  required int channels,
  required int sampleRate,
  required List<double> samples,
}) {
  const bytesPerSample = 4;
  final blockAlign = channels * bytesPerSample;
  final dataLength = samples.length * bytesPerSample;
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.sublistView(bytes);
  _writeText(bytes, 0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  _writeText(bytes, 8, 'WAVE');
  _writeFormat(data, bytes, channels, sampleRate, blockAlign, 32, 3, dataLength);
  for (var index = 0; index < samples.length; index++) {
    data.setFloat32(44 + index * 4, samples[index], Endian.little);
  }
  return bytes;
}

void _writeFormat(
  ByteData data,
  Uint8List bytes,
  int channels,
  int sampleRate,
  int blockAlign,
  int bitDepth,
  int encoding,
  int dataLength,
) {
  _writeText(bytes, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, encoding, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * blockAlign, Endian.little);
  data.setUint16(32, blockAlign, Endian.little);
  data.setUint16(34, bitDepth, Endian.little);
  _writeText(bytes, 36, 'data');
  data.setUint32(40, dataLength, Endian.little);
}

void _writeText(Uint8List bytes, int offset, String value) {
  for (var index = 0; index < value.length; index++) {
    bytes[offset + index] = value.codeUnitAt(index);
  }
}
