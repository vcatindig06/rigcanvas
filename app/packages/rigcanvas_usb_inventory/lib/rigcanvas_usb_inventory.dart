import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _usbInventoryChannel =
    MethodChannel('com.rigcanvas/usb_inventory');

abstract interface class UsbDeviceInventoryClient {
  Future<List<UsbDeviceInfo>> listUsbDevices();
}

class UsbDeviceInventory implements UsbDeviceInventoryClient {
  const UsbDeviceInventory();

  @override
  Future<List<UsbDeviceInfo>> listUsbDevices() async {
    final result = await _usbInventoryChannel.invokeMethod<List<dynamic>>(
      'listUsbDevices',
    );
    if (result == null) return const <UsbDeviceInfo>[];

    return result.map((entry) {
      if (entry is! Map) {
        throw const FormatException('Invalid USB device record returned by the platform.');
      }
      return UsbDeviceInfo.fromMap(Map<Object?, Object?>.from(entry));
    }).toList(growable: false);
  }
}

@immutable
class UsbDeviceInfo {
  const UsbDeviceInfo({
    required this.vendorId,
    required this.productId,
    required this.deviceClass,
    required this.deviceSubclass,
    required this.deviceProtocol,
    required this.name,
    this.manufacturer,
    this.product,
    this.interfacesAvailable = false,
    this.detailLevel = 'identifiers-only',
    this.interfaces = const <UsbInterfaceInfo>[],
  });

  final int vendorId;
  final int productId;
  final int deviceClass;
  final int deviceSubclass;
  final int deviceProtocol;
  final String name;
  final String? manufacturer;
  final String? product;
  final bool interfacesAvailable;
  final String detailLevel;
  final List<UsbInterfaceInfo> interfaces;

  String get vendorIdHex => vendorId.toRadixString(16).padLeft(4, '0').toUpperCase();
  String get productIdHex => productId.toRadixString(16).padLeft(4, '0').toUpperCase();
  String get displayName =>
      (product?.trim().isNotEmpty ?? false) ? product!.trim() : name;

  factory UsbDeviceInfo.fromMap(Map<Object?, Object?> map) {
    final records = map['interfaces'] as List<dynamic>? ?? const [];
    return UsbDeviceInfo(
      vendorId: _asInt(map['vendorId'], 'vendorId'),
      productId: _asInt(map['productId'], 'productId'),
      deviceClass: _asInt(map['deviceClass'], 'deviceClass'),
      deviceSubclass: _asInt(map['deviceSubclass'], 'deviceSubclass'),
      deviceProtocol: _asInt(map['deviceProtocol'], 'deviceProtocol'),
      name: _asString(map['name']) ?? 'USB device',
      manufacturer: _asString(map['manufacturer']),
      product: _asString(map['product']),
      interfacesAvailable: map['interfacesAvailable'] == true,
      detailLevel: _asString(map['detailLevel']) ?? 'identifiers-only',
      interfaces: records
          .whereType<Map>()
          .map((entry) => UsbInterfaceInfo.fromMap(Map<Object?, Object?>.from(entry)))
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'vendorId': vendorId,
    'productId': productId,
    'vendorIdHex': vendorIdHex,
    'productIdHex': productIdHex,
    'deviceClass': deviceClass,
    'deviceSubclass': deviceSubclass,
    'deviceProtocol': deviceProtocol,
    'name': name,
    'manufacturer': manufacturer,
    'product': product,
    'interfacesAvailable': interfacesAvailable,
    'detailLevel': detailLevel,
    'interfaces': interfaces.map((item) => item.toJson()).toList(),
  };
}

@immutable
class UsbInterfaceInfo {
  const UsbInterfaceInfo({
    required this.id,
    required this.interfaceClass,
    required this.interfaceSubclass,
    required this.interfaceProtocol,
    this.endpoints = const <UsbEndpointInfo>[],
  });

  final int id;
  final int interfaceClass;
  final int interfaceSubclass;
  final int interfaceProtocol;
  final List<UsbEndpointInfo> endpoints;

  factory UsbInterfaceInfo.fromMap(Map<Object?, Object?> map) {
    final records = map['endpoints'] as List<dynamic>? ?? const [];
    return UsbInterfaceInfo(
      id: _asInt(map['id'], 'interface.id'),
      interfaceClass: _asInt(map['interfaceClass'], 'interfaceClass'),
      interfaceSubclass: _asInt(map['interfaceSubclass'], 'interfaceSubclass'),
      interfaceProtocol: _asInt(map['interfaceProtocol'], 'interfaceProtocol'),
      endpoints: records
          .whereType<Map>()
          .map((entry) => UsbEndpointInfo.fromMap(Map<Object?, Object?>.from(entry)))
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'interfaceClass': interfaceClass,
    'interfaceSubclass': interfaceSubclass,
    'interfaceProtocol': interfaceProtocol,
    'endpoints': endpoints.map((item) => item.toJson()).toList(),
  };
}

@immutable
class UsbEndpointInfo {
  const UsbEndpointInfo({
    required this.address,
    required this.direction,
    required this.transferType,
    required this.maxPacketSize,
    required this.interval,
  });

  final int address;
  final String direction;
  final String transferType;
  final int maxPacketSize;
  final int interval;

  factory UsbEndpointInfo.fromMap(Map<Object?, Object?> map) {
    return UsbEndpointInfo(
      address: _asInt(map['address'], 'endpoint.address'),
      direction: _asString(map['direction']) ?? 'unknown',
      transferType: _asString(map['transferType']) ?? 'unknown',
      maxPacketSize: _asInt(map['maxPacketSize'], 'maxPacketSize'),
      interval: _asInt(map['interval'], 'interval'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'address': address,
    'direction': direction,
    'transferType': transferType,
    'maxPacketSize': maxPacketSize,
    'interval': interval,
  };
}

int _asInt(Object? value, String field) {
  if (value is int) return value;
  throw FormatException('USB inventory field "$field" is missing or invalid.');
}

String? _asString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
