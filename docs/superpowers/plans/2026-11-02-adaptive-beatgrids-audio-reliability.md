# Adaptive Beatgrids and Audio Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional adaptive beat timing that improves musical navigation while preserving existing playback, preparation and touch behavior, and gate release on audio reliability evidence.

**Architecture:** Keep ordinary playback independent of beatgrid analysis. Store a bounded, validated timing map with track preparation, preserve current fixed grids as the default and fallback, and publish immutable map data through the existing producer-to-render command path. Background analysis creates candidates; user edits and explicit preparation actions accept them. Existing gestures continue to call the same beat-based actions, which resolve through the selected map.

**Tech Stack:** Swift, SwiftUI, AVFoundation analysis, C transport engine, XCTest, existing runtime audio checks and on-device listening.

**Spec:** User-provided feature notes at `/Users/veland/.codex/attachments/3cfe4e8e-d56e-4820-bf0b-ccfc76ce4d2a/Pasted text.txt`, especially “Adaptive beatgrids: the main upgrade,” “Automatic analysis,” and “The interface rule I would enforce.” Project constraints are documented in `Replica/Responsiveness.md`, `Replica/TransportTransitions.md`, `Replica/Status.md`, and `Replica/Sources/TDJCore/BeatGrid.swift`.

## Global Constraints

- Combined audio output and immediate performance controls remain the highest-priority work.
- The render callback must not wait for analysis, collection work, persistence, locks, file I/O, or allocation.
- Keep current fixed-grid behavior and serialized workspace compatibility for existing tracks.
- Analysis must not change audio playback or active transport state.
- Do not replace accepted manual corrections or imported TDJ preparation during routine reanalysis.
- A result that completes during playback must not move the active beat phase, loop, cue, playback rate, or source position.
- Preserve the two-deck layout and current tap, swipe, pinch, scratch, and loop gesture meanings.
- Do not widen existing audio/control limits to make new work pass.
- The minimum hardware target is the saved 10.5-inch iPad Pro (2017/A10X); device qualification requires a user-agreed testing window.

## Review Focus

- Existing fixed-grid tracks and old serialized snapshots retain identical behavior after decoding and saving. Test legacy fixtures and equality of retained preparation.
- Variable-tempo and swung music do not create unstable beat movement from individual offbeat transients. Test synthetic drift, swing, late snare, tempo ramps, and abrupt tempo sections.
- Invalid, sparse, non-monotonic, extreme, or oversized timing maps fail closed to the retained fixed grid. Test validation and fallback at model and transport boundaries.
- Background analysis completion during active playback cannot alter the current transport. Test active loop, cue, Flux, Sync, paused deck, and load-generation changes.
- Two decks using different timing maps do not cross-contaminate Sync or queued actions. Test paired maps and deck replacement.

## Implementation Sequence

This plan covers the first feature milestone only. Beat Jump, key shifting, FX combinations, preparation sync, suggestions, stems, MIDI Learn, phrase guidance, streaming sources, and other roadmap items need separate plans after the timing interfaces stabilize.

### Task 1: Establish the audio reliability gate

**Files:**
- Modify: `Replica/Status.md`
- Modify: `Replica/Responsiveness.md`
- Inspect: `Replica/Validation/audio-priority-2026-10-29.md`
- Inspect: latest retained reports referenced from `Replica/Status.md`
- Create: `Replica/Validation/AdaptiveBeatgridReliabilityBaseline-2026-11-02-01/README.md`

**Interfaces:**
- Consumes: existing callback metrics, runtime-check launchers, and retained Mac/iPad reports.
- Produces: an explicit baseline manifest listing source identity, workload, output route, duration, callback faults, control deadlines, recording frame counts, and device/listening acceptance still open.

- [ ] **Step 1: Record the pre-change source and evidence set.** Capture the current shared source identity and link the latest successful and failed reliability runs. Keep each run's hardware and workload scope explicit.
- [ ] **Step 2: Define pass/fail criteria without changing thresholds.** Use the existing callback and control limits. Require zero callback failures, invalid samples, recording drops, and unexplained control deadline misses in the qualified workload. Record any engine stop or output-route change as a failed/invalidated run, not as a clean pass.
- [ ] **Step 3: Add a baseline manifest.** Create `README.md` with the source identity, commands or harness used, evidence file paths, and remaining physical listening/device acceptance. Do not run checks on the user's iPad without a new testing window.
- [ ] **Step 4: Review the gate against current evidence.** Confirm that host tests, sustained runtime, physical-device timing, and listening acceptance remain separate claims.

