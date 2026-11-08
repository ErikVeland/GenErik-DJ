# Current work

Use `main` in `/Users/veland/GenErik DJ` for every test build. Work serially on short-lived `feature/` branches and merge before building. Other chats and historical working folders remain inactive.

The main goal is a performance-ready app on the 2017 10.5-inch A10X iPad Pro. Live sets must have uninterrupted audio and consistently responsive UI, matching Erik's TDJ1 performance standard. Audio gaps, dropouts, visible stutter, UI stalls and delayed controls block acceptance. Features, analysis, polish and repository cleanup are subordinate to this goal. Background work must yield before it compromises performance. [Performance acceptance](release-gates.md) requires actual A10X evidence and Erik's listening and touch checks.

Preserve the TDJ1 touch workflow. Phone front-screen changes must not replace the iPad or Duo inside layouts.

**Build 128** installed and launched on the A10X iPad Pro. Loading a track while both decks are idle sets the master tempo to its BPM. Erik checks the tempo during idle loads and during playback. [Build record](../testing/builds/128.json).

**Build 124** came from `main` at `a7acf07d9`. The A10X iPad Pro launched the new analyser and saved a 71.0058 BPM grid for 3CAG. All 56 reference bars are within 20.5 ms of the fitted grid. The iPad kept the manual grid and key and saved sections and automatic cue candidates. [Build record](../testing/builds/124.json).

Latest installed Duo candidate is **build 126**, from `main` at `c4202fbe8`. It saves the beat grid and key before it analyses structure and automatic hot cues. On the Duo, the first check advanced the counter to 1 of 376 after the 13-second “Catchphrases”. The queue resumed after reconnecting and had 88 saved matching results at the last reachable check. [Build record](../testing/builds/126.json).

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
