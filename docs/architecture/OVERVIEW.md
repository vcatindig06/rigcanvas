# Architecture overview

## Product split

RigCanvas has two related but deliberately separate products:

1. **RigCanvas Controller** — a Windows/Android editor, preset library, and performance controller for a supported physical device.
2. **RigCanvas Desktop Rack** — an independent Windows software audio processor. It may eventually host original effects, amp models, cabinet processing, neural capture playback, and VST3 plugins.

The Controller must not imply that a feature is available inside the KPT Pro unless the firmware and communication protocol prove it. The Desktop Rack can provide advanced processing independently of pedal firmware.

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

Optional Windows audio process
  ├── Audio I/O and device selection
  ├── DSP graph and routing
  ├── Effect / amp / cabinet nodes
  ├── Neural capture runtime
  └── VST3 host
```

## Boundaries

- UI code must not encode USB or Bluetooth packet formats.
- Device adapters implement typed operations and report unsupported capabilities.
- Preset files are versioned and validated before import.
- Hardware writes require a verified backup and an explicit user action.
- The mock gateway is the default until device compatibility is demonstrated.
- The future audio engine runs outside Flutter's UI thread and must not allocate or block in its real-time callback.

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
