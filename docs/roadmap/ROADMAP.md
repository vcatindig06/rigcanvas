# Roadmap

## Milestone 0 — repository and application foundation

- [x] Establish architecture and device safety boundary.
- [x] Record initial KPT Pro documentation findings.
- [x] Create Flutter Windows/Android application shell.
- [x] Keep one shared RigCanvas feature set across Android and Windows; responsive navigation may differ, but product workflows and destinations remain available on both.
- [x] Verify compact and wide layouts expose the same Gig, Workspace, Presets, Assets, and Settings destinations.
- [x] Create local simulation workspace with reorderable effect blocks.
- [x] Run Flutter format, analyze, tests, and platform builds in CI.
- [x] Confirm first CI run is green.

## Milestone 1 — editor UX and local data

- [x] Preset list and preset detail.
- [x] Local preset schema with an explicit schema version.
- [x] RigCanvas-native JSON export/import.
- [ ] Undo/redo and preset version history.
- [x] IR/AM2 asset library with metadata and conservative format checks.
- [x] Link local amp captures only to Amplifier blocks and cabinet IRs only to Cabinet blocks, with a warning acknowledgement before new assignment and preset/scene persistence.
- [x] Prevent saving a missing or wrong-family asset reference until the link is replaced or cleared.
- [x] Show format-specific limitations: NAM structure checks do not confirm model/runtime support; AM2/AMP files remain unverified; WAV metadata checks do not confirm audio-engine or KPT Pro acceptance.
- [x] Cover both Amp and Cabinet assignment plus wrong-family reference recovery in widget tests.
- [x] Search, tags, favorites, and setlists.

## Milestone 1.5 — Grid Workspace v1 (local simulation)

- [x] Persist a four-row by eight-slot Grid using stable effect-block IDs.
- [x] Migrate schema-version-1 presets and scene snapshots into the row-major Grid without losing block settings or asset references.
- [x] Add and remove blocks from slots; drag blocks between slots and swap occupied positions.
- [x] Keep Grid positions in scene snapshots and restore them when recalling a scene.
- [x] Make Preset, Scene, Stomp, and Hybrid modes control the same active preset.
- [x] Add A–H scene pads, Stomp bypass controls, and the A–D / E–H Hybrid layout.
- [x] Verify the Grid and all four modes with unit and widget tests (51 tests passed).
- [x] Pass Android installable APK and Windows release CI builds for the same commit.
- [ ] Manually smoke-test the Grid and all four modes on Android and Windows.

**v1 boundary:** each row is an independent local lane with derived input-to-output ordering. Splitter/mixer nodes, cross-lane routing, user-defined multi-block footswitch assignments, and actual audio processing are not part of v1. Do not present lane endpoints as physical KPT Pro inputs or outputs.

## Milestone 1.6 — Fixed effect-model catalog

- [x] Add a searchable catalog picker with category filters and explicit KPT Pro Factory / RigCanvas Library source labels.
- [x] Include the named KPT Pro FX, MOD, DLY, REV and EXT options and the documented numbered guitar/bass AMP and CAB slots.
- [x] Include the KPT Pro overview's 3-band EQ item while documenting its uncertain module placement and the manual's 8-versus-9 MOD discrepancy.
- [x] Add additional generic Dynamics, Drive, Amplifier, Cabinet, Modulation, Delay, Reverb, EQ, Pitch and Expression archetypes informed by leading multi-effects systems.
- [x] Persist stable model IDs and normalize legacy custom labels through preset schema v3 migration.
- [x] Remove free-text custom block naming; add and edit blocks through the same model picker.
- [x] Add unit, migration, controller and cross-platform widget tests for catalog selection and source separation (63 tests passed).
- [x] Pass Android installable APK and Windows release CI builds for the same revision.
- [ ] Verify the numbered KPT Pro AMP/CAB slots and exact MOD/REV choices against the user's physical pedal, firmware and M-EFCS.
- [ ] Manually smoke-test model selection and preset migration on Android and Windows.

**Important boundary:** KPT Pro factory AMP/CAB names are not published in the accessible manual copy. Show numbered slots instead of guessed names. RigCanvas Library entries are generic archetypes, not clones or licensed manufacturer algorithms. The picker does not mean audio rendering or KPT Pro protocol support exists.
 
## Milestone 2 — hardware discovery

