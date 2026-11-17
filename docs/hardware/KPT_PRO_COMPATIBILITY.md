# KPT Pro compatibility notes

**Status: physical BLE GATT profile and owner-provided firmware-v8 AMP/CAB inventory captured; application-level KPT Pro commands and preset protocol remain unverified.**

## Known test-unit baseline

| Field | Recorded value | Evidence / status |
|---|---|---|
| Device | YUIMER KPT Pro | User-confirmed target |
| Firmware display | v8 | User-reported on 2026-11-17; not independently read by RigCanvas |
| Hardware revision | Not recorded | Pending physical label / system information |
| USB VID/PID | Not recorded | Pending read-only inventory scan |
| M-EFCS application | v3.10.2311 | User-reported on 2026-11-17; user previously reported the app working with KPT Pro |
| BLE identity | `KPTPRO_BLE` advertisement; RSSI -54 dBm at capture | User-provided read-only report, 2026-11-17 |
| BLE-MIDI profile | Service `03B80E5A-EDE8-4B33-A751-6CE34EC4C700`; characteristic `7772E5DB-3868-4112-A1A9-F2669D106BF3` | Exact standard BLE-MIDI UUID pair; GATT reports write-without-response and notify |
| Vendor BLE service | `0000AE40-0000-1000-8000-00805F9B34FB`; TX `AE41`; RX `AE42` | UUIDs/properties observed; application payload protocol unknown |
| Transport protocol | BLE GATT with BLE-MIDI service and AE40 vendor service | GATT profile captured; MIDI/vendor command semantics remain unknown |

The firmware string is retained exactly as reported: v8. It must not be reinterpreted as 0.8, a build number, or another version format.

## Official firmware and software download evidence

