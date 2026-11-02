# Playback responsiveness

Documentation reviewed against the shared implementation on 30 October 2026. [Current readiness and verification](Status.md) is the implementation status record. Dated measurements below apply only to their recorded source and workload.

This pass removes avoidable UI and transport dependencies on background work. The [current audio report](Validation/audio-priority-2026-10-29.md) distinguishes the fixed handoff regressions and fresh runtime checks from earlier baselines. The retained Mac results and later exact-source A10X baselines have different scopes; neither establishes current-source full-session acceptance.

## Audio priority contract

The combined audio output callback is the highest-priority work. Playback and performance controls take precedence over analysis, collection search, artwork, import and persistence. The callback must not wait for those jobs, take their locks, allocate work buffers, decode media or write files. Recording capture uses the preallocated ring; its utility-priority writer drains independently. A full recording ring reports lost recording frames rather than blocking live output. That failure remains an acceptance failure, not successful recording.

Background queue priority alone does not guarantee deadlines. Production playback now reads fixed PCM buffers instead of file mappings. Anonymous buffers remain subject to host memory management. System scheduling, I/O and thermal limits still require target-device measurement.

## Bounded playback access — 29 October 2026

Each streamed asset owns a 32 MiB pool. Two decks normally own 64 MiB. A process-wide 128 MiB ceiling includes replacements and retired assets until disposal finishes. The C renderer reads immutable ready tables. It performs no file reads, allocation, locks, waits or buffer disposal. Read-ahead runs on a separate serial user-initiated queue for each asset, with at most sixteen 64 KiB blocks per service pass. Initial decoding remains on its independent background queue.

Initial loading prepares a real reserved generation before submission. Cold cues, seeks and performance regions prepare asynchronously while the current source continues. New intent cancels superseded preparation. Ticket identities remain owned through acknowledgement and any quantised execution. Once a ticket is consumed, live native requests supersede its old reserved range without waiting for display polling. Separate physical storage permits immutable old and next tables to coexist. Optional warming covers the eight cue positions without evicting mandatory audible, Keylock, pending-target or Flux-return data. A busy replacement budget yields asynchronously rather than blocking controls.

Paused cue recall now validates its target and start together. A cold target cannot start the old position. Compound slice/rate commands likewise cannot reverse the old music before a cold slice is ready. Releasing an inactive cold audition preserves the live Keylock state. Changing mode, grid editing or Freeze cancels pending audition work before it can start.

`streamed-native-tempo-context-tests.log` covers the Swift loader, exact reference output, cold actions and cancellation, optional cue warming, replacement-budget backpressure and context changes. Native normal, address/undefined and thread sanitizer logs cover table ownership, retirement, short reads, stalled workers, explicit starvation and compound controls. These checks do not replace A10X device acceptance.

The first combined streamed run passed in `Validation/SwiftRuntime-2026-10-28-StreamedEleven60s01/`. Both decks used 32 MiB, with no source-read misses, audio deadline misses, timestamp gaps, recording drops or control-budget misses. All eleven effects ran with background import/analysis/history work and 5,000-record searches. This run used four-second loops. Sequential read-ahead beyond the pool is a separate check.

## Interface observation — 29 October 2026

Playback position changes now reach separate waveform and overview views. Toolbar, header, panel and transport state remain in stable view owners. Control displays publish exact individual values, so advancing source positions and changing meter peaks do not invalidate unchanged Play, cue, Loop, Flux, EQ or crossfader displays. Filter positions and tempo retain their existing cadence. Actions read current values at invocation; touch sessions and panel input gates retain their ownership.

The first A10X static-interface run failed 715 control deadlines. View isolation reduced that to 43; individual control-value publication then passed with zero control misses and a 5.671 ms maximum audio callback. The [source-bound evidence](Validation/GenErikAudioCheck-2026-10-29-01/ui60-control-display01/manifest.json) retains the limits and all earlier failures. Seven before/after rendered screen states are byte-identical. Repeats, continuous reading, real panel motion and touch, frame presentation and auditory acceptance remain separate work.

## Changes

