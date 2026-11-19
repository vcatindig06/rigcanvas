import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';

import 'kpt_pro_protocol.dart';

enum KptBluetoothAdapterState { unknown, unsupported, unauthorized, poweredOff, poweredOn }

@immutable
class NearbyKptBleDevice {
  const NearbyKptBleDevice({required this.id, required this.rssi, this.name, this.serviceUuids = const []});
  final String id;
  final int rssi;
  final String? name;
  final List<String> serviceUuids;
}

@immutable
class KptGattCharacteristicSnapshot {
  const KptGattCharacteristicSnapshot({required this.uuid, required this.properties, required this.descriptorUuids});
  final String uuid;
  final List<String> properties;
  final List<String> descriptorUuids;
  Map<String, Object?> toJson() => {'uuid': uuid, 'properties': properties, 'descriptors': descriptorUuids};
}

@immutable
class KptGattServiceSnapshot {
  const KptGattServiceSnapshot({required this.uuid, required this.isPrimary, required this.characteristics});
  final String uuid;
  final bool isPrimary;
  final List<KptGattCharacteristicSnapshot> characteristics;
  Map<String, Object?> toJson() => {
    'uuid': uuid,
    'primary': isPrimary,
    'characteristics': characteristics.map((item) => item.toJson()).toList(),
  };
}

@immutable
class KptProDeviceInformation {
  const KptProDeviceInformation({this.manufacturer, this.model, this.firmware, this.hardware, this.errors = const {}});
  final String? manufacturer;
  final String? model;
  final String? firmware;
  final String? hardware;
  final Map<String, String> errors;
  Map<String, Object?> toJson() => {
    'manufacturer': manufacturer,
    'model': model,
    'firmware': firmware,
    'hardware': hardware,
    'readErrors': errors,
  };
}

/// One vendor-characteristic notification received after the user starts
/// the optional passive monitor. Raw bytes are retained for local diagnostics.
@immutable
class KptProVendorNotification {
  KptProVendorNotification({
    required this.receivedAt,
    required List<int> value,
    required List<KptProProtocolFrame> frames,
    this.frameParseError,
  }) : value = List<int>.unmodifiable(value),
       frames = List<KptProProtocolFrame>.unmodifiable(frames);

  final DateTime receivedAt;
  final List<int> value;
  final List<KptProProtocolFrame> frames;
  final String? frameParseError;

  String get valueHex => value.map(_hexByte).join(' ');

  Map<String, Object?> toJson() => {
    'receivedAt': receivedAt.toUtc().toIso8601String(),
    'valueLengthBytes': value.length,
    'valueHex': valueHex,
    'validatedFrames': frames.map((frame) => {
      'commandId': '0x${frame.commandId.toRadixString(16).padLeft(2, '0').toUpperCase()}',
      'bodyLengthBytes': frame.bodyLength,
      'checksumValid': true,
      'rawFrameHex': frame.rawBytes.map(_hexByte).join(' '),
    }).toList(),
    'frameParseError': frameParseError,
  };

  static String _hexByte(int value) =>
      value.toRadixString(16).padLeft(2, '0').toUpperCase();
}

@immutable
class KptProVendorMonitorInfo {
  const KptProVendorMonitorInfo({
    required this.enabled,
    required this.characteristicUuid,
    required this.message,
  });

  final bool enabled;
  final String characteristicUuid;
  final String message;
}

@immutable
class KptProGattReport {
  const KptProGattReport({required this.device, required this.services, required this.capturedAt});
  final NearbyKptBleDevice device;
  final List<KptGattServiceSnapshot> services;
  final DateTime capturedAt;

  bool get hasDeviceInformationService => services.any((s) => _isBluetoothUuid(s.uuid, '180a'));

  /// True only when AE40 contains AE42 with Notify or Indicate in this GATT map.
  bool get hasKptProVendorNotifyCharacteristic => services.any((service) =>
      _isBluetoothUuid(service.uuid, 'ae40') &&
      service.characteristics.any((characteristic) =>
          _isBluetoothUuid(characteristic.uuid, 'ae42') &&
          (characteristic.properties.contains('notify') ||
              characteristic.properties.contains('indicate'))));

