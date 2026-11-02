# Native Music Integration Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans. Implement the tasks in this chat. Keep each test cycle separate.

**Goal:** Combine the existing automatic native Music browser and playlist behaviour with the verified player, without delaying Audio Out or performance controls.

**Architecture:** Start from the private fader/recording candidate `a653e1f4479fbfb892fc260a988288a1602ed0e1a5ad42936990cdf3c11b49ee`. Merge native-library changes by function and field. Retain the accepted-generation load callbacks, preparation pins and original timing limits. Keep catalogue projection, analysis and file work off the main actor.

**Tech Stack:** Swift 6, SwiftUI, MediaPlayer, AVFoundation, the existing native audio engine and serial background workers.

**Spec:** `Analysis/Traktor-DJ-1x/15-performer-fidelity-specification.md`, requirements 1–8. The user also requested automatic native-library access, analysis and Apple Music playlists in the later development chats.

## Global Constraints

- Combined Audio Out and immediate performance controls have first priority.
- Minimum device: 10.5-inch iPad Pro (2017/A10X).
- Keep the original and exact control-completion limits at 20 ms.
- Keep background analysis at background priority.
- Do not query, install, launch, terminate or automate GenErik while the user tests.
- Keep the original Traktor app and parked gig iPad excluded.
- Do not copy shared source or the later test app wholesale.
- Preserve imported preparation, manual edits, cue deletions and loaded generations.
- Do not duplicate the entire native music library into the app's storage.
- Do not transfer tests or performance acceptance between source fingerprints.

## Review Focus

- A background analysis that has not returned must not hold a new musical load behind its task.
- Loading from a native URL must retain the accepted-generation callback and recording title.
- A cancelled or obsolete analysis must not replace a playing track's grid or full analysis.
- Playlist source order and filesystem/native source identities must survive refresh and restart.
- Large catalogues must not trigger CPU-heavy projection or uncontrolled task creation on the main actor.
- Files imports remain browsable when Music access is denied and when a Music catalogue is present.

## Sources and workspace

- Native-library development source: `TestBuilds/AllLatest-2026-10-30/Replica`, fingerprint `34aae950a0446e9224b0c8626d073fed7931b553e528eea93b1c9619fc4fcf0b`.
- Later playlist-order source: shared `Replica`, observed fingerprint `76c8cf6907134a5720101991eeb8635fc6e71dcabd443fa73c62b6de1e41f060`.
- Integration workspace: `Private/NativeMusicIntegration-2026-10-31/Replica`.
- Evidence: `Replica/Validation/NativeMusicIntegration-2026-10-31-01`.
- The later chat reports an installed main-app update. Its current device fingerprint is unknown. Do not query the device to resolve it during this hold.

## Task 1: Preserve the baseline and map the merge

- [ ] Finish the current fader/recording build, visual and Mac timing sequence.
- [ ] Copy its source into the separate persistent integration workspace, excluding generated build output.
- [ ] Verify source, tests, scripts, projects and synthetic fixtures against the baseline.
- [ ] Save function-level diffs from the native-library and playlist sources.
- [ ] Retain the current candidate unchanged as the comparison baseline.

## Task 2: Native references and source loading

Files: `Sources/TDJCore/Models.swift`, `Workspace.swift`, `PCMCache.swift`; `Sources/TDJInterface/PlaybackController.swift`, `ReplicaModel.swift`.

- [ ] Add the existing `nativeLibraryOnly` optional field without replacing the qualified BPM/key/grid accessors.
- [ ] Add `LibraryService.analyzeNativeMusic` without replacing preparation staging, duplicate-analysis retention or provenance checks.
- [ ] Add an optional native `sourceURL` to PCM preparation and the existing controller load method.
- [ ] Retain the existing `committed(generation)` callback and cancellation/acknowledgement lifecycle.
- [ ] Verify native-source loading, restart, temporary-file cleanup, failure rollback and recording titles with real synthetic files.
- [ ] Run the existing preparation-pin, late-grid and duplicate-analysis regressions alongside these tests.

## Task 3: Catalogue and playlist projection

Files: `MusicLibraryReconciliation.swift`, `CollectionProjection.swift`; `NativeMusicBrowser.swift`, `BrowserView.swift`.

- [ ] Retain available native songs as browser entries before analysis completes.
- [ ] Include prepared Files imports in All Songs without duplicating prepared native entries. Test Music denial and a nonempty native catalogue.
- [ ] Test original playlist order, duplicate membership, unprepared entries and explicit sorting.
- [ ] Run large-catalogue matching/filtering on a serial background worker with cancellation and stale-result checks.
- [ ] Keep UI rows free of file reads and repeated full-library searches.
- [ ] Preserve the current suggestion ranking and destination behaviour.

## Task 4: Automatic background analysis and load priority

Files: native Music methods in `ReplicaModel.swift`, the existing analysis workers and `MusicLibraryWorkflowTests.swift`.

- [ ] Add the existing automatic discovery/analysis flow in a separate model extension where practical.
- [ ] Reproduce a load while background analysis is deliberately held.
- [ ] Remove any dependency on joining that held analysis before musical loading can progress.
- [ ] Keep heavy analysis serial and cancellable. Do not raise its priority or fan out full analyses.
- [ ] Test load replacement, obsolete completion, active preparation protection, shutdown and cleanup.
- [ ] Compare the other playing deck's rendered PCM during these operations.

## Task 5: Gesture and display integration

Files: `LoadSliderGestureSession.swift`, `TouchSurface.swift`, browser views and their tests.

- [ ] Merge the reported LOAD threshold/scroll-ownership fix without replacing later contact and panel guards.
- [ ] Test visible endpoint commits, cancellation, repeated load attempts and held contacts during replacement.
- [ ] Use existing stable control displays for performance-phase dependencies.
- [ ] Render the affected browser states offscreen. Record intentional native-library layout differences separately from performance-screen comparisons.

## Task 6: Full verification

- [ ] Freeze a new source fingerprint and all test/build inputs.
- [ ] Run focused native Music, playlist, preparation, gesture and recording checks.
- [ ] Run the full serial Release suite with unchanged limits.
- [ ] Run the six generic package/build checks and offscreen comparisons.
- [ ] Retain complete Mac timing reports, including failures. Do not infer A10X performance from compilation or synthetic PCM checks.
- [ ] Update the current-state record and remaining physical acceptance plan.
- [ ] Keep this candidate private and leave GenErik untouched until the user releases the testing window.

## 31 October execution checkpoint

The combined native Music model, background browser projection, selected alias recording metadata, source integrity guards and LOAD endpoint/scroll ownership changes are staged privately. Focused tests include an uncooperative held background preparation and a sample-for-sample comparison with the other deck's control player. Review corrections preserve browse position during analysis and invalidate cancelled playlist saves.

Candidate `8c78f05e0f279983ea078c7293fe78e974fe59f9a949439ea39bdd23584c13a9` is frozen for the complete verification sequence. Device acceptance remains deferred under the user testing hold. The earlier exact-completion miss remains open. See the dated integration evidence and ledger before interpreting any checklist item as qualification.
