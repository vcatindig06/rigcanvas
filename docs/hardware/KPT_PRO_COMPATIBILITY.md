# KPT Pro compatibility notes

**Status: research in progress. Hardware protocol and firmware-specific support are not verified.**

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

The vendor's [TankPedal download page](https://tankpedal.com/pages/data-sharing-opt-out) lists its M-EFCS PC and mobile downloads as supporting **TANK-G and TANK-B**, and describes PC USB and mobile wireless connections. The page separately lists KPT Pro firmware and the KPT Pro user manual.

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

This does **not** prove that KPT Pro is incompatible with M-EFCS. It means the exact KPT Pro firmware, M-EFCS build, and transport protocol must be identified before writing a KPT Pro adapter.

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

A capability is not supported until it is tested on the physical KPT Pro and documented with firmware/app versions.
