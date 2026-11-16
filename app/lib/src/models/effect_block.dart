import 'package:material_ui/material_ui.dart';

enum EffectFamily {
  gate,
  drive,
  amplifier,
  cabinet,
  modulation,
  delay,
  reverb,
}

extension EffectFamilyPresentation on EffectFamily {
  String get label {
    switch (this) {
      case EffectFamily.gate:
        return 'Dynamics';
      case EffectFamily.drive:
        return 'Drive';
      case EffectFamily.amplifier:
        return 'Amplifier';
      case EffectFamily.cabinet:
        return 'Cabinet';
      case EffectFamily.modulation:
        return 'Modulation';
      case EffectFamily.delay:
        return 'Delay';
      case EffectFamily.reverb:
        return 'Reverb';
    }
  }

  IconData get icon {
    switch (this) {
      case EffectFamily.gate:
        return Icons.graphic_eq;
      case EffectFamily.drive:
        return Icons.bolt;
      case EffectFamily.amplifier:
        return Icons.speaker;
      case EffectFamily.cabinet:
        return Icons.album;
      case EffectFamily.modulation:
        return Icons.waves;
      case EffectFamily.delay:
        return Icons.av_timer;
      case EffectFamily.reverb:
        return Icons.blur_on;
    }
  }
}

@immutable
class EffectParameterSpec {
  const EffectParameterSpec({
    required this.key,
    required this.label,
    required this.minimum,
    required this.maximum,
    required this.initial,
    this.unit = '',
    this.divisions = 100,
  });

  final String key;
  final String label;
  final double minimum;
  final double maximum;
  final double initial;
  final String unit;
  final int divisions;
}

const Map<EffectFamily, List<EffectParameterSpec>> effectParameterSpecs = {
  EffectFamily.gate: [
    EffectParameterSpec(
      key: 'threshold',
      label: 'Threshold',
      minimum: -80,
      maximum: 0,
      initial: -48,
      unit: 'dB',
    ),
    EffectParameterSpec(
      key: 'release',
      label: 'Release',
      minimum: 5,
      maximum: 500,
      initial: 120,
      unit: 'ms',
    ),
  ],
  EffectFamily.drive: [
    EffectParameterSpec(
      key: 'gain',
      label: 'Gain',
      minimum: 0,
      maximum: 100,
      initial: 35,
      unit: '%',
    ),
    EffectParameterSpec(
      key: 'tone',
      label: 'Tone',
      minimum: 0,
      maximum: 100,
      initial: 55,
      unit: '%',
    ),
    EffectParameterSpec(
      key: 'level',
      label: 'Level',
      minimum: 0,
      maximum: 100,
      initial: 65,
      unit: '%',
    ),
    EffectParameterSpec(
      key: 'blend',
      label: 'Blend',
      minimum: 0,
      maximum: 100,
      initial: 100,
      unit: '%',
    ),
  ],
  EffectFamily.amplifier: [
    EffectParameterSpec(
      key: 'gain',
      label: 'Gain',
      minimum: 0,
      maximum: 100,
      initial: 48,
      unit: '%',
    ),
    EffectParameterSpec(
      key: 'bass',
      label: 'Bass',
      minimum: 0,
      maximum: 100,
      initial: 50,
      unit: '%',
    ),
    EffectParameterSpec(
      key: 'mid',
      label: 'Middle',
      minimum: 0,
      maximum: 100,
      initial: 58,
      unit: '%',
    ),
    EffectParameterSpec(
      key: 'treble',
      label: 'Treble',
      minimum: 0,
      maximum: 100,
      initial: 52,
      unit: '%',
    ),
    EffectParameterSpec(
      key: 'presence',
      label: 'Presence',
      minimum: 0,
      maximum: 100,
      initial: 45,
      unit: '%',
    ),
    EffectParameterSpec(
      key: 'master',
      label: 'Master',
      minimum: 0,
      maximum: 100,
      initial: 70,
      unit: '%',
    ),
  ],
  EffectFamily.cabinet: [
    EffectParameterSpec(
      key: 'lowCut',
      label: 'Low Cut',
      minimum: 20,
      maximum: 500,
      initial: 80,
      unit: 'Hz',
    ),
    EffectParameterSpec(
      key: 'highCut',
      label: 'High Cut',
      minimum: 2000,
      maximum: 20000,
      initial: 11000,
      unit: 'Hz',
    ),
    EffectParameterSpec(
      key: 'level',
      label: 'Level',
      minimum: -24,
      maximum: 12,
      initial: 0,
      unit: 'dB',
    ),
  ],
  EffectFamily.modulation: [
    EffectParameterSpec(
      key: 'rate',
      label: 'Rate',
      minimum: 0.1,
      maximum: 10,
      initial: 1.2,
      unit: 'Hz',
    ),
    EffectParameterSpec(
      key: 'depth',
      label: 'Depth',
      minimum: 0,
      maximum: 100,
      initial: 45,
      unit: '%',
    ),
    EffectParameterSpec(
      key: 'mix',
      label: 'Mix',
      minimum: 0,
      maximum: 100,
      initial: 25,
      unit: '%',
    ),
  ],
  EffectFamily.delay: [
    EffectParameterSpec(
      key: 'time',
      label: 'Time',
      minimum: 1,
      maximum: 2000,
      initial: 480,
      unit: 'ms',
    ),
    EffectParameterSpec(
      key: 'feedback',
      label: 'Feedback',
      minimum: 0,
      maximum: 100,
      initial: 32,
      unit: '%',
    ),
    EffectParameterSpec(
      key: 'mix',
      label: 'Mix',
      minimum: 0,
      maximum: 100,
      initial: 24,
      unit: '%',
    ),
  ],
  EffectFamily.reverb: [
    EffectParameterSpec(
      key: 'decay',
      label: 'Decay',
      minimum: 0.1,
      maximum: 20,
      initial: 5.5,
      unit: 's',
    ),
    EffectParameterSpec(
      key: 'tone',
      label: 'Tone',
      minimum: 0,
      maximum: 100,
      initial: 55,
      unit: '%',
    ),
    EffectParameterSpec(
      key: 'mix',
      label: 'Mix',
      minimum: 0,
      maximum: 100,
      initial: 30,
      unit: '%',
    ),
  ],
};