  Map<String, Object?> toJson({KptProDeviceInformation? deviceInformation}) => {
    'reportType': 'RigCanvas read-only KPT Pro BLE/GATT inspection',
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'device': {
      'name': device.name,
      'platformPeripheralId': device.id,
      'rssiDbm': device.rssi,
      'advertisedServiceUuids': device.serviceUuids,
    },
    'gattServices': services.map((s) => s.toJson()).toList(),
    'standardDeviceInformation': deviceInformation?.toJson(),
    'safety': {
      'vendorCharacteristicValuesRead': false,
      'vendorCharacteristicValuesWritten': false,
      'vendorNotificationSubscriptionAtInspection': false,
      'presetCommandsSent': false,
      'firmwareOperationsSent': false,
    },
  };
}

abstract interface class KptProHardwareGateway {
  KptBluetoothAdapterState get adapterState;
  Stream<KptBluetoothAdapterState> get adapterStateChanges;
  Stream<NearbyKptBleDevice> get discoveries;
  Stream<KptProVendorNotification> get vendorNotifications;
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<KptProGattReport> connectAndInspect(String deviceId);
  Future<KptProDeviceInformation> readStandardDeviceInformation();
  Future<KptProVendorMonitorInfo> startVendorNotificationMonitor();
  Future<void> stopVendorNotificationMonitor();
  Future<void> disconnect();
  Future<void> dispose();
}

class SimulationKptProHardwareGateway implements KptProHardwareGateway {
  const SimulationKptProHardwareGateway();
  @override
  KptBluetoothAdapterState get adapterState => KptBluetoothAdapterState.unsupported;
  @override
  Stream<KptBluetoothAdapterState> get adapterStateChanges => const Stream.empty();
  @override
  Stream<NearbyKptBleDevice> get discoveries => const Stream.empty();
  @override
  Stream<KptProVendorNotification> get vendorNotifications => const Stream.empty();
  @override
  Future<void> startDiscovery() async => throw UnsupportedError('Bluetooth is unavailable in simulation mode.');
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<KptProGattReport> connectAndInspect(String id) async => throw UnsupportedError('Hardware inspection is unavailable in simulation mode.');
  @override
  Future<KptProDeviceInformation> readStandardDeviceInformation() async => throw UnsupportedError('Hardware inspection is unavailable in simulation mode.');
  @override
  Future<KptProVendorMonitorInfo> startVendorNotificationMonitor() async => throw UnsupportedError('Vendor notification monitoring is unavailable in simulation mode.');
  @override
  Future<void> stopVendorNotificationMonitor() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {}
}

/// BLE central adapter with read-only inspection and an opt-in passive vendor
/// Notify monitor. It never reads/writes vendor values or sends pedal commands.
class BluetoothKptProHardwareGateway implements KptProHardwareGateway {
  BluetoothKptProHardwareGateway({CentralManager? manager}) : _manager = manager ?? CentralManager() {
    _stateSubscription = _manager.stateChanged.listen((event) {
      if (!_disposed) _stateController.add(_mapState(event.state));
    });
    _notificationSubscription = _manager.characteristicNotified.listen(_handleVendorNotification);
    _discoverySubscription = _manager.discovered.listen((event) {
      if (_disposed) return;
      String? name;
      try {
        name = event.advertisement.name?.trim();
      } on UnsupportedError {
        name = null;
      }
      final device = NearbyKptBleDevice(
        id: event.peripheral.uuid.toString(),
        name: name == null || name.isEmpty ? null : name,
        rssi: event.rssi,
        serviceUuids: event.advertisement.serviceUUIDs.map((u) => u.toString()).toList(growable: false),
      );
      _peripherals[device.id] = event.peripheral;
      _devices[device.id] = device;
      _discoveryController.add(device);
    });
  }

