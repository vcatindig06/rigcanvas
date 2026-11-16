import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show TextField, TextFormField;
import 'package:rigcanvas/src/app.dart';
import 'package:rigcanvas/src/data/preset_repository.dart';
import 'package:rigcanvas/src/data/setlist_repository.dart';
import 'package:rigcanvas/src/models/rig_preset.dart';
import 'package:rigcanvas/src/models/rig_setlist.dart';

class MemoryPresetRepository implements PresetRepository {
  List<RigPreset> stored = <RigPreset>[];

  @override
  Future<List<RigPreset>> loadPresets() async => List.of(stored);

  @override
  Future<void> savePresets(List<RigPreset> presets) async {
    stored = List.of(presets);
  }
}

class MemorySetlistRepository implements SetlistRepository {
  List<RigSetlist> stored = <RigSetlist>[];

  @override
  Future<List<RigSetlist>> loadSetlists() async => List.of(stored);

  @override
  Future<void> saveSetlists(List<RigSetlist> setlists) async {
    stored = List.of(setlists);
  }
}

void main() {
  testWidgets('shows the RigCanvas local simulation workspace', (tester) async {
    await tester.pumpWidget(
      RigCanvasApp(
        repository: MemoryPresetRepository(),
        setlistRepository: MemorySetlistRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workspace'));
    await tester.pumpAndSettle();

    expect(find.text('RigCanvas'), findsOneWidget);
    expect(find.text('Signal Workspace'), findsOneWidget);
    expect(find.text('KPT Pro · Disconnected'), findsOneWidget);
    expect(find.text('SIMULATION'), findsOneWidget);
    expect(find.text('Input Gate'), findsOneWidget);
  });

  testWidgets('creates a setlist and adds a song in Gig View', (tester) async {
    await tester.pumpWidget(
      RigCanvasApp(
        repository: MemoryPresetRepository(),
        setlistRepository: MemorySetlistRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gig View'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-setlist-empty')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Sunday Gathering');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Sunday Gathering'), findsOneWidget);
    await tester.tap(find.text('Add first song'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Song title'), 'Oceans');
    await tester.enterText(find.widgetWithText(TextFormField, 'Key'), 'D');
    await tester.tap(find.text('Save song'));
    await tester.pumpAndSettle();

    expect(find.text('Oceans'), findsOneWidget);
    expect(find.textContaining('Key D'), findsOneWidget);
  });

  testWidgets('opens the local preset library', (tester) async {
    await tester.pumpWidget(
      RigCanvasApp(
        repository: MemoryPresetRepository(),
        setlistRepository: MemorySetlistRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Presets'));
    await tester.pumpAndSettle();

    expect(find.text('Preset Library'), findsOneWidget);
    expect(find.text('New preset'), findsOneWidget);
  });
}
