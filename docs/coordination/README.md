# Current work

Use `main` in `/Users/veland/GenErik DJ` for every test build. Work serially on short-lived `feature/` branches and merge before building. Other chats and historical working folders remain inactive.

The main goal is a performance-ready app on the 2017 10.5-inch A10X iPad Pro. Live sets must have uninterrupted audio and consistently responsive UI, matching Erik's TDJ1 performance standard. Audio gaps, dropouts, visible stutter, UI stalls and delayed controls block acceptance. Features, analysis, polish and repository cleanup are subordinate to this goal. Background work must yield before it compromises performance. [Performance acceptance](release-gates.md) requires actual A10X evidence and Erik's listening and touch checks.

Preserve the TDJ1 touch workflow. Phone front-screen changes must not replace the iPad or Duo inside layouts.

Latest installed candidate: **build 113**, application source `526ae0e25`. R51 lets the iPad browser expand to the full workspace below the toolbar. Normal opening size, orientation memory and right-hand control positions are retained. Fast release at full height retains that height. All 3,142 focused geometry checks, source identity, signing and framework checks pass. Installation succeeded, iPadOS accepted launch and device actions stopped.

Erik’s browser drag and control checks remain open. Current request **R50** resumes after that check, as Erik requested. Build 112 has setup captures only, with no combined-load performance result. Profiling both decks, FX, recording and background analysis remains pending on build 113. Automatic analysis pauses during playback by design. Setup evidence and failed attempts remain under ignored `TestBuilds/r50/`, and R51 checks remain under `TestBuilds/r51/`.

R48 is recorded in [the cleanup report](../maintenance.md). The stem model, original media, private candidates and failed evidence remain preserved.

- [Requests](requests.md) retain every request ID and remaining work.
- [Testing](../testing/README.md) defines the single-change iPad loop.
- [Release gates](release-gates.md) separate build evidence from real-setup acceptance.
- [Known issues](known-issues.md) record unresolved limitations.
- [Completion programme](completion-programme.md) lists unfinished product work.
- [History](../history.md) locates archived designs, coordination metadata, logs and captures.

No full-session A10X or gig-readiness claim follows from compilation or launch. Historical private-source reconciliation remains open under R19.