@immutable
class EffectBlock {
  const EffectBlock({
    required this.id,
    required this.name,
    required this.family,
    required this.description,
    this.enabled = true,
    this.parameters = const <String, double>{},
    this.assetId,
  });

  final String id;
  final String name;
  final EffectFamily family;
  final String description;
  final bool enabled;
  final Map<String, double> parameters;

  /// Local Asset Library reference. This does not load or transmit the asset.
  final String? assetId;

  EffectBlock copyWith({
    String? name,
    String? description,
    bool? enabled,
    Map<String, double>? parameters,
    String? assetId,
    bool clearAssetId = false,
  }) {
    return EffectBlock(
      id: id,
      name: name ?? this.name,
      family: family,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      parameters: parameters ?? this.parameters,
      assetId: clearAssetId ? null : (assetId ?? this.assetId),
    );
  }

  static Map<String, double> defaultParameters(EffectFamily family) {
    return {
      for (final spec in effectParameterSpecs[family] ?? <EffectParameterSpec>[])
        spec.key: spec.initial,
    };
  }

  static EffectBlock create({
    required String id,
    required EffectFamily family,
  }) {
    return EffectBlock(
      id: id,
      name: 'New ${family.label} Block',
      family: family,
      description: 'Local workspace block · not sent to hardware',
      parameters: defaultParameters(family),
    );
  }

  static List<EffectBlock> demoChain() {
    return [
      EffectBlock(
        id: 'demo-gate',
        name: 'Input Gate',
        family: EffectFamily.gate,
        description: 'Noise control · demo block',
        parameters: defaultParameters(EffectFamily.gate),
      ),
      EffectBlock(
        id: 'demo-drive',
        name: 'Transparent Overdrive',
        family: EffectFamily.drive,
        description: 'Klon-inspired concept · software mock',
        parameters: defaultParameters(EffectFamily.drive),
      ),
      EffectBlock(
        id: 'demo-amp',
        name: 'British Stack',
        family: EffectFamily.amplifier,
        description: 'Amp model concept · software mock',
        parameters: defaultParameters(EffectFamily.amplifier),
      ),
      EffectBlock(
        id: 'demo-cab',
        name: '4×12 Cabinet',
        family: EffectFamily.cabinet,
        description: 'Cabinet / IR slot · software mock',
        parameters: defaultParameters(EffectFamily.cabinet),
      ),
      EffectBlock(
        id: 'demo-delay',
        name: 'Stereo Delay',
        family: EffectFamily.delay,
        description: 'Tempo-synced repeats · software mock',
        parameters: defaultParameters(EffectFamily.delay),
      ),
      EffectBlock(
        id: 'demo-reverb',
        name: 'Hall Reverb',
        family: EffectFamily.reverb,
        description: 'Ambient tail · software mock',
        parameters: defaultParameters(EffectFamily.reverb),
      ),
    ];
  }
}
