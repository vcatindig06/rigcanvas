# RigCanvas

RigCanvas is an independent Windows and Android guitar-rig editor and processing workspace. Development starts with a safe, local editor prototype and KPT Pro compatibility research.

> **Current status:** local-first editor with persistent presets, Grid layout, scene snapshots, Gig View setlists, an Asset Library, and an expanded offline native DSP prototype. Live audio-device I/O and KPT Pro communication remain disabled; no device protocol has been confirmed or implemented.

## Product direction

RigCanvas is one cross-platform application for Android and Windows. Both builds must expose the same user-facing features, workflows, preset formats, asset management, and performance tools. Only responsive layout and operating-system integrations (such as audio-device and USB/Bluetooth access) may differ.

Future software audio processing is part of this same product and must be implemented for both Android and Windows before it is released on either platform. A Windows-only feature is not considered part of the shared RigCanvas feature set. If a capability cannot be delivered equivalently on both platforms, defer it or provide a documented equivalent before release.

Software-only blocks must never be sent to a physical pedal that cannot execute them.

## Repository layout

- app/ — Flutter Windows/Android application.
- docs/architecture/ — architecture and engineering decisions.
- docs/hardware/ — KPT Pro compatibility notes.
- docs/device-discovery/ — safe protocol-research procedure.
- docs/roadmap/ — staged milestones and acceptance criteria.
- engine/ — reserved for a future native C++ audio engine.

## Technology direction

- Flutter / Dart for the shared Controller UI.
- Narrow device gateway abstraction between UI and USB/Bluetooth adapters.
- Local-first preset, setlist, and asset persistence in app-private storage.
- Kotlin and Android USB/Bluetooth APIs for Android-specific communication.
- Native Windows USB APIs behind a Windows adapter.
- Shared native C++ audio/DSP engine for Android and Windows, with thin operating-system-specific audio I/O adapters. The first offline DSP foundation is implemented through Flutter native-assets FFI; real-time I/O is a later milestone.
- Plugin hosting only after a format/runtime with equivalent Android and Windows support has been selected and licensing reviewed.

Flutter 3.50.0 is the current pinned CI toolchain at project initialization.

## Start the app

Install Flutter stable and the Android / Windows platform toolchains.

From the repository root:

    cd app
    flutter create --project-name rigcanvas --org com.rigcanvas --platforms=android,windows .
    flutter pub get
    flutter run -d windows

For Android, connect a developer-enabled device and run:

    cd app
    flutter run

The initial app opens in **Simulation Workspace**. Reordering blocks and toggling them changes local UI state only.

## Asset Library

- Amp captures: .nam files receive a JSON-envelope check. .am2 and .amp files are copied unchanged and labeled unverified because their format has not been confirmed here.
- Cabinet IRs: mono/stereo PCM or IEEE-float WAV files receive header, encoding, channel, sample-rate, bit-depth, and data-length checks.
- Imported files and catalog metadata are stored locally in the app's private support directory. The library supports search, tags, favorites, metadata editing, and deletion.
- Current validation is a file-format check, not a promise that a file runs in a future audio engine or is compatible with the KPT Pro.

## Hardware safety

Do not flash firmware, replay undocumented traffic, or write unverified preset bytes to a physical pedal. Begin with read-only identification and observation of official software. See the KPT Pro compatibility and protocol investigation docs in docs/hardware/ and docs/device-discovery/.

## Roadmap

See docs/roadmap/ROADMAP.md.

## Licensing

No open-source license is applied yet. Third-party SDKs, capture formats, trademarks, and bundled DSP assets must be reviewed before distribution.


## Workspace asset links

Amplifier blocks can reference an imported amp capture, and Cabinet blocks can reference a cabinet IR from the local Asset Library. The link is saved as a local asset ID in the preset and scene snapshot. New assignments require acknowledgement of the compatibility notice. A file-format check is not an audio-renderer or KPT Pro compatibility guarantee; the current Workspace still runs in simulation mode only.