**Done when:** The baseline can distinguish a code regression from an interrupted output route, and does not describe Mac-only evidence as target-device acceptance.

### Task 2: Add a bounded adaptive grid model with legacy decoding

**Files:**
- Create: `Replica/Sources/TDJCore/BeatGridMap.swift`
- Modify: `Replica/Sources/TDJCore/Models.swift`
- Modify: `Replica/Sources/TDJCore/Workspace.swift`
- Test: `Replica/Tests/TDJCoreTests/BeatGridMapTests.swift`
- Test: `Replica/Tests/TDJCoreTests/WorkspaceTests.swift`

**Interfaces:**
- Produces: `BeatGridAnchor(beat: Double, frame: Double)` and `BeatGridMap(anchors: [BeatGridAnchor], sampleRate: Double, downbeatOffset: Int)`.
- Produces: `BeatGridMap.frame(atBeat:)`, `beat(atFrame:)`, and `validate(frameCount:)` with piecewise-linear interpolation between anchors and constant-tempo extrapolation from the nearest end segment.
- `Preparation` retains its existing `grid` and `gridIsManual` fields, and gains optional adaptive map and lock state. Missing fields decode as no adaptive map and unlocked.

- [ ] **Step 1: Write failing model tests.** Cover interpolation, end extrapolation, forward/inverse lookup, invalid sample rate, non-finite values, non-increasing beat or frame positions, out-of-track anchors, and the documented maximum anchor count.
- [ ] **Step 2: Run focused tests to confirm the missing model behavior.** Run `swift test --filter BeatGridMapTests` from `Replica`; expect compile or assertion failures for the new API.
- [ ] **Step 3: Implement the value types and validation.** Make anchors immutable after initialization. Select and document a fixed maximum of 256 anchors per track; reject oversized maps rather than truncating accepted preparation.
- [ ] **Step 4: Add backward-compatible preparation fields.** Keep absent adaptive fields optional in serialized data. Validate maps against each track's frame count when loading a workspace.
- [ ] **Step 5: Test legacy decode and round-trip.** Verify existing JSON fixtures decode without adaptive fields and encode without changing fixed-grid values, cues, imported preparation, or analysis identity.
- [ ] **Step 6: Run focused tests.** Run `swift test --filter BeatGridMapTests` and `swift test --filter WorkspaceTests`; expect all relevant tests to pass.

### Task 3: Produce candidate adaptive maps in background analysis

**Files:**
- Modify: `Replica/Sources/TDJCore/MusicalAnalysisFeatures.swift`
- Modify: `Replica/Sources/TDJCore/AudioAnalyzer.swift`
- Modify: `Replica/Sources/TDJCore/AnalysisWorker.swift`
- Modify: `Replica/Sources/TDJCore/Models.swift`
- Test: `Replica/Tests/TDJCoreTests/MusicalRhythmRegressionTests.swift`
- Test: `Replica/Tests/TDJCoreTests/AnalysisWorkerTests.swift`

**Interfaces:**
- Produces: an optional candidate `BeatGridMap` and confidence/diagnostic data in the analysis result. Analysis output is a candidate; it does not replace `Preparation.grid` or accepted adaptive preparation.
- Consumes: the current pulse/onset analysis, cancellation checks, track duration, and existing analysis versioning.

