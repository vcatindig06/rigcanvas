# RigCanvas shared DSP engine — offline DSP milestone 5.2

## Purpose and platform parity

RigCanvas uses one native C++17 DSP implementation, compiled through a local Flutter native-assets package and called from Dart FFI. Android and Windows use the same DSP graph, parameter mapping, WAV decoder, and preset traversal. Only the low-level build target differs.

This is still an **offline/block-processing prototype**, not a live guitar processor. The Audio page generates an internal test signal; no audio device is opened and no sound is sent to speakers or headphones.

## Implemented processing nodes

The version-2 native C ABI exposes a bounded graph of up to 32 ordered nodes:

- **Dynamics:** linked-stereo detector with generic noise-gate and compressor modes.
- **Drive:** soft-clipping overdrive with gain, tone, level, and blend.
- **Amplifier:** generic saturation with low, mid, high, presence, and master shaping.
- **Cabinet:** FIR convolution with a mono IR shared across outputs or an independent stereo IR. Low cut, high cut, level, and dry/wet mix are provided.
- **Modulation:** generic chorus / vibrato / flanger delay modulation and tremolo amplitude modulation.
- **Delay:** standard delay and stereo ping-pong modes, with time, feedback, high-cut, and mix.
- **Reverb:** a generic four-comb, damped room-style algorithm with decay, pre-delay, tone, and mix.
- **EQ:** a generic four-band low / low-mid / high-mid / high equalizer with output level.

The modulation implementation does not include phaser, wah/autofilter, Univibe, rotary, ring modulation, or pitch shifting. Specialized delay types such as reverse, ducking, tape, lo-fi, multi-tap, and granular are not implemented as their named algorithms. The generic reverb is not a spring, shimmer, cloud, swell, plate, or cathedral emulation. Unsupported catalog entries remain visibly skipped in the Audio page rather than being presented as completed algorithms.

## Cabinet WAV loading

The Asset Library stores the original imported file. When the Audio page tests a preset, it resolves the linked CAB asset ID, reads the stored file, and runs the same WAV decoder on both Android and Windows.

The WAV decoder:

- Validates RIFF/WAVE structure, chunk sizes and padding, format information, byte rate, block alignment, and data size.
- Supports little-endian integer PCM 8-, 16-, 24-, and 32-bit files.
- Supports little-endian IEEE-float 32- and 64-bit files.
- Supports WAVEFORMATEXTENSIBLE only for PCM and IEEE-float subtypes with valid/container bit depth matching.
- Accepts mono and stereo IRs only, with source sample rates from 8 kHz to 192 kHz.
- Converts samples to finite normalized float values, resamples to the engine's 48 kHz test rate, and retains stereo channels separately.
- Limits the loaded response to 4096 frames per channel. The Audio page reports when a file was resampled or truncated.

A mono IR is shared by the left and right processing channels. A stereo IR uses its left and right responses independently. Files with unsupported codecs, channels, sample rates, multiple data chunks, invalid lengths, or non-finite float data are rejected. RF64 and big-endian RIFX are not supported.

### Important quality and performance limits

The current resampler uses linear interpolation. It does not yet use a high-quality anti-aliasing filter, so it is suitable for this offline prototype but should not be treated as a production resampler.

Cabinet convolution is direct FIR convolution with a maximum of 4096 taps per channel. This can be computationally expensive for long responses. A production live-audio implementation should use profiled, allocation-free callback processing and an appropriate partitioned-convolution design rather than moving this offline code unchanged into an audio callback.

The original WAV file remains stored in the Asset Library; decoding creates a temporary DSP float buffer for the offline preset test. The application does not rewrite or replace the imported source file.

## Preset and parameter mapping

The Audio page traverses enabled blocks in Grid row/slot order. The preset's generic parameter metadata is mapped to the prototype node controls. These are not verified KPT Pro parameter scales or exact hardware settings.

KPT Pro Factory and RigCanvas Library entries remain catalog identities. The generic processors do not reproduce KPT Pro firmware, Fractal, Quad Cortex, Helix, or Kemper algorithms. A selected catalog name is not proof that the corresponding named effect has been modeled.

## Offline test behavior

The Audio page generates a 440 Hz sine wave internally at 48 kHz stereo for 500 ms, traverses the active preset's enabled supported blocks in Grid order, and displays input/output RMS, peak, frame count, and enabled node count. Linked CAB WAVs are decoded and loaded before the offline signal is processed. Unsupported block variants are listed separately.

The signal is not captured from a physical guitar, microphone, audio interface, or KPT Pro. It is not routed to speakers or headphones and does not provide live monitoring.

## Not implemented yet

- Low-latency real-time audio I/O or device selection.
- Android AAudio / Windows WASAPI capture and playback adapters.
- Monitoring, input/output gain staging, callback scheduling, underrun reporting, and audio-thread safety.
- NAM/AM2 amp-capture runtime.
- Model-specific KPT Pro, Fractal, Quad Cortex, Helix, or Kemper algorithms.
- Phaser, wah/autofilter, Univibe, rotary, pitch, expression, and specialized delay/reverb algorithms.
- Splitters, mixers, parallel graph routing, sidechain, and tail management.
- KPT Pro device discovery, protocol mapping, preset transfer, and hardware control.

## Safety and validation gates

1. Keep offline buffer processing separate from the future real-time callback path; no allocation, file I/O, or UI work may run in the audio callback.
2. Add deterministic impulse-response and frequency-response tests, clipping/noise measurements, parameter-boundary tests, and performance benchmarks.
3. Upgrade the resampler and convolution implementation only with reference tests and cross-platform profiling.
4. Introduce OS audio I/O behind the same cross-platform stream/device contract, then verify latency and stability independently on Android and Windows.
5. Do not infer KPT Pro device compatibility from this software DSP engine or from generic catalog categories.


## Native DSP control and readback API — ABI v3

The native C++ engine now exposes a bidirectional software-control surface in addition to audio processing:

- Read a node's parameter value back from native memory after a control change.
- Read a node's actual bypass/enabled state and change it independently.
- Inspect node count and node type.
- Reorder nodes in the native processing graph.
- Remove a node from the native graph.

The Audio page uses this API for the Software Multi-FX Control panel. Each supported block parameter is mapped to its DSP-native scale, written into the running native graph when adjusted, and read back for display. Parameter changes are committed to the local preset when the slider interaction ends. Bypass state is also changed in the native graph and saved to the preset.

These controls operate on RigCanvas's software DSP graph only. They do not send messages to a physical KPT Pro. The native graph still processes supplied buffers or an internally generated test signal offline; no live audio input/output or low-latency monitoring is enabled by this milestone.
