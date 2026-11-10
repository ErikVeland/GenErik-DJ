# Analysis accuracy: R103

R103 follows the [R94 Mac measurement](mac-analysis-audit.md). Use the same 12 files and nine compatible saved references. The manifest and audio hashes remain unchanged.

The [R109 follow-up](analysis-adaptive-r109.md) fixed the adaptive-candidate failure and its bar-coordinate error. It also records Erik’s correction to the 99 Problems reference.

Erik clarified the reference status on 9 November 2026. The Traktor grids combine automatic results and his manual corrections. The keys are Traktor's automatic results. Individual grid provenance is unknown. Report agreement with these references, not independently verified musical accuracy.

## Changes

- **Opening downbeats:** Allow small timing errors in the first supported four-bar run. Limit this tolerance to 150 ms or one fifth of a beat, whichever is smaller. Keep the full-track agreement and residual gates. A half-beat or whole-beat displacement must still fail.
- **Key selection:** Retain a borderline whole-track candidate only when at least three tonal sections provide majority support and the candidate has a sufficient lead. Retain its measured confidence. An independent key below 0.25 confidence requests review. Manual and imported key authority remains unchanged.
- **Tempo octaves:** When the small model cannot fit a grid, compare the fallback tempo and its half/double against consecutive predicted beats. Require sufficient support across at least three 30-second windows. A correction preserves the fallback beat phase, removes the downbeat claim and caps confidence below automatic bar acceptance. This does not establish a reliable fixed grid.
- **Deep tempo evidence:** If the larger model cannot fit a bar grid, retain a separate tempo candidate. An octave correction can replace an automatic DSP fallback only. It cannot replace a fitted model grid, imported grid, adaptive grid or manual preparation. The result follows the existing automatic sharing path and still requests downbeat review.

The tempo decision uses existing model output. It adds no model inference. Long mixes and adaptive grids do not receive this correction.

## Versions and existing libraries

The first-pass configuration changes to `beat-this-small0-grid-2-tuned-hpcp-2`. The small-model decision version changes from `fit1` to `fit2`. The weights and preprocessing remain unchanged.

Deep analysis uses generation 3 and decision policy 3. Its inference ID remains unchanged, so existing prediction windows can be reused. Earlier policy results remain on disk. The changes recover supported grids after small opening timing errors and retain tempo evidence when a downbeat remains unknown.

Previously unresolved keys can receive the new matching pass. Previously automatic small-model fallback grids can also receive a tempo review. Manual, edited, locked, imported and adaptive grids remain protected. Accepted deep grids remain protected during matching refresh.

## Verification

Three failure cases were reproduced before the fixes: opening timing wobble, supported borderline keys and octave selection. Existing contradictory-opening tests remained in the focused checks. Additional checks cover ambiguous tempo evidence, cancellation, manual preparation and key authority.

The opt-in `AnalysisAccuracyProbeTests.swift` checks source hashes and exports diagnostic features. Its frame-key votes use untuned frame chroma and are not the production key-stability measure.

Thirty-seven focused tests passed across 46 cases. Five report-scoring tests passed. The checks cover key authority, earlier key-history records, octave ambiguity, offbeat percussion, cancellation, checkpoint reuse and automatic sharing. Sharing was checked locally, not between physical devices.

One additional drifting-tempo fixture failed. Its candidate was 2.990862 seconds early at beat 120. The archived R94 Mac app reproduced the same error with the same fixture code. Its executable hash matched the recorded baseline. This pre-existing adaptive-candidate error remains unresolved. The candidate is not accepted automatically as performance preparation. Evidence is in `drift-baseline/comparison.json` and `deep-tempo-green.log`.

The first release Mac comparison used policy 2. Exact key agreement rose from 5/9 to 6/9. Tempo stayed at 8/9 and downbeats at 4/9. First-pass work took 326.53 seconds. Deep work took 97.40 seconds. This attempt did not resolve the tempo octave. Its report and tested app remain preserved.

## Final Mac comparison

The release Mac app completed all 12 original files, containing 78.23 minutes of audio. All audio hashes matched R94. All 164 prediction windows were byte-identical to the baseline predictions. The weights and model output did not change. The decision rules changed.

| Measure against nine saved references | R94 baseline | R103 final |
| --- | ---: | ---: |
| BPM within 0.1 | 8/9 | 9/9 |
| Exact key | 5/9 | 6/9 |
| Beat phase within 25 ms | 7/9 | 7/9 |
| Downbeat within 25 ms | 4/9 | 4/9 |
| Maximum full-track grid error within 25 ms | 7/9 | 7/9 |

Nine full grids and one tempo-only correction were accepted across the 12 files. All 12 saved results reopened unchanged. Reopening them took 0.010 seconds in total.

“…In The End” changes from 160.018 to 80.009 BPM after the deep pass. The larger model's independent spacing estimate is 79.956 BPM. The accepted correction halves the existing fitted tempo and retains its beat position. The downbeat stays unknown. Beat phase still differs from the saved reference by about 205 ms. This is a tempo improvement, not a complete mix-ready grid.

“99 Problems” now returns E major at 0.179 confidence and requests key review. Its recovered deep grid reduces maximum reference drift from 40.37 to 37.13 ms. Initial beat-phase disagreement increases from 26.39 to 29.59 ms. Its downbeat remains about one beat away from the saved reference.

“I Like It” has a downbeat-phase difference of 0.87 ms, previously 5.56 ms. Its maximum full-track difference increases slightly, from 5.56 to 6.65 ms. Both stay within the 25 ms limit.

The other final tempo and key choices remain unchanged. Downbeat disagreements remain for “99 Problems,” “Big Ole Freak,” the CeeLo remix and “Untouched.” “…In The End” has no accepted downbeat. Relative major/minor key disagreements remain for “3Cag,” “Groove Is In The Heart” and the CeeLo remix. These need listening review before they can serve as known-correct labels.

| Measured work | R94 baseline | R103 final |
| --- | ---: | ---: |
| First pass | 310.24 s | 325.75 s |
| Additional deep pass | 108.00 s | 96.94 s |
| Combined analysis | 418.24 s | 422.70 s |
| Entire audit process | 432.93 s | 437.64 s |

Thermal state remained nominal. Peak process RSS was 563.59 MiB. These are individual runs on a shared Mac, with fresh analysis caches and ordinary operating-system caches. Per-track times varied substantially. The measurements do not establish a speedup or a meaningful slowdown. They do not measure normal queue throughput, audio deadlines or UI response.

## Source and evidence

The tested source was committed to `main` before packaging:

- Source commit: `1595eb81c315dcc567026c13499d89ed11b6b3b3`.
- Source SHA-256: `eb54943a7e8b2c02e9f50b79bef293ce0e85711d6ec3788b3ef392b45b171c2d`.
- App SHA-256: `e7dfe2411246158fbbbc34aa2f6b373103d3814d7b0665223c370fb3c3813d27`.
- Final run: `27EECB5E-AFDA-4E40-AC9D-CC101F4991EC`.

Evidence is archived in the primary checkout at `TestBuilds/r103`. It includes both Mac runs, the tested apps, reports, source hashes, failed checks and the baseline drift reproduction. The original working evidence remains in the authorised worktree at `TestBuilds/r97`. That directory predates resolution of the request-ID collision.

The packaged app uses local SwiftPM resources. It is a local Mac diagnostic, not a portable distribution package. This chat did not deploy to iOS or verify physical iPad/Duo transfer. Downbeat accuracy, independent key labels, the adaptive-candidate failure and device performance remain open.
