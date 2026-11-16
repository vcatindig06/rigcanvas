import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/app.dart';
import 'package:rigcanvas/src/data/preset_repository.dart';
import 'package:rigcanvas/src/models/rig_preset.dart';

class MemoryPresetRepository implements PresetRepository {
  List<RigPreset> stored = <RigPreset>[];

  @override
  Future<List<RigPreset>> loadPresets() async => List.of(stored);

  @override
  Future<void> savePresets(List<RigPreset> presets) async {
    stored = List.of(presets);
  }
}

void main() {
  testWidgets('shows the RigCanvas local simulation workspace', (tester) async {
    await tester.pumpWidget(
      RigCanvasApp(repository: MemoryPresetRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('RigCanvas'), findsOneWidget);
    expect(find.text('Signal Workspace'), findsOneWidget);
    expect(find.text('KPT Pro · Disconnected'), findsOneWidget);
    expect(find.text('SIMULATION'), findsOneWidget);
    expect(find.text('Transparent Overdrive'), findsOneWidget);
  });

  testWidgets('opens the local preset library', (tester) async {
    await tester.pumpWidget(
      RigCanvasApp(repository: MemoryPresetRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Presets'));
    await tester.pumpAndSettle();

    expect(find.text('Preset Library'), findsOneWidget);
    expect(find.text('Sunday Clean + Ambient'), findsOneWidget);
    expect(find.text('New preset'), findsOneWidget);
  });
}
