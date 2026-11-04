# R45: Audio and waveform feedback before analysis

Erik reported that loading must give immediate visual feedback and accept Play, even when analysis is incomplete. The feedback assumes build 98, the last recorded iPad installation. Build 100 was a separate Duo deployment.

## Cause and change

`loadPreparedTrack` awaited full analysis when BPM or key was missing. Only then did it prepare audio and request the saved waveform. Play input was disabled and discarded during that wait.

The candidate requests the saved waveform at selection. Audio preparation starts without full analysis. Play accepts one pending request, shows its active colour and starts when audio is ready. A second tap cancels it. Replacement, failure and shutdown clear the applicable request. Each request belongs to one native or managed load identity.

Missing analysis runs separately while decks are idle. Playback and performance touches cancel it. An idle deck can receive its detected grid without reloading the audio. Load identity and audio generation checks reject stale results. Pending manual preparation remains authoritative.

First-use native export, initial waveform generation and full PCM-cache decoding still take time. This candidate removes the full-analysis gate. It does not establish a latency budget or complete the first-use streaming path.

## Verification

- All five source-order checks fail on the baseline and pass after the change.
- Swift syntax parsing and whitespace checks pass.
- Four runtime tests cover early waveform display, Play before analysis, second-tap cancellation and replacement. The existing deferred-analysis test now awaits background analysis explicitly.
- The focused runtime command could not run these tests. Package compilation stops on four existing optional-chaining errors in `ControllerMIDIUMPDecoderTests.swift`, lines 63–65. The complete failed output is retained in `focused-tests.log`. No runtime-test success is claimed.
- The isolated test configuration compiles only the two selected test files. All five selected test functions pass, covering eight cases in 87.427 seconds. The production manifest was restored exactly. The test manifest and complete output are retained.
- Build 101 passes compilation, source identity, archive digest, framework resolution and signing. Its source is `df33fd13f`. A compiler-task diagnostic appears in the log, but the build exits successfully.
- The signed iPad build, installation and acceptance state are recorded in `result.json` and the numbered build record.

## Erik's check

1. Load an unanalysed track on deck A.
2. Check that the waveform appears before musical analysis finishes.
3. Tap Play immediately and check that one tap starts audio when ready.
4. Repeat on deck B while deck A plays.
5. Check that a second loading-time Play tap cancels the request.
6. Replace a pending load and check that the old request cannot start playback.
7. Pause both decks and check that missing analysis resumes.
8. Check that manual preparation stays intact and audio stays clean.

Physical latency, native first-use behaviour, failure recovery and clean audio remain subject to Erik's acceptance.
