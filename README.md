# RigCanvas

RigCanvas is an independent Windows and Android guitar-rig editor and processing workspace. Development starts with a safe, local editor prototype and KPT Pro compatibility research.

> **Current status:** local-first editor prototype with persistent presets, scene snapshots, Gig View setlists, and an Asset Library for amp captures and cabinet impulse responses. KPT Pro communication remains disabled: no device protocol has been confirmed or implemented.

## Product direction

1. **RigCanvas Controller** — cross-platform editor, preset library, asset manager, setlists, and performance controller for verified hardware capabilities.
2. **RigCanvas Desktop Rack** — optional Windows software audio engine for original DSP, stereo/parallel routing, neural capture playback, cabinet processing, and VST3 hosting.

The Controller and Desktop Rack are separate capability targets. Software-only blocks must never be sent to a physical pedal that cannot execute them.

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
- Separate native C++ engine for real-time Windows audio processing.
- VST3 hosting only after SDK and licensing review.

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
