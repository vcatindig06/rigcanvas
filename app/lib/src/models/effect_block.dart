import 'package:material_ui/material_ui.dart';

enum EffectFamily {
  gate,
  drive,
  amplifier,
  cabinet,
  modulation,
  delay,
  reverb,
  eq,
  pitch,
  expression,
}

extension EffectFamilyPresentation on EffectFamily {
  String get label => switch (this) {
    EffectFamily.gate => 'Dynamics',
    EffectFamily.drive => 'Drive',
    EffectFamily.amplifier => 'Amplifier',
    EffectFamily.cabinet => 'Cabinet',
    EffectFamily.modulation => 'Modulation',
    EffectFamily.delay => 'Delay',
    EffectFamily.reverb => 'Reverb',
    EffectFamily.eq => 'EQ',
    EffectFamily.pitch => 'Pitch',
    EffectFamily.expression => 'Wah / Expression',
  };

  IconData get icon => switch (this) {
    EffectFamily.gate => Icons.graphic_eq,
    EffectFamily.drive => Icons.bolt,
    EffectFamily.amplifier => Icons.speaker,
    EffectFamily.cabinet => Icons.album,
    EffectFamily.modulation => Icons.waves,
    EffectFamily.delay => Icons.av_timer,
    EffectFamily.reverb => Icons.blur_on,
    EffectFamily.eq => Icons.equalizer,
    EffectFamily.pitch => Icons.multitrack_audio,
    EffectFamily.expression => Icons.tune,
  };
}

enum EffectModelSource { kptProFactory, rigcanvasExpanded }

extension EffectModelSourcePresentation on EffectModelSource {
  String get label => switch (this) {
    EffectModelSource.kptProFactory => 'KPT PRO FACTORY',
    EffectModelSource.rigcanvasExpanded => 'RIGCANVAS LIBRARY',
  };
}

enum EffectInstrument { universal, guitar, bass }

@immutable
class EffectModelDefinition {
  const EffectModelDefinition({
    required this.id,
    required this.family,
    required this.name,
    required this.description,
    required this.source,
    this.instrument = EffectInstrument.universal,
  });

  final String id;
  final EffectFamily family;
  final String name;
  final String description;
  final EffectModelSource source;
  final EffectInstrument instrument;

  String get instrumentLabel => switch (instrument) {
    EffectInstrument.universal => 'Guitar / Bass',
    EffectInstrument.guitar => 'Guitar',
    EffectInstrument.bass => 'Bass',
  };
}

/// Fixed model catalog. The KPT Pro manual numbers its amp and cabinet slots
/// but does not publish each model's descriptive name. Those remain numbered.
class EffectModelCatalog {
  EffectModelCatalog._();

  static EffectModelDefinition _model(
    String id,
    EffectFamily family,
    String name,
    String description,
    EffectModelSource source,
    {EffectInstrument instrument = EffectInstrument.universal}
  ) => EffectModelDefinition(
    id: id,
    family: family,
    name: name,
    description: description,
    source: source,
    instrument: instrument,
  );

