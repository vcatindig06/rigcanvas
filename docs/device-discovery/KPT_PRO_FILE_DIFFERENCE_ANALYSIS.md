# KPT Pro Native Export — Differential Analysis

Purpose: compare two local M-EFCS exports without a Bluetooth/HCI capture.

## Controlled file pair

1. Export a baseline tone and keep the original unchanged.
2. Duplicate the tone in M-EFCS or use a disposable test slot.
3. Change exactly one item, such as one parameter by a small amount, then export the second file.
4. Preserve the original names/extensions and compare them in RigCanvas, Settings, KPT Pro Control Center, Compare two native exports.

Do not overwrite a valuable factory or user preset. Avoid changing multiple settings between exports because that makes a byte difference harder to correlate to one action.

## Reported data

The report includes file lengths and SHA-256 fingerprints, changed-byte count and percentage, common prefix/suffix lengths, contiguous changed-offset ranges, and a bounded sample of old/new byte values. Files are compared locally with a 64 MiB combined limit. Source payload bytes are not retained in the report.

## Interpretation limits

A changed byte is not automatically a parameter value. Files may include timestamps, IDs, checksums, compression, encryption, or ordering changes. A small edit can change many bytes. Repeat controlled pairs before assigning meaning to any offset.

The comparison does not decode a KPT Pro patch schema, prove slot addressing, identify vendor commands, or establish a safe device write/commit path. Hardware writes remain locked. Never replay file bytes over BLE or USB.

## M-EFCS package-inspection status

The public Android package identifier is com.digAmp.m_efcs. APKPure lists v3.10.2311 as an XAPK dated November 17, 2026, but its download endpoint redirected to v3.9.2314 in this investigation. That binary was not accepted as the owner's exact v3.10.2311 build, and no app internals are claimed to have been inspected. References: [APKPure version history](https://apkpure.net/m-efcs/com.digAmp.m_efcs/versions) and [Google Play](https://play.google.com/store/apps/details?id=com.digAmp.m_efcs).

The user's reported working M-EFCS version remains v3.10.2311. Public package metadata does not replace the installed binary or prove KPT Pro protocol semantics.
