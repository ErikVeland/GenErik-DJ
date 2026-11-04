# Current work

Use `main` in `/Users/veland/GenErik DJ` for every test build. Work serially on short-lived `feature/` branches and merge before building. Other chats and historical working folders remain inactive.

The main goal is a performance-ready app on the 2017 10.5-inch A10X iPad Pro. Live sets must have uninterrupted audio and consistently responsive UI, matching Erik's TDJ1 performance standard. Audio gaps, dropouts, visible stutter, UI stalls and delayed controls block acceptance. Features, analysis, polish and repository cleanup are subordinate to this goal. Background work must yield before it compromises performance. [Performance acceptance](release-gates.md) requires actual A10X evidence and Erik's listening and touch checks.

Preserve the TDJ1 touch workflow. Phone front-screen changes must not replace the iPad or Duo inside layouts.

Latest installed candidate: **build 112**, application source `4cdd0b927`. R48 removes generated/historical clutter from the active tree, standardises first-party source, repairs MIDI test compilation and reduces catalogue counting/search allocations. All 31 focused Swift tests, 4,484 geometry assertions, loading-order checks and native transport checks at three rates pass. The repository check reports no issues. Source identity, signing and framework resolution passed. Installation succeeded, and iPadOS accepted launch. Device actions stopped. Erik's physical acceptance remains open.

Current request: **R50**, profile build 112 on the actual A10X with both decks, FX, recording and background analysis. On 5 November Erik reconnected and unlocked the device. The installed app reports build 112. Device-wide CPU, UI and audio-instrument setup captures succeeded. These captures do not verify the requested workload. The latest screen shows empty decks, and Erik requested setup help. The Mac screen viewer remains at “Connecting display”, but device screenshots work. Automatic analysis pauses during playback by design. The combined performance capture, measured fixes and next build remain pending. Build 112 stays installed. Setup evidence and failed attempts are preserved under ignored `TestBuilds/r50/`.

R48 is recorded in [the cleanup report](../maintenance.md). The stem model, original media, private candidates and failed evidence remain preserved.

- [Requests](requests.md) retain every request ID and remaining work.
- [Testing](../testing/README.md) defines the single-change iPad loop.
- [Release gates](release-gates.md) separate build evidence from real-setup acceptance.
- [Known issues](known-issues.md) record unresolved limitations.
- [Completion programme](completion-programme.md) lists unfinished product work.
- [History](../history.md) locates archived designs, coordination metadata, logs and captures.

No full-session A10X or gig-readiness claim follows from compilation or launch. Historical private-source reconciliation remains open under R19.
