import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/device/kpt_pro_ble_gateway.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RigCanvasApp(hardwareGateway: BluetoothKptProHardwareGateway()));
}
