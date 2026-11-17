import 'package:flutter/foundation.dart';

const int rigGridRowCount = 4;
const int rigGridColumnCount = 8;
const int maximumRigGridBlocks = rigGridRowCount * rigGridColumnCount;

@immutable
class GridPlacement {
  const GridPlacement({
    required this.blockId,
    required this.row,
    required this.column,
  });

  final String blockId;
  final int row;
  final int column;

  Map<String, Object?> toJson() => {
    'blockId': blockId,
    'row': row,
    'column': column,
  };

  static GridPlacement fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Grid placement must be an object.');
    }
    final blockId = value['blockId'];
    final row = value['row'];
    final column = value['column'];
    if (blockId is! String ||
        blockId.trim().isEmpty ||
        blockId.length > 128 ||
        row is! int ||
        column is! int ||
        row < 0 ||
        row >= rigGridRowCount ||
        column < 0 ||
        column >= rigGridColumnCount) {
      throw const FormatException('Grid placement has an invalid block or slot.');
    }
    return GridPlacement(blockId: blockId, row: row, column: column);
  }
}

@immutable
class GridConnection {
  const GridConnection({required this.from, required this.to});

  final String from;
  final String to;

  Map<String, Object?> toJson() => {'from': from, 'to': to};

  static GridConnection fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Grid connection must be an object.');
    }
    final from = value['from'];
    final to = value['to'];
    if (from is! String ||
        to is! String ||
        from.trim().isEmpty ||
        to.trim().isEmpty ||
        from.length > 128 ||
        to.length > 128 ||
        from == to) {
      throw const FormatException('Grid connection endpoints are invalid.');
    }
    return GridConnection(from: from, to: to);
  }

  @override
  bool operator ==(Object other) =>
      other is GridConnection && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// The saved four-row/eight-slot editor layout.
///
/// Each row is an independent local lane in v1. Connections are explicit and
/// deterministic: input -> occupied slots from left to right -> output.
/// Splitter/merge nodes and cross-lane routing are intentionally not implied.
@immutable
class RigGrid {
  const RigGrid({this.placements = const <GridPlacement>[]});

  final List<GridPlacement> placements;

  List<GridConnection> get connections {
    final result = <GridConnection>[];
    for (var row = 0; row < rigGridRowCount; row++) {
      final rowItems = placements.where((item) => item.row == row).toList()
        ..sort((a, b) => a.column.compareTo(b.column));
      if (rowItems.isEmpty) continue;

      var previous = 'input:$row';
      for (final item in rowItems) {
        result.add(GridConnection(from: previous, to: item.blockId));
        previous = item.blockId;
      }
      result.add(GridConnection(from: previous, to: 'output:$row'));
    }
    return List.unmodifiable(result);
  }

  int get blockCount => placements.length;

  factory RigGrid.fromBlockIds(Iterable<String> blockIds) {
    final ids = blockIds.toList(growable: false);
    if (ids.length > maximumRigGridBlocks) {
      throw const FormatException('The Grid supports up to 32 effect blocks.');
    }
    if (ids.toSet().length != ids.length) {
      throw const FormatException('Grid block IDs must be unique.');
    }
    return RigGrid(
      placements: List.unmodifiable([
        for (var index = 0; index < ids.length; index++)
          GridPlacement(
            blockId: ids[index],
            row: index ~/ rigGridColumnCount,
            column: index % rigGridColumnCount,
          ),
      ]),
    );
  }

  factory RigGrid.fromJson(
    Object? value, {
    required Iterable<String> blockIds,
  }) {
    final ids = blockIds.toList(growable: false);
    if (value == null) return RigGrid.fromBlockIds(ids);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Preset grid must be an object.');
    }

    final rows = value['rows'];
    final columns = value['columns'];
    final rawPlacements = value['placements'];
    if (rows != rigGridRowCount ||
        columns != rigGridColumnCount ||
        rawPlacements is! List ||
        rawPlacements.length > maximumRigGridBlocks) {
      throw const FormatException('Preset grid dimensions or placements are invalid.');
    }

    final placements = rawPlacements.map(GridPlacement.fromJson).toList();
    final knownIds = ids.toSet();
    final placementIds = placements.map((item) => item.blockId).toSet();
    final occupiedSlots = placements
        .map((item) => '${item.row}:${item.column}')
        .toSet();

