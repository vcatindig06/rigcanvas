# RigCanvas Effect Model Catalog — Research Notes

**Research date:** 2026-11-17  
**Application targets:** Android and Windows (shared Flutter catalog)  
**Implementation branch:** `feature/grid-workspace-v1`

## Purpose and evidence boundaries

RigCanvas now uses a fixed, searchable effect-model catalog when creating or changing a block. The catalog deliberately separates:

- **KPT Pro Factory** — choices named or counted in the available KPT Pro user-manual copies.
- **RigCanvas Library** — generic effect and amp/cabinet archetypes added after reviewing leading processors. These are not KPT Pro factory models and are not representations of licensed manufacturer algorithms.

The catalog is a selection and preset-metadata layer. It does not yet implement audio DSP, load an amp model for playback, render a cabinet IR, or communicate a selected block to KPT Pro.

The available KPT Pro manual is hosted by third-party manual sites rather than a manufacturer-controlled documentation portal. Its summary sections are not fully consistent. Treat exact firmware-specific availability as provisional until checked against the user's physical KPT Pro and its matching M-EFCS/app version.

## User-reported firmware baseline

The project owner reports that their physical KPT Pro displays firmware v15 (reported 2026-11-17). This is recorded as a user-provided baseline only; RigCanvas has not independently read the version from the pedal. The manufacturer's download page currently lists a KPT Pro firmware archive labelled KPT PRO-011, but does not publish a mapping from that archive label to the displayed v15 value. The inventory below is manual-documented and must not be described as verified for firmware v15 until the physical unit is checked.

## KPT Pro factory inventory

The KPT Pro manual describes seven movable effect modules — FX, AMP, MOD, DLY, REV, CAB, and EXT — with up to seven plus one effects in simultaneous use. Its detailed module list reports:

| Manual module | Catalog choices | Implementation treatment |
|---|---:|---|
| FX | 6 | AI Gate, Compress, F Compress, A Boost, B Boost, Boost OD |
| AMP | 60 | Guitar Preamp 01–50 and Bass Preamp 51–60 |
| MOD | 9 named entries | Chorus, Phaser, Tremolo, Flanger, Vibrato, Univibe, Autofilter, Wah-Wah, Sense-Wah |
| DLY | 5 | Analog, Duck, dTape, Dual, Lofi |
| REV | 6 | Room, Hall, Swell, Spring, Shimmer, Cloud |
| CAB | 60 | Guitar CAB 01–50 and Bass CAB 51–60 |
| EXT | 5 | VOL, X-Wah, Funk-Wah, Slide-Wah, Cry-Wah |

The module list therefore accounts for 151 factory choices. The manual's overview/FAQ separately mentions a 3-band EQ but does not make its placement in the seven-module chain clear. RigCanvas includes it as a documented KPT Pro EQ choice with a note that its exact module position is unspecified. The catalog test consequently counts 152 KPT-labelled entries including that one overview-level EQ option.

### Important KPT Pro documentation discrepancies

1. The named MOD module list enumerates nine models (including Sense-Wah), while the manual's FAQ/overview says “8 Modulations.” RigCanvas includes all nine named module entries pending confirmation on the exact firmware.
2. The detailed module inventory lists Cloud in REV. Some alternate seller/manual descriptions differ in the reported Reverb list. Factory list differences must be checked against the installed device firmware.
3. The manual identifies AMP and CAB slot counts and numbering, but the accessible text does not publish individual descriptive amp or cabinet names. RigCanvas therefore uses numbered factory-slot labels. It does not invent Fender-, Marshall-, Vox-, Mesa-, or other manufacturer-style names for those slots.
4. The manual's FX section describes combinations such as noise gate plus boost/compression. The catalog exposes the listed choices for browsing, but it does not reproduce their internal hardware combination logic or the physical KPT Pro's slot constraints.

### KPT Pro parameter evidence

The KPT Pro manual gives module-specific controls, not one uniform parameter set for every model. Examples include:

- Compress: Gate, Sustain, Attack, Level, Blend.
- F Compress: Ratio, Threshold, Attack, Tone, Level, Blend.
- A Boost / B Boost: Gate, Gain, Bass, Mid, Treble, Level.
- Boost OD: Gate, Gain, Grit, Level.
- AMP: Gain, Level, Bass, Mid, Treble.
- Chorus: Speed, Depth, Mix.
- Analog delay: Time, Feedback, Mix, Phaser, Pitch.
- dTape: Time, Feedback, Mix, Grit, Speed, Depth.
- Room/Hall reverb: Decay, Mix, high-pass and low-pass controls, with additional model-specific controls for other reverbs.

The current RigCanvas parameter editor is a generic local control template by effect family. It should not be mistaken for the exact KPT Pro firmware parameter map. A future hardware-compatibility milestone must map each verified model to the actual control names, ranges, units, and supported values before writing to a device.

## Broader multi-effects research

The expanded RigCanvas Library uses broad categories and model archetypes after reviewing current documentation for four prominent processor families:

- **Fractal Axe-Fx III:** its official block inventory spans amps, cabinets, compressors, drives, dynamic distortion, gate/expander, graphic and parametric EQ, chorus, flanger, phaser, pitch shift, multiple delay families, reverb, rotary, tremolo, wah, filters, synth, and routing/mix blocks. Its published inventory lists hundreds of amp and cab choices and extensive effect-type inventories.
- **Neural DSP Quad Cortex:** its current manual organizes blocks into AMP, CAB, OVERDRIVE, DELAY, REVERB, COMPRESSOR, PITCH, MODULATION, FILTER, EQ, IR LOADER, WAH, FX LOOP, LOOPER, SYNTH, MORPH, and UTILITY categories. It supports mono/stereo variants and sidechain compressor choices.
- **Line 6 Helix:** its 3.80 owner's manual groups the model picker into categories including Distortion, Dynamics, EQ, Modulation, Delay, and Reverb, with Amp, Preamp, Cab, IR, and Split/Merge path blocks. The manual also explains DSP-dependent block limits rather than pretending every effect can always be loaded simultaneously.
- **Kemper Profiler:** its official materials cover Wah, Distortion, Booster, Shaper, Equalizer, Compressor, Noise Gate, Chorus, Tremolo, Phaser/Flanger, Pitch Shifter, Delay, Pitch Shifter Delay, and Reverb, and describe profiling/capturing amps, cabinets, and microphones.

### RigCanvas expanded library categories

The implementation adds generic, non-factory selections across:

- Dynamics: input/hard gate, downward expander, VCA/optical/FET/sustain/multiband/ducking compressor, transient shaper.
- Drive: clean boost, transparent/mid-hump/blues/open overdrive, classic/modern/high-gain distortion, vintage/octave/gated fuzz, bass overdrive.
- Amplifier archetypes: American clean, tweed, Blackface-style clean, boutique clean/lead, British Class-A, British stack/modern, California/German high gain, acoustic preamp, bass tube/solid-state/DI.
- Cabinets: 1×8, 1×10, 1×12, 2×12, 4×10 bass, 4×12, 1×15 bass and 8×10 bass archetypes.
- Modulation: dimension/ensemble chorus, script phaser, harmonic/optical tremolo, rotary, jet flanger, ring mod, envelope filter, micro-pitch.
- Delay: digital, stereo, ping-pong, reverse, modulated, multi-tap, dotted-eighth, slapback, granular texture.
- Reverb: plate, chamber, cathedral, gated, reverse, modulated, bloom, ambient, particle.
- EQ, pitch, and expression: 3-band/graphic/parametric/tilt/low-high cut EQ; octave, harmony, detune, wham and polyphonic pitch; volume, wah and auto-wah.

These labels describe functional archetypes, not cloned commercial models, manufacturer-endorsed models, or completed DSP algorithms.

## Preset and selection behavior

- Each catalog entry has a stable model ID.
- New blocks are selected from a searchable category picker; the user cannot type a custom model name.
- Changing an existing block opens the same fixed model selector, restricted to its effect family.
- The displayed block name is resolved from the catalog entry and stored with its model ID.
- Preset schema v3 stores model IDs. Schema-v1/v2 preset imports and local preset databases are migrated using the closest exact catalog name or a deterministic family default where no match exists.
- Existing blocks with a user-entered/unknown legacy label are normalized to a catalog label during migration; their old custom label is not retained as a model identity.
- Android and Windows share the same catalog, selection flow, and serialization.
- KPT Pro and RigCanvas-expanded entries have visibly different source tags in the picker and on the Grid.