## Grid Workspace v1

The Grid Workspace is designed around a four-row by eight-slot editor. Effect blocks keep stable IDs while their saved row and slot positions can be changed by drag-and-drop. Dropping a block onto an occupied slot swaps the two positions. The layout and its derived lane connections are stored in the RigCanvas preset format.

Preset, Scene, Stomp, and Hybrid are control modes for the same active preset:

- **Preset:** edit, add, move, and remove blocks in the Grid.
- **Scene:** A–H recall the first eight saved snapshots, with additional saved scenes available below the pads; each snapshot restores block settings and Grid positions.
- **Stomp:** A–H toggle the first eight blocks in preset order.
- **Hybrid:** A–D recall scenes, while E–H toggle the first four blocks in preset order.

The current v1 layout treats each row as an independent local lane. It does not yet model splitters, mixers, cross-lane routing, or custom multi-block footswitch assignments. The input/output labels are local editor lane endpoints, not verified KPT Pro ports.

Android and Windows use the same Flutter workspace and preset schema. The Audio page can process a generated test signal offline using the shared native DSP core; the Workspace is not a live audio path and does not send data to hardware.


## Fixed effect-model catalog

Adding a block now opens a searchable model picker rather than creating a generic custom-named block. Models are grouped into Dynamics, Drive, Amplifier, Cabinet, Modulation, Delay, Reverb, EQ, Pitch, and Wah / Expression. Each model has a stable ID; the block name is resolved from the selected catalog entry and custom free-text model names are not supported.

The catalog distinguishes two sources:

- **KPT Pro Factory:** 152 catalog entries based on the available KPT Pro manual's named options and documented numbered AMP/CAB slots, including a separately documented 3-band EQ overview entry. The manual itself has a discrepancy: the detailed MOD list names nine options while its FAQ says eight; the app preserves all nine named options. AMP/CAB individual factory labels are not available in the inspected manual, so those choices are shown as numbered guitar/bass slots, not invented model names.
- **RigCanvas Library:** additional generic amp, cabinet, drive, dynamics, modulation, delay, reverb, EQ, pitch, and expression archetypes informed by the broad block families of leading processors. These are not KPT Pro factory models.

The current catalog is selection metadata only. It does not implement the DSP, load a virtual amp/cab model for playback, or send model/parameter values to the KPT Pro. See [Effect Model Catalog research](docs/research/EFFECT_MODEL_CATALOG.md) for the source distinctions, manual discrepancies, and next validation requirements.


## Offline DSP foundation

The Audio page processes an internally generated 440 Hz / 48 kHz / 500 ms test signal through the active preset's supported enabled blocks in Grid order. The shared C++ core has generic dynamics (gate/compressor), soft-clipping drive, amplifier preamp/tone shaping, cabinet FIR, chorus/vibrato/flanger/tremolo, standard/ping-pong delay, a room-style reverb, and four-band EQ.

Linked cabinet WAVs are loaded from the Asset Library for the offline test. The shared WAV decoder validates RIFF/WAVE structure, accepts PCM 8/16/24/32-bit and IEEE float 32/64-bit mono/stereo files, resamples to 48 kHz, and caps the loaded IR at 4,096 frames per channel. The Audio test reports resampling and truncation. The original imported file is preserved.

These are generic RigCanvas prototypes, **not** emulations of KPT Pro factory algorithms or other manufacturers' DSP. Catalog names remain labels; some specialized types (including phaser, wah/autofilter, rotary, pitch, ducking/reverse/tape/lo-fi delay, and spring/shimmer/cloud reverb) remain unsupported and are explicitly skipped. The current linear-interpolation resampler and direct FIR convolution are not production-grade live-audio implementations.

The engine is still offline: it does not capture a guitar or microphone, open an audio interface, or play through speakers/headphones. NAM/AM2 capture execution and KPT Pro device control remain unimplemented. See [DSP engine architecture](docs/architecture/DSP_ENGINE.md).
