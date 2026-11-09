# R93: persistent Sync and grid transport

Erik requested this change on 9 November 2026 after the first A10X/Z1 live test.
He selected Sync as the next fix after build 150. R89 physical acceptance is not yet reported.

## Required behaviour

Sync is a saved user choice. Only an explicit Sync-off action may disable it.
The beat grid governs normal transport. A held scratch, brake or sub-beat loop is a temporary performance state.
When that state ends, playback returns to the master beat phase.

- Loading retains the saved Sync choice, including when a grid is not yet available.
- A missing grid shows unresolved alignment. It must not silently turn Sync off or claim reliable alignment.
- A normal stop pauses immediately, clears temporary touch rate and pending jumps, and parks on the nearest beat.
- Restart and cue entry use the grid. Existing queued-start deadlines remain unchanged.
- A stopped seek uses the nearest in-bounds beat. A playing seek matches the master phase at execution.
- Lifting a finger with Sync enabled ends waveform coasting and restores grid alignment immediately.
- Cancellation also releases the contact and restores alignment.
- Vinyl stop retains Sync. Resume restores alignment or uses the normal queued start after the stop completes.
- Loop entry retains the selected loop boundaries and aligns the playback position inside them.
- Leaving a loop restores beat phase. Sub-beat loops retain their deliberate effect while active.
- An explicit Sync-off choice retains free transport and waveform coasting across reloads.

The first solo start can begin at file position zero. Its grid establishes the master phase.
A stopped deck rests on its grid. Restart aligns it to the running clock.

## Implementation

The native audio engine resolves phase against its current clock before accepting a source transition.
Quantised jumps and loops prepare the phase required at their scheduled execution beat.
Loop boundaries remain separate from the prepared playback position inside the loop.

The streamed-source planner prepares the same aligned positions. Existing source admission, memory limits,
keylock limits and transition ramps remain in use. A tempo change during braking still reserves the captured audio speed.
No polling-based UI correction was added.

Waveform dragging no longer sends Sync-off. A cancelled coasting task checks cancellation again after its wait,
so it cannot move a newly caught waveform. The Sync button explicitly toggles the saved choice.
Automatic recovery cannot enable Sync on a deck that the user disabled.

## Verification

Focused tests cover retained intent, grid arrival, immediate and quantised seeks, cues, scratch release,
cancellation, stop during a held waveform, vinyl resume, fixed and adaptive grids, and loop entry and exit.
Streamed tests compare actual output with the prepared-audio reference and check continuity counters.
Explicit Sync-off behaviour and the R89 load/playhead checks remain in scope.

The original transport tests reproduced twenty failed expectations across twelve cases before the change.
Additional tests reproduced coasting after finger release and half-beat loop misalignment.
The initial affected-test run also found a cancellation race and old expectations that required Sync-off after braking.
One streamed-brake preparation expired during the concurrent host run. Its isolated retry passed.
The final streamed loop check required a fractional-frame tolerance. The cold-jump check now expects the aligned destination.
A separate failing check exposed insufficient preparation speed during a brake tempo change.
Stop-grid checks reproduced three failures before the final stop change. The R89 reload fixture now plays beyond the first beat before pausing.
Forty-two focused host tests passed across fifty-nine cases on the final app source.
The final follow-up passed the revised reload check and the isolated streamed-brake check.
All attempts remain under `TestBuilds/r93/`. Source identity belongs in the numbered build record.

## A10X handover checks

1. Play two prepared tracks with Sync enabled.
2. Stop and restart either deck. Listen for beat alignment.
3. Seek, recall a cue, drag the waveform and lift your finger. Listen for immediate grid alignment.
4. Catch and cancel a drag. Check that no old movement continues.
5. Enter and leave a loop. Check beat alignment and the selected loop boundaries.
6. Use vinyl stop and resume, if enabled. Check that Sync stays on.
7. Disable Sync explicitly. Check that free control remains available after a reload.
8. Check uninterrupted audio and responsive controls with the Z1 connected.

Host checks and installation do not establish A10X acceptance or gig readiness.
R90 crossfader silence, R91 preview-strip behaviour and R92 long-track flicker remain separate blockers.
