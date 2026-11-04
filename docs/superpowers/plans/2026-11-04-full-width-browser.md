# Full-width browser implementation plan

> **For agentic workers:** Use superpowers:executing-plans. Erik has authorised implementation in this chat. Project rules prohibit parallel agents and require one focused iPad release.

**Goal:** Give Songs, Suggestions and Prep list the full browser width while preserving the fixed performance dock and explicit A/B loading.

**Architecture:** Retain the browser inside the existing work area. Replace the permanent columns with three retained list views and optional source/detail drawers. Keep selection separate from drawer visibility and recommendation reference selection.

**Tech stack:** SwiftUI, iOS 17, existing Swift geometry checks and `tools/ipad_test.py`.

**Spec:** Erik approved the portrait browsing design in this chat on 4 November 2026. This first increment covers full-width songs/recommendations and accessible performance controls. The wider pane programme remains in `../specs/2026-11-03-touch-fidelity-design.md`.

## Global constraints

- Use `feature/project-integration`. Preserve build 87's deck divider, dock, full-height crossfader and R34/R35/R37 audio analysis.
- Keep on-device library filtering and the existing recommendation ranking.
- Keep the existing directional load gesture. Provide separate Load A and Load B buttons.
- Use targets of at least 44 points, labelled drawer controls and Reduce Motion support.
- Run focused browser/dock checks and one incremental signed iPad build. Do not run Mac packaging, simulator builds or broad regression sweeps.
- Erik performs physical touch and audio acceptance. Do not infer acceptance from compilation.

## Review focus

1. Selecting a suggestion must not change its reference or reopen details.
2. Switching lists must preserve the previous list's scroll position.
3. Drawers must cover only browser content and reject input to covered content.
4. Playlist/source filters must not restrict recommendation candidates or Prep list resolution.
5. Loading, search, narrow widths and larger text must retain usable controls.

## Task 1: Full-width browsing increment (R39)

**Files:** `BrowserView.swift` composes the lists, source/detail drawers and selected-song shelf. `BrowserLayoutState.swift` owns list navigation, drawer exclusivity and pure browser geometry. `tools/check_browser_layout.swift` and `tools/check_browser_layout.py` check those production sources alongside the fixed dock. Update `BrowserLayoutStateTests.swift`, the request ledger and numbered build record.

**Interfaces:** Add `BrowserListTab` and `BrowserLayoutState.selectTab(_:)`. Add `BrowserContentGeometry(width:height:)` with a full-width `listArea` and bounded `drawerWidth`. Existing source/detail drag methods remain available. Opening one drawer closes the other. List selection does not call `showDetail()`.

- [x] Add and run focused checks for full-width geometry, drawer exclusivity and switching lists without a drawer opening. Retain the initial failure.
- [x] Implement the layout state and UI. Retain each list while switching tabs. Pin the reference entry on opening Suggestions and expose an explicit update action. Rank against `projection.allEntries` and keep selection out of the refresh key.
- [x] Run the browser checks and existing dock-anchor checks. Review search, playlist navigation, full-library queue resolution, hidden-view input and unchanged performance files.
- [ ] Commit source, checks and R39 status. Build/install one signed increment with `tools/ipad_test.py`, record its source and outcome, push and hand back. Stop device actions after launch.

## Deferred scope

Do not implement new musical gestures, recommendation algorithms, settings redesign, arbitrary pane rearrangement or automatic loading. Further refinements follow Erik's result on this build.