  static final List<EffectModelDefinition> all = List.unmodifiable([
    // KPT Pro FX module: six documented factory choices.
    _model('kpt.fx.ai_gate', EffectFamily.gate, 'AI Gate',
      'KPT Pro factory FX slot · intelligent noise gate.', EffectModelSource.kptProFactory),
    _model('kpt.fx.compress', EffectFamily.gate, 'Compress',
      'KPT Pro factory FX slot · compressor.', EffectModelSource.kptProFactory),
    _model('kpt.fx.f_compress', EffectFamily.gate, 'F Compress',
      'KPT Pro factory FX slot · compressor variant.', EffectModelSource.kptProFactory),
    _model('kpt.fx.a_boost', EffectFamily.drive, 'A Boost',
      'KPT Pro factory FX slot · boost.', EffectModelSource.kptProFactory),
    _model('kpt.fx.b_boost', EffectFamily.drive, 'B Boost',
      'KPT Pro factory FX slot · boost.', EffectModelSource.kptProFactory),
    _model('kpt.fx.boost_od', EffectFamily.drive, 'Boost OD',
      'KPT Pro factory FX slot · boost overdrive.', EffectModelSource.kptProFactory),

    // KPT Pro manual: guitar preamps 1–50, bass preamps 51–60.
    ...List.generate(50, (index) {
      final slot = index + 1;
      final number = slot.toString().padLeft(2, '0');
      return _model(
        'kpt.amp.guitar.' + index.toString(),
        EffectFamily.amplifier,
        'Guitar Preamp ' + number,
        'KPT Pro factory preamp slot ' + slot.toString() +
            '. The available manual does not publish an individual model name.',
        EffectModelSource.kptProFactory,
        instrument: EffectInstrument.guitar,
      );
    }),
    ...List.generate(10, (index) {
      final slot = index + 51;
      final number = slot.toString().padLeft(2, '0');
      return _model(
        'kpt.amp.bass.' + index.toString(),
        EffectFamily.amplifier,
        'Bass Preamp ' + number,
        'KPT Pro factory preamp slot ' + slot.toString() +
            '. The available manual does not publish an individual model name.',
        EffectModelSource.kptProFactory,
        instrument: EffectInstrument.bass,
      );
    }),

    // KPT Pro MOD module: nine documented factory choices.
    _model('kpt.mod.chorus', EffectFamily.modulation, 'Chorus',
      'KPT Pro factory modulation model.', EffectModelSource.kptProFactory),
    _model('kpt.mod.phaser', EffectFamily.modulation, 'Phaser',
      'KPT Pro factory modulation model.', EffectModelSource.kptProFactory),
    _model('kpt.mod.tremolo', EffectFamily.modulation, 'Tremolo',
      'KPT Pro factory modulation model.', EffectModelSource.kptProFactory),
    _model('kpt.mod.flanger', EffectFamily.modulation, 'Flanger',
      'KPT Pro factory modulation model.', EffectModelSource.kptProFactory),
    _model('kpt.mod.vibrato', EffectFamily.modulation, 'Vibrato',
      'KPT Pro factory modulation model.', EffectModelSource.kptProFactory),
    _model('kpt.mod.univibe', EffectFamily.modulation, 'Univibe',
      'KPT Pro factory modulation model.', EffectModelSource.kptProFactory),
    _model('kpt.mod.autofilter', EffectFamily.modulation, 'Autofilter',
      'KPT Pro factory modulation model.', EffectModelSource.kptProFactory),
    _model('kpt.mod.wah_wah', EffectFamily.modulation, 'Wah-Wah',
      'KPT Pro factory modulation model.', EffectModelSource.kptProFactory),
    _model('kpt.mod.sense_wah', EffectFamily.modulation, 'Sense-Wah',
      'KPT Pro factory touch-sensitive wah model.', EffectModelSource.kptProFactory),

    // KPT Pro DLY module: five documented factory choices.
    _model('kpt.delay.analog', EffectFamily.delay, 'Analog',
      'KPT Pro factory delay model.', EffectModelSource.kptProFactory),
    _model('kpt.delay.duck', EffectFamily.delay, 'Duck',
      'KPT Pro factory ducking delay model.', EffectModelSource.kptProFactory),
    _model('kpt.delay.dtape', EffectFamily.delay, 'dTape',
      'KPT Pro factory tape-style delay model.', EffectModelSource.kptProFactory),
    _model('kpt.delay.dual', EffectFamily.delay, 'Dual',
      'KPT Pro factory dual delay model.', EffectModelSource.kptProFactory),
    _model('kpt.delay.lofi', EffectFamily.delay, 'Lofi',
      'KPT Pro factory lo-fi delay model.', EffectModelSource.kptProFactory),

    // KPT Pro REV module: six documented factory choices.
    _model('kpt.reverb.room', EffectFamily.reverb, 'Room',
      'KPT Pro factory reverb model.', EffectModelSource.kptProFactory),
    _model('kpt.reverb.hall', EffectFamily.reverb, 'Hall Reverb',
      'KPT Pro factory Hall reverb model.', EffectModelSource.kptProFactory),
    _model('kpt.reverb.swell', EffectFamily.reverb, 'Swell',
      'KPT Pro factory reverb model.', EffectModelSource.kptProFactory),
    _model('kpt.reverb.spring', EffectFamily.reverb, 'Spring',
      'KPT Pro factory reverb model.', EffectModelSource.kptProFactory),
    _model('kpt.reverb.shimmer', EffectFamily.reverb, 'Shimmer',
      'KPT Pro factory reverb model.', EffectModelSource.kptProFactory),
    _model('kpt.reverb.cloud', EffectFamily.reverb, 'Cloud',
      'KPT Pro factory reverb model.', EffectModelSource.kptProFactory),

    // KPT Pro manual: guitar CAB slots 1–50, bass CAB slots 51–60.
    ...List.generate(50, (index) {
      final slot = index + 1;
      final number = slot.toString().padLeft(2, '0');
      return _model(
        'kpt.cab.guitar.' + index.toString(),
        EffectFamily.cabinet,
        'Guitar CAB ' + number,
        'KPT Pro factory guitar cabinet slot ' + slot.toString() +
            '. The available manual does not publish an individual cabinet name.',
        EffectModelSource.kptProFactory,
        instrument: EffectInstrument.guitar,
      );
    }),
    ...List.generate(10, (index) {
      final slot = index + 51;
      final number = slot.toString().padLeft(2, '0');
      return _model(
        'kpt.cab.bass.' + index.toString(),
        EffectFamily.cabinet,
        'Bass CAB ' + number,
        'KPT Pro factory bass cabinet slot ' + slot.toString() +
            '. The available manual does not publish an individual cabinet name.',
        EffectModelSource.kptProFactory,
        instrument: EffectInstrument.bass,
      );
    }),

    // The KPT Pro overview also lists a built-in three-band EQ.
    // It is shown as a documented factory control, separately from the
    // seven named movable module inventories above.
    _model('kpt.eq.three_band', EffectFamily.eq, '3-Band EQ',
      'KPT Pro manual overview EQ option; its exact module position is not specified.',
      EffectModelSource.kptProFactory),

    // KPT Pro EXT module: five documented external-control choices.
    _model('kpt.ext.volume', EffectFamily.expression, 'VOL',
      'KPT Pro factory external-control volume option.', EffectModelSource.kptProFactory),
    _model('kpt.ext.x_wah', EffectFamily.expression, 'X-Wah',
      'KPT Pro factory external-control wah option.', EffectModelSource.kptProFactory),
    _model('kpt.ext.funk_wah', EffectFamily.expression, 'Funk-Wah',
      'KPT Pro factory external-control wah option.', EffectModelSource.kptProFactory),
    _model('kpt.ext.slide_wah', EffectFamily.expression, 'Slide-Wah',
      'KPT Pro factory external-control wah option.', EffectModelSource.kptProFactory),
    _model('kpt.ext.cry_wah', EffectFamily.expression, 'Cry-Wah',
      'KPT Pro factory external-control wah option.', EffectModelSource.kptProFactory),

    // RigCanvas expanded models. These are generic choices inspired by the
    // categories and broad capabilities documented for leading processors.
    _model('dyn.input_gate', EffectFamily.gate, 'Input Gate',
      'Fast input noise gate.', EffectModelSource.rigcanvasExpanded),
    _model('dyn.hard_gate', EffectFamily.gate, 'Hard Gate',
      'Firm gate for high-gain noise control.', EffectModelSource.rigcanvasExpanded),
    _model('dyn.expander', EffectFamily.gate, 'Downward Expander',
      'Gentler level reduction below threshold.', EffectModelSource.rigcanvasExpanded),
    _model('dyn.studio_vca', EffectFamily.gate, 'Studio VCA Compressor',
      'Controlled, punchy compression.', EffectModelSource.rigcanvasExpanded),
    _model('dyn.optical', EffectFamily.gate, 'Optical Compressor',
      'Smooth leveling and sustain.', EffectModelSource.rigcanvasExpanded),
    _model('dyn.fet', EffectFamily.gate, 'FET Compressor',
      'Fast attack and assertive compression.', EffectModelSource.rigcanvasExpanded),
    _model('dyn.sustain', EffectFamily.gate, 'Sustain Compressor',
      'Even note level and longer sustain.', EffectModelSource.rigcanvasExpanded),
    _model('dyn.multiband', EffectFamily.gate, 'Multiband Compressor',
      'Independent low, mid, and high-band control.', EffectModelSource.rigcanvasExpanded),
    _model('dyn.transient', EffectFamily.gate, 'Transient Shaper',
      'Shape pick attack and note body.', EffectModelSource.rigcanvasExpanded),
    _model('dyn.ducking', EffectFamily.gate, 'Ducking Compressor',
      'Level-dependent compression for space and clarity.', EffectModelSource.rigcanvasExpanded),

    _model('drive.clean_boost', EffectFamily.drive, 'Clean Boost',
      'Level boost with minimal added clipping.', EffectModelSource.rigcanvasExpanded),
    _model('drive.transparent', EffectFamily.drive, 'Transparent Overdrive',
      'Low-to-medium gain with a broad, open response.', EffectModelSource.rigcanvasExpanded),
    _model('drive.mid_hump', EffectFamily.drive, 'Mid-Hump Overdrive',
      'Focused mids for pushing an amplifier.', EffectModelSource.rigcanvasExpanded),
    _model('drive.blues', EffectFamily.drive, 'Blues Overdrive',
      'Soft-edged breakup and touch response.', EffectModelSource.rigcanvasExpanded),
    _model('drive.open', EffectFamily.drive, 'Open Overdrive',
      'Wide-band overdrive with a natural low end.', EffectModelSource.rigcanvasExpanded),
    _model('drive.classic_distortion', EffectFamily.drive, 'Classic Distortion',
      'Harder-clipping rock distortion.', EffectModelSource.rigcanvasExpanded),
    _model('drive.modern_distortion', EffectFamily.drive, 'Modern Distortion',
      'Tighter, higher-gain distortion.', EffectModelSource.rigcanvasExpanded),
    _model('drive.high_gain', EffectFamily.drive, 'High-Gain Distortion',
      'Saturated modern rhythm and lead drive.', EffectModelSource.rigcanvasExpanded),
    _model('drive.fuzz', EffectFamily.drive, 'Vintage Fuzz',
      'Dense fuzz with a softer top end.', EffectModelSource.rigcanvasExpanded),
    _model('drive.octave_fuzz', EffectFamily.drive, 'Octave Fuzz',
      'Fuzz with an upper-octave character.', EffectModelSource.rigcanvasExpanded),
    _model('drive.gated_fuzz', EffectFamily.drive, 'Gated Fuzz',
      'Fuzz with an abrupt, gated decay.', EffectModelSource.rigcanvasExpanded),
    _model('drive.bass_overdrive', EffectFamily.drive, 'Bass Overdrive',
      'Drive voicing intended to retain bass fundamentals.',
      EffectModelSource.rigcanvasExpanded, instrument: EffectInstrument.bass),

    _model('amp.american_clean', EffectFamily.amplifier, 'American Clean Combo',
      'Clean combo archetype with generous headroom.', EffectModelSource.rigcanvasExpanded),
    _model('amp.tweed_combo', EffectFamily.amplifier, 'Tweed Combo',
      'Early American breakup and rounded mids.', EffectModelSource.rigcanvasExpanded),
    _model('amp.blackface_clean', EffectFamily.amplifier, 'Blackface-Style Clean',
      'Bright, scooped clean amplifier archetype.', EffectModelSource.rigcanvasExpanded),
    _model('amp.boutique_clean', EffectFamily.amplifier, 'Boutique Clean',
      'Wide, touch-sensitive clean platform.', EffectModelSource.rigcanvasExpanded),
    _model('amp.british_class_a', EffectFamily.amplifier, 'British Class-A Combo',
      'Chime-rich low-to-mid-gain combo archetype.', EffectModelSource.rigcanvasExpanded),
    _model('amp.british_stack', EffectFamily.amplifier, 'British Stack',
      'Classic British stack with a broad crunch range.', EffectModelSource.rigcanvasExpanded),
    _model('amp.british_modern', EffectFamily.amplifier, 'British Modern Stack',
      'Hot-rodded British high-gain archetype.', EffectModelSource.rigcanvasExpanded),
    _model('amp.california_high_gain', EffectFamily.amplifier, 'California High-Gain',
      'Modern high-gain amp with tight low end.', EffectModelSource.rigcanvasExpanded),
    _model('amp.german_high_gain', EffectFamily.amplifier, 'German High-Gain',
      'Aggressive, articulate high-gain archetype.', EffectModelSource.rigcanvasExpanded),
    _model('amp.boutique_smooth_lead', EffectFamily.amplifier, 'Boutique Smooth Lead',
      'Singing lead voicing with strong sustain.', EffectModelSource.rigcanvasExpanded),
    _model('amp.acoustic_preamp', EffectFamily.amplifier, 'Acoustic Preamp',
      'Full-range acoustic instrument preamp archetype.', EffectModelSource.rigcanvasExpanded),
    _model('amp.bass_vintage_tube', EffectFamily.amplifier, 'Bass Vintage Tube',
      'Warm bass amplifier archetype.', EffectModelSource.rigcanvasExpanded,
      instrument: EffectInstrument.bass),
    _model('amp.bass_modern_solid_state', EffectFamily.amplifier, 'Bass Modern Solid-State',
      'Fast, controlled modern bass amplifier archetype.', EffectModelSource.rigcanvasExpanded,
      instrument: EffectInstrument.bass),
    _model('amp.bass_studio_di', EffectFamily.amplifier, 'Bass Studio DI',
      'Clean direct-input bass preamp archetype.', EffectModelSource.rigcanvasExpanded,
      instrument: EffectInstrument.bass),

    _model('cab.1x8_practice', EffectFamily.cabinet, '1×8 Practice Cabinet',
      'Compact open-back cabinet archetype.', EffectModelSource.rigcanvasExpanded),
    _model('cab.1x10_combo', EffectFamily.cabinet, '1×10 Combo Cabinet',
      'Small-format combo cabinet archetype.', EffectModelSource.rigcanvasExpanded),
    _model('cab.1x12_open', EffectFamily.cabinet, '1×12 Open-Back Cabinet',
      'Open, airy single-speaker cabinet archetype.', EffectModelSource.rigcanvasExpanded),
    _model('cab.1x12_closed', EffectFamily.cabinet, '1×12 Closed-Back Cabinet',
      'Focused single-speaker cabinet archetype.', EffectModelSource.rigcanvasExpanded),
    _model('cab.2x12_open', EffectFamily.cabinet, '2×12 Open-Back Cabinet',
      'Wide clean and edge-of-breakup cabinet archetype.', EffectModelSource.rigcanvasExpanded),
    _model('cab.2x12_closed', EffectFamily.cabinet, '2×12 Closed-Back Cabinet',
      'Tighter two-speaker cabinet archetype.', EffectModelSource.rigcanvasExpanded),
    _model('cab.2x12_alnico', EffectFamily.cabinet, '2×12 Alnico-Style Cabinet',
      'Chime-rich speaker pairing archetype.', EffectModelSource.rigcanvasExpanded),
    _model('cab.4x10_bass', EffectFamily.cabinet, '4×10 Bass Cabinet',
      'Punchy bass cabinet archetype.', EffectModelSource.rigcanvasExpanded,
      instrument: EffectInstrument.bass),
    _model('cab.4x12_greenback', EffectFamily.cabinet, '4×12 Classic British Cabinet',
      'Mid-forward British cabinet archetype.', EffectModelSource.rigcanvasExpanded),
    _model('cab.4x12_vintage', EffectFamily.cabinet, '4×12 Cabinet',
      'Vintage-style speaker cabinet archetype.', EffectModelSource.rigcanvasExpanded),
    _model('cab.4x12_modern', EffectFamily.cabinet, '4×12 Modern High-Gain Cabinet',
      'Tight low end and extended high-gain response.', EffectModelSource.rigcanvasExpanded),
    _model('cab.4x12_oversized', EffectFamily.cabinet, '4×12 Oversized Cabinet',
      'Large enclosure with extended low end.', EffectModelSource.rigcanvasExpanded),
    _model('cab.1x15_bass', EffectFamily.cabinet, '1×15 Bass Cabinet',
      'Round low-frequency bass cabinet archetype.', EffectModelSource.rigcanvasExpanded,
      instrument: EffectInstrument.bass),
    _model('cab.8x10_bass', EffectFamily.cabinet, '8×10 Bass Cabinet',
      'Large-format punchy bass cabinet archetype.', EffectModelSource.rigcanvasExpanded,
      instrument: EffectInstrument.bass),

    _model('mod.dimension', EffectFamily.modulation, 'Dimension Chorus',
      'Subtle stereo width and modulation.', EffectModelSource.rigcanvasExpanded),
    _model('mod.ensemble', EffectFamily.modulation, 'Ensemble Chorus',
      'Dense multi-voice chorus.', EffectModelSource.rigcanvasExpanded),
    _model('mod.script_phaser', EffectFamily.modulation, 'Script Phaser',
      'Classic shallow phaser sweep.', EffectModelSource.rigcanvasExpanded),
    _model('mod.harmonic_tremolo', EffectFamily.modulation, 'Harmonic Tremolo',
      'Frequency-split tremolo movement.', EffectModelSource.rigcanvasExpanded),
    _model('mod.optical_tremolo', EffectFamily.modulation, 'Optical Tremolo',
      'Smooth amplitude modulation.', EffectModelSource.rigcanvasExpanded),
    _model('mod.rotary', EffectFamily.modulation, 'Rotary Speaker',
      'Rotating speaker-style movement.', EffectModelSource.rigcanvasExpanded),
    _model('mod.jet_flanger', EffectFamily.modulation, 'Jet Flanger',
      'Pronounced flanging sweep.', EffectModelSource.rigcanvasExpanded),
    _model('mod.ring_mod', EffectFamily.modulation, 'Ring Modulator',
      'Inharmonic metallic modulation.', EffectModelSource.rigcanvasExpanded),
    _model('mod.envelope_filter', EffectFamily.modulation, 'Envelope Filter',
      'Pick-responsive filter movement.', EffectModelSource.rigcanvasExpanded),
    _model('mod.micro_pitch', EffectFamily.modulation, 'Micro Pitch',
      'Small pitch offsets for width and thickening.', EffectModelSource.rigcanvasExpanded),

    _model('delay.digital', EffectFamily.delay, 'Digital Delay',
      'Clean, precise repeats.', EffectModelSource.rigcanvasExpanded),
    _model('delay.stereo', EffectFamily.delay, 'Stereo Delay',
      'Independent left and right repeat paths.', EffectModelSource.rigcanvasExpanded),
    _model('delay.ping_pong', EffectFamily.delay, 'Ping-Pong Delay',
      'Alternating stereo repeats.', EffectModelSource.rigcanvasExpanded),
    _model('delay.reverse', EffectFamily.delay, 'Reverse Delay',
      'Reversed repeat texture.', EffectModelSource.rigcanvasExpanded),
    _model('delay.modulated', EffectFamily.delay, 'Modulated Delay',
      'Repeats with modulation movement.', EffectModelSource.rigcanvasExpanded),
    _model('delay.multi_tap', EffectFamily.delay, 'Multi-Tap Delay',
      'Multiple rhythmic repeat taps.', EffectModelSource.rigcanvasExpanded),
    _model('delay.dotted_eighth', EffectFamily.delay, 'Dotted-Eighth Delay',
      'Tempo-oriented dotted-eighth repeats.', EffectModelSource.rigcanvasExpanded),
    _model('delay.slapback', EffectFamily.delay, 'Slapback Echo',
      'Short single-repeat echo.', EffectModelSource.rigcanvasExpanded),
    _model('delay.granular', EffectFamily.delay, 'Granular Texture Delay',
      'Experimental, diffused repeat texture.', EffectModelSource.rigcanvasExpanded),

    _model('reverb.plate', EffectFamily.reverb, 'Plate Reverb',
      'Dense, smooth plate-style decay.', EffectModelSource.rigcanvasExpanded),
    _model('reverb.chamber', EffectFamily.reverb, 'Chamber Reverb',
      'Refined chamber-style ambience.', EffectModelSource.rigcanvasExpanded),
    _model('reverb.cathedral', EffectFamily.reverb, 'Cathedral Reverb',
      'Long, spacious hall-like decay.', EffectModelSource.rigcanvasExpanded),
    _model('reverb.gated', EffectFamily.reverb, 'Gated Reverb',
      'Abruptly truncated reverb envelope.', EffectModelSource.rigcanvasExpanded),
    _model('reverb.reverse', EffectFamily.reverb, 'Reverse Reverb',
      'Reverse-swelling ambience.', EffectModelSource.rigcanvasExpanded),
    _model('reverb.modulated', EffectFamily.reverb, 'Modulated Reverb',
      'Moving, modulated reverb tail.', EffectModelSource.rigcanvasExpanded),
    _model('reverb.bloom', EffectFamily.reverb, 'Bloom Reverb',
      'Slow-building ambient reverb.', EffectModelSource.rigcanvasExpanded),
    _model('reverb.ambient', EffectFamily.reverb, 'Ambient Reverb',
      'Long, diffuse atmospheric tail.', EffectModelSource.rigcanvasExpanded),
    _model('reverb.particle', EffectFamily.reverb, 'Particle Reverb',
      'Shimmering, granular reverb texture.', EffectModelSource.rigcanvasExpanded),

    _model('eq.three_band', EffectFamily.eq, '3-Band EQ',
      'Bass, middle, and treble tone shaping.', EffectModelSource.rigcanvasExpanded),
    _model('eq.graphic', EffectFamily.eq, 'Graphic EQ',
      'Multi-band graphic equalizer.', EffectModelSource.rigcanvasExpanded),
    _model('eq.parametric', EffectFamily.eq, 'Parametric EQ',
      'Frequency, gain, and bandwidth control.', EffectModelSource.rigcanvasExpanded),
    _model('eq.low_high_cut', EffectFamily.eq, 'Low / High Cut',
      'Frequency-limited tone shaping.', EffectModelSource.rigcanvasExpanded),
    _model('eq.tilt', EffectFamily.eq, 'Tilt EQ',
      'One-control dark-to-bright balance.', EffectModelSource.rigcanvasExpanded),

    _model('pitch.octave', EffectFamily.pitch, 'Octave',
      'Octave-up and octave-down voice.', EffectModelSource.rigcanvasExpanded),
    _model('pitch.sub_octave', EffectFamily.pitch, 'Sub Octave',
      'Lower octave reinforcement.', EffectModelSource.rigcanvasExpanded),
    _model('pitch.harmony', EffectFamily.pitch, 'Intelligent Harmony',
      'Diatonic harmony voice.', EffectModelSource.rigcanvasExpanded),
    _model('pitch.detune', EffectFamily.pitch, 'Detune',
      'Small fixed pitch offsets.', EffectModelSource.rigcanvasExpanded),
    _model('pitch.wham', EffectFamily.pitch, 'Wham Pitch',
      'Expression-controlled pitch shift.', EffectModelSource.rigcanvasExpanded),
    _model('pitch.poly', EffectFamily.pitch, 'Polyphonic Pitch',
      'Polyphonic pitch-shift archetype.', EffectModelSource.rigcanvasExpanded),

    _model('expression.volume', EffectFamily.expression, 'Volume Pedal',
      'Local expression-controlled volume model.', EffectModelSource.rigcanvasExpanded),
    _model('expression.wah', EffectFamily.expression, 'Wah Pedal',
      'Conventional expression-controlled wah.', EffectModelSource.rigcanvasExpanded),
    _model('expression.auto_wah', EffectFamily.expression, 'Auto Wah',
      'Envelope-responsive wah sweep.', EffectModelSource.rigcanvasExpanded),
  ]);

