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

## Phase 1 — USB enumeration (read-only)

1. Connect the pedal using a known data-capable USB cable.
2. Record device descriptors using OS tools:
   - Windows: Device Manager and USB Device Tree Viewer.
   - Linux: `lsusb -v` and kernel logs.
3. Record VID, PID, interface number, interface class/subclass/protocol, endpoint addresses, and transfer types.
4. Do not send custom control transfers or vendor commands.
5. Confirm whether the device exposes a standard USB audio interface separately from any control interface.

## Phase 2 — observe official application behavior

Only when the official app recognizes the exact KPT Pro model:
1. Capture a baseline preset backup using the official app.
2. Start an authorized USB trace (for example USBPcap/Wireshark) or OS-level Bluetooth trace.
3. Capture device discovery and a read-only preset/list refresh.
4. Save traces privately; do not commit raw captures or personal preset data.
5. Compare repeated discovery traces to identify stable framing versus session values.
6. Do not replay captured traffic.

## Phase 3 — protocol documentation

Create a written protocol specification only after repeated observations:
- Framing and message boundaries.
- Request/response correlation.
- Device identity and firmware negotiation.
- Length, checksum, and integrity fields.
- Timeouts and retry behavior.
- Read operations and response validation.
- Write transaction and rollback behavior, if safely documented.

Mark each field as observed, inferred, or unknown. Never present an inference as a confirmed fact.

## Phase 4 — implementation gate

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
