import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/models/effect_block.dart';
import 'package:rigcanvas/src/models/rig_preset.dart';

void main() {
  group('PresetCodec', () {
    test('exports and imports a complete preset', () {
      final original = RigPreset.starter(
        now: DateTime.utc(2026, 11, 16),
      );
      final decoded = PresetCodec.decode(PresetCodec.encode(original));

      expect(decoded.id, original.id);
      expect(decoded.name, original.name);
      expect(decoded.blocks.length, original.blocks.length);
      expect(decoded.blocks.first.family, EffectFamily.gate);
      expect(decoded.blocks[1].parameters['gain'], 35);
    });

    test('rejects an unsupported schema version', () {
      final source = jsonEncode({
        'format': 'rigcanvas-preset',
        'schemaVersion': 999,
        'preset': RigPreset.starter().toJson(),
      });

      expect(
        () => PresetCodec.decode(source),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects parameters outside the declared range', () {
      final preset = RigPreset.starter().toJson();
      final blocks = preset['blocks'] as List<dynamic>;
      final drive = blocks[1] as Map<String, dynamic>;
      drive['parameters'] = {'gain': 999};

      final source = jsonEncode({
        'format': 'rigcanvas-preset',
        'schemaVersion': currentPresetSchemaVersion,
        'preset': preset,
      });

      expect(
        () => PresetCodec.decode(source),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects duplicate block identifiers', () {
      final preset = RigPreset.starter().toJson();
      final blocks = preset['blocks'] as List<dynamic>;
      blocks[1] = Map<String, dynamic>.from(blocks[0] as Map);

      final source = jsonEncode({
        'format': 'rigcanvas-preset',
        'schemaVersion': currentPresetSchemaVersion,
        'preset': preset,
      });

      expect(
        () => PresetCodec.decode(source),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