  static List<EffectModelDefinition> forFamily(EffectFamily family) =>
      List.unmodifiable(all.where((model) => model.family == family));

  static EffectModelDefinition? byId(String id) {
    for (final model in all) {
      if (model.id == id) return model;
    }
    return null;
  }

  static EffectModelDefinition defaultForFamily(EffectFamily family) =>
      all.firstWhere((model) => model.family == family);

  static String resolveId(
    EffectFamily family, {
    String? modelId,
    String? legacyName,
    String? fallbackModelId,
  }) {
    if (modelId != null) {
      final selected = byId(modelId);
      if (selected == null || selected.family != family) {
        throw FormatException('Unknown model "' + modelId + '" for ' + family.label + '.');
      }
      return selected.id;
    }

    if (legacyName != null) {
      final legacy = legacyName.trim().toLowerCase();
      for (final model in all) {
        if (model.family == family && model.name.toLowerCase() == legacy) {
          return model.id;
        }
      }
    }

    if (fallbackModelId != null) {
      final fallback = byId(fallbackModelId);
      if (fallback != null && fallback.family == family) return fallback.id;
    }

    return defaultForFamily(family).id;
  }

  static int get kptProFactoryCount =>
      all.where((model) => model.source == EffectModelSource.kptProFactory).length;
}

