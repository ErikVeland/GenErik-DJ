# R43 main verification and iPad handover

Erik requested the R43 main merge, a fresh Creep check and an iPad installation on 4 November 2026.
The consolidation had already merged the implementation into main as `770a53322`.
Main checkpoint `db5b29c10` includes the R43 source, waveform changes and immediate loading changes.

Fresh checks pass: 23 rhythm/bar/state cases and seven late-rhythm cases.
A native probe compiled from the current main detector reads the saved iPad Creep playback cache.
The cache digest matches the original iPad evidence. It gives 136.017769 BPM and bar zero at 0.180574 seconds.
The saved-preparation regression also checks automatic adoption of this grid and protection of user edits and locks.

Another active R45 chat temporarily changed the package manifest during its focused test.
That affected the initial whole-application fingerprint. The recorded detector file hashes match committed main exactly.
The temporary fingerprint remains in the result with this limitation. A signed build requires stable committed application files.

The earlier nine-recording genre/version review remains in `../2026-11-04-auto-bars/genre-review.json`.
It has two unresolved bar results and five candidates below the inherited-import support gate.
No new broad song review or independent listening evaluation was run for this handover.

Build and installation evidence is recorded below.
Physical opening-bar alignment, later alignment, saved cues, playback and scratching remain Erik’s acceptance checks.

## Combined R43/R44/R45 check

Erik then requested all current work in one main build.
The first-use loading change joins the existing automatic bar starts and direct waveform motion.
Fresh combined-source checks pass: 23 bar cases, seven late-rhythm cases, five loading-order assertions and 93 waveform-motion assertions.
A new native cache probe again gives 136.017769 BPM and bar zero at 0.180574 seconds.
The application fingerprint stayed unchanged throughout that probe. The generated model snapshot matches the current model source.

The compressed-audio probe compiles the production decoder prefix with host error adapters.
`CompressedDecoderProbe.swift` compares AVAssetReader with AVAudioFile on the local Creep MP3.
All seven ranges match exactly, including the opening, block boundaries, reverse seeks and a range near the end.
Both backends report 22,746,240 frames at 44,100 Hz. `compressed-creep.json` records input, decoder and probe hashes.
Commercial audio remains local. This host check does not establish physical iPad performance or ipod-library access.

The loading checkpoint records seven core tests, seven interface test functions covering ten cases and native stream checks.
See `../../R45/2026-11-04-first-use/result.json` for its source hashes, failed attempts and remaining device acceptance.
The combined signed build and installation record completes the software handover.

R45 checkpoint `d2bf0e280` is committed and its chat has stopped. Its owned file hashes match the combined source.

## Build 106 handover

Main source `1147096218b3893ff964ac06e0d767f4ab18d4ee` produced signed build 106 in 257.34 seconds.
The complete application fingerprint matches the combined-source check. The saved app passes bundle identity, runtime framework resolution and strict signature checks.
The build contains both the R43 bar detector and R45 direct native loader. `artifact-checks-106.json` records their binary markers.
An initial extra marker check expected an obsolete waveform literal. Its correction remains recorded. No app change or rebuild followed.

Build 106 installed on the 10.5-inch test iPad. iPadOS accepted the launch request. Device actions then stopped.
The 240-second limit was available for installation. The deployment completed successfully without a retry.
The previous build 105 timeout remains in its original record. No historical build or audio evidence was deleted.

Erik's acceptance remains open:

1. Pause both decks.
2. Reload Creep and wait for “Beat grid ready”.
3. Check beat one near 0.180574 seconds and later bar alignment.
4. Check saved cues, manual preparation, playback and scratching.
5. Load an unanalysed native track and check its opening waveform and Play response.
6. Check clean other-deck audio and continued operation.
