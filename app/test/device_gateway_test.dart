import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/device/device_gateway.dart';

void main() {
  test('simulation gateway never claims hardware discovery is available', () {
    const gateway = SimulationDeviceGateway();
    expect(gateway.adapterState, BluetoothAdapterState.unsupported);
  });

  test('simulation gateway does not start a physical scan', () async {
    const gateway = SimulationDeviceGateway();
    await expectLater(gateway.startDiscovery(), throwsA(isA<UnsupportedError>()));
  });
}
