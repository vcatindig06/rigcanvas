import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/device/device_gateway.dart';

void main() {
  test('simulation gateway never reports a physical pedal as connected',
      () async {
    const gateway = SimulationDeviceGateway();

    final result = await gateway.discover();

    expect(result.state, DeviceConnectionState.disconnected);
    expect(result.identity, isNull);
    expect(result.capabilities.features, isEmpty);
    expect(result.message, contains('Simulation mode'));
  });
}
