/// Metadata-only preview of a future KPT Pro patch transfer.
/// No vendor frames are encoded and no hardware-write API is exposed.
import '../models/rig_preset.dart';

class KptProWriteBlocker {
  const KptProWriteBlocker({
    required this.code,
    required this.title,
    required this.detail,
  });

  final String code;
  final String title;
  final String detail;
}

class KptProWritePlan {
  KptProWritePlan({
    required this.presetId,
    required this.presetName,
    required this.blockCount,
    required this.sceneCount,
    required List<KptProWriteBlocker> blockers,
  }) : blockers = List<KptProWriteBlocker>.unmodifiable(blockers);

  final String presetId;
  final String presetName;
  final int blockCount;
  final int sceneCount;
  final List<KptProWriteBlocker> blockers;

  bool get isBlocked => blockers.isNotEmpty;
  bool get hardwareWriteEnabled => false;
  bool get payloadGenerated => false;
}

class KptProWritePlanner {
  const KptProWritePlanner();

  KptProWritePlan prepare(RigPreset preset) {
    return KptProWritePlan(
      presetId: preset.id,
      presetName: preset.name,
      blockCount: preset.blocks.length,
      sceneCount: preset.scenes.length,
      blockers: const [
        KptProWriteBlocker(
          code: 'command-semantics',
          title: 'KPT Pro command meanings are not verified',
          detail: 'The observed frame envelope and Tank-G-style f1/f2 slices do not identify KPT Pro read, edit, save, or import commands.',
        ),
        KptProWriteBlocker(
          code: 'patch-schema',
          title: 'Native KPT Pro patch structure is unknown',
          detail: 'The hardware module chain, slot map, parameter IDs, value types, and ranges are not decoded. RigCanvas Grid blocks cannot be mapped safely by assumption.',
        ),
        KptProWriteBlocker(
          code: 'transaction-verification',
          title: 'Acknowledgement and read-back are not verified',
          detail: 'KPT-specific completion responses, timeout/retry rules, read-back comparison, and interruption behavior are not established.',
        ),
        KptProWriteBlocker(
          code: 'recovery',
          title: 'Hardware recovery path is not tested',
          detail: 'There is no verified immutable device backup and restore procedure for a failed or interrupted patch operation.',
        ),
        KptProWriteBlocker(
          code: 'native-file-fixture',
          title: 'No genuine M-EFCS whole-patch fixture is available',
          detail: 'A native M-EFCS whole-patch file is needed to establish its container and compatibility rules. RigCanvas JSON and AM2/IR assets are different file families.',
        ),
      ],
    );
  }
}
