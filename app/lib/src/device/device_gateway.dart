import 'package:flutter/foundation.dart';

enum BluetoothAdapterState { unknown, unsupported, unauthorized, poweredOff, poweredOn }

@immutable
class NearbyBluetoothDevice {
  const NearbyBluetoothDevice({
    required this.id,
    required this.rssi,
    this.name,
    this.serviceUuids = const <String>[],
  });

  /// Platform-provided identifier; it may differ between operating systems.
  final String id;
  final String? name;
  final int rssi;
  final List<String> serviceUuids;

  bool get nameMentionsKpt => name?.toLowerCase().contains('kpt') ?? false;
}

/// Shared UI boundary for scan-only Bluetooth discovery.
abstract interface class DeviceGateway {
  BluetoothAdapterState get adapterState;
  Stream<BluetoothAdapterState> get adapterStateChanges;
  Stream<NearbyBluetoothDevice> get discoveries;
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<void> dispose();
}

/// Safe default used in tests and preview sessions.
class SimulationDeviceGateway implements DeviceGateway {
  const SimulationDeviceGateway();

  @override
  BluetoothAdapterState get adapterState => BluetoothAdapterState.unsupported;
  @override
  Stream<BluetoothAdapterState> get adapterStateChanges =>
      const Stream<BluetoothAdapterState>.empty();
  @override
  Stream<NearbyBluetoothDevice> get discoveries =>
      const Stream<NearbyBluetoothDevice>.empty();
  @override
  Future<void> startDiscovery() async {
    throw UnsupportedError('Hardware discovery is not enabled in simulation mode.');
  }
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> dispose() async {}
}
