import 'dart:ffi';

@Native<Uint32 Function()>()
external int rg_engine_abi_version();

@Native<Pointer<Void> Function(Uint32, Uint32)>()
external Pointer<Void> rg_engine_create(int sampleRate, int channels);

@Native<Void Function(Pointer<Void>)>()
external void rg_engine_destroy(Pointer<Void> handle);

@Native<Int32 Function(Pointer<Void>, Int32, Int32, Int32)>()
external int rg_engine_add_node(
  Pointer<Void> handle,
  int nodeType,
  int mode,
  int enabled,
);

@Native<Int32 Function(Pointer<Void>, Uint32, Uint32, Float)>()
external int rg_engine_set_parameter(
  Pointer<Void> handle,
  int nodeIndex,
  int parameterIndex,
  double value,
);

@Native<Int32 Function(Pointer<Void>, Uint32, Pointer<Float>, Uint32)>()
external int rg_engine_set_cabinet_ir(
  Pointer<Void> handle,
  int nodeIndex,
  Pointer<Float> samples,
  int sampleCount,
);

@Native<Int32 Function(Pointer<Void>, Pointer<Float>, Uint32)>()
external int rg_engine_process(
  Pointer<Void> handle,
  Pointer<Float> interleaved,
  int frameCount,
);

@Native<Int32 Function(Pointer<Void>, Float, Uint32)>()
external int rg_engine_run_test_tone(
  Pointer<Void> handle,
  double frequencyHz,
  int durationMs,
);

@Native<Double Function(Pointer<Void>)>()
external double rg_engine_input_rms_db(Pointer<Void> handle);

@Native<Double Function(Pointer<Void>)>()
external double rg_engine_output_rms_db(Pointer<Void> handle);

@Native<Double Function(Pointer<Void>)>()
external double rg_engine_input_peak_db(Pointer<Void> handle);

@Native<Double Function(Pointer<Void>)>()
external double rg_engine_output_peak_db(Pointer<Void> handle);

@Native<Uint32 Function(Pointer<Void>)>()
external int rg_engine_processed_frames(Pointer<Void> handle);

@Native<Uint32 Function(Pointer<Void>)>()
external int rg_engine_enabled_node_count(Pointer<Void> handle);
