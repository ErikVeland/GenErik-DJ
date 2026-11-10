# Remaining product work

The [request ledger](requests.md) controls scope. Follow the [iPad feedback loop](../testing/README.md).

## First test on the A10X

Use the current signed iPad build, the original Z1 and headphones. Use two decks in Mix mode. Record the build number and the first reproducible fault.

1. Play a prepared track on deck A. Sweep the Z1 crossfader to both ends and back. Listen for unexpected silence or crackle. Confirm that playback continues without a restart.
2. Keep deck A playing. Load a long, uncached and unanalysed track on deck B. Check that the master stays clean, the waveform stays steady and Play responds promptly.
3. During the load, check headphone cueing and repeat the crossfader sweep. Check that each touch still responds.
4. Fix the first reproducible blocker. Repeat the same check on the next build.

See the [original live-test feedback](live-test-144.md) and [long-track load checks](live-waveform-continuity.md).

## Next on the A10X

1. Compare waveform drag and throw, preview-strip navigation, beat jumps, two-finger loop sizing and pane resizing with TDJ1. Check simultaneous controls and the load swipe in two-deck mode. Check grid alignment after release while Sync is on.
2. Resume R50 on the current signed source. Use the original Z1 and real library for a sustained two-deck rehearsal. Include FX, recording, browsing, repeated loads and output recovery.
3. Record listening, touch, frame motion and thermal results against that build. Apply the [existing acceptance gates](release-gates.md). The two-deck baseline holds when Erik confirms clean audio and responsive touch through the combined workload.

## Deferred work

- Defer four-deck work and live stems, including stem slideout follow-up, until the two-deck baseline holds. Keep four decks opt-in. Test four decks and live stems separately when work resumes.
- Keep cached stem preparation on the later roadmap. Measure processing time, memory and audio continuity before promoting it.
- Defer broader controller coverage, Pattern Player, hardware screens, Duo layouts and cosmetic polish. Keep the original Z1 audio and controls in scope.
- Prioritise prompt loading and grid fixes that matter in a mix. Reuse trusted preparation. Leave deeper analysis, new models and richer section labels for idle preparation or later work.
- Keep native key-import verification, external preparation write-back and review of preserved private candidates behind the live-set work.

Erik deferred subscription streaming. Keep the library local-only. A hardware bridge is allowed where required. External format writes and unsupported device protocols require verified mappings.
