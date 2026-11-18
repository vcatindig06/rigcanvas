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
