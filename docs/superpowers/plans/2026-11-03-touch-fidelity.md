# TDJ1 Gesture Fidelity and Unified Touch Space Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement one accepted task at a time. Project rules prohibit parallel agents and broad routine validation. Stop after each device hand-back.

**Goal:** Close TDJ1 gesture gaps and provide directly resizable panels around stable essential controls.

**Architecture:** Retain the existing SwiftUI deck views and native contact surfaces. Separate a fixed performance dock from the resizable work area. Share panel extent rules, then migrate contact mapping without changing audio scheduling.

**Tech Stack:** Swift 6, SwiftUI, UIKit contact tracking, the existing native audio renderer, focused Swift checks, and `tools/ipad_test.py`.

**Spec:** [TDJ1 gestures and a unified touch space](../specs/2026-11-03-touch-fidelity-design.md). The spatial defaults are proposals. This plan does not start implementation or deployment.

## Test-release progress — 4 November 2026

The fixed dock shipped to the test iPad in build 78. Library gestures followed in build 80. Build 82 added retained held-contact mapping and the full-height crossfader. Build 85 now adds the Task 4 FX, EQ and extra-control panel implementation, with 2,977 focused assertions and signing passed. It installed and launched on the 10.5-inch test iPad. Erik explicitly requested the three panel migrations in one test release. Builds 83 and 84 remain saved without installation after review corrections.

Build 87 adds Task 2’s direct A/B divider and separate session size memory per orientation. All 3,665 focused assertions and signing passed. It installed and launched on the test iPad. Physical acceptance remains pending. See `../../testing/checks/R30/2026-11-04-deck-divider/`.

Physical touch, hide/lock semantics, audio acceptance and the original TDJ1 comparisons remain open. Browser side columns and later tasks are not complete. See `../../testing/checks/R30/2026-11-04-performance-panels/`.

## Global constraints

- Prioritise TDJ1 gesture fidelity.
- Keep the right-hand FX/EQ/loop/Play stacks and centre crossfader stable.
- Essential targets are at least 44 by 44 points.
- Preserve clean continuous audio and immediate performance control.
- Keep the existing one-change, one-build, install, hand-back loop. Erik is the acceptance tester.
- iPad is the only active target. Keep iOS 17 and the existing A10X minimum-device requirement.
- Use `feature/project-integration`. Preserve unrelated work, old builds and failed evidence.
- Do not run routine Mac packaging, simulator builds, full-suite sweeps or parallel agents.
- Keep the test-app identity `org.generikdj.replica.audiocheck` and the single existing device-build cache.
- Keep gestures on the current renderer command path. Do not add layout work to the audio callback.
- Keep local-library-only scope, manual preparation authority and existing audio/performance limits.

## Review focus

1. A stationary performance finger must not move a musical value when another finger resizes a panel. Task 3 owns this check.
2. Repeated add-track requests must open usable browsing without disturbing playback or the dock. Task 2 owns this check.
3. A hidden or partially revealed panel must not receive musical touches through invisible controls. Tasks 2–4 own this check.
4. Cancellation, track replacement and rotation must not leave a held audition or transfer an old contact. Tasks 3 and 5 own this check.
5. Portrait, reduced motion and constrained windows must not create dock overlap or undersized targets. Tasks 1 and 8 own this check.

## File responsibilities

