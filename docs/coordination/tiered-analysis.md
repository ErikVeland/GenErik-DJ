# R88: whole-library preparation, then deep analysis

Approved by Erik on 9 November 2026: make the whole library mix-ready first, then use the plugged-in, idle Duo
for the deepest analysis of every track, and share accepted results with the iPad.

## Product contract

1. Reuse compatible saved and trusted imported fields before running inference.
2. Give every available track its first BPM, beat-grid and key attempt before starting automatic refinement or structure work.
3. Save each usable result immediately. Unsupported, unavailable and ambiguous results remain explicitly marked for review.
4. A failed track does not prevent other tracks from progressing. A completed attempt does not imply a reliable result.
5. Eventually run the current validated deep profile on every track, including tracks with confident initial results.
6. Run expensive automatic work on the Duo only while external power is present and performance controls are idle.
7. Pause when playback, recording, loading or deck interaction needs resources. Pause detailed work at serious or critical thermal state.
8. Resume from saved stage results. Do not clear preparation or restart expensive completed stages after a pause.
9. Share accepted results with the iPad using verified audio identity. Do not change a loaded deck or overwrite manual preparation.
10. Report separate first-pass and deep-pass progress. Never label current heuristic structure analysis as the completed future deep profile.

“Deepest” means the strongest validated profile available in this app version, not an endless loop over all possible models.
A profile upgrade creates new work for the affected stages. It does not remove the existing usable result.
Unknown power state does not authorise expensive work. A fully charged device on external power does.
The initial implementation treats idle as no playback, recording, deck touch, import, sync or loading operation.
It does not require the screen to be locked. Screen-off Neural Engine processing needs separate OS capability and device verification.

## Engine responsibilities

| Component | Responsibility |
| --- | --- |
| Source identity and reuse | Verify the exact audio, retain trusted field authority and resolve saved stage results. No ML is needed for hashing. |
| First pass | Produce usable BPM/grid/key or an explicit review state. Process shorter tracks first within this pass. Keep existing long-mix limits. |
| Deep worker | Process every eligible track after the first pass. Start with stronger beat/downbeat evidence, then detailed structure and cues. |
| Acceptance policy | Evaluate each field independently. A newer or larger model is not sufficient reason to replace an accepted field. |
| Durable stage store | Key results by exact audio identity, stage, model/algorithm version and profile. Persist successful stages and interrupted attempts separately. |
| Transfer queue | Upload completed revisions in bounded batches and retry after network/account recovery. Local analysis must not wait for the network. |
| iPad receiver | Validate the audio and stage schema, retain local history, and adopt accepted automatic fields only when the track is unloaded and playback is idle. |

BPM, beat timing, downbeat, key, sections and cue proposals need separate states and provenance.
Keep manual grids, key authority, corrected section labels, manual cues, loops and deliberate cue deletions.
Store ambiguous candidates separately from accepted values. A remote revision is evidence, not an instruction to replace a local library.
Use source hash plus sample rate, channels and frame count. Do not match titles or opening excerpts.
Different encodings require a future verified canonical-audio identity path; the present container hash must not be treated as proof of equivalence.

## Deep profile rollout

The current small0 Neural Engine path remains the first-pass model on capable iOS devices.
Evaluate the larger Beat This model as the first deep beat candidate, using bounded windows across the track and explicit coverage records.
Full-track coverage for long mixes needs resumable window checkpoints. Do not silently lift the current 90-second inference limit.
Evaluate learned key and section models separately. Current DSP key and structure outputs remain available while those candidates are tested.
Whisper Core ML encoder support is a separate integration, not a `use_gpu` switch.
A stage is deep-complete only for the profile and coverage it actually ran.

Use held-out labelled audio to compare tempo octave, phase, downbeat, key, section roles and full-track drift.
Keep precision and coverage together. The audit's 98%/95% precision and 20 ms drift goals remain targets, not measured results.
Compare execution placement, speed, memory, heat and cancellation on the actual Duo.
Keep A10X CPU behaviour conservative and validate received-result playback on the actual iPad.

## Ordered releases

| Release | Deliverable | Verification |
| --- | --- | --- |
| R88 first increment | All matching batches before all structure batches. Gate existing automatic structure work on external power and thermal state. Resume after conditions improve. | Queue order including mixes, waiting without retry loops, unplug cancellation, saved-result reuse, charging resume and signed Duo build. |
| Durable deep stages | Per-field/stage records, profile and coverage identifiers, resumable windows and explicit deep progress. | Interrupted writes, app termination, changed audio/model, no false completion, no repeated accepted work. |
| Deep ML profile | Validated stronger beat model and later validated key/section stages, applied eventually to every track. | Same-audio musical comparisons and actual Duo execution, latency, memory, thermal and cancellation checks. |
| Automatic sharing | Separate automatic-analysis transfer/adoption from explicit full-revision recovery. Send completed stages and consume compatible results without musical re-analysis. | Offline/reconnect, duplicates, account changes, malformed/stale results, loaded tracks, manual edits and deleted cues. |
| Device acceptance | One coherent source on Duo and iPad, using the established signed-device loop. | Duo power/idle behaviour, iPad reuse and uninterrupted playback. No gig-readiness claim from compilation. |

