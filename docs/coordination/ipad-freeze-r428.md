# R428: iPad freeze when opening recommendations

Erik reported a complete app freeze on 19 November 2026. It had lasted at least eight minutes. He tapped Deck B album art to find a matching track for Da Hool Love Parade. The Home button returned to the Home screen. Audio continuity remains unconfirmed.

## Device evidence

The device inventory confirms build 227 on the A10X iPad Pro. Its process was 850. The app launched at 18:23:56 Brisbane time.

The saved report `GenErikDJ-2026-11-19-214253.ips` records a scene-update watchdog termination at 21:42:52. iPadOS killed the background app after its ten-second scene-update allowance expired. This allowance is not the total freeze duration.

The main thread was inside `ObservationRegistrar.State.cancel`, copying and removing observation registrations. The application frames are `ReplicaModel.browserPresentationID.setter`, `ReplicaModel.showSuggestions(destination:)` and the DeckView tap callback. The thread had not reached recommendation ranking. The report identifies the blocked notification path, but does not establish why its registrations became expensive.

The initial Time Profiler capture attached but stalled during finalisation. Later device requests timed out. Both wireless and USB debugger connections failed during the initial handshake. Direct USB crash-report retrieval succeeded. Evidence, including failed attempts and a readable stack summary, remains under ignored `TestBuilds/r428/`.

## Focused candidate

The candidate marks the browser request ID as unobserved and delivers requests through a Combine event publisher. The existing browser views receive the event after destination state is ready. The panel handle keeps its own request ID. This bypasses the observed UUID setter in the failure report. Other model notifications remain unchanged.

Focused checks cover event delivery, repeat presentation, the missing-reference fallback and the loaded-track album-art workflow. The first host test compiled, then stalled without a test result. The second attempt was stopped during compilation to prioritise the iPad build. Both attempts remain incomplete. Neither is a pass or a reproduced freeze.

Build 228 passed compilation and signing and is installed on the iPad. Erik checks opening recommendations, continued touch response and continuous audio. An extended-session device check remains open.

## Build storage

The Mac reached 244 MB of free space during verification. Builds 220–225 were copied to `/Volumes/Games/GenErikDJ-preserved-builds/R428/`. File sizes, SHA-256 hashes and symlink targets matched before removing each original copy. The original build paths now link to the preserved directories. The manifest is `TestBuilds/r428/archive-relocation.jsonl`. No saved build was discarded.

## Build 228

Build 228 from `591dfd9d09f77ee88cdda236cf8989989a766f6f` passed iPad compilation, runtime framework checks and signing. The standard installer timed out after 20 seconds. Direct installation of the same saved signed app succeeded over Wi-Fi at 22:35:16 Brisbane time. Both remote launch requests timed out. Device actions stopped. Erik later reported initial operation. Sustained physical acceptance remains open.

1. Open GenErik DJ on the iPad.
2. Retry Deck B album-art recommendations for Da Hool Love Parade while audio plays.
3. Check repeated taps, continuous audio and immediate touch response, including after an extended session.

## Completed focused verification

All four focused host tests passed on 19 November 2026. The application sources match build 228 at `591dfd9d09f77ee88cdda236cf8989989a766f6f`. The added tests are committed at `3dfa2b59df5215e45799ef823c30c7749f2fd2e7`. No application source changed, and no new iPad app build or device action ran in this verification pass.

| Check | Result |
| --- | --- |
| Shared request-ID registrar bypass | Passed. The original model registrar received no request-ID notification. Events still arrived for repeated opens and the missing-reference fallback. |
| Loaded-track album-art workflow | Passed. Opening recommendations retained the expected destination and did not load another track or add a playback-history event. |
| Legacy notification control | Passed. A deliberate call to the old mutation-notification path fired the observer. The current request path did not. |
| Observer backlog and audio | Passed. 10,000 pending request-ID observers remained untouched across 128 requests. All 128 distinct events arrived with coherent destination and visibility state. The two-track fixture returned one eligible recommendation. |
| Offline playback comparison | Included in the stress test. All 65,536 stereo frames matched the reference exactly, with finite, non-silent output. Playback positions, phases, Sync choice and loaded tracks stayed unchanged. |

The 128 request calls took 33.557 ms in total on this Mac. This is a host measurement, not an A10X response-time result. The original pair passed in 89.341 seconds. The added pair passed in 88.793 seconds. Fixture preparation accounts for much of that time.

The first retry required a long test-bundle compilation. A process sample confirmed that the runner was analysing the existing workflow fixture after compilation. The new fixture uses known grids and real WAV files to avoid repeating unrelated musical analysis.

Evidence remains under `TestBuilds/r428/`: `test-focused-resume.log`, `test-stress.log` and `focused-verification.json`. The summary includes log hashes, source identities and measured counts. Earlier incomplete attempts remain preserved.

Erik reported that the app seemed to be working. He could not confirm repeated taps with audio, test duration, or absence of audio/touch defects. These host checks verify the targeted notification bypass and offline playback behaviour. They do not render SwiftUI views, measure live audio deadlines, or reproduce the original extended-session A10X freeze. Sustained device acceptance remains open.
