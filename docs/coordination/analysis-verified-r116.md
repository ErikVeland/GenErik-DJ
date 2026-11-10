# R116: Verified analysis benchmark and measured candidates

The benchmark contains 378 source-matched excerpts with published human annotations. The Mac app measured the production baseline and a native learned-key candidate. Rhythm testing exposed an automatic deep-grid regression. Final policy 7 preserves existing grids and keeps full-grid proposals for explicit review.

The learned-key model remains an external evaluation candidate. It is not part of normal library analysis. Physical Duo, iPad sharing and A10X performance acceptance remain open.

## Measured results

Exact key results count both tonic and major/minor mode. Related keys receive no exact credit. Missing keys stay in the denominator.

| Key cohort | Current detector | Learned candidate | Corrected / worsened |
|---|---:|---:|---:|
| Development, 100 excerpts | 49/100 | 91/100 | 45 / 3 |
| Held out, 78 excerpts | 41/78 (52.56%) | 63/78 (80.77%) | 29 / 7 |

The model and confidence bands were fixed before the held-out comparison. At confidence 0.8 or higher, the candidate matched 50 of 55 held-out keys (90.91%). Its output score is not calibrated certainty. Commercial model rights and production acceptance rules remain unresolved.

Rhythm scores below are beat / downbeat micro-F1 percentages at 25 ms. They count matched, missing and extra events. They are not percentages of fully correct tracks.

| Rhythm cohort | First pass | Earlier automatic deep rule | Final automatic policy 7 | If all offered review candidates were accepted |
|---|---:|---:|---:|---:|
| Development, 100 excerpts | 63.39 / 53.16 | 63.99 / 53.95 | 63.39 / 53.16 | 66.20 / 55.69 |
| Held out, 100 excerpts | 57.56 / 53.70 | 54.43 / 50.50 | 57.56 / 53.70 | 59.10 / 54.96 |

The earlier automatic rule failed the held-out no-regression check. Small constant-grid timing changes caused substantial losses on some tracks. The final policy contains that failure without tuning model thresholds. Its results on this same corpus are regression checks, not new independent accuracy evidence.

Development offered nine adaptive candidates. Eight improved both event scores and one worsened both. The held-out set offered seven adaptive candidates, all of which improved both scores. It also offered one constant-grid candidate for a missing grid. That candidate matched no reference events and remains unaccepted. This is why model confidence alone cannot authorise a new grid.

All 200 final rhythm results reopened. The Mac policy replay reused all 400 prediction windows without neural inference. Each window matched its saved source bytes. The actual playback timeline equalled the first-pass timeline on every benchmark excerpt.

## Final engine behaviour

- Preserve existing first-pass timing when a full deep-grid proposal arrives.
- Keep a missing grid visibly unresolved until the user accepts a proposed grid.
- Retain the separate tempo-octave correction and its existing evidence rules.
- Offer bounded adaptive alternatives when a constant fit is missing or weak.
- Carry review candidates through automatic analysis sharing without accepting them on the receiver.
- Preserve manual, locked, imported and accepted adaptive preparation.
- Retain pending deep candidates across a later first pass for the same audio identity.

Adaptive candidates require consecutive beat intervals and consistent four-beat bars. The complete sequence must fit within 256 anchors and 8 ms compression error. The fitter rejects unsupported bar lengths, missing-beat sequences and maps that exceed those bounds. It never truncates the track to fit the anchor limit. Candidates have no calibrated confidence value.

Explicit acceptance can create a base grid when none exists. A constant deep proposal uses the same acceptance controls through a two-anchor map. Previously accepted legacy grids remain intact. This change does not reconstruct their lost first-pass timing.

Deep results now use generation 7 and decision policy 7. Model weights, conversion and preprocessing versions remain unchanged. Policy changes can reuse predictions. Model or preprocessing changes use a separate inference identity. Older results are reconsidered only where the policy can add useful evidence. Completed policy 5 and 6 evidence needs no repeated inference for this containment change.

## Same-track and regression checks

The final fresh Mac run completed all 12 original tracks and reopened every saved result without error. First-pass musical results matched R109 within numerical rounding. The separate tempo-octave rule retained the 80.009 BPM correction. No full constant-grid proposal replaced playback timing automatically.

Against nine saved references, final agreement remained 9/9 for tempo, 6/9 for key, 7/9 for beat phase and 4/9 for downbeat phase. Seven full-track grids stayed within 25 ms of those references. These are regression comparisons, not verified musical-accuracy scores. First-pass analysis took 270.85 seconds. Deep analysis took another 90.26 seconds for the same 78.23 minutes of audio.

Both 128-beat drift fixtures retained the R109 fix. Maximum beat error was 2.493 ms. Error at beat 120 stayed below 1.497 ms, and the delayed fixture retained bar position 2. Both saved results reopened and kept their original adaptive candidates.

Final prediction bytes matched 111 of 164 R109 windows. Differences occurred in M4A files, and some raw peak events changed. The maximum logit difference was 0.1484375. No cause or exact numerical reproducibility is claimed.

The fixed learned-key candidate also analysed the same 12 audio identities. Agreement with nine automatic Traktor keys fell from six to four. This is not verified accuracy loss. Blue Monday, 99 Problems and Big Ole Freak changed key predictions and need listening review.

Erik verified only that the Traktor bar for 99 Problems starts one beat early. That verifies bar choice, not exact beat time, tempo or key. The final downbeat phase differs from that shifted reference by 26.428 ms. It remains outside the strict 25 ms comparison. Other original Traktor comparisons remain unverified.