- Deck artwork no longer reads files or decodes images inside the SwiftUI view body. A background task creates a decoded thumbnail of at most 192 pixels per side. Concurrent requests share one task. A cache retains at most 32 thumbnails, and a changed deck cannot display a stale result.
- Library services share one serial background analysis queue. Concurrent imports cannot fan out into multiple CPU-heavy analysis jobs. Cancellation is checked during hashing, each decode block and each tempo-search lag. The worker uses a background dispatch queue rather than relying on the priority of an awaiting UI task.
- Recommendation ranking uses a separate serial background worker. Superseded requests cancel, and changed library/reference contexts cannot publish old results. The confirmed recommendation order is unchanged.
- Deck PCM preparation now uses its own serial background queue instead of user-initiated detached tasks. It does not queue behind analysis. Decode scratch storage is reused across blocks, and cancellation propagates into the preparation loop.
- Collection search, grouping and sorting now run on a separate serial background worker. The UI retains the last results while searching and discards superseded results. Playlist and suggestion lookups use a dictionary instead of repeated full-library searches. Import copying and post-copy hashing also run on a serial background queue, with a duplicate check after returning to the library actor.
- Recording file creation runs off the main actor. Concurrent start requests join one task; shutdown waits for startup and finalisation, and a stop requested during startup prevents it from restarting audio.
- Recording ring capture and draining use one wrap calculation per block rather than integer division on every audio frame. Arbitrary ring capacities remain supported.
- Play no longer waits for the global preparation/persistence task chain. A deck that is actually loading remains protected. Grid commands reach an already-loaded deck before the asynchronous save. Edits made while a deck loads are applied when that load commits. A late save cannot send an old grid to a replacement track.
- Mixer preferences and local playlists use the same off-main, coalescing writer as performance and FX settings. Normal Mac quit waits for pending saves and AIFF finalisation. Concurrent finish requests join the same recording task.
- The iPad target declares background audio. Moving the app to the background pauses visual polling and flushes preferences under a short OS background-task lease, while playback and recording continue. Returning to the foreground resumes polling. Closing the view, stopping audio or a system interruption still follows the explicit stop/finalisation path. Physical background/lock-screen behavior is not yet verified.

## Focused verification

The later audio-priority pass passed 13 focused recording, cache and cancellation tests (`Validation/audio-priority-focused-tests.log`). Its ring test now uses a non-power-of-two capacity. The final pass (`Validation/audio-priority-final-tests.log`) passed 16 tests in 66.298 seconds, including concurrent import deduplication and recording startup/shutdown. `Validation/audio-priority-ipad.log` records successful shared iPad SDK compilation, and `Validation/audio-priority-package.log` records the rebuilt, signed Mac app. The corresponding source and binary hashes are in `Validation/audio-priority-build-sha256.json`. `Validation/audio-priority-browser-tests.log` passes search/group filtering and preservation of suggestion order through the background projection.


`Validation/responsiveness-focused-tests.log` passes three regressions: serial analysis/cancellation, Play while preparation persistence is deliberately stalled, and grid persistence with the corrected BPM reaching the transport. `Validation/background-ui-tests.log` passes background ranking parity and thumbnail downsampling/task reuse. `Validation/responsiveness-ipad.log` records successful iPad SDK compilation.

The transport regression uses offline rendering and a deliberately stalled task. It proves that Play does not await that task; it does not measure a hardware deadline. The thumbnail test checks the 192 × 96 result from a 1024 × 512 source and reuse of the decoded image for simultaneous and later requests.

The combined regression passed 96 tests in 315.625 seconds (`Validation/responsiveness-full-tests.log`). Analysis jobs now run serially at background priority, and this run overlapped the coordinated native stress test. Its total duration is not a playback latency measurement. Subsequent lifecycle and effect-history checks passed five tests (`lifecycle-final-tests.log`). The final waveform-index and lifecycle rerun passed three tests (`waveform-lifecycle-tests.log`), and `performance-final-ipad.log` records a successful final SDK build. The iPad project and supplemental background-audio plist pass `plutil` validation. No iPad app installation or background runtime test was performed.

The Mac app was packaged and signed (`Validation/performance-mac-package.log`). Native UI inspection confirmed that it launches, accepts normal Quit through the application menu, exits and relaunches with its six-track development collection. This check used idle decks and did not connect hardware or start audio playback. Pending recording/preference draining is covered by the focused shutdown test rather than this idle UI check.

