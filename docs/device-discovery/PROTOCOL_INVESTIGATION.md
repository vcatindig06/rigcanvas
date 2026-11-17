# KPT Pro protocol investigation plan

## Objective

Identify how the official software discovers and communicates with the KPT Pro, without modifying firmware or corrupting user presets.

## Phase 0 — information capture

Collect:
- Pedal model and hardware revision.
- Current firmware version.
- Windows version and Android version used for testing.
- Official M-EFCS app version and install source.
- Whether the device appears in the official application.
- Whether USB control, wireless control, and USB audio are separate functions.

## Phase 1 — BLE GATT profile capture (read-only)

A user-provided RigCanvas report captured on 2026-11-17 identifies a peripheral advertising as `KPTPRO_BLE` and confirms:

- `0000AE40-0000-1000-8000-00805F9B34FB` with `AE41` write-without-response and `AE42` notify.
- Standard BLE-MIDI service `03B80E5A-EDE8-4B33-A751-6CE34EC4C700` and characteristic `7772E5DB-3868-4112-A1A9-F2669D106BF3`, with read, write-without-response, and notify properties.
- No standard Device Information service `180A`.
- No vendor reads, notification subscriptions, or writes were performed.

The BLE-MIDI UUIDs identify the standard MIDI transport only; they do not define effect-editor or preset commands. The AE40 service is a vendor data-tunnel candidate, but its payload format is unknown. Similar UUID layouts in other products are not protocol evidence for KPT Pro.

## Phase 2 — official-app Android HCI trace

The owner reports KPT Pro firmware v8 and M-EFCS Android v3.10.2311, and confirms that the official app connects to the pedal. RigCanvas now contains a local BTSnoop/HCI importer for Android HCI UART/H4 captures.

The importer:
- Recognizes BLE advertising reports and LE connection-complete/disconnection events.
- Associates ATT events with their connection handle and observed advertiser name.
- Parses ATT writes, reads, notifications, indications, service declarations, and characteristic declarations.
- Correlates ATT attribute handles with discovered 16-bit or 128-bit service and characteristic UUIDs, including characteristic property bits, within each connection handle.
- Filters an export to one selected connection, masks the BLE peer address, and excludes all other connections.
- Keeps ATT payload bytes off by default because they may contain user preset or proprietary data.
- Preserves the complete discovered characteristic table for the selected connection, including declarations with no observed read/write/notify payload; the table remains available after disconnect.
- The service/characteristic map is evidence from the captured GATT discovery exchange; it does not decode proprietary command payload semantics.

The importer never replays a captured packet and never writes to the pedal. It currently accepts BTSnoop v1 / HCI UART H4 data-link type 1002. See [Android HCI capture guide](ANDROID_HCI_CAPTURE_GUIDE.md) for the Samsung Android 12 workflow.

**Required capture:** enable full/unfiltered Bluetooth HCI snoop, restart Bluetooth, connect only M-EFCS to the KPT Pro, allow its normal preset-list/current-preset refresh to complete without editing or saving, disconnect, extract only `btsnoop_hci.log`, and import it into RigCanvas → Devices → Android Bluetooth Trace Analyzer. Share the filtered report with ATT payload bytes only when comfortable disclosing the captured pedal data. Disable HCI snoop logging after the capture.

**No command implementation is authorized from the GATT property list alone.** First compare the ATT sequence for discovery, notifications, and read/list refresh; identify characteristic UUIDs from the GATT discovery records; then document actual payload framing and any acknowledgement behavior. Do not replay traffic.

## Phase 2.1 — first owner-provided M-EFCS ATT trace (2026-11-17)

The owner supplied a filtered BTSnoop v1 / HCI UART-H4 (data-link type 1002) report for a selected BLE connection, handle `0x0200`, spanning frames 350–1,194. It contains 330 ATT events from a 1,195-packet capture. The advertisement name was absent and the report did not identify the connection as KPT Pro by name; this remains an owner-associated pedal candidate session, not independent device identity evidence.

Observed report totals:
- 158 ATT Write Requests/Commands.
- 165 Handle Value Notifications/Indications.
- Zero simple attribute-value Read Requests/Responses in the legacy summary.
- Empty characteristic-discovery map.

