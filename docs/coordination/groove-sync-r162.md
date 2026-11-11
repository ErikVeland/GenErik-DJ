# R162: human groove with bar alignment

## Purpose

A DJ should be able to play a record with human timing and blend it into a steady modern remix. Solo playback should retain the original timing variation. Starting the second deck should engage automatic alignment at bar boundaries.

Erik selected second-deck start as the trigger on 11 November 2026. Loading another track does not engage the lock. Headphone preparation counts once the second deck starts. The interval choices mean 4, 8, 16 or 32 beats. Start with four beats, or one bar in the supported four-beat metre.

This changes adaptive Sync playback. It does not change analysis results, accepted preparation or the saved Sync choice.

The [musical mixing strategy](humanising-dj-mixing.md) covers headroom, phase, frequency space, warmth, DJ control and shared research. Broader assistance remains proposed.

## Value during a set

Consider a drifting Norwegian disco remix followed by a steady modern remix. During solo playback, continuous beat correction can change the original push and pull. During a long blend, unchecked tempo drift requires repeated nudges and can separate the two rhythms.

R162 gives those two situations different behaviour. The solo record keeps a constant playback rate. During the blend, the engine steers towards shared bar boundaries. It does not make every internal beat a separate correction target.

The intended advantages are:

- Retain expressive timing while one record plays.
- Reduce repeated nudges during long blends between drifting and steady recordings.
- Keep the first beats of bars together while allowing the source rhythm to move between them.
- Engage through the existing Play action, without another button or a fader threshold.
- Preserve personal grids and the explicit Sync-off choice.
- Show unresolved alignment when the timing evidence or correction limits cannot support the blend.

These are product goals. Automated timing checks cannot establish retained feel or acceptable time-stretch sound. Erik must compare the same recordings on the A10X and original Z1.

## Behaviour

| State | Playback behaviour | Alignment display |
| --- | --- | --- |
| Solo groove | Keep a constant playback rate. Allow the grid to move against the master clock. | Saved Sync stays on. Solo drift is intentional. |
| Acquiring | Start bounded speed corrections after another synced, gridded deck starts or queues. | Do not claim a completed bar lock yet. |
| Bar aligned | Continue correction towards each shared bar boundary. Retain the source rhythm between boundaries. | Show alignment without requiring every internal beat to match. |
| Limited | Keep correction within its rate and speed limits. Never jump the cursor to force alignment. | Show that alignment remains unresolved. |
| Explicit Sync off | Use the existing free-transport behaviour. | Sync stays off until the DJ enables it. |

A stopped or unanalysed second deck does not supply a reliable timing partner. Missing grids remain unresolved on the affected deck. Fixed-grid playback retains its existing behaviour.

The feature needs a usable accepted adaptive map. A static or incorrect map cannot identify drifting bar positions. R162 does not promote an unreviewed analysis candidate into trusted preparation.

When the other deck stops, hold the current playback rate for solo playback. This avoids an automatic rate step at the end of a blend. Deliberate master-tempo changes still apply. A later blend can acquire bar alignment again.

If the DJ has not selected a master tempo, the first track establishes it from its nominal grid BPM. A faster or slower internal beat must not change the initial playback speed.

## Start and clock ownership

Preserve the source position of the audible deck. Never seek that deck to the master clock when the blend starts.

If it is the only clock-dependent performance source, establish the shared bar phase from its current accepted grid. Keep the chosen master BPM. Prepare the incoming source through the existing queued-start path. Retain its deadlines and readiness checks.

For an ordinary adaptive start, retain the existing beat-aligned source position and schedule its bar phase against the shared clock. A pickup can start before the next shared downbeat. Its following bar boundary meets that downbeat. Do not cut the pickup or move a cue to the nearest bar. Loading still displays file position zero. The producer and renderer retain the same prepared source position.

An active Pattern Player or Loop Recorder also depends on the clock. Do not change their clock phase to accommodate a solo deck. In that case, acquire against the existing clock through bounded correction and report any unresolved alignment.

## Bar controller

Keep the original accepted adaptive map and its downbeat offset. Predict the source position at the next shared bar boundary using the nominal playback rate. Choose the closest future source bar to that prediction. If that bar is already behind the source, use the following clock boundary. This avoids pairing a nearly completed source bar with a much later clock bar. Retain the resulting pairing while the audio advances.

At each output sample, calculate the source distance and clock time remaining until the paired boundaries. Their ratio gives the speed needed to reach the target. Limit the target speed and slew the applied speed towards it. Advance the source through ordinary rendering. Do not assign a new source position as a correction.

When the clock reaches the target, measure the source error. Then advance both targets by four beats. Do not select a different source bar because the previous correction finished slightly late. This prevents an error from becoming a whole-bar shift.

The first numerical defaults are:

