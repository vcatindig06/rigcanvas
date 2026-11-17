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

    test('uses the owner-reported firmware-v8 AMP and CAB names', () {
      final guitarAmps = EffectModelCatalog.all
          .where((model) => model.id.startsWith('kpt.amp.guitar.'))
          .toList();
      final guitarCabs = EffectModelCatalog.all
          .where((model) => model.id.startsWith('kpt.cab.guitar.'))
          .toList();
      final firstBassAmp = EffectModelCatalog.byId('kpt.amp.bass.0')!;
      final lastBassAmp = EffectModelCatalog.byId('kpt.amp.bass.9')!;
      final firstBassCab = EffectModelCatalog.byId('kpt.cab.bass.0')!;

      expect(guitarAmps, hasLength(50));
      expect(guitarCabs, hasLength(50));
      expect(guitarAmps.first.name, 'CL-UWETWINS');
      expect(guitarAmps.last.name, 'CL-MATDC30');
      expect(guitarCabs.first.name, 'EAGLPROV30S');
      expect(guitarCabs.last.name, 'VXAC30');
      expect(firstBassAmp.name, 'Bass Preamp 51');
      expect(lastBassAmp.name, 'Bass Preamp 60');
      expect(firstBassCab.name, 'Bass CAB 51');
      expect(firstBassAmp.description, contains('not been confirmed'));
      expect(firstBassCab.description, contains('not been confirmed'));
    });

    test('classifies the owner's AMP prefixes as Clean, Overdrive, and Distortion', () {
      final clean = EffectModelCatalog.byId('kpt.amp.guitar.0')!;
      final overdrive = EffectModelCatalog.byId('kpt.amp.guitar.2')!;
      final distortion = EffectModelCatalog.byId('kpt.amp.guitar.4')!;

      expect(clean.name, 'CL-UWETWINS');
      expect(clean.ampType, AmpModelType.clean);
      expect(clean.ampType!.labelWithCode, 'Clean (CL)');
      expect(overdrive.name, 'OD-MARVM410');
      expect(overdrive.ampType, AmpModelType.overdrive);
      expect(overdrive.ampType!.labelWithCode, 'Overdrive (OD)');
      expect(distortion.name, 'DS-BRITPLEX');
      expect(distortion.ampType, AmpModelType.distortion);
      expect(distortion.ampType!.labelWithCode, 'Distortion (DS)');
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