- [ ] **Step 1: Add deterministic synthetic rhythm fixtures.** Include constant tempo, gradual drift, tempo ramp, two stable tempo sections, swing, late snare, and syncopated percussion.
- [ ] **Step 2: Write regression expectations.** Require constant-tempo output to stay equivalent to the fixed grid within a documented tolerance. Require drift to reduce end-to-end beat error without following percussive groove offsets. Require low-confidence input to produce no adaptive candidate.
- [ ] **Step 3: Implement candidate extraction off the render path.** Use robust windowed beat evidence and a smooth bounded tempo trajectory. Cap output at the model's 256-anchor maximum and preserve cancellation checks during long analysis.
- [ ] **Step 4: Version the analysis configuration.** Update the configuration identity so cached constant-grid results are not mistaken for results from the adaptive analyzer.
- [ ] **Step 5: Preserve existing preparation on reanalysis.** Extend existing merge rules so manual fixed-grid edits, imported TDJ preparation, locked adaptive maps, and saved cue positions remain authoritative. Keep a new map as a candidate when those rules do not permit automatic replacement.
- [ ] **Step 6: Run focused analysis and worker tests.** Run `swift test --filter MusicalRhythmRegressionTests` and `swift test --filter AnalysisWorkerTests`; expect deterministic output and unchanged playback/preparation state.

**Done when:** Analysis can suggest an adaptive map without changing which map a loaded track uses.

### Task 4: Publish immutable maps through the native transport safely

**Files:**
- Modify: `Replica/Sources/CTDJTransport/include/TDJTransport.h`
- Modify: `Replica/Sources/CTDJTransport/TDJTransport.c`
- Modify: `Replica/Sources/TDJCore/SourceControl.swift`
- Modify: `Replica/Sources/TDJCore/SampleTransport.swift`
- Modify: `Replica/Sources/TDJInterface/PlaybackController.swift`
- Test: `Replica/Tests/TDJCoreTests/TransportTests.swift`
- Test: `Replica/Tests/TDJInterfaceTests/StreamedPlaybackIntegrationTests.swift`
- Test: `Replica/Tests/TDJCoreTests/AudioCallbackMetricsTests.swift`

**Interfaces:**
- Consumes: the validated immutable `BeatGridMap` from Task 2.
- Produces: a bounded native map publication command that is validated and staged on the control producer before audio use. Render-time lookup performs no allocation, locking, or file work.
- Existing `BeatGrid` remains the fixed-grid representation and fallback.

- [ ] **Step 1: Audit every beat consumer.** List native and Swift call sites for Sync, quantised cues/queued starts, loops, Flux, Freeze, Loop Slicer, SuperSlicer, and beat-synchronised effects. Add the list to the task's implementation notes.
- [ ] **Step 2: Add failing native tests for map lookup.** Cover segment boundaries, fractional beat lookup, fixed-grid fallback, malformed publication, deck isolation, map replacement, and source-generation replacement.
- [ ] **Step 3: Implement bounded native ownership and publication.** Keep map memory alive for every command and render snapshot that can reference it. Reject a map before publication if it exceeds capacity or has invalid anchors. Never copy an unbounded map in the render callback.
- [ ] **Step 4: Route every beat-based control through one lookup contract.** Ensure all listed controls use the same frame-to-beat and beat-to-frame mapping. Keep continuous unsynced playback on its existing source-rate path.
- [ ] **Step 5: Make activation explicit and non-disruptive.** Applying a candidate while a deck plays must wait until a safe stopped/paused boundary or a deliberate user action. Do not alter current source position, loop boundaries, playback rate, active cue, Flux return position, or Sync phase during background completion.
- [ ] **Step 6: Run transport and integration tests.** Run `swift test --filter TransportTests`, `swift test --filter StreamedPlaybackIntegrationTests`, and `swift test --filter AudioCallbackMetricsTests`; expect existing fixed-grid comparisons to remain exact and no new callback allocation or fault.

**Done when:** The same beat map drives every beat-based operation, while ordinary playback and the audio callback retain current behavior and limits.

### Task 5: Extend the existing grid editor without changing gestures

**Files:**
- Modify: `Replica/Sources/TDJInterface/ReplicaModel.swift`
- Modify: `Replica/Sources/TDJInterface/WaveformTouch.swift`
- Modify: `Replica/Sources/TDJInterface/ReplicaView.swift`
- Modify: `Replica/Sources/TDJInterface/PerformanceControls.swift`
- Test: `Replica/Tests/TDJInterfaceTests/GridContactTests.swift`
- Test: `Replica/Tests/TDJInterfaceTests/GestureWorkflowTests.swift`

