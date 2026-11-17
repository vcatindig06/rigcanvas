import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:rigcanvas_dsp/rigcanvas_dsp.dart' as native;

enum DspNodeType {
  dynamics(1), drive(2), amplifier(3), cabinet(4),
  modulation(5), delay(6), reverb(7), equalizer(8);
  const DspNodeType(this.nativeValue);
  final int nativeValue;
}
enum DspDynamicsMode {
  gate(0), compressor(1);
  const DspDynamicsMode(this.nativeValue);
  final int nativeValue;
}
enum DspModulationMode {
  chorus(0), tremolo(1), flanger(2), vibrato(3);
  const DspModulationMode(this.nativeValue);
  final int nativeValue;
}
enum DspDelayMode {
  standard(0), pingPong(1);
  const DspDelayMode(this.nativeValue);
  final int nativeValue;
}

class DspProcessMetrics {
  const DspProcessMetrics({
    required this.sampleRate,
    required this.channels,
    required this.processedFrames,
    required this.enabledNodeCount,
    required this.inputRmsDb,
    required this.outputRmsDb,
    required this.inputPeakDb,
    required this.outputPeakDb,
  });
  final int sampleRate;
  final int channels;
  final int processedFrames;
  final int enabledNodeCount;
  final double inputRmsDb;
  final double outputRmsDb;
  final double inputPeakDb;
  final double outputPeakDb;
  int get durationMilliseconds => (processedFrames * 1000 / sampleRate).round();
}

/// Owns one offline native processing graph shared by Android and Windows.
class RigCanvasDspEngine {
  RigCanvasDspEngine({this.sampleRate = 48000, this.channels = 2})
    : _handle = native.rgEngineCreate(sampleRate, channels) {
    if (_handle == nullptr) {
      throw ArgumentError('Unsupported DSP engine format: $sampleRate Hz, $channels channels.');
    }
    if (native.rgEngineAbiVersion() != 3) {
      native.rgEngineDestroy(_handle);
      _handle = nullptr;
      throw StateError('RigCanvas DSP native API version mismatch.');
    }
  }

  final int sampleRate;
  final int channels;
  Pointer<Void> _handle;

  int addNode(
    DspNodeType type, {
    DspDynamicsMode dynamicsMode = DspDynamicsMode.compressor,
    DspModulationMode modulationMode = DspModulationMode.chorus,
    DspDelayMode delayMode = DspDelayMode.standard,
    bool enabled = true,
  }) {
    _ensureAlive();
    final mode = switch (type) {
      DspNodeType.dynamics => dynamicsMode.nativeValue,
      DspNodeType.modulation => modulationMode.nativeValue,
      DspNodeType.delay => delayMode.nativeValue,
      _ => 0,
    };
    final result = native.rgEngineAddNode(_handle, type.nativeValue, mode, enabled ? 1 : 0);
    if (result < 0) {
      throw StateError('Native DSP could not add the selected block ($result).');
    }
    return result;
  }

  void setParameter(int nodeIndex, int parameterIndex, double value) {
    _ensureAlive();
    if (!value.isFinite) throw ArgumentError.value(value, 'value', 'Must be finite.');
    final result = native.rgEngineSetParameter(_handle, nodeIndex, parameterIndex, value);
    if (result != 0) {
      throw ArgumentError('Native DSP rejected parameter $parameterIndex for block $nodeIndex ($result).');
    }
  }

  /// Reads the current value held by the native DSP node.
  double getParameter(int nodeIndex, int parameterIndex) {
    _ensureAlive();
    final value = native.rgEngineGetParameter(_handle, nodeIndex, parameterIndex);
    if (!value.isFinite) {
      throw RangeError('Native DSP has no parameter $parameterIndex on block $nodeIndex.');
    }
    return value;
  }

  int get nodeCount {
    _ensureAlive();
    return native.rgEngineNodeCount(_handle);
  }

  DspNodeType nodeTypeAt(int nodeIndex) {
    _ensureAlive();
    final nativeType = native.rgEngineGetNodeType(_handle, nodeIndex);
    return DspNodeType.values.firstWhere(
      (type) => type.nativeValue == nativeType,
      orElse: () => throw RangeError('Invalid DSP node index $nodeIndex.'),
    );
  }

  bool isNodeEnabled(int nodeIndex) {
    _ensureAlive();
    final result = native.rgEngineGetNodeEnabled(_handle, nodeIndex);
    if (result < 0) throw RangeError('Invalid DSP node index $nodeIndex.');
    return result == 1;
  }

