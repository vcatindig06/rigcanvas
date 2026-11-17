import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rigcanvas/src/screens/device_discovery_screen.dart';
import 'package:rigcanvas_usb_inventory/rigcanvas_usb_inventory.dart';

class FakeUsbInventory implements UsbDeviceInventoryClient {
  FakeUsbInventory(this.devices);

  final List<UsbDeviceInfo> devices;
  int calls = 0;

  @override
  Future<List<UsbDeviceInfo>> listUsbDevices() async {
    calls++;
    return devices;
  }
}

void main() {
  testWidgets('scans and displays a read-only USB inventory record', (tester) async {
    final inventory = FakeUsbInventory([
      const UsbDeviceInfo(
        vendorId: 0x1234,
        productId: 0x5678,
        deviceClass: 0,
        deviceSubclass: 0,
        deviceProtocol: 0,
        name: 'Test Guitar Processor',
        manufacturer: 'Test Manufacturer',
        product: 'Test Pedal',
        interfacesAvailable: true,
        detailLevel: 'android-usb-interface-and-endpoint-descriptors',
        interfaces: [
          UsbInterfaceInfo(
            id: 0,
            interfaceClass: 1,
            interfaceSubclass: 2,
            interfaceProtocol: 0,
            endpoints: [
              UsbEndpointInfo(
                address: 0x81,
                direction: 'in',
                transferType: 'bulk',
                maxPacketSize: 64,
                interval: 0,
              ),
            ],
          ),
        ],
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DeviceDiscoveryScreen(inventory: inventory)),
      ),
    );

    expect(inventory.calls, 0);
    await tester.tap(find.byKey(const ValueKey('scan-usb-devices')));
    await tester.pumpAndSettle();

    expect(inventory.calls, 1);
    expect(find.text('Test Pedal'), findsOneWidget);
    expect(find.textContaining('VID 1234'), findsOneWidget);
    expect(find.textContaining('PID 5678'), findsOneWidget);
    expect(find.textContaining('Interface 0'), findsOneWidget);
    expect(find.textContaining('bulk'), findsOneWidget);
    expect(find.textContaining('No USB transfers'), findsOneWidget);
  });

  testWidgets('shows a clear empty state when no USB devices are attached', (tester) async {
    final inventory = FakeUsbInventory(const []);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DeviceDiscoveryScreen(inventory: inventory)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('scan-usb-devices')));
    await tester.pumpAndSettle();

    expect(find.textContaining('No USB devices were reported'), findsOneWidget);
  });
}
