import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rigcanvas/src/models/rig_grid.dart';
import 'package:rigcanvas/src/models/rig_preset.dart';

void main() {
  group('RigGrid', () {
    test('places legacy blocks in the first four by eight slots', () {
      final grid = RigGrid.fromBlockIds(
        List.generate(10, (index) => 'block-$index'),
      );

      expect(grid.blockCount, 10);
      expect(grid.positionOf('block-0')?.row, 0);
      expect(grid.positionOf('block-7')?.column, 7);
      expect(grid.positionOf('block-8')?.row, 1);
      expect(grid.positionOf('block-9')?.column, 1);
    });

    test('moves into an occupied slot by swapping both blocks', () {
      final grid = RigGrid.fromBlockIds(['a', 'b', 'c']);
      final moved = grid.moveBlockToSlot('a', 0, 1);

      expect(moved.positionOf('a')?.column, 1);
      expect(moved.positionOf('b')?.column, 0);
      expect(moved.positionOf('c')?.column, 2);
    });

    test('moves into an empty slot without changing other positions', () {
      final grid = RigGrid.fromBlockIds(['a', 'b']);
      final moved = grid.moveBlockToSlot('a', 3, 7);

      expect(moved.positionOf('a')?.row, 3);
      expect(moved.positionOf('a')?.column, 7);
      expect(moved.positionOf('b')?.row, 0);
      expect(moved.positionOf('b')?.column, 1);
    });

    test('derives independent input-to-output connections per lane', () {
      final grid = RigGrid.fromBlockIds(
        List.generate(9, (index) => 'block-$index'),
      );
      final firstLane = grid.connections.where(
        (connection) =>
            connection.from.startsWith('input:0') ||
            connection.to.startsWith('output:0') ||
            (connection.from.startsWith('block-') &&
                connection.to.startsWith('block-') &&
                int.parse(connection.from.substring(6)) < 8),
      );

      expect(grid.connections, contains(const GridConnection(from: 'input:0', to: 'block-0')));
      expect(grid.connections, contains(const GridConnection(from: 'block-7', to: 'output:0')));
      expect(grid.connections, contains(const GridConnection(from: 'input:1', to: 'block-8')));
      expect(grid.connections, contains(const GridConnection(from: 'block-8', to: 'output:1')));
      expect(firstLane.length, 9);
    });

    test('round-trips placements and derived connections', () {
      final original = RigGrid.fromBlockIds(['a', 'b', 'c'])
          .moveBlockToSlot('b', 2, 4);
      final restored = RigGrid.fromJson(
        original.toJson(),
        blockIds: ['a', 'b', 'c'],
      );

      expect(
        restored.placements.map((item) => item.toJson()).toList(),
        original.placements.map((item) => item.toJson()).toList(),
      );
      expect(restored.connections.toSet(), original.connections.toSet());
    });

    test('rejects duplicate and out-of-range slots', () {
      expect(
        () => RigGrid.fromJson(
          {
            'rows': 4,
            'columns': 8,
            'placements': [
              {'blockId': 'a', 'row': 0, 'column': 0},
              {'blockId': 'b', 'row': 0, 'column': 0},
            ],
          },
          blockIds: ['a', 'b'],
        ),
        throwsFormatException,
      );
      expect(
        () => RigGrid.fromJson(
          {
            'rows': 4,
            'columns': 8,
            'placements': [
              {'blockId': 'a', 'row': 4, 'column': 0},
            ],
          },
          blockIds: ['a'],
        ),
        throwsFormatException,
      );
    });

    test('rejects more than 32 blocks', () {
      expect(
        () => RigGrid.fromBlockIds(
          List.generate(33, (index) => 'block-$index'),
        ),
        throwsFormatException,
      );
    });
  });

  group('preset grid compatibility', () {
    test('loads schema version 1 presets as a row-major Grid', () {
      final preset = RigPreset.starter(
        now: DateTime.utc(2026, 11, 16),
      ).toJson()
        ..remove('grid');
      final source = jsonEncode({
        'format': 'rigcanvas-preset',
        'schemaVersion': 1,
        'preset': preset,
      });

      final restored = PresetCodec.decode(source);

      expect(restored.grid.blockCount, restored.blocks.length);
      for (var index = 0; index < restored.blocks.length; index++) {
        final placement = restored.grid.positionOf(restored.blocks[index].id);
        expect(placement?.row, index ~/ rigGridColumnCount);
        expect(placement?.column, index % rigGridColumnCount);
      }
    });

    test('scene snapshots retain their own grid layout', () {
      final original = RigPreset.starter(
        now: DateTime.utc(2026, 11, 16),
      );
      final movedGrid = original.grid.moveBlockToSlot(
        original.blocks.first.id,
        3,
        7,
      );
      final withScene = original.copyWith(
        scenes: [
          RigScene(
            id: 'scene-grid-test',
            name: 'Bridge',
            createdAt: DateTime.utc(2026, 11, 16),
            blocks: original.blocks,
            grid: movedGrid,
          ),
        ],
      );
      final restored = PresetCodec.decode(PresetCodec.encode(withScene));

      expect(
        restored.scenes.single.grid.positionOf(original.blocks.first.id)?.row,
        3,
      );
      expect(
        restored.scenes.single.grid.positionOf(original.blocks.first.id)?.column,
        7,
      );
    });
  });
}
