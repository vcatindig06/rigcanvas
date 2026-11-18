import 'package:flutter/foundation.dart';

import 'btsnoop_capture.dart';
import 'kpt_pro_protocol.dart';

/// A checksum-validated frame observed in an imported ATT capture.
///
/// The command byte is intentionally retained as a raw identifier. This
/// analyzer does not assign operation names or infer what a command changes.
@immutable
class KptProObservedFrame {
  const KptProObservedFrame({
    required this.direction,
    required this.attributeHandle,
    required this.commandId,
    required this.bodyLength,
    required this.firstFrameNumber,
    required this.lastFrameNumber,
    required this.firstTimestampMicros,
    required this.lastTimestampMicros,
    required this.fragmentCount,
  });

  final BtsnoopDirection direction;
  final int? attributeHandle;
  final int commandId;
  final int bodyLength;
  final int firstFrameNumber;
  final int lastFrameNumber;
  final int firstTimestampMicros;
  final int lastTimestampMicros;
  final int fragmentCount;

  int get durationMicros => lastTimestampMicros - firstTimestampMicros;

  String get commandIdHex =>
      '0x${commandId.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  String get attributeHandleLabel => attributeHandle == null
      ? 'unmapped handle'
      : '0x${attributeHandle!.toRadixString(16).padLeft(4, '0').toUpperCase()}';

  Map<String, Object?> toJson() => {
    'direction': direction.label,
    'attributeHandle': attributeHandleLabel,
    'commandId': commandIdHex,
    'bodyLengthBytes': bodyLength,
    'firstAttFrame': firstFrameNumber,
    'lastAttFrame': lastFrameNumber,
    'firstTimeFromCaptureStartMicros': firstTimestampMicros,
    'lastTimeFromCaptureStartMicros': lastTimestampMicros,
    'fragmentCount': fragmentCount,
  };
}

/// Count of one raw command byte on one directional ATT attribute stream.
@immutable
class KptProCommandSummary {
  const KptProCommandSummary({
    required this.direction,
    required this.attributeHandle,
    required this.commandId,
    required this.count,
    required this.observedBodyLengths,
  });

  final BtsnoopDirection direction;
  final int? attributeHandle;
  final int commandId;
  final int count;
  final List<int> observedBodyLengths;

  String get commandIdHex =>
      '0x${commandId.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  String get attributeHandleLabel => attributeHandle == null
      ? 'unmapped handle'
      : '0x${attributeHandle!.toRadixString(16).padLeft(4, '0').toUpperCase()}';

  Map<String, Object?> toJson() => {
    'direction': direction.label,
    'attributeHandle': attributeHandleLabel,
    'commandId': commandIdHex,
    'frameCount': count,
    'observedBodyLengthsBytes': observedBodyLengths,
  };
}

/// Read-only analysis of the observed 00 59 frame envelope in one ATT session.
@immutable
class KptProFrameAnalysis {
  KptProFrameAnalysis._({
    required this.frames,
    required this.invalidFrameCount,
    required this.incompleteStreamCount,
    required this.analyzedValueEventCount,
  }) : commandSummaries = _buildCommandSummaries(frames);

  final List<KptProObservedFrame> frames;
  final int invalidFrameCount;
  final int incompleteStreamCount;
  final int analyzedValueEventCount;
  final List<KptProCommandSummary> commandSummaries;

  int get completeFrameCount => frames.length;

  Map<String, Object?> toJson() => {
    'analysisType': 'Read-only KPT Pro observed 00 59 frame-envelope analysis',
    'completeFrames': completeFrameCount,
    'invalidFrameCandidates': invalidFrameCount,
    'incompleteStreamsAtEndOfCapture': incompleteStreamCount,
    'analyzedValueEvents': analyzedValueEventCount,
    'commandIdentifiersAreUninterpreted': true,
    'commands': commandSummaries.map((item) => item.toJson()).toList(),
    'frames': frames.map((item) => item.toJson()).toList(),
    'safety': {
      'captureOnly': true,
      'packetsReplayed': false,
      'commandsSent': false,
      'hardwareWritesPerformed': false,
    },
  };

  static List<KptProCommandSummary> _buildCommandSummaries(
    List<KptProObservedFrame> frames,
  ) {
    final grouped = <_CommandSummaryKey, List<KptProObservedFrame>>{};
    for (final frame in frames) {
      final key = _CommandSummaryKey(
        frame.direction,
        frame.attributeHandle,
        frame.commandId,
      );
      grouped.putIfAbsent(key, () => <KptProObservedFrame>[]).add(frame);
    }

    final summaries = grouped.entries.map((entry) {
      final bodyLengths = entry.value
          .map((frame) => frame.bodyLength)
          .toSet()
          .toList()
        ..sort();
      return KptProCommandSummary(
        direction: entry.key.direction,
        attributeHandle: entry.key.attributeHandle,
        commandId: entry.key.commandId,
        count: entry.value.length,
        observedBodyLengths: List<int>.unmodifiable(bodyLengths),
      );
    }).toList();

    summaries.sort((left, right) {
      final directionOrder =
          left.direction.index.compareTo(right.direction.index);
      if (directionOrder != 0) return directionOrder;
      final handleOrder = (left.attributeHandle ?? -1).compareTo(
        right.attributeHandle ?? -1,
      );
      if (handleOrder != 0) return handleOrder;
      return left.commandId.compareTo(right.commandId);
    });
    return List<KptProCommandSummary>.unmodifiable(summaries);
  }
}

/// Applies the captured-byte frame parser to one selected BLE connection.
///
/// Only ATT Write Request, Write Command, Notification and Indication values
/// are considered. Independent streams are maintained by direction, handle,
/// bearer and L2CAP CID so fragments from unrelated attributes are not joined.
class KptProFrameAnalyzer {
  const KptProFrameAnalyzer._();

