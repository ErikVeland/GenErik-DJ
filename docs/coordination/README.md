# Current work

Use `main` in `/Users/veland/GenErik DJ` for every test build. Work serially on short-lived `feature/` branches and merge before building. Other chats and historical working folders remain inactive.

The main goal is a performance-ready app on the 2017 10.5-inch A10X iPad Pro. Live sets must have uninterrupted audio and consistently responsive UI, matching Erik's TDJ1 performance standard. Audio gaps, dropouts, visible stutter, UI stalls and delayed controls block acceptance. Features, analysis, polish and repository cleanup are subordinate to this goal. Background work must yield before it compromises performance. [Performance acceptance](release-gates.md) requires actual A10X evidence and Erik's listening and touch checks.

Preserve the TDJ1 touch workflow. Phone front-screen changes must not replace the iPad or Duo inside layouts.


**TestFlight build 147 (0.1.0)** uploaded from committed main with Xcode 27.1. Apple completed processing. The build shows Ready to Submit, and its test notes are saved. R86 adds explicit private iCloud preparation sync and next-launch recovery. The CloudKit schema is deployed to Production. Thirteen focused Swift tests and four release-tool tests passed. Device sync, restoration and A10X audio/touch acceptance remain open. The installed iPad remains on build 144. [Build record](../testing/builds/147.json) · [Test steps](cloudkit-testflight.md).

Erik handed R87 to the “Choose analysis data sync” chat on 8 November 2026. The implementation is merged and pushed. Continue from build 148 feedback. TestFlight build 147 does not include R87.

**Build 148** installed on the Duo, and iOS accepted launch. R87 adds a Float16 Beat This model and foreground CPU + Neural Engine execution on capable iOS devices. Six focused tests passed across seven cases. The original A10X CPU model remains. Actual Duo throughput, musical accuracy and playback checks remain open. [Build record](../testing/builds/148.json) · [ML audit and rollout](neural-analysis.md).

**Build 144** installed on the A10X iPad Pro, and iPadOS accepted launch. R83/R84 add amber warnings every four beats at 30 seconds remaining and every beat at 10, plus a subtle blue beat pulse. Filter/FX actions remain unchanged. Twenty-one focused tests passed across 24 cases. Physical light timing, brightness, control and audio checks remain open. [Build record](../testing/builds/144.json) · [Test steps](../testing/controller-test.md).

**Build 143** installed on the A10X iPad Pro, and iPadOS accepted launch. R85 runs both analysis passes for shorter tracks before mixes over 19 minutes. Eight focused tests passed across 15 cases. Saved results are reused. Erik checks phase 2 progress and playback. R83/R84 lights follow in build 144. [Build record](../testing/builds/143.json).

**Build 142** installed on the A10X iPad Pro, and iPadOS accepted launch. R82 adds the native Z1 accessory session, calibration, direct controls and light feedback. Native discovery is on by default. Thirteen focused host checks passed. Physical Z1 and A10X performance acceptance remain open. [Build record](../testing/builds/142.json) · [Protocol evidence](z1-native-accessory.md) · [Test steps](../testing/controller-test.md).

**Build 140** installed on the A10X iPad Pro, and iPadOS accepted launch. Erik released the analysis hold for R81. Controllers now shows the first Z1 connection test and shares MIDI, accessory and audio details. Direct iPad Z1 accessory control remains unimplemented. Physical input and routing checks remain open. [Build record](../testing/builds/140.json) · [Test steps](../testing/controller-test.md).

**Build 139** installed on the Duo, and iOS accepted launch. R80 releases audio hash buffers after each chunk. The iPad analysis was left running for that update. [Build record](../testing/builds/139.json).

**Build 138** installed and launched on the A10X iPad Pro after Erik released the hold. Beat This uses up to 90 seconds on long mixes and requires a supported opening downbeat. Speed, accuracy and playback checks remain open. [Build record](../testing/builds/138.json).

**Build 137** installed and launched on the A10X iPad Pro. Pass 1 reports Traktor grid only, key only and both separately. [Build record](../testing/builds/137.json).

**Build 136** installed on the A10X iPad Pro, and iPadOS accepted launch. [Build record](../testing/builds/136.json). R76 adds the first measurement increment from Erik's analysis optimisation audit. It records stage timings, source/cache paths and interrupted attempts. Musical decisions remain unchanged. The [rollout record](analysis-optimisation.md) lists measurement limits, report commands and the remaining corpus, A10X and Traktor comparisons.

