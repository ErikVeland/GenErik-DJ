# Mixer and Z1 development implementation

Current build and acceptance: [project status](../docs/coordination/README.md). Historical measurements apply only to their recorded source.

The shared renderer now supplies stereo master and headphone buses. Touch, recording and the optional Mac Z1 input use the same mixer state.

## Controls and routing

The vertical crossfader places A at the top and B at the bottom. Each deck's mixer button opens volume, Low/Mid/High EQ and an XY filter. X selects low-pass or high-pass cutoff, and Y controls resonance. Reset EQ resets the three bands and preserves volume. Filter Y is retained through bypass and saved in the workspace across restart.

The audio-output button selects stereo master or Master 1–2 / Headphones 3–4. Four-channel mode checks the device channel count before starting. It does not intentionally downmix headphones into a stereo output. Headphone cue buttons, cue/master blend and headphone gain use the separate bus. Recordings always capture the master bus. Routing changes require recording to be stopped and pause playback.

Physical four-channel output and disconnect behaviour remain unverified. SDK compilation and offline bus tests are not a hardware test.

## DSP choices that remain unmatched

Mixer changes use 5 ms linear ramps. Both decks have unity crossfader gain at the centre. Channel volume is 0–1, pre-gain is 0–4, EQ band gain is 0–2, and the existing default master gain is 0.5. A complementary one-pole split at 250 Hz and 2.5 kHz supplies the three EQ bands. Neutral EQ is transparent.

The filter uses a trapezoidal state-variable design, an exponential cutoff curve and resonance Q from approximately 0.707 to 8. Its mixer parameters ramp over 5 ms. The mathematical derivation is described in [Andrew Simper’s state-variable filter paper](https://cytomic.com/files/dsp/SvfLinearTrapOptimised2.pdf). These are independent DSP choices. They are not NI's recovered EQ/filter sound. An abrupt-coefficient biquad prototype produced excessive transients in the rapid-sweep test and was replaced. Rapid gestures still need listening and original-reference comparison.

## Original Z1 on Mac

Choose **Connect original Z1** in the audio panel to enable the Mac HID transport. Startup, tests and preview rendering never connect automatically. The transport matches vendor 0x17cc, product 0x1210. The implementation does not target Z1 Mk2.

Input decoding covers gain, EQ, filter X, channel volumes, cue blend, crossfader, cue buttons and MODE+CUE transport. It reads the crossfader endpoint calibration from feature report D2. Without valid calibration, crossfader input stays gated. Button actions use rising edges and ignore buttons already held when the connection starts. Output reports contain cue/filter feedback and meter segments.

The byte layout comes from the [Mixxx Z1 protocol notes](https://github.com/mixxxdj/mixxx/wiki/Native-Instruments-Traktor-Kontrol-Z1/c5c948a256d9da65cecc5591bf3fda4fedab48b2) and the offsets in the [maintained controller implementation](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-Kontrol-Z1-scripts.js). The implementation is independently written. Control behaviour follows the locally retained NI Z1 manual's Traktor DJ section, rather than Mixxx's different button assignments.

The later continuation adds per-deck FX mode, selected-slot X/ON control and mode feedback on Mac. Native iPad Z1 accessory communication, physical-device testing, pickup/takeover, exact analogue curves and meter thresholds remain unfinished. The Mac implementation has been compiled and tested with synthetic packets only. No hardware was contacted during this development pass.

## iPad Z1 transport investigation — 30 October 2026

The authorised 2017 iPad Pro uses an A10X processor. Apple's iPadOS DriverKit documentation requires an M-series iPad, so a DriverKit implementation cannot be the transport for this test device. Apple's External Accessory framework requires a supported accessory protocol supplied by its manufacturer; the protocol and access for this specific Z1 have not yet been established. NI documents MIDI-mode use on a computer, but that does not establish that the original Z1 presents a usable MIDI endpoint on this iPad. The Mac IOHID implementation cannot simply be enabled on iPadOS.

The next physical diagnostic must distinguish the Z1 audio route, any exposed Core MIDI endpoint, and any supported External Accessory protocol on the actual A10X iPad. Preserve the current diagnostic while another device test is in progress. A controller test build must also exercise faders, EQ, filter/FX, cue, output routing and disconnect behaviour under playback. An audio route alone does not demonstrate controller input or feedback. The connection method and matching protocol remain unverified; no Z1 iPad support is claimed.

References: [Apple DriverKit on iPadOS](https://developer.apple.com/documentation/driverkit/creating-drivers-for-ipados), [Apple External Accessory](https://developer.apple.com/documentation/externalaccessory/), and [Native Instruments Z1 MIDI use on a computer](https://support.native-instruments.com/support/solutions/articles/69000879502-how-to-use-the-traktor-kontrol-z1-as-a-midi-controller-and-audio-interface-with-ableton-live).

## Shared FX pad continuation — 28 October 2026

The drawer now has three selector tabs sharing one XY pad. This follows the firsthand [2013 review](https://www.musicradar.com/news/tech/review-native-instruments-traktor-dj-for-ipad-571281), which describes this layout and the eight launch effects. A contact keeps its original slot until all fingers release or the surface cancels. Selection changes during a hold become visible after release. Closing the drawer cancels an active contact; an already released locked effect remains retained. Vertical movement preserves X changes made by hardware.

`shared-effect-pad-tests.log` passes thirteen contact, selector, hardware-axis, effect-tail and recording checks. `shared-effect-pad-preview.png` is an offscreen layout check. It does not verify native touch handling or exact original geometry. Original one-at-a-time touch activation versus later hardware multi-slot behaviour remains a target-version comparison gap.

Native Instruments' [effect reference](https://docs.native-instruments.com/online-guides/traktor-pro-manual/en/effect-reference.html) provides useful desktop-family behaviour: Digital LoFi reduces resolution and sample rate; Iceverb filters its reverb output outside the feedback loop; Reverse Grain captures and reverses grains; Transpose Stretch combines captured-loop stretching and pitch shifting. These descriptions do not establish mobile XY mappings or algorithm equivalence.

The following base-effect batch adds Digital LoFi and dedicated high-pass/low-pass filters, bringing the implemented catalog to eight. C exports the supported count, and the Swift catalog supplies the selector names and runtime-validation rotation. Existing effect IDs remain unchanged. The new processing uses per-slot sample-hold/quantizer state and the existing stable state-variable filter. It adds no audio buffers, callback allocations or locks. X controls bit/rate reduction or cutoff, and Y remains wet mix. These curves are independent choices and are not claimed as recovered mobile mappings. Spectral attenuation, stereo polarity, reduction, sweeps and catalog/renderer agreement pass in `eight-base-effects-tests.log`. Iceverb, Transpose Stretch and Reverse Grain now have development implementations. Their current reverb/grain architecture is documented in Effects.md; original sound fidelity remains open.

The direct H5 screenshot also shows FX and mixer windows sharing the deck width, separate Equalizer/Filter tabs, vertical Low/Mid/High/Volume faders and different FX/EQ colours. The UI now follows those arrangements. The panel choice stays in the deck view while its drawer is hidden. Inactive FX tabs select before opening a menu; selecting another tab dismisses an old menu without letting its contact act on the new selection. Existing centre reset and temporary second-finger fader handling now support the vertical axis. Endpoint input accounts for the drawn thumb margins. Fifteen focused checks pass in `reference-panel-contact-tests.log`. Exact target-build geometry, selection defaults, hidden-lock bypass and physical multitouch comparisons remain open.