## Remaining performance evidence

The coordinated gesture chat owns C transport/FX callback costs and combined stress tests. Automated combined audio/control, recording, background work and panel motion have been measured on the authorised A10X diagnostic app. Exact-source manual touch, actual presented frames, listening, memory/thermal headroom and full gig duration remain open. No test on the parked gig iPad is authorised or claimed. Synchronous startup loading, full-library persistence cost, waveform drawing and native library decoding remain areas to measure at realistic collection sizes.

## Optimized package and combined native workload

The Mac packaging script now builds and copies the release executable. `Validation/audio-priority-release-package.log` records the optimized package; `Validation/audio-priority-release-ipad.log` records successful release-mode compilation of the shared iPad interface. The earlier debug test logs remain regression evidence. The build-hash manifest now identifies the release binary.

The coordinated final native run completed 180 seconds with two keylocked decks, six effects, recording, two CPU/memory workers and 84 successful real analysis runs. All 8,640,512 captured frames reached the reopened 24-bit AIFF, with zero recording drops or errors. Across 16,876 callbacks there were no source/graph deadline overruns, timestamp gaps, HAL overloads or C++ allocations during rendering. Maximum graph time was 4.450 ms against a 10.667 ms budget at 512 frames/48 kHz. See [recording-performance.md](Validation/recording-performance.md) for the full evidence and source hashes.

This is the native C audio harness with the production recording ring and an equivalent utility AIFF writer. It is not a runtime measurement of the Swift app UI, target-iPad scheduling, thermal behaviour or audible output; the probe silences hardware output after rendering. It does not establish complete Traktor DSP or DLC fidelity.

The optimized packaged app was quit and relaunched through the native UI. Its six-track browser populated, searching “Hello” returned the matching track, and clearing the field restored all six rows. This was an idle UI check, not a frame-pacing benchmark under playback. The static ImageRenderer browser image omits lazy rows and shows unsupported native-control placeholders; it is not counted as visual acceptance.

## Continued implementation after the performance pass

The native Music-library picker now projects search, playlist order and prepared/selectable rows on a serial background worker, with stale results discarded. Native catalog scans and iPad per-track artwork preparation use a separate serial background queue instead of user-initiated tasks or the main actor. `Validation/music-library-priority-tests.log` records passing playlist/search and prepared-selection checks. The complete unsigned generic-simulator Xcode app builds in Release, including the iPad wrapper and generated permission/background-audio plist.

The deck layout now follows the saved S20 reference placement: Sync in the header, with FX, EQ, headphone cue and Play in a vertical column beside the waveform. Native UI verification confirms that upward loading prepares deck A without starting playback and the moved EQ button opens and closes its drawer. Exact dimensions, artwork and full visual fidelity remain open.

Browser navigation now collapses both decks to compact overview rows with cue and Play controls above the collection, as shown in S15/S21. The browser gear opens an inline Playback section using the shared reference settings. Native UI inspection verified all six collection rows, both deck controls and the four Quantize choices, Slicer Quantize and Freeze on Load. Album sorting is now included, matching inventory F009. Load-slider contact handling now resets on cancellation/removal and isolates its owning contact; its existing development distance threshold is unchanged.

## Runtime continuation — 28 October 2026

Loaded-track lookups now cache the two deck records and invalidate on any library change, including metadata edits that retain the same revision. Runtime recording-list refreshes read the directory on a utility worker and coalesce overlapping requests. The recording sheet shows progress while its first list is being read. `continuation-runtime-ui-tests.log` passes four checks covering metadata invalidation, completed-file filtering, recording/shutdown and refreshed lists; `continuation-contact-tests.log` passes three loading/browser projection checks.

The new [production Swift runtime validator](Validation/swift-runtime-validation.md) exercises the actual source callback and Swift recorder with background analysis in the same process. Its 60-second check passed 5,625 callbacks, 58 loop recalls, 382 analyses and 1,381 searches with no deadline misses, render errors, rejected commands or recording frame loss. All 2,880,000 captured frames reached the AIFF. This supplements the native C-harness evidence and retains its own source/binary manifest and limitations.

