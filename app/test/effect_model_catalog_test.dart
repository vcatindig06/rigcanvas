import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/models/effect_block.dart';

void main() {
  group('EffectModelCatalog', () {
    test('contains the complete documented KPT Pro factory catalog count', () {
      expect(EffectModelCatalog.kptProFactoryCount, 152);
    });

    test('contains all documented KPT Pro factory model groups', () {
      final factoryModels = EffectModelCatalog.all
          .where((model) => model.source == EffectModelSource.kptProFactory)
          .toList();

      expect(
        factoryModels.where((model) => model.family == EffectFamily.amplifier),
        hasLength(60),
      );
      expect(
        factoryModels.where((model) => model.family == EffectFamily.cabinet),
        hasLength(60),
      );
      expect(
        factoryModels.where((model) => model.family == EffectFamily.modulation),
        hasLength(9),
      );
      expect(
        factoryModels.where((model) => model.family == EffectFamily.delay),
        hasLength(5),
      );
      expect(
        factoryModels.where((model) => model.family == EffectFamily.reverb),
        hasLength(6),
      );
      expect(
        factoryModels.where((model) => model.family == EffectFamily.expression),
        hasLength(5),
      );
      expect(
        factoryModels.where((model) => model.family == EffectFamily.eq),
        hasLength(1),
      );
      expect(
        factoryModels.where((model) => model.family == EffectFamily.gate),
        hasLength(3),
      );
      expect(
        factoryModels.where((model) => model.family == EffectFamily.drive),
        hasLength(3),
      );
    });

    test('numbers guitar and bass preamp and cabinet slots without inventing names', () {
      final guitarAmp = EffectModelCatalog.byId('kpt.amp.guitar.0')!;
      final lastGuitarAmp = EffectModelCatalog.byId('kpt.amp.guitar.49')!;
      final firstBassAmp = EffectModelCatalog.byId('kpt.amp.bass.0')!;
      final lastBassAmp = EffectModelCatalog.byId('kpt.amp.bass.9')!;
      final guitarCab = EffectModelCatalog.byId('kpt.cab.guitar.0')!;
      final firstBassCab = EffectModelCatalog.byId('kpt.cab.bass.0')!;

      expect(guitarAmp.name, 'Guitar Preamp 01');
      expect(lastGuitarAmp.name, 'Guitar Preamp 50');
      expect(firstBassAmp.name, 'Bass Preamp 51');
      expect(lastBassAmp.name, 'Bass Preamp 60');
      expect(guitarCab.name, 'Guitar CAB 01');
      expect(firstBassCab.name, 'Bass CAB 51');
      expect(guitarAmp.description, contains('does not publish an individual model name'));
    });

    test('gives every catalog model a unique stable identifier', () {
      final ids = EffectModelCatalog.all.map((model) => model.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('expanded models are kept separate from KPT Pro factory models', () {
      final transparent = EffectModelCatalog.byId('drive.transparent')!;
      final kptBoost = EffectModelCatalog.byId('kpt.fx.a_boost')!;

      expect(transparent.source, EffectModelSource.rigcanvasExpanded);
      expect(kptBoost.source, EffectModelSource.kptProFactory);
    });
  });

  group('EffectBlock model selection', () {
    test('new blocks use a selected catalog model', () {
      final block = EffectBlock.create(
        id: 'block-test',
        family: EffectFamily.reverb,
        modelId: 'kpt.reverb.cloud',
      );

      expect(block.modelId, 'kpt.reverb.cloud');
      expect(block.name, 'Cloud');
      expect(block.model.source, EffectModelSource.kptProFactory);
    });

    test('custom free-form names cannot replace a selected model', () {
      final block = EffectBlock.create(
        id: 'block-test',
        family: EffectFamily.drive,
        modelId: 'drive.transparent',
      );
      final updated = block.copyWith(name: 'My Custom Secret Model');

      expect(updated.modelId, 'drive.transparent');
      expect(updated.name, 'Transparent Overdrive');
    });

    test('rejects a model ID from a different family', () {
      expect(
        () => EffectBlock.create(
          id: 'block-test',
          family: EffectFamily.drive,
          modelId: 'kpt.reverb.cloud',
        ),
        throwsFormatException,
      );
    });
  });
}
