import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/app.dart';

void main() {
  testWidgets('shows the RigCanvas simulation workspace', (tester) async {
    await tester.pumpWidget(const RigCanvasApp());

    expect(find.text('RigCanvas'), findsOneWidget);
    expect(find.text('Signal Workspace'), findsOneWidget);
    expect(find.text('KPT Pro · Disconnected'), findsOneWidget);
    expect(find.text('SIMULATION'), findsOneWidget);
    expect(find.text('Transparent Overdrive'), findsOneWidget);
  });
}
