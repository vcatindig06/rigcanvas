# KPT Pro BLE frame format — captured-byte specification

**Evidence baseline:** owner-provided KPT Pro capture dated 2026-11-17  
**Reported test context:** KPT Pro firmware display v8; M-EFCS Android v3.10.2311  
**Implementation:** read-only Dart parser and notification reassembler in `app/lib/src/device/kpt_pro_protocol.dart`

## Evidence scope

The payload-enabled capture contains one selected connection with 330 ATT events. The event stream contains 157 phone-to-pedal ATT Write Commands on handle `0x0062` and 165 pedal-to-phone Handle Value Notifications on handle `0x0064`. The two uploaded text reports were duplicate copies of the same capture.

The trace does not contain a successful GATT service/characteristic declaration map. Therefore, this page refers to ATT attribute handles only; it does not claim that `0x0062` is AE41 or `0x0064` is AE42 in this connection.

## Observed outer frame

The captured vendor messages use this byte layout:

| Offset | Size | Observed field | Confidence |
|---:|---:|---|---|
| 0 | 1 | Magic byte `00` | Directly observed |
| 1 | 1 | Magic byte `59` | Directly observed |
| 2 | 1 | Command identifier | Directly observed; semantics unknown |
| 3–4 | 2 | Body length, unsigned little-endian | Validates against captured complete messages |
| 5 | 1 | Reserved/header byte; observed as `00` | Directly observed; other values unknown |
| 6… | Declared length | Body bytes | Directly observed; schema unknown |
| 6 + length | 1 | Checksum | Verified against observed body bytes |

Total frame size is exactly **7 + declared body length**.

The checksum rule validated across the capture is:

`checksum = (0xFF - (sum(body bytes) mod 256)) mod 256`

The sum is over the body bytes only. It does not include the magic, command identifier, length, or reserved byte.

## Validation against the supplied capture

- **157/157** complete phone-to-pedal vendor frames beginning with `00 59` had the declared length and matching checksum.
- **157/157** complete pedal-to-phone frames were reconstructed from the notification stream and had the declared length and matching checksum.
- The inbound stream contained command byte `0x11` once and `0x23` 156 times. These are raw identifiers, not interpreted operation names.
- The `0x11` response body contains the ASCII token `KPTPRO_008`. This is a payload identifier; the suffix is not proof of firmware version or cryptographic identity.
- The largest observed body was 848 bytes. Each of the two 848-byte response bodies was split across five ATT notifications. Continuation notifications did not repeat the frame header.
- Other observed complete response body lengths were 27, 40, 64, 18, and 150 bytes.

These counts validate the framing hypothesis for this one KPT Pro trace. They do not establish compatibility with other firmware versions, devices, or transports.

## Reassembly behavior implemented

`KptProNotificationFrameReassembler` accepts notification payloads from an already-selected stream. It waits for the `00 59` magic, reads the declared length after the header is available, appends continuation notification bytes, and returns a frame only after the complete frame is present and the checksum validates.

Unframed notifications received while idle are ignored. A partial frame can be discarded with `reset()` after a disconnect. The parser enforces a configurable maximum body length (default 8192 bytes) before buffering an advertised body.

The implementation has no BLE dependency and does not subscribe, read, write, replay, or construct a vendor command. The test helper that creates synthetic frames exists only inside the test suite.

## Still unknown — do not infer

This capture does **not** establish:

- the semantic meaning of command identifiers `0x11` or `0x23`;
- the meaning of fields inside any `0x23` body, including address-like or length-like values;
- whether the repeated `0x23` exchanges are discovery, polling, status, parameter reads, or another operation;
- how a user preset, slot number, effect order, parameter, enabled state, or patch name is encoded;
- the preset slot map, patch length, factory/user boundaries, or any native tone-file schema;
- which frame is a write, commit, erase, or firmware operation;
- application-level acknowledgement, retry, timeout, rollback, or save/readback semantics;
- whether handles `0x0062` and `0x0064` map to the earlier-observed AE41/AE42 UUIDs in this exact trace;
- whether any Tank-G/Tank-B memory layout, frame body schema, preset count, or command semantics apply to KPT Pro.

The public Tank-G protocol research was useful as a candidate comparison, but no Tank-G body schema or memory map is imported into this KPT Pro parser.

## Safety boundary and next evidence

The code intentionally implements **parsing only**. It has no outgoing frame encoder, command builder, BLE notification subscription, preset read operation, or hardware write operation.

Before a read-only device operation can be considered, collect a fresh complete GATT discovery exchange so the exact service/characteristic/descriptor mapping is known. To understand any `0x23` body, collect a passive, timestamped M-EFCS trace correlated with one clearly recorded action on a disposable, backed-up test patch. Preserve a native M-EFCS-exported test file unchanged if its format is to be investigated.

Do not replay captured packets or send guessed commands. Hardware writes stay disabled until KPT-specific request semantics, acknowledgements, immutable backup, readback comparison, and recovery behavior are independently verified.


## Offline trace analyzer

The Devices → Android Bluetooth Trace Analyzer now applies this parser to the selected connection's ATT value events. It keeps independent streams by direction, attribute handle, ATT bearer, and L2CAP CID; reconstructs notification fragments; validates the complete frame checksum; and reports raw command-byte counts, body lengths, ATT frame ranges, and capture-relative timestamps.

Only captured ATT Write Requests, Write Commands, Notifications, and Indications are considered. Invalid candidates and streams still incomplete at the end of the capture are counted separately. The optional exported `protocolEnvelopeAnalysis` contains metadata only; the raw ATT values remain controlled by the existing payload-inclusion toggle.

This is a diagnostic aid, not a command decoder. It does not map command IDs to reads, parameter edits, saves, imports, or acknowledgements. It does not build or transmit frames.