  final CentralManager _manager;
  final Map<String, Peripheral> _peripherals = {};
  final Map<String, NearbyKptBleDevice> _devices = {};
  final StreamController<KptBluetoothAdapterState> _stateController = StreamController.broadcast();
  final StreamController<NearbyKptBleDevice> _discoveryController = StreamController.broadcast();
  final StreamController<KptProVendorNotification> _vendorNotificationController = StreamController.broadcast();
  late final StreamSubscription<BluetoothLowEnergyStateChangedEventArgs> _stateSubscription;
  late final StreamSubscription<DiscoveredEventArgs> _discoverySubscription;
  late final StreamSubscription<GATTCharacteristicNotifiedEventArgs> _notificationSubscription;
  bool _scanning = false;
  bool _disposed = false;
  Peripheral? _connectedPeripheral;
  NearbyKptBleDevice? _connectedDevice;
  List<GATTService> _connectedServices = const [];
  GATTCharacteristic? _vendorNotifyCharacteristic;
  bool _vendorNotificationMonitorEnabled = false;
  KptProNotificationFrameReassembler? _vendorFrameReassembler;

  @override
  KptBluetoothAdapterState get adapterState => _mapState(_manager.state);
  @override
  Stream<KptBluetoothAdapterState> get adapterStateChanges => _stateController.stream;
  @override
  Stream<NearbyKptBleDevice> get discoveries => _discoveryController.stream;
  @override
  Stream<KptProVendorNotification> get vendorNotifications => _vendorNotificationController.stream;

  @override
  Future<void> startDiscovery() async {
    _ensureAlive();
    if (_scanning) return;
    if (Platform.isAndroid && _manager.state == BluetoothLowEnergyState.unauthorized) {
      final granted = await _manager.authorize();
      if (!granted) throw StateError('Bluetooth permission was not granted.');
    }
    if (_manager.state != BluetoothLowEnergyState.poweredOn) {
      throw StateError('Bluetooth is not ready (${_manager.state.name}). Enable Bluetooth and grant permission.');
    }
    _peripherals.clear();
    _devices.clear();
    await _manager.startDiscovery();
    _scanning = true;
  }

  @override
  Future<void> stopDiscovery() async {
    _ensureAlive();
    if (!_scanning) return;
    await _manager.stopDiscovery();
    _scanning = false;
  }

  @override
  Future<KptProGattReport> connectAndInspect(String deviceId) async {
    _ensureAlive();
    final peripheral = _peripherals[deviceId];
    final device = _devices[deviceId];
    if (peripheral == null || device == null) {
      throw StateError('Scan result is no longer available. Scan again and select the pedal.');
    }
    if (_scanning) await stopDiscovery();
    if (_connectedPeripheral != null) await disconnect();

    await _manager.connect(peripheral);
    _connectedPeripheral = peripheral;
    _connectedDevice = device;
    try {
      _connectedServices = await _manager.discoverGATT(peripheral);
      return _buildReport();
    } catch (_) {
      try { await _manager.disconnect(peripheral); } catch (_) { /* preserve original error */ }
      _connectedPeripheral = null;
      _connectedDevice = null;
      _connectedServices = const [];
      rethrow;
    }
  }

  /// Enables Notify/Indicate on discovered AE40/AE42. This configures the
  /// BLE CCCD only; it does not read/write vendor values or send a KPT command.
  @override
  Future<KptProVendorMonitorInfo> startVendorNotificationMonitor() async {
    _ensureAlive();
    final peripheral = _connectedPeripheral;
    if (peripheral == null) {
      throw StateError('Connect to the pedal before monitoring vendor notifications.');
    }
    if (_vendorNotificationMonitorEnabled && _vendorNotifyCharacteristic != null) {
      return KptProVendorMonitorInfo(
        enabled: true,
        characteristicUuid: _vendorNotifyCharacteristic!.uuid.toString(),
        message: 'Passive vendor notification monitoring is already active.',
      );
    }

    GATTCharacteristic? target;
    for (final service in _connectedServices) {
      if (!_isBluetoothUuid(service.uuid.toString(), 'ae40')) continue;
      for (final characteristic in service.characteristics) {
        if (_isBluetoothUuid(characteristic.uuid.toString(), 'ae42')) {
          target = characteristic;
          break;
        }
      }
    }
    if (target == null) {
      throw StateError('The discovered KPT vendor service does not contain characteristic AE42.');
    }
    final canNotify = target.properties.contains(GATTCharacteristicProperty.notify);
    final canIndicate = target.properties.contains(GATTCharacteristicProperty.indicate);
    if (!canNotify && !canIndicate) {
      throw StateError('AE42 does not advertise Notify or Indicate in this GATT session.');
    }

    _vendorFrameReassembler = KptProNotificationFrameReassembler();
    _vendorNotifyCharacteristic = target;
    // Enable the event handler before the asynchronous CCCD operation starts.
    _vendorNotificationMonitorEnabled = true;
    try {
      await _manager.setCharacteristicNotifyState(peripheral, target, state: true);
    } catch (_) {
      _resetVendorNotificationMonitor();
      rethrow;
    }
    return KptProVendorMonitorInfo(
      enabled: true,
      characteristicUuid: target.uuid.toString(),
      message: 'Listening passively for pedal notifications. No vendor command was sent.',
    );
  }

