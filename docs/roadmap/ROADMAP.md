# Roadmap

## Milestone 0 — repository and application foundation

- [x] Establish architecture and device safety boundary.
- [x] Record initial KPT Pro documentation findings.
- [x] Create Flutter Windows/Android application shell.
- [x] Create local simulation workspace with reorderable effect blocks.
- [ ] Run Flutter format, analyze, tests, and platform builds in CI.
- [ ] Confirm first CI run is green.

## Milestone 1 — editor UX and local data

- [ ] Preset list and preset detail.
- [x] Local preset schema with an explicit schema version.
- [x] RigCanvas-native JSON export/import.
- [ ] Undo/redo and preset version history.
- [ ] IR/AM2 asset library with metadata and compatibility checks.
- [ ] Search, tags, favorites, and setlists.

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

## Release gates

A milestone is not complete because the UI exists. It must include:
- Automated tests for core logic.
- Manual verification on each target OS.
- Documented supported hardware/firmware combinations.
- Clear unsupported-feature messaging.
- No destructive device operation without a tested backup/recovery workflow.
