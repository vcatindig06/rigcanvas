import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rigcanvas/src/device/device_gateway.dart';
import 'package:rigcanvas/src/screens/device_connection_screen.dart';

class FakeDeviceGateway implements DeviceGateway {
  BluetoothAdapterState state = BluetoothAdapterState.poweredOn;
  final StreamController<BluetoothAdapterState> stateController = StreamController<BluetoothAdapterState>.broadcast();
  final StreamController<NearbyBluetoothDevice> discoveryController = StreamController<NearbyBluetoothDevice>.broadcast();
  int startCalls = 0;
  @override BluetoothAdapterState get adapterState => state;
  @override Stream<BluetoothAdapterState> get adapterStateChanges => stateController.stream;
  @override Stream<NearbyBluetoothDevice> get discoveries => discoveryController.stream;
  @override Future<void> startDiscovery() async { startCalls++; }
  @override Future<void> stopDiscovery() async {}
  @override Future<void> dispose() async { await stateController.close(); await discoveryController.close(); }
}

void main() {
  testWidgets('scans and displays nearby devices without connecting', (tester) async {
    final gateway = FakeDeviceGateway();
    addTearDown(gateway.dispose);
    await tester.pumpWidget(MaterialApp(home: DeviceConnectionScreen(gateway: gateway)));
    expect(find.text('Start scan'), findsOneWidget);
    await tester.tap(find.text('Start scan'));
    await tester.pump();
    expect(gateway.startCalls, 1);
    expect(find.text('Stop scan'), findsOneWidget);
    gateway.discoveryController.add(const NearbyBluetoothDevice(
      id: 'test-peripheral-uuid', name: 'KPT PRO', rssi: -54,
      serviceUuids: ['0000180F-0000-1000-8000-00805F9B34FB'],
    ));
    await tester.pump();
    expect(find.text('KPT PRO'), findsOneWidget);
    expect(find.textContaining('Name contains'), findsOneWidget);
    expect(find.textContaining('-54 dBm'), findsOneWidget);
    expect(find.textContaining('Scan-only safety'), findsOneWidget);
  });

  testWidgets('disables scanning while Bluetooth is powered off', (tester) async {
    final gateway = FakeDeviceGateway()..state = BluetoothAdapterState.poweredOff;
    addTearDown(gateway.dispose);
    await tester.pumpWidget(MaterialApp(home: DeviceConnectionScreen(gateway: gateway)));
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start scan'));
    expect(button.onPressed, isNull);
    expect(find.textContaining('Turn on Bluetooth'), findsOneWidget);
  });
}
