# Android BTSnoop trace analysis — 2026-11-17

## Evidence source and limits

This analysis is based on the owner-provided **filtered RigCanvas JSON report**, not the original raw BTSnoop file. RigCanvas did not capture, replay, or transmit any packet for this analysis. The report had ATT payload bytes disabled, and the peer address was redacted.

The owner associates this capture with the M-EFCS / KPT Pro test session. The report itself does not prove the selected peripheral's identity: its advertising name is null and `identifiedAsKptProByAdvertisementName` is false. Record it as the **owner-associated pedal candidate session**, not a device-identity confirmation.

## Capture summary

| Field | Observed value |
|---|---|
| Report type | RigCanvas filtered Android BTSnoop ATT analysis |
| BTSnoop version | 1 |
| Data-link type | 1002 (HCI UART/H4) |
| Packets in capture | 1,195 |
| Selected connection handle | `0x0200` |
| Connection frame range | 350–1,194 |
| ATT events | 330 |
| Name in advertising report | Not available |
| Peer address | Redacted; suffix `6C:9F` |
| Advertisement-name identity match | No |
| ATT payload bytes | Excluded |
| Characteristic discovery map | Empty |

### ATT event totals

- Write Requests and Write Commands: 158.
- Notifications and Indications: 165.
- Simple attribute-value Read Requests/Responses: 0, according to the original report's legacy summary field.
- The event list also contains a **Read By Type Request (opcode `0x08`)** and an **Error Response (opcode `0x01`)**. These are not counted by that legacy simple-read metric; they are GATT attribute-discovery traffic, not ordinary characteristic-value reads.

## Observed ATT sequence

The following events are visible in the supplied report:

| Frame | Direction | ATT operation | Handle | Interpretation |
|---:|---|---|---|---|
| 359 | Phone → pedal | Read By Type Request (`0x08`) | Not in request header | A GATT attribute-type query was attempted; requested UUID/range not available in this payload-excluded report |
| 364 | Pedal → phone | Error Response (`0x01`) | Error handle not decoded in original report | The preceding ATT request received an error; error code and failed request handle need payload decoding |
| 365 / 367 | Both directions | Exchange MTU Request / Response | — | ATT MTU negotiation |
| 372 / 374 | Both directions | Exchange MTU Request / Response | — | A second MTU exchange is visible in the same selected session; values and reason are not established |
| 377 / 380 | Both directions | Write Request / Write Response | `0x0065` | One acknowledged ATT Write Request |
| 387 onward | Phone → pedal | Write Command (`0x52`) | `0x0062` | Repeated phone-to-pedal writes without ATT Write Response |
| 390 onward | Pedal → phone | Handle Value Notification (`0x1B`) | `0x0064` | Repeated pedal-to-phone notifications |

The supplied summary counts 158 write requests/commands. The displayed event stream shows the acknowledged write to `0x0065` followed by repeated write commands to `0x0062`. It also shows repeated notifications on `0x0064`. This is strong evidence of an active bidirectional ATT data path during the official-app session, but the ATT operation names alone do not reveal the application command semantics.

## Correlation with the earlier GATT profile

A separate earlier read-only GATT inspection recorded:

- Vendor service `AE40`.
- Characteristic `AE41`: Write Without Response.
- Characteristic `AE42`: Notify.
- A separate standard BLE-MIDI service/characteristic.

The new trace has repeated writes to handle `0x0062` and notifications from handle `0x0064`. Their directions and operation types are **consistent with** the previously observed AE41/AE42 roles. However, this capture's `characteristicDiscovery` map is empty, so the exact handle-to-UUID association is **not proven in this session**. Do not hard-code `0x0062 = AE41` or `0x0064 = AE42` as a verified mapping yet.

The Write Request to `0x0065` may be a Client Characteristic Configuration Descriptor (CCCD) write associated with the notification characteristic at `0x0064`. That is only a hypothesis: its value bytes and this session's characteristic map are absent. A value of `01 00` would normally enable notifications and `02 00` indications, but the report does not show either value.

**MTU-exchange anomaly:** the report lists two client-to-server Exchange MTU Requests and two responses for the same selected connection. Bluetooth Core ATT §3.4.2.1 says the client sends ATT_EXCHANGE_MTU_REQ only once during a connection, and §3.4.2.2 defines the server response. The current parser includes ATT data only from the fixed ATT L2CAP channel (CID `0x0004`); dynamically allocated enhanced ATT bearers are not represented in this report. Thus both requests appear on the same parsed fixed bearer. ATT MTU is a per-bearer value, while the GATT Exchange MTU subprocedure is initiated only once during a connection. Check the raw timestamps and HCI lifecycle; do not assume a pedal defect. The payload-free report cannot distinguish duplicate stack traffic from a capture/parser artifact. See the [Bluetooth Core Specification, ATT §3.2.8 and §3.4.2](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/attribute-protocol--att-.html) and [GATT §4.3.1](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/generic-attribute-profile--gatt-.html). See the [Bluetooth Core Specification, Attribute Protocol §3.4.2](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-61/out/en/host/attribute-protocol--att-.html).

## Why characteristic discovery is empty

The parser populates the service map from successful ATT Read By Group Type Responses (`0x11`) and the characteristic map from successful Read By Type Responses (`0x09`). This selected report contains a Read By Type Request and an Error Response, but no successful declaration responses. Consequently, an empty `characteristicDiscovery` object is expected; it is not evidence that the pedal has no GATT characteristics.

The Android stack may also have a cached GATT database, or this capture may have begun after the discovery exchange. Those explanations remain possibilities, not conclusions from the supplied report.