@immutable
class EffectParameterSpec {
  const EffectParameterSpec({
    required this.key,
    required this.label,
    required this.minimum,
    required this.maximum,
    required this.initial,
    this.unit = '',
    this.divisions = 100,
  });

  final String key;
  final String label;
  final double minimum;
  final double maximum;
  final double initial;
  final String unit;
  final int divisions;
}

const Map<EffectFamily, List<EffectParameterSpec>> effectParameterSpecs = {
  EffectFamily.gate: [
    EffectParameterSpec(key: 'threshold', label: 'Threshold', minimum: -80, maximum: 0, initial: -48, unit: 'dB'),
    EffectParameterSpec(key: 'attack', label: 'Attack', minimum: 0.1, maximum: 100, initial: 10, unit: 'ms'),
    EffectParameterSpec(key: 'release', label: 'Release', minimum: 5, maximum: 1000, initial: 120, unit: 'ms'),
    EffectParameterSpec(key: 'ratio', label: 'Ratio', minimum: 1, maximum: 20, initial: 3, unit: ':1'),
    EffectParameterSpec(key: 'makeup', label: 'Makeup', minimum: -12, maximum: 24, initial: 0, unit: 'dB'),
    EffectParameterSpec(key: 'mix', label: 'Mix', minimum: 0, maximum: 100, initial: 100, unit: '%'),
  ],
  EffectFamily.drive: [
    EffectParameterSpec(key: 'gain', label: 'Gain', minimum: 0, maximum: 100, initial: 35, unit: '%'),
    EffectParameterSpec(key: 'tone', label: 'Tone', minimum: 0, maximum: 100, initial: 55, unit: '%'),
    EffectParameterSpec(key: 'level', label: 'Level', minimum: 0, maximum: 100, initial: 65, unit: '%'),
    EffectParameterSpec(key: 'blend', label: 'Blend', minimum: 0, maximum: 100, initial: 100, unit: '%'),
  ],
  EffectFamily.amplifier: [
    EffectParameterSpec(key: 'gain', label: 'Gain', minimum: 0, maximum: 100, initial: 48, unit: '%'),
    EffectParameterSpec(key: 'bass', label: 'Bass', minimum: 0, maximum: 100, initial: 50, unit: '%'),
    EffectParameterSpec(key: 'mid', label: 'Middle', minimum: 0, maximum: 100, initial: 58, unit: '%'),
    EffectParameterSpec(key: 'treble', label: 'Treble', minimum: 0, maximum: 100, initial: 52, unit: '%'),
    EffectParameterSpec(key: 'presence', label: 'Presence', minimum: 0, maximum: 100, initial: 45, unit: '%'),
    EffectParameterSpec(key: 'master', label: 'Master', minimum: 0, maximum: 100, initial: 70, unit: '%'),
  ],
  EffectFamily.cabinet: [
    EffectParameterSpec(key: 'lowCut', label: 'Low Cut', minimum: 20, maximum: 500, initial: 80, unit: 'Hz'),
    EffectParameterSpec(key: 'highCut', label: 'High Cut', minimum: 2000, maximum: 20000, initial: 11000, unit: 'Hz'),
    EffectParameterSpec(key: 'micDistance', label: 'Mic Distance', minimum: 0, maximum: 100, initial: 20, unit: '%'),
    EffectParameterSpec(key: 'level', label: 'Level', minimum: -24, maximum: 12, initial: 0, unit: 'dB'),
  ],
  EffectFamily.modulation: [
    EffectParameterSpec(key: 'rate', label: 'Rate', minimum: 0.1, maximum: 10, initial: 1.2, unit: 'Hz'),
    EffectParameterSpec(key: 'depth', label: 'Depth', minimum: 0, maximum: 100, initial: 45, unit: '%'),
    EffectParameterSpec(key: 'tone', label: 'Tone', minimum: 0, maximum: 100, initial: 55, unit: '%'),
    EffectParameterSpec(key: 'mix', label: 'Mix', minimum: 0, maximum: 100, initial: 25, unit: '%'),
  ],
  EffectFamily.delay: [
    EffectParameterSpec(key: 'time', label: 'Time', minimum: 1, maximum: 8000, initial: 480, unit: 'ms'),
    EffectParameterSpec(key: 'feedback', label: 'Feedback', minimum: 0, maximum: 100, initial: 32, unit: '%'),
    EffectParameterSpec(key: 'highCut', label: 'High Cut', minimum: 1000, maximum: 20000, initial: 9000, unit: 'Hz'),
    EffectParameterSpec(key: 'mix', label: 'Mix', minimum: 0, maximum: 100, initial: 24, unit: '%'),
  ],
  EffectFamily.reverb: [
    EffectParameterSpec(key: 'decay', label: 'Decay', minimum: 0.1, maximum: 60, initial: 5.5, unit: 's'),
    EffectParameterSpec(key: 'predelay', label: 'Pre-delay', minimum: 0, maximum: 250, initial: 25, unit: 'ms'),
    EffectParameterSpec(key: 'tone', label: 'Tone', minimum: 0, maximum: 100, initial: 55, unit: '%'),
    EffectParameterSpec(key: 'mix', label: 'Mix', minimum: 0, maximum: 100, initial: 30, unit: '%'),
  ],
  EffectFamily.eq: [
    EffectParameterSpec(key: 'lowGain', label: 'Low', minimum: -18, maximum: 18, initial: 0, unit: 'dB'),
    EffectParameterSpec(key: 'lowMidGain', label: 'Low Mid', minimum: -18, maximum: 18, initial: 0, unit: 'dB'),
    EffectParameterSpec(key: 'highMidGain', label: 'High Mid', minimum: -18, maximum: 18, initial: 0, unit: 'dB'),
    EffectParameterSpec(key: 'highGain', label: 'High', minimum: -18, maximum: 18, initial: 0, unit: 'dB'),
    EffectParameterSpec(key: 'output', label: 'Output', minimum: -24, maximum: 12, initial: 0, unit: 'dB'),
  ],
  EffectFamily.pitch: [
    EffectParameterSpec(key: 'semitones', label: 'Semitones', minimum: -24, maximum: 24, initial: 12, unit: 'st'),
    EffectParameterSpec(key: 'fineTune', label: 'Fine Tune', minimum: -100, maximum: 100, initial: 0, unit: 'cent'),
    EffectParameterSpec(key: 'mix', label: 'Mix', minimum: 0, maximum: 100, initial: 50, unit: '%'),
  ],
  EffectFamily.expression: [
    EffectParameterSpec(key: 'min', label: 'Minimum', minimum: 0, maximum: 100, initial: 0, unit: '%'),
    EffectParameterSpec(key: 'max', label: 'Maximum', minimum: 0, maximum: 100, initial: 100, unit: '%'),
    EffectParameterSpec(key: 'sweep', label: 'Sweep', minimum: 0, maximum: 100, initial: 50, unit: '%'),
    EffectParameterSpec(key: 'level', label: 'Level', minimum: -24, maximum: 12, initial: 0, unit: 'dB'),
  ],
};

