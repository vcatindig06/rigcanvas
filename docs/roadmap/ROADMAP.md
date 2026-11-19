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
- [x] Record the owner's 50 named AMP and 50 named CAB entries for firmware v8; show CL/OD/DS as structured amp types.
- [x] Add AMP type filters for All, Clean (CL), Overdrive (OD), and Distortion (DS), with widget coverage for filtered catalog counts.
- [ ] Verify the exact AMP/CAB order and the MOD/REV choices on the physical v8 pedal.
- [ ] Manually smoke-test model selection and preset migration on Android and Windows.

**Important boundary:** the accessible manual does not publish individual AMP/CAB names; the firmware-v8 owner's 50 AMP and 50 CAB names are now included as user-provided factory-menu entries, not independently manufacturer-verified aliases. The extra manual-listed bass slots remain unverified. RigCanvas Library entries are generic archetypes, not clones or licensed manufacturer algorithms. Catalog selection does not mean audio rendering or KPT Pro protocol support exists.
 
## Milestone 2 — hardware discovery

- [x] Scan and connect to the physical BLE peripheral; capture its GATT service/characteristic UUIDs and properties without sending writes.
- [x] Identify the standard BLE-MIDI service/characteristic UUID pair from the physical report.
- [x] Add a local Android BTSnoop HCI/H4 importer with ATT event decoding, LE connection-session filtering, address masking, and payload-off-by-default export.
- [x] Correlate ATT handles to 16-bit and 128-bit GATT service/characteristic UUIDs and property bits within each connection; retain the complete discovered map after disconnect.
- [ ] Capture and document KPT Pro-specific MIDI messages or vendor-tunnel framing from an authorized official-app trace; do not infer commands from UUIDs alone.
- [x] Record the owner's M-EFCS v3.10.2311 version and reported working pairing with KPT Pro.


- [x] Record the owner's reported KPT Pro firmware display as v8 and M-EFCS v3.10.2311 (reported 2026-11-17; firmware is not independently read by RigCanvas).
- [x] Add a shared Devices screen for Android and Windows with read-only USB inventory.
- [x] Add Android USB Host enumeration for attached device VID/PID, interfaces, and endpoints without opening the USB device or transferring data.
- [x] Add Windows SetupAPI enumeration for present USB Plug-and-Play names, manufacturer, class, VID, and PID; full Windows interface/endpoint descriptor capture remains outstanding.
- [ ] Identify the physical KPT Pro record from a scan and verify the VID/PID on the user's unit.
- [ ] Record hardware revision from the pedal label or system information.
- [ ] Capture full Windows USB configuration/interface/endpoint descriptors; the physical BLE profile is now identified, but its application protocol is not.
- [x] Record the 50 named AMP and 50 named CAB entries supplied from the physical firmware-v8 menu.
- [ ] Verify AMP/CAB ordering and compare the physical firmware-v8 unit's MOD/REV inventory and module-slot behavior against the manual.
- [ ] Document verified protocol evidence and a capability matrix before implementing any protocol exchange.

- [x] Analyze the first owner-provided M-EFCS ATT trace: recurring phone writes on `0x0062`, pedal notifications on `0x0064`, and one acknowledged write on `0x0065`; keep handle-to-UUID assignments unverified because discovery map/payloads are absent.
- [x] Add payload-free decoding for ATT discovery query ranges/UUIDs, ATT error details, and MTU values; split GATT discovery counts from simple attribute-value reads; flag repeated MTU-exchange requests.
- [ ] Capture a short selected-connection HCI trace with payload bytes enabled after reviewing privacy implications, to identify vendor-tunnel framing and response correlation.
- [ ] Reconfirm the selected connection's GATT declaration map so ATT handles can be mapped to AE41/AE42 within the same session.
- [ ] Identify message framing, length fields, sequence/acknowledgement behavior and any fragmentation from payload evidence; do not replay packets or issue writes.

## Milestone 3 — KPT Pro native patch control (current priority)

**Product priority:** pause further catalog/DSP expansion and complete a genuine KPT Pro patch workflow first: read the pedal's patches, edit a real device patch, save it back, and import/export the pedal's native tone files. RigCanvas-local JSON presets are not KPT Pro patch files and must remain clearly separate.

### Evidence and protocol gates

