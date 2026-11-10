# R129: Downbeat recovery and first-pass cost

Continue from R124 in the authorised analysis worktree. Erik requested Mac app tests and the same full-track comparisons. Preserve manual, imported and accepted preparation. No device installation is part of this check.

## Frozen validation scope

Use the previous 394 rhythm excerpts for development. Reserve 100 previously unscored GTZAN recordings before R129 tuning. Audio and recording identities differ from the prior cohorts. All 100 artists overlap earlier cohorts because R124 consumed the remaining artist-disjoint components. Do not describe this set as artist-disjoint.

The new GTZAN reference hash is `d4a7b34a0240d4a5522427eaa7261669faa4ee47fc0be697b6dbd490631855f4`. Selection uses a fixed hash seed and genre balance, without analysis results.

Reserve 80 Ballroom excerpts as additional diagnostics. The reference hash is `842fd06fcfb5716664d018ceecca0aa57fabec52b937a98a37805a10aab61d47`. Exclude published recording replicas and exact audio duplicates. Keep three-beat metres in the diagnostic set. Artist identity is unavailable.

Ballroom was part of upstream model training. Its scores measure new policy behaviour on new diagnostic inputs, not generalisation to unseen model data. The [model authors describe this distinction](https://github.com/CPJKU/beat_this#available-models). The [Ballroom annotation authors describe manual bar labels and corrected beat times](https://github.com/CPJKU/BallroomAnnotations#annotation-strategy).

Do not score either new reference set until the native candidate is frozen. Enable the recovery policy only if review downbeat event F1 improves on the new GTZAN recordings. Preserve first-pass and playback timelines in the replay comparison. Record paired losses as well as gains. Keep a failed candidate and its evidence if qualification fails.

## Fixed implementation hypotheses

The R124 first pass spent 151.91 seconds in beat-model inference and 125.38 seconds in decoding and feature extraction on the original 12 tracks. The Mac path requested CPU-only execution. Test the existing foreground Neural Engine path on capable Macs, with the existing CPU fallback and cancellation rules. Older hardware retains the CPU path.

A CPU sample of the production app found repeated Swift array-access checks in the spectral transform loop. Use bounded buffer access and reusable prefix storage. Retain the transform, sample coverage, arithmetic and musical decisions. Compare harmonic features directly against the previous app.

For rhythm, retain every candidate accepted by the existing fitter. Recovery runs only after that fitter fails. Permit one to three beat intervals, with each inferred interval within the existing 12% tolerance. Limit inserted beats to 5% of observed beats, allowing one insertion on a short excerpt.

If the original bar peaks still fail, compare downbeat logits within each four-beat group. Require a positive winning peak, a logit margin of at least two, at least four supporting groups, and 90% agreement on one bar position. Reject ambiguous two-beat and unsupported three-beat patterns. Keep compression, anchor, tempo, cancellation and audio-coverage bounds.

Recovered grids remain review candidates. They have no numerical confidence estimate because calibration version 2 did not use this decoder. Existing candidates retain their calibrated evidence. Deep generation and decision policy 12 identify the change while retaining compatible prediction windows.

## Required measurements

Replay the previous rhythm cohorts and the frozen new inputs through the packaged Mac app. Compare a fresh accelerated first pass with the baseline first pass. Repeat the same 12 full tracks and both drift fixtures. Verify source hashes, saved-result reopening, unchanged key features, bounded timing and preparation authority. Record app and source identities for each result.

Fresh host timing comparisons remain observational. Mac results do not establish Duo throughput, physical result sharing or A10X live acceptance.

Frozen benchmark identifiers retain R128. The analysis request is R129 because the controller request owns R128. Raw analysis evidence remains under `TestBuilds/r128/` in this worktree. Consolidated copies use `TestBuilds/r129/`.

## Recovery qualification

The frozen native candidate passed the declared GTZAN qualification rule. Downbeat event F1 rose from 56.22% to 57.40% on the 99 newly reserved recordings with downbeat labels. Three tracks improved and two worsened. The remaining recording has beat labels only. No algorithm changes followed these scores.

These are event scores at a 25 ms tolerance. They are not the percentage of fully correct tracks.

| Cohort | Tracks with bar labels | Previous review F1 | Policy 12 review F1 | Improved / worsened tracks |
| --- | ---: | ---: | ---: | ---: |
| R116 development | 100 | 60.48% | 61.91% | 6 / 1 |
| R116 former holdout | 100 | 57.47% | 58.95% | 5 / 0 |
| R118 former independent set | 100 | 62.71% | 65.10% | 5 / 0 |
| R124 former fresh set | 94 | 80.40% | 80.34% | 4 / 3 |
| New GTZAN recordings | 99 | 56.22% | 57.40% | 3 / 2 |
| New Ballroom diagnostics | 80 | 66.89% | 67.32% | 1 / 0 |

Policy replay preserved first-pass decisions and playback timelines on all 574 recordings. All saved results reopened. All 1,146 beat windows and 574 key windows were byte-identical to their inputs. The 323 existing adaptive candidates retained their evidence and confidence. The 42 recovered candidates have no numerical confidence. Final key choices stayed unchanged.

The replay report omits waveform bins by design. The first checker attempt stopped because it compared those empty bins with a full baseline waveform. The second stopped on the GTZAN recording without downbeat labels. The corrected checker compares every retained first-pass field and both timelines. It counts downbeats only where labels exist. Both failed attempts remain in the evidence folder.

## Human reference corrections

Erik checked these bar positions against the saved Traktor references. Positive shifts move the reference later in the track.

| Track | Reference correction |
| --- | --- |
| 99 Problems | One beat later, retained from R109 |
| Big Ole Freak | Two beats later |
| Fuck You, Rhythm Scholar Remix | One beat later |
| Untouched | One beat later |
| ...In The End, Dune | Half a beat later at the confirmed 80 BPM metrical level |

The [correction record](../testing/analysis-human-bar-corrections-r129.json) binds each statement to the exact audio hash. Original Traktor comparisons remain available. These checks establish relative beat or bar position. They do not establish precise onset timestamps, exact tempo precision or key accuracy.

Updating these reference labels raises the previous app's strict downbeat agreement from 4/9 to 7/9. GenErik already chose the corrected bars on Big Ole Freak, the Cee-Lo remix and Untouched. The corrected 99 Problems bar remains 26.43 ms from the saved reference, just outside the 25 ms limit. Dune retains a roughly 170 ms phase error after its 80 BPM correction. Its neural peaks also favour the wrong phase. No track-specific offset was added.

## Accelerated first-pass candidate

The CPU + Neural Engine candidate reduced the same-track first pass from 307.66 to 158.11 seconds. This total includes 20.20 seconds for initial model loading. Beat inference fell from 151.91 to 16.65 seconds. The deep pass took another 169.44 seconds. These are observational Mac timings.

The full-track comparison rejected this acceleration change. Untouched moved to the wrong bar. Dune retained 80 BPM but lost its downbeat proposal. Corrected downbeat agreement fell from 7/9 to 6/9. Tempo agreement remained 9/9 and key agreement remained 6/9.

Restore the previous Mac first-pass model and retain the spectral CPU optimisation. Deep Neural Engine analysis and the existing iOS execution policy stay available. A focused test now checks that Mac foreground analysis retains the qualified first-pass model. The archived accelerated app and its failed accuracy evidence remain available for model work.
