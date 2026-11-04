# Current work

Use `main` in `/Users/veland/GenErik DJ` for every test build. Work serially on short-lived `feature/` branches and merge before building. Other chats and historical working folders remain inactive.

The main goal is a performance-ready app on the 2017 10.5-inch A10X iPad Pro. Live sets must have uninterrupted audio and consistently responsive UI, matching Erik's TDJ1 performance standard. Audio gaps, dropouts, visible stutter, UI stalls and delayed controls block acceptance. Features, analysis, polish and repository cleanup are subordinate to this goal. Background work must yield before it compromises performance. [Performance acceptance](release-gates.md) requires actual A10X evidence and Erik's listening and touch checks.

Preserve the TDJ1 touch workflow. Phone front-screen changes must not replace the iPad or Duo inside layouts.

Latest installed candidate: **build 114**, application source `b02866e54`. R52 removes the visible Actions label and places the icon flush in the waveform corner. Default zoom shows five beats. Side controls fill and follow the deck area, with the crossfader centred on the divider between equal or unequal decks. All 2,661 focused geometry checks, six core waveform tests, six rendered deck cases, source identity, signing and framework checks pass. Installation succeeded, iPadOS accepted launch and device actions stopped.

Erik’s corner control, zoom, deck split and browser resize checks remain open. R51 full-height browsing remains included. Current request **R50** resumes after these UI checks. Build 112 has setup captures only, with no combined-load performance result. Profiling both decks, FX, recording and background analysis remains pending on build 114, and automatic analysis pauses during playback by design. Setup and failed evidence remain under ignored `TestBuilds/r50/`, with the UI checks under `TestBuilds/r51/` and `TestBuilds/r52/`.

R48 is recorded in [the cleanup report](../maintenance.md). The stem model, original media, private candidates and failed evidence remain preserved.

- [Requests](requests.md) retain every request ID and remaining work.
- [Testing](../testing/README.md) defines the single-change iPad loop.
- [Release gates](release-gates.md) separate build evidence from real-setup acceptance.
- [Known issues](known-issues.md) record unresolved limitations.
- [Completion programme](completion-programme.md) lists unfinished product work.
- [History](../history.md) locates archived designs, coordination metadata, logs and captures.

No full-session A10X or gig-readiness claim follows from compilation or launch. Historical private-source reconciliation remains open under R19.