| File | Responsibility |
| --- | --- |
| `Replica/Sources/TDJInterface/ReplicaView.swift` | Compose retained decks, work area, dock and panel views. Keep transport actions unchanged. |
| `Replica/Sources/TDJInterface/AdaptivePerformanceLayout.swift` | Calculate work-area bounds and panel limits. Remove resize-driven rail reorientation. |
| New `Replica/Sources/TDJInterface/PerformanceDock.swift` | Render the two fixed stacks and centre crossfader with explicit deck ownership. |
| New `Replica/Sources/TDJInterface/TouchPanelState.swift` | Pure extent, remembered size, release and cancellation rules. No audio or persistence work. |
| New `Replica/Sources/TDJInterface/TouchPanel.swift` | Retained presentation, boundary lane and reveal tab using the shared state. |
| `BrowserView.swift`, `BrowserLayoutState.swift`, `PaneDismissGesture.swift` in the same source directory | Integrate library and browser columns with shared extent rules. |
| `TouchSurface.swift`, `TouchSurfaceInputGate.swift`, `WaveformTouch.swift` in the same source directory | Stable contact coordinates, explicit cancellation and ownership. |
| `MixerView.swift`, `EffectsView.swift`, `PerformanceControls.swift` in the same source directory | Fit musical controls inside resizable panels without reducing targets. |
| `ArrangementViews.swift` in the same source directory | Present performance editing in the work area. |
| New `tools/check_touch_layout.py` and `tools/check_touch_layout.swift` | Compile pure production geometry/state sources and assert observable invariants without a package-wide build. |
| `Replica/Tests/TDJInterfaceTests/` | Extend existing ownership, gesture, loader, FX and fader tests. |
| New `docs/testing/checks/R02/touch-fidelity/` | Index source-bound cases and evidence across numbered builds. |

Register any new Swift files in the iPad project only if its existing source inclusion requires it. Do not split unrelated files or move DSP code.

## Common iteration procedure

Every implementation task below follows this sequence. A task with several independent corrections takes several releases.

- [ ] Recheck branch, working changes, latest installed build and current request ownership. Preserve R34 and any newer work.
- [ ] Add the named focused failing check for the behaviour being changed. Retain its output.
- [ ] Implement only that correction and run its focused check. Retain any toolchain blocker as blocked, not passed.
- [ ] Commit source, checks and the request-ledger update together.
- [ ] From the coordinated integration checkout with the existing cache, prepare the numbered signed app:

```sh
python3 tools/ipad_test.py build --notes "R02/R30: describe this single touch correction"
```

- [ ] When Erik hands over for installation, deploy that saved build using `python3 tools/ipad_test.py deploy --number N`, with N replaced by its recorded number.
- [ ] Hand back immediately. Stop device actions and implementation. Record Erik's feedback against N before the next correction.
- [ ] Push source and build records to `origin/feature/project-integration`. Do not report acceptance before Erik confirms it.

Do not build from this documentation worktree or create another device cache. Reconcile implementation into the coordinated checkout before building. Do not automatically deploy historical build 75 over a newer R34 candidate.

Latest handover reviewed during planning: build 77 installed on the 10.5-inch test iPad, with automatic launch timed out and acceptance pending. The latest confirmed Duo installation remains build 70. Confirm launch and device identity separately. A result on one device does not accept the other.

The new layout checker uses the host compiler for pure geometry assertions only. It does not package the Mac app. Existing Swift Testing cases can use a narrow `bash Replica/Scripts/check.sh --filter '<case-name>'` run when the toolchain works. If still blocked, retain that status and use the signed device build plus the named physical case. Do not substitute syntax checks for interaction acceptance or repair the whole toolchain within a touch task.

## Task 0: Establish the accepted baseline and evidence map

**Requests:** R02/R20/R30/R34. **Dependencies:** none.

**Files:** `docs/coordination/requests.md`, the actual `docs/testing/builds/N.json`, new `docs/testing/checks/R02/touch-fidelity/index.json`, and the existing gesture contract.

**Produces:** An exact baseline build/source and an evidence row for each G01–G28 family. Each row records status, reference version/source, replica build/source, initial state, case description, result and outstanding question. Unknown results remain unknown.

- [ ] Start with the R34 build 77 handover on the 10.5-inch test iPad. Confirm Erik can open it and obtain his result. Recheck newer records before acting. Establish Duo's baseline separately without discarding the R34 fix. Record each choice and rollback build.
- [ ] Have Erik check loading A/B, Play/Stop, Sync, crossfader, EQ/filter and library access on that baseline. Record blocking failures before panel work.
- [ ] Use retained original evidence and Erik's next demonstrations to fill the highest-priority gesture cases. Never promote an unmeasured development threshold to reference behaviour.
- [ ] Record the design's proposed dock and shared panel rules as QoL changes. Retain a separate TDJ1-equivalence status.

