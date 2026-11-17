import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../device/kpt_pro_ble_gateway.dart';

class KptProConnectionPanel extends StatefulWidget {
  const KptProConnectionPanel({required this.gateway, super.key});
  final KptProHardwareGateway gateway;

  @override
  State<KptProConnectionPanel> createState() => _KptProConnectionPanelState();
}

class _KptProConnectionPanelState extends State<KptProConnectionPanel> {
  late KptBluetoothAdapterState _adapterState;
  final Map<String, NearbyKptBleDevice> _devices = {};
  StreamSubscription<KptBluetoothAdapterState>? _stateSubscription;
  StreamSubscription<NearbyKptBleDevice>? _discoverySubscription;
  bool _scanning = false;
  String? _busyDeviceId;
  String? _error;
  KptProGattReport? _report;
  KptProDeviceInformation? _deviceInformation;

  @override
  void initState() {
    super.initState();
    _adapterState = widget.gateway.adapterState;
    _stateSubscription = widget.gateway.adapterStateChanges.listen((state) {
      if (mounted) setState(() => _adapterState = state);
    });
    _discoverySubscription = widget.gateway.discoveries.listen((device) {
      if (mounted) setState(() => _devices[device.id] = device);
    });
  }

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel());
    unawaited(_discoverySubscription?.cancel());
    super.dispose();
  }

  bool get _canScan => _adapterState == KptBluetoothAdapterState.poweredOn ||
      _adapterState == KptBluetoothAdapterState.unauthorized;

  String get _adapterMessage {
    switch (_adapterState) {
      case KptBluetoothAdapterState.unknown: return 'Checking Bluetooth availability…';
      case KptBluetoothAdapterState.unsupported: return 'Bluetooth LE is unavailable in this session.';
      case KptBluetoothAdapterState.unauthorized: return 'Bluetooth permission is required. Start a scan to request it.';
      case KptBluetoothAdapterState.poweredOff: return 'Turn on Bluetooth on the phone or PC and on the KPT Pro.';
      case KptBluetoothAdapterState.poweredOn: return 'Bluetooth is ready. Enable BT on the KPT Pro, then scan.';
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _devices.clear();
      _report = null;
      _deviceInformation = null;
      _error = null;
      _scanning = true;
    });
    try {
      await widget.gateway.startDiscovery();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _stopScan() async {
    try {
      await widget.gateway.stopDiscovery();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(NearbyKptBleDevice device) async {
    setState(() {
      _busyDeviceId = device.id;
      _error = null;
      _report = null;
      _deviceInformation = null;
    });
    try {
      final report = await widget.gateway.connectAndInspect(device.id);
      if (mounted) setState(() => _report = report);
    } catch (error) {
      if (mounted) setState(() => _error = 'GATT connection/inspection failed: $error');
    } finally {
      if (mounted) setState(() {
        _busyDeviceId = null;
        _scanning = false;
      });
    }
  }

  Future<void> _readStandardIdentity() async {
    setState(() {
      _busyDeviceId = _report?.device.id;
      _error = null;
    });
    try {
      final info = await widget.gateway.readStandardDeviceInformation();
      if (mounted) setState(() => _deviceInformation = info);
    } catch (error) {
      if (mounted) setState(() => _error = 'Standard identity read failed: $error');
    } finally {
      if (mounted) setState(() => _busyDeviceId = null);
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _busyDeviceId = _report?.device.id;
      _error = null;
    });
    try {
      await widget.gateway.disconnect();
      if (mounted) setState(() {
        _report = null;
        _deviceInformation = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Disconnect failed: $error');
    } finally {
      if (mounted) setState(() => _busyDeviceId = null);
    }
  }

  Future<void> _copyReport() async {
    final report = _report;
    if (report == null) return;
    final jsonReport = const JsonEncoder.withIndent('  ').convert(
      report.toJson(deviceInformation: _deviceInformation),
    );
    await Clipboard.setData(ClipboardData(text: jsonReport));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('KPT Pro GATT report copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = _report != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.bluetooth_searching, color: Color(0xFF9CC7A4)),
              const SizedBox(width: 10),
              const Expanded(child: Text(
                'BLUETOOTH CONNECTION & GATT INSPECTION',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
              )),
              if (connected) const Chip(avatar: Icon(Icons.link, size: 14), label: Text('Connected')),
            ]),
            const SizedBox(height: 7),
            Text(_adapterMessage, style: const TextStyle(color: Color(0xFFB8C0CC), fontSize: 12)),
            const SizedBox(height: 10),
            const Text(
              'Connect to the KPT Pro, inspect its service/characteristic map, and read standard Device Information fields where available. No GATT writes or pedal commands are sent.',
              style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 11, height: 1.45),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('scan-kpt-ble'),
                onPressed: _scanning || connected || !_canScan ? null : _startScan,
                icon: _scanning
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.bluetooth_searching, size: 18),
                label: Text(_scanning ? 'Scanning Bluetooth…' : 'Scan for KPT Pro'),
              ),
            ),
            if (_scanning)
              OutlinedButton.icon(
                key: const ValueKey('stop-kpt-ble-scan'),
                onPressed: _stopScan,
                icon: const Icon(Icons.stop, size: 16),
                label: const Text('Stop scan'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFFF987B), fontSize: 11)),
            ],
            if (_devices.isNotEmpty && !connected) ...[
              const Divider(height: 20),
              const Text('NEARBY BLUETOOTH DEVICES', style: TextStyle(
                color: Color(0xFF9AA4B2), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1,
              )),
              for (final device in _devices.values)
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Card(
                    color: const Color(0xFF101419),
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(device.name ?? 'Unnamed BLE device', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          '${device.id}\n${device.rssi} dBm · ${device.serviceUuids.isEmpty ? 'No advertised service UUIDs' : device.serviceUuids.join(' · ')}',
                          style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 10, height: 1.35),
                        ),
                        const SizedBox(height: 7),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: ValueKey('connect-kpt-device-${device.id}'),
                            onPressed: _busyDeviceId == null ? () => _connect(device) : null,
                            icon: _busyDeviceId == device.id
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.link, size: 16),
                            label: Text(_busyDeviceId == device.id ? 'Connecting…' : 'Connect & inspect'),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
            ],
            if (_scanning && _devices.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Looking for nearby BLE advertisements…', style: TextStyle(color: Color(0xFF818B99), fontSize: 11)),
              ),
            if (_report != null) ...[
              const Divider(height: 20),
              Row(children: [
                Expanded(child: Text(_report!.device.name ?? 'Connected BLE peripheral',
                    style: const TextStyle(fontWeight: FontWeight.w800))),
                TextButton.icon(
                  key: const ValueKey('copy-kpt-gatt-report'),
                  onPressed: _copyReport,
                  icon: const Icon(Icons.copy, size: 15),
                  label: const Text('Copy report'),
                ),
              ]),
              Text('${_report!.device.id} · ${_report!.services.length} GATT services',
                  style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 10)),
              const SizedBox(height: 7),
              for (final service in _report!.services)
                ExpansionTile(
                  key: ValueKey('gatt-service-${service.uuid}'),
                  tilePadding: EdgeInsets.zero,
                  title: Text(service.uuid, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  subtitle: Text('${service.characteristics.length} characteristics · ${service.isPrimary ? 'primary' : 'secondary'}'),
                  children: [
                    for (final characteristic in service.characteristics)
                      ListTile(
                        dense: true,
                        title: Text(characteristic.uuid, style: const TextStyle(fontSize: 10)),
                        subtitle: Text(characteristic.properties.map((p) => p.toUpperCase()).join(' · '),
                            style: const TextStyle(fontSize: 9, color: Color(0xFF9AA4B2))),
                      ),
                  ],
                ),
              if (_report!.hasDeviceInformationService) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('read-standard-device-info'),
                    onPressed: _busyDeviceId == null ? _readStandardIdentity : null,
                    icon: const Icon(Icons.info_outline, size: 17),
                    label: const Text('Read standard device identity'),
                  ),
                ),
              ] else
                const Text(
                  'Standard Device Information service (0x180A) is not exposed. Vendor-specific values have not been read.',
                  style: TextStyle(color: Color(0xFFFFB08E), fontSize: 10),
                ),
              if (_deviceInformation != null) ...[
                const SizedBox(height: 10),
                const Text('STANDARD DEVICE INFORMATION',
                    style: TextStyle(fontSize: 10, letterSpacing: 0.9, fontWeight: FontWeight.w800, color: Color(0xFF9CC7A4))),
                for (final entry in <String, String?>{
                  'Manufacturer': _deviceInformation!.manufacturer,
                  'Model': _deviceInformation!.model,
                  'Firmware': _deviceInformation!.firmware,
                  'Hardware': _deviceInformation!.hardware,
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      SizedBox(width: 92, child: Text(entry.key, style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 10))),
                      Expanded(child: Text(entry.value ?? 'Not reported', style: const TextStyle(fontSize: 11))),
                    ]),
                  ),
                for (final entry in _deviceInformation!.errors.entries)
                  Text('${entry.key}: ${entry.value}', style: const TextStyle(color: Color(0xFFFFB08E), fontSize: 9)),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('disconnect-kpt-device'),
                onPressed: _busyDeviceId == null ? _disconnect : null,
                icon: const Icon(Icons.link_off, size: 16),
                label: const Text('Disconnect'),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Safety boundary: vendor-specific GATT reads, characteristic writes, preset changes, firmware commands, and flash operations are disabled.',
              style: TextStyle(color: Color(0xFF818B99), fontSize: 10, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
