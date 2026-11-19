import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/device/kpt_pro_write_plan.dart';
import 'package:rigcanvas/src/models/rig_preset.dart';

void main() {
  test('write preview stays locked without verified KPT Pro evidence', () {
    final preset = RigPreset.starter();
    final plan = const KptProWritePlanner().prepare(preset);

    expect(plan.presetId, preset.id);
    expect(plan.presetName, preset.name);
    expect(plan.blockCount, preset.blocks.length);
    expect(plan.sceneCount, preset.scenes.length);
    expect(plan.isBlocked, isTrue);
    expect(plan.hardwareWriteEnabled, isFalse);
    expect(plan.payloadGenerated, isFalse);
    expect(
      plan.blockers.map((item) => item.code),
      containsAll([
        'command-semantics',
        'patch-schema',
        'transaction-verification',
        'recovery',
        'native-file-fixture',
      ]),
    );
  });
}