  void setNodeEnabled(int nodeIndex, bool enabled) {
    _ensureAlive();
    final result = native.rgEngineSetNodeEnabled(_handle, nodeIndex, enabled ? 1 : 0);
    if (result != 0) {
      throw RangeError('Native DSP could not change bypass state for block $nodeIndex ($result).');
    }
  }

  void moveNode(int fromIndex, int toIndex) {
    _ensureAlive();
    final result = native.rgEngineMoveNode(_handle, fromIndex, toIndex);
    if (result != 0) {
      throw RangeError('Native DSP could not move block $fromIndex to $toIndex ($result).');
    }
  }

  void removeNode(int nodeIndex) {
    _ensureAlive();
    final result = native.rgEngineRemoveNode(_handle, nodeIndex);
    if (result != 0) {
      throw RangeError('Native DSP could not remove block $nodeIndex ($result).');
    }
  }

  /// Copies mono or stereo interleaved IR samples into native memory.
  void setCabinetImpulseResponse(
    int nodeIndex,
    Float32List samplesInterleaved, {
    int irChannels = 1,
  }) {
    _ensureAlive();
    if (irChannels < 1 || irChannels > 2 ||
        (irChannels == 2 && channels != 2) ||
        samplesInterleaved.isEmpty ||
        samplesInterleaved.length % irChannels != 0) {
      throw ArgumentError('Cabinet IR must contain complete mono or stereo frames.');
    }
    final frameCount = samplesInterleaved.length ~/ irChannels;
    if (frameCount > 4096) {
      throw ArgumentError.value(frameCount, 'frameCount', 'IRs are limited to 4096 frames per channel.');
    }
    if (samplesInterleaved.any((sample) => !sample.isFinite)) {
      throw ArgumentError('Impulse response samples must be finite.');
    }
    final pointer = calloc<Float>(samplesInterleaved.length);
    try {
      pointer.asTypedList(samplesInterleaved.length).setAll(0, samplesInterleaved);
      final result = native.rgEngineSetCabinetIr(
        _handle, nodeIndex, pointer, frameCount, irChannels,
      );
      if (result != 0) throw ArgumentError('Native DSP rejected the cabinet IR ($result).');
    } finally {
      calloc.free(pointer);
    }
  }

  /// Processes interleaved float audio offline; this is not live device I/O.
  Float32List processInterleaved(Float32List samples) {
    _ensureAlive();
    if (samples.isEmpty || samples.length % channels != 0) {
      throw ArgumentError('Audio data must contain complete frames for $channels channels.');
    }
    final frameCount = samples.length ~/ channels;
    if (frameCount > sampleRate * 2) {
      throw ArgumentError('A processing block cannot exceed two seconds.');
    }
    final pointer = calloc<Float>(samples.length);
    try {
      pointer.asTypedList(samples.length).setAll(0, samples);
      final result = native.rgEngineProcess(_handle, pointer, frameCount);
      if (result != 0) throw StateError('Native DSP processing failed ($result).');
      return Float32List.fromList(pointer.asTypedList(samples.length));
    } finally {
      calloc.free(pointer);
    }
  }

  DspProcessMetrics runTestTone({
    double frequencyHz = 440,
    int durationMilliseconds = 250,
  }) {
    _ensureAlive();
    final result = native.rgEngineRunTestTone(_handle, frequencyHz, durationMilliseconds);
    if (result != 0) throw ArgumentError('Native DSP test signal failed ($result).');
    return DspProcessMetrics(
      sampleRate: sampleRate,
      channels: channels,
      processedFrames: native.rgEngineProcessedFrames(_handle),
      enabledNodeCount: native.rgEngineEnabledNodeCount(_handle),
      inputRmsDb: native.rgEngineInputRmsDb(_handle),
      outputRmsDb: native.rgEngineOutputRmsDb(_handle),
      inputPeakDb: native.rgEngineInputPeakDb(_handle),
      outputPeakDb: native.rgEngineOutputPeakDb(_handle),
    );
  }

  void dispose() {
    if (_handle == nullptr) return;
    native.rgEngineDestroy(_handle);
    _handle = nullptr;
  }

  void _ensureAlive() {
    if (_handle == nullptr) throw StateError('The RigCanvas DSP engine has been disposed.');
  }
}
