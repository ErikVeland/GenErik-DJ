# R167 musical cues in the performance view

Erik requested visual, rhythmic hints that remain clear during a live set.
The cues use prepared song structure and the existing playback snapshot.
They do not start analysis, change audio, alter Sync or add a timer.

## Visual language

- Keep each cue beside its deck and on its waveform time axis.
- Use a thin section rail and a quiet header tint for the current song structure.
- Emphasise one upcoming boundary. Its symbol identifies a build, drop, breakdown, vocal or ending.
- Show saved regions as ribbons. Their start and end stay at their actual source positions.
- Use saved mix-in and mix-out regions as suggestions. Do not infer a safe transition from a section name.
- Keep short names and distances beside symbols. Preserve custom section names.
- Increase marker contrast near arrival. Do not flash the performance surface.
- Show four small remaining-beat marks only during the next cue's final four beats.
- Keep the ending cue quiet in the existing time row. Do not duplicate its beat marks.
- Preserve the existing section editor, waveform gestures, pane geometry and touch targets.

## Timing and uncertainty

Use actual beat positions from the accepted timing map. Preserve vocal pickups between grid beats.
The existing timing model uses four beats per bar.
Playback rate changes the seconds estimate. It does not change the number of musical beats.
Without reliable timing, show seconds and omit beat marks.

Suggested boundaries have dashed lines and approximate distances.
Accepted landmarks and manual section boundaries take precedence over estimates at the same position.
Do not claim that automatically detected labels or boundaries are confirmed.

A cue beyond a repeating loop shows After loop. It has no arrival beat marks.
Slip retains the audible source position for nearby cues and the continuing position for the ending.
The ending row marks Slip explicitly. Reverse playback suppresses approaching cues and shows Reverse.
Tail and Ended remain distinct. Reduced Motion hides the beat marks.

## Verification and delivery

Focused checks cover pickups, adaptive timing, rate changes, missing grids, loop holds and Slip.
They also cover reverse, pause, active ribbons, dismissed landmarks, endings and accepted preparation.
The normal package test command encountered existing grid-downbeat setter errors in other source files.
The focused production-core checks use a separate XCTest entry point to avoid that interface build blocker.
Keep the command, source identity, results and failed attempts under `TestBuilds/r167/`.

All 11 cue tests passed against the current production core objects.
The cue views compiled and rendered in a static component fixture at 320 and 680 points.
The fixture uses the production cue views and timing policy with a small read-only observable model.
Its waveform is synthetic. These component images do not establish full-app or iPad behaviour.
Visual inspection checked labels, ribbons, loop holds and boundary placement at both widths.

The numbered iPad installer stopped because this checkout has no signing-team or device configuration.
No signed iPad build or installation is claimed. Readability and performance acceptance remain open.

## A10X acceptance

1. Load a prepared track and identify the next change after a brief glance.
2. Check a vocal pickup, a saved region and a drum ending against the audio.
3. Hold a loop before the next cue, then release it.
4. Check an unresolved grid and an estimated boundary.
5. Move the crossfader while the other hand controls the waveform.
6. Check both orientations and a partly open browser.
7. Confirm that sound stays clean and touch stays immediate.

Erik confirms whether the cues help without drawing attention away from the performance.
