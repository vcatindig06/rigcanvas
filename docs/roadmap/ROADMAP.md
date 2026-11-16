# Roadmap

## Milestone 0 — repository and application foundation

- [x] Establish architecture and device safety boundary.
- [x] Record initial KPT Pro documentation findings.
- [x] Create Flutter Windows/Android application shell.
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

## Milestone 5 — Windows Desktop Rack

- [ ] Audio device selection and monitoring.
- [ ] Low-latency audio graph.
- [ ] Original drive, modulation, delay, and reverb DSP.
- [ ] Amp and cabinet processing.
- [ ] Stereo routing and parallel branches.
- [ ] Sidechain and envelope/follow-input nodes.
- [ ] Delay/reverb tail management.
- [ ] VST3 hosting after licensing and compatibility review.
- [ ] Neural capture runtime after format and model-runtime licensing review.

## Weekly roadmap review

- **Cadence:** Every Monday (Asia/Manila).
- Compare roadmap checkboxes against source code, automated tests, and the latest GitHub Actions results; do not treat a UI-only placeholder as a completed capability.
- Record the review date, completed work, blockers, and the next highest-value milestone.
- Keep KPT Pro protocol work read-only until exact model, firmware, official application, and transport behavior have been verified. Never infer KPT Pro support from Tank-G/Tank-B documentation.

### Review log — 2026-11-16

- Verified the Workspace editor exposes local amp-capture references for Amplifier blocks and cabinet IR references for Cabinet blocks; preset and scene serialization retain asset IDs.
- Strengthened assignment safety: missing or wrong-family references must be cleared or replaced, and new assignments require an explicit warning acknowledgement.
- Added dedicated test coverage for cabinet IR assignment and invalid-reference recovery alongside the existing amplifier-capture assignment test.
- **Next focus:** Milestone 2 — collect the exact KPT Pro hardware/firmware and official M-EFCS versions, then perform read-only USB enumeration. Do not implement undocumented device writes.

## Release gates

A milestone is not complete because the UI exists. It must include:
- Automated tests for core logic.
- Manual verification on each target OS.
- Documented supported hardware/firmware combinations.
- Clear unsupported-feature messaging.
- No destructive device operation without a tested backup/recovery workflow.
