import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/rig_setlist.dart';
import 'preset_repository.dart';

abstract interface class SetlistRepository {
  Future<List<RigSetlist>> loadSetlists();

  Future<void> saveSetlists(List<RigSetlist> setlists);
}

class JsonFileSetlistRepository implements SetlistRepository {
  JsonFileSetlistRepository({SupportDirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final SupportDirectoryProvider _directoryProvider;

  Future<File> _setlistFile() async {
    final supportDirectory = await _directoryProvider();
    final appDirectory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}rigcanvas',
    );
    await appDirectory.create(recursive: true);
    return File('${appDirectory.path}${Platform.pathSeparator}setlists.json');
  }

  @override
  Future<List<RigSetlist>> loadSetlists() async {
    final file = await _setlistFile();
    final backup = File('${file.path}.bak');
    final temporary = File('${file.path}.tmp');

    if (!await file.exists() && await backup.exists()) {
      await backup.rename(file.path);
    }
    if (await file.exists() && await backup.exists()) {
      await backup.delete();
    }
    if (await temporary.exists()) {
      await temporary.delete();
    }
    if (!await file.exists()) return <RigSetlist>[];

    return SetlistDocumentCodec.decode(await file.readAsString());
  }

  @override
  Future<void> saveSetlists(List<RigSetlist> setlists) async {
    if (setlists.length > maximumSetlists) {
      throw const FormatException('Too many setlists.');
    }
    final file = await _setlistFile();
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');

    await temporary.writeAsString(
      SetlistDocumentCodec.encode(setlists),
      flush: true,
    );
    if (await backup.exists()) await backup.delete();

    final hadOriginal = await file.exists();
    if (hadOriginal) await file.rename(backup.path);

    try {
      await temporary.rename(file.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (hadOriginal && await backup.exists() && !await file.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }
}