## Next requirements before audio or hardware support

1. Record the owner's reported firmware display as v15, then verify it directly on the connected unit; record hardware revision and exact M-EFCS app version/device-recognition result.
2. Compare the actual AMP/CAB model slots, MOD count, and REV choices on that unit against the manual.
3. Document model-specific parameter names/ranges for every confirmed KPT Pro model.
4. Choose or implement a shared Android/Windows DSP engine before advertising any expanded model as playable.
5. Capture the v15 unit's read-only USB inventory and full descriptors, then compare the actual AMP/CAB slots, MOD count, REV choices, and effect-slot rules against the manual.
6. Only map KPT model IDs to device memory/control IDs after read-only protocol discovery confirms the mapping. Never send guessed IDs or guessed parameter values to hardware.

## References

### KPT Pro

- [YUIMER KPT PRO User Manual — effect module summary](https://manuals.plus/ae/1005008910756720) — seven movable modules and the named FX/AMP/MOD/DLY/REV/CAB/EXT inventory.
- [YUIMER KPT PRO User Manual — ManualsLib copy](https://www.manualslib.com/manual/3679532/Yuimer-Kpt-Pro.html) — overview and module pages 26–33. Page 19's FAQ lists eight modulations, while the detailed MOD pages list nine; page 27 identifies AMP slots 1–50 for guitar and 51–60 for bass.
- [KPT Pro manual page 26](https://www.manualslib.com/manual/3679532/Yuimer-Kpt-Pro.html?page=26) — FX module and compressor/boost controls.
- [KPT Pro manual page 27](https://www.manualslib.com/manual/3679532/Yuimer-Kpt-Pro.html?page=27) — AMP slot numbers/controls and MOD list beginning.
- [KPT Pro manual page 28](https://www.manualslib.com/manual/3679532/Yuimer-Kpt-Pro.html?page=28) — remaining MOD models, including Wah-Wah.
- [KPT Pro manual page 29](https://www.manualslib.com/manual/3679532/Yuimer-Kpt-Pro.html?page=29) — Sense-Wah and Delay module.
- [KPT Pro manual page 30](https://www.manualslib.com/manual/3679532/Yuimer-Kpt-Pro.html?page=30) — dTape, Dual and Lofi delays.
- [KPT Pro manual page 31](https://www.manualslib.com/manual/3679532/Yuimer-Kpt-Pro.html?page=31) — Room, Hall, Swell, Spring and Shimmer reverb controls.
- [KPT Pro manual page 32](https://www.manualslib.com/manual/3679532/Yuimer-Kpt-Pro.html?page=32) — remaining reverb and external expression controls.
- [TankPedal official downloads](https://tankpedal.com/pages/download) — KPT Pro firmware package label and M-EFCS PC/mobile stated support list.
- [YUIMER KPT Pro product listing](https://www.theoriginalera.com/products/kpt-pro-multi-effects-pedal-upgraded-version-from-yuimer-factory-previously-known-as-tank-g-and-tank-b) — corroborates 50 guitar / 10 bass preamp and cabinet slot counts. This is a reseller, not a firmware reference.

### Broader multi-effects references

- [Fractal Audio Axe-Fx III — official product and block inventory](https://www.fractalaudio.com/iii)
- [Fractal Audio Axe-Fx III Owner's Manual](https://www.fractalaudio.com/downloads/manuals/axe-fx-3/Axe-Fx-III-Owners-Manual.pdf)
- [Neural DSP Quad Cortex User Manual 4.1.1](https://neuraldsp.com/manual/quad-cortex)
- [Line 6 Helix 3.80 Owner's Manual](https://line6.com/data/6/0a00051afda2673ccc1cc8e68/application/pdf/Helix%203.80%20Owner%27s%20Manual%20-%20English%20.pdf)
- [Kemper Profiler overview](https://www.kemper-amps.com/profiler/overview)
- [Kemper effects overview](https://www.kemper-amps.com/effects)