  @override
  Future<void> stopVendorNotificationMonitor() async {
    final peripheral = _connectedPeripheral;
    final characteristic = _vendorNotifyCharacteristic;
    if (!_vendorNotificationMonitorEnabled || peripheral == null || characteristic == null) {
      _resetVendorNotificationMonitor();
      return;
    }
    try {
      await _manager.setCharacteristicNotifyState(peripheral, characteristic, state: false);
    } finally {
      _resetVendorNotificationMonitor();
    }
  }

  void _handleVendorNotification(GATTCharacteristicNotifiedEventArgs event) {
    if (_disposed || !_vendorNotificationMonitorEnabled) return;
    final peripheral = _connectedPeripheral;
    final characteristic = _vendorNotifyCharacteristic;
    if (peripheral == null || characteristic == null) return;
    if (event.peripheral.uuid.toString() != peripheral.uuid.toString()) return;
    if (!_isBluetoothUuid(event.characteristic.uuid.toString(), 'ae42')) return;

    final value = event.value.toList(growable: false);
    var frames = const <KptProProtocolFrame>[];
    String? parseError;
    try {
      frames = _vendorFrameReassembler?.addNotification(value) ??
          const <KptProProtocolFrame>[];
    } on FormatException catch (error) {
      parseError = error.message;
      _vendorFrameReassembler?.reset();
    }
    if (!_vendorNotificationController.isClosed) {
      _vendorNotificationController.add(KptProVendorNotification(
        receivedAt: DateTime.now(),
        value: value,
        frames: frames,
        frameParseError: parseError,
      ));
    }
  }

  void _resetVendorNotificationMonitor() {
    _vendorNotificationMonitorEnabled = false;
    _vendorNotifyCharacteristic = null;
    _vendorFrameReassembler?.reset();
    _vendorFrameReassembler = null;
  }

  @override
  Future<KptProDeviceInformation> readStandardDeviceInformation() async {
    _ensureAlive();
    final peripheral = _connectedPeripheral;
    if (peripheral == null) throw StateError('Connect before reading standard identity fields.');

    GATTService? infoService;
    for (final service in _connectedServices) {
      if (_isBluetoothUuid(service.uuid.toString(), '180a')) {
        infoService = service;
        break;
      }
    }
    if (infoService == null) {
      return const KptProDeviceInformation(errors: {
        'service': 'Standard Device Information service 0x180A is not exposed.',
      });
    }

    // Allowlist only. Serial number 0x2A25 and vendor-specific values are excluded.
    const allowlist = {
      '2a29': 'manufacturer',
      '2a24': 'model',
      '2a26': 'firmware',
      '2a27': 'hardware',
    };
    final values = <String, String?>{
      'manufacturer': null, 'model': null, 'firmware': null, 'hardware': null,
    };
    final errors = <String, String>{};

    for (final item in allowlist.entries) {
      GATTCharacteristic? characteristic;
      for (final candidate in infoService.characteristics) {
        if (_isBluetoothUuid(candidate.uuid.toString(), item.key)) {
          characteristic = candidate;
          break;
        }
      }
      if (characteristic == null) {
        errors[item.value] = 'Characteristic ${item.key.toUpperCase()} is not exposed.';
        continue;
      }
      if (!characteristic.properties.contains(GATTCharacteristicProperty.read)) {
        errors[item.value] = 'Characteristic ${item.key.toUpperCase()} is not readable.';
        continue;
      }
      try {
        final bytes = await _manager.readCharacteristic(peripheral, characteristic);
        final value = utf8.decode(bytes, allowMalformed: true).replaceAll(' ', '').trim();
        values[item.value] = value.isEmpty ? null : value;
        if (value.isEmpty) errors[item.value] = 'Characteristic returned an empty value.';
      } catch (error) {
        errors[item.value] = error.toString();
      }
    }

    return KptProDeviceInformation(
      manufacturer: values['manufacturer'],
      model: values['model'],
      firmware: values['firmware'],
      hardware: values['hardware'],
      errors: Map.unmodifiable(errors),
    );
  }