- [ ] Capture a fresh complete M-EFCS connection from connect through disconnect, including successful service, characteristic, and descriptor discovery.
- [ ] Correlate a controlled, single-parameter edit in M-EFCS with the exact outgoing and incoming ATT messages.
- [ ] Correlate Save to a disposable user slot with its request, acknowledgement, and subsequent readback.
- [ ] Correlate a native tone/preset export and import operation; preserve the exact source filename, extension, and original bytes.
- [ ] Document vendor characteristic UUIDs, framing, message lengths, sequence/correlation fields, fragmentation, checksums, timeouts, acknowledgement behavior, and error responses as observed / inferred / unknown.
- [ ] Confirm the exact 7-module hardware model (FX, AMP, MOD, DLY, REV, CAB, EXT), reordering rules, and the meaning of the manual's additional “7+1” wording. Do not map the local four-row/eight-slot Grid directly onto the pedal.
- [ ] Confirm preset-slot numbering and factory/user boundaries on the physical firmware baseline; never assume an occupied slot is safe to overwrite.
- [ ] Keep all device writes disabled until a valid backup, disposable test slot, verified transaction response, readback, and recovery procedure exist.

### Patch read / edit / save / import implementation

- [x] Reverse-engineer and document the outer KPT Pro frame envelope, little-endian body length, body checksum, and BLE-notification fragmentation using the 2026-11-17 payload capture; add a pure Dart parser/reassembler and regression tests. This establishes framing only, not command semantics.
- [x] Integrate read-only frame-envelope analysis into the selected HCI capture session, preserving per-direction/per-handle stream boundaries and exposing raw command counts plus capture positions only.
- [x] Add comparison-only f1/f2 word slicing for the two recurring eight-byte CMD 0x23 body variants; expose full raw words and candidate fields in the offline analyzer without assigning KPT Pro command semantics.
- [x] Add an opt-in passive AE40/AE42 notification monitor. Parse incoming notifications only; configure/disable BLE Notify subscription and never send KPT vendor commands.
- [ ] Confirm whether the KPT Pro emits useful model, status, or preset data without a request; passive monitoring cannot retrieve data that is only returned on demand.
- [ ] Verify the f1/f2 field meanings and correlate CMD 0x23 with a named M-EFCS action using a new controlled trace.
- [ ] Create a KPT-specific patch domain model from decoded device data. Preserve unknown fields and raw bytes so a read → save → read cycle does not discard unsupported settings.
- [ ] Implement read-only device identity, capability reporting, preset-slot listing, and complete patch download first.
- [ ] Build a hardware patch editor for the actual module order, enabled state, factory model selection, and per-model parameter names / values / units. Do not reuse generic RigCanvas DSP parameter scales as KPT Pro hardware values.
- [ ] Implement local patch editing and a before/after change view without sending writes.
- [ ] Add verified save-to-device and swap operations only after the protocol transaction and recovery gates above pass.
- [ ] Add native KPT Pro tone-file import/export only after a real M-EFCS-exported sample establishes the container, version, checksum, and payload structure.
- [ ] Treat AMP capture / AM2 data and CAB IR imports as separate file families from a complete preset/patch. Do not infer that “A2 support” names a file extension.
- [ ] Verify read → export → import-to-test-slot → readback round trips on the owner's exact KPT Pro hardware and firmware, without altering factory slots.
- [ ] Add fixtures from sanitized test-patch files, byte-preservation tests, malformed/truncated-file tests, parameter-range tests, transaction timeout/retry tests, and Android/Windows parity tests.

### Current implementation boundary

- RigCanvas can scan and inspect a BLE GATT profile and read allowlisted standard Device Information fields when exposed.
- The current hardware gateway can opt in to a passive AE42 notification subscription and parse incoming frame envelopes, but it does not issue vendor requests, read vendor patch data, or send vendor writes. A separate offline parser validates captured KPT Pro frames and checksums, and displays a comparison-only f1/f2 field-slice hypothesis for two recurring 0x23 body variants; it is not connected to the BLE gateway and cannot read or write the pedal.
- The existing Preset Library imports/exports only the `rigcanvas-preset` JSON format. The UI explicitly warns that these files are not device presets.
- The 2026-11-17 payload capture contains repeated writes and notifications, but no successful characteristic declaration map and no user-action correlation. The repeated byte patterns are not yet decoded commands. No packet may be replayed or repurposed as a guessed patch command.

### Current blocker / required owner evidence

See [KPT Pro Patch Control — Evidence and Implementation Plan](../device-discovery/KPT_PRO_PATCH_CONTROL_PLAN.md) for the controlled M-EFCS capture procedure and exact files needed to implement the real patch workflow.

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

### Review log — 2026-11-17