- [ ] Collect exact KPT Pro firmware/app versions.
- [ ] Capture USB descriptors.
- [ ] Confirm whether official M-EFCS recognizes the tested KPT Pro.
- [ ] Identify wireless transport and OS permissions.
- [ ] Document protocol evidence and a capability matrix.
- [ ] Implement safe read-only discovery only after protocol behavior is understood.

## Milestone 3 — KPT Pro read-only editor

- [ ] Device identity and firmware display.
- [ ] Capability negotiation.
- [ ] Read preset list and download a backup.
- [ ] Parse only confirmed preset formats.
- [ ] Compare local and device presets.
- [ ] Add verified preset write support only after the hardware safety gate.

## Milestone 4 — performance workflow

- [ ] Complete the Grid-based Preset / Scene / Stomp / Hybrid performance workflow on the shared preset model.
- [x] App-managed scene snapshots for local effect order, bypass states, and parameter values.
- [x] Local stomp-style block bypass controls.
- [ ] Map performance modes to KPT Pro controls only after capabilities are verified.
- [x] Local Gig View with persistent setlists, song order, key/BPM/notes, and per-song preset/scene assignments.
- [ ] External MIDI support where target OS/hardware expose it.

## Milestone 5 — Cross-platform Software Audio Engine (Android + Windows)

- [ ] Build one shared DSP graph and node API used by both operating systems.
- [ ] Add audio-device selection, input/output routing, and monitoring with equivalent user controls on Android and Windows.
- [ ] Implement the shared drive, modulation, delay, and reverb blocks with matching parameters and preset behavior.
- [ ] Add amp-capture playback using a model format and runtime that work on both platforms.
- [ ] Add cabinet IR convolution with matching format support and parameters on both platforms.
- [ ] Add stereo routing and parallel branches on both platforms.
- [ ] Add sidechain and envelope/follow-input nodes on both platforms.
- [ ] Add delay/reverb tail management on both platforms.
- [ ] Consider plugin hosting only after a plugin format and runtime with equivalent Android and Windows support has been verified and licensing reviewed; do not ship Windows-only plugin hosting.

**Parity gate:** a software-engine feature is not complete until the same capability, controls, preset serialization, and supported asset formats work on both Android and Windows. Use thin native audio I/O adapters where the operating systems require different low-level APIs.

## Weekly roadmap review

- **Cadence:** Every Monday (Asia/Manila).
- Compare roadmap checkboxes against source code, automated tests, and the latest GitHub Actions results; do not treat a UI-only placeholder as a completed capability.
- Record the review date, completed work, blockers, and the next highest-value milestone.
- Keep KPT Pro protocol work read-only until exact model, firmware, official application, and transport behavior have been verified. Never infer KPT Pro support from Tank-G/Tank-B documentation.

### Review log — 2026-11-16

- Verified the Workspace editor exposes local amp-capture references for Amplifier blocks and cabinet IR references for Cabinet blocks; preset and scene serialization retain asset IDs.
- Strengthened assignment safety: missing or wrong-family references must be cleared or replaced, and new assignments require an explicit warning acknowledgement.
- Added dedicated test coverage for cabinet IR assignment and invalid-reference recovery alongside the existing amplifier-capture assignment test.
- Confirmed feature-parity rule: the same Gig, Workspace, Presets, Assets, and Settings destinations are covered in compact and wide layout tests; Android APK and Windows desktop builds are both required in CI.
- **Next focus:** finish and verify Grid Workspace v1 on Android and Windows. Only after this local editor milestone is stable should work return to KPT Pro discovery; start with exact device/firmware and official M-EFCS version evidence, then read-only USB enumeration.

## Release gates

A milestone is not complete because the UI exists. It must include:
- Automated tests for core logic.
- Manual verification on each target OS.
- Android and Windows must ship the same user-facing feature set; platform-specific UI layout or native I/O adapters must not remove product workflows.
- CI must build and upload an installable Android APK alongside the Windows desktop package for the same source revision.
- Documented supported hardware/firmware combinations.
- Clear unsupported-feature messaging.
- No destructive device operation without a tested backup/recovery workflow.


### Grid Workspace implementation log — 2026-11-16

