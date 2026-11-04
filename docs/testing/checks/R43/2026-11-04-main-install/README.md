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

Build and installation evidence will be recorded after the shared working folder is stable.
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
The combined signed build and installation record will complete this handover.

R45 checkpoint `d2bf0e280` is committed and its chat has stopped. Its owned file hashes match the combined source.