- Recorded the owner's correction: the physical KPT Pro firmware baseline is v8, not v15; M-EFCS Android version v3.10.2311 is owner-reported and the owner confirms it connects to the pedal.
- Added 50 owner-provided AMP and 50 CAB menu names exactly as supplied. AMP model prefixes are structured Clean (CL), Overdrive (OD), or Distortion (DS) metadata; the extra manual-listed bass slots are still marked unverified for the v8 unit.
- Added visible AMP type filter chips and tests covering All / CL / OD / DS result counts.
- Recorded public M-EFCS App Store release-note evidence for KPT Pro A2 support in the 3.10 series, without treating that as a published BLE command protocol.
- GitHub Actions run [#125](https://github.com/vcatindig06/rigcanvas/actions/runs/44069719859) passed Flutter analysis, all 90 automated tests, Android APK build/package verification, and Windows desktop build. Both artifacts uploaded successfully.
- Added the offline Android HCI/BTSnoop capture importer and ATT analyzer to Devices. It filters by one LE connection, identifies the `KPTPRO_BLE` advertised name when present, maps characteristic declaration UUIDs, masks peer addresses, and excludes payload bytes by default.
- Added unit coverage for advertising/connection correlation, characteristic UUID mapping, ATT writes/notifications, connection filtering, payload redaction, and ACL fragmentation.
- Extended the trace decoder to map ATT handles through service ranges to characteristic UUIDs and property bits, with per-connection tables preserved after disconnect. The exported map includes discovered characteristics even if no payload was exchanged on them.
- GitHub Actions run [#154](https://github.com/vcatindig06/rigcanvas/actions/runs/44077392484) passed Flutter format/static analysis and all 97 automated tests, built and checksum-verified the Android APK, and built the Windows desktop package. Both artifacts uploaded successfully.
- Documented the Samsung Android 12 HCI snoop capture process. Waiting for the owner to import a real M-EFCS v3.10.2311 / KPT Pro firmware-v8 capture; no physical pedal writes are implemented.
- **Next focus:** analyze the private Android HCI snoop capture from M-EFCS v3.10.2311 / KPT Pro firmware v8. Capture a normal connection and preset-list refresh first; only after that read exchange is understood should a controlled test-preset parameter change be considered.

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
- [x] Add FIR cabinet convolution for supplied mono or stereo float IR buffers (up to 4096 frames per channel).
- [x] Process the active preset's enabled supported nodes in saved Grid row/slot order.
- [x] Add an internal 440 Hz offline test signal (500 ms on the Audio page) and input/output RMS / peak reporting.
- [x] Keep unsupported block families visible as skipped and avoid implying a physical guitar or speaker path.
- [x] Decode supported WAV IR files, resample to the offline DSP rate, preserve mono/stereo, and load verified samples from the Asset Library (PCM 8/16/24/32-bit and IEEE float 32/64-bit; 4096 frames/channel ceiling).
- [x] Add native engine unit coverage for graph processing, FIR IR-buffer copy, offline buffer shape, invalid formats, and engine disposal. (80 total Flutter unit/widget tests pass in CI run #90.)
- [ ] Add deeper DSP validation: impulse-response and frequency-response references, distortion/noise measurements, parameter-boundary tests, and performance benchmarks.
- [ ] Manually build and smoke-test the Audio page on physical Android hardware and a Windows PC.
- [ ] Add production-safe real-time audio callback and device abstractions only after profiling and lifecycle design.
- [ ] Implement Android and Windows capture/playback adapters with equivalent device controls and routing.

**Milestone 5.1 boundary:** this is offline/block DSP only. It is not a low-latency live guitar processor. Current algorithms are generic prototypes, not manufacturer-model simulations. The WAV decoder uses linear interpolation and cabinet convolution is direct FIR, so both need further quality and performance validation before live use. See [DSP engine architecture](../architecture/DSP_ENGINE.md).

### DSP foundation implementation log — 2026-11-16

- Started a shared C++17 DSP core under app/packages/rigcanvas_dsp/src, compiled for target platforms via app/packages/rigcanvas_dsp/hook/build.dart.
- Added Dart FFI bindings and a wrapper using the native-assets API rather than separate Android and Windows DSP implementations.
- Added initial Dynamics (gate/compressor), Drive (soft clipping), Amplifier (preamp/tone shaping), and Cabinet (mono FIR buffer) nodes.
- Added an Audio page that applies the supported enabled blocks in Grid order to an internal 440 Hz test signal and displays input/output RMS, peak, frame, and node metrics.
- Unsupported families, missing live audio I/O, amp-capture playback, and unconnected WAV IR imports are disclosed in the app.
- GitHub Actions run [#87](https://github.com/vcatindig06/rigcanvas/actions/runs/43824897566) passed Flutter static analysis and all 69 unit/widget tests, built the Android APK with SHA-256 verification, and built the Windows release package. Both artifacts uploaded successfully. Physical Android and Windows smoke tests remain.


## Milestone 5.2 — cabinet WAV loading and expanded offline DSP

- [x] Add a shared RIFF/WAVE decoder for PCM 8/16/24/32-bit and IEEE-float 32/64-bit mono/stereo files.
- [x] Validate WAV chunk boundaries, byte rate, block alignment, sample rate, channel count, and finite float samples.
- [x] Resample imported cabinet IRs to the shared 48 kHz offline engine rate and cap the response at 4096 frames per channel.
- [x] Read stored cabinet WAV bytes through the Asset Library repository/controller instead of treating an asset ID as a loaded sound.
- [x] Load mono IRs into both output channels and stereo IRs into independent left/right FIR responses.
- [x] Implement generic chorus/vibrato/flanger/tremolo, standard/ping-pong delay, room-style reverb, and four-band EQ nodes in the shared C++ engine.
- [x] Connect these supported block families to the Audio test in Grid row/slot order.
- [x] Keep specialized/unsupported phaser, wah, rotary, pitch, and delay/reverb variants explicitly skipped.
- [x] Add tests for PCM24, stereo preservation, sample-rate conversion, maximum IR length, malformed files, non-finite float samples, native DSP nodes, asset-byte reads, and a widget-level linked-IR load.
- [ ] Improve the linear-interpolation resampler with an anti-aliasing/reference-tested resampling method.
- [ ] Benchmark direct FIR convolution and design partitioned convolution for longer responses.
- [ ] Add impulse/frequency-response and distortion/noise reference tests plus CPU/memory profiling.
- [ ] Manually test WAV import, CAB assignment, and Audio offline test on a physical Android device and Windows PC.

**Milestone 5.2 boundary:** the added modulation/delay/reverb/EQ algorithms are generic offline DSP prototypes. They do not recreate KPT Pro factory models. The WAV decoder and CAB path do not provide real-time monitoring or guarantee that every manufacturer's IR file is supported. Live device I/O remains a separate milestone.

### DSP expansion implementation log — 2026-11-16

- Added WAV PCM/IEEE-float decoding and strict RIFF validation in the shared Dart layer.
- Connected AssetRepository and AssetController file reads to the Audio screen so a linked CAB WAV is retrieved, decoded and loaded for offline testing.
- Extended the native C ABI to version 2 with mono/stereo cabinet IR transfer and independent stereo FIR response data.
- Added generic modulation, delay, reverb, and EQ processing nodes to the shared C++ core; specialized unsupported variants remain explicitly skipped.
- Updated UI messaging to distinguish loaded CAB WAVs, generic processing, and still-unavailable live audio/KPT Pro functionality.
- GitHub Actions run [#90](https://github.com/vcatindig06/rigcanvas/actions/runs/43833693025) passed static analysis and all 80 Flutter tests, built and uploaded the Android APK with SHA-256 verification, and built and uploaded the Windows release. Manual Android/Windows smoke tests, DSP quality/performance tests, and live audio I/O remain outstanding.

### DSP implementation log — 2026-11-18

- Extended the shared native DSP modulation node with a four-stage all-pass phaser, envelope-responsive wah/autofilter, and a stereo-offset rotary-speaker approximation.
- Added dedicated software-control labels and parameter mapping for phaser feedback, wah sensitivity/resonance, and rotary speed, while keeping the existing preset model IDs and native DSP ABI v3 stable.
- Added regression coverage that processes a modulated stereo test signal through all three modes, checks finite output and non-identity processing, and verifies native parameter readback.
- These are generic RigCanvas software effects shared by Android and Windows; they do not claim to reproduce KPT Pro factory algorithms or expression-pedal control.
- **Next DSP focus:** implement and test distinct delay variants (ducking, tape-style, lo-fi, and dual) and specialized reverb algorithms only with documented control mappings and deterministic signal tests. Keep live audio I/O and physical KPT Pro writes disabled until their separate safety/performance gates are met.

### Priority change — 2026-11-18

- Reprioritized the product around genuine KPT Pro patch control: read device slots, edit actual hardware parameters, save patches to the pedal, and import/export native tone data.
- Paused further generic offline DSP expansion until the KPT Pro read/edit/save/import path has passed hardware verification.
- Confirmed the distinction between RigCanvas JSON presets and KPT Pro device patches. The existing local import/export flow must not be labelled or treated as hardware synchronization.
- The next implementation input is a fresh M-EFCS action-correlated BLE capture plus an exact M-EFCS-exported test patch file. No undocumented vendor writes will be sent before the request/response protocol and recovery path are verified.
