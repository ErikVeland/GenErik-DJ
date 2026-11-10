# R129: Downbeat recovery and first-pass speed

The final Mac first pass took **128.97 seconds**, down from **307.66 seconds**, on the same 12 tracks. First pass plus deep analysis took **278.17 seconds**, down from **454.67 seconds**. These are observed diagnostic timings, with model startup included.

Version 12 adds limited recovery of rejected rhythm proposals. On newly reserved GTZAN recordings, review downbeat event F1 rose from **56.22% to 57.40%**. Three tracks improved and two worsened. Recovered grids require review and have no numerical confidence estimate.

## Same-track accuracy and human corrections

Erik's corrections move the saved Traktor reference later in each track. The [correction record](../testing/analysis-human-bar-corrections-r129.json) binds each statement to the exact audio hash. Original comparisons remain available.

| Track | Reference correction | Final result |
| --- | --- | --- |
| 99 Problems | One beat later, retained from R109 | Correct bar choice, about 26 ms from the reference |
| Big Ole Freak | Two beats later | Agrees within 25 ms |
| Fuck You, Rhythm Scholar Remix | One beat later | Agrees within 25 ms |
| Untouched | One beat later | Still approximately two beats early |
| ...In The End, Dune | Half a beat later at the confirmed 80 BPM level | Correct tempo level, roughly 170 ms beat-phase error, bar unresolved |

The corrected baseline and final app both have 6/9 downbeats within 25 ms. Tempo agreement remains 9/9 and key agreement remains 6/9. The largest playback-event change between the baseline and final app is 0.365 ms. Exact harmonic features, waveforms and final key choices stayed unchanged on all 12 tracks.

These human checks establish relative beat or bar position. They do not establish precise onset timestamps, exact tempo precision or key accuracy. The remaining Traktor labels include automatic results.

An interim update incorrectly reported a 7/9 baseline and attributed the 6/9 result to acceleration. A direct comparison and a fresh CPU control exposed that reporting error. Untouched's wrong bar and Dune's unresolved bar already occur in the stored baseline. Erik received the correction. The final app retains the validated acceleration path. Earlier interpretations remain in the raw history and are superseded by the [final verification record](../testing/analysis-first-pass-r129-results.json).

## First-pass speed

| Stage, all 12 tracks | R124 CPU baseline | Optimised CPU control | Final accelerated first pass |
| --- | ---: | ---: | ---: |
| First-pass wall time | 307.66 s | 220.32 s | 128.97 s |
| Decode and audio features | 125.38 s | 65.05 s | 64.70 s |
| Beat-model inference | 151.91 s | 124.89 s | 18.45 s |

The final model-loading total was 19.69 seconds. Core ML requested CPU + Neural Engine execution. Per-operator hardware placement was not profiled.

A separate consecutive CPU comparison on Blue Monday reduced decode and feature time from 8.70 to 5.42 seconds. First-pass output matched exactly in that pair. All 12 CPU-control musical decisions stayed unchanged. Two tracks had floating-point differences below 1e-9 in stored numeric values.

The two accelerated full-track first passes took 158.11 and 128.97 seconds. OS caches and other host activity were not controlled. These timings do not establish Duo throughput or A10X performance.

## Frozen benchmark and recovery results

The prior 394 rhythm excerpts were development and regression data. We reserved 100 previously unscored GTZAN recordings and 80 Ballroom diagnostics before tuning. GTZAN audio hashes and recording identities differ from prior cohorts. Every selected recording shares an artist with earlier cohorts. The GTZAN set is not artist-disjoint.

GTZAN reference SHA-256: `d4a7b34a0240d4a5522427eaa7261669faa4ee47fc0be697b6dbd490631855f4`.

Ballroom reference SHA-256: `842fd06fcfb5716664d018ceecca0aa57fabec52b937a98a37805a10aab61d47`.

