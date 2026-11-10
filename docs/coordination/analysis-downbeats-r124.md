# R124: Downbeats, confidence and audio preparation

Continue from the measured R118 engine. Use the existing authorised worktree and Mac app audits. Preserve manual, imported and accepted preparation. Keep full-grid changes subject to review.

## Fixed experiment scope

Use all 300 previously measured rhythm excerpts for development and regression comparisons. They are no longer fresh validation data. Reserve the 94 remaining eligible artist, recording and audio components before development. Their frozen reference hash is `1897a9eac2b8266ab9e45c0705d17dbfa8fda32ce20882b52a6b82778c93c332`.

The key model, model weights, acceptance threshold and feature definition remain unchanged. Test feature equivalence on the original files and decoded PCM. Compare production feature timings without profiling, using the same source files and background worker.

The CPU sample identifies repeated decoding as the main key-feature cost. Five readers independently decode the source. Share one bounded source stream and one resampler per rate. Advance consumers together, including across saved-window gaps. Verify that decoded source frames never exceed the source length and buffers stay bounded.

For rhythm, test parabolic interpolation around isolated model peaks. Retain plateau centres and the existing 8 ms review correction. Do not change the first-pass timing or tempo-octave rule. Development probes found no gain from changing bar-phase votes or allowing missing bar peaks. Keep those rules unchanged.

For confidence, compare a fixed regularised logistic estimator with the previous two-bin rule. Use beat strength, peak curvature, bar-phase contrast, interval variation, constant-fit residual and strong-fit status. Develop with the three previous cohorts as separate cross-validation folds. Train final coefficients only on completed native development results. Retain the 20–35 second domain. Freeze coefficients before inspecting the 94 new reference scores. Enable a confidence update only if it improves Brier loss against the R118 rule on fresh validation. Otherwise, keep numerical confidence unresolved for the new policy.

Repeat the 178-key benchmark, all prior rhythm cohorts, the 94 fresh excerpts, the same 12 full tracks and both drift fixtures. Verify saved-result reopening, policy replay and key-window repair. Preserve failed and incomplete results. Bind comparisons to source, app, resource, model and report hashes. Mac measurements do not establish Duo throughput or A10X acceptance.