Twenty-four focused Swift tests passed. Twenty benchmark and key-comparison Python tests passed. One optional real-model unit test stayed skipped. The packaged Mac audits provide separate real-model evidence. Negative Mac replay checks rejected incomplete reports, different inference identities and changed audio. Failed evidence remains saved.

## Benchmark scope and provenance

The frozen corpus contains 200 GTZAN rhythm excerpts and 178 GiantSteps+ key excerpts. Development uses 100 from each dataset. Holdout uses 100 rhythm and 78 key excerpts. Artist, recording and audio-identity groups were split before selection. Duplicate audio is rejected both within and across splits. Reference answers are absent from the app input manifests.

GTZAN selection used 913 eligible files after published fault and identity exclusions. One downloaded file also failed its source checksum and was excluded. GiantSteps+ selection used 264 eligible files. Missing metadata, uncertain keys, non-standard modes and annotated key changes excluded the other 336 files. Every selected audio file matched its published checksum and has a recorded SHA-256.

Published human references are not personal listening checks by Erik. GTZAN labels and group metadata have pinned repository revisions. GiantSteps+ uses revised human key labels with high confidence. The annotation files, source indexes and per-field labels have recorded hashes.

Beat This authors declare GTZAN excluded from training. The key-model authors report distinct GiantSteps MTG training and GiantSteps Key test recordings. Artist overlap with model training data is not established.

Event matching is one-to-one within 25 ms over annotated spans, including annotated opening beats. Half tempo loses recall. Double tempo loses precision. Unresolved outputs stay in the denominator. Exact key and related-key scores remain separate. The excerpts cannot establish whole-track drift, key modulation, long-mix accuracy or gig readiness.

## Models, conversion and speed

Tests ran on an Apple M4 Pro with 24 GiB of memory. The production Mac first pass requests CPU only. The deep rhythm and learned-key passes request CPU and Neural Engine units. Core ML preferred the Neural Engine for all 40 learned-key operations and all 746 operations in a separate small-beat-model plan probe. These are placement plans, not runtime utilisation counters. The probe did not change the Mac first-pass policy.

The first rhythm baseline processed 50.04 minutes of audio in 290.16 seconds for the first pass and 92.33 seconds for deep analysis. Later fresh runs were similar. Audit report writes and compilation are separate overhead. These host measurements do not establish Duo queue speed or live A10X performance.

The learned key pass took 11.93 seconds on development and 9.19 seconds on holdout, excluding model load. Held-out inference took 0.21 seconds. Audio feature preparation took 8.82 seconds. This is an additional key pass, not a whole-engine speed comparison.

The candidate is `madmom-key-cnn-2018-eval1`, with separate weights, preprocessing, conversion and decision versions. Its weights use CC-BY-NC-SA-4.0 and remain outside the application bundle. Original-to-Torch conversion differed by at most 0.000000656 in the parity check. FP16 Core ML differed by at most 0.023923 and retained the predicted key. On decoded PCM, native frontend features differed by at most 0.0000036. MP3 decoder differences are recorded separately.

This comparison does not establish the strongest available key model. [InceptionKeyNet](https://github.com/stefan-baumann/inceptionkeynet) provides a newer architecture and training code. [S-KEY](https://github.com/deezer/skey) provides a 2025 model but restricts published weights to non-commercial research. Neither was measured here. Further selection needs suitable model rights and fresh independent test data.

## Source and evidence

Final tested application source: `6114fcf63f3a033eff879cc48a754f8d0365a957`. Source SHA-256: `33ce5aa8cafc9e71f4fdc936104f10397d0424676087d48eae00b3c7ac5dc5fa`. The feature source was merged into consolidated `main` before packaging.

Frozen references are in `docs/testing/analysis-benchmark-r116-gtzan.json` and `docs/testing/analysis-benchmark-r116-key.json`. The [compact results record](../testing/analysis-results-r116.json) binds each comparison to its source, model and report hashes.

Raw reports, source records, model artifacts, failed attempts, app archives and logs remain under ignored `TestBuilds/r116` in the authorised worktree. The consolidated folder also holds compact evidence and compressed report copies. The archived Mac app still requires the worktree's built resource bundles. It is not a standalone distribution package. No iPad or Duo installation was performed.

## Remaining work

- Obtain suitable model rights and test calibrated rules before replacing normal key analysis.
- Evaluate rhythm candidates on fresh independent material before permitting automatic grid replacement.
- Add full-track listening references, tempo changes and meters beyond the supported four-beat candidate fit.
- Investigate the M4A prediction differences and review previously accepted deep grids where needed.
- Measure throughput on the Duo and verify automatic transfer to the iPad.
- Confirm that background analysis yields before it affects audio or controls on the actual A10X.

## Reproduce the checks

1. Validate a frozen corpus with `tools/verified_analysis_benchmark.py validate` and `--verify-audio`.
2. Create an unlabelled input with the tool's `manifest` operation and the required split.
3. Run the Mac app with `--analysis-audit <manifest> <new-output-folder>`.
4. Score the report with the tool's `score` operation, `--report` and `--output`.
5. Replay a policy with `--analysis-policy-audit <completed-report> <new-output-folder>`.
6. Evaluate external keys with `--key-candidate-audit <manifest> <model-folder> <new-output-folder>`.
7. Compare keys with `tools/compare_key_candidate.py <benchmark> <baseline-report> <candidate-report> <new-output-file>`.

Keep source, binary, model, manifest and report hashes for every run. Keep failed runs. Mark replay timings as reused work. Do not use a scored holdout as fresh validation after further tuning.