This order follows the project's one-change, one-build, install-and-hand-back rule.
The first increment does not implement stronger-model refinement or automatic cross-device adoption.
R86's explicit revision sync and next-launch recovery remain available. They are not the automatic receiver described above.
The first-pass ordering supersedes R85's shorter-track structure-before-long-mix policy.

## First-increment implementation plan

**Execution:** Serial in this chat and working folder, on a short-lived feature branch. No agents or worktrees.
**Goal:** Establish the ordered queue and power/idle contract before adding new model work.
**Architecture:** Keep the serial queue and current matching/structure stages. Add observable pause reasons and environment-driven restart.
**Tech stack:** Swift, Foundation, UIKit notifications and the existing Swift Testing suite.
**Spec:** Product contract and ordered releases above.

### Global constraints

- Keep existing inference, cancellation and long-mix limits.
- Keep saved preparation and waveform data.
- Build from committed `main`; install on the Duo for this requested device-policy change.
- Stop device actions after launch. Physical throughput and audio/control acceptance remain Erik's checks.

### Review focus

- Unknown power: detailed work waits; first-pass work can continue.
- Fully charged but connected: detailed work is eligible.
- Power loss during structure: cancel the work and do not mark the pass complete.
- A new track arrives while waiting: run its first-pass work without requiring power.
- A failed first-pass source: retain review state and allow other tracks to progress.

### Task 1: Order the first pass across the whole library

Files: `Replica/Sources/TDJInterface/NativeMusicAnalysisQueue.swift`, `NativeMusicModel.swift` and their queue/background tests.
Interface: `NativeMusicAnalysisQueue.prepare() async -> [Batch]` retains its existing signature.

- [x] Change tests to expect short matching, mix matching, short structure, mix structure.
- [x] Run `swift test --package-path Replica --filter 'analysisQueue|wholeLibraryMatching'` and retain the failing output.
- [x] Build batches by pass, then duration group. Retain loaded-track priority within each group and the 19-minute boundary.
- [x] Update the log wording and verify ordering, progress totals, saved-result reuse and empty queues.

### Task 2: Gate existing automatic structure work

Files: `Replica/Sources/TDJInterface/LibraryAnalysisConditions.swift`, `NativeMusicModel.swift`, `ReplicaLifecycle.swift`,
`LibraryAnalysisBackgroundTasks.swift`, and `Replica/Tests/TDJInterfaceTests/BackgroundPreparationTests.swift`.
Interfaces: `LibraryAnalysisConditions(externalPower: Bool, thermalState: ProcessInfo.ThermalState)`;
`ReplicaModel.updateLibraryAnalysisConditions(_ conditions: LibraryAnalysisConditions)`.

- [x] Test first-pass completion on battery, a waiting phase without false completion, and charging resume.
- [x] Test cancellation during structure after power loss, thermal pause/resume and saved-result reuse after restart.
- [x] Store the active pass and waiting snapshot in session state. Leave `finishedAnalysis` unset while structure waits.
- [x] Observe iOS battery/thermal changes, treating charging/full as external power and unknown/unplugged as unavailable.
- [x] Cancel an active structure job when conditions become unsuitable. Restart when suitable, using saved results.
- [x] Check actual playback/recording/touch idleness before starting work and before each job.
- [x] Run only the focused policy, ordering and existing cancellation tests. Retain the source digest with the results.

### Task 3: Signed test handover

- [ ] Commit coherent code, tests and records on the feature branch. Merge into `main` before building.
- [ ] Use `tools/ipad_test.py` for one incremental signed build and Duo installation.
- [ ] Record the build number, source identity, failures and unverified device checks.
- [ ] Commit and push the handover record. Stop device actions after launch.

## Decisions and remaining work

Ruling: Implement the queue/power contract as the first release; keep stronger ML and automatic sharing in separate releases.
Reason: The project requires one focused change per device-test cycle. Both later changes have distinct accuracy and persistence risks.
This release must not be described as the completed tiered engine.

Ruling: Apply the power gate to existing automatic structure work on both iOS device classes.
Reason: This establishes consistent idle-preparation behaviour without changing the A10X analyser or requiring Neural Engine hardware for cached results.
Host tests use an explicitly suitable environment. iOS starts with unknown power until the device observer supplies its state.

Self-review: The product contract covers every track, power/idle gating, accepted-result sharing, manual authority and profile upgrades.
The first increment covers ordering and eligibility only. Model selection, durable deep stages and automatic adoption remain explicitly open.

Review ruling: Recheck eligible waiting work when the old task finishes.
A charging event can arrive during queue cleanup, before a new task is allowed to start. The final check prevents a missed resume.

## First-increment checks

The old queue failed the new first-pass ordering checks. Those failed results remain in `TestBuilds/r88/queue-red.log`.
The missing policy API failed compilation before implementation; that output remains in `policy-red.log`.
Focused host checks cover mixed/empty queues, loaded mixes, matching on battery, charging resume, thermal cancellation,
new tracks while waiting, source failures, saved-result reuse and foreground/background transitions.
They do not establish actual device power-event behaviour, analysis throughput or live audio/control performance.

Final-source verification: ten focused tests passed across fifteen cases. The source digest is retained in `TestBuilds/r88/verification.json`.
