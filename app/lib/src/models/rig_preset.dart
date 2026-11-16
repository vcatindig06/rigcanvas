import 'dart:convert';

import 'effect_block.dart';

const int currentPresetSchemaVersion = 1;
const int maximumPresetBlocks = 32;

class RigPreset {
  const RigPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.blocks,
    this.target = 'local-workspace',
  });

  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<EffectBlock> blocks;
  final String target;

  RigPreset copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? updatedAt,
    List<EffectBlock>? blocks,
    String? target,
  }) {
    return RigPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      blocks: blocks ?? this.blocks,
      target: target ?? this.target,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'target': target,
      'blocks': blocks.map(_blockToJson).toList(),
    };
  }

  static RigPreset fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Preset must be a JSON object.');
    }

    final id = _readString(value, 'id', maximumLength: 128);
    final name = _readString(value, 'name', maximumLength: 80);
    final description = _readString(
      value,
      'description',
      maximumLength: 500,
      allowEmpty: true,
    );
    final target = _readString(value, 'target', maximumLength: 64);
    final createdAt = _readDate(value, 'createdAt');
    final updatedAt = _readDate(value, 'updatedAt');
    final rawBlocks = value['blocks'];

    if (name.trim().isEmpty) {
      throw const FormatException('Preset name cannot be empty.');
    }
    if (rawBlocks is! List || rawBlocks.length > maximumPresetBlocks) {
      throw FormatException(
        'Preset blocks must be a list of up to $maximumPresetBlocks items.',
      );
    }

    final blocks = rawBlocks.map(_blockFromJson).toList();
    final blockIds = blocks.map((block) => block.id).toSet();
    if (blockIds.length != blocks.length) {
      throw const FormatException('Preset contains duplicate effect block IDs.');
    }

    return RigPreset(
      id: id,
      name: name.trim(),
      description: description,
      createdAt: createdAt,
      updatedAt: updatedAt,
      blocks: blocks,
      target: target,
    );
  }

  static Map<String, Object?> _blockToJson(EffectBlock block) {
    return {
      'id': block.id,
      'name': block.name,
      'family': block.family.name,
      'description': block.description,
      'enabled': block.enabled,
      'parameters': block.parameters,
    };
  }

  static EffectBlock _blockFromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Effect block must be a JSON object.');
    }

    final id = _readString(value, 'id', maximumLength: 128);
    final name = _readString(value, 'name', maximumLength: 80);
    final description = _readString(
      value,
      'description',
      maximumLength: 500,
      allowEmpty: true,
    );
    final familyName = _readString(value, 'family', maximumLength: 32);
    final enabled = value['enabled'];
    final rawParameters = value['parameters'];

    if (enabled is! bool) {
      throw const FormatException('Effect block enabled flag must be boolean.');
    }
    if (rawParameters is! Map<String, dynamic>) {
      throw const FormatException('Effect block parameters must be an object.');
    }

    final family = EffectFamily.values.firstWhere(
      (candidate) => candidate.name == familyName,
      orElse: () => throw FormatException(
        'Unsupported effect family "$familyName".',
      ),
    );

    final specs = effectParameterSpecs[family] ?? <EffectParameterSpec>[];
    final allowedKeys = specs.map((spec) => spec.key).toSet();
    final parameters = <String, double>{};

    for (final entry in rawParameters.entries) {
      if (!allowedKeys.contains(entry.key)) {
        throw FormatException(
          'Unsupported parameter "${entry.key}" for $familyName.',
        );
      }
      if (entry.value is! num) {
        throw FormatException('Parameter "${entry.key}" must be numeric.');
      }
      final number = (entry.value as num).toDouble();
      if (!number.isFinite) {
        throw FormatException('Parameter "${entry.key}" must be finite.');
      }
      final spec = specs.firstWhere((candidate) => candidate.key == entry.key);
      if (number < spec.minimum || number > spec.maximum) {
        throw FormatException(
          'Parameter "${entry.key}" is outside its allowed range.',
        );
      }
      parameters[entry.key] = number;
    }

    for (final spec in specs) {
      parameters.putIfAbsent(spec.key, () => spec.initial);
    }

    return EffectBlock(
      id: id,
      name: name,
      family: family,
      description: description,
      enabled: enabled,
      parameters: parameters,
    );
  }

  static String _readString(
    Map<String, dynamic> source,
    String key, {
    required int maximumLength,
    bool allowEmpty = false,
  }) {
    final value = source[key];
    if (value is! String ||
        value.length > maximumLength ||
        (!allowEmpty && value.trim().isEmpty)) {
      throw FormatException('Invalid or missing "$key" field.');
    }
    return value;
  }

  static DateTime _readDate(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is! String) {
      throw FormatException('Invalid or missing "$key" date.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('Invalid "$key" date.');
    }
    return parsed.toUtc();
  }

  factory RigPreset.starter({DateTime? now}) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return RigPreset(
      id: 'preset-starter',
      name: 'Sunday Clean + Ambient',
      description: 'Starter workspace · edit and customize this preset.',
      createdAt: timestamp,
      updatedAt: timestamp,
      blocks: EffectBlock.demoChain(),
    );
  }
}

class PresetCodec {
  const PresetCodec._();

  static String encode(RigPreset preset) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'rigcanvas-preset',
      'schemaVersion': currentPresetSchemaVersion,
      'preset': preset.toJson(),
    });
  }

  static RigPreset decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('RigCanvas preset file must be a JSON object.');
    }
    if (decoded['format'] != 'rigcanvas-preset') {
      throw const FormatException('This is not a RigCanvas preset file.');
    }
    if (decoded['schemaVersion'] != currentPresetSchemaVersion) {
      throw FormatException(
        'Unsupported preset schema version: ${decoded['schemaVersion']}.',
      );
    }
    return RigPreset.fromJson(decoded['preset']);
  }
}
