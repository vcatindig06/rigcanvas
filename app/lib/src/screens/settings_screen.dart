import 'package:material_ui/material_ui.dart';
import 'package:rigcanvas_usb_inventory/rigcanvas_usb_inventory.dart';

import '../device/kpt_pro_ble_gateway.dart';
import '../state/asset_controller.dart';
import '../state/preset_controller.dart';
import 'audio_engine_screen.dart';
import 'device_discovery_screen.dart';
import 'kpt_pro_control_center_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.presetController,
    required this.assetController,
    required this.usbInventory,
    required this.hardwareGateway,
    super.key,
  });

  final PresetController presetController;
  final AssetController assetController;
  final UsbDeviceInventoryClient usbInventory;
  final KptProHardwareGateway hardwareGateway;

  void _openTool(BuildContext context, String title, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: screen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF30231F),
                  child: Icon(Icons.graphic_eq, color: Color(0xFFFF987B)),
                ),
                title: const Text('Audio', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openTool(
                  context,
                  'Audio',
                  AudioEngineScreen(
                    controller: presetController,
                    assetController: assetController,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF30231F),
                  child: Icon(Icons.usb, color: Color(0xFFFF987B)),
                ),
                title: const Text('Devices', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openTool(
                  context,
                  'Devices',
                  DeviceDiscoveryScreen(
                    inventory: usbInventory,
                    hardwareGateway: hardwareGateway,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF30231F),
                  child: Icon(Icons.tune, color: Color(0xFFFF987B)),
                ),
                title: const Text(
                  'Patch Control Center',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Local backup and transfer readiness'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openTool(
                  context,
                  'Patch Control Center',
                  KptProControlCenterScreen(presetController: presetController),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
