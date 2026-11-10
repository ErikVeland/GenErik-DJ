# R124: Downbeats, confidence and audio preparation

Continue from the measured R118 engine. Use the existing authorised worktree and Mac app audits. Preserve manual, imported and accepted preparation. Keep full-grid changes subject to review.

## Fixed experiment scope

Use all 300 previously measured rhythm excerpts for development and regression comparisons. They are no longer fresh validation data. Reserve the 94 remaining eligible artist, recording and audio components before development. Their frozen reference hash is `1897a9eac2b8266ab9e45c0705d17dbfa8fda32ce20882b52a6b82778c93c332`.

The key model, model weights, acceptance threshold and feature definition remain unchanged. Test feature equivalence on the original files and decoded PCM. Compare production feature timings without profiling, using the same source files and background worker.

The CPU sample identifies repeated decoding as the main key-feature cost. Five readers independently decode the source. Share one bounded source stream and one resampler per rate. Advance consumers together, including across saved-window gaps. Verify that decoded source frames never exceed the source length and buffers stay bounded.

For rhythm, test parabolic interpolation around isolated model peaks. Retain plateau centres and the existing 8 ms review correction. Do not change the first-pass timing or tempo-octave rule. Development probes found no gain from changing bar-phase votes or allowing missing bar peaks. Keep those rules unchanged.

For confidence, compare a fixed regularised logistic estimator with the previous two-bin rule. Use beat strength, peak curvature, bar-phase contrast, interval variation, constant-fit residual and strong-fit status. Develop with the three previous cohorts as separate cross-validation folds. Train final coefficients only on completed native development results. Retain the 20–35 second domain. Freeze coefficients before inspecting the 94 new reference scores. Enable a confidence update only if it improves Brier loss against the R118 rule on fresh validation. Otherwise, keep numerical confidence unresolved for the new policy.

Repeat the 178-key benchmark, all prior rhythm cohorts, the 94 fresh excerpts, the same 12 full tracks and both drift fixtures. Verify saved-result reopening, policy replay and key-window repair. Preserve failed and incomplete results. Bind comparisons to source, app, resource, model and report hashes. Mac measurements do not establish Duo throughput or A10X acceptance.

## Implementation and versions

Deep generation and decision policy 11 refine isolated beat and bar peaks between the model's 20 ms frames. Flat peaks retain their original centres. The existing 8 ms review correction and bar-spacing rules remain. The tempo-octave rule and first-pass engine remain unchanged.

Rhythm evidence version 1 stores six measurements separately from timing. Calibration version 2 uses the frozen regularised logistic model. Its identity includes the SHA-256 of [the training record](../testing/analysis-r124-rhythm-calibration.json). A calibration change invalidates the final result identity while retaining compatible neural prediction windows. Missing evidence, unknown versions and tracks outside 20–35 seconds have no calibrated estimate.

The key frontend now decodes each source once. It shares three rate converters across the five filter groups. Each rate advances with the others, including across saved-window gaps. The source buffer has a fixed bound. Cancellation stops preparation before further decoding. The key model, weights, feature definition and acceptance threshold retain their R118 versions.

## Rhythm and confidence evidence

The frozen R124 reference contains 94 previously unused excerpts. Artist, recording and audio components are disjoint from the previous 300 excerpts. The set has 35 disco, 20 country, 13 pop, 10 metal, seven hip-hop and three each of classical, reggae and rock. It contains no blues or jazz. Commit `d16c78147` froze the confidence coefficients before the R124 reference scores were inspected. The training tool accepts only complete prior cohorts. A diagnostic check rejected the reserved validation set as training input and reproduced the frozen fit exactly.

Review downbeat F1 measures matched events within 25 ms. It assumes acceptance of every offered review candidate. It is not the percentage of fully correct tracks.

| Cohort | Tracks | R118 review downbeat F1 | R124 review downbeat F1 |
|---|---:|---:|---:|
| R116 development | 100 | 59.74% | 60.48% |
| R116 former holdout | 100 | 57.36% | 57.47% |
| R118 former validation | 100 | 62.11% | 62.71% |
| Fresh R124 validation | 94 | 80.53% | 80.40% |

The timing gains on prior data did not generalise to the fresh set. Retain this limitation when describing the change. Do not claim a universal downbeat improvement. Full grids remain review candidates. Manual, imported and accepted preparation remain protected.

