# Android HCI snoop capture guide — KPT Pro / M-EFCS

**Test baseline:** KPT Pro firmware v8; M-EFCS Android v3.10.2311 (owner-reported).

## Why this capture is needed

RigCanvas has identified the physical KPT Pro BLE GATT profile, including the vendor service `AE40` with `AE41` (write without response) and `AE42` (notify), plus the standard BLE-MIDI service. UUIDs and GATT properties do not reveal the app's command bytes. An Android Bluetooth HCI snoop log records the HCI packets exchanged by the Android Bluetooth stack and can expose the ATT writes and notifications produced by the official M-EFCS app.

This guide collects traffic from the official app. **RigCanvas does not connect at the same time, transmit commands, replay packets, or modify the pedal.**

## Before you start

1. Use the phone that has M-EFCS v3.10.2311 installed and the KPT Pro firmware-v8 pedal.
2. Disconnect RigCanvas from the pedal. Do not leave another BLE app connected.
3. Disconnect Bluetooth headphones, watches, speakers, and other accessories for this capture. Android HCI snoop records traffic for all Bluetooth devices, not only the pedal.
4. Do not start a firmware update, factory reset, preset restore, import, or save operation during this first capture.
5. Keep the original capture private. It can contain other Bluetooth device addresses, timestamps, and proprietary pedal/preset data.

## Enable HCI snoop on Android 12

On a Samsung Galaxy phone running Android 12, the names may vary slightly by One UI version:

1. Open **Settings → About phone → Software information**.
2. Tap **Build number** seven times. Enter your phone PIN if requested. Android confirms that Developer options are enabled.
3. Return to Settings and open **Developer options**.
4. Find **Enable Bluetooth HCI snoop log**. If Android offers a logging mode, choose the full/unfiltered capture mode, not a filtered mode.
5. Turn Bluetooth off, then on again so the logging setting takes effect.
6. Leave Bluetooth enabled. Do not connect RigCanvas to the pedal for this capture.

Android documents that HCI snoop captures Bluetooth HCI packets and that a bug report can be used to collect logs. The common file is named `btsnoop_hci.log`; device vendors may place it in a different location.

## Capture one read-only M-EFCS session

1. Turn on the KPT Pro Bluetooth function.
2. Open **M-EFCS v3.10.2311**.
3. Open the device selector, choose **KPT PRO** as the current device, scan, and connect. The KPT Pro manual describes this selection-and-scan process.
4. Wait until the pedal is connected and the preset list/current preset information finishes loading.
5. Do not change parameters or save presets in this first pass. The purpose is to record discovery, service setup, and the normal read/list-refresh traffic.
6. Leave the app connected for approximately 10 seconds, then disconnect from the pedal in M-EFCS.

## Export the log

Preferred method:

1. Open **Developer options → Take bug report** and choose a full bug report if prompted.
2. Wait for Android to finish generating it, then share/save the bug-report ZIP to a location you can open.
3. Extract the ZIP on the phone or a computer.
4. Look for `FS/data/misc/bluetooth/logs/btsnoop_hci.log`. Some Samsung builds use a different location or include a `.last` file. The exact path can vary.
5. Copy only the relevant `btsnoop_hci.log` file to Downloads. Do not upload the entire bug-report ZIP unless specifically requested after reviewing its contents.

Alternative with a computer and USB debugging enabled:

```bash
adb bugreport kpt-pro-bugreport.zip
```

Extract the bug report ZIP and locate the BTSnoop log as above. Android's AOSP debugging guide also documents the `btsnooz.py` extraction path for bug reports when the snoop data is embedded in report text.

## Analyze the capture in RigCanvas

1. Open **RigCanvas → Devices**.
2. Find **Android Bluetooth Trace Analyzer**.
3. Tap **Import HCI snoop log** and select the extracted `btsnoop_hci.log` file (not the ZIP).
4. RigCanvas identifies LE connection sessions and tries to match the advertiser name `KPTPRO_BLE`.
5. Select the KPT Pro connection if more than one session appears.
6. For the next GATT declaration/descriptor capture, keep **Include ATT payload bytes** off. The parser extracts service, characteristic, and descriptor UUID metadata from successful ATT declaration and Find Information responses without exporting raw values.
7. Tap **Copy selected connection report**. The report masks the peer address and excludes other connections. It now includes connection start/end timestamp offsets and the HCI disconnect reason when those lifecycle events are present.
8. Only enable payload bytes in a later capture when command-value analysis is specifically needed and you are comfortable sharing possible preset names/settings.
8. Paste the filtered report into the RigCanvas development conversation. Do not commit raw traces to the public repository.

The current parser accepts BTSnoop version 1 with Android HCI UART/H4 data-link type 1002. If RigCanvas reports a different data-link type or a truncated capture, keep the file private and report the exact error. Do not convert or replay packets.

## Next capture: full GATT declaration and descriptor map

The payload-enabled owner report exposed the KPTPRO_008 identifier and model-name catalogs, but it did not include successful service/characteristic declaration responses or Find Information responses. The next short capture should cover one complete connection from the LE Connection Complete event through the Disconnection Complete event:

1. Start HCI snoop logging before opening the device connection in M-EFCS.
2. Connect with M-EFCS and allow its normal device/service setup and preset-list refresh to finish. Do not edit or save parameters.
3. Leave the app connected briefly, then disconnect normally from M-EFCS so the HCI disconnect event is included.
4. Import the log in RigCanvas and select only the KPT Pro candidate connection.
5. Keep ATT payload export **off** and share the filtered JSON report.

The analyzer now decodes Read By Group Type/Read By Type declaration responses and Find Information Request/Response entries. It exports a separate descriptor map and can label standard descriptor UUIDs such as CCCD 0x2902. The same report includes connection start/end timestamps and disconnect reason for lifecycle correlation. Raw ATT value bytes are not required for this milestone.

If the new report still has no successful declaration responses, the Android stack or M-EFCS may be using a cached GATT database, or the capture may not include the discovery phase. The report alone cannot distinguish those possibilities; do not guess handle-to-UUID mappings.

## Payload-enabled command analysis (later milestone)

The existing payload-enabled report shows repeated writes to ATT handle `0x0062`, notifications from `0x0064`, and an acknowledged write to `0x0065`. Actual command framing still requires examining selected-connection ATT values and correlating them with a clearly timestamped official-app action. Enable payload export only when that later command-analysis step is specifically needed; it may disclose preset names/settings. Keep other device connections excluded and use a non-personal test preset where practical.

## After capture

1. Turn **Enable Bluetooth HCI snoop log** off when the capture is finished.
2. Remove the raw log from shared/public folders after the analysis is complete.
3. Keep the M-EFCS test session read-only. A later controlled parameter-change trace should only be captured after the read-only exchange is understood and a duplicate/test preset has been backed up.

## Privacy and safety notes

- A full HCI snoop log is system-wide. It may contain traffic from every Bluetooth device active during the capture.
- The filtered RigCanvas JSON omits other connection sessions and masks the peer address, but included ATT payload bytes can still contain preset names, parameter values, or proprietary protocol data.
- Do not share a full bug report, serial number, or other Bluetooth device traffic.
- Captured commands are evidence only. Do not replay any captured write, notification, or firmware-related packet.
- This milestone performs offline analysis only; it does not write to the KPT Pro.
