# KPT Pro compatibility notes

**Status:** KPT Pro firmware v8 and M-EFCS v3.10.2311 have been reported by the user. The user also reports that M-EFCS works with the KPT Pro. RigCanvas has not yet independently enumerated the device or verified its communication protocol.

## User-reported test baseline — 2026-11-17

| Item | Value | Evidence |
|---|---|---|
| Device | KPT Pro | User-reported |
| Firmware | v8 | User-reported |
| Official M-EFCS build | v3.10.2311 | User-reported |
| Official M-EFCS operation | Works with KPT Pro | User-reported; not a RigCanvas protocol trace |
| Hardware revision | Not recorded | Unknown |
| USB VID/PID | Not captured | Unknown |
| USB interfaces/endpoints | Not captured | Unknown |
| Wireless transport | Not identified | Unknown |

These values establish the baseline for further testing; they are not a claim that RigCanvas can connect to or control the pedal.

## Documentation findings

The KPT Pro manual hosted by Manuals+ describes:
- M-EFCS computer control for adjusting module parameters and moving modules in the signal chain.
- Preset save, swap, import, and export.
- AM2 data import and third-party IR import.
- Seven effect modules in the stomp chain.
- 120 preset/timbre slots arranged as 40 banks of three.
- USB sound-card operation and mobile OTG recording.
- ANN-based timbre cloning that produces AM2 files.

Source: [KPT Pro user manual mirror](https://manuals.plus/ae/1005009814096903), particularly sections 6.5–6.6 and 6.11–6.15.

The vendor's [TankPedal download page](https://tankpedal.com/pages/data-sharing-opt-out) lists its M-EFCS PC and mobile downloads as supporting **TANK-G and TANK-B**, and describes PC USB and mobile wireless connections. The page separately lists KPT Pro firmware and the KPT Pro user manual.

## Compatibility conclusion

There is a documentation discrepancy:
- The KPT Pro manual describes M-EFCS control for KPT Pro.
- The vendor's general download page labels its M-EFCS binaries as supporting Tank-G and Tank-B.

The user's successful M-EFCS v3.10.2311 / KPT Pro firmware v8 test is positive device-specific evidence that the official application works with this setup. It does **not** establish the USB message format, Bluetooth transport, public protocol availability, or permission to reuse Tank-G/Tank-B packet definitions.

Do not assume Tank-G packets, firmware, preset files, or bootloader behavior are compatible with KPT Pro.

## Documented capability indicators

| Area | Current documentation | Confidence |
|---|---|---|
| USB-C | USB audio / PC connection described | Manual-level evidence |
| Wireless | Mobile app connection described | Transport still unknown |
| M-EFCS editor | User reports M-EFCS v3.10.2311 works with KPT Pro | User-reported device test |
| Presets | 120 slots / 40 banks × 3 | Manual-level evidence |
| Signal chain | Seven effect modules can be selected and reordered | Manual-level evidence |
| AM2 | KPT Pro manual describes importing AM2 captures | Manual-level evidence |
| IR | Third-party IR WAV import described | Manual-level evidence |
| New DSP blocks | No public evidence that arbitrary algorithms can be installed | Not established |
| Arbitrary parallel routing | Not established | Unknown |
| Native scene snapshots | Not established by sources reviewed | Unknown |

## Hardware compatibility gate

Before enabling a KPT Pro device profile, record and verify:
1. Exact model label and hardware revision.
2. Firmware version shown by the pedal.
3. M-EFCS application version and its device list.
4. USB vendor/product IDs, interfaces, endpoints, and OS descriptors.
5. Wireless service UUIDs and characteristics, if Bluetooth Low Energy is used.
6. A read-only device identification exchange.
7. A known-good preset export/import format and checksum behavior.
8. Whether read and write operations are distinct and whether writes can be safely verified.

A capability is not supported until it is tested on the physical KPT Pro and documented with firmware/app versions and repeatable evidence. See the [USB descriptor capture checklist](../device-discovery/USB_DESCRIPTOR_CAPTURE.md) for the next safe collection step.
