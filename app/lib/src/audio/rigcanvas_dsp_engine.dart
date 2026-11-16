import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'rigcanvas_dsp_bindings.dart' as native;

enum DspNodeType {
  dynamics(1),
  drive(2),
  amplifier(3),
  cabinet(4);

  const DspNodeType(this.nativeValue);
  final int nativeValue;
}

enum DspDynamicsMode {
  gate(0),
  compressor(1);

  const DspDynamicsMode(this.nativeValue);
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

  int get durationMilliseconds =>
      (processedFrames * 1000 / sampleRate).round();
}

/// Owns one native processing graph. The same C++ implementation is compiled
/// for Android and Windows and called through Dart's native-asset FFI support.
class RigCanvasDspEngine {
  RigCanvasDspEngine({
    this.sampleRate = 48000,
    this.channels = 2,
  }) : _handle = native.rg_engine_create(sampleRate, channels) {
    if (_handle == nullptr) {
      throw ArgumentError(
        'Unsupported DSP engine format: $sampleRate Hz, $channels channels.',
      );
    }
    if (native.rg_engine_abi_version() != 1) {
      native.rg_engine_destroy(_handle);
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
    bool enabled = true,
  }) {
    _ensureAlive();
    final result = native.rg_engine_add_node(
      _handle,
      type.nativeValue,
      dynamicsMode.nativeValue,
      enabled ? 1 : 0,
    );
    if (result < 0) {
      throw StateError('Native DSP could not add the selected block ($result).');
    }
    return result;
  }

  void setParameter(int nodeIndex, int parameterIndex, double value) {
    _ensureAlive();
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'Must be finite.');
    }
    final result = native.rg_engine_set_parameter(
      _handle,
      nodeIndex,
      parameterIndex,
      value,
    );
    if (result != 0) {
      throw ArgumentError(
        'Native DSP rejected parameter $parameterIndex for block $nodeIndex ($result).',
      );
    }
  }

  /// Copies mono IR samples into native memory. The C++ engine owns its copy
  /// after this method returns.
  void setCabinetImpulseResponse(int nodeIndex, Float32List samples) {
    _ensureAlive();
    if (samples.isEmpty || samples.length > 4096) {
      throw ArgumentError.value(
        samples.length,
        'samples.length',
        'Impulse responses must contain 1–4096 samples.',
      );
    }
    if (samples.any((sample) => !sample.isFinite)) {
      throw ArgumentError('Impulse response samples must be finite.');
    }

    final pointer = calloc<Float>(samples.length);
    try {
      pointer.asTypedList(samples.length).setAll(0, samples);
      final result = native.rg_engine_set_cabinet_ir(
        _handle,
        nodeIndex,
        pointer,
        samples.length,
      );
      if (result != 0) {
        throw ArgumentError('Native DSP rejected the cabinet IR ($result).');
      }
    } finally {
      calloc.free(pointer);
    }
  }

  /// Offline block processing. The application does not yet connect this API
  /// to a microphone, guitar input, audio interface, or speaker output.
  Float32List processInterleaved(Float32List samples) {
    _ensureAlive();
    if (samples.isEmpty || samples.length % channels != 0) {
      throw ArgumentError(
        'Audio data must contain complete frames for $channels channels.',
      );
    }
    final frameCount = samples.length ~/ channels;
    if (frameCount > sampleRate * 2) {
      throw ArgumentError('A processing block cannot exceed two seconds.');
    }

    final pointer = calloc<Float>(samples.length);
    try {
      pointer.asTypedList(samples.length).setAll(0, samples);
      final result = native.rg_engine_process(_handle, pointer, frameCount);
      if (result != 0) {
        throw StateError('Native DSP processing failed ($result).');
      }
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
    final result = native.rg_engine_run_test_tone(
      _handle,
      frequencyHz,
      durationMilliseconds,
    );
    if (result != 0) {
      throw ArgumentError('Native DSP test signal failed ($result).');
    }
    return DspProcessMetrics(
      sampleRate: sampleRate,
      channels: channels,
      processedFrames: native.rg_engine_processed_frames(_handle),
      enabledNodeCount: native.rg_engine_enabled_node_count(_handle),
      inputRmsDb: native.rg_engine_input_rms_db(_handle),
      outputRmsDb: native.rg_engine_output_rms_db(_handle),
      inputPeakDb: native.rg_engine_input_peak_db(_handle),
      outputPeakDb: native.rg_engine_output_peak_db(_handle),
    );
  }

  void dispose() {
    if (_handle == nullptr) return;
    native.rg_engine_destroy(_handle);
    _handle = nullptr;
  }

  void _ensureAlive() {
    if (_handle == nullptr) {
      throw StateError('The RigCanvas DSP engine has been disposed.');
    }
  }
}
