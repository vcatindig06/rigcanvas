import 'package:flutter/foundation.dart';

import 'effect_block.dart';

@immutable
class EffectCatalogEntry {
  const EffectCatalogEntry({
    required this.id,
    required this.name,
    required this.family,
    required this.source,
    required this.description,
  });

  final String id;
  final String name;
  final EffectFamily family;
  final EffectCatalogSource source;
  final String description;
}

const rigCanvasSoftwareCatalog = <EffectCatalogEntry>[
  EffectCatalogEntry(id: 'rigcanvas.dynamics.noise-gate', name: 'Noise Gate', family: EffectFamily.gate, source: EffectCatalogSource.rigCanvasSoftware, description: 'Fast threshold gate template. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.dynamics.adaptive-gate', name: 'Adaptive Gate', family: EffectFamily.gate, source: EffectCatalogSource.rigCanvasSoftware, description: 'Program-dependent gate template. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.dynamics.studio-compressor', name: 'Studio Compressor', family: EffectFamily.gate, source: EffectCatalogSource.rigCanvasSoftware, description: 'General-purpose compressor template. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.dynamics.fet-compressor', name: 'FET Compressor', family: EffectFamily.gate, source: EffectCatalogSource.rigCanvasSoftware, description: 'Fast, assertive compressor archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.dynamics.optical-compressor', name: 'Optical Compressor', family: EffectFamily.gate, source: EffectCatalogSource.rigCanvasSoftware, description: 'Smooth leveling compressor archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.dynamics.multiband-compressor', name: 'Multiband Compressor', family: EffectFamily.gate, source: EffectCatalogSource.rigCanvasSoftware, description: 'Multi-band dynamics template. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.dynamics.limiter', name: 'Limiter', family: EffectFamily.gate, source: EffectCatalogSource.rigCanvasSoftware, description: 'Peak-control dynamics template. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.dynamics.sustain-compressor', name: 'Sustain Compressor', family: EffectFamily.gate, source: EffectCatalogSource.rigCanvasSoftware, description: 'Sustain-oriented compressor template. Software audio processing is not implemented yet.'),

  EffectCatalogEntry(id: 'rigcanvas.drive.clean-boost', name: 'Clean Boost', family: EffectFamily.drive, source: EffectCatalogSource.rigCanvasSoftware, description: 'Low-colour level boost archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.drive.transparent-overdrive', name: 'Transparent Overdrive', family: EffectFamily.drive, source: EffectCatalogSource.rigCanvasSoftware, description: 'Low-to-medium gain transparent overdrive archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.drive.klon-style', name: 'Klon-style Overdrive', family: EffectFamily.drive, source: EffectCatalogSource.rigCanvasSoftware, description: 'Transparent overdrive with a focused midrange concept. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.drive.tube-screamer-style', name: 'Tube Screamer-style Drive', family: EffectFamily.drive, source: EffectCatalogSource.rigCanvasSoftware, description: 'Mid-hump overdrive archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.drive.bluesbreaker-style', name: 'Bluesbreaker-style Overdrive', family: EffectFamily.drive, source: EffectCatalogSource.rigCanvasSoftware, description: 'Open, low-gain overdrive archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.drive.morning-glory-style', name: 'Morning Glory-style Overdrive', family: EffectFamily.drive, source: EffectCatalogSource.rigCanvasSoftware, description: 'Transparent British-flavoured overdrive concept. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.drive.blues-driver-style', name: 'Blues Driver-style Overdrive', family: EffectFamily.drive, source: EffectCatalogSource.rigCanvasSoftware, description: 'Broad-range overdrive archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.drive.rat-style', name: 'Rat-style Distortion', family: EffectFamily.drive, source: EffectCatalogSource.rigCanvasSoftware, description: 'Classic hard-clipping distortion archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.drive.modern-distortion', name: 'Modern Distortion', family: EffectFamily.drive, source: EffectCatalogSource.rigCanvasSoftware, description: 'Tighter high-gain distortion archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.drive.vintage-fuzz', name: 'Vintage Fuzz', family: EffectFamily.drive, source: EffectCatalogSource.rigCanvasSoftware, description: 'Vintage fuzz archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.drive.sustain-fuzz', name: 'Sustain Fuzz', family: EffectFamily.drive, source: EffectCatalogSource.rigCanvasSoftware, description: 'Dense, sustaining fuzz archetype. Software audio processing is not implemented yet.'),

  EffectCatalogEntry(id: 'rigcanvas.amp.american-clean', name: 'American Clean', family: EffectFamily.amplifier, source: EffectCatalogSource.rigCanvasSoftware, description: 'Clean American combo archetype. Not a named KPT PRO factory model.'),
  EffectCatalogEntry(id: 'rigcanvas.amp.tweed-clean', name: 'Tweed-style Clean', family: EffectFamily.amplifier, source: EffectCatalogSource.rigCanvasSoftware, description: 'Early American combo archetype. Not a named KPT PRO factory model.'),
  EffectCatalogEntry(id: 'rigcanvas.amp.boutique-clean', name: 'Boutique Clean', family: EffectFamily.amplifier, source: EffectCatalogSource.rigCanvasSoftware, description: 'Dynamic boutique clean archetype. Not a named KPT PRO factory model.'),
  EffectCatalogEntry(id: 'rigcanvas.amp.british-chime', name: 'British Chime', family: EffectFamily.amplifier, source: EffectCatalogSource.rigCanvasSoftware, description: 'Chime-focused British amp archetype. Not a named KPT PRO factory model.'),
  EffectCatalogEntry(id: 'rigcanvas.amp.british-crunch', name: 'British Crunch', family: EffectFamily.amplifier, source: EffectCatalogSource.rigCanvasSoftware, description: 'Classic British crunch archetype. Not a named KPT PRO factory model.'),
  EffectCatalogEntry(id: 'rigcanvas.amp.british-high-gain', name: 'British High Gain', family: EffectFamily.amplifier, source: EffectCatalogSource.rigCanvasSoftware, description: 'Hot-rodded British amp archetype. Not a named KPT PRO factory model.'),
  EffectCatalogEntry(id: 'rigcanvas.amp.modern-high-gain', name: 'Modern High Gain', family: EffectFamily.amplifier, source: EffectCatalogSource.rigCanvasSoftware, description: 'Tight modern high-gain archetype. Not a named KPT PRO factory model.'),
  EffectCatalogEntry(id: 'rigcanvas.amp.classic-lead', name: 'Classic Lead', family: EffectFamily.amplifier, source: EffectCatalogSource.rigCanvasSoftware, description: 'Mid-forward lead amp archetype. Not a named KPT PRO factory model.'),
  EffectCatalogEntry(id: 'rigcanvas.amp.boutique-overdrive', name: 'Boutique Overdrive', family: EffectFamily.amplifier, source: EffectCatalogSource.rigCanvasSoftware, description: 'Touch-sensitive overdrive amp archetype. Not a named KPT PRO factory model.'),
  EffectCatalogEntry(id: 'rigcanvas.amp.jazz-clean', name: 'Jazz Clean', family: EffectFamily.amplifier, source: EffectCatalogSource.rigCanvasSoftware, description: 'Clean, high-headroom amp archetype. Not a named KPT PRO factory model.'),
  EffectCatalogEntry(id: 'rigcanvas.amp.bass-clean', name: 'Bass Clean', family: EffectFamily.amplifier, source: EffectCatalogSource.rigCanvasSoftware, description: 'Clean bass amp archetype. Not a named KPT PRO factory model.'),

  EffectCatalogEntry(id: 'rigcanvas.cab.112-open-back', name: '1×12 Open Back', family: EffectFamily.cabinet, source: EffectCatalogSource.rigCanvasSoftware, description: 'Open-back 1×12 cabinet template. Not a named KPT PRO factory cabinet.'),
  EffectCatalogEntry(id: 'rigcanvas.cab.112-closed-back', name: '1×12 Closed Back', family: EffectFamily.cabinet, source: EffectCatalogSource.rigCanvasSoftware, description: 'Closed-back 1×12 cabinet template. Not a named KPT PRO factory cabinet.'),
  EffectCatalogEntry(id: 'rigcanvas.cab.212-open-back', name: '2×12 Open Back', family: EffectFamily.cabinet, source: EffectCatalogSource.rigCanvasSoftware, description: 'Open-back 2×12 cabinet template. Not a named KPT PRO factory cabinet.'),
  EffectCatalogEntry(id: 'rigcanvas.cab.212-closed-back', name: '2×12 Closed Back', family: EffectFamily.cabinet, source: EffectCatalogSource.rigCanvasSoftware, description: 'Closed-back 2×12 cabinet template. Not a named KPT PRO factory cabinet.'),
  EffectCatalogEntry(id: 'rigcanvas.cab.212-alnico-style', name: '2×12 Alnico-style', family: EffectFamily.cabinet, source: EffectCatalogSource.rigCanvasSoftware, description: 'Alnico-voiced 2×12 cabinet template. Not a named KPT PRO factory cabinet.'),
  EffectCatalogEntry(id: 'rigcanvas.cab.412-greenback-style', name: '4×12 Greenback-style', family: EffectFamily.cabinet, source: EffectCatalogSource.rigCanvasSoftware, description: 'Classic British 4×12 cabinet template. Not a named KPT PRO factory cabinet.'),
  EffectCatalogEntry(id: 'rigcanvas.cab.412-v30-style', name: '4×12 V30-style', family: EffectFamily.cabinet, source: EffectCatalogSource.rigCanvasSoftware, description: 'Modern 4×12 cabinet template. Not a named KPT PRO factory cabinet.'),
  EffectCatalogEntry(id: 'rigcanvas.cab.412-modern', name: '4×12 Modern', family: EffectFamily.cabinet, source: EffectCatalogSource.rigCanvasSoftware, description: 'Modern closed-back 4×12 cabinet template. Not a named KPT PRO factory cabinet.'),
  EffectCatalogEntry(id: 'rigcanvas.cab.810-bass', name: '8×10 Bass Cabinet', family: EffectFamily.cabinet, source: EffectCatalogSource.rigCanvasSoftware, description: 'Large-format bass cabinet template. Not a named KPT PRO factory cabinet.'),
  EffectCatalogEntry(id: 'rigcanvas.cab.ir-loader', name: 'Third-party IR Loader', family: EffectFamily.cabinet, source: EffectCatalogSource.rigCanvasSoftware, description: 'Local cabinet IR assignment slot. Rendering is not available until the audio engine is implemented.'),

  EffectCatalogEntry(id: 'rigcanvas.mod.stereo-chorus', name: 'Stereo Chorus', family: EffectFamily.modulation, source: EffectCatalogSource.rigCanvasSoftware, description: 'Wide stereo chorus archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.mod.dimension-chorus', name: 'Dimension Chorus', family: EffectFamily.modulation, source: EffectCatalogSource.rigCanvasSoftware, description: 'Subtle multi-voice chorus archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.mod.phaser', name: 'Phaser', family: EffectFamily.modulation, source: EffectCatalogSource.rigCanvasSoftware, description: 'Classic phase-shift modulation archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.mod.flanger', name: 'Flanger', family: EffectFamily.modulation, source: EffectCatalogSource.rigCanvasSoftware, description: 'Regenerative sweep modulation archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.mod.tremolo', name: 'Tremolo', family: EffectFamily.modulation, source: EffectCatalogSource.rigCanvasSoftware, description: 'Amplitude modulation archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.mod.harmonic-tremolo', name: 'Harmonic Tremolo', family: EffectFamily.modulation, source: EffectCatalogSource.rigCanvasSoftware, description: 'Frequency-split tremolo archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.mod.vibrato', name: 'Vibrato', family: EffectFamily.modulation, source: EffectCatalogSource.rigCanvasSoftware, description: 'Pitch modulation archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.mod.univibe', name: 'Uni-Vibe-style Modulation', family: EffectFamily.modulation, source: EffectCatalogSource.rigCanvasSoftware, description: 'Phase-and-amplitude modulation archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.mod.rotary', name: 'Rotary Speaker', family: EffectFamily.modulation, source: EffectCatalogSource.rigCanvasSoftware, description: 'Rotating speaker simulation concept. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.mod.auto-wah', name: 'Auto Wah', family: EffectFamily.modulation, source: EffectCatalogSource.rigCanvasSoftware, description: 'Envelope-controlled wah archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.mod.envelope-filter', name: 'Envelope Filter', family: EffectFamily.modulation, source: EffectCatalogSource.rigCanvasSoftware, description: 'Touch-sensitive filter archetype. Software audio processing is not implemented yet.'),

  EffectCatalogEntry(id: 'rigcanvas.delay.digital', name: 'Digital Delay', family: EffectFamily.delay, source: EffectCatalogSource.rigCanvasSoftware, description: 'Clean digital repeat archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.delay.analog', name: 'Analog Delay', family: EffectFamily.delay, source: EffectCatalogSource.rigCanvasSoftware, description: 'Dark analog repeat archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.delay.tape', name: 'Tape Echo', family: EffectFamily.delay, source: EffectCatalogSource.rigCanvasSoftware, description: 'Tape-style repeat and modulation archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.delay.dual', name: 'Dual Delay', family: EffectFamily.delay, source: EffectCatalogSource.rigCanvasSoftware, description: 'Two-engine delay template. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.delay.ping-pong', name: 'Ping-Pong Delay', family: EffectFamily.delay, source: EffectCatalogSource.rigCanvasSoftware, description: 'Alternating stereo repeat archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.delay.ducking', name: 'Ducking Delay', family: EffectFamily.delay, source: EffectCatalogSource.rigCanvasSoftware, description: 'Input-sensitive repeat level archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.delay.reverse', name: 'Reverse Delay', family: EffectFamily.delay, source: EffectCatalogSource.rigCanvasSoftware, description: 'Reversed repeat texture archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.delay.slapback', name: 'Slapback Delay', family: EffectFamily.delay, source: EffectCatalogSource.rigCanvasSoftware, description: 'Short single-repeat archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.delay.circular', name: 'Circular Delay', family: EffectFamily.delay, source: EffectCatalogSource.rigCanvasSoftware, description: 'Multi-path rhythmic delay template. Software audio processing is not implemented yet.'),

  EffectCatalogEntry(id: 'rigcanvas.reverb.room', name: 'Room Reverb', family: EffectFamily.reverb, source: EffectCatalogSource.rigCanvasSoftware, description: 'Small-room ambience archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.reverb.hall', name: 'Hall Reverb', family: EffectFamily.reverb, source: EffectCatalogSource.rigCanvasSoftware, description: 'Large hall ambience archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.reverb.plate', name: 'Plate Reverb', family: EffectFamily.reverb, source: EffectCatalogSource.rigCanvasSoftware, description: 'Dense plate reverb archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.reverb.spring', name: 'Spring Reverb', family: EffectFamily.reverb, source: EffectCatalogSource.rigCanvasSoftware, description: 'Classic spring reverb archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.reverb.chamber', name: 'Chamber Reverb', family: EffectFamily.reverb, source: EffectCatalogSource.rigCanvasSoftware, description: 'Studio chamber ambience archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.reverb.shimmer', name: 'Shimmer Reverb', family: EffectFamily.reverb, source: EffectCatalogSource.rigCanvasSoftware, description: 'Octave-enhanced ambient reverb concept. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.reverb.cloud', name: 'Cloud Reverb', family: EffectFamily.reverb, source: EffectCatalogSource.rigCanvasSoftware, description: 'Diffuse ambient reverb archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.reverb.modulated', name: 'Modulated Reverb', family: EffectFamily.reverb, source: EffectCatalogSource.rigCanvasSoftware, description: 'Modulated reverb tail archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.reverb.swell', name: 'Swell Reverb', family: EffectFamily.reverb, source: EffectCatalogSource.rigCanvasSoftware, description: 'Volume-swell ambience archetype. Software audio processing is not implemented yet.'),
  EffectCatalogEntry(id: 'rigcanvas.reverb.gated', name: 'Gated Reverb', family: EffectFamily.reverb, source: EffectCatalogSource.rigCanvasSoftware, description: 'Gated ambience archetype. Software audio processing is not implemented yet.'),
];