    if (placementIds.length != placements.length ||
        placements.any((item) => !knownIds.contains(item.blockId)) ||
        occupiedSlots.length != placements.length) {
      throw const FormatException('Preset grid contains duplicate or unknown slots.');
    }

    // Recover blocks missing from a partially saved layout by placing them
    // into the first available slots. Existing valid positions are untouched.
    // When any placement is recovered, saved connections are stale by
    // definition; the connections getter below rebuilds the lane graph.
    final missingBlockIds = ids
        .where((blockId) => !placementIds.contains(blockId))
        .toList(growable: false);
    for (final blockId in missingBlockIds) {
      final occupied = occupiedSlots;
      var placed = false;
      for (var row = 0; row < rigGridRowCount && !placed; row++) {
        for (var column = 0; column < rigGridColumnCount; column++) {
          final key = '${row}:${column}';
          if (occupied.contains(key)) continue;
          placements.add(
            GridPlacement(blockId: blockId, row: row, column: column),
          );
          occupied.add(key);
          placed = true;
          break;
        }
      }
      if (!placed) {
        throw const FormatException('Preset grid has no free slot for an effect block.');
      }
    }

    final grid = RigGrid(placements: List.unmodifiable(placements));
    final rawConnections = value['connections'];
    if (rawConnections != null) {
      if (rawConnections is! List) {
        throw const FormatException('Preset grid connections must be a list.');
      }
      final saved = rawConnections.map(GridConnection.fromJson).toList();
      if (missingBlockIds.isEmpty) {
        final expected = grid.connections;
        if (saved.length != expected.length ||
            saved.toSet().length != saved.length ||
            !saved.toSet().containsAll(expected)) {
          throw const FormatException('Preset grid connections do not match its lane layout.');
        }
      }
    }
    return grid;
  }

  GridPlacement? positionOf(String blockId) {
    for (final placement in placements) {
      if (placement.blockId == blockId) return placement;
    }
    return null;
  }

  GridPlacement? blockAt(int row, int column) {
    for (final placement in placements) {
      if (placement.row == row && placement.column == column) return placement;
    }
    return null;
  }

  RigGrid withAddedBlock(String blockId, {int preferredRow = 0}) {
    if (preferredRow < 0 || preferredRow >= rigGridRowCount) {
      throw const FormatException('Grid row must be between 1 and 4.');
    }
    if (positionOf(blockId) != null) {
      throw const FormatException('This block is already on the Grid.');
    }
    if (placements.length >= maximumRigGridBlocks) {
      throw const FormatException('The Grid is full. Remove a block before adding another.');
    }

    for (final row in [
      preferredRow,
      ...List.generate(rigGridRowCount, (index) => index)
          .where((index) => index != preferredRow),
    ]) {
      for (var column = 0; column < rigGridColumnCount; column++) {
        if (blockAt(row, column) != null) continue;
        return RigGrid(
          placements: List.unmodifiable([
            ...placements,
            GridPlacement(blockId: blockId, row: row, column: column),
          ]),
        );
      }
    }
    throw const FormatException('The Grid has no available slot.');
  }

  RigGrid moveBlockToSlot(String blockId, int row, int column) {
    if (row < 0 ||
        row >= rigGridRowCount ||
        column < 0 ||
        column >= rigGridColumnCount) {
      throw const FormatException('Choose a valid Grid slot.');
    }
    final sourceIndex = placements.indexWhere((item) => item.blockId == blockId);
    if (sourceIndex < 0) {
      throw const FormatException('The selected block is not on the Grid.');
    }
    final source = placements[sourceIndex];
    if (source.row == row && source.column == column) return this;

    final next = List<GridPlacement>.from(placements);
    final targetIndex = next.indexWhere(
      (item) => item.row == row && item.column == column,
    );
    if (targetIndex >= 0) {
      next[targetIndex] = GridPlacement(
        blockId: next[targetIndex].blockId,
        row: source.row,
        column: source.column,
      );
    }
    next[sourceIndex] = GridPlacement(
      blockId: blockId,
      row: row,
      column: column,
    );
    return RigGrid(placements: List.unmodifiable(next));
  }

  RigGrid withoutBlock(String blockId) {
    return RigGrid(
      placements: List.unmodifiable(
        placements.where((item) => item.blockId != blockId),
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'rows': rigGridRowCount,
    'columns': rigGridColumnCount,
    'placements': placements.map((item) => item.toJson()).toList(),
    'connections': connections.map((item) => item.toJson()).toList(),
  };
}
