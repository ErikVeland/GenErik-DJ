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

This candidate must pass compilation and signing, then return to the same iPad. Erik checks opening recommendations, continued touch response and continuous audio. Repeat after an extended session. A passing host test or successful launch does not resolve the reported freeze.

## Build storage

The Mac reached 244 MB of free space during verification. Builds 220–225 were copied to `/Volumes/Games/GenErikDJ-preserved-builds/R428/`. File sizes, SHA-256 hashes and symlink targets matched before removing each original copy. The original build paths now link to the preserved directories. The manifest is `TestBuilds/r428/archive-relocation.jsonl`. No saved build was discarded.

## Build 228

Build 228 from `591dfd9d09f77ee88cdda236cf8989989a766f6f` passed iPad compilation, runtime framework checks and signing. The standard installer timed out after 20 seconds. Direct installation of the same saved signed app succeeded over Wi-Fi at 22:35:16 Brisbane time. Both remote launch requests timed out. Erik opens the installed app. No launch confirmation or physical acceptance is claimed. Device actions stopped.

1. Open GenErik DJ on the iPad.
2. Retry Deck B album-art recommendations for Da Hool Love Parade while audio plays.
3. Check repeated taps, continuous audio and immediate touch response, including after an extended session.