**Build 135** installed and launched on the A10X iPad Pro. Pass 1 logs reuse, fresh analysis and failures every 100 checks and when the pass stops. [Build record](../testing/builds/135.json).

**Build 133** installed and launched on the A10X iPad Pro. Pass 1 reuses validated Traktor grids and keys. A file path or date change alone does not mark audio as changed. Erik checks Pass 1 speed. [Build record](../testing/builds/133.json).

**Build 134** installed and launched on the A10X iPad Pro. The app keeps the screen awake during foreground analysis on external power. Erik checks Auto-Lock during and after analysis. [Build record](../testing/builds/134.json).

**Build 131** installed and launched on the A10X iPad Pro. The analysis badge shows the current pass and its song count. [Build record](../testing/builds/131.json).

**Build 132** installed and launched on the A10X iPad Pro. The information dropdown shows Music library notices and includes Mark all as read. Erik checks the unread badge. [Build record](../testing/builds/132.json).

**Build 130** installed and launched on the A10X iPad Pro. The battery icon shows a bolt while charging. It turns orange below 20% and red below 10%. Erik confirmed that the bolt follows plug and unplug events. Library analysis reached 504 of 11918 checks. Erik reported slower analysis than original Traktor. [Build record](../testing/builds/130.json).

**Build 129** installed and launched on the A10X iPad Pro. All Songs opens on the left. The deck shortcut opens Recommendations on the right. Erik checks both entry points. [Build record](../testing/builds/129.json).

**Build 128** installed and launched on the A10X iPad Pro. Erik confirmed the master tempo reset. Library analysis paused at 389, then restarted at 14:37 Brisbane time after deck analysis finished. [Build record](../testing/builds/128.json).

**Build 124** came from `main` at `a7acf07d9`. The A10X iPad Pro launched the new analyser and saved a 71.0058 BPM grid for 3CAG. All 56 reference bars are within 20.5 ms of the fitted grid. The iPad kept the manual grid and key and saved sections and automatic cue candidates. [Build record](../testing/builds/124.json).

Latest installed Duo candidate is **build 148**. Erik checks foreground Neural Engine analysis, grid placement and playback. [Build record](../testing/builds/148.json).

Duo **build 126** came from `main` at `c4202fbe8`. It saves the beat grid and key before it analyses structure and automatic hot cues. On the Duo, the first check advanced the counter to 1 of 376 after the 13-second “Catchphrases”. The queue resumed after reconnecting and had 88 saved matching results at the last reachable check. [Build record](../testing/builds/126.json).

**Build 127** is signed and ready. The deck flag controls cue visibility. The battery icon follows the reported level, shows full at 100% and turns red below 10%. [Build record](../testing/builds/127.json).

**Build 125** is signed and ready to install. It adds background library analysis on supported systems. The test iPad and Duo were unavailable. Verify system scheduling and playback on the devices. [Build record](../testing/builds/125.json).

Build 114 was profiled on the actual A10X with two playing decks, five active FX slots, recording and the existing read-only analysis comparison. The steady run used 25.8 seconds of main-thread CPU in 30 seconds, with a mean 28.4 FPS. The combined run used 36.8 seconds in 45 seconds, with estimates from 21 to 60 FPS. The 116.2-second stereo AIFF saved successfully, and the comparison completed 120 songs. Erik reported no obvious problem during the first listening/touch run. Instruments exposed no client audio I/O events, so no deadline or underrun count is claimed.

R50 remains open for the same-workload A10X comparison of the latest installed build and direct audio timing checks. Normal automatic analysis still pauses during playback. Temporary UI automation was removed, and the earlier FX settings and comparison report were restored. Evidence, symbols, recordings and failed attempts remain under ignored `TestBuilds/r50/build-114/`. R51/R52 UI changes remain included, with their checks under `TestBuilds/r51/` and `TestBuilds/r52/`.

R48 is recorded in [the cleanup report](../maintenance.md). The stem model, original media, private candidates and failed evidence remain preserved.

- [Requests](requests.md) retain every request ID and remaining work.
- [Testing](../testing/README.md) defines the single-change iPad loop.
- [Release gates](release-gates.md) separate build evidence from real-setup acceptance.
- [Known issues](known-issues.md) record unresolved limitations.
- [Completion programme](completion-programme.md) lists unfinished product work.
- [History](../history.md) locates archived designs, coordination metadata, logs and captures.

No full-session A10X or gig-readiness claim follows from compilation or launch. Historical private-source reconciliation remains open under R19.