@immutable
class EffectBlock {
  EffectBlock({
    required this.id,
    required String name,
    required this.family,
    required this.description,
    this.enabled = true,
    this.parameters = const <String, double>{},
    this.assetId,
    String? modelId,
  }) : modelId = EffectModelCatalog.resolveId(
         family,
         modelId: modelId,
         legacyName: name,
       ),
       name = EffectModelCatalog.byId(
         EffectModelCatalog.resolveId(
           family,
           modelId: modelId,
           legacyName: name,
         ),
       )!.name;

  final String id;
  /// Canonical catalog model name. User-entered free-form names are not used.
  final String name;
  final String modelId;
  final EffectFamily family;
  final String description;
  final bool enabled;
  final Map<String, double> parameters;

  /// Local Asset Library reference. This does not load or transmit the asset.
  final String? assetId;

  EffectModelDefinition get model => EffectModelCatalog.byId(modelId)!;

  EffectBlock copyWith({
    String? name,
    String? modelId,
    String? description,
    bool? enabled,
    Map<String, double>? parameters,
    String? assetId,
    bool clearAssetId = false,
  }) {
    final nextModelId = EffectModelCatalog.resolveId(
      family,
      modelId: modelId,
      legacyName: name,
      fallbackModelId: this.modelId,
    );
    final nextModel = EffectModelCatalog.byId(nextModelId)!;
    return EffectBlock(
      id: id,
      name: nextModel.name,
      modelId: nextModelId,
      family: family,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      parameters: parameters ?? this.parameters,
      assetId: clearAssetId ? null : (assetId ?? this.assetId),
    );
  }