Music preparation now belongs to the model rather than its sheet. Done and dismissal return to the decks while the batch continues; reopening provides progress and Stop. Shutdown cancels the owned batch. Three background-preparation checks pass in `music-preparation-background-tests.log`.

The [storage update](Storage.md) externalises waveform samples, keeps the app/service snapshots compact and hydrates selected decks in the background. Tests preserve samples, ranking and preparation, verify backups/corruption checks and show that longer waveforms do not enlarge the collection index. Ready decks no longer wait for load-history persistence; stale library completions cannot replace a newer revision.

Recording failure is now observed through an atomic status flag or ring overflow. The controller finalises the failed recording and retains its incomplete file while playback continues. `recording-failure-continuity-tests.log` passes five fault/reset, overflow, shutdown and recording checks.

The combined storage/lifecycle regression passed all 135 tests (`storage-continuation-full-tests.log`). The complete generic iPad simulator Release app built successfully, and the compatible Mac Release app was packaged. The updated silent Swift runtime check passed 60 seconds with 5,000 search records, repeated history saves and 407 background analysis passes. All 2,880,512 captured frames reached the AIFF. There were no measured audio deadline misses, timestamp gaps, recording drops or control-budget misses. See the runtime report for scope and source hashes. Live touch inspection could not proceed while the Mac was locked.

Library-service transactions now use a shared serial background executor with enforced background QoS. This covers index encoding, history/grid commits, artwork-file writes and import bookkeeping that previously ran off the main actor but could inherit ordinary task priority. Analysis, media copying and waveform hydration retain their separate background workers. Live grid/transport changes still precede persistence. The app does not put audio work on this executor.

The subsequent full regression passed all 136 tests in 307.744 seconds (`library-priority-full-tests.log`). Six focused library checks also pass with native codec services available (`library-storage-priority-tests-local.log`). `library-priority-ipad.log` records the successful shared Release iPad build. The earlier restricted-process test attempt exited without test results and is not counted as a pass.

The five-minute production Swift run then passed 28,125 callbacks, 15,000 control batches and 298 saved-loop recalls, alongside 1,862 background analyses/history saves and 4,054 searches across 5,000 metadata records. All 14,400,000 captured frames reached the AIFF. There were no measured source deadline misses, timestamp gaps, render failures, rejected commands, control-budget misses or recording drops. Maximum callback time was 5.415 ms against 10.667 ms. `Validation/SwiftRuntime-2026-10-28-Priority300s01/` retains the result and matching source/vendor/binary hashes. These are silent Mac measurements, with the same limits described in the runtime report.

The user confirmed the saved 2017 10.5-inch iPad Pro/A10X as the minimum target on 28 October 2026. The current package and app deployment target is iPadOS 17; that model is on Apple's [compatibility list](https://www.apple.com/ca/newsroom/2023/09/ipados-17-is-now-available/). A 2015-model backport is outside this confirmed minimum. Target-device runtime acceptance remains pending. The user also confirmed the Mac is unlocked, so live Mac checks can resume.

The next UI batch restores three FX selector tabs sharing one pad. Contacts retain their original slot through tab changes, partial releases and cancellation; the pad defers visible selection changes until release. Thirteen focused FX/hardware-axis/tail/recording tests pass. The final Release package and shared iPad build pass (`shared-effect-pad-final-package.log`, `shared-effect-pad-final-ipad.log`). Offscreen rendering verifies the single-pad layout and readable inactive tabs. A second live-inspection attempt still found the Mac locked. This UI batch follows the recorded five-minute run and has separate checks; its later source files are not claimed to match that earlier manifest.

The subsequent DSP batch adds the three remaining base effects, with a shared C count/Swift catalog and runtime coverage of all eight. It adds small fixed per-slot state and no audio buffers, render-time allocations or locks. Once fully bypassed, held samples and filter state clear so reactivation cannot replay stale sound. Twenty-five focused performance tests pass. A new 60-second production Swift run passed all eight algorithms under analysis/history/search/recording load, with 5,628 callbacks and no measured deadline, timestamp, render, command, control-budget or recording failures. Every captured frame reached the AIFF. See the runtime report for the matching manifest and scope limits.

