# Resizable FX, EQ and extra controls — R02/R30/R31

Date: 4 November 2026, Australia/Brisbane.

Each deck now uses the library's panel state for FX, EQ and extra controls. Dedicated grab strips reveal, hide and resize the panels. A slow release retains a usable width. A deliberate flick restores the remembered width or closes. Cancel restores the width before the drag. Each deck, panel and orientation keeps its own session memory.

FX, the waveform and EQ occupy separate bounded regions. Their grab strips do not sit on the musical surfaces. The extra-controls strip sits at its inner boundary, so it follows the resizing finger. Resizing one side cannot consume the opposite panel's width. Opening a second side may collapse extras to make room. In very narrow layouts, controls retain a compact reveal lane instead of becoming smaller targets. Opening a panel from the compact library layout restores performance space and retains the library size.

The content views remain mounted. Presentation intent and visible extent are separate, so shrinking a panel does not close its performance input gate. Held waveform, EQ, filter and FX contacts retain the build 82 mapping. Explicit close still uses the existing cancellation path. The dock and full-height fader render identically.

## Verification

`green.log` retains 1,330 dock, 179 library, 36 held-contact and 1,424 performance-panel assertions with zero failures. The last group compiles the actual panel presentation class and input gates. It checks remembered sizes, orientation changes, hidden and clipped content, opposite-pane stability, bounded pairs, grab-lane separation, held mapping, zero-width previews and explicit-close isolation.

`red.log` and `gates-red.log` retain the missing-interface baselines. `first-check.log` and `diagnostic.log` retain the initial extra-budget defect and the empty-rectangle intersection diagnosis. The budget now caps after subtracting the side panels. Empty clipped regions have no active area. Temporary compiled mutations produce one failure for an ignored opposite-pane budget and five failures when resizing disables FX input. Production source was not mutated.

R34/R35 analysis/preparation and the original recording fixture are unchanged. The R82 contact mapping, viewport cancellation, waveform span and fader inset sources are unchanged. Dock button anchors, full-gap fader geometry and native audio/transport code are unchanged.

## Execution decisions

Pre-flight: Task 4 consumes the shared extent state from Task 2 and captured contacts from Task 3. The presentation class owns per-deck panel states and the existing input gates. Width changes do not issue audio commands.

Task 4: Ruling: combine the three panel migrations into the single test release Erik explicitly requested. Cost if wrong: physical feedback must identify which panel needs correction.

Task 4: Ruling: keep a 200-point minimum side content width, 144-point minimum extras width and separate 44-point grab lanes. Optional extras collapse first when a newly opened side needs room. Very narrow layouts keep their reveal lanes. Cost if wrong: Erik may prefer a different balance of waveform and controls.

Task 4: Ruling: horizontal handle capacity can change during a drag as room is made. It clamps continuously rather than cancelling itself. A new presentation command or viewport configuration still invalidates the old resize gesture. Cost if wrong: simultaneous layout gestures need a focused follow-up.

Task 4: Ruling: panel size memory remains session-local, as for the library. Cost if wrong: relaunch restores usable defaults instead of saved widths.

Final review: self-review under the project rule against parallel agents. The review covered view identity, layout budgets, the optional tempo-fader width, input admission, gate transitions, FX menu geometry and protected source. Original-app matching and physical listening remain open.

## Erik's device check

Show, resize, hide and reopen FX, EQ and MORE on both decks. Check separate portrait and landscape sizes. Open FX and EQ together and close either one. Hold a waveform, EQ, filter or FX gesture while resizing another panel or the library. Check effect selection, lock/release, the extra-controls scroll and all transport buttons. Confirm that the dock and full-height crossfader stay fixed and audio remains clean.
