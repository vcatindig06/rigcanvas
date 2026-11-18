import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rigcanvas/src/device/kpt_pro_ble_gateway.dart';
import 'package:rigcanvas/src/device/kpt_pro_protocol.dart';
import 'package:rigcanvas/src/screens/kpt_pro_connection_panel.dart';

class FakeKptGateway implements KptProHardwareGateway {
  KptBluetoothAdapterState state = KptBluetoothAdapterState.poweredOn;
  final states = StreamController<KptBluetoothAdapterState>.broadcast();
  final devices = StreamController<NearbyKptBleDevice>.broadcast();
  final notifications = StreamController<KptProVendorNotification>.broadcast();
  int scanCalls = 0;
  int connectCalls = 0;
  int readCalls = 0;
  int monitorStartCalls = 0;
  int monitorStopCalls = 0;
  bool monitoring = false;

  @override
  KptBluetoothAdapterState get adapterState => state;
  @override
  Stream<KptBluetoothAdapterState> get adapterStateChanges => states.stream;
  @override
  Stream<NearbyKptBleDevice> get discoveries => devices.stream;
  @override
  Stream<KptProVendorNotification> get vendorNotifications => notifications.stream;
  @override
  Future<void> startDiscovery() async { scanCalls++; }
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<KptProGattReport> connectAndInspect(String deviceId) async {
    connectCalls++;
    return KptProGattReport(
      device: NearbyKptBleDevice(id: deviceId, name: 'KPT PRO', rssi: -51),
      services: const [
        KptGattServiceSnapshot(
          uuid: '0000AE40-0000-1000-8000-00805F9B34FB',
          isPrimary: true,
          characteristics: [
            KptGattCharacteristicSnapshot(
              uuid: '0000AE42-0000-1000-8000-00805F9B34FB',
              properties: ['notify'],
              descriptorUuids: ['00002902-0000-1000-8000-00805F9B34FB'],
            ),
          ],
        ),
        KptGattServiceSnapshot(
          uuid: '0000180A-0000-1000-8000-00805F9B34FB',
          isPrimary: true,
          characteristics: [
            KptGattCharacteristicSnapshot(
              uuid: '00002A26-0000-1000-8000-00805F9B34FB',
              properties: ['read'],
              descriptorUuids: [],
            ),
          ],
        ),
      ],
      capturedAt: DateTime.utc(2026, 11, 17),
    );
  }
  @override
  Future<KptProDeviceInformation> readStandardDeviceInformation() async {
    readCalls++;
    return const KptProDeviceInformation(
      manufacturer: 'YUIMER',
      model: 'KPT PRO',
      firmware: 'v8',
    );
  }
  @override
  Future<KptProVendorMonitorInfo> startVendorNotificationMonitor() async {
    monitorStartCalls++;
    monitoring = true;
    return const KptProVendorMonitorInfo(enabled: true, characteristicUuid: '0000AE42-0000-1000-8000-00805F9B34FB', message: 'Passive vendor notification monitoring started.');
  }
  @override
  Future<void> stopVendorNotificationMonitor() async {
    monitorStopCalls++;
    monitoring = false;
  }
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    await states.close();
    await devices.close();
    await notifications.close();
  }
}

void main() {
  testWidgets('connects, inventories GATT and reads allowlisted identity fields', (tester) async {
    final gateway = FakeKptGateway();
    addTearDown(gateway.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: KptProConnectionPanel(gateway: gateway))),
    ));

    await tester.tap(find.byKey(const ValueKey('scan-kpt-ble')));
    // Scanning intentionally shows an indeterminate progress indicator.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(gateway.scanCalls, 1);

    gateway.devices.add(const NearbyKptBleDevice(
      id: 'ble-kpt-01',
      name: 'KPT PRO',
      rssi: -51,
    ));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('connect-kpt-device-ble-kpt-01')));
    await tester.pumpAndSettle();

    expect(gateway.connectCalls, 1);
    expect(find.textContaining('2 GATT services'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('read-standard-device-info')));
    await tester.pumpAndSettle();

    expect(gateway.readCalls, 1);
    expect(find.text('YUIMER'), findsOneWidget);
    expect(find.text('v8'), findsOneWidget);
  });

  testWidgets('starts passive notification monitoring and displays validated frames', (tester) async {
    final gateway = FakeKptGateway();
    addTearDown(gateway.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: KptProConnectionPanel(gateway: gateway))),
    ));
    await tester.tap(find.byKey(const ValueKey('scan-kpt-ble')));
    await tester.pump();
    gateway.devices.add(const NearbyKptBleDevice(id: 'ble-kpt-01', name: 'KPT PRO', rssi: -51));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('connect-kpt-device-ble-kpt-01')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('start-kpt-vendor-notify-monitor')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('start-kpt-vendor-notify-monitor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-kpt-vendor-notify-monitor')));
    await tester.pumpAndSettle();
    expect(gateway.monitorStartCalls, 1);
    expect(gateway.monitoring, isTrue);

    const rawFrame = [0x00, 0x59, 0x11, 0x00, 0x00, 0x00, 0xFF];
    gateway.notifications.add(KptProVendorNotification(
      receivedAt: DateTime.utc(2026, 11, 18, 9),
      value: rawFrame,
      frames: [KptProProtocolFrame.parse(rawFrame)],
    ));
    await tester.pump();

    expect(find.textContaining('1 observed notification value(s)'), findsOneWidget);
    expect(find.textContaining('CMD 0x11'), findsOneWidget);
    expect(find.byKey(const ValueKey('copy-kpt-vendor-notifications')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('stop-kpt-vendor-notify-monitor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stop-kpt-vendor-notify-monitor')));
    await tester.pumpAndSettle();
    expect(gateway.monitorStopCalls, 1);
    expect(gateway.monitoring, isFalse);
  });

  testWidgets('does not scan when Bluetooth is powered off', (tester) async {
    final gateway = FakeKptGateway()..state = KptBluetoothAdapterState.poweredOff;
    addTearDown(gateway.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: KptProConnectionPanel(gateway: gateway))),
    ));

    final button = tester.widget<FilledButton>(find.byKey(const ValueKey('scan-kpt-ble')));
    expect(button.onPressed, isNull);
  });
}
