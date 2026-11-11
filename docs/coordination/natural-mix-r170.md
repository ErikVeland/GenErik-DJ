# R170: natural mix assistance

## Intent and assumptions

Preserve bass weight and clear attacks during a two-deck blend. Keep Erik in control of the transition.
Treat beat alignment, groove, bass cancellation, masking and clipping as separate problems.
Do not promise that arbitrary tracks can blend without conflict.

Erik authorised a documented plan and implementation on 12 November 2026.
This checkout is `/Users/erikveland/GenErik-DJ`. The documented `/Users/veland/GenErik DJ` folder is absent on this Mac.
Use the current checkout serially. Preserve existing commits and historical evidence, including the unrelated `TestBuilds/r169/` folder.

## Delivery plan

1. Add bounded bass measurements after deck EQ, effects, volume and crossfader gain.
2. Verify that measurement alone produces identical output samples.
3. Add an optional bass handover with a saved, default-off mode.
4. Verify bass recovery, stereo preservation, cue isolation, bypass and control transitions with native fixtures.
5. Compile the affected Swift boundary and run focused preference and interface checks.
6. Commit the focused change on a feature branch and merge into main before a device build.
7. Use `tools/ipad_test.py` for the signed iPad iteration when the environment supports it.
8. Hand back for Erik's A10X listening and touch checks. Keep physical acceptance open until he confirms it.

## First release contract

Playback Settings has three choices: Off, Measure only, and Bass handover.
Existing preference files open with Off. No permanent performance control is added.

- Off stops the added analysis after any active cut has returned smoothly to unity.
- Measure only reads the two deck contributions. It does not change audio samples.
- Bass handover keeps one bass foundation and reduces the other smoothly, by no more than 12 dB at DC.
- The crossfader selects the leader outside a centre deadband. At the centre, retain the leader to prevent repeated swaps.
- On initial overlap at the centre, favour the earlier playing deck.
- Require measurable bass from both decks. Reduce intervention as the quieter contribution falls.
- Keep separate left and right filter states. Apply the same reduction to both channels.
- Analyse the stereo channels separately before summing their energies. Do not cancel wide stereo content through a mono analysis fold.
- Use a complementary 120 Hz low-pass component for the cut. Upper frequencies remain part of the original signal.
- Keep the headphone cue contribution unchanged. Master-in-headphones and recordings follow the assisted master.
- Do not move source positions, change Sync, rewrite EQ values, boost cancellation or flip polarity.
- Bypass automatic handover for four decks, live deck inputs and non-standard crossfader assignments.
- Publish measurements outside the sample loop. Add no allocation, file access, logging, locks or lookahead delay to rendering.

Measurements describe A/B bass interaction before assistance. They are not instrument identification or a guarantee of perceived quality.
The cancellation estimate compares combined band energy with the sum of separate band energies.
Positive correlation can increase level. Negative correlation can reduce it. Neither value alone establishes a musical fault.

The first candidate uses a 50 ms energy response, 100 ms qualification period and 10 ms decision interval.
Cuts ramp over 120 ms. Restoration takes up to 250 ms.
The low-band power must exceed 3% of each deck's full-band power.
Overlapping channel power must exceed 1% of the stronger deck's bass power.
These thresholds are initial engineering choices. They require Erik's listening review.
The correction follows the current fader gains, so a closed fader cannot leak a filter tail.

## Success criteria

- Off and Measure only match the original renderer sample for sample.
- Opposed bass fixtures retain more output energy with handover than without it.
- Solo playback, crossfader endpoints and unrelated stereo channels remain unaffected after the release ramp.
- Bright material without measurable bass does not trigger handover.
- Gain changes remain bounded and finite through mode changes, silence, reloads and rapid crossfader movement.
- Headphone cue samples match the unassisted renderer. Recorded master samples include assistance.
- Older preferences retain their values and open with assistance off. The selected mode survives a save and reload.
- Host checks bind to exact source and retain failed attempts. Host timings do not establish A10X readiness.

## Separate work and later experiments

[R162](persistent-sync.md#r162-human-groove-and-bar-alignment) remains the transport work for natural groove and bar alignment.
R170 must not replace its grid authority or introduce another timing controller.

Dynamic phase rotation, fractional delays, predictive analysis and automatic peak protection need separate measured experiments.
Do not enable these techniques through this release. Changing full-track timing to maximise bass can damage rhythmic alignment.
Do not add a lookahead limiter or live stem separation to this change.

Dynamic phase optimisation and sidechain EQ are established techniques, but their use does not prove device suitability.
See [Sound Radix Pi](https://www.soundradix.com/products/pi/),
[iZotope's sidechain EQ examples](https://www.izotope.com/community/blog/5-ways-to-use-dynamic-eq-with-sidechain),
and [FabFilter's phase and latency explanation](https://www.fabfilter.com/help/pro-q/using/processingmode).

## A10X acceptance

1. Compare Off, Measure only and Bass handover at matched listening levels.
2. Use bass-heavy dance music, human-played disco, sparse passages and wide stereo recordings.
3. Check a long blend, both deck start orders and both crossfader directions.
4. Adjust the bass EQ manually. Check that assistance respects the chosen balance.
5. Listen for bass dips, pumping, dull attacks and audible changes when the leader swaps.
6. Check headphones, the recorded mix and mono playback separately.
7. Check simultaneous touches, loading, output continuity and heat on the A10X with the original Z1.

Stop acceptance at the first reproducible audio or touch defect.
A smooth leader swap can still pass through destructive interference. This release does not guarantee cancellation-free transitions.

## Status

The first release is implemented. Playback Settings contains the saved mode and a conditional bass readout.
No phase rotation, automatic timing correction or limiter is included in R170.

### Local verification

- All 51 native cases passed at 44.1, 48 and 96 kHz through the existing transport-check script.
- Four focused Swift tests passed. The preference round-trip test includes all three modes.
- The settings test reopens the saved mode and verifies that it changes the native renderer.
- Measure only matches unassisted master and cue samples exactly.
- Opposed bass gains output energy. Reinforcing bass retains a controlled foundation.
- Stereo polarity, cue isolation, recording, silence gates, endpoints, reloads, pauses and block sizes passed.
- Rapid mode changes and concurrent meter reads remained finite and bounded.
- New-file formatting and diff whitespace checks passed.
- The repository check retains 12 existing historical link failures. None is in the changed documents.

Commands:

```sh
bash Replica/Scripts/check-transport-transitions-native.sh --bass-assist-only
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
PATH="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH" \
bash Replica/Scripts/check.sh --filter bassAssistance
```

Evidence is retained under `TestBuilds/r170-natural-mix/`, including failed and incomplete attempts.
The first native attempt found a test constant typo. Later fixtures exposed a fader-tail issue and weak-signal qualification.
The implementation now applies fader gain to the correction and requires sufficient overlapping bass power.
The reload fixture initially tried to replace a playing deck. It now pauses that deck before loading, as the transport requires.

The shell initially selected Command Line Tools. That toolchain lacks Swift Testing and crashed during interface compilation.
The installed Xcode 27.2 toolchain compiled the affected targets and passed the focused Swift tests.
The native check retains an existing integer-conversion warning in `TDJLoopRecorder.h`.

### Delivery boundary

The feature branch still requires its final merge before the iPad helper runs.
This Mac reports no valid signing identity. The iPad signing configuration is absent.
CoreDevice device discovery timed out. No signed build, installation or A10X acceptance is established.
Do not enable assistance by default or describe this candidate as gig-ready.
