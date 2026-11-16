import 'package:flutter/foundation.dart';

enum DeviceConnectionState {
  disconnected,
  discovering,
  connected,
  unsupported,
  permissionDenied,
  protocolMismatch,
}

enum DeviceFeature {
  readPresetCatalog,
  exportPreset,
  writePreset,
  importAm2,
  importIrWav,
  reorderEffectModules,
  nativeScenes,
  stereoSignalPath,
  parallelRouting,
}

@immutable
class DeviceIdentity {
  const DeviceIdentity({
    required this.modelName,
    this.hardwareRevision,
    this.firmwareVersion,
  });

  final String modelName;
  final String? hardwareRevision;
  final String? firmwareVersion;
}

@immutable
class DeviceCapabilities {
  const DeviceCapabilities({
    this.features = const <DeviceFeature>{},
  });

  final Set<DeviceFeature> features;

  bool supports(DeviceFeature feature) => features.contains(feature);
}

@immutable
class DeviceDiscoveryResult {
  const DeviceDiscoveryResult({
    required this.state,
    required this.message,
    this.identity,
    this.capabilities = const DeviceCapabilities(),
  });

  final DeviceConnectionState state;
  final String message;
  final DeviceIdentity? identity;
  final DeviceCapabilities capabilities;
}

/// The UI depends on this interface, never on transport-specific packets.
///
/// A physical KPT Pro adapter must not be implemented until its exact
/// firmware/protocol has been observed and documented.
abstract interface class DeviceGateway {
  Future<DeviceDiscoveryResult> discover();
}

/// Safe default gateway used by the app until hardware support is verified.
class SimulationDeviceGateway implements DeviceGateway {
  const SimulationDeviceGateway();

  @override
  Future<DeviceDiscoveryResult> discover() async {
    return const DeviceDiscoveryResult(
      state: DeviceConnectionState.disconnected,
      message: 'Simulation mode: no hardware transport is active.',
    );
  }
}
