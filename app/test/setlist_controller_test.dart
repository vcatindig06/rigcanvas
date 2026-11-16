import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/data/setlist_repository.dart';
import 'package:rigcanvas/src/models/rig_setlist.dart';
import 'package:rigcanvas/src/state/setlist_controller.dart';

class MemorySetlistRepository implements SetlistRepository {
  List<RigSetlist> stored = <RigSetlist>[];

  @override
  Future<List<RigSetlist>> loadSetlists() async => List.of(stored);

  @override
  Future<void> saveSetlists(List<RigSetlist> setlists) async {
    stored = List.of(setlists);
  }
}

void main() {
  group('SetlistController', () {
    late MemorySetlistRepository repository;
    late SetlistController controller;

    setUp(() async {
      repository = MemorySetlistRepository();
      controller = SetlistController(repository);
      await controller.initialize();
    });

    tearDown(() => controller.dispose());

    test('creates a local setlist and persists song information', () async {
      await controller.createSetlist('Sunday Gathering');
      await controller.addSong(
        title: 'Oceans',
        keySignature: 'D',
        bpm: 72,
        notes: 'Begin softly, build into the final chorus.',
      );

      expect(controller.activeSetlist?.name, 'Sunday Gathering');
      expect(controller.activeSetlist?.songs, hasLength(1));
      expect(controller.activeSetlist?.songs.single.title, 'Oceans');
      expect(controller.activeSetlist?.songs.single.bpm, 72);
      expect(repository.stored.single.songs.single.notes, contains('Begin softly'));
    });

    test('reorders and removes songs', () async {
      await controller.createSetlist('Rehearsal');
      await controller.addSong(title: 'Opening', keySignature: 'E');
      await controller.addSong(title: 'Closing', keySignature: 'G');

      await controller.reorderSongs(1, 0);
      expect(
        controller.activeSetlist!.songs.map((song) => song.title).toList(),
        ['Closing', 'Opening'],
      );

      final songId = controller.activeSetlist!.songs.first.id;
      await controller.deleteSong(songId);
      expect(controller.activeSetlist!.songs, hasLength(1));
      expect(controller.activeSetlist!.songs.single.title, 'Opening');
    });

    test('rejects invalid tempo and scene without preset', () async {
      await controller.createSetlist('Test');

      await expectLater(
        controller.addSong(
          title: 'Invalid',
          keySignature: 'C',
          bpm: 400,
        ),
        throwsFormatException,
      );
      await expectLater(
        controller.addSong(
          title: 'Invalid scene',
          keySignature: 'C',
          sceneId: 'scene-without-preset',
        ),
        throwsFormatException,
      );
      expect(controller.activeSetlist!.songs, isEmpty);
    });

    test('renames and deletes a setlist', () async {
      await controller.createSetlist('Old Name');
      final id = controller.activeSetlist!.id;
      await controller.renameSetlist(id, 'New Name');
      expect(controller.activeSetlist!.name, 'New Name');

      await controller.deleteSetlist(id);
      expect(controller.activeSetlist, isNull);
    });
  });
}