The confidence target requires both beat and downbeat event F1 to reach 95% within 25 ms. Training used 159 available candidates from the previous 300 excerpts. Leave-one-cohort-out Brier loss fell from 0.238 for refitted two-bin estimates to 0.214 for the new model. Each of the three folds improved.

Fresh validation offered 64 candidates. The new confidence model reduced Brier loss from 0.233 to 0.174 against the R118 rule on those same candidates. Mean predicted success was 52.0%, against 50.0% observed success. Four of 27 candidates below 50% confidence passed the target. Twenty-eight of 37 candidates above 50% passed. No candidate reached 80% confidence. These estimates remain imperfect and do not authorise automatic grid replacement.

The final Mac app reproduced all 223 calibrated probabilities across the four cohorts. Maximum difference from the frozen Python model was `2.22e-16`. Native feature extraction matched the development calculation for all 159 training candidates.

## Audio preparation evidence

A production CPU sample identified repeated decoding as the main frontend cost. The previous reader decoded the source independently for five filter groups. The new reader uses one shared source.

A sequential, unprofiled comparison used the same 12 full tracks and reused their first-pass and beat predictions. Total key-feature preparation fell from 113.95 to 39.36 seconds, approximately 2.9 times faster. Key choices and acceptance decisions stayed the same. Some prediction scores differed by up to `5.90e-5`. Other host activity and OS caches were not controlled.

Standalone feature comparisons were bit-identical for 11 of the 12 files. The remaining file had a maximum feature difference of `2.02e-7`. The streaming tests cover stereo 44.1 kHz and 48 kHz sources, a long skipped window range, bounded decoding and cancellation. They reproduced the old repeated-decoding defect before the change.

## Final Mac checks

The final app used source `9d3a20b88f463856efb7511a2befe4726ad11716`. Its source hash is `18c71789465bbb980657ec803e0a7d8a2c2d85ca1278a961f9f7e1ae745c3805`. The result record also contains the app, binary, resource and report hashes. Later controller-only changes to main are not part of this measured source.

All 394 rhythm excerpts, 178 key excerpts, 12 original full tracks and two drift fixtures completed and reopened. All 178 key prediction scores, choices and acceptance decisions matched R118 exactly. Final exact key matches stayed at 60/100 and 56/78.

The original tracks retained their automatic tempo, beat, bar and key choices. Track 06 received a refined review candidate. The tempo-only correction for track 11 remains 160.0182 to 80.0091 BPM, with its downbeat unresolved. Against the nine saved references, counts remain 9/9 tempo, 7/9 beat phase, 4/9 downbeat phase and 6/9 key. The corrected “99 Problems” bar choice agrees with Erik, but its 26.43 ms phase difference still exceeds the strict 25 ms threshold.

| Fresh original-track run | R118 | R124 |
|---|---:|---:|
| First pass | 257.34 s | 307.66 s |
| Deep pass | 203.94 s | 147.00 s |
| Total | 461.28 s | 454.67 s |
| Key-feature preparation within deep pass | 108.89 s | 36.35 s |

These are observational host timings. The first-pass code did not change. The whole-engine gain is much smaller than the isolated feature-preparation gain.

Both drift fixtures retain 33 anchors and their original bar offsets. Maximum timing error remains 2.4932 ms. Identical decoded PCM produced bit-identical features. The repair check recomputed one damaged and one missing key window, reused the other two, and restored all window bytes and the final result exactly. It did not repeat beat inference.

Twenty-two focused Swift tests passed. One optional model test was skipped. Production Mac audits exercised the actual models. Twenty benchmark tests and six report tests passed. The Swift test source is recorded separately from the final app source. Missing evidence, unknown calibration versions, invalid values and the full-track confidence boundary were checked.

## Verification scope and remaining work

Use [the measured result record](../testing/analysis-results-r124.json) for final source identities, hashes, scores and timings. Preserve the raw reports, failed checks, application, resource bundles and scripts under `TestBuilds/r124/`.

Mac diagnostics do not establish Duo throughput, physical iPad sharing or A10X live performance. Confidence on full tracks remains uncalibrated. Future rhythm development needs new disjoint references, especially full tracks, ambiguous half-time material and manually checked bar positions. All 394 rhythm excerpts have now been inspected. Do not describe them as fresh validation in later work.

The original Traktor references remain a mixture of automatic and possibly corrected grids. Erik confirmed only that the Traktor bar for “99 Problems” is one beat early. Exact beat timing and key labels for those tracks remain unverified.