**Exit:** We know which app is being judged, which original behaviours are established, and which corrections come first. Documentation does not require a new app build.

## Task 1: Keep essential controls fixed through layout changes

**Requests:** R02/R30/R31. **Dependencies:** Task 0.

**Files:** Create `PerformanceDock.swift`, `tools/check_touch_layout.py`, `tools/check_touch_layout.swift`. Modify `ReplicaView.swift` and `AdaptivePerformanceLayout.swift`.

**Interfaces:** `PerformanceDockGeometry.init(width: Double, height: Double)` produces `aButtons: [CGRect]`, `bButtons: [CGRect]`, `crossfader: CGRect`, `workArea: CGRect` and `fits: Bool`. Keep this geometry Foundation-only for the standalone check. `PerformanceDock(model: ReplicaModel)` renders existing action views in these bounds.

- [ ] Add `--group anchors` checks: target sizes at least 44 points, no dock intersections, every target within bounds when `fits`, and unchanged dock centres within one point for every panel extent at the same window size.
- [ ] Include actual Duo and iPad viewport sizes from baseline evidence, portrait/landscape, and a smaller-than-supported case that returns `fits == false` without invalid frames.
- [ ] Extract the dock using the existing buttons and crossfader actions. Remove the library-driven horizontal rail branch. Keep layout changes confined to `workArea`.
- [ ] Expose only the existing private view helpers required by that extraction within the interface module. Do not duplicate transport logic in the new dock.
- [ ] Run `python3 tools/check_touch_layout.py --group anchors`. Follow the common iteration procedure.

**Erik's check:** Open/close and resize the library while both decks play. Confirm fixed stacks, centre fader, correct deck association, no overlap and usable targets.

**Exit:** Essential controls remain stable. If the proposed dock breaks deck association, correct it before Task 2.

## Task 2: Make library reveal and resize the shared panel behaviour

**Requests:** R02/R04/R25/R30/R32. **Dependencies:** Task 1.

**Files:** Create `TouchPanelState.swift`, `TouchPanel.swift`. Modify `ReplicaView.swift`, `BrowserView.swift`, `BrowserLayoutState.swift`, `PaneDismissGesture.swift` and the layout checker.

**Interfaces:** `TouchPanelState.init(minimumExtent: Double, initialExtent: Double)` exposes read-only `extent` and `rememberedExtent`; mutations are `beginDrag()`, `updateDrag(translation: Double, maximumExtent: Double)`, `endDrag(velocity: Double, maximumExtent: Double)`, `cancelDrag()`, and `setPresented(_: Bool, maximumExtent: Double)`. Translation and velocity are positive towards opening. `TouchPanel` accepts a binding to this state, its edge, available extent and content. Use the spec's release values rather than separate browser constants.

- [ ] Add `--group panels` checks: one-to-one travel, usable arbitrary-size retention, half-minimum release, flick qualification, bounds, cancellation, non-finite input and remembered reopening.
- [ ] Add the library's dedicated 44-point grab lane and reveal tab. Use the existing retained browser. Every explicit add-track event requests maximum library space within `workArea`.
- [ ] In a separate release, add the A/B work-region divider using the same boundary input rules. Keep both labelled compact strips reachable and retain dock anchors when either waveform gains space. Extend `--group anchors` for both divider extremes.
- [ ] Migrate browser side columns in separate focused releases. Keep song selection, search, queue and A/B loader ownership unchanged. Do not let a horizontal column gesture claim a loader drag or vertical list scroll.
- [ ] Extend `LoadSliderGestureTests.swift` and `BrowserLayoutStateTests.swift` for repeated opening, both loader directions and cancellation. Run the focused checks and common iteration procedure for each release.

