# M-EFCS Package Inspection — Acquisition Status

**Research date:** 2026-11-19  
**Target reported by owner:** Android M-EFCS v3.10.2311 with KPT Pro firmware display v8  
**Purpose:** Capture-free static inspection for independently implementing KPT Pro interoperability

## Executive result

The official M-VAVE download portal was inspected, but the APK and Windows installer binaries could not be retrieved into the analysis workspace. Therefore, **no M-EFCS executable has been reverse-engineered in this milestone**. No app code, protocol constants, device tables, or native-file schema are claimed as discovered.

The portal's current compatibility lists do not explicitly include KPT Pro:

- The PC M-EFCS list names TANK-G, TANK-B, BLACKBOX, STATION-G, STATION-B, Tank Mini, Pocket Amp, SP100, MK300, and MK20.
- The mobile M-EFCS list names TANK-G, TANK-B, NANO, ANNBLACKBOX, and MK300.

This conflicts with the owner's report that Android M-EFCS v3.10.2311 connects to the physical KPT Pro. The repository also records an M-EFCS App Store version-history entry for 3.10.2016 that says A2 support was added for MK20, TANK PRO, and KPT PRO. These sources describe different release/listing contexts; neither proves the binary installed on the owner's phone contains the KPT Pro v8 transport implementation.

## Sources checked

1. **Official M-VAVE download portal:** https://www.m-vave.com/appdownload  
   The current page lists the M-EFCS PC and mobile compatibility names above and links the Windows package and Android APK.
2. **Google Play listing:** https://play.google.com/store/apps/details?id=com.digAmp.m_efcs  
   The listing describes wireless Bluetooth control, parameter adjustment, tone-library management, and effect-chain editing. Its visible supported-device examples include Tank-G, Tank-B, MK300, MK20, and Blackbox; it does not publish a KPT Pro command protocol.
3. **M-EFCS App Store history:** https://apps.apple.com/us/app/m-efcs/id6470352068  
   The repository's earlier research records the 3.10.2016 A2-support note for MK20, TANK PRO, and KPT PRO. This is release-note evidence, not a binary inspection.
4. **Official direct package endpoints linked by the portal:**
   - Android: https://resource.m-vave.com/software/app/M-EFCS.apk
   - Windows: https://yms-file-store.oss-cn-hongkong.aliyuncs.com/software/pc/M-EFCS.zip

## Retrieval outcome

The web retrieval service rejected both binary downloads because their MIME types are Android APK and ZIP. A separate direct download attempt from the working environment also failed. Consequently, no APK/ZIP bytes, file hashes, package version, signing certificate, or internal resources were available to inspect.

Do not treat a download link, store description, or version-history note as evidence that a particular executable was analyzed.

## What remains unknown

- Whether the owner's installed v3.10.2311 APK includes KPT Pro-specific device identifiers or A2 transport support.
- Whether KPT Pro uses the same BLE service/characteristic path as any other M-EFCS-supported model.
- Whether a separate Windows M-EFCS build has a different device matrix or USB transport implementation.
- The native whole-patch extension, container, schema, parameter IDs, slot map, checksums, acknowledgement semantics, and commit/read-back behavior.
- Whether any M-EFCS package contains a distinct KPT Pro model table or merely generic A2 support.

## Safe next step

Obtain the exact APK installed on the owner's phone (or the exact official Windows ZIP used with the KPT Pro) and provide it unchanged for local static inspection. Record its original filename, version/build number, source, and SHA-256. Inspect only package metadata, resources, strings, device/model tables, file extensions, and call structure. Do not redistribute vendor binaries or copy proprietary implementation code into RigCanvas.

A genuine M-EFCS-exported disposable whole-patch file remains an equally valuable independent input. Inspect it separately from AM2 AMP captures and CAB IR assets.

## RigCanvas implementation boundary

Until executable or native-file evidence is available, the app must continue to:

- Keep vendor patch writes disabled on Android and Windows.
- Avoid borrowing Tank-G command meanings, memory IDs, addresses, or commit behavior.
- Keep generic RigCanvas DSP parameters separate from KPT Pro hardware parameters.
- Preserve unknown bytes and fields when a genuine native format is eventually decoded.
- Require acknowledged writes, read-back verification, backup, and recovery tests before enabling hardware save/import.
