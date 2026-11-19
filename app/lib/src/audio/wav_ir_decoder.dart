import 'dart:math' as math;
import 'dart:typed_data';

const int maximumCabinetIrFrames = 4096;

class WavIrFileInfo {
  const WavIrFileInfo({
    required this.encoding,
    required this.channels,
    required this.sampleRateHz,
    required this.bitDepth,
    required this.blockAlign,
    required this.byteRate,
    required this.dataOffset,
    required this.dataLength,
    required this.frameCount,
  });

  /// 1 = integer PCM, 3 = IEEE floating point.
  final int encoding;
  final int channels;
  final int sampleRateHz;
  final int bitDepth;
  final int blockAlign;
  final int byteRate;
  final int dataOffset;
  final int dataLength;
  final int frameCount;

  String get encodingLabel => encoding == 1 ? 'PCM' : 'IEEE float';
  String get channelLabel => channels == 1 ? 'mono' : 'stereo';
}

/// Validates and decodes PCM/IEEE-float RIFF/WAVE cabinet impulse responses.
class WavIrDecoder {
  WavIrDecoder._();

  static WavIrFileInfo inspect(Uint8List bytes) {
    if (bytes.length < 44) {
      throw const FormatException('WAV file is too short to contain a valid header.');
    }
    final data = ByteData.sublistView(bytes);
    String fourCc(int offset) =>
        String.fromCharCodes(bytes.sublist(offset, offset + 4));
    if (fourCc(0) != 'RIFF' || fourCc(8) != 'WAVE') {
      throw const FormatException('File does not contain a RIFF/WAVE header.');
    }

    final riffEnd = data.getUint32(4, Endian.little) + 8;
    if (riffEnd < 44 || riffEnd > bytes.length) {
      throw const FormatException('WAV RIFF length is invalid or truncated.');
    }

    int? encoding;
    int? channels;
    int? sampleRate;
    int? blockAlign;
    int? byteRate;
    int? bitDepth;
    int? dataOffset;
    int? dataLength;
    var offset = 12;

    while (offset + 8 <= riffEnd) {
      final chunkId = fourCc(offset);
      final chunkLength = data.getUint32(offset + 4, Endian.little);
      final chunkStart = offset + 8;
      final chunkEnd = chunkStart + chunkLength;
      if (chunkEnd < chunkStart || chunkEnd > riffEnd) {
        throw const FormatException('WAV contains a truncated or invalid chunk.');
      }

      if (chunkId == 'fmt ') {
        if (encoding != null || chunkLength < 16) {
          throw const FormatException('WAV format chunk is missing, duplicated, or incomplete.');
        }
        var format = data.getUint16(chunkStart, Endian.little);
        channels = data.getUint16(chunkStart + 2, Endian.little);
        sampleRate = data.getUint32(chunkStart + 4, Endian.little);
        byteRate = data.getUint32(chunkStart + 8, Endian.little);
        blockAlign = data.getUint16(chunkStart + 12, Endian.little);
        bitDepth = data.getUint16(chunkStart + 14, Endian.little);

        if (format == 0xFFFE) {
          if (chunkLength < 40 ||
              data.getUint16(chunkStart + 16, Endian.little) < 22) {
            throw const FormatException('WAVEFORMATEXTENSIBLE format data is incomplete.');
          }
          final validBits = data.getUint16(chunkStart + 18, Endian.little);
          final subtype = data.getUint32(chunkStart + 24, Endian.little);
          const guidTail = <int>[
            0x00, 0x00, 0x10, 0x00, 0x80, 0x00,
            0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71,
          ];
          var guidMatches = true;
          for (var index = 0; index < guidTail.length; index++) {
            if (bytes[chunkStart + 28 + index] != guidTail[index]) {
              guidMatches = false;
              break;
            }
          }
          if (!guidMatches || (subtype != 1 && subtype != 3)) {
            throw const FormatException(
              'WAVEFORMATEXTENSIBLE must use the PCM or IEEE-float subtype.',
            );
          }
          if (validBits != bitDepth) {
            throw const FormatException(
              'WAVEFORMATEXTENSIBLE valid bits must match the container bit depth.',
            );
          }
          format = subtype;
        }
        if (format != 1 && format != 3) {
          throw const FormatException('WAV encoding must be PCM or IEEE floating point.');
        }
        encoding = format;
      } else if (chunkId == 'data') {
        if (dataOffset != null) {
          throw const FormatException('WAV contains multiple audio data chunks.');
        }
        dataOffset = chunkStart;
        dataLength = chunkLength;
      }

      final paddedEnd = chunkEnd + (chunkLength.isOdd ? 1 : 0);
      if (paddedEnd > riffEnd) {
        throw const FormatException('WAV chunk padding is truncated.');
      }
      offset = paddedEnd;
    }

    if (encoding == null ||
        channels == null ||
        sampleRate == null ||
        blockAlign == null ||
        byteRate == null ||
        bitDepth == null ||
        dataOffset == null ||
        dataLength == null) {
      throw const FormatException('WAV must contain valid format and audio data chunks.');
    }
    if (channels < 1 || channels > 2) {
      throw const FormatException('Cabinet IR WAV files must be mono or stereo.');
    }
    if (sampleRate < 8000 || sampleRate > 192000) {
      throw const FormatException('WAV sample rate must be between 8 and 192 kHz.');
    }
    final validDepth = encoding == 1
        ? const <int>{8, 16, 24, 32}.contains(bitDepth)
        : const <int>{32, 64}.contains(bitDepth);
    if (!validDepth) {
      throw const FormatException('WAV bit depth is not supported for its encoding.');
    }

    final expectedBlockAlign = channels * (bitDepth ~/ 8);
    final expectedByteRate = sampleRate * expectedBlockAlign;
    if (blockAlign != expectedBlockAlign ||
        byteRate != expectedByteRate ||
        dataLength <= 0 ||
        dataLength % blockAlign != 0 ||
        dataOffset + dataLength > riffEnd) {
      throw const FormatException('WAV byte rate, block alignment, or audio data length is invalid.');
    }

    return WavIrFileInfo(
      encoding: encoding,
      channels: channels,
      sampleRateHz: sampleRate,
      bitDepth: bitDepth,
      blockAlign: blockAlign,
      byteRate: byteRate,
      dataOffset: dataOffset,
      dataLength: dataLength,
      frameCount: dataLength ~/ blockAlign,
    );
  }

