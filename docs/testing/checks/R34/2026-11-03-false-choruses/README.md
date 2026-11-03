# R34: False chorus labels in 99 Problems

Erik requested this focused correction and an iPad installation on 3 November 2026.
The reported recording is Danger Mouse’s **99 Problems**, from **The Grey Album (2012 Remaster)**.
The decoded PCM came from the Duo app’s playback cache. Its identity is in `result.json`.
Raw audio and copied device library data remain under ignored `TestBuilds/ipad/R34/`.

## Reproduction

The previous production analyser reproduced the saved Duo result: 17 chorus labels across 19 sections.
The labels covered the first 216.39 seconds of a 244.65-second recording.
The eight hot-cue slots concealed the full label count.

The old rule compared average pitch and frequency profiles from separate vocal passages.
It discarded passage order and did not require contrast with other vocal passages.
The new regression checks first produced seven failed assertions. See `failing.log` and `track-baseline.log`.

## Correction

Structure version 3 compares eight ordered summaries within each passage.
Candidates must have similar durations and match in at least six summaries.
The average sequence distance must also pass the existing similarity threshold.
At least eight seconds and 25% of vocal-section time must provide contrasting pitch or frequency evidence.
These are conservative engineering rules. They are not calibrated probabilities or a trained song-form model.

When the evidence cannot establish a chorus, the analyser uses **Vocal section ?**.
It does not infer a verse solely from vocal presence when no chorus has been established.
The exact recording now has zero chorus suggestions. Its 19 section boundaries remain unchanged.
This removes unsupported labels. It does not identify the recording’s true hooks or complete song form.

Old caches refresh when the track loads. Automatic hot-cue labels also refresh at retained boundaries.
Manual section locks, manual cues and deliberate cue deletions retain their existing authority.
The change adds no model downloads or work to the audio callback.

## Verification

Fifteen focused production checks pass through `check.py`. No app package or simulator test run was used.
The checks cover the recorded features, uniform backing loops, different sequences with equal averages,
nine distinct recurring refrain suggestions, generated cue refresh, existing cue protection and existing structure checks.
The committed feature fixture contains one-second measurements, not audio or independent section annotations.
Its real-track check rejects blanket chorus coverage. It is not a measure of semantic recognition accuracy.

`probe.py` and `TrackProbe.swift` run the production feature extractor on the retained exact PCM.
The baseline and candidate logs and arrangements retain both results.
Host elapsed times are diagnostic only. They do not establish iPad cost.

The build number, source identity and installation result are recorded in `result.json` and the numbered build record.
Erik must reload this track, check the replacement labels and listen for clean audio during analysis.
Wider library accuracy, phrase boundaries and full song-form recognition remain open.