**Erik's check:** Pull out the library, leave it at three intermediate sizes, hide/reopen it, and tap A/B add-track repeatedly. Give each waveform more space in turn. Use both loader ends and both drag directions while the other deck plays.

**Exit:** The library and browser columns provide the accepted model for later panels. No sliver opening or lost selection remains on the accepted build.

## Task 3: Preserve musical contacts through panel resizing

**Requests:** R01/R02/R03. **Dependencies:** Task 2. Complete before shipping resizable musical panels.

**Files:** Modify `TouchSurface.swift`, `TouchSurfaceInputGate.swift`, `WaveformTouch.swift`, `PanelInputGateTests.swift`, `FaderLiveInputTests.swift`, `EffectPadGestureTests.swift` and `GestureWorkflowTests.swift`. Create `TouchContactGeometryTests.swift`.

**Interfaces:** Add `TouchSurfaceGeometryPolicy` with `.cancelOnResize` and `.retainContactSpace`. Keep `.cancelOnResize` as the default. The retained policy captures the initial window-space rectangle for each contact session. The waveform session captures its initial span for non-zoom musical operations. No renderer interface changes.

- [ ] Add `touchContactStationaryDuringResize`: unchanged window-space finger position produces unchanged mapped position and no new seek, rate or parameter jump after a size/origin change.
- [ ] Add `touchContactOwnerDoesNotTransfer`: crossing a grab lane cannot change the owning action. A third contact and partial lift cannot invent a replacement action.
- [ ] Add `touchContactCancellationAfterRotationAndReload`: affected sessions cancel once, restore temporary state and reject stale release events. Another deck's contacts remain active.
- [ ] Opt in waveform, then EQ, filter and FX in separate releases. Retain the same view and contact identities. Keep explicit cancellation for interruption and actual removal.
- [ ] Run narrow ownership checks when available and follow the common iteration procedure. Preserve existing generation and Flux behaviour.

**Erik's check:** Hold a filter or waveform gesture while resizing with another finger. Repeat across decks and release fingers in both orders. Then rotate or interrupt and confirm clean cancellation.

**Exit:** A layout change does not create a musical command or lose an unrelated held control. Unverified surfaces retain their old cancellation policy.

## Task 4: Apply direct reveal and resize to FX, EQ and extra controls

**Requests:** R02/R13/R22/R30/R31. **Dependencies:** Task 3.

**Files:** Modify `ReplicaView.swift`, `TouchPanel.swift`, `MixerView.swift`, `EffectsView.swift`, `PerformanceControls.swift`, `AdaptivePerformanceLayout.swift`, the layout checker and `RetainedMixerPaneTests.swift`.

**Consumes:** Task 2's extent model and Task 3's retained contact policy. Keep per-deck and per-panel state separate. Existing rail buttons toggle the same state used by grab edges.

- [ ] Add `--group panel-pairs` checks for two simultaneous panels: no dock/panel overlap, stable opposite panel, clamped combined widths, minimum usable controls and a reachable reveal tab at every compact state.
- [ ] Replace fixed half-width FX and EQ presentation, one panel per release. Use the proposed 200-point expanded minimum and 128-point XY minimum. Confirm geometry on device before retaining those values.
- [ ] Expand EQ/Filter and FX selector targets to at least 44 points. Keep three FX slots, their shared XY pad, original selection gestures and independent parameter state.
- [ ] Migrate extra controls to the same extent rules. Keep loop length, cues, Freeze and Flux there. Keep the four essential rail actions in the dock.
- [ ] Test hidden-panel hit rejection, temporary EQ restoration, latched-state retention and closing during contact. Complete G21–G24 original comparisons before declaring hide/lock semantics matched.
- [ ] Follow the common iteration procedure for each panel. Do not combine all panel migrations in one test build.

**Erik's check:** Resize each panel, use FX and EQ together, hide a locked effect, reopen it, and operate the other deck. Confirm adequate waveform visibility and unchanged dock positions.