  static Map<String, double> defaultParameters(EffectFamily family) {
    return {
      for (final spec in effectParameterSpecs[family] ?? <EffectParameterSpec>[])
        spec.key: spec.initial,
    };
  }

  static EffectBlock create({
    required String id,
    required EffectFamily family,
    String? modelId,
  }) {
    final selected = modelId == null
        ? EffectModelCatalog.defaultForFamily(family)
        : EffectModelCatalog.byId(modelId);
    if (selected == null || selected.family != family) {
      throw FormatException('Invalid model selection for ' + family.label + '.');
    }
    return EffectBlock(
      id: id,
      name: selected.name,
      modelId: selected.id,
      family: family,
      description: selected.description,
      parameters: defaultParameters(family),
    );
  }

  static List<EffectBlock> demoChain() {
    return [
      EffectBlock.create(id: 'demo-gate', family: EffectFamily.gate, modelId: 'dyn.input_gate'),
      EffectBlock.create(id: 'demo-drive', family: EffectFamily.drive, modelId: 'drive.transparent'),
      EffectBlock.create(id: 'demo-amp', family: EffectFamily.amplifier, modelId: 'amp.british_stack'),
      EffectBlock.create(id: 'demo-cab', family: EffectFamily.cabinet, modelId: 'cab.4x12_vintage'),
      EffectBlock.create(id: 'demo-delay', family: EffectFamily.delay, modelId: 'delay.stereo'),
      EffectBlock.create(id: 'demo-reverb', family: EffectFamily.reverb, modelId: 'kpt.reverb.hall'),
    ];
  }
}
