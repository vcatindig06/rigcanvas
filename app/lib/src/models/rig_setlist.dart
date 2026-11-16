import 'dart:convert';

const int currentSetlistSchemaVersion = 1;
const int maximumSetlists = 64;
const int maximumSongsPerSetlist = 100;

class RigSong {
  const RigSong({
    required this.id,
    required this.title,
    required this.keySignature,
    required this.createdAt,
    this.bpm,
    this.notes = '',
    this.presetId,
    this.sceneId,
  });

  final String id;
  final String title;
  final String keySignature;
  final DateTime createdAt;
  final int? bpm;
  final String notes;
  final String? presetId;
  final String? sceneId;

  RigSong copyWith({
    String? title,
    String? keySignature,
    int? bpm,
    bool clearBpm = false,
    String? notes,
    String? presetId,
    bool clearPresetId = false,
    String? sceneId,
    bool clearSceneId = false,
  }) {
    return RigSong(
      id: id,
      title: title ?? this.title,
      keySignature: keySignature ?? this.keySignature,
      createdAt: createdAt,
      bpm: clearBpm ? null : (bpm ?? this.bpm),
      notes: notes ?? this.notes,
      presetId: clearPresetId ? null : (presetId ?? this.presetId),
      sceneId: clearSceneId ? null : (sceneId ?? this.sceneId),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'keySignature': keySignature,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'bpm': bpm,
    'notes': notes,
    'presetId': presetId,
    'sceneId': sceneId,
  };

  factory RigSong.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Setlist song must be a JSON object.');
    }
    final id = _readString(value, 'id', maximumLength: 128);
    final title = _readString(value, 'title', maximumLength: 120);
    final keySignature = _readString(
      value,
      'keySignature',
      maximumLength: 8,
    );
    final createdAt = _readDate(value, 'createdAt');
    final notes = _readString(
      value,
      'notes',
      maximumLength: 1000,
      allowEmpty: true,
    );
    final rawBpm = value['bpm'];
    final presetId = _readOptionalString(value['presetId'], 'presetId');
    final sceneId = _readOptionalString(value['sceneId'], 'sceneId');

    int? bpm;
    if (rawBpm != null) {
      if (rawBpm is! int || rawBpm < 40 || rawBpm > 300) {
        throw const FormatException('Song BPM must be between 40 and 300.');
      }
      bpm = rawBpm;
    }

    if (title.trim().isEmpty || keySignature.trim().isEmpty) {
      throw const FormatException('Song title and key cannot be empty.');
    }
    if (sceneId != null && presetId == null) {
      throw const FormatException('A scene assignment requires a preset assignment.');
    }

    return RigSong(
      id: id,
      title: title.trim(),
      keySignature: keySignature.trim(),
      createdAt: createdAt,
      bpm: bpm,
      notes: notes,
      presetId: presetId,
      sceneId: sceneId,
    );
  }
}

class RigSetlist {
  const RigSetlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.songs,
    this.description = '',
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RigSong> songs;
  final String description;

  RigSetlist copyWith({
    String? name,
    String? description,
    DateTime? updatedAt,
    List<RigSong>? songs,
  }) {
    return RigSetlist(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      songs: songs ?? this.songs,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'songs': songs.map((song) => song.toJson()).toList(),
  };

  factory RigSetlist.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Setlist must be a JSON object.');
    }
    final id = _readString(value, 'id', maximumLength: 128);
    final name = _readString(value, 'name', maximumLength: 80);
    final description = _readString(
      value,
      'description',
      maximumLength: 500,
      allowEmpty: true,
    );
    final createdAt = _readDate(value, 'createdAt');
    final updatedAt = _readDate(value, 'updatedAt');
    final rawSongs = value['songs'];

    if (name.trim().isEmpty) {
      throw const FormatException('Setlist name cannot be empty.');
    }
    if (rawSongs is! List || rawSongs.length > maximumSongsPerSetlist) {
      throw const FormatException(
        'Setlist must contain no more than 100 songs.',
      );
    }
    final songs = rawSongs.map(RigSong.fromJson).toList();
    final songIds = songs.map((song) => song.id).toSet();
    if (songIds.length != songs.length) {
      throw const FormatException('Setlist contains duplicate song IDs.');
    }

    return RigSetlist(
      id: id,
      name: name.trim(),
      description: description,
      createdAt: createdAt,
      updatedAt: updatedAt,
      songs: songs,
    );
  }
}

String _readString(
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

String? _readOptionalString(Object? value, String field) {
  if (value == null) return null;
  if (value is! String || value.isEmpty || value.length > 128) {
    throw FormatException('Invalid "$field" field.');
  }
  return value;
}

DateTime _readDate(Map<String, dynamic> source, String key) {
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

class SetlistDocumentCodec {
  const SetlistDocumentCodec._();

  static String encode(List<RigSetlist> setlists) {
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': currentSetlistSchemaVersion,
      'setlists': setlists.map((setlist) => setlist.toJson()).toList(),
    });
  }

  static List<RigSetlist> decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Setlist database must be a JSON object.');
    }
    if (value['schemaVersion'] != currentSetlistSchemaVersion) {
      throw FormatException(
        'Unsupported setlist database schema: ${value['schemaVersion']}.',
      );
    }
    final rawSetlists = value['setlists'];
    if (rawSetlists is! List || rawSetlists.length > maximumSetlists) {
      throw const FormatException('Setlist database has an invalid setlist list.');
    }
    final setlists = rawSetlists.map(RigSetlist.fromJson).toList();
    final ids = setlists.map((setlist) => setlist.id).toSet();
    if (ids.length != setlists.length) {
      throw const FormatException('Setlist database contains duplicate IDs.');
    }
    return setlists;
  }
}
