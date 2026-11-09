# Current work

Use `main` in `/Users/veland/GenErik DJ` for every test build. Work serially on short-lived `feature/` branches and merge before building. Other chats and historical working folders remain inactive.

The main goal is a performance-ready app on the 2017 10.5-inch A10X iPad Pro. Live sets must have uninterrupted audio and consistently responsive UI, matching Erik's TDJ1 performance standard. Audio gaps, dropouts, visible stutter, UI stalls and delayed controls block acceptance. Features, analysis, polish and repository cleanup are subordinate to this goal. Background work must yield before it compromises performance. [Performance acceptance](release-gates.md) requires actual A10X evidence and Erik's listening and touch checks.

Preserve the TDJ1 touch workflow. Phone front-screen changes must not replace the iPad or Duo inside layouts.

**Build 173** installed on the A10X iPad Pro, and iPadOS accepted launch. R108 adds native S2 Mk3 deck and mixer controls and blue beat and amber warning lights on pad 8. Thirty-five focused host tests passed across 41 cases. Physical S2 Mk3 acceptance remains open. [Build record](../testing/builds/173.json) · [Protocol and scope](s2-mk3-native.md).

**Build 172** installed on the A10X iPad Pro, and iPadOS accepted launch. R98 adds a detailed waveform and overview to the full-height editor. The edit cursor sets placement. Split Section and Add Landmark stay above the edit lists. Erik checks placement and layout. [Build record](../testing/builds/172.json).

**Build 171** installed on the A10X iPad Pro, and iPadOS accepted launch. R107 restores support for earlier key history. The fixed reader reopened all 5,799 tracks in the copied iPad library and preserved the file hash. Erik checks that the decks and library appear. [Build record](../testing/builds/171.json).

**Build 170** installed on the A10X iPad Pro, and iPadOS accepted launch. R106 gives the Z1 a brighter blue hit and a curved fade through each beat. Thirty-one focused host tests passed. Erik checks the physical pulse, audio and touch. [Build record](../testing/builds/170.json).

**Build 169** installed on the A10X iPad Pro, and iPadOS accepted launch. R98 moves the sections editor to a filled bookmark before Settings and opens it at full iPad height. Sync and Grid, the loop controls, and the utility strip each have a shared border. Erik checks the layout and controls. [Build record](../testing/builds/169.json).

**Build 168** installed on the A10X iPad Pro, and iPadOS accepted launch. R105 holds the source cursor during starvation and returns to the live beat when samples refill. The other deck and master clock keep running. Six focused host tests passed across nine cases. Physical recovery remains open. [Build record](../testing/builds/168.json) · [Refill checks](source-starvation-recovery.md).

**Build 167** installed on the A10X iPad Pro, and iPadOS accepted launch. R104 detects a stalled renderer even without a route notification. The monitor can rebuild output while preserving deck positions and Sync. Ten focused host checks passed. Physical output recovery remains open. [Build record](../testing/builds/167.json) · [Stall detection and limits](output-stall-recovery.md).

**Build 166** installed on the A10X iPad Pro, and iPadOS accepted launch. R102 starts Music playback before saving waveform data. Six focused host checks passed. Erik checks audible start time while the waveform is still loading. [Build record](../testing/builds/166.json).

**Build 165** installed on the A10X iPad Pro, and iPadOS accepted launch. R101 keeps library analysis warnings read and adds a fresh unread warning when the affected track loads. Erik checks the badge and notice order. [Build record](../testing/builds/165.json).

**Build 162** installed on the A10X iPad Pro, and iPadOS accepted launch. R99 requests iPadOS alert protection for call banners. A host probe also reproduced a silent hold after a short clip release. Check call banners with Silent Mode off. [Build record](../testing/builds/162.json) · [Remaining gaps](system-audio-interruptions.md).

**Build 161** installed on the A10X iPad Pro, and iPadOS accepted launch. R98 puts the utility button at the waveform's left edge and opens the strip to its right in one row. Freeze, Cues and Flux use icons. The loop selector shows the beat count. Erik checks the layout and touch controls. [Build record](../testing/builds/161.json).

**Build 158** installed on the A10X iPad Pro, and iPadOS accepted launch. R91 raises the preview strip from 24 to 60 points when the deck has room. Erik checks strip size and drag precision against TDJ1. [Build record](../testing/builds/158.json) · [Preview workflow](preview-strip-navigation.md).

**Build 157** installed on the A10X iPad Pro, and iPadOS accepted launch. R95 restores Music loading when old app audio copies are missing. A fresh refresh removes records with no available local source and repairs records with playable Music audio. Load failures appear on the deck and block Play from restarting the previous track. Twelve initial focused host tests and six follow-up tests passed. The actual Hannah audio with saved iPad metadata passed on the final source. Build 156 was stopped before installation to include Erik's cleanup request. Physical loading, cleanup, audio and touch acceptance remain open. [Build record](../testing/builds/157.json) · [Cause and checks](track-source-recovery.md).

**Build 160** installed on the A10X iPad Pro, and iPadOS accepted launch. R97 selects original Z1 main and headphone outputs automatically. The Z1 routing controls show Automatic. Nine focused host checks passed on the signed source. Headphone listening, real port detection, reconnect and A10X acceptance remain open. [Build record](../testing/builds/160.json) · [Routing contract and checks](z1-audio-routing.md).