**Exit:** Every primary performance panel follows the same direct manipulation rules. Sound-state differences from TDJ1 remain explicit until resolved.

## Task 5: Close waveform, browser, grid and loop fidelity first

**Requests:** R02/R03/R04/R25. **Dependencies:** Baseline evidence starts at Task 0. Run corrections throughout Tasks 1–4 when Erik exposes a blocking mismatch. Final combined acceptance follows Task 4.

**Files:** `WaveformTouch.swift`, `ReplicaView.swift` stripe/tempo components, `LoadSliderGestureSession.swift`, `TempoWheelGestureSession.swift`, their existing focused tests, and the gesture contract/evidence index.

- [ ] G01–G04: compare browser entry, selection versus loading, directional load, navigation and artwork suggestions. Correct the highest-impact mismatch first.
- [ ] G05–G09: compare tempo wheel, overview inspection, pinch anchor, beat-tap jump, paused seek, playing scrub and release. Keep preview and audible seek distinct.
- [ ] G10–G12: compare grid entry, phase drag, downbeat, BPM correction, pinch and magnetic snapping. Do not treat view zoom as BPM editing.
- [ ] G13–G17: compare cue actions, saved loops, two-finger create/move/pinch/dismiss, file boundaries and both contact orders.
- [ ] For each mismatch, add the exact reference sequence and failing regression before changing that policy. Test playing, paused or queued states where applicable. Change one policy per release.
- [ ] Record unresolved original thresholds instead of tuning unrelated values. Retain original and replica clips or Erik's explicit comparison notes with their build identities.

**Erik's check:** Perform the same short musical action on the reference and candidate where available. Judge acceptance, sound, timing, feedback and release, including a second simultaneous control.

**Exit:** Each required G01–G17 row has accepted evidence or an explicit remaining reference blocker. No row closes from an implementation label alone.

## Task 6: Close Freeze, Flux, SuperSlicer, mixer and FX fidelity

**Requests:** R02/R03/R08/R22. **Dependencies:** Task 5's relevant navigation/loop behaviour and Task 4's panel integration.

**Files:** `WaveformTouch.swift`, `PerformanceControls.swift`, `MixerView.swift`, `EffectsView.swift`, `TouchFader.swift`, `EffectPadGestureSession.swift`, existing focused tests, and native transport/effects files only for a reproduced audible mismatch.

- [ ] G18–G20: compare Freeze scale, slices, loop slicing, Flux return, Scratch direction/sensitivity, Brake stop, Reverse, pitch and family changes. Resolve overlap and release order explicitly.
- [ ] G21–G25: compare independent EQ contacts/reset, filter X/Y, locks, hidden-drawer sound, FX selection/curves/tails, crossfader and headphone control.
- [ ] Add a focused native audio check when a correction changes timing, rate, loop wrap or DSP. Retain existing callback and control deadlines. Do not rewrite an effect merely to make its label match.
- [ ] Separate visual/gesture matches from sound-response matches. Mark provisional SuperSlicer and DSP curves honestly until compared and accepted.
- [ ] Use one correction per common iteration. Include other-deck playback in Erik's listening check.

**Exit:** G18–G25 close only on the combined candidate's accepted musical behaviour. Missing original sound evidence remains a blocker to a 1:1 claim.

## Task 7: Keep performance preparation inside the work area

**Requests:** R02/R09/R13/R30. **Dependencies:** Tasks 2–4. Lower priority than blocking gesture corrections.

**Files:** `ArrangementViews.swift`, `ReplicaView.swift`, `TouchPanelState.swift`, `GestureWorkflowTests.swift`. Keep `KeyImportReviewView.swift` and system pickers outside this change.

**Interfaces:** The section editor uses Task 2's docked panel state and captures its track ID when opened. A changed load identity closes/cancels that edit instead of applying it to the next track.

