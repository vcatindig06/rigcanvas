# KPT Pro compatibility notes

**Status: M-EFCS compatibility is user-confirmed; RigCanvas hardware protocol and firmware-specific support remain unverified.**

## User-confirmed compatibility baseline

- On 2026-11-17, the user confirmed that the latest installed M-EFCS version works with their KPT PRO.
- The pedal firmware is reported by the user as **v15**; RigCanvas has not independently read this version.
- The exact M-EFCS version/build number has not yet been captured.
- The KPT Pro mobile-app instructions say to enable BT on both the phone and pedal, select **KPT PRO** as the current device in M-EFCS, and scan nearby devices. This points to wireless discovery, but does not identify BLE versus Bluetooth Classic or reveal GATT UUIDs/commands.
- RigCanvas now performs BLE advertisement scanning only on Android and Windows; it does not connect, read characteristics, or write to the pedal.

## Documentation findings

The KPT Pro manual hosted by Manuals+ describes:
- M-EFCS computer control for adjusting module parameters and moving modules in the signal chain.
- Preset save, swap, import, and export.
- AM2 data import and third-party IR import.
- Seven movable effect modules in the signal chain.
- 120 preset/timbre slots arranged as 40 banks of three.
- USB sound-card operation and mobile OTG recording.
- ANN-based timbre cloning that produces AM2 files.

Sources:
- [KPT Pro user manual mirror](https://manuals.plus/ae/1005009814096903), particularly sections 6.5–6.6 and 6.11–6.15.
- [KPT Pro user manual PDF mirror](https://manuals.plus/yuimer/kpt-pro-guitar-pedal-manual.pdf).

The vendor's [TankPedal download page](https://tankpedal.com/en-asia/pages/download) lists its M-EFCS PC and mobile downloads as supporting **TANK-G and TANK-B**, while separately listing KPT Pro firmware and manual downloads. This public list appears incomplete or stale relative to the user's direct confirmation that the latest installed M-EFCS works with KPT PRO.

## Documented KPT Pro effect catalogue

The KPT Pro manual mirror's effect catalogue identifies these module families and names. This is a source-backed starting catalogue, not a complete parameter schema or proof that every item is exposed by every firmware revision.

| Module | Documented catalogue |
|---|---|
| FX | AI Gate, Compress, F Compress, A Boost, B Boost, Boost OD |
| AMP | 50 guitar amp models and 10 bass amp models; individual model names and parameter maps still need verified source data |
| MOD | Chorus, Phaser, Tremolo, Flanger, Vibrato, Univibe, Autofilter, Wah-Wah, Sense-Wah |
| DLY | Analog, Duck, dTape, Dual, Lofi |
| REV | Room, Hall, Swell, Spring, Shimmer, Cloud |
| CAB | 50 guitar cabinet IRs and 10 bass cabinet IRs; individual names and parameter maps still need verified source data |
| EXT | VOL, X-Wah, Funk-Wah, Slide-Wah, Cry-Wah |

Source: [KPT Pro Multi-Effects Pedal manual mirror](https://manuals.plus/ae/1005008910756720).

### Catalogue implementation rules

1. Keep the KPT Pro factory catalogue distinct from RigCanvas software-only effect models.
2. Represent module family, effect display name, source evidence, and verification status as separate data.
3. Do not invent individual amp/cab model names, parameter ranges, defaults, or effect algorithms when the available source does not publish them.
4. Do not claim that a RigCanvas effect can be installed on the KPT Pro. Physical-device support requires a verified firmware capability and protocol.
5. Preserve the distinction between a factory model, an imported AM2 capture, and a third-party cabinet IR.
6. Keep the same catalogue and user-facing workflows on Android and Windows.

## Compatibility conclusion

There is a documentation discrepancy:
- The KPT Pro manual describes M-EFCS control for KPT Pro.
- The vendor's general download page labels its M-EFCS binaries as supporting Tank-G and Tank-B.

The user's successful M-EFCS use confirms practical compatibility for their KPT PRO setup. The exact M-EFCS build and control transport still need to be recorded, and RigCanvas must independently verify the device protocol before implementing control.

Do not assume Tank-G packets, firmware, preset files, or bootloader behavior are compatible with KPT Pro.

## Documented capability indicators

| Area | Current documentation | Confidence |
|---|---|---|
| USB-C | USB audio / PC connection described | Manual-level evidence |
| Wireless | Mobile app connection described | Transport still unknown |
| M-EFCS editor | Computer control described in KPT Pro manual | Needs app/version confirmation |
| Presets | 120 slots / 40 banks × 3 | Manual-level evidence |
| Signal chain | Seven effect modules can be selected and reordered | Manual-level evidence |
| AM2 | KPT Pro manual describes importing AM2 captures | Manual-level evidence |
| IR | Third-party IR WAV import described | Manual-level evidence |
| New DSP blocks | No public evidence that arbitrary algorithms can be installed | Not established |
| Arbitrary parallel routing | Not established | Unknown |
| Native scene snapshots | Not established by sources reviewed | Unknown |



## Test device baseline — user reported

- **Device firmware:** v15 (reported by the user on 2026-11-17).
- **Verification status:** user-reported; not independently read from the physical device by RigCanvas.
- **Firmware package mapping:** unresolved. The official download page provides a KPT PRO firmware-upgrade download but does not publish a visible version mapping in the page text. Do not equate the user's display value `v15` with the separate manual mirror's `KPTPRO007` label without confirming the device's About/System screen and the firmware package metadata.
- **Next hardware discovery:** identify the exact M-EFCS application version and confirm whether it lists/connects to KPT PRO; then capture USB descriptors from the user's Windows PC. The official TankPedal download page currently labels the listed M-EFCS PC and mobile builds as supporting TANK-G/TANK-B, and says PC uses USB while mobile uses wireless. This support-list limitation must be resolved for KPT PRO before using M-EFCS as a protocol oracle.

Official vendor source: [TankPedal download page](https://tankpedal.com/en-asia/pages/download). The page separately lists a KPT PRO firmware upgrade and KPT PRO manual, but its M-EFCS PC/mobile support labels name TANK-G and TANK-B. This is a documented discrepancy, not proof of incompatibility.

### Discovery task order for firmware v15

1. On the pedal, photograph or transcribe the complete firmware/version screen (including any suffix/build identifier).
2. Record the exact M-EFCS version installed and whether KPT PRO appears in its device selector.
3. If M-EFCS recognizes the pedal, first perform a read-only connection and record the device identity; do not initiate firmware update, factory reset, preset write, or import.
4. On Windows, capture USB VID/PID, interface descriptors, endpoints, and device strings while connecting the powered-on pedal.
5. Compare observations only against this same firmware v15 device. Treat other KPT Pro revisions and Tank-G/Tank-B as separate profiles until proven compatible.

## Hardware compatibility gate

Before enabling a KPT Pro device profile, record and verify:
1. Exact model label and hardware revision.
2. Firmware version shown by the pedal.
3. M-EFCS application version and its device list.
4. BLE advertisements: local name, OS-provided identifier, RSSI, and advertised service UUIDs; then establish BLE versus Bluetooth Classic.
5. USB vendor/product IDs, interfaces, endpoints, and OS descriptors if Windows M-EFCS uses USB for control.
6. Wireless service UUIDs and characteristics only after a verified connection path is identified.
7. A read-only device identification exchange.
8. A known-good preset export/import format and checksum behavior.
9. Whether read and write operations are distinct and whether writes can be safely verified.

A capability is not supported until it is tested on the physical KPT Pro and documented with firmware/app versions.
