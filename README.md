# RigCanvas

RigCanvas is an independent Windows and Android guitar-rig editor and processing workspace. Development starts with a safe, local editor prototype and KPT Pro compatibility research.

> **Current status:** local-first editor prototype with persistent presets, scene snapshots, Gig View setlists, and an Asset Library for amp captures and cabinet impulse responses. Android and Windows now include scan-only BLE discovery; KPT Pro connection, preset reading, and writing remain disabled until the device protocol is verified.

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
- Narrow device gateway abstraction between UI and platform BLE adapters.
- Scan-only BLE advertisement discovery on Android and Windows.
- Local-first preset, setlist, and asset persistence in app-private storage.
- Kotlin and Android USB/Bluetooth APIs for Android-specific communication.
- Native Windows USB APIs behind a Windows adapter.
- Shared native C++ audio/DSP engine for Android and Windows, with thin operating-system-specific audio I/O adapters.
- Plugin hosting only after a format/runtime with equivalent Android and Windows support has been selected and licensing reviewed.

Flutter 3.50.0 is the current pinned CI toolchain at project initialization.

## Start the app

Install Flutter stable and the Android / Windows platform toolchains.

From the repository root:

    cd app
    flutter create --project-name rigcanvas --org com.rigcanvas --platforms=android,windows .
    dart run tool/prepare_platforms.dart
    flutter pub get
    flutter run -d windows

For Android, connect a developer-enabled device and run:

    cd app
    flutter run

The Workspace remains local simulation. The Settings destination provides scan-only BLE discovery on Android and Windows; it does not connect to or control a pedal.

## Asset Library

- Amp captures: .nam files receive a JSON-envelope check. .am2 and .amp files are copied unchanged and labeled unverified because their format has not been confirmed here.
- Cabinet IRs: mono/stereo PCM or IEEE-float WAV files receive header, encoding, channel, sample-rate, bit-depth, and data-length checks.
- Imported files and catalog metadata are stored locally in the app's private support directory. The library supports search, tags, favorites, metadata editing, and deletion.
- Current validation is a file-format check, not a promise that a file runs in a future audio engine or is compatible with the KPT Pro.

## Hardware safety

Do not flash firmware, replay undocumented traffic, connect to unknown GATT characteristics, or write unverified preset bytes to a physical pedal. RigCanvas scans BLE advertisements only; a scan result is not a verified KPT Pro connection. Begin with read-only identification and observation of official software. See the KPT Pro compatibility and protocol investigation docs in docs/hardware/ and docs/device-discovery/.

## Roadmap

See docs/roadmap/ROADMAP.md.

## Licensing

No open-source license is applied yet. Third-party SDKs, capture formats, trademarks, and bundled DSP assets must be reviewed before distribution.


## Workspace asset links

Amplifier blocks can reference an imported amp capture, and Cabinet blocks can reference a cabinet IR from the local Asset Library. The link is saved as a local asset ID in the preset and scene snapshot. New assignments require acknowledgement of the compatibility notice. A file-format check is not an audio-renderer or KPT Pro compatibility guarantee; the current Workspace still runs in simulation mode only.