**Interfaces:**
- Consumes: fixed and adaptive map values and the candidate/accepted preparation state from Tasks 2 and 3.
- Produces: editor actions for Automatic, Fixed, and Adaptive interpretation; set/correct a local anchor; undo the last correction; and lock/unlock accepted preparation.
- Existing tap, swipe, pinch, scratch, loop creation, and library-dismiss gesture ownership remains unchanged.

- [ ] **Step 1: Write gesture regression tests.** Pin current contact counts, gesture ownership, loop resizing, scratch behavior, pinch zoom, and editor dismissal before adding controls.
- [ ] **Step 2: Add editor state transitions.** Test selecting Fixed or Adaptive, accepting a candidate, inserting or moving a local anchor, undoing, locking, unlocking, and falling back to the retained fixed grid.
- [ ] **Step 3: Add controls inside the existing grid editor.** Keep the performance screen unchanged. Show adaptive confidence and candidate status in the editor only. Do not add a new main-screen panel or assign a new waveform gesture.
- [ ] **Step 4: Verify gesture tests.** Run `swift test --filter GridContactTests` and `swift test --filter GestureWorkflowTests`; expect no changes to established gesture outcomes.

### Task 6: Qualify audio reliability and musical behavior

**Files:**
- Modify: `Replica/Status.md`
- Modify: `Replica/Responsiveness.md`
- Create: `Replica/Validation/AdaptiveBeatgridReliability-2026-11-02-01/README.md`
- Create: `Replica/Validation/AdaptiveBeatgridReliability-2026-11-02-01/manifest.json`
- Preserve: exact source, test outputs, callback/control reports, and listening notes in the validation folder.

**Interfaces:**
- Consumes: completed code from Tasks 2–5 and the baseline gate from Task 1.
- Produces: a source-identified qualification report. A failure blocks promotion and retains the failed inputs.

- [ ] **Step 1: Run the full serial test suite and native sanitizer checks on an isolated source copy.** Preserve exact source hashes and command output. Do not edit thresholds or fixtures to make failures pass.
- [ ] **Step 2: Run the unchanged short and sustained host workloads.** Include two-deck playback, adaptive Sync, looping, slicing, Flux, all six FX slots, background analysis, import/search activity, and recording. Require zero callback faults, invalid output, recording drops, and unexplained control deadline misses.
- [ ] **Step 3: Test controlled listening cases.** Compare fixed and adaptive maps on known steady, drifting, swung, live-drum, and deliberate tempo-change tracks. Confirm ordinary unsynced playback sounds and runs at its existing natural timing.
- [ ] **Step 4: Complete target-device acceptance only in a user-agreed window.** The current status says the user owns GenErik during hands-on testing. Do not query, install, launch, terminate, or run automated checks on the iPad until that window is agreed.
- [ ] **Step 5: Record results and limitations.** Separate Mac host evidence, physical callback/timing evidence, listening evidence, and user acceptance. Any route interruption, engine stop, missing evidence, or callback/control failure keeps the feature unqualified.

**Done when:** Fixed-grid behavior remains unchanged, adaptive maps improve measured timing on target examples, touch behavior remains stable, and audio/device gates pass at the required scope.

## Follow-on Plans

Create separate plans after this milestone establishes stable map and editor interfaces:

1. Automatic analysis queue and cache continuation, if the existing queue needs further work.
2. Beat Jump and musical loop movement.
3. Manual key shift and key-match popover.
4. FX sound refinement and selected combined effects.
5. Mac/iPad preparation continuity.
6. Library suggestions, filtering, and queueing.
7. Prepared vocal/instrumental stem prototype.
8. MIDI Learn, phrase guidance, advanced FX chains, and streaming integrations, driven by measured demand.

## Execution record — 2 November 2026

The implementation and source-bound verification are retained in `Replica/Validation/AdaptiveBeatgridReliability-2026-11-02-01/README.md`. Tasks 2–5 are implemented. The baseline gate is recorded. Task 6 remains incomplete: current-source concurrent changes, the complete combined timed workload, listening and a user-agreed A10X testing window remain open. No physical device operation was performed by this task.
