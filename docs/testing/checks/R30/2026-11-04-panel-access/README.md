# Performance access correction — R02/R30

Date: 4 November 2026, Australia/Brisbane.

Build 94 removed visible access to the action tray and left FX/EQ opening at their 200-point minimum. Compact deck allocations could also leave too little vertical space. An open section editor could cover the performance panes.

Each loaded deck now has a Controls button. The full header has a labelled button, and the compact overview strip reserves a complete 44-point target. Empty decks keep the tray closed. The quiet resize grips remain unchanged. Large panel handles also appears in Settings → Features, without requiring access to the tray.

Untouched FX/EQ defaults use half the available panel budget. A 1004-point deck with quiet grips opens each pane at 428 points. Untouched defaults grow with the window. Explicit drag choices remain remembered per panel and orientation. Opening Controls redistributes visible space without closing the held FX/EQ input gates. A constrained panel grab starts at its drawn width, so the boundary follows the finger immediately.

Opening a performance pane makes enough vertical room where possible. Both compact deck strips remain reachable. Selecting performance controls hides the section editor but keeps its draft. The dock, full-height fader, native contact mapping, R34 analysis/preparation, launch repair and restored iPad/Duo browser remain unchanged.

## Verification

All 4,590 focused assertions pass. The 21 new access checks cover loaded/empty entry policy, default panel size, Controls with paired FX/EQ, held input gates, constrained drag/cancel, custom size memory, window expansion and requested deck height. Existing layout, editor and browser checks also pass. A temporary compiled mutation restores the old minimum-size defaults and produces the failures retained in `minimum-default-mutation.log`. Production source was not mutated.

`red.log` retains the missing-entry/API baseline. `first-check.log`, `green.log` and `browser-preservation.log` retain the passing focused results. Final review was self-review under the project rule against parallel agents.

## Erik’s check

1. Load a track and tap Controls in the header.
2. Open Controls from the compact strip while browsing.
3. Open FX and EQ and check their default size.
4. Resize one, close it and reopen it.
5. Open Controls with both panes active and hold a musical gesture.
6. Open the section editor, then switch back to performance controls.
7. Check the main Settings → Features handle option.
8. Confirm fixed dock/fader positions and clean audio.

The final candidate also retains the current R38 analysis and R43 beat-grid diagnosis from integration. Their source and existing evidence are preserved. This change does not alter analysis, preparation validation or beat-grid policy.
