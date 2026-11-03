# R31: Tempo after a long intro

The full-track tempo path remains first. If it returns no BPM or weak confidence, the analyser searches overlapping 24-second windows through the track. A final 12-second window covers late rhythm near the ending. Local activity and level scaling prevent a loud intro from masking quieter later percussion.

A supported window supplies tempo and phase. A backward local-contrast check recovers earlier attacks in that beat train. Two unsupported beats stop the extension. Anchors remain at their actual source positions. Adaptive-map frame positions, beat numbers and downbeat offsets shift with the recovered anchor. The periodicity fallback also requires a supported beat train and anchors it at an actual attack instead of a phase projected to the start.

The analysis configuration changes to 0.3.2. Tracks without BPM already trigger full analysis when loaded under R29. This change improves that attempt. It does not prove a reliable BPM for 3Cag, whose audio was not available to these checks.

Seven focused production checks pass. They cover low whole-track activity, over three minutes of intro, a loud irregular intro with much quieter late beats, rhythm near the file ending, isolated-hit rejection, steady-tempo retention, cancellation and decoded generated audio. One test combines several related timing assertions. The actual audio fixture has an 85-second intro, then quiet 123 BPM beats.

The original code failed seven assertions. The first local-window implementation found tempo but started the anchor too late. The next backward extension exposed a falling intro edge that looked like an attack. The extension now requires a positive attack near the predicted beat. Failed results remain in `baseline.log`, `anchor-failure.log` and `anchor-contrast-failure.log`. Intermediate source snapshots were not saved, so those two failures are not tied to exact source hashes.

Run `python3 docs/testing/checks/R29/2026-11-03-late-rhythm/check.py` for the focused checks. The harness compiles production rhythm, spectrum and audio-decoder code without the app UI. No simulator or broad regression sweep is required for this test iteration. Erik checks 3Cag, anchor placement and uninterrupted other-deck audio on the Duo candidate.
