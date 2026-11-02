# Recovery loop implementation plan

> Use superpowers:executing-plans for inline implementation.

**Goal:** Keep music playing when a DJ misses a track ending. Replay last drop is the default.

**Architecture:** Prepare recovery positions away from the audio callback. Arm native renderer commands with generation checks. The renderer owns the final-beat wrap and the 8/16-bar crossfade. Use the current recommendation ranking and normal track-loading path.

**Tech Stack:** Swift, SwiftUI, C audio renderer, Swift Testing.

**Spec:** Approved chat description, 2 November 2026.

## Global constraints
- Modes: Off, Replay last drop (default), Auto-mix next track.
- Replay starts at the boundary after the final musical beat, never earlier.
- Auto-mix starts 8 or 16 bars before that boundary, initially 16.
- Prepare audio before arming. Auto-mix falls back to replay if unavailable.
- Manual transport and transition controls cancel pending recovery.
- Show recovery mode and countdown. Preserve existing local edits.

## Review focus
- No usable grid or waveform: report unavailable rather than invent timing.
- Manual actions during preparation: invalidate pending work and retain DJ control.
- Changed load generations: reject stale recovery.
- Streamed target coverage: reserve the drop and incoming audio before arming.
- Tempo changes: retain musical boundaries rather than wall-clock deadlines.

## Tasks
- [ ] Test settings migration, waveform endpoint/drop selection, and 8/16-bar lead positions. Implement RecoverySettings and RecoveryPlan, with a manual drop override.
- [ ] Test native final-boundary replay, mid-buffer triggers, tempo changes, cancellation, stale generations, and auto-mix. Implement bounded native commands and snapshot state.
- [ ] Integrate preparation, ranking, loading, cancellation, saved settings and countdown UI. Test controller/model integration.
- [ ] Run the Swift test suite and review the complete diff. Record limits in the playback notes.

Ruling: The managed worktree request did not return. Work on the existing feature branch and preserve unrelated local edits. Do not merge, push, or operate devices.
