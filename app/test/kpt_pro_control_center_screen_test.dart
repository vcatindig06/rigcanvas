import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rigcanvas/src/data/preset_repository.dart';
import 'package:rigcanvas/src/models/rig_preset.dart';
import 'package:rigcanvas/src/screens/kpt_pro_control_center_screen.dart';
import 'package:rigcanvas/src/state/preset_controller.dart';

class _MemoryPresetRepository implements PresetRepository {
  final List<RigPreset> stored = <RigPreset>[];

  @override
  Future<List<RigPreset>> loadPresets() async => List.of(stored);

  @override
  Future<void> savePresets(List<RigPreset> presets) async {
    stored
      ..clear()
      ..addAll(presets);
  }
}

void main() {
  testWidgets('shows locked write state, local backup, and alternative routes',
      (tester) async {
    final controller = PresetController(_MemoryPresetRepository());
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KptProControlCenterScreen(presetController: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KPT Pro Control Center'), findsOneWidget);
    expect(find.text('HARDWARE WRITE LOCKED'), findsOneWidget);
    expect(find.text('Export local preset-library backup'), findsOneWidget);
    expect(find.text('Write disabled · No transfer bytes generated'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Passive BLE notification monitor'),
      350,
    );
    expect(find.text('Passive BLE notification monitor'), findsOneWidget);
    expect(find.text('Official M-EFCS package inspection'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Native exported patch-file analysis'),
      350,
    );
    expect(find.text('Native exported patch-file analysis'), findsOneWidget);
  });
}