**Build 159** installed on the A10X iPad Pro, and iPadOS accepted launch. R96 retains mixer and effect values under queue pressure, retries gesture release and preserves Sync during output recovery. Eleven focused host tests passed across thirteen cases. Physical Z1 routing, listening and touch acceptance remain open. [Build record](../testing/builds/159.json) · [Audit and verification](reliability-audit-155.md).

**R96 reliability audit:** Build 155 had blocking control-delivery gaps. Three focused cases reproduced silence after channel/master volume return and a waveform release that remained held. Output-change recovery and current-source A10X performance qualification also remain open. No app or device change was made in this audit. [Findings and evidence](reliability-audit-155.md).

**Build 155** installed on the A10X iPad Pro, and iPadOS accepted launch. It came from committed `main`. R90 retains the latest Z1 crossfader position under queue pressure. R91 preserves preview-window contact and grid-aligned beat taps. R92 retains waveform drawings and pauses optional whole-track work during performance. Eighteen combined host tests passed across nineteen cases. Earlier R89 playhead and R93 Sync fixes remain included. Physical acceptance of all five live-test issues remains open. Build 154 was rejected after concurrent source changes and was not installed. [Build record](../testing/builds/155.json) · [Long-track changes](live-waveform-continuity.md) · [Preview workflow](preview-strip-navigation.md) · [Crossfader checks](z1-crossfader-continuity.md).

**R103 accuracy check:** The release Mac app repeated the same 12 files. Against nine saved references, tempo agreement improved from 8/9 to 9/9 and exact key agreement from 5/9 to 6/9. Downbeats remain 4/9. The 80 BPM correction leaves the downbeat unresolved. Combined analysis took 422.70 seconds, compared with 418.24 seconds before. Thirty-seven focused tests passed across 46 cases. A pre-existing adaptive drift failure remains open. [Results, versions and remaining work](analysis-accuracy-r103.md).

**R94 Mac check:** The release Mac app analysed 12 tracks with 78.23 minutes of audio. Fresh first-pass work took 310.24 seconds. The additional deep pass took 108.00 seconds. All 164 deep windows completed, and all 12 saved results reopened unchanged. Against nine compatible saved references, final agreement was 8/9 for tempo, 7/9 for beat phase, 4/9 for downbeat and 5/9 for key. Deep analysis improved some timings but did not change those aggregate counts. These references are not human ground truth. No iPad or Duo action was part of this check. [Results, source and limits](mac-analysis-audit.md).

**Build 153** is signed and ready from committed `main`. R88 adds full-track Beat This final0 analysis, versioned window checkpoints and automatic private iCloud result sharing. All matching groups finish before deep work. Deep analysis waits for external power and idle performance controls. Model upgrades declare their benefit and preserve usable preparation until replacement evidence passes. Forty-one focused host tests passed before the final review-notice change. Five follow-up tests passed on the final source. Three real tracks completed the full path, and interrupted analysis resumed to the same result. The Duo install failed because its trusted device connection was unavailable. The iPad received these changes with build 155. Actual Duo throughput, cross-device transfer and A10X live acceptance remain open. [Build record](../testing/builds/153.json) · [Engine contract and verification](tiered-analysis.md).


**Build 151** installed on the A10X iPad Pro, and iPadOS accepted launch. R93 retains Sync until explicitly disabled. Stops park on the grid. Starts, seeks, cues, gesture releases, vinyl resume and loop transitions restore beat alignment. Streamed preparation follows the same positions. Forty-two focused host tests passed across fifty-nine cases. Erik checks two-deck alignment, audio continuity and touch response with the Z1. R89 and R93 await physical acceptance. R90–R92 remain open. [Build record](../testing/builds/151.json) · [Sync contract and checks](persistent-sync.md).

**Build 149** remains the last recorded Duo install. R88 checks the whole library for beats and key before structure analysis. Automatic structure work waits for external power and suitable thermal state, then resumes from saved results. Ten focused tests passed across fifteen cases. Build 153 adds deep ML profiles and automatic sharing, but its Duo installation failed. The iPad is now on build 155. [Build record](../testing/builds/149.json) · [Approved policy and rollout](tiered-analysis.md).

**Build 150** installed on the A10X iPad Pro, and iPadOS accepted launch. R89 starts the waveform at the file beginning, follows ready and playing audio, and rejects stale playhead positions during a reload. Nine focused host tests passed across twelve cases. Erik checks load/reload position and playback. Build 144 live testing confirmed original Z1 operation and custom lights, but found five blocking issues. Crossfader silence, preview-strip feel and long-track flicker remain open as R90–R92. The R93 Sync candidate is in build 151. [Build record](../testing/builds/150.json) · [Live-test feedback and transport contract](live-test-144.md).

**TestFlight build 147 (0.1.0)** uploaded from committed main with Xcode 27.1. Apple completed processing. The build shows Ready to Submit, and its test notes are saved. R86 adds explicit private iCloud preparation sync and next-launch recovery. The CloudKit schema is deployed to Production. Thirteen focused Swift tests and four release-tool tests passed. Device sync, restoration and A10X audio/touch acceptance remain open. The iPad is now on build 155. [Build record](../testing/builds/147.json) · [Test steps](cloudkit-testflight.md).

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

Latest installed Duo candidate is **build 149**. Erik checks first-pass ordering, unplug/reconnect behaviour and playback. [Build record](../testing/builds/149.json).

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