- Started the shared four-row/eight-slot Grid model on `feature/grid-workspace-v1`; block positions are stored by stable block ID.
- Added schema-version-2 serialization with a version-1 compatibility path that creates the original row-major order and rewrites the local database in the new schema.
- Added scene-level Grid snapshots so scene recall can restore layout as well as block settings.
- Implemented row-local add, move/swap, and remove operations; block removal also clears matching scene references.
- Reworked the Workspace UI around the Grid and added Scene, Stomp, and Hybrid A–H controls. Stomp currently maps the first eight blocks in preset order; Hybrid maps A–D to scenes and E–H to the first four blocks.
- Added Grid model, migration, controller, and widget tests. GitHub Actions run [#50](https://github.com/vcatindig06/rigcanvas/actions/runs/43816049229) passed analysis and all 51 automated tests.
- The same run built and uploaded the installable Android APK plus SHA-256 checksum and the Windows release package.
- **Status:** automated checks complete; manual Android and Windows smoke checks remain. PR [#5](https://github.com/vcatindig06/rigcanvas/pull/5) remains draft and unmerged pending those checks.


### Effect model catalog implementation log — 2026-11-16

- Reviewed the available YUIMER KPT PRO manual copies and current official documentation for Fractal Axe-Fx III, Neural DSP Quad Cortex, Line 6 Helix and Kemper Profiler.
- Added a fixed searchable model catalog with KPT Pro Factory and RigCanvas Library source labels.
- Added numbered guitar/bass AMP and CAB factory-slot entries because the manual supplies slot counts but not individual descriptive names.
- Added stable model IDs to preset schema v3, with schema-v1/v2 import and local-database migration.
- Replaced custom free-text model names with a fixed catalog selection for block insertion and editing.
- Added catalog count/source-separation tests, schema migration tests, controller tests and model-picker widget tests. GitHub Actions run [#66](https://github.com/vcatindig06/rigcanvas/actions/runs/43820097363) passed Flutter analysis and all 63 tests.
- The same run built and uploaded the Android APK plus SHA-256 checksum and the Windows release package.
- **Status:** catalog implementation and automated cross-platform builds complete; physical KPT Pro slot verification and manual Android/Windows smoke tests remain. PR [#5](https://github.com/vcatindig06/rigcanvas/pull/5) remains draft.
- **Boundary:** the expanded options are catalog metadata/archetypes only. DSP/audio processing and KPT Pro write/control support are not implemented.


## Milestone 5.1 — shared native DSP foundation (offline prototype)

- [x] Compile one C++17 DSP implementation for Android and Windows with Flutter native-assets build hooks.
- [x] Expose a bounded C ABI and Dart FFI wrapper for engine lifecycle, node configuration, processing, and metrics.
- [x] Implement generic linked-stereo noise gate and compressor modes.
- [x] Implement generic soft-clipping overdrive and an amp preamp / tone-shaping stage.
- [x] Add FIR cabinet convolution for an explicitly supplied mono float IR buffer (up to 4096 taps).
- [x] Process the active preset's enabled supported nodes in saved Grid row/slot order.
- [x] Add an internal 440 Hz offline test signal and input/output RMS / peak reporting.
- [x] Keep unsupported block families visible as skipped and avoid implying a physical guitar or speaker path.
- [ ] Decode imported WAV IR files, resample as required, and load the verified samples from the Asset Library.
- [ ] Add impulse-response, frequency-response, distortion, noise, parameter-boundary, and performance tests.
- [ ] Manually build and smoke-test the Audio page on physical Android hardware and a Windows PC.
- [ ] Add production-safe real-time audio callback and device abstractions only after profiling and lifecycle design.
- [ ] Implement Android and Windows capture/playback adapters with equivalent device controls and routing.

**Milestone 5.1 boundary:** this is offline/block DSP only. It is not a low-latency live guitar processor. Current gate/compressor/drive/amp algorithms are generic prototypes, not manufacturer-model simulations. Cabinet FIR is usable only when sample buffers are supplied directly; imported WAV decoding and auto-loading are not yet connected. See [DSP engine architecture](../architecture/DSP_ENGINE.md).

### DSP foundation implementation log — 2026-11-16

- Started a shared C++17 DSP core under app/packages/rigcanvas_dsp/src, compiled for target platforms via app/packages/rigcanvas_dsp/hook/build.dart.
- Added Dart FFI bindings and a wrapper using the native-assets API rather than separate Android and Windows DSP implementations.
- Added initial Dynamics (gate/compressor), Drive (soft clipping), Amplifier (preamp/tone shaping), and Cabinet (mono FIR buffer) nodes.
- Added an Audio page that applies the supported enabled blocks in Grid order to an internal 440 Hz test signal and displays input/output RMS, peak, frame, and node metrics.
- Unsupported families, missing live audio I/O, amp-capture playback, and unconnected WAV IR imports are disclosed in the app.
- Automated tests and both platform builds are pending CI verification. Physical Android and Windows smoke tests remain.