## Protocol conclusions

### Confirmed by the supplied report

1. One selected BLE connection carried 330 ATT events.
2. The phone repeatedly sent Write Commands to attribute handle `0x0062`.
3. The pedal repeatedly sent Handle Value Notifications on attribute handle `0x0064`.
4. The phone performed one acknowledged Write Request to `0x0065`.
5. A Read By Type Request received an ATT Error Response.
6. Two MTU request/response pairs appear in the trace.
7. The provided export omits all payload values and does not identify the peripheral by its advertising name.

### Plausible but unconfirmed

- Handles `0x0062` and `0x0064` may correspond to the previously observed AE41 write and AE42 notify characteristics.
- Handle `0x0065` may be the notification/indication configuration descriptor.
- The repeating write/notification traffic may be an application-level request/response or streaming exchange.

These interpretations must be checked against payload bytes and a successful GATT attribute map before they become protocol facts.

### Not established

- The meaning of any command or response byte.
- Message framing, command identifiers, sequence counters, checksums, fragmentation, or acknowledgement semantics.
- Whether the traffic is preset listing, current-preset synchronization, status polling, or another application operation.
- Firmware identity, hardware revision, or preset contents.
- Safe third-party parameter-write or preset-transfer support.

## Analyzer improvement prompted by this trace

RigCanvas now adds payload-free `protocolDetails` for:
- Read By Type and Read By Group Type Requests: start handle, end handle, and queried 16-bit/128-bit attribute type UUID.
- ATT Error Responses: failed request opcode, failed attribute handle, error code, and standard error name.
- Exchange MTU Requests/Responses: the receive-MTU value carried by each message, plus request/response counts and a warning when multiple client MTU requests appear in one selected connection.

The summary now separately counts GATT discovery operations, attribute-value reads, and ATT Error Responses. These decoded fields are available even when the user leaves payload export disabled. The original raw ATT PDU/value bytes remain excluded unless the owner explicitly enables payload export.

## Next capture required

The next useful evidence is a short, filtered trace with payload bytes enabled for **only the selected connection**, captured while M-EFCS connects and performs its normal preset-list/current-preset refresh:

1. Use the same KPT Pro and M-EFCS v3.10.2311 setup; keep the pedal firmware v8 as the owner-reported baseline.
2. Start HCI snoop logging before connecting M-EFCS. Restart Bluetooth or clear the system Bluetooth cache only if needed for a fresh GATT discovery, and do not reset or alter the pedal.
3. Keep unrelated Bluetooth devices disconnected where practical.
4. Allow the normal list/current-preset refresh to finish. Do not edit or save effect parameters.
5. In RigCanvas, select the candidate connection and enable ATT payload export.
6. Review the filtered JSON locally before sharing. Payloads may reveal preset names, settings, or proprietary data; use a non-personal test preset where practical.
7. Stop HCI logging and keep the system-wide raw log private.

The payload-enabled report should let us compare ATT values on handles `0x0062`, `0x0064`, and `0x0065`, inspect the `0x08` query and `0x01` error, and determine whether the traffic contains identifiable framing or request/response correlation.

## Safety boundary

- Do not replay captured traffic.
- Do not send guessed GATT writes, MIDI/SysEx, vendor commands, preset changes, erase commands, or firmware operations.
- Do not infer KPT Pro protocol support from Tank-G/Tank-B packet captures.
- Do not implement device-side parameter/preset writes until payload framing, response behavior, backup, and recovery are documented and verified on the exact model/firmware.


## Payload-enabled companion report

A separate export of the same 330-event selected connection (handle 0x0200, frames 350–1,194) is now available with ATT payload bytes included. It exposes the KPTPRO_008 payload string, recurring write/notification message patterns, and model-name catalogs. It does not add a successful GATT declaration map, so the handle-to-UUID mappings remain provisional. The two uploaded files were byte-identical duplicates of this payload-enabled export.

See [PAYLOAD_ANALYSIS_2026-11-17.md](PAYLOAD_ANALYSIS_2026-11-17.md) for the decoded observations, exact source model-name strings, caveats, and next safe evidence milestones. The privacy-restricted analysis above remains the record of what could be concluded when ATT payload export was disabled.


## Follow-up analyzer capability — descriptor and connection lifecycle metadata

The BTSnoop parser now also decodes ATT Find Information Requests (0x04) and Responses (0x05). Successful responses are retained as handle-to-UUID evidence. Where a returned attribute handle falls after a known characteristic value and before the next characteristic or service boundary, the export identifies it as a descriptor and associates it with the owning characteristic. Standard descriptor UUIDs, including Client Characteristic Configuration (0x2902), receive readable labels. This allows a future complete discovery trace to determine whether the write to handle 0x0065 is actually a CCCD write, rather than relying on the value 01 00 alone.

The report adds a separate descriptorDiscovery map and descriptor counts while preserving the existing characteristicDiscovery JSON shape. The analyzer panel now displays descriptor count and warns when characteristics were found but no descriptor map was observed.

Connection sessions now export their start/end frame and timestamp offsets, plus HCI disconnection status/reason when a successful Disconnection Complete event is captured. Partial ACL/L2CAP fragments are cleared when a connection ends or a connection handle is reused, preventing fragment data from one session being carried into another.

These changes do not add any BLE writes, notification subscriptions, packet replay, or vendor command support. They also do not yet parse Enhanced ATT (EATT) dynamic bearers; MTU interpretation remains restricted to the ATT fixed channel currently handled by this parser.
