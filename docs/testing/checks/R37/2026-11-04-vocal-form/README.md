# R37: vocal song form

Erik asked for verse, hook and chorus detection, starting with Danger Mouse’s **99 Problems**, followed by genre/version checks and an iPad test build.
Build 82 is the assumed feedback baseline. This change preserves its touch fixes and the R35 rhythmic-edge profile.

## Change

Structure version 5 combines local word recognition, repeated word sequences and SoundAnalysis voice evidence.
Rap refrains and short sampled phrases can receive **Hook**. Sustained sung refrains can receive **Chorus**.
Substantial changing lyrics can receive **Verse**. The pass consolidates older acoustic subdivisions where the new evidence supports a role.
A chorus uses local singing evidence and matching returns, so a long instrumental intro cannot dilute its score.
Repeated phrases have no fixed three-chorus limit.

The model runs offline, on the CPU, through a serial preparation queue at utility priority.
Starting either deck or touching a performance waveform cancels this work. Both decks must be idle before it restarts.
Complete results are cached. Existing cue positions, cue deletions and manual preparation retain their authority.
Recognised text is transient. Saved arrangements contain no lyrics. The regression fixture contains word fingerprints and source-frame timings.

The app bundles the 190,085,487-byte Whisper small multilingual Q5_1 model.
`model.json` pins its source revision and SHA-256. The iPad build helper verifies the model before it calculates the application source identity.
The framework is pinned to whisper.cpp v1.8.7 and its archive checksum. Both MIT licence notices ship with the model.

## Exact recording

The native probe uses the same stereo PCM as R34, with source content hash
`01ed5962e6583b090ae9ca4309a6900218c06da2788df9e874838c76e8e217c9`.
Its source timeline has 10,788,864 frames at 44,100 Hz.

| Seconds | Assignment |
| --- | --- |
| 0.00–5.08 | Opening hook |
| 5.08–43.64 | Verse |
| 43.64–58.48 | Hook |
| 58.48–115.64 | Verse |
| 115.64–138.76 | Hook |
| 138.76–187.64 | Verse |
| 187.64–221.12 | Hook |
| 221.12–244.65 | Outro |

These are machine-assisted assignments, not independent listening annotations.
The recogniser misses words near the start of the second verse. Sustained voice evidence joins that gap to the substantial unique lyrics that follow.
Phrase boundaries remain approximate. For example, a separate earlier transcription placed the second verse pickup near 56.9 seconds.
Erik must check those pickups by ear.

## Evidence and limits

`result.json` binds the checks to the production source files. `corpus-review.json` retains each reviewed recording and its predictions.
The sample starts with two successful baseline recordings per genre family, then includes seven successful 12-inch entries and missing version types. The eighth 12-inch entry failed in the earlier baseline.
It reuses the original, hash-verified recordings and the R35 tempo/key values. This iteration does not re-evaluate tempo or key accuracy.
The final role pass replays the saved native word fingerprints and classifier frames after the local chorus-score and subdivision fixes.

Thirty-eight focused checks pass. They cover the exact recording, sung and rap refrains, short samples, nine legitimate refrains,
long instrumental edges, consistent roles on matching returns, missed words, instrumental gaps, cue positions, cache coding and manual-preparation rules.
The native cancellation probe stops inference after its cancellation flag. This checks the model abort path on the host.
It does not establish iPad playback continuity or A10X preparation cost.

The 28 recordings all retain valid source timelines and section boundaries. Nine role inventories change.
Vocal form is assigned on nine recordings, compared with one in the baseline. These counts describe coverage, not correctness.
The review remains unlabelled. New assignments are not a measured accuracy score.
Dense remixes can defeat word recognition. Automatic language selection can also fail on instrumental openings.
Short chants, bridges, pre-choruses and boundaries need further review. The earlier five R35 EOF failures remain outside this selected successful-source sample.

Rejected evidence remains local under `TestBuilds/ipad/R37/`.
The acoustic-only experiment matched the backing loop. A smaller quantised model repeated invented text.
Forcing suppression of non-speech output made the final model repeat the hook over later verses.
The shipped settings allow non-speech output. The exact native run then recovers the three verse passages and three main hooks.

## Reproduce

1. Run `python3 tools/prepare_vocal_model.py`.
2. Run `python3 docs/testing/checks/R37/2026-11-04-vocal-form/check.py`.
3. Extract the pinned framework archive with `ditto` to preserve its macOS symlinks.
4. Compile the focused native probe with `tools/analysis_review/compile_vocal_probe.py`.
5. Run `review_vocal_form.py` against the saved R35 report.
6. Replay final role assignments with its `--replay` option.

The older `CorpusProbe.swift` remains an acoustic-only baseline tool. Its output now states that the vocal-form pass did not run.
