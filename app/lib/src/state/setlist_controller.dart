import 'package:flutter/foundation.dart';

import '../data/setlist_repository.dart';
import '../models/rig_setlist.dart';

class SetlistController extends ChangeNotifier {
  SetlistController(this._repository);

  final SetlistRepository _repository;

  List<RigSetlist> _setlists = <RigSetlist>[];
  String? _activeSetlistId;
  bool _isLoading = true;
  String? _errorMessage;

  List<RigSetlist> get setlists => List.unmodifiable(_setlists);
  String? get activeSetlistId => _activeSetlistId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  RigSetlist? get activeSetlist {
    for (final setlist in _setlists) {
      if (setlist.id == _activeSetlistId) return setlist;
    }
    return _setlists.isEmpty ? null : _setlists.first;
  }

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _setlists = await _repository.loadSetlists();
      _activeSetlistId = _setlists.isEmpty ? null : _setlists.first.id;
    } catch (error) {
      _setlists = <RigSetlist>[];
      _activeSetlistId = null;
      _errorMessage = 'Unable to load setlists: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectSetlist(String id) {
    if (!_setlists.any((setlist) => setlist.id == id)) return;
    _activeSetlistId = id;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> createSetlist(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 80) {
      throw const FormatException('Setlist name must contain 1–80 characters.');
    }
    if (_setlists.length >= maximumSetlists) {
      throw const FormatException('RigCanvas has reached its setlist limit.');
    }
    final now = DateTime.now().toUtc();
    final setlist = RigSetlist(
      id: _newId('setlist'),
      name: cleanName,
      description: '',
      createdAt: now,
      updatedAt: now,
      songs: const <RigSong>[],
    );
    await _commit([..._setlists, setlist], activeId: setlist.id);
  }

  Future<void> renameSetlist(String id, String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 80) {
      throw const FormatException('Setlist name must contain 1–80 characters.');
    }
    final next = _setlists
        .map(
          (setlist) => setlist.id == id
              ? setlist.copyWith(name: cleanName)
              : setlist,
        )
        .toList();
    await _commit(next, activeId: _activeSetlistId);
  }

  Future<void> deleteSetlist(String id) async {
    final next = _setlists.where((setlist) => setlist.id != id).toList();
    if (next.length == _setlists.length) return;
    final nextActive = _activeSetlistId == id
        ? (next.isEmpty ? null : next.first.id)
        : _activeSetlistId;
    await _commit(next, activeId: nextActive);
  }

  Future<void> addSong({
    required String title,
    required String keySignature,
    int? bpm,
    String notes = '',
    String? presetId,
    String? sceneId,
  }) async {
    final current = activeSetlist;
    if (current == null) {
      throw const FormatException('Create or select a setlist first.');
    }
    if (current.songs.length >= maximumSongsPerSetlist) {
      throw const FormatException('This setlist already contains 100 songs.');
    }
    final song = _validatedSong(
      id: _newId('song'),
      title: title,
      keySignature: keySignature,
      bpm: bpm,
      notes: notes,
      presetId: presetId,
      sceneId: sceneId,
    );
    await _replaceSongs([...current.songs, song]);
  }

  Future<void> updateSong(RigSong song) async {
    final current = activeSetlist;
    if (current == null) return;
    final replacement = _validatedSong(
      id: song.id,
      title: song.title,
      keySignature: song.keySignature,
      bpm: song.bpm,
      notes: song.notes,
      presetId: song.presetId,
      sceneId: song.sceneId,
    );
    final nextSongs = current.songs
        .map((item) => item.id == song.id ? replacement : item)
        .toList();
    await _replaceSongs(nextSongs);
  }

  Future<void> deleteSong(String songId) async {
    final current = activeSetlist;
    if (current == null) return;
    final nextSongs = current.songs
        .where((song) => song.id != songId)
        .toList();
    if (nextSongs.length == current.songs.length) return;
    await _replaceSongs(nextSongs);
  }

  Future<void> reorderSongs(int oldIndex, int newIndex) async {
    final current = activeSetlist;
    if (current == null ||
        oldIndex < 0 ||
        oldIndex >= current.songs.length ||
        newIndex < 0 ||
        newIndex >= current.songs.length) {
      return;
    }
    final nextSongs = List<RigSong>.from(current.songs);
    final song = nextSongs.removeAt(oldIndex);
    nextSongs.insert(newIndex, song);
    await _replaceSongs(nextSongs);
  }

  RigSong _validatedSong({
    required String id,
    required String title,
    required String keySignature,
    required int? bpm,
    required String notes,
    required String? presetId,
    required String? sceneId,
  }) {
    final cleanTitle = title.trim();
    final cleanKey = keySignature.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 120) {
      throw const FormatException('Song title must contain 1–120 characters.');
    }
    if (cleanKey.isEmpty || cleanKey.length > 8) {
      throw const FormatException('Song key must contain 1–8 characters.');
    }
    if (bpm != null && (bpm < 40 || bpm > 300)) {
      throw const FormatException('BPM must be between 40 and 300.');
    }
    if (notes.length > 1000) {
      throw const FormatException('Song notes cannot exceed 1,000 characters.');
    }
    if (sceneId != null && presetId == null) {
      throw const FormatException('A scene assignment requires a preset.');
    }
    final existing = _findSong(id);
    return RigSong(
      id: id,
      title: cleanTitle,
      keySignature: cleanKey,
      createdAt: existing?.createdAt ?? DateTime.now().toUtc(),
      bpm: bpm,
      notes: notes,
      presetId: presetId,
      sceneId: sceneId,
    );
  }

  RigSong? _findSong(String id) {
    for (final setlist in _setlists) {
      for (final song in setlist.songs) {
        if (song.id == id) return song;
      }
    }
    return null;
  }

  Future<void> _replaceSongs(List<RigSong> songs) async {
    final current = activeSetlist;
    if (current == null) return;
    final next = _setlists
        .map(
          (setlist) => setlist.id == current.id
              ? setlist.copyWith(songs: songs)
              : setlist,
        )
        .toList();
    await _commit(next, activeId: current.id);
  }

  Future<void> _commit(List<RigSetlist> next, {String? activeId}) async {
    await _repository.saveSetlists(next);
    _setlists = next;
    _activeSetlistId = activeId ??
        (_setlists.any((setlist) => setlist.id == _activeSetlistId)
            ? _activeSetlistId
            : (_setlists.isEmpty ? null : _setlists.first.id));
    _errorMessage = null;
    notifyListeners();
  }

  String _newId(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    var candidate = '$prefix-$timestamp';
    var suffix = 0;
    while (_setlists.any(
      (setlist) =>
          setlist.id == candidate ||
          setlist.songs.any((song) => song.id == candidate),
    )) {
      suffix++;
      candidate = '$prefix-$timestamp-$suffix';
    }
    return candidate;
  }
}
