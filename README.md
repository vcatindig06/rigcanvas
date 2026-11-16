# RigCanvas

RigCanvas is an independent Windows and Android guitar-rig editor and processing workspace. Development starts with a safe, local editor prototype and KPT Pro compatibility research.

> **Current status:** early scaffold / simulation mode. No KPT Pro communication protocol has been confirmed or implemented. The workspace currently edits local mock effect blocks only.

## Product direction

1. **RigCanvas Controller** — cross-platform editor, preset library, asset manager, setlists, and performance controller for verified hardware capabilities.
2. **RigCanvas Desktop Rack** — optional Windows software audio engine for original DSP, stereo/parallel routing, neural capture playback, cabinet processing, and VST3 hosting.

The Controller and Desktop Rack are separate capability targets. Software-only blocks must never be sent to a physical pedal that cannot execute them.

## Repository layout

- `app/` — Flutter Windows/Android application.
- `docs/architecture/` — architecture and engineering decisions.
- `docs/hardware/` — KPT Pro compatibility notes.
- `docs/device-discovery/` — safe protocol-research procedure.
- `docs/roadmap/` — staged milestones and acceptance criteria.
- `engine/` — reserved for a future native C++ audio engine.

## Technology direction

- Flutter / Dart for the shared Controller UI.
- Narrow device gateway abstraction between UI and USB/Bluetooth adapters.
- Local-first preset and setlist persistence (SQLite/Drift candidate).
- Kotlin and Android USB/Bluetooth APIs for Android-specific communication.
- Native Windows USB APIs behind a Windows adapter.
- Separate native C++ engine for real-time Windows audio processing.
- VST3 hosting only after SDK and licensing review.

Flutter 3.50.0 is the current pinned CI toolchain at project initialization.

## Start the app

Install Flutter stable and the Android / Windows platform toolchains.

From the repository root:

```bash
cd app
flutter create --project-name rigcanvas --org com.rigcanvas --platforms=android,windows .
flutter pub get
flutter run -d windows
```

For Android, connect a developer-enabled device and run:

```bash
cd app
flutter run
```

The initial app opens in **Simulation Workspace**. Reordering blocks and toggling them changes local UI state only.

## Hardware safety

Do not flash firmware, replay undocumented traffic, or write unverified preset bytes to a physical pedal. Begin with read-only identification and observation of official software. See [KPT Pro compatibility](docs/hardware/KPT_PRO_COMPATIBILITY.md) and the [protocol investigation plan](docs/device-discovery/PROTOCOL_INVESTIGATION.md).

## Roadmap

See [the development roadmap](docs/roadmap/ROADMAP.md).

## Licensing

No open-source license is applied yet. Third-party SDKs, capture formats, trademarks, and bundled DSP assets must be reviewed before distribution.