  @override
  Future<void> disconnect() async {
    _ensureAlive();
    final peripheral = _connectedPeripheral;
    if (peripheral == null) return;
    try {
      try { await stopVendorNotificationMonitor(); } catch (_) { /* link may already be lost */ }
      await _manager.disconnect(peripheral);
    } finally {
      _resetVendorNotificationMonitor();
      _connectedPeripheral = null;
      _connectedDevice = null;
      _connectedServices = const [];
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    if (_scanning) {
      try { await _manager.stopDiscovery(); } catch (_) { /* adapter already stopped */ }
    }
    if (_connectedPeripheral != null) {
      try { await stopVendorNotificationMonitor(); } catch (_) { /* connection dropped */ }
      try { await _manager.disconnect(_connectedPeripheral!); } catch (_) { /* connection dropped */ }
    }
    _scanning = false;
    _connectedPeripheral = null;
    _connectedDevice = null;
    _connectedServices = const [];
    _resetVendorNotificationMonitor();
    _disposed = true;
    await _stateSubscription.cancel();
    await _discoverySubscription.cancel();
    await _notificationSubscription.cancel();
    await _stateController.close();
    await _discoveryController.close();
    await _vendorNotificationController.close();
  }

  KptProGattReport _buildReport() {
    final device = _connectedDevice;
    if (device == null) throw StateError('No connected peripheral selected.');
    return KptProGattReport(
      device: device,
      services: _connectedServices.map((service) => KptGattServiceSnapshot(
        uuid: service.uuid.toString(),
        isPrimary: service.isPrimary,
        characteristics: service.characteristics.map((characteristic) => KptGattCharacteristicSnapshot(
          uuid: characteristic.uuid.toString(),
          properties: characteristic.properties.map((property) => property.name).toList(growable: false),
          descriptorUuids: characteristic.descriptors.map((descriptor) => descriptor.uuid.toString()).toList(growable: false),
        )).toList(growable: false),
      )).toList(growable: false),
      capturedAt: DateTime.now(),
    );
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('KPT Pro BLE gateway has been disposed.');
  }

  static KptBluetoothAdapterState _mapState(BluetoothLowEnergyState state) {
    switch (state) {
      case BluetoothLowEnergyState.unknown: return KptBluetoothAdapterState.unknown;
      case BluetoothLowEnergyState.unsupported: return KptBluetoothAdapterState.unsupported;
      case BluetoothLowEnergyState.unauthorized: return KptBluetoothAdapterState.unauthorized;
      case BluetoothLowEnergyState.poweredOff: return KptBluetoothAdapterState.poweredOff;
      case BluetoothLowEnergyState.poweredOn: return KptBluetoothAdapterState.poweredOn;
    }
  }
}

bool _isBluetoothUuid(String value, String shortUuid) {
  final normalized = value.replaceAll('-', '').toLowerCase();
  final short = shortUuid.toLowerCase();
  return normalized == short ||
      normalized == '0000$short' ||
      normalized == '0000${short}00001000800000805f9b34fb';
}
