import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../device/device_gateway.dart';

class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({required this.gateway, super.key});
  final DeviceGateway gateway;

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
  late BluetoothAdapterState _adapterState;
  final Map<String, NearbyBluetoothDevice> _devices = {};
  StreamSubscription<BluetoothAdapterState>? _stateSubscription;
  StreamSubscription<NearbyBluetoothDevice>? _discoverySubscription;
  bool _scanning = false;
  String? _errorMessage;

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

  bool get _canScan =>
      _adapterState == BluetoothAdapterState.poweredOn ||
      _adapterState == BluetoothAdapterState.unauthorized;

  String get _adapterMessage {
    switch (_adapterState) {
      case BluetoothAdapterState.unknown: return 'Checking Bluetooth availability…';
      case BluetoothAdapterState.unsupported: return 'Bluetooth LE discovery is unavailable in this session.';
      case BluetoothAdapterState.unauthorized: return 'Bluetooth permission is required. Start a scan to request it.';
      case BluetoothAdapterState.poweredOff: return 'Turn on Bluetooth on this device and on your KPT Pro.';
      case BluetoothAdapterState.poweredOn: return 'Bluetooth is ready. Put the KPT Pro in Bluetooth mode, then scan.';
    }
  }

  Future<void> _startScan() async {
    setState(() { _devices.clear(); _errorMessage = null; _scanning = true; });
    try {
      await widget.gateway.startDiscovery();
    } catch (error) {
      if (!mounted) return;
      setState(() { _scanning = false; _errorMessage = error.toString().replaceFirst('Bad state: ', ''); });
    }
  }

  Future<void> _stopScan() async {
    try {
      await widget.gateway.stopDiscovery();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Device connection', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          const Text('Discover a nearby KPT Pro using Bluetooth Low Energy.',
              style: TextStyle(color: Color(0xFF9AA4B2))),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(_adapterState == BluetoothAdapterState.poweredOn
                        ? Icons.bluetooth_connected : Icons.bluetooth,
                      color: _adapterState == BluetoothAdapterState.poweredOn
                        ? const Color(0xFF65D6A0) : const Color(0xFFFFB29D)),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Bluetooth Low Energy discovery',
                        style: TextStyle(fontWeight: FontWeight.w700))),
                    if (_scanning) const Text('SCANNING',
                      style: TextStyle(color: Color(0xFF65D6A0), fontSize: 10,
                          fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ]),
                  const SizedBox(height: 10),
                  Text(_adapterMessage, style: const TextStyle(color: Color(0xFFB8C0CC), fontSize: 13)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _scanning ? _stopScan : (_canScan ? _startScan : null),
                      icon: Icon(_scanning ? Icons.stop : Icons.search, size: 18),
                      label: Text(_scanning ? 'Stop scan' : 'Start scan'),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFF987B), fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('NEARBY DEVICES', style: TextStyle(
            color: Color(0xFF9AA4B2), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.3)),
          const SizedBox(height: 8),
          Expanded(
            child: _devices.isEmpty
                ? Center(child: Text(_scanning ? 'Looking for nearby BLE advertisements…' : 'No scan results yet.',
                    textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF818B99))))
                : ListView.separated(
                    itemCount: _devices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final device = _devices.values.elementAt(index);
                      final services = device.serviceUuids.isEmpty
                          ? 'No service UUIDs advertised' : device.serviceUuids.join(' · ');
                      return Card(child: ListTile(
                        leading: Icon(device.nameMentionsKpt ? Icons.sports_esports : Icons.bluetooth,
                            color: device.nameMentionsKpt ? const Color(0xFFFF987B) : const Color(0xFF9AA4B2)),
                        title: Text(device.name ?? 'Unnamed BLE device'),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(device.id, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text('${device.rssi} dBm · ${services}', maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (device.nameMentionsKpt)
                            const Text('Name contains “KPT” · verify against your pedal',
                                style: TextStyle(color: Color(0xFFFFB29D), fontSize: 11)),
                        ]),
                        isThreeLine: true,
                      ));
                    },
                  ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan-only safety: RigCanvas does not connect, read GATT values, change pedal settings, or write presets here. A missing scan result does not prove the KPT Pro is unsupported; its M-EFCS transport still needs to be identified.',
            style: TextStyle(color: Color(0xFF818B99), fontSize: 11)),
        ],
      ),
    );
  }
}
