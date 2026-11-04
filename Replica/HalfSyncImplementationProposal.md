# Immediate half-sync restoration implementation

Current build and acceptance: [project status](../docs/coordination/README.md). Historical measurements apply only to their recorded source.

Implemented on 29 October 2026. The performer confirmed an immediate correction using the smallest jump to the nearest beat, with backward movement allowed. The [focused validation](../docs/history.md#local-validation) passes 27 Swift checks and the native zero-allocation render check. The current full-regression and physical-acceptance status is recorded in Status.md; this focused result is historical evidence for the immediate-restoration implementation.

NI’s S4 manual, app section5.2.3, documents matched tempo with displaced phase after scratching or out-of-time cues. Sync appears red. Pressing it restores alignment and green. The user confirmed the precise timing and smallest-jump policy. The original colour threshold and interaction edges still need comparison.

## Transport and preparation

`TDJ_SYNC_RESTORE` is an explicit command. It reads the current render clock and native source grid when accepted, selects the closest admissible beat-phase coordinate and commits immediately. It does not wait for a beat or bar. File and active-loop bounds remain hard limits. Equal half-beat ties move forward.

The command validates complete streamed-source coverage before changing audible state. Preparation uses the snapshot’s native grid, and the consumer recomputes the target at acceptance. Stale or cold commands leave playback unchanged. Successful source corrections release obsolete source claims through the existing discontinuity path.

Restoration keeps tempo matching enabled. It preserves the master clock, other deck, generation, pending cue and Flux continuing position. The existing Keylock reset and transport transition handle the source discontinuity. No new render-time allocation, I/O or waiting is added.

The boolean tempo toggle remains separate. The UI routes red Sync to restoration. Green Sync disables tempo matching. Enabling Sync during playback also uses the explicit restoration path.

## Snapshot and feedback

Native snapshots publish source sample rate, grid anchor and downbeat with the existing source position and master clock. Swift computes display phase outside the callback. Optional grid metadata preserves decoding of older saved snapshots.

The existing0.01-beat display threshold remains unchanged. It is not claimed as a measured original threshold.

## Preserved edge limits

A held waveform gesture retains ownership. Restoration reports a plain instruction to finish it before using Sync. A source interval with no matching beat position remains unchanged. Exact original behaviour for these cases and half-beat ties still needs comparison.

The focused checks cover immediate forward/backward correction, unchanged clock and other-deck samples, native grid edits, tempo matching, loop/Flux preservation, stale actions, ineligible intervals, held contacts, old snapshot decoding, red/green button behaviour and exact streamed/resident sample equality. The first failed test attempt is retained. Its meter-window and oversized-test-buffer setup errors were corrected without relaxing audio comparisons.