The recovered H5 screenshot now guides half-width FX/mixer overlays, one row of FX names, separate Equalizer/Filter tabs and four vertical Low/Mid/High/Volume faders. The existing audio values and temporary second-finger behaviour remain in use. Touch coordinates match the drawn thumb endpoints, avoiding a value jump when touching an endpoint thumb. Filter and FX pads clip their markers to the control area; the panels use simple grid/shape drawing without blur. Fifteen contact/control checks pass (`reference-panel-contact-tests.log`), and the optimized Mac package plus shared iPad build pass. `reference-panels-preview.png` is an offscreen geometry check, not native frame-pacing or touch acceptance.


## Background control and output resumption — 29 October 2026

Control maintenance continues independently of the visual refresh loop. It collects acknowledgements and recording failures and completes prepared actions while display polling is paused. Its feedback queue is bounded. Audio buffer safety does not depend on this timer meeting a deadline: the native consumer releases obsolete range reservations from the live source requests.

Recording Stop closes its atomic capture gate before scheduling finalisation. The file worker waits for an already accepted sample copy before draining and closing the AIFF. This keeps producer joining on the recording worker and excludes later callbacks even if finalisation is delayed. The capture loop is unchanged; focused sample, overflow, restart and shutdown checks pass. Combined validation is recorded separately in `Validation/stop-controls-final-build-results.json`.

Output resumption verifies the coverage actually adopted by the native renderer, including shared assets and the configured maximum callback size. A prepared ticket alone is insufficient. The query performs no storage reads or allocation. Engine start and the final coverage/bound checks run without an intervening main-actor suspension.


## Collection sort working memory — 29 October 2026

Collection sorting now keeps integer positions in its filter/sort working buffers and copies the selected track values into the result once. The existing localized comparisons, missing-value rules, manual metadata, stable ties and unsorted suggestion order stay the same. No shared cache or new lock was added. Three focused compatibility checks pass against a frozen copy of the former implementation, including duplicate identifiers and full record equality. The coordinated read-only review found no ownership or ordering issue.

The [fair production comparison](Validation/CollectionSortIndex-2026-10-29-01/manifest.json) sorts 115,219 shuffled records on a background queue. Both implementations are called across module boundaries. Median time across three runs was 7.390 seconds before and 4.490 seconds after, a 39.2% reduction on this Mac. Every output identifier matched. Working elements measured 384 bytes before and 8 bytes after; these are working-buffer elements, not total process memory. The result still contains track values. These numbers do not establish A10X performance.

The first five-second shuffled-catalog smoke check retained clean audio, source, recording and control counters but failed because its first search had not completed before cancellation. That result is retained. The following workload uses a longer short-check window and retains the requirement for completed background searches. Cancellation still checks around the complete sort; this change does not claim immediate cancellation inside sorting. Full regression/build checks and new source-bound playback runs follow this production change.


The [final current-source checks](Validation/audio-priority-2026-10-29.md#final-current-source-checks) pass all 196 tests, complete app builds, and 15/60/300-second Mac workloads after this sort change. The shuffled full-catalog checks preserve every captured recording frame with zero measured audio, source, recording or control-budget failures. The separate unsigned iPad check app is archived for authorised hardware testing; no physical acceptance is claimed.

The [later live Mac check](Validation/LiveMacControls-2026-10-29-01/manifest.json) clears the lock-screen blocker without changing those validated inputs. Done, the tempo wheel and normal Quit responded during a pending native Music read. A fresh process completed the 115,219-song/401-playlist catalog, and native search, playlist selection, local preparation, deck loading, playback, mixer access and AIFF finalisation were verified. Slow service startup remains open. These observations do not measure frame pacing or audio deadlines.

## Current scheduling and source boundary

Analysis quality is the current development priority, while real-time output and live control retain runtime scheduling precedence. The analysis queue remains serial and background-priority. The current output callback is the Objective-C++ bridge into the C renderer/recorder. Private fractional-span and FX display candidates are not current production merely because their isolated reports pass. Use Status.md and exact source hashes to distinguish promoted and private work.
