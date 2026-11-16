# Architecture overview

## One product, two target operating systems

RigCanvas is one application delivered for Android and Windows. Both builds must have the same user-facing feature set, navigation destinations, workflows, preset and scene behavior, asset management, and performance tools.

The Flutter UI, domain models, validation rules, preset codecs, and application state are shared. Responsive navigation may adapt to screen width (bottom navigation on compact layouts, a navigation rail on wide layouts), but this must not remove or hide a product feature on either platform.

Operating-system-specific code is limited to adapters for native capabilities such as audio I/O, file access, USB, and Bluetooth. A feature that depends on a native capability must still have an equivalent workflow on both targets before release. If equivalent support is not practical, defer that feature on both rather than shipping a Windows-only feature.

The app must not imply that a software feature is available inside the KPT Pro unless the exact firmware and communication protocol prove it. The shared software workspace remains separate from physical-pedal capabilities.

## High-level layers

```text
Flutter UI
  ├── Workspace / Presets / Asset Library / Gig View
  ├── Application state and validation
  ├── Domain models (preset, block, scene, asset)
  └── Device gateway interface
         ├── Demo gateway (first implementation)
         ├── KPT Pro USB adapter (not implemented)
         └── KPT Pro wireless adapter (not implemented)

Shared native audio engine (Android + Windows)
  ├── Common DSP graph, nodes, and routing
  ├── Shared amp-capture and cabinet processing
  └── Platform audio I/O adapters
         ├── Android audio backend
         └── Windows audio backend
```

## Boundaries

- UI code must not encode USB or Bluetooth packet formats.
- Device adapters implement typed operations and report unsupported capabilities.
- Preset files are versioned and validated before import.
- Hardware writes require a verified backup and an explicit user action.
- The mock gateway is the default until device compatibility is demonstrated.
- The shared audio engine runs outside Flutter's UI thread and must not allocate or block in its real-time callback.
- The same audio/DSP capabilities and parameter behavior must be available on Android and Windows; only the low-level device I/O adapters may differ.
- Do not ship Windows-exclusive app features. Defer features that cannot be delivered equivalently on both target operating systems.

## Target-aware graphs

A preset should eventually contain:
- Stable ID and schema version.
- Name, description, tags, and optional song/setlist references.
- Ordered effect blocks.
- Block enable states and typed parameters.
- AMP/AM2 and IR references with checksums and format metadata.
- Optional scene snapshots and control assignments.
- Device target and capability requirements.

The local software workspace can represent richer graphs than the physical device. Every graph must declare its target: `softwareRack` or a verified hardware capability profile.

## Persistence

Start local-first. Preset drafts and setlists should work offline. Device synchronization is a separate operation with visible read/write status. SQLite is the current candidate for structured metadata; larger IR/capture assets should remain file-backed and be referenced by checksum.

## Error handling

Device operations must report typed outcomes such as:
- disconnected
- unsupported device or firmware
- permission denied
- protocol mismatch
- invalid payload
- transfer failed
- verification failed

Never show a successful hardware write when an operation failed or was not actually sent.