  static DecodedWavIr decode(
    Uint8List bytes, {
    int targetSampleRateHz = 48000,
    int maximumFrames = maximumCabinetIrFrames,
  }) {
    if (targetSampleRateHz < 8000 || targetSampleRateHz > 192000) {
      throw ArgumentError.value(
        targetSampleRateHz,
        'targetSampleRateHz',
        'Target sample rate must be between 8 and 192 kHz.',
      );
    }
    if (maximumFrames < 1 || maximumFrames > 65536) {
      throw ArgumentError.value(maximumFrames, 'maximumFrames');
    }

    final info = inspect(bytes);
    final view = ByteData.sublistView(bytes);
    final resampledFrames = math.max(
      1,
      (info.frameCount * targetSampleRateHz / info.sampleRateHz).round(),
    );
    final framesUsed = math.min(resampledFrames, maximumFrames);
    final output = Float32List(framesUsed * info.channels);
    final bytesPerSample = info.bitDepth ~/ 8;

    double readSample(int frame, int channel) {
      final sampleOffset = info.dataOffset +
          frame * info.blockAlign +
          channel * bytesPerSample;
      if (info.encoding == 1) {
        switch (info.bitDepth) {
          case 8:
            return (view.getUint8(sampleOffset) - 128) / 128.0;
          case 16:
            return view.getInt16(sampleOffset, Endian.little) / 32768.0;
          case 24:
            var value = view.getUint8(sampleOffset) |
                (view.getUint8(sampleOffset + 1) << 8) |
                (view.getUint8(sampleOffset + 2) << 16);
            if ((value & 0x800000) != 0) value -= 0x1000000;
            return value / 8388608.0;
          case 32:
            return view.getInt32(sampleOffset, Endian.little) / 2147483648.0;
          default:
            throw const FormatException('Unsupported PCM bit depth.');
        }
      }

      final value = info.bitDepth == 32
          ? view.getFloat32(sampleOffset, Endian.little).toDouble()
          : view.getFloat64(sampleOffset, Endian.little);
      if (!value.isFinite) {
        throw const FormatException('WAV floating-point samples must be finite.');
      }
      return value.clamp(-1.0, 1.0).toDouble();
    }

    for (var frame = 0; frame < framesUsed; frame++) {
      final sourcePosition =
          frame * info.sampleRateHz / targetSampleRateHz;
      final firstFrame = sourcePosition.floor().clamp(0, info.frameCount - 1);
      final secondFrame = math.min(firstFrame + 1, info.frameCount - 1);
      final fraction = sourcePosition - firstFrame;
      for (var channel = 0; channel < info.channels; channel++) {
        final first = readSample(firstFrame, channel);
        final second = readSample(secondFrame, channel);
        output[frame * info.channels + channel] =
            (first + (second - first) * fraction)
                .clamp(-1.0, 1.0)
                .toDouble();
      }
    }

    return DecodedWavIr(
      samplesInterleaved: output,
      channelCount: info.channels,
      sampleRateHz: targetSampleRateHz,
      sourceSampleRateHz: info.sampleRateHz,
      sourceFrameCount: info.frameCount,
      resampledFrameCount: resampledFrames,
      framesUsed: framesUsed,
      wasResampled: info.sampleRateHz != targetSampleRateHz,
      wasTrimmed: resampledFrames > framesUsed,
    );
  }
}

class DecodedWavIr {
  const DecodedWavIr({
    required this.samplesInterleaved,
    required this.channelCount,
    required this.sampleRateHz,
    required this.sourceSampleRateHz,
    required this.sourceFrameCount,
    required this.resampledFrameCount,
    required this.framesUsed,
    required this.wasResampled,
    required this.wasTrimmed,
  });

  final Float32List samplesInterleaved;
  final int channelCount;
  final int sampleRateHz;
  final int sourceSampleRateHz;
  final int sourceFrameCount;
  final int resampledFrameCount;
  final int framesUsed;
  final bool wasResampled;
  final bool wasTrimmed;
}