Observed handles and traffic:
- Phone-to-pedal Write Commands (ATT opcode `0x52`) repeatedly target handle `0x0062`.
- Pedal-to-phone Handle Value Notifications (ATT opcode `0x1B`) repeatedly target handle `0x0064`.
- One acknowledged Write Request to handle `0x0065` is followed by a Write Response.
- An ATT Read By Type Request (`0x08`) is followed by an ATT Error Response (`0x01`).
- Two Exchange MTU Request/Response pairs are visible.

**MTU-exchange anomaly:** the report lists two client-to-server Exchange MTU Requests and two responses for the same selected connection. Bluetooth Core ATT §3.4.2.1 says the client sends ATT_EXCHANGE_MTU_REQ only once during a connection, and §3.4.2.2 defines the server response. The current parser includes ATT data only from the fixed ATT L2CAP channel (CID `0x0004`); dynamically allocated enhanced ATT bearers are not represented in this report. Thus both requests appear on the same parsed fixed bearer. ATT MTU is a per-bearer value, while the GATT Exchange MTU subprocedure is initiated only once during a connection. Check the raw timestamps and HCI lifecycle; do not assume a pedal defect. The payload-free report cannot distinguish duplicate stack traffic from a capture/parser artifact. See the [Bluetooth Core Specification, ATT §3.2.8 and §3.4.2](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/attribute-protocol--att-.html) and [GATT §4.3.1](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/generic-attribute-profile--gatt-.html). See the [Bluetooth Core Specification, Attribute Protocol §3.4.2](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-61/out/en/host/attribute-protocol--att-.html).


A prior separate GATT inspection found AE40 / AE41 (write-without-response) / AE42 (notify). The new handles and directions are consistent with those roles, but this trace has no successful service/characteristic declaration responses and therefore does not prove that `0x0062 = AE41`, `0x0064 = AE42`, or `0x0065` is the notification CCCD. Treat these as hypotheses only.

The empty characteristic map is expected when the selected trace contains no successful Read By Group Type Response (`0x11`) or Read By Type Response (`0x09`) declarations. The visible Read By Type Request and Error Response are insufficient to build the map. The legacy summary's `readRequestsAndResponses: 0` counts simple Read Request/Response traffic, not GATT discovery requests; the analyzer now reports discovery, attribute-value reads, and ATT errors separately.

RigCanvas now exports payload-free protocol details for Read By Type/Group Type Requests (handle range and queried UUID), Error Responses (failed opcode/handle and ATT error), and MTU messages. These additions preserve privacy when payload export is off. The detailed evidence and limitations are in [TRACE_ANALYSIS_2026-11-17.md](TRACE_ANALYSIS_2026-11-17.md).

**Status at the time of this first, payload-free report:** the next evidence requested was a payload-enabled companion export. That companion has since been supplied and is documented in Phase 2.2 and [PAYLOAD_ANALYSIS_2026-11-17.md](PAYLOAD_ANALYSIS_2026-11-17.md).

The analyzer has since been extended to parse ATT Find Information Request/Response traffic (0x04/0x05), retain discovered handle-to-UUID attributes, and infer descriptor-to-characteristic association from known GATT handle ranges. Standard descriptors such as CCCD UUID 0x2902 are labelled in a separate descriptorDiscovery map. Session exports also include HCI connection start/end timestamp offsets and successful disconnect status/reason. This prepares the analyzer to map a future fresh discovery capture; it does not retroactively create descriptor evidence in the current payload-enabled report.

## Phase 2.2 — payload-enabled M-EFCS ATT trace (2026-11-17)

The owner supplied the payload-enabled companion export for the 330-event selected session (connection handle 0x0200, frames 350–1,194). The export contains 1 Write Request, 157 Write Commands, and 165 Handle Value Notifications. The two uploaded text files are byte-identical duplicates and are treated as one capture.

New observations:

- A pedal-to-phone notification on handle 0x0064 contains the ASCII string KPTPRO_008. This is payload-level product-like identification evidence, although the advertising name remains absent and the token's suffix is not proven to be a firmware version.
- A Write Request to 0x0065 carries 01 00 and receives an ATT Write Response. This is consistent with a CCCD notification-enable write, but the descriptor mapping is not proven without declarations.
- Phone Write Commands target 0x0062; pedal notifications target 0x0064. Their direction and operation pattern are consistent with a bidirectional vendor data path. The capture still has no successful characteristic declaration response, so the UUID mapping to previously observed AE41/AE42 remains unconfirmed.
- The vendor-looking payloads include repeated 00 59 11 and 00 59 23 prefixes. Two Write Command payload variants occur 76 times each, and two notification payload variants occur 76 times each. This supports a recurring exchange, but does not establish whether it is polling, synchronization, keep-alive traffic, or parameter control.
- The payload contains long model-name lists. The speaker/cabinet-like names appear in notifications at frames 413–440. CL/OD/DS amp model names appear at frames 450–477, followed by a standalone FNDR AMPCAB string and Bass-prefixed names. Original strings and segmentation caveats are preserved in [PAYLOAD_ANALYSIS_2026-11-17.md](PAYLOAD_ANALYSIS_2026-11-17.md).
- A larger binary notification is visible at frame 486, but no parameter offsets, types, ranges, or meanings are claimed.

The report does not disclose a decoded FX, drive, modulation, delay, reverb, or dynamics catalog in the selected payload excerpts. This is an evidence gap, not proof those block types are absent.

**Updated evidence status:** the payload-enabled capture milestone has been completed. The next required evidence is a successful fresh GATT service/characteristic/descriptor discovery to map handles 0x0062, 0x0064, and 0x0065 to UUIDs, plus raw HCI lifecycle context to resolve the repeated MTU exchange. Only after that should a passive, action-correlated official-app capture be used to investigate parameter semantics. In any such capture, RigCanvas remains read-only; do not replay messages or send guessed writes.

The payload report itself is not included in the public repository. Only the summarized observations and model-name strings needed for the investigation are documented. No user preset dump, full proprietary payload sequence, or raw BTSnoop capture is committed.

## Phase 3 — USB enumeration (read-only)

1. Connect the pedal using a known data-capable USB cable.
2. Record device descriptors using OS tools:
   - Windows: Device Manager and USB Device Tree Viewer.
   - Linux: `lsusb -v` and kernel logs.
3. Record VID, PID, interface number, interface class/subclass/protocol, endpoint addresses, and transfer types.
4. Do not send custom control transfers or vendor commands.
5. Confirm whether the device exposes a standard USB audio interface separately from any control interface.

## Phase 4 — observe official application behavior

Only when the official app recognizes the exact KPT Pro model:
1. Capture a baseline preset backup using the official app.
2. Start an authorized USB trace (for example USBPcap/Wireshark) or OS-level Bluetooth trace.
3. Capture device discovery and a read-only preset/list refresh.
4. Save traces privately; do not commit raw captures or personal preset data.
5. Compare repeated discovery traces to identify stable framing versus session values.
6. Do not replay captured traffic.

## Phase 5 — protocol documentation

Create a written protocol specification only after repeated observations:
- Framing and message boundaries.
- Request/response correlation.
- Device identity and firmware negotiation.
- Length, checksum, and integrity fields.
- Timeouts and retry behavior.
- Read operations and response validation.
- Write transaction and rollback behavior, if safely documented.

Mark each field as observed, inferred, or unknown. Never present an inference as a confirmed fact.

## Phase 6 — implementation gate

The first adapter should implement only:
- Device discovery.
- Identity query.
- Read-only preset listing/export, if explicitly understood.
- Capability reporting.

Write support remains disabled until:
- A complete backup has been verified.
- A known test preset is available.
- Checksums and acknowledgements are understood.
- A recovery path is documented.
- Multiple test cycles pass on the exact model and firmware.

## Security and safety

- Never flash firmware as part of protocol discovery.
- Never send unknown write, erase, bootloader, or update commands.
- Do not infer KPT Pro behavior from Tank-G/Tank-B packet captures.
- Treat device dumps as potentially proprietary and as user data.
- Keep private captures outside the public repository.