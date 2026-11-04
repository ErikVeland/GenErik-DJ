# Stable performance dock — R02/R30/R31

The dock reserves 96 points at the right of the workspace. Each deck has four 80-by-48-point targets, with explicit A/B labels. The crossfader stays at the window centre. The library and extra panels resize beside the dock. Existing audio and transport actions remain unchanged.

## Evidence

- `red.log`: initial failure because the new geometry types were absent.
- `initial-geometry-compile.log`: retained Swift initialisation error, corrected by capturing a local height before assigning all stored fields.
- `resize-coupling-mutation.log`: a temporary wrong dependency on resized deck height produces 224 failing assertions. Production source was not mutated.
- `green.log`: 1,322 assertions pass against production geometry.
- `result.json`: source hashes, R34 preservation, scope and deployment result.

## Execution decisions

Pre-flight: Task 1 produces dock/work-area geometry. Later panel tasks consume that work area without changing the dock anchors. The interfaces agree with the design. Only Task 1 is authorised in this iteration.

Task 0: Erik explicitly authorised the dock change and one installation. Build 77 is the retained R34 baseline; its automatic launch was unconfirmed. That acceptance remains open.

Task 1: Ruling: the documentation worktree has unrelated R36 edits. Implement in a separate worktree and reuse the existing build cache, archive and lock through local links. This avoids an extra cache and excludes uncommitted R36 changes. Cost if wrong: a source-path change may require additional incremental compilation.

Task 1: Ruling: viewports shorter than 576 points retain upright controls in a scrollable dock. Supported iPad/Duo sizes have a fixed, non-scrolling dock. R28 still owns the one-deck phone layout. Cost if wrong: a constrained window needs scrolling to reach all controls.

Final review: self-review under the project rule against parallel agents. Geometry, state ownership, cancellation, existing action routing and R34 hashes were checked. Physical touch, sound and layout acceptance remain with Erik.

## Device check

Open and close the library. Drag its divider through several positions. Hide and show each extra-controls panel. Confirm both four-button stacks and the centre crossfader stay in place. Check FX, EQ, loop, Play/Stop and the fader on both decks. Listen for clean audio. Confirm the R34 neutral vocal labels remain on the same recording.

## Build 78 handover

Source `e6cf72aa2` passed incremental device compilation and signature checks in 52.4 seconds. Build 78 installed on the 10.5-inch test iPad. Automatic launch timed out after 10 seconds. Launch is unconfirmed. No further device actions were taken. Erik opens the app manually and performs the device check above. The pre-build request note is superseded by this result. Acceptance remains pending.
