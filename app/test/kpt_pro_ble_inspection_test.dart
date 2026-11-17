import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rigcanvas/src/device/kpt_pro_ble_gateway.dart';
import 'package:rigcanvas/src/screens/kpt_pro_connection_panel.dart';

class FakeKptGateway implements KptProHardwareGateway {
  KptBluetoothAdapterState state = KptBluetoothAdapterState.poweredOn;
  final states = StreamController<KptBluetoothAdapterState>.broadcast();
  final devices = StreamController<NearbyKptBleDevice>.broadcast();
  int scanCalls = 0;
  int connectCalls = 0;
  int readCalls = 0;

  @override
  KptBluetoothAdapterState get adapterState => state;
  @override
  Stream<KptBluetoothAdapterState> get adapterStateChanges => states.stream;
  @override
  Stream<NearbyKptBleDevice> get discoveries => devices.stream;
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
      firmware: 'v15',
    );
  }
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    await states.close();
    await devices.close();
  }
}

void main() {
  testWidgets('connects, inventories GATT and reads allowlisted identity fields', (tester) async {
    final gateway = FakeKptGateway();
    addTearDown(gateway.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: KptProConnectionPanel(gateway: gateway)),
    ));

    await tester.tap(find.byKey(const ValueKey('scan-kpt-ble')));
    await tester.pumpAndSettle();
    expect(gateway.scanCalls, 1);

    gateway.devices.add(const NearbyKptBleDevice(
      id: 'ble-kpt-01',
      name: 'KPT PRO',
      rssi: -51,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('connect-kpt-device-ble-kpt-01')));
    await tester.pumpAndSettle();

    expect(gateway.connectCalls, 1);
    expect(find.text('1 GATT services'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('read-standard-device-info')));
    await tester.pumpAndSettle();

    expect(gateway.readCalls, 1);
    expect(find.text('YUIMER'), findsOneWidget);
    expect(find.text('v15'), findsOneWidget);
  });

  testWidgets('does not scan when Bluetooth is powered off', (tester) async {
    final gateway = FakeKptGateway()..state = KptBluetoothAdapterState.poweredOff;
    addTearDown(gateway.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: KptProConnectionPanel(gateway: gateway)),
    ));

    final button = tester.widget<FilledButton>(find.byKey(const ValueKey('scan-kpt-ble')));
    expect(button.onPressed, isNull);
  });
}
