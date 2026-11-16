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

- [x] Local Preset / Scene / Stomp / Hybrid workspace modes.
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
- Expanded the KPT Pro catalogue from available manual evidence: FX, AMP, MOD, DLY, REV, CAB, and EXT families are recorded separately; unsupported individual amp/cab names and parameter ranges are explicitly not invented.
- Recorded the vendor download-page discrepancy: M-EFCS is listed for TANK-G/TANK-B, while a KPT Pro manual describes M-EFCS control. KPT Pro compatibility remains unverified; Tank-G protocol assumptions are prohibited.
- **Next focus:** obtain the user's exact KPT Pro firmware version and M-EFCS app version/device-list result, then capture read-only USB descriptors. Do not implement undocumented device writes or mark the catalogue as verified device capability.

## Release gates

A milestone is not complete because the UI exists. It must include:
- Automated tests for core logic.
- Manual verification on each target OS.
- Android and Windows must ship the same user-facing feature set; platform-specific UI layout or native I/O adapters must not remove product workflows.
- CI must build and upload an installable Android APK alongside the Windows desktop package for the same source revision.
- Documented supported hardware/firmware combinations.
- Clear unsupported-feature messaging.
- No destructive device operation without a tested backup/recovery workflow.
