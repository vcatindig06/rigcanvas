# Engineering decisions

## ADR 0001 — Flutter for the shared Controller UI

**Status:** accepted.

Flutter provides a shared UI codebase for Android and Windows. Platform-specific communication stays behind adapters, so UI code does not own USB/Bluetooth implementation details.

A separate native C++ engine is reserved for the Windows Desktop Rack because real-time audio processing has different latency and scheduling requirements from UI work.

## ADR 0002 — No undocumented KPT Pro writes

**Status:** accepted.

The first release uses a local simulation. Device writes remain unavailable until the exact model/firmware protocol is verified, read/write transactions are understood, and backup/restore behavior is tested.

## ADR 0003 — Two product capability profiles

**Status:** accepted.

The local software workspace may represent richer graphs than the hardware pedal. Every future preset/graph must declare a target:
- `kptPro:<verified-profile>`
- `softwareRack:<version>`

A software-only block must never be silently sent to hardware that cannot execute it.

## ADR 0004 — Local-first project data

**Status:** accepted.

Preset drafts and setlists should work offline. Device synchronization is explicit. Metadata is stored locally; large IR/capture assets remain files referenced by checksum and format metadata.

## Future decision — desktop audio framework

JUCE is a candidate for the C++ audio engine and VST3 host, but JUCE is dual-licensed under AGPLv3 or a commercial license. The final framework and license must be decided before the project depends on it. See the [official JUCE repository](https://github.com/juce-framework/JUCE).
