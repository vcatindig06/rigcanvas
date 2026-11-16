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

    test('round-trips scene snapshots with the preset', () {
      final preset = RigPreset.starter();
      final withScene = preset.copyWith(
        scenes: [
          RigScene(
            id: 'scene-chorus',
            name: 'Chorus',
            createdAt: DateTime.utc(2026, 11, 16),
            blocks: preset.blocks,
          ),
        ],
      );

      final restored = PresetCodec.decode(PresetCodec.encode(withScene));

      expect(restored.scenes, hasLength(1));
      expect(restored.scenes.single.name, 'Chorus');
      expect(restored.scenes.single.blocks[1].parameters['gain'], 35);
    });

    test('loads an older preset that has no scenes field', () {
      final presetJson = RigPreset.starter().toJson()..remove('scenes');
      final source = jsonEncode({
        'format': 'rigcanvas-preset',
        'schemaVersion': currentPresetSchemaVersion,
        'preset': presetJson,
      });

      final restored = PresetCodec.decode(source);

      expect(restored.scenes, isEmpty);
    });


    test('round-trips capture and cabinet IR references in presets and scenes', () {
      final starter = RigPreset.starter();
      final linkedBlocks = starter.blocks.map((block) {
        if (block.family == EffectFamily.amplifier) {
          return block.copyWith(assetId: 'asset-capture');
        }
        if (block.family == EffectFamily.cabinet) {
          return block.copyWith(assetId: 'asset-cabinet-ir');
        }
        return block;
      }).toList();
      final linkedPreset = starter.copyWith(
        blocks: linkedBlocks,
        scenes: [
          RigScene(
            id: 'scene-linked-assets',
            name: 'Linked Assets',
            createdAt: DateTime.utc(2026, 11, 16),
            blocks: linkedBlocks,
          ),
        ],
      );

      final restored = PresetCodec.decode(PresetCodec.encode(linkedPreset));
      final amplifier = restored.blocks.firstWhere(
        (block) => block.family == EffectFamily.amplifier,
      );
      final cabinet = restored.blocks.firstWhere(
        (block) => block.family == EffectFamily.cabinet,
      );

      expect(amplifier.assetId, 'asset-capture');
      expect(cabinet.assetId, 'asset-cabinet-ir');
      expect(
        restored.scenes.single.blocks
            .firstWhere((block) => block.family == EffectFamily.amplifier)
            .assetId,
        'asset-capture',
      );
    });

    test('continues to read legacy blocks without an asset reference', () {
      final presetJson = RigPreset.starter().toJson();
      final blocks = presetJson['blocks'] as List<dynamic>;
      for (final block in blocks) {
        (block as Map<String, dynamic>).remove('assetId');
      }
      final source = jsonEncode({
        'format': 'rigcanvas-preset',
        'schemaVersion': currentPresetSchemaVersion,
        'preset': presetJson,
      });

      final restored = PresetCodec.decode(source);

      expect(restored.blocks.every((block) => block.assetId == null), isTrue);
    });

    test('rejects asset links on unrelated effect families', () {
      final presetJson = RigPreset.starter().toJson();
      final blocks = presetJson['blocks'] as List<dynamic>;
      final gate = blocks.first as Map<String, dynamic>;
      gate['assetId'] = 'asset-invalid';

      final source = jsonEncode({
        'format': 'rigcanvas-preset',
        'schemaVersion': currentPresetSchemaVersion,
        'preset': presetJson,
      });

      expect(
        () => PresetCodec.decode(source),
        throwsA(isA<FormatException>()),
      );
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
