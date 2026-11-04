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
