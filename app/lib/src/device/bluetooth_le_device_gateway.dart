import 'dart:async';
import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import 'device_gateway.dart';

/// BLE advertisement discovery for Android and Windows.
/// This adapter never connects or reads/writes peripheral attributes.
class BluetoothLeDeviceGateway implements DeviceGateway {
  BluetoothLeDeviceGateway({CentralManager? manager})
      : _manager = manager ?? CentralManager() {
    _stateSubscription = _manager.stateChanged.listen((event) {
      if (!_disposed) _stateController.add(_mapState(event.state));
    });
    _discoverySubscription = _manager.discovered.listen((event) {
      if (_disposed) return;
      // The package does not expose advertisement names on Windows.
      String? name;
      try {
        name = event.advertisement.name?.trim();
      } on UnsupportedError {
        name = null;
      }
      _discoveryController.add(NearbyBluetoothDevice(
        id: event.peripheral.uuid.toString(),
        name: name == null || name.isEmpty ? null : name,
        rssi: event.rssi,
        serviceUuids: event.advertisement.serviceUUIDs
            .map((uuid) => uuid.toString())
            .toList(growable: false),
      ));
    });
  }

  final CentralManager _manager;
  final StreamController<BluetoothAdapterState> _stateController =
      StreamController<BluetoothAdapterState>.broadcast();
  final StreamController<NearbyBluetoothDevice> _discoveryController =
      StreamController<NearbyBluetoothDevice>.broadcast();
  late final StreamSubscription<BluetoothLowEnergyStateChangedEventArgs>
      _stateSubscription;
  late final StreamSubscription<DiscoveredEventArgs> _discoverySubscription;
  bool _scanning = false;
  bool _disposed = false;

  @override
  BluetoothAdapterState get adapterState => _mapState(_manager.state);
  @override
  Stream<BluetoothAdapterState> get adapterStateChanges => _stateController.stream;
  @override
  Stream<NearbyBluetoothDevice> get discoveries => _discoveryController.stream;

  @override
  Future<void> startDiscovery() async {
    if (_disposed) throw StateError('The Bluetooth discovery adapter has been disposed.');
    if (_scanning) return;
    if (Platform.isAndroid && _manager.state == BluetoothLowEnergyState.unauthorized) {
      final granted = await _manager.authorize();
      if (!granted) throw StateError('Bluetooth permission was not granted.');
    }
    if (_manager.state != BluetoothLowEnergyState.poweredOn) {
      throw StateError(
        'Bluetooth is not ready (${_manager.state.name}). Turn it on and grant permission, then scan.',
      );
    }
    await _manager.startDiscovery();
    _scanning = true;
  }

  @override
  Future<void> stopDiscovery() async {
    if (!_scanning || _disposed) return;
    await _manager.stopDiscovery();
    _scanning = false;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    if (_scanning) {
      try { await _manager.stopDiscovery(); } catch (_) { /* Platform may have stopped it. */ }
    }
    _disposed = true;
    await _stateSubscription.cancel();
    await _discoverySubscription.cancel();
    await _stateController.close();
    await _discoveryController.close();
  }

  static BluetoothAdapterState _mapState(BluetoothLowEnergyState state) {
    switch (state) {
      case BluetoothLowEnergyState.unknown: return BluetoothAdapterState.unknown;
      case BluetoothLowEnergyState.unsupported: return BluetoothAdapterState.unsupported;
      case BluetoothLowEnergyState.unauthorized: return BluetoothAdapterState.unauthorized;
      case BluetoothLowEnergyState.poweredOff: return BluetoothAdapterState.poweredOff;
      case BluetoothLowEnergyState.poweredOn: return BluetoothAdapterState.poweredOn;
    }
  }
}
