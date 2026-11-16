import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/rig_preset.dart';

abstract interface class PresetRepository {
  Future<List<RigPreset>> loadPresets();

  Future<void> savePresets(List<RigPreset> presets);
}

typedef SupportDirectoryProvider = Future<Directory> Function();

class JsonFilePresetRepository implements PresetRepository {
  JsonFilePresetRepository({SupportDirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final SupportDirectoryProvider _directoryProvider;

  Future<File> _presetFile() async {
    final supportDirectory = await _directoryProvider();
    final appDirectory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}rigcanvas',
    );
    await appDirectory.create(recursive: true);
    return File(
      '${appDirectory.path}${Platform.pathSeparator}presets.json',
    );
  }

  @override
  Future<List<RigPreset>> loadPresets() async {
    final file = await _presetFile();
    if (!await file.exists()) {
      return <RigPreset>[];
    }

    final source = await file.readAsString();
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Local preset database is not a JSON object.');
    }
    if (decoded['schemaVersion'] != currentPresetSchemaVersion) {
      throw FormatException(
        'Local preset database schema ${decoded['schemaVersion']} is unsupported.',
      );
    }
    final rawPresets = decoded['presets'];
    if (rawPresets is! List) {
      throw const FormatException('Local preset database has no preset list.');
    }

    final presets = rawPresets.map(RigPreset.fromJson).toList();
    final ids = presets.map((preset) => preset.id).toSet();
    if (ids.length != presets.length) {
      throw const FormatException('Local preset database contains duplicate IDs.');
    }
    return presets;
  }

  @override
  Future<void> savePresets(List<RigPreset> presets) async {
    final file = await _presetFile();
    final document = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': currentPresetSchemaVersion,
      'presets': presets.map((preset) => preset.toJson()).toList(),
    });

    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');

    await temporary.writeAsString(document, flush: true);

    if (await backup.exists()) {
      await backup.delete();
    }

    final hadOriginal = await file.exists();
    if (hadOriginal) {
      await file.rename(backup.path);
    }

    try {
      await temporary.rename(file.path);
      if (await backup.exists()) {
        await backup.delete();
      }
    } catch (_) {
      if (hadOriginal && await backup.exists() && !await file.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }
}
