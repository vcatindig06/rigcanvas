# KPT Pro Patch Control — Evidence and Implementation Plan

**Priority:** highest active product milestone  
**Hardware baseline reported by owner:** YUIMER KPT PRO, firmware display v8  
**Official editor reported by owner:** M-EFCS Android v3.10.2311  
**Target platforms:** Android and Windows, with one shared patch model and equivalent workflows

## Goal

Implement actual KPT Pro hardware operations in RigCanvas:

1. Read the device's preset slots and download a complete patch backup.
2. Edit the real KPT Pro module chain and its real per-model hardware parameters.
3. Save the edited patch to a selected device slot and verify it by reading it back.
4. Import and export native KPT Pro tone/preset files, while separately supporting AMP capture/AM2 and CAB IR assets where their formats are confirmed.

This is not the same as editing an offline RigCanvas simulation. The four-row/eight-slot Grid and the generic offline DSP engine are local software features. The KPT Pro manual describes a different hardware chain.

## What is documented

The KPT Pro manual describes 120 preset-tone storage slots, with the first 54 populated by factory tones by default. It names seven reorderable effect modules: FX, AMP, MOD, DLY, REV, CAB, and EXT. It also describes editing and exchanging tone data through supporting computer/mobile software, importing/exporting tone data, importing IRs, and importing AMP module tone data. The manual separately mentions AM2 data and third-party IR imports. [KPT Pro manual](https://manuals.plus/yuimer/kpt-pro-guitar-pedal-manual.pdf)

The manual's “7+1 effects” wording and the exact data representation for the extra effect are not resolved by the available documentation. The patch model must be based on captured device data, not an assumed eighth block.

The M-EFCS App Store version history states that version 3.10.2016 added A2 support for MK20, TANK PRO, and KPT PRO, and version 3.10.2314 included parameter synchronization improvements. The owner's installed Android version is reported as 3.10.2311. This supports the existence of KPT Pro support in the M-EFCS 3.10 series, but “A2 support” is a device-support note; it does not establish a patch-file extension or binary schema. [M-EFCS App Store version history](https://apps.apple.com/us/app/m-efcs/id6470352068)

There is an official-documentation discrepancy: the current TankPedal download page describes M-EFCS PC and mobile downloads as supporting TANK-G/TANK-B, while the App Store history names KPT PRO A2 support. The physical unit and the owner's working M-EFCS build are therefore the relevant test baseline; do not infer protocol compatibility from a different TANK model. [TankPedal downloads](https://tankpedal.com/pages/download)

## What RigCanvas currently proves

### GATT profile evidence

An earlier owner-provided read-only GATT report recorded:
- Vendor service UUID `0000AE40-0000-1000-8000-00805F9B34FB`.
- Characteristic AE41 with Write Without Response.
- Characteristic AE42 with Notify.
- Standard BLE-MIDI service and characteristic UUIDs.

This profile was inventoried, but no vendor characteristic read, notification subscription, or vendor write was performed in that inspection. The AE40 service is a vendor-transport candidate; its command grammar is not implied by its UUID or properties.

### Payload-enabled ATT trace (2026-11-17)

The documented selected connection contains 330 ATT events:
- 1 Write Request, 157 Write Commands, and 165 Handle Value Notifications.
- Phone-to-pedal writes repeatedly target ATT handle `0x0062`.
- Pedal-to-phone notifications repeatedly target ATT handle `0x0064`.
- One acknowledged Write Request targets `0x0065` with value `01 00`.
- Notification payloads include the ASCII token `KPTPRO_008`.
- Repeated payload prefixes include `00 59 11` and `00 59 23`.

Important limitations:
- The report has no successful service/characteristic declaration map. Do not label `0x0062` as AE41 or `0x0064` as AE42 based on this trace alone.
- The meaning of the recurring byte sequences is unknown. The trace did not time-correlate them to an edit, save, slot change, or import action.
- The two uploaded text reports were identical duplicates of one capture, not independent action traces.
- The larger binary notification was not decoded into parameter IDs, types, ranges, or values.

Source analysis: [Payload-enabled trace analysis](PAYLOAD_ANALYSIS_2026-11-17.md) and [Protocol investigation](PROTOCOL_INVESTIGATION.md).

## Confirmed outer-frame parser milestone — 2026-11-18

The existing 2026-11-17 payload capture has now been independently checked byte by byte. All 157 complete phone-to-pedal vendor frames and all 157 complete pedal-to-phone frames match the observed envelope: magic `00 59`, one command byte, a two-byte little-endian body length, a reserved byte (observed `00`), body bytes, and a one-byte checksum equal to the 8-bit complement of the body-byte sum. The two 848-byte response bodies are fragmented across five BLE notifications each and reassemble using the declared total length. A pure Dart parser/reassembler and tests have been added; it has no BLE transport, no command encoder, and cannot send data to the pedal. The Devices screen also applies the parser to imported selected-connection ATT values and reports direction/handle-scoped raw command counts, frame lengths, ATT frame ranges, capture offsets, invalid candidates, and incomplete streams; command meanings remain undecoded. Details: [KPT Pro BLE frame format](KPT_PRO_FRAME_FORMAT.md).

A second read-only analysis pass found that the two recurring eight-byte phone-to-pedal `0x23` bodies (76 occurrences each) split into two 32-bit little-endian words with the same f1/f2 bit-packing shape used in the separate Tank-G Control Center reverse-engineering project. The comparison-only slices are:

- `04 00 00 00 20 38 00 00` → F1 `0x00000004`, F2 `0x00003820`; candidate fields memory `0x04`, 24-bit address `0x000000`, length `56`, space `2`.
- `04 00 00 60 70 0A 00 00` → F1 `0x60000004`, F2 `0x00000A70`; candidate fields memory `0x04`, 24-bit address `0x600000`, length `10`, space `7`.

This is a strong structural match, not confirmation of Tank-G semantics on KPT Pro. The parser/UI retain the entire words and full 24-bit address candidate, apply the slices only to phone-to-pedal `0x23` ATT transfers, label every slice as a hypothesis, and do not call command `0x23` a read. The candidate extraction is covered by tests and included as metadata in the optional trace export.

This result does not decode command semantics, preset slots, native patch storage, GATT UUID mapping, or write/commit behavior; the f1/f2 slices remain comparison-only candidates. The controlled action-correlated M-EFCS trace and native test export remain necessary before implementing even a device-side read operation.

## Alternative path when no new HCI capture is available

RigCanvas now includes an optional **passive vendor-notification monitor**. After a fresh BLE connection and runtime GATT discovery, it checks for the reported AE40 service and AE42 characteristic. If AE42 advertises Notify or Indicate, the user can explicitly start monitoring.

- The monitor listens for AE42 notification values and applies the existing offline `00 59` frame parser/reassembler.
- Enabling a BLE notification subscription configures the characteristic's Client Characteristic Configuration Descriptor (CCCD). It does **not** send a KPT vendor command, read a vendor value, or write a preset.
- Raw values and validated frame envelopes can be copied from the Devices screen. Command bytes remain uninterpreted.
- Monitoring is opt-in, stops on disconnect, and does not transmit requests. It may reveal device-initiated model catalogs, state updates, or other unsolicited data if the firmware emits them.

**Limit:** if the KPT Pro only sends patch data in response to an M-EFCS request, passive monitoring will not retrieve those patches. This route cannot replace request/response correlation, patch read, save, import, or export evidence.

A second non-capture avenue is static inspection of an officially distributed M-EFCS APK/desktop package for public resource names, device identifiers, model tables, and protocol call structure. RigCanvas must use independently implemented interoperability code and must not copy proprietary app code or redistribute factory preset dumps. A package can be analyzed only when its binary itself is available; public store metadata does not disclose its internal protocol implementation.

## Capture-free implementation milestone — 2026-11-18

The Control Center now has a supported workflow that can advance without another BTSnoop/HCI capture:

- **Local preset-library backup:** RigCanvas exports every local preset, scene snapshot, and Grid layout into one RigCanvas JSON backup. The schema version is recorded, and imported asset payload files are explicitly marked as not included. This is a local recovery copy only; it is not a KPT Pro backup, is not accepted by M-EFCS as a native patch, and does not contain NAM/AM2/IR file contents.
- **Write-readiness preview:** a metadata-only planner summarizes the selected local preset and lists protocol, native-schema, transaction, recovery, and test-fixture blockers. It does not generate bytes and has no hardware-write method.
- **Control Center UX:** a new Settings entry provides the local-backup action, a visible hardware-write lock, manual hardware references, and capture-free investigation routes. The same Flutter screen is shared by Android and Windows.
- **No protocol borrowing:** Tank-G Control Center is used only as a workflow reference (preset organization, backups, before/after review, and explicit transfer status). Its f1/f2 layout remains a comparison hypothesis only; no Tank-G memory IDs, address units, preset schema, command IDs, or write transaction is copied.

### Capture-free route order

1. **Passive BLE observation:** use the existing BLE discovery and opt-in notification monitor. It sends no vendor request and may collect unsolicited state/catalog notifications only; it cannot force a patch read if the pedal is request-driven.
2. **Official M-EFCS package inspection:** when the exact owner-provided or officially distributed APK/desktop package is available, inspect non-secret resources, device identifiers, model tables, file extensions, and call structure. Record observations as observed/inferred/unknown. Implement independent interoperability code; do not copy M-EFCS code or redistribute proprietary preset content. This package has not been inspected in this milestone.
3. **Native tone export analysis:** a genuine M-EFCS-exported whole-patch file can be analyzed without HCI. Preserve its original name, extension, and bytes. First identify whether it is a complete preset/tone, AM2 AMP data, or CAB IR. No native whole-patch fixture is currently available in the repository.
4. **Manual UI parameter inventory:** record each hardware module/model, displayed parameter label, unit, and range. This informs a separate KPT Pro editor, but does not reveal command IDs or prove write support.

### Current implemented boundary

The Control Center exports a RigCanvas local preset-library backup and shows a metadata-only write-readiness preview. It cannot read device slots, download a hardware backup, translate a RigCanvas graph into a KPT Pro patch, encode vendor commands, save to the pedal, or import/export native KPT Pro tone files. Vendor writes remain disabled on Android and Windows.

## Tank-G protocol comparison — 2026-11-18

The public Tank-G Control Center research repository provides a detailed, separately verified Tank-G protocol record in `research/FINDINGS.md`. It documents the Tank-G / Tank-Gv2 BLE operations as follows: command `0x23` reads, command `0x22` writes, memory `4` contains preset records, and Tank-G uses its own spaces for bank data, live editing, status, commit, and preset selection. Its preset bank is a 758-byte structure with 36 records of 21 bytes. These are **Tank-G-only findings** from that project's hardware and firmware; they are not a KPT Pro memory map. [Tank-G Control Center research](https://github.com/CamiloFerreira/tankg-control-center/blob/main/research/FINDINGS.md)

The comparison is useful precisely because it prevents unsafe assumptions:

| Feature | Tank-G / Tank-Gv2 research | KPT Pro evidence available to RigCanvas |
|---|---|---|
| BLE vendor framing | `00 59` envelope and field words | Matching outer envelope independently validated against the supplied KPT trace |
| `0x23` meaning | Read operation on Tank-G | Repeated KPT traffic exists, but its meaning is uncorrelated with a user action |
| Write command | `0x22` on Tank-G | No KPT-specific write command has been established |
| Preset memory | Memory `4`, 36 × 21-byte records | Field-slice candidates appear in two KPT `0x23` bodies; no slot schema or record length is known |
| Space values | Tank-G spaces `0`, `1`, `2`, `E`, and `F` have documented Tank-G meanings | KPT candidate spaces include `2` and `7` with candidate lengths 56 and 10; semantics are unknown |
| Save/commit | Tank-G commit and read-back procedure verified on Tank-G | KPT acknowledgement, commit, read-back, and recovery are unverified |

Therefore, neither Tank-G's `0x23 = read` nor `0x22 = write` mapping is copied into the KPT Pro implementation. In particular, the KPT candidate with space `2` and length `56` does not match the Tank-G research's four-byte status shape. This is a concrete mismatch, not evidence that either protocol is wrong.

### Product workflow adopted as design guidance only

The Tank-G Control Center documents a full-bank backup before writes, writing only changed presets, and reading values back after the operation. RigCanvas adopts these as **future safety acceptance requirements**, not as a command implementation. The Tank-G source repository reports no SPDX/repository licence, and its research directory contains manufacturer factory preset data; RigCanvas does not copy its source code, protocol implementation, or factory dumps. [Tank-G Control Center README and terms](https://github.com/CamiloFerreira/tankg-control-center)

### Current M-EFCS documentation discrepancy

The current [M-VAVE downloads page](https://www.m-vave.com/appdownload) lists M-EFCS device support but does not explicitly name KPT Pro in its PC or mobile compatibility lists. The [TankPedal download page](https://tankpedal.com/en-asia/pages/download) labels its M-EFCS PC/mobile downloads as TANK-G/TANK-B support. The owner's working Android M-EFCS v3.10.2311 / KPT Pro firmware-v8 pairing remains an owner-reported physical observation and is retained as the target test baseline. The public download-page lists do not establish that a generic current M-EFCS installer has KPT Pro protocol support.

## Capture-free implementation milestone — 2026-11-18

The Control Center now includes a generic **Native File Inspection** path. The user can select the exact M-EFCS-exported candidate file, and RigCanvas records its original filename/extension, file size, SHA-256 fingerprint, generic file signature, bounded entropy sample, a short hex prefix, readable ASCII strings, and JSON root keys where applicable. It copies a metadata-only report; it does not retain or upload the bytes, assume the extension names a whole patch, extract archives, or send any data to the pedal.

This does not yet decode a native KPT Pro schema. It is intended to classify the first genuine export and preserve its provenance. AM2 AMP data, IR audio, and whole-patch exports must be identified by the actual export action and format evidence rather than their extension alone.

## Required capture package

Use the owner's working **M-EFCS Android v3.10.2311** and the physical KPT Pro. Capture with Android Bluetooth HCI snoop logging enabled before opening the connection. Select only the KPT Pro connection in RigCanvas's Android Bluetooth Trace Analyzer.

### Prepare a disposable test patch

1. In M-EFCS, export a backup of a non-critical user patch first.
2. Duplicate a non-critical user patch into a separate disposable user slot. Do not use a factory slot and do not overwrite the only copy of any patch.
3. Record the displayed source slot, destination test slot, firmware display, and exact M-EFCS version.
4. Use a generic test-patch name without personal information.

### Capture four separated actions

Keep a few seconds of idle time between actions and record the phone's local clock time for each step:

| Action | What to do in M-EFCS | What must be recorded |
|---|---|---|
| Connect / read | Connect and let the preset list and selected patch finish loading | Connect time; selected slot; when the list finishes loading |
| Edit one parameter | Change exactly one parameter on the disposable patch, then pause | Module/model; parameter label; original displayed value; new displayed value; edit time |
| Save patch | Save to the disposable user slot; wait; then reselect/read that slot | Save time; destination slot; whether the UI reports success; value after re-read |
| Export / import | Export the test patch; then import that exported file into a second disposable user slot | Original exported filename and extension; export time; import time; second target slot; result after re-read |

Do not change several parameters at once. Distinct, timestamped actions are what let us distinguish discovery polling from a real edit, save, and import transaction.

### Files to provide

1. **Action-correlated filtered trace report:** import the new BTSnoop log into RigCanvas → Devices → Android Bluetooth Trace Analyzer, select only the KPT Pro connection, and enable ATT payload bytes for this controlled test. Export/copy the selected connection report. The payload can contain patch data, so use only the disposable test patch and review the report before sharing.
2. **Native exported patch/tone file:** attach the exact file that M-EFCS produced, unchanged, including its original extension. Do not rename it to `.a2` or `.am2` unless that is the extension shown by M-EFCS.
3. **Action notes:** provide the times and values from the table above. The file and trace should come from the same test session.

If M-EFCS offers separate operations for a complete preset/tone, AM2 amp data, and IR data, capture/export them as separate files and identify which menu action produced each. Do not treat an AM2 AMP model file or CAB IR as a complete patch.

After capturing, disable HCI snoop logging. Keep the full unfiltered bug report and raw HCI log private; share only the filtered selected-connection report and the disposable test-patch export.

## Implementation sequence after evidence arrives

### 1. Device connection and capabilities
- Confirm the vendor service and characteristics from a fresh successful GATT declaration/descriptor exchange.
- Add the actual notify subscription lifecycle and disconnect handling only for the confirmed patch-control characteristic.
- Create a capability response for this exact model/firmware. Do not assume another KPT or TANK device uses the same command schema.

### 2. Read and backup
- Decode preset-slot listing and complete patch reads.
- Preserve unknown bytes/fields exactly.
- Store a local immutable backup with source device, firmware, slot, byte length, and SHA-256.
- Verify that repeated reads of an unchanged patch produce stable normalized content.

### 3. Edit
- Build a separate KPT patch editor for the seven named hardware modules and their verified chain order.
- Populate each effect model with its real hardware parameter IDs, names, units, and ranges. Do not map generic offline DSP parameters onto hardware.
- Keep edits local until the user explicitly chooses Save to Device.
- Show an exact before/after diff before writing.

### 4. Save / swap
- Implement only the observed transaction format with explicit acknowledgement, timeout, retry, and error handling.
- Require an immutable backup and an explicitly selected disposable user slot for initial testing.
- Re-read the target slot after save and compare all decoded fields and preserved unknown bytes.
- Keep factory-slot writes disabled until separate recovery testing is complete.

### 5. Import / export
- Identify the native whole-patch format from the M-EFCS-exported sample. Determine version, container length, checksum, and field schema.
- Keep full-patch files separate from AM2 AMP data and WAV/IR assets.
- Validate file version, target model, firmware compatibility, size, checksums, and every decoded parameter before presenting Import to Device.
- Import first into a disposable slot, then read it back and compare with the source file's normalized content.

## Release acceptance gate

True KPT Pro patch control is complete only when:
- Read/list, one-parameter edit, save, and import have been traced to exact operations and implemented without guessed bytes.
- Every write is acknowledged and the saved patch can be read back.
- Interrupted/failed transactions leave the prior slot recoverable.
- Native import/export round-trips pass with known test files.
- Tests cover malformed files, unknown fields, wrong-device/firmware files, truncated messages, wrong checksums, timeouts, and Android/Windows parity.
- Physical validation succeeds on the owner's exact KPT Pro firmware baseline and M-EFCS version.

Until then, RigCanvas stays read-only for vendor patch data. Do not replay captured packets or use guessed commands.