| Control | Initial value | Reason |
| --- | --- | --- |
| Target interval | 4 beats | Start with bar alignment and a small verification scope. |
| Additional speed correction | At most 6% above or below the nominal tempo ratio | Bound automatic acceleration and deceleration. |
| Automatic rate slew | At most 6 percentage points of the nominal ratio per second | Spread changes instead of stepping the rate. |
| Completed-boundary tolerance | 0.01 beat, with at least two source frames | Match the existing alignment scale while allowing numerical rounding. |

These are engineering defaults pending musical acceptance. They do not guarantee inaudible correction. User-requested tempo changes are separate from automatic correction. Existing keylock and streaming limits remain authoritative.

If the requested correction exceeds a limit, retain bounded playback and report unresolved alignment. Do not widen limits, extend launch deadlines or seek the audible source to obtain a pass.

## Integration

Keep controller state in the native transport. The audio callback must not allocate, read files, acquire locks or run analysis. Resolve map targets at bar boundaries and after explicit transport changes.

Publish solo, acquiring, aligned and limited states through the existing snapshot. The interface must not treat intended internal-beat movement as lost Sync. Older saved snapshots must remain readable.

Reserve the controller speed envelope during streamed-source preparation. Keep existing memory, source-readiness and keylock limits. Use the applied rate for Flux continuation. Preserve scratch, brake, seek and loop contracts. Rebuild the bar target after a deliberate source discontinuity.

Held gestures, braking and active loops retain their existing transport behaviour in this first version. Resume the groove policy after those states end. Do not reinterpret a deliberate performance effect as an automatic timing error.

Solo clock-dependent effects should follow the playing record. During a blend, effects follow the shared clock. Recording captures the existing renderer output. R162 does not rewrite source files or export permanently quantised edits.

## Delivery and verification

1. Add focused native checks that exercise actual source positions and rendered samples.
2. Verify solo drift with another deck loaded and paused.
3. Start the second deck and check both start orders.
4. Verify shared bar boundaries and retained movement between those boundaries.
5. Check automatic speed and slew limits on an unsuitable grid.
6. Stop either deck and verify continuous source position and rate.
7. Verify explicit Sync off, missing grids, pause, seek, loops and gesture release.
8. Compare streamed and resident playback, including readiness and starvation counters.
9. Run the impacted Swift transport and preparation checks.
10. Build one signed iPad candidate through the existing test helper when signing and device access permit it.
11. Hand back the build number and leave the device for Erik.

Bind each result to its source. Retain failed attempts. Build and host success do not establish A10X acceptance.

For musical acceptance, use the same drifting remix and steady modern remix. Include a long blend, breakdowns, sparse percussion and ordinary fixed-tempo controls. Check retained groove, bar alignment, stretching sound, headphone preparation, touch and heat. A wrong bar reference must remain an analysis issue rather than a target for stronger correction.

## Scope and status

The first version uses one-bar alignment with existing controls. It does not add the later 8/16/32-beat selector or change automatic adaptive-grid adoption. Broader controller qualification, four decks and live stems remain separate work.

The one-bar implementation is now merged into main. Its original isolated review is [PR 4](https://github.com/ErikVeland/GenErik-DJ/pull/4). The historical worktree and evidence remain preserved. R170 now verifies bass assistance against this timing controller. No new consolidated device build is established.

## Recorded verification

- All 36 focused Swift tests passed: 32 core tests and four interface tests. These cover Sync intent, bar acquisition, pickups, old snapshots, source preparation and gesture restoration.
- All 13 native scenarios passed. They cover both deck orders, output block sizes of 1/127/512 frames, natural first-track speed, solo drift, internal timing, bar alignment, rate limits and return to solo.
- The clock-ownership case retains an active Pattern Player's master phase and acquires the correct later source bar.
- Streamed and resident output matched sample for sample with Keylock enabled over 358,400 output frames. The check used synthetic tones and required a non-silent signal. Source-read misses and missing output frames both remained zero.
- The existing adaptive-map check passed bounds, interpolation, deck isolation and concurrent publication/snapshot checks.
- Whitespace checks passed. The plan has no prose sentence above 25 words. The repository check still reports 12 existing links to missing historical captures or calibration files. None belongs to R162.

The [result record](../testing/groove-sync-r162-results.json) binds these results to source hashes. Raw logs, the native source manifest and binary hash remain under ignored `TestBuilds/r162/`. Failed and intermediate attempts remain retained.

An older streamed-restoration test expected drift after a quantised jump. A probe against the original fixed-grid source confirmed that the jump already aligns. Its expectation now follows that existing contract. The adaptive scratch fixture uses a nominal tempo within the new correction envelope. It checks immediate gesture restoration and later bar alignment separately.

The iPad build helper stopped before compilation because local signing configuration is missing. No signing identity for the recorded project team is available on this Mac. The A10X is absent from the connected-device inventory. No build number was allocated, and no device app changed.

The tests establish synthetic timing and source-continuity behaviour. They do not establish musical feel, time-stretch quality, real-remix accuracy, A10X deadlines, sustained touch performance or thermal readiness. The 6% defaults need Erik's listening review. The normal one-change signed-iPad loop resumes when signing and device access are available.