- [ ] Add checks for open/close retaining zoom, preview return, section selection and manual preparation. Add a changed-track case that refuses a stale apply.
- [ ] Replace the section-editor sheet with an in-space editor and the same grab/reveal controls. Keep both transports and crossfader reachable.
- [ ] Check grid/cue transitions and help entry without adding another independent navigation system. Retain system presentation for imports, sharing and infrequent configuration.
- [ ] Follow the common iteration procedure.

**Erik's check:** Edit a section while the other deck plays. Resize or dismiss the editor, return to the waveform, and confirm preparation and musical position.

**Exit:** Performance preparation preserves the same spatial context and stable controls.

## Task 8: Accept the combined touch instrument

**Requests:** R01/R02/R13/R20/R27/R30. **Dependencies:** Tasks 1–7 and explicit dispositions for their remaining blockers.

**Files:** Gesture evidence index/contract, request ledger, source-bound build record and `docs/coordination/release-gates.md`.

- [ ] Close G28 with both-deck overlap, reversed release order, third contacts, out-of-bounds movement, rotation, interruption and relaunch. Check reduced motion and both orientations on intended devices.
- [ ] Close touch portions of G27: recording/settings/help access must preserve performance context. Recording integrity retains its separate acceptance work.
- [ ] Run a short source-bound scenario combining two decks, Sync, loop/slice/Flux, FX, panel resizing, browsing/analysis and recording. Include physical listening. Record any faults instead of inheriting an older stress pass.
- [ ] Keep physical G26 controller/touch coexistence open until the actual Z1 connection is available. Unknown hardware behaviour cannot block unrelated touch fixes or count as passed.
- [ ] Record separate verdicts for unified touch-space acceptance, TDJ1 gesture fidelity and remaining sound/analysis/hardware gates. Take a new exact-source snapshot if any app code changes afterwards.

**Exit:** Erik can perform the accepted gestures and panel movements without searching for moved controls, unintended transport or audible faults. Any required unresolved row prevents a complete gesture-fidelity claim.

## Remaining gap order after touch acceptance

| Priority | Requests | Deliverable and completion boundary |
| --- | --- | --- |
| Immediate exception | R01/R03/R06 | Any dropout, unintended transport, recording loss or lost preparation interrupts the schedule and receives the next focused fix. |
| Next | R05/R07/R09/R16/R26/R29/R33/R34 | Real-library BPM/key/downbeat/energy and semantic-label evaluation, including long intros and false choruses. Retain manual authority. Paired real-track results close analysis claims. |
| Next | R06/R08/R10/R11/R15 | Real-music sound, recovery, key control and recording/finalisation/transfer acceptance. Compare actual app output and retain source identity. |
| Next | R14/R23, G26 | Original Z1 connection, mapping, touch coexistence, feedback and audio route on actual hardware. Broader models require their own evidence. |
| Then | R12/R16 | Representative Mixed In Key/Traktor adapters, preview/conflicts, backups and governed write-back. Verify actual target formats before external writes. |
| Separate scoped work | R17/R23/R28 | Define stems, remaining controller contracts and the one-deck phone layout. Do not treat generic MIDI or a compressed two-deck UI as completion. Streaming stays deferred. |
| Before a complete-project claim | R19 | Restore/review private candidates and record meaningful dispositions. Hash comparison alone does not close missed-work coverage. |
| Final | R20 | Complete the user-directed audio/release gates and Erik's rehearsal on the intended setup. Retain an accepted rollback build. |

## Completion checklist

- [ ] Essential controls stay stable through all accepted panel operations.
- [ ] All primary panels reveal, hide, resize and restore through one consistent touch model.
- [ ] Musical contacts retain ownership through geometry changes and cancel safely on interruption.
- [ ] Required G01–G28 cases have accepted evidence or explicit, visible outstanding blockers.
- [ ] QoL differences are labelled separately from TDJ1 matches.
- [ ] Each reported fix has Erik's result against a numbered build.
- [ ] Analysis, DSP, hardware, historical reconciliation and rehearsal retain their separate completion boundaries.