const kptProManualCatalog = <EffectCatalogEntry>[
  EffectCatalogEntry(id: 'kptpro.fx.ai-gate', name: 'AI Gate', family: EffectFamily.gate, source: EffectCatalogSource.kptProManual, description: 'KPT PRO FX module · listed in the user manual; firmware v15 behavior not yet device-verified.'),
  EffectCatalogEntry(id: 'kptpro.fx.compress', name: 'Compress', family: EffectFamily.gate, source: EffectCatalogSource.kptProManual, description: 'KPT PRO FX module · listed in the user manual; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.fx.f-compress', name: 'F Compress', family: EffectFamily.gate, source: EffectCatalogSource.kptProManual, description: 'KPT PRO FX module · listed in the user manual; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.fx.a-boost', name: 'A Boost', family: EffectFamily.drive, source: EffectCatalogSource.kptProManual, description: 'KPT PRO FX module · listed in the user manual; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.fx.b-boost', name: 'B Boost', family: EffectFamily.drive, source: EffectCatalogSource.kptProManual, description: 'KPT PRO FX module · listed in the user manual; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.fx.boost-od', name: 'Boost OD', family: EffectFamily.drive, source: EffectCatalogSource.kptProManual, description: 'KPT PRO FX module · listed in the user manual; control map not yet verified.'),

  EffectCatalogEntry(id: 'kptpro.mod.chorus', name: 'Chorus', family: EffectFamily.modulation, source: EffectCatalogSource.kptProManual, description: 'KPT PRO MOD module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.mod.phaser', name: 'Phaser', family: EffectFamily.modulation, source: EffectCatalogSource.kptProManual, description: 'KPT PRO MOD module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.mod.tremolo', name: 'Tremolo', family: EffectFamily.modulation, source: EffectCatalogSource.kptProManual, description: 'KPT PRO MOD module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.mod.flanger', name: 'Flanger', family: EffectFamily.modulation, source: EffectCatalogSource.kptProManual, description: 'KPT PRO MOD module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.mod.vibrato', name: 'Vibrato', family: EffectFamily.modulation, source: EffectCatalogSource.kptProManual, description: 'KPT PRO MOD module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.mod.univibe', name: 'Univibe', family: EffectFamily.modulation, source: EffectCatalogSource.kptProManual, description: 'KPT PRO MOD module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.mod.autofilter', name: 'Autofilter', family: EffectFamily.modulation, source: EffectCatalogSource.kptProManual, description: 'KPT PRO MOD module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.mod.wah-wah', name: 'Wah-Wah', family: EffectFamily.modulation, source: EffectCatalogSource.kptProManual, description: 'KPT PRO MOD module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.mod.sense-wah', name: 'Sense-Wah', family: EffectFamily.modulation, source: EffectCatalogSource.kptProManual, description: 'KPT PRO MOD module · manual-listed model; control map not yet verified.'),

  EffectCatalogEntry(id: 'kptpro.dly.analog', name: 'Analog', family: EffectFamily.delay, source: EffectCatalogSource.kptProManual, description: 'KPT PRO DLY module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.dly.duck', name: 'Duck', family: EffectFamily.delay, source: EffectCatalogSource.kptProManual, description: 'KPT PRO DLY module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.dly.dtape', name: 'dTape', family: EffectFamily.delay, source: EffectCatalogSource.kptProManual, description: 'KPT PRO DLY module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.dly.dual', name: 'Dual', family: EffectFamily.delay, source: EffectCatalogSource.kptProManual, description: 'KPT PRO DLY module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.dly.lofi', name: 'Lofi', family: EffectFamily.delay, source: EffectCatalogSource.kptProManual, description: 'KPT PRO DLY module · manual-listed model; control map not yet verified.'),

  EffectCatalogEntry(id: 'kptpro.rev.room', name: 'Room', family: EffectFamily.reverb, source: EffectCatalogSource.kptProManual, description: 'KPT PRO REV module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.rev.hall', name: 'Hall', family: EffectFamily.reverb, source: EffectCatalogSource.kptProManual, description: 'KPT PRO REV module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.rev.swell', name: 'Swell', family: EffectFamily.reverb, source: EffectCatalogSource.kptProManual, description: 'KPT PRO REV module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.rev.spring', name: 'Spring', family: EffectFamily.reverb, source: EffectCatalogSource.kptProManual, description: 'KPT PRO REV module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.rev.shimmer', name: 'Shimmer', family: EffectFamily.reverb, source: EffectCatalogSource.kptProManual, description: 'KPT PRO REV module · manual-listed model; control map not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.rev.cloud', name: 'Cloud', family: EffectFamily.reverb, source: EffectCatalogSource.kptProManual, description: 'KPT PRO REV module · manual-listed model; control map not yet verified.'),

  EffectCatalogEntry(id: 'kptpro.ext.volume', name: 'Volume (EXT)', family: EffectFamily.gate, source: EffectCatalogSource.kptProManual, description: 'KPT PRO EXT module · manual-listed control; exact mapping not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.ext.x-wah', name: 'X-Wah (EXT)', family: EffectFamily.modulation, source: EffectCatalogSource.kptProManual, description: 'KPT PRO EXT module · manual-listed control; exact mapping not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.ext.funk-wah', name: 'Funk-Wah (EXT)', family: EffectFamily.modulation, source: EffectCatalogSource.kptProManual, description: 'KPT PRO EXT module · manual-listed control; exact mapping not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.ext.slide-wah', name: 'Slide-Wah (EXT)', family: EffectFamily.modulation, source: EffectCatalogSource.kptProManual, description: 'KPT PRO EXT module · manual-listed control; exact mapping not yet verified.'),
  EffectCatalogEntry(id: 'kptpro.ext.cry-wah', name: 'Cry-Wah (EXT)', family: EffectFamily.modulation, source: EffectCatalogSource.kptProManual, description: 'KPT PRO EXT module · manual-listed control; exact mapping not yet verified.'),
];

List<EffectCatalogEntry> effectCatalogFor(EffectCatalogSource source) {
  switch (source) {
    case EffectCatalogSource.rigCanvasSoftware:
      return rigCanvasSoftwareCatalog;
    case EffectCatalogSource.kptProManual:
      return kptProManualCatalog;
  }
}

List<EffectCatalogEntry> effectCatalogForFamily({
  required EffectCatalogSource source,
  required EffectFamily family,
}) => effectCatalogFor(source)
    .where((entry) => entry.family == family)
    .toList(growable: false);