Ballroom selection excludes published recording replicas and audio duplicates. Three-beat metres remain included. Artist identity is unavailable. Ballroom was in upstream model training, so it is additional diagnostic evidence. The [model authors describe training coverage](https://github.com/CPJKU/beat_this#available-models). The [annotation authors describe the manual reference process](https://github.com/CPJKU/BallroomAnnotations#annotation-strategy).

The declared qualification rule required improved review downbeat F1 on the new GTZAN recordings, with unchanged playback timelines in policy replay. The candidate passed. No algorithm tuning followed these scores.

| Cohort | Tracks with bar labels | Previous review F1 | Policy 12 review F1 | Improved / worsened tracks |
| --- | ---: | ---: | ---: | ---: |
| R116 development | 100 | 60.48% | 61.91% | 6 / 1 |
| R116 former holdout | 100 | 57.47% | 58.95% | 5 / 0 |
| R118 former independent set | 100 | 62.71% | 65.10% | 5 / 0 |
| R124 former fresh set | 94 | 80.40% | 80.34% | 4 / 3 |
| New GTZAN recordings | 99 | 56.22% | 57.40% | 3 / 2 |
| New Ballroom diagnostics | 80 | 66.89% | 67.32% | 1 / 0 |

These are event scores at a 25 ms tolerance, not percentages of fully correct tracks. One new GTZAN recording has beat labels only. A paired bootstrap over 60 artist and recording groups gives a descriptive 95% interval of −0.21 to +3.08 percentage points. The observed gain does not establish a reliable improvement across other libraries.

A fresh accelerated run also checked all 180 new excerpts. First-pass downbeat F1 changed from 53.49% to 53.64% on GTZAN and from 64.60% to 64.74% on Ballroom. Beat scores had one paired gain and one paired loss in each set. Harmonic features, waveforms and final key choices stayed unchanged across these excerpts and the 12 original tracks. Rhythm-dependent energy values changed on 12 inputs.

## Implementation and versions

Keep existing valid rhythm candidates. Recovery runs only after the original fitter fails. It permits sparse missed beats with the existing 12% interval tolerance and a 5% insertion limit. Bar recovery requires a positive winner, a logit margin of two, at least four supporting groups and 90% agreement. Existing compression, tempo, audio-coverage and cancellation bounds remain.

The 42 recovered candidates have no numerical confidence. Calibration version 2 still applies only to unchanged original candidates. Deep generation and decision policy 12 identify the new behaviour. Compatible model predictions and key windows remain reusable. Manual, imported and accepted preparation retain priority.

Mac foreground analysis now uses the existing accelerated model path on capable hardware. The iOS policy remains unchanged. The spectral transform uses bounded array access and reusable prefix storage. It retains the same arithmetic, precision and sample coverage.

## Verification and remaining work

All 574 policy-replay results reopened. First-pass decisions and playback timelines stayed unchanged. All 1,146 beat windows and 574 key windows were byte-identical to their inputs. The 323 existing adaptive candidates retained their evidence and confidence. Final key choices stayed unchanged.

The final package repeated the 180 fresh policy replays, all 12 original tracks and both drift fixtures. The drift fixtures remain within 2.493 ms across 128 beats. The final package includes the consolidated progress-reporting changes.

Thirty-two focused tests passed. One optional actual-model unit test was skipped. Packaged-app runs exercised the actual models. A wider earlier filter exposed two unrelated failures: exact floating-point assertions in key transposition and an unavailable-item browser fixture. They were reproduced in isolation, with unchanged source hashes. Their logs remain preserved.

The first replay checker compared omitted waveform bins with full waveform data. The second assumed every track had downbeat labels. Both stopped before qualification. Corrected checks compare every retained field, both timelines and only labelled events. An interrupted build and all subsequent attempts remain preserved.

Untouched's bar choice, Dune's phase, precise full-track references, calibrated recovery confidence, stronger independent validation, physical result sharing and device performance remain open. Mac results do not establish live A10X acceptance.

## Evidence

The final app ran source `b13f33c446d7312022ad73b430d8fb1c69b7e0cb`. The [verification record](../testing/analysis-first-pass-r129-results.json) contains source, app and report hashes, scores, timing, paired losses and limits.

Frozen benchmark identifiers retain R128 because that identifier was reserved before the controller request took it. The analysis request is R129. Raw evidence remains under `TestBuilds/r128/` in the authorised analysis worktree. Consolidated copies use `TestBuilds/r129/`. `AcceptedPolicy12.app` is the final package. `FinalPolicy12.app` is the retained CPU control. `Policy12.app` is the first accelerated candidate.
