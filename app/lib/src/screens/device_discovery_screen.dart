import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rigcanvas_usb_inventory/rigcanvas_usb_inventory.dart';

class DeviceDiscoveryScreen extends StatefulWidget {
  const DeviceDiscoveryScreen({
    required this.inventory,
    super.key,
  });

  final UsbDeviceInventoryClient inventory;

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen> {
  List<UsbDeviceInfo> _devices = const <UsbDeviceInfo>[];
  bool _isScanning = false;
  bool _hasScanned = false;
  String? _error;

  Future<void> _scan() async {
    setState(() {
      _isScanning = true;
      _error = null;
      _hasScanned = false;
    });
    try {
      final devices = await widget.inventory.listUsbDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _hasScanned = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PlatformException
            ? (error.message ?? error.code)
            : error.toString();
        _hasScanned = true;
      });
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _copyReport() async {
    final report = <String, Object?>{
      'reportType': 'RigCanvas read-only USB inventory',
      'devices': _devices.map((device) => device.toJson()).toList(),
    };
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(report)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('USB inventory report copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KPT Pro Hardware Discovery',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              const Text(
                'Start with read-only USB inventory. RigCanvas does not open the device, send control packets, read presets, or write firmware in this stage.',
                style: TextStyle(color: Color(0xFF9AA4B2), height: 1.5),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B211D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF354C3A)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined, color: Color(0xFF9CC7A4)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Read-only scan · No USB transfers · No preset or firmware changes',
                        style: TextStyle(color: Color(0xFFD5E4D8), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('scan-usb-devices'),
                onPressed: _isScanning ? null : _scan,
                icon: _isScanning
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.usb),
                label: Text(_isScanning ? 'Scanning USB devices…' : 'Scan USB devices'),
              ),
              const SizedBox(height: 18),
              if (_error != null)
                _Notice(
                  icon: Icons.error_outline,
                  color: const Color(0xFFFFA38F),
                  text: 'USB inventory failed: ' + _error!,
                )
              else if (_hasScanned && _devices.isEmpty)
                const _Notice(
                  icon: Icons.usb_off,
                  color: Color(0xFFB9C2CE),
                  text: 'No USB devices were reported. Check the data cable, OTG/USB connection, and device power, then scan again.',
                )
              else if (!_hasScanned)
                const _Notice(
                  icon: Icons.info_outline,
                  color: Color(0xFFB9C2CE),
                  text: 'Connect the KPT Pro with a data-capable USB cable, then scan. This list includes all attached USB devices; RigCanvas does not guess which VID/PID belongs to the pedal.',
                ),
              if (_devices.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _devices.length.toString() +
                            ' USB device record' +
                            (_devices.length == 1 ? '' : 's'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _copyReport,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy report'),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                for (final device in _devices) _UsbDeviceCard(device: device),
              ],
              const SizedBox(height: 14),
              const Text(
                'Platform detail level',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Android reports the connected USB device, interfaces, and endpoint descriptors. Windows currently reports USB Plug-and-Play names and VID/PID only; full Windows interface/endpoint descriptor capture is a separate step. Neither adapter sends USB control or bulk transfers.',
                style: TextStyle(color: Color(0xFF9AA4B2), height: 1.45, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsbDeviceCard extends StatelessWidget {
  const _UsbDeviceCard({required this.device});

  final UsbDeviceInfo device;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              (device.manufacturer ?? 'Manufacturer not reported') +
                  ' · ' + device.name,
              style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 12),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _DataChip('VID ' + device.vendorIdHex),
                _DataChip('PID ' + device.productIdHex),
                _DataChip('Class ' + device.deviceClass.toString()),
              ],
            ),
            if (device.interfacesAvailable && device.interfaces.isNotEmpty) ...[
              const Divider(height: 22),
              for (final usbInterface in device.interfaces) ...[
                Text(
                  'Interface ' + usbInterface.id.toString() +
                  ' · class ' + usbInterface.interfaceClass.toString() +
                  ' / subclass ' + usbInterface.interfaceSubclass.toString() +
                  ' / protocol ' + usbInterface.interfaceProtocol.toString(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                for (final endpoint in usbInterface.endpoints)
                  Padding(
                    padding: const EdgeInsets.only(left: 9, bottom: 3),
                    child: Text(
                      'Endpoint 0x' +
                          endpoint.address.toRadixString(16).padLeft(2, '0').toUpperCase() +
                          ' · ' + endpoint.direction +
                          ' · ' + endpoint.transferType +
                          ' · max packet ' + endpoint.maxPacketSize.toString() +
                          ' · interval ' + endpoint.interval.toString(),
                      style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 11),
                    ),
                  ),
              ],
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 9),
                child: Text(
                  'Windows PnP record · USB interface and endpoint descriptors are not included in this scan.',
                  style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DataChip extends StatelessWidget {
  const _DataChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      visualDensity: VisualDensity.compact,
      side: const BorderSide(color: Color(0xFF39424D)),
      backgroundColor: const Color(0xFF20262E),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171C22),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF303944)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFB5BEC9), height: 1.45, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
