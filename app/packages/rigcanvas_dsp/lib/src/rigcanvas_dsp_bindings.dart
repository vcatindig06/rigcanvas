import 'dart:ffi';

@Native<Uint32 Function()>(symbol: 'rg_engine_abi_version')
external int rgEngineAbiVersion();

@Native<Pointer<Void> Function(Uint32, Uint32)>(symbol: 'rg_engine_create')
external Pointer<Void> rgEngineCreate(int sampleRate, int channels);

@Native<Void Function(Pointer<Void>)>(symbol: 'rg_engine_destroy')
external void rgEngineDestroy(Pointer<Void> handle);

@Native<Int32 Function(Pointer<Void>, Int32, Int32, Int32)>(symbol: 'rg_engine_add_node')
external int rgEngineAddNode(
  Pointer<Void> handle,
  int nodeType,
  int mode,
  int enabled,
);

@Native<Int32 Function(Pointer<Void>, Uint32, Uint32, Float)>(symbol: 'rg_engine_set_parameter')
external int rgEngineSetParameter(
  Pointer<Void> handle,
  int nodeIndex,
  int parameterIndex,
  double value,
);

@Native<Int32 Function(Pointer<Void>, Uint32, Pointer<Float>, Uint32)>(symbol: 'rg_engine_set_cabinet_ir')
external int rgEngineSetCabinetIr(
  Pointer<Void> handle,
  int nodeIndex,
  Pointer<Float> samples,
  int sampleCount,
);

@Native<Int32 Function(Pointer<Void>, Pointer<Float>, Uint32)>(symbol: 'rg_engine_process')
external int rgEngineProcess(
  Pointer<Void> handle,
  Pointer<Float> interleaved,
  int frameCount,
);

@Native<Int32 Function(Pointer<Void>, Float, Uint32)>(symbol: 'rg_engine_run_test_tone')
external int rgEngineRunTestTone(
  Pointer<Void> handle,
  double frequencyHz,
  int durationMs,
);

@Native<Double Function(Pointer<Void>)>(symbol: 'rg_engine_input_rms_db')
external double rgEngineInputRmsDb(Pointer<Void> handle);

@Native<Double Function(Pointer<Void>)>(symbol: 'rg_engine_output_rms_db')
external double rgEngineOutputRmsDb(Pointer<Void> handle);

@Native<Double Function(Pointer<Void>)>(symbol: 'rg_engine_input_peak_db')
external double rgEngineInputPeakDb(Pointer<Void> handle);

@Native<Double Function(Pointer<Void>)>(symbol: 'rg_engine_output_peak_db')
external double rgEngineOutputPeakDb(Pointer<Void> handle);

@Native<Uint32 Function(Pointer<Void>)>(symbol: 'rg_engine_processed_frames')
external int rgEngineProcessedFrames(Pointer<Void> handle);

@Native<Uint32 Function(Pointer<Void>)>(symbol: 'rg_engine_enabled_node_count')
external int rgEngineEnabledNodeCount(Pointer<Void> handle);