The [TankPedal official download page](https://tankpedal.com/pages/download) currently exposes a KPT Pro firmware download labelled KPT PRO-011. The page does not provide a version-history table or a public mapping between that archive label and a pedal-displayed v8 value. RigCanvas must not assume that firmware v8 equals KPT PRO-011 or recommend flashing that archive to the user's unit.

The same official page states that:
- M-EFCS PC software for Windows/macOS supports TANK-G and TANK-B and connects by USB.
- M-EFCS mobile apps for Android/iOS support TANK-G and TANK-B and connect wirelessly.
- M-EFCS 1.22 adds AM2 import for TANK-G and TANK-B.
- A separate KPT Pro firmware download and KPT Pro manual are listed.

The [KPT Pro manual](https://www.manualslib.com/manual/3679532/Yuimer-Kpt-Pro.html) discusses PC/mobile software support for the KPT Pro, but the current official download page does not explicitly list KPT Pro among the stated M-EFCS supported devices. This is an unresolved vendor-documentation gap, not proof of incompatibility. Do not assume TANK-G/TANK-B protocol packets, preset formats, firmware images, or bootloader behavior are compatible with KPT Pro.

## M-EFCS version evidence

The owner reports using **M-EFCS v3.10.2311** with the KPT Pro firmware-v8 unit and confirms that the app connects. The public M-EFCS App Store history separately lists a 3.10.2016 release adding KPT Pro A2 support and a later 3.10.2314 release with device-support and parameter/snapshot synchronization improvements. This reinforces that KPT Pro is supported in the 3.10 app series, but it does not expose the BLE command protocol. See the [M-EFCS App Store version history](https://apps.apple.com/us/app/m-efcs/id6470352068).

## Owner-provided factory AMP/CAB inventory — firmware v8

The owner supplied the following names from the physical KPT Pro menu on 2026-11-17. They are recorded exactly as supplied, including abbreviations, spacing, and spelling. These are user-provided menu observations, not a manufacturer-published parameter specification.

**AMP model types:** `CL` = Clean, `OD` = Overdrive, `DS` = Distortion. RigCanvas stores that prefix as structured amp-type metadata, displays both the full type and short code, and exposes a type filter in the AMP picker.

**AMP names (50):**

`CL-UWETWINS, CL-UKC30, OD-MARVM410, OD-MARVICTO, DS-BRITPLEX, DS-MARSFD100, DS-EAGLES, DS-DISELHGN, DS-PVEV5150, CL-FORTIN, CL-MESSMKT, CL-CA-TWEED, CL-BOGSV20, DS-JUICEJIM, DS-SURSL68, CL-BOGBLUE, CL-BOGSH20, DS-BOGES20, CL-MESASTAR, DS-MESADR, CL-FEN65, OD-FEN65P, CL-FENRED, OD-FENFTMAN, CL-MARJ800, OD-MARJ900, DS-MARJ2000, DS-MAR2555, OD-MARSV20, CL-OGTB50, OD-OGRK30, DS-OGOR120, OD-SURSL68, OD-SURBR35, OD-ENGPB2, DS-ENGMK60, CL-PEY6534, DS-PEY6505, OD-RLAN120, OD-SOLD100, OD-SOLDH25, OD-DIEV4C2, DS-DIEV4C3, DS-VITRYSK, CL-TWORC, OD-FMAN100, CL-GOJAX, OD-VXAC30, CL-FOTINCA, CL-MATDC30`

**CAB names (50):**

`EAGLPROV30S, SPERIMENTAL, JUICE4X12V30, MESS BOG, FDCHAMP, FDPRJUNIR, MAR960BV30, DIZZLV30, ELCTROVOICE, MESSRECTV30, TWINJENSENC, TWEDDLX1X12, FENDSHOWMAN, J120ROLND, AC30SILVERS, FENDELU, FENBFACE, FENMNTW, FENBMAN, FENPRIN2, FENPROJ, MESSOS, MESSBRO, MESSLM24, MESSSTDIO, MESSSTITO, MESSNOM, MAR36, MARMG15R, MARJ2000, MARMFOUR, MARPLX, MARVAL4, MARVAL2, ENG412, ENG412P, OGP212, PEY5150, PEYDEBLU, SOLDHOR, SOLDSC12, SOLDANG412, SOLDSC412, ALTON212, BOGUX, DIEV30, FIMANVT, HABTONV, VXAC15, VXAC30`

RigCanvas preserves the existing `kpt.amp.guitar.0–49` and `kpt.cab.guitar.0–49` model IDs so earlier presets referencing these 50 slots continue to resolve. The previous manual's additional bass slots 51–60 are retained as manual-listed, but their availability and names have not been confirmed on this firmware-v8 unit. Do not treat those placeholder bass entries as confirmed device models.

The lists establish menu names and AMP type prefixes only. They do not establish device slot numbers, parameter ranges, MIDI CC/PC/SysEx mappings, BLE AE40 packet framing, or preset-file encoding.

## Manual-documented capabilities (not yet verified against firmware v8)

The available manual describes:
- Seven movable effect modules: FX, AMP, MOD, DLY, REV, CAB, and EXT.
- 7+1 simultaneous effects slots; this does not establish arbitrary parallel routing or an unrestricted plugin chain.
- 120 preset/timbre positions.
- 50 guitar and 10 bass preamp slots.
- 50 guitar and 10 bass cabinet slots.
- Third-party IR WAV and AM2 import.
- USB-C computer data/audio functionality and mobile OTG recording.
- 44.1 kHz / 24-bit audio specifications.
- Bluetooth music playback and an external expression/MIDI-controller expansion option in the manual.

These remain manual-level claims, not observations from the user's firmware-v8 unit. The manual's 7+1 language must not be interpreted as proof that RigCanvas can install new algorithms or arbitrary software blocks on the pedal.

## Factory effect inventory reported by the manual

| Module / category | Manual inventory | RigCanvas treatment |
|---|---|---|
| FX | AI Gate, Compress, F Compress, A Boost, B Boost, Boost OD; the manual also describes gate/boost/compressor combinations | Fixed catalogue entries; exact combination and slot rules await device verification |
| AMP | 60 slots in the manual: guitar 1–50, bass 51–60 | 50 owner-provided named entries; 10 additional manual-listed bass slots remain unverified on firmware v8 |
| MOD | Nine named entries: Chorus, Phaser, Tremolo, Flanger, Vibrato, Univibe, Autofilter, Wah-Wah, Sense-Wah | All nine detailed-list entries shown; overview/FAQ says eight, so firmware-v8 count is pending |
| DLY | Analog, Duck, dTape, Dual, Lofi | Fixed catalogue entries |
| REV | Room, Hall, Swell, Spring, Shimmer, Cloud | Fixed catalogue entries |
| CAB | 60 slots in the manual: guitar 1–50, bass 51–60 | 50 owner-provided named entries; 10 additional manual-listed bass slots remain unverified on firmware v8 |
| EXT | VOL, X-Wah, Funk-Wah, Slide-Wah, Cry-Wah | External-control options; not treated as standalone DSP blocks without device evidence |
| EQ | Overview mentions a 3-band EQ, but its position in the movable chain is unclear | Separately labelled overview-level option; not assumed to consume an extra module slot |

The manual's detailed MOD pages enumerate nine models while the overview/FAQ says eight. Its FX section describes selectable gate/boost/compressor combinations, so the catalogue must not imply that all six FX labels can occupy independent simultaneous slots. RigCanvas-expanded effect archetypes remain software-only and are not KPT Pro factory algorithms.

## Physical BLE/GATT inspection — 2026-11-17

A RigCanvas read-only inspection report supplied by the owner confirms a BLE peripheral advertising as `KPTPRO_BLE` (RSSI -54 dBm at capture). The report contains these services:

| Service / characteristic | Observed properties | Interpretation |
|---|---|---|
| Generic Access `1800` / Device Name `2A00` | Read, write | Standard GAP device-name characteristic; no value was read by this inspection |
| `AE40` / `AE41` | Write without response | Vendor-specific data-input candidate; payload framing is unknown |
| `AE40` / `AE42` | Notify; CCCD present | Vendor-specific data-output candidate; payload framing is unknown |
| BLE-MIDI `03B80E5A-EDE8-4B33-A751-6CE34EC4C700` / `7772E5DB-3868-4112-A1A9-F2669D106BF3` | Read, write without response, notify; CCCD present | Standard BLE-MIDI service and MIDI I/O characteristic |

The BLE-MIDI UUID pair is defined by the Bluetooth LE MIDI profile. This establishes a standard MIDI transport endpoint, not an editor protocol. MIDI messages may support performance/control use, but the GATT profile alone does not identify which MIDI messages (if any) change KPT Pro effects, parameters, presets, or chain order.

The `AE40/AE41/AE42` topology resembles a generic BLE UART/data-tunnel layout seen in other products. That similarity is only a research clue. It does not establish that the KPT Pro uses another product's framing, opcodes, checksums, block IDs, or preset memory map. Do not copy or replay packets from M-VAVE Blackbox, Tank-G, Tank-B, MK-300, or other devices as if they were KPT Pro commands.

The inspection did not read vendor characteristics, subscribe to notifications, or send GATT writes. Standard Device Information service `180A` was absent, so manufacturer/model/firmware/hardware identity values were not available from the standard allowlist. The BLE peripheral name is not proof of hardware revision or firmware version.

**Next evidence:** record the pedal hardware revision, then—using the owner-reported working M-EFCS v3.10.2311 pairing—capture a private Bluetooth trace of an ordinary read-only refresh and separately identify any BLE-MIDI performance messages. Do not share serial numbers, personal preset content, or unredacted private captures in the public repository.

## RigCanvas read-only USB discovery

The shared Devices screen collects local USB inventory only:
- Android uses the USB Host API to list attached devices and their exposed interface/endpoint descriptors.
- Windows uses SetupAPI to list present USB Plug-and-Play records and extract VID/PID, friendly name, manufacturer, and class. Full Windows USB configuration/interface/endpoint descriptor capture is not included in the first adapter.
- Neither adapter opens the USB device for communication, requests a USB permission grant, sends control/bulk/interrupt transfers, reads presets, sends MIDI/SysEx, or changes device memory/firmware.
- The app does not guess which VID/PID belongs to the KPT Pro. Identification requires a scan while the pedal is connected and manual confirmation of the matching record.
- Device serial numbers are deliberately not collected in the inventory report.

## Required next evidence

1. Run RigCanvas → Devices → Scan USB devices while the KPT Pro is connected with a known data-capable USB cable.
2. Copy the inventory report and identify the KPT Pro record. Do not share device serial numbers.
3. Preserve the owner-reported M-EFCS v3.10.2311 version and working KPT Pro pairing as the baseline; record the operating system and app connection steps.
4. Record the hardware revision printed on the pedal label or shown in its system information, if available.
5. Compare the physical firmware-v8 unit's AMP/CAB slot counts, MOD count, REV choices, and effect-slot behavior against the manual.
6. Capture full Windows USB configuration/interface/endpoint descriptors separately if Windows is the test platform.
7. Only after identity and descriptors are confirmed, document a read-only protocol exchange. Do not issue unverified commands or writes.

## Hardware safety gate

Before enabling a KPT Pro device profile or preset operation, record and verify:
1. Exact model label and hardware revision.
2. Firmware version as displayed on the physical unit (owner-reported v8; direct RigCanvas readback not available yet).
3. Official editor/app version and actual device-recognition result (owner-reported M-EFCS v3.10.2311 working with KPT Pro).
4. USB VID/PID, interface descriptors, endpoints, and OS descriptors.
5. Wireless transport type and service/profile details, if applicable.
6. Read-only identity exchange and response format.
7. A known-good preset export format and checksum behavior.
8. Separate read/write operations, backup/restore procedure, and safe verification behavior.

A capability is not supported until it has been tested on the physical KPT Pro with its exact firmware/app combination documented. Factory catalogue membership does not establish device write support or exact audio-model behavior.
