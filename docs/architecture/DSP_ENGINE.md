# RigCanvas shared DSP engine — milestone 5.1

## Purpose

RigCanvas now has one native C++ DSP implementation compiled for Android and Windows through a local package_ffi-style dependency at app/packages/rigcanvas_dsp, using Flutter's native-assets build hook. The Flutter UI and preset format stay shared; only compilation targets differ. Dart calls the C ABI through dart:ffi.

The current milestone is an **offline processing foundation**, not a real-time guitar processor.

## Implemented

- Native engine lifecycle, ABI version, and bounded four-family processing graph (maximum 32 nodes).
- Linked-stereo dynamics detector with gate and compressor modes.
- Soft-clipping overdrive with gain, tone, level, and blend controls.
- Generic amplifier preamp saturation with low, mid, high, presence, and master shaping.
- Cabinet FIR convolution accepting a copied mono float impulse response of up to 4096 taps.
- Offline interleaved float-buffer processing and an internally generated 440 Hz test tone.
- Input/output RMS and peak measurements, processed frame count, and active node count.
- Grid preset traversal in row/slot order. Enabled Dynamics, Drive, Amplifier, and Cabinet blocks are translated to the current native graph. Other families are explicitly reported as not implemented.

## Important DSP and model limitations

The algorithms in this milestone are original, generic RigCanvas prototypes. They are not copies of KPT Pro firmware, Fractal, Neural DSP, Line 6, or Kemper algorithms. A KPT Pro Factory catalog choice currently selects only a catalog identity and generic family processing; it does not reproduce the physical pedal's named model or parameter mappings.

The existing effect editor has generic parameter names and ranges. Those values are normalized and mapped into the native prototype controls. They are not verified KPT Pro parameter scales, and they should not be described as exact hardware settings.

Cabinet convolution is available when mono float samples are supplied to the native API. The Asset Library's WAV inspector does not yet decode imported WAV samples into a DSP-ready buffer; an assigned CAB IR therefore is not automatically active in playback. Until that decoder is implemented and tested, the Workspace test keeps a cabinet node transparent except for its output-level control. Stereo IR handling and resampling are not implemented.

Imported NAM files are not loaded into an amp-capture runtime. AM2/AMP remain unverified. The amplifier node is a generic saturation and tone-shaping stage, not NAM execution and not a model-specific amp simulation.

## Offline test behavior

The Audio page generates a 440 Hz sine signal internally at 48 kHz, stereo, for 250 ms. It traverses the active preset's Grid order and processes the supported enabled blocks. It reports dBFS and frame metrics.

The test tone is not captured from a physical guitar, microphone, audio interface, or KPT Pro. The output is not routed to speakers or headphones. It is only an internal processing verification.

## Not implemented yet

- Low-latency real-time audio I/O or device selection.
- Android AAudio / Windows WASAPI capture and playback adapters.
- Monitoring, input/output gain staging, callback scheduling, underrun reporting, and audio-thread safety.
- Imported WAV decoding, IR normalization/resampling, stereo IRs, and automatic asset loading.
- NAM/AM2 amp-capture runtime.
- Modulation, delay, reverb, EQ, pitch, expression, splits, parallel graph routing, sidechain, and tail management.
- KPT Pro device discovery, protocol mapping, preset transfer, and hardware control.

## Safety and validation gates

1. Keep offline buffer processing separate from the future real-time callback path; no allocation or UI work may run in the audio callback.
2. Add deterministic impulse, frequency-response, clipping, and parameter-boundary tests before treating any algorithm as production-ready.
3. Decode WAV explicitly, validate RIFF chunks and data size, convert PCM/float samples safely, and resample only with a tested implementation.
4. Introduce OS audio I/O only behind the same cross-platform stream/device contract, then verify latency and stability independently on Android and Windows.
5. Do not infer KPT Pro device compatibility from this software DSP engine or from generic catalog categories.
