import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/device/bluetooth_le_device_gateway.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RigCanvasApp(deviceGateway: BluetoothLeDeviceGateway()));
}