  static KptProFrameAnalysis analyze(
    Iterable<KptBleAttEvent> source, {
    int maxBodyLength = 8192,
  }) {
    final events = source.where(_isValueTransfer).toList()
      ..sort((left, right) {
        final timeOrder = left.relativeTimestampMicros.compareTo(
          right.relativeTimestampMicros,
        );
        return timeOrder != 0
            ? timeOrder
            : left.frameNumber.compareTo(right.frameNumber);
      });

    final streams = <_KptProStreamKey, _FrameStreamState>{};
    final observations = <KptProObservedFrame>[];
    var invalidFrameCount = 0;
    var analyzedValueEventCount = 0;

    for (final event in events) {
      if (event.value.isEmpty) continue;

      final key = _KptProStreamKey(
        direction: event.direction,
        attributeHandle: event.attributeHandle,
        attBearerId: event.attBearerId,
        l2capCid: event.l2capCid,
      );
      final state = streams.putIfAbsent(
        key,
        () => _FrameStreamState(
          KptProNotificationFrameReassembler(maxBodyLength: maxBodyLength),
        ),
      );

      final wasPending = state.reassembler.hasPendingFrame;
      final beginsCandidate = _startsWithFrameMagic(event.value);
      if (!wasPending && !beginsCandidate) continue;

      analyzedValueEventCount++;
      if (wasPending) {
        state.pendingFragmentCount++;
      } else {
        state.pendingStartEvent = event;
        state.pendingFragmentCount = 1;
      }

      final pendingStart = state.pendingStartEvent;
      final pendingFragments = state.pendingFragmentCount;
      List<KptProProtocolFrame> parsedFrames;
      try {
        parsedFrames = state.reassembler.addNotification(event.value);
      } on FormatException {
        invalidFrameCount++;
        state.clearMetadata();
        continue;
      }

      for (var index = 0; index < parsedFrames.length; index++) {
        final parsed = parsedFrames[index];
        final startsInEarlierEvent = index == 0 && wasPending;
        final firstEvent = startsInEarlierEvent ? pendingStart ?? event : event;
        observations.add(
          KptProObservedFrame(
            direction: event.direction,
            attributeHandle: event.attributeHandle,
            commandId: parsed.commandId,
            bodyLength: parsed.bodyLength,
            firstFrameNumber: firstEvent.frameNumber,
            lastFrameNumber: event.frameNumber,
            firstTimestampMicros: firstEvent.relativeTimestampMicros,
            lastTimestampMicros: event.relativeTimestampMicros,
            fragmentCount: startsInEarlierEvent ? pendingFragments : 1,
          ),
        );
      }

      if (state.reassembler.hasPendingFrame) {
        if (parsedFrames.isNotEmpty) {
          // Any trailing partial frame in this notification starts here.
          state.pendingStartEvent = event;
          state.pendingFragmentCount = 1;
        }
      } else {
        state.clearMetadata();
      }
    }

    observations.sort((left, right) {
      final timeOrder = left.firstTimestampMicros.compareTo(
        right.firstTimestampMicros,
      );
      return timeOrder != 0
          ? timeOrder
          : left.firstFrameNumber.compareTo(right.firstFrameNumber);
    });

    return KptProFrameAnalysis._(
      frames: List<KptProObservedFrame>.unmodifiable(observations),
      invalidFrameCount: invalidFrameCount,
      incompleteStreamCount: streams.values
          .where((state) => state.reassembler.hasPendingFrame)
          .length,
      analyzedValueEventCount: analyzedValueEventCount,
    );
  }

  static bool _isValueTransfer(KptBleAttEvent event) =>
      event.opcode == 0x12 ||
      event.opcode == 0x52 ||
      event.opcode == 0x1B ||
      event.opcode == 0x1D;

  static bool _startsWithFrameMagic(List<int> value) {
    if (value.isEmpty || value[0] != KptProProtocolFrame.magic0) {
      return false;
    }
    return value.length == 1 || value[1] == KptProProtocolFrame.magic1;
  }
}

class _FrameStreamState {
  _FrameStreamState(this.reassembler);

  final KptProNotificationFrameReassembler reassembler;
  KptBleAttEvent? pendingStartEvent;
  int pendingFragmentCount = 0;

  void clearMetadata() {
    pendingStartEvent = null;
    pendingFragmentCount = 0;
  }
}

class _KptProStreamKey {
  const _KptProStreamKey({
    required this.direction,
    required this.attributeHandle,
    required this.attBearerId,
    required this.l2capCid,
  });

  final BtsnoopDirection direction;
  final int? attributeHandle;
  final int? attBearerId;
  final int? l2capCid;

  @override
  bool operator ==(Object other) =>
      other is _KptProStreamKey &&
      other.direction == direction &&
      other.attributeHandle == attributeHandle &&
      other.attBearerId == attBearerId &&
      other.l2capCid == l2capCid;

  @override
  int get hashCode =>
      Object.hash(direction, attributeHandle, attBearerId, l2capCid);
}

class _CommandSummaryKey {
  const _CommandSummaryKey(
    this.direction,
    this.attributeHandle,
    this.commandId,
  );

  final BtsnoopDirection direction;
  final int? attributeHandle;
  final int commandId;

  @override
  bool operator ==(Object other) =>
      other is _CommandSummaryKey &&
      other.direction == direction &&
      other.attributeHandle == attributeHandle &&
      other.commandId == commandId;

  @override
  int get hashCode => Object.hash(direction, attributeHandle, commandId);
}
