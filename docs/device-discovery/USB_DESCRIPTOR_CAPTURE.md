# KPT Pro USB descriptor capture checklist

## Purpose

Capture the KPT Pro's standard USB descriptors on a Windows computer before any RigCanvas device communication is implemented. This is a read-only identification step. It does not send KPT Pro vendor commands, change a USB configuration, claim an interface, or read/write pedal presets.

## Reported test baseline

- Device: KPT Pro
- Firmware: v8 (user-reported)
- Official desktop editor: M-EFCS v3.10.2311 (user-reported)
- M-EFCS operation: user reports that this version works with the KPT Pro

## Windows capture procedure

1. Use a known data-capable USB cable. Power on the KPT Pro and connect it directly to the Windows computer rather than through a hub, where practical.
2. Close RigCanvas. It does not need to be open for descriptor capture.
3. Open [USB Device Tree Viewer (UsbTreeView)](https://www.uwe-sieber.de/usbtreeview_e.html). The publisher provides a Windows x64 build and documents support for saving XML reports. [Microsoft USBView](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/usbview) is an alternative; Microsoft documents that it displays Device, Configuration, Interface, and Endpoint Descriptors.
4. Note the current USB device tree, disconnect the KPT Pro, reconnect it, and identify the device node that appears. Do not identify it by a guessed manufacturer name alone.
5. Select the KPT Pro device node and save/export its complete report. Include child/interface nodes and all configurations where the tool exposes them.
6. Also open Windows Device Manager (devmgmt.msc), find the matching device, and copy the **Hardware Ids** value from **Properties → Details → Property: Hardware Ids**. Record each child interface's hardware ID if Windows lists a composite device.
7. Open M-EFCS v3.10.2311 separately and record whether it detects the KPT Pro. Do not change presets, import files, export user presets, update firmware, or run any write/sync action for this capture.

## Descriptor fields needed

Please include as many of these as the tool reports:

- Device descriptor: USB version (bcdUSB), vendor ID (idVendor), product ID (idProduct), device release (bcdDevice), device class/subclass/protocol, and configuration count.
- String descriptors: manufacturer and product. A unique serial number is not required; redact it before sharing.
- Each configuration: configuration value, attributes, and maximum power.
- Each interface and alternate setting: interface number, alternate setting, class, subclass, protocol, and endpoint count.
- Each endpoint: address, direction, transfer type, maximum packet size, and interval.
- Any separate USB Audio Class interfaces or audio streaming endpoints shown by the tool.

If a field is absent, leave it absent. Do not infer values from a friendly device name or from another Tank-series pedal.

## What to send back

1. The complete UsbTreeView text/XML report, or clear screenshots of the descriptor pane if exporting a report is not possible.
2. The Hardware Ids text copied from Device Manager.
3. Whether M-EFCS v3.10.2311 detects and operates the KPT Pro while connected over USB.

Before sharing, remove the device serial number and any personal file paths or Windows account names. Do not include personal preset backups or raw packet captures in a public repository.

## Safety boundary

- Do not use USBPcap or replay captured packets for this descriptor-only step.
- Do not send custom control transfers, vendor requests, bulk writes, firmware commands, or bootloader commands.
- Do not install a generic USB/WinUSB driver or use Zadig to replace an existing driver. That could change how M-EFCS or USB audio accesses the pedal.
- Keep the official M-EFCS connection as the known-good reference. Protocol tracing is a separate later step and must be passive and limited to an explicitly read-only action.

Once the descriptors are available, RigCanvas can assess whether Android and Windows can enumerate the same physical interfaces safely and choose a transport adapter based on evidence rather than guessing.
