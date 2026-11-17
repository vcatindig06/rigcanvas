# RigCanvas read-only device discovery

## Scope

This milestone identifies attached USB devices without communicating with the pedal's undocumented control protocol. It does not read presets or firmware, send MIDI/SysEx, write preset memory, or flash firmware. It does not open a USB device handle for data transfer.

## Current known hardware baseline

The project owner reports that their KPT Pro displays firmware v8 and that M-EFCS Android v3.10.2311 connects to it. These values are user-reported; RigCanvas has not independently read the firmware version. The official vendor download page lists a KPT Pro firmware archive labelled KPT PRO-011, but does not publish a mapping from that archive label to the displayed v8 string.

## Android

1. Connect the KPT Pro to the Android phone using a data-capable USB cable and compatible USB-OTG adapter.
2. Power on the KPT Pro.
3. Open RigCanvas and select Devices.
4. Tap Scan USB devices.
5. Review manufacturer/product name, VID/PID, interfaces, and endpoints.
6. Tap Copy report and share the resulting JSON with the development review. The report intentionally excludes USB serial numbers.

Android enumeration uses UsbManager.deviceList and reads descriptor metadata exposed by the Android USB Host API. It does not open a USB device, request its permission, or send control/bulk/interrupt transfers. USB host capability is declared optional so the app can still run on devices without OTG support.

## Windows

1. Connect the powered KPT Pro to the Windows PC using a data-capable USB cable.
2. Open RigCanvas and select Devices.
3. Tap Scan USB devices.
4. Review friendly name, manufacturer, VID, and PID. A composite USB device may be represented by multiple Plug-and-Play records.

The first Windows adapter uses SetupAPI to enumerate present USB Plug-and-Play records. It does not yet query full USB configuration, interface, or endpoint descriptors. Use the [USB descriptor capture checklist](USB_DESCRIPTOR_CAPTURE.md) to collect the full report with a read-only viewer; this does not install a driver or send pedal commands.

## Evidence to return

Provide:
- The copied RigCanvas inventory report, or screenshots showing the USB records.
- The exact M-EFCS application name and version/build shown in its About screen.
- Whether the app's actual supported-device list or discovered-device list shows KPT Pro.
- Any hardware revision printed on the pedal label or shown in system information.

Do not include serial numbers, account credentials, private preset contents, or other personal information. Do not update firmware, import firmware packages, or experiment with unknown protocol commands as part of discovery.
