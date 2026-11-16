import 'package:flutter/material.dart';

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
class EffectBlock {
  const EffectBlock({
    required this.id,
    required this.name,
    required this.family,
    required this.description,
    this.enabled = true,
  });

  final String id;
  final String name;
  final EffectFamily family;
  final String description;
  final bool enabled;

  EffectBlock copyWith({bool? enabled}) {
    return EffectBlock(
      id: id,
      name: name,
      family: family,
      description: description,
      enabled: enabled ?? this.enabled,
    );
  }

  static List<EffectBlock> demoChain() {
    return const [
      EffectBlock(
        id: 'demo-gate',
        name: 'Input Gate',
        family: EffectFamily.gate,
        description: 'Noise control · demo block',
      ),
      EffectBlock(
        id: 'demo-drive',
        name: 'Transparent Overdrive',
        family: EffectFamily.drive,
        description: 'Klon-inspired concept · software mock',
      ),
      EffectBlock(
        id: 'demo-amp',
        name: 'British Stack',
        family: EffectFamily.amplifier,
        description: 'Amp model concept · software mock',
      ),
      EffectBlock(
        id: 'demo-cab',
        name: '4×12 Cabinet',
        family: EffectFamily.cabinet,
        description: 'Cabinet / IR slot · software mock',
      ),
      EffectBlock(
        id: 'demo-delay',
        name: 'Stereo Delay',
        family: EffectFamily.delay,
        description: 'Tempo-synced repeats · software mock',
      ),
      EffectBlock(
        id: 'demo-reverb',
        name: 'Hall Reverb',
        family: EffectFamily.reverb,
        description: 'Ambient tail · software mock',
      ),
    ];
  }
}
