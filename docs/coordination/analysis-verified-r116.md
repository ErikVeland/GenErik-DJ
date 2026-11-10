# R116: Verified analysis benchmark

Erik requested a verified benchmark before rhythm and learned key changes. Mac app testing is authorised in the existing analysis worktree.

## Implementation order

1. Pin published human annotations and match each audio file to the source checksum. Record label scope for each field.
2. Freeze artist and recording groups before model evaluation. Keep development, holdout and the original 12-track regression set separate.
3. Test the scorer with missed beats, extra beats, half tempo, failures, hash changes and split overlap.
4. Record the actual first-pass and final playback timelines in the production Mac audit. Keep reference answers outside the analysis input.
5. Run the unchanged production engine on the development cohort. Preserve source, model, input and application hashes.
6. Evaluate rhythm and learned key candidates on development data. Change production decisions only when measured results support them.
7. Run the selected candidate on frozen holdout data and the same 12 regression tracks. Preserve failed runs and report coverage.

## Evidence rules

Published human annotations are reference labels with a named source. They are not personal listening checks by Erik. Key changes, modal labels and uncertain labels must remain visible. They must not become ordinary major/minor labels by truncation.

The original Traktor values remain automatic comparisons. Erik verified only that its 99 Problems bar starts one beat early. This does not verify its exact beat time, tempo or key.

The benchmark counts missing outputs as failures. Beat and downbeat scores use one-to-one event matching at 25 ms, including annotated opening beats. Half-tempo predictions lose recall. Double-tempo predictions lose precision. Exact key scores remain separate from related-key credit. Confidence and coverage must be reported together.

GTZAN has known duplicates and repeated artists. Use its published fault-filtered groups and exclude unknown identities from the initial cohort. Beat This final and small models declare GTZAN excluded from training. Other dataset and model overlap must be recorded explicitly.

The initial benchmark uses short excerpts. It cannot establish whole-track drift, long-mix performance or live A10X readiness. The existing full-length regression tracks and adaptive fixtures remain required.

## Status

The frozen corpus contains 200 GTZAN rhythm excerpts and 178 GiantSteps+ key excerpts. Development uses 100 excerpts from each dataset. Holdout contains 100 rhythm and 78 key excerpts. The source files match the published checksums. Artist components remain separate across splits.

GTZAN selection uses 913 eligible files after fault and identity exclusions. One downloaded file also failed its audio checksum. GiantSteps+ selection uses 264 eligible files. Missing metadata, uncertain keys, non-standard modes and annotated key changes exclude the other 336 files. These exclusions limit the scope of the single-key score.

The first production Mac baseline completed all 100 rhythm development excerpts. All saved deep results reopened correctly. Source commit: `fee71c1e62488aeaa847fd5d4d11163cf8138e3b`. Source hash: `7c44804f6d18efe8705875727b871c5c27226613f0ba822763bf5dc4ceff51d0`.

At 25 ms, accepted playback events scored 63.99% beat micro-F1 and 53.95% downbeat micro-F1. The raw deep-model events scored 74.51% and 64.01%. These scores count matched, missing and extra events. They are not percentages of fully correct tracks. First-pass analysis took 290.16 seconds and deep analysis took 92.33 seconds for 50.04 minutes of audio. These are host diagnostics, not queue or live-performance timings.

The model-to-grid gap is largest on variable-tempo music and unsupported bar lengths. In `gtzan:rock.00059`, the model matched every annotated beat, but the four-beat grid fitter produced no tempo. A constant-pulse recovery probe failed the timing limits because this excerpt also drifts. No recovery policy has been adopted from that probe.

The 2018 madmom key CNN is an external evaluation candidate. Its weights use CC-BY-NC-SA-4.0 and are not bundled with the application. Its original and Torch outputs differed by at most 0.000000656 in the conversion check. The FP16 Core ML output differed by at most 0.023923 and retained the predicted key. On decoded PCM, Mac frontend features differed by at most 0.0000036. Candidate weights, conversion, preprocessing and decision policy have separate version fields.

On the same 100 key development files, the production detector matched 49 exact keys. The native learned candidate matched 91. It corrected 45 results and worsened three. Its confidence above 0.8 selected 68 tracks, with 67 exact matches. The candidate took 11.93 seconds in total, excluding model load. This is an extra key pass, not a whole-engine speed comparison. Core ML's compute plan preferred the Neural Engine for all 40 reported operations. Runtime hardware counters were not captured.

The fixed candidate matched 63 of 78 held-out keys (80.77%). The production detector matched 41 (52.56%). The candidate corrected 29 results and worsened seven. Its confidence band from 0.8 selected 55 excerpts, with 50 exact matches (90.91%). It took 9.19 seconds, excluding model load. These lower held-out results limit the development claim. No threshold was adjusted after this comparison. The 100-file rhythm holdout remains untested.

Deep policy 4 added a review candidate when the constant-grid fit failed. In the development run, it offered two candidates. Hypothetical acceptance increased beat F1 from 63.99% to 64.43% and downbeat F1 from 53.95% to 54.36%. All saved results reopened. The actual playback timelines remained unchanged.

Policy 5 also offers alternatives to weak constant fits. The candidate requires consistent four-beat bars and consecutive beat intervals. It compresses the complete model sequence to at most 256 anchors, with at most 8 ms deviation. Unsupported bar lengths and sequences that exceed the anchor limit remain unresolved. The candidate does not replace playback preparation or an existing adaptive candidate. It has no calibrated confidence value. The sharing path carries it as analysis evidence.

The final development run offered nine review candidates. Hypothetical acceptance raised beat F1 to 66.79% and downbeat F1 to 56.46%. Eight candidates improved both scores and one worsened both. All 200 prediction windows matched the baseline bytes. All 100 saved results reopened. The automatic playback timelines stayed equivalent within floating-point rounding. These results support review access, not automatic replacement.

Policy 5 failed the held-out no-regression check. The existing automatic constant-grid rule reduced beat F1 from 57.56% to 54.43%. Downbeat F1 fell from 53.70% to 50.50%. Thirty-one tracks changed event scores after automatic constant-grid updates. The new adaptive candidates were separate: all seven improved both scores when evaluated for acceptance. Their combined review scores were 56.37% and 52.15%. All 100 results reopened without errors. This failed result remains preserved.

Policy 6 contains that failure without tuning model thresholds. Strong deep evidence can fill a missing grid, but it cannot automatically replace an existing usable grid. The separate tempo-octave correction remains unchanged. Compatible evidence does not generate a new review warning merely because replacement is disabled. Previously accepted grids remain intact. This change does not reconstruct their lost first-pass timing.

The Mac policy audit reuses a completed first-pass report and its prediction checkpoints. It verifies audio hashes, inference identity and source coverage. Its output records the source report hash and run ID. Replay timings are not fresh-analysis timings. Policy 6 checks on the same corpus are regression checks after the failed holdout, not new independent accuracy evidence.

The policy 6 replay exposed one false grid fill: `gtzan:metal.00001`. Its high-confidence deep grid matched no annotated beats or downbeats. Policy 7 therefore keeps full constant-grid proposals for explicit review. For a missing grid, a bounded constant candidate uses the existing grid acceptance controls. The first-pass grid remains unchanged. The separate tempo-octave correction still uses its existing evidence rules. Existing accepted grids are not silently reset.

Explicit acceptance can create a missing base grid. Policy 5 preserves strong policy 3 and 4 fits with the same inference profile. It also skips policy 4 results whose missing constant fit was already reviewed. Weak older constant fits can upgrade. The model weights remain unchanged, so these policy upgrades can reuse saved predictions. Changed weights and later policies remain eligible under the existing version rules.

A later first pass retains an offered deep candidate only for the same audio identity. The existing manual, locked, imported and accepted adaptive preparation protections remain in place. Twenty-one focused Swift tests passed. Twenty Python tests passed for the benchmark and key comparison. One optional real-model unit test remains skipped. The packaged Mac audit supplies the real-model evidence separately.

## Model and hardware scope

Tests ran on an Apple M4 Pro Mac with 24 GiB of memory. Core ML preferred the Neural Engine for all 746 operations in the small beat model's inspected plan. The learned key plan preferred it for all 40 operations. Both probes requested CPU and Neural Engine compute units. These are placement plans, not runtime utilisation measurements or Duo timings.

The production Mac first pass requests CPU only. The deep rhythm pass and the external learned-key pass request CPU and Neural Engine units. The small-model plan probe does not change the production first-pass policy. A Mac first-pass acceleration comparison remains separate work.

The learned key weights remain external research assets. No automatic learned-key replacement is enabled. The current licence restricts commercial use. Commercial model selection or training rights remain open. The new model's output scores also need calibration before automatic acceptance.

The native key conversion preserves separate weights, preprocessing, conversion and decision versions. Its audio frontend uses bounded windows. The original 12 files were evaluated with the same fixed candidate. Agreement with nine automatic Traktor keys fell from six to four. This is not a verified accuracy loss. Blue Monday, 99 Problems and Big Ole Freak changed key predictions and need listening review.

This comparison does not establish the strongest available key model. [InceptionKeyNet](https://github.com/stefan-baumann/inceptionkeynet) provides a newer reference architecture and training code. [S-KEY](https://github.com/deezer/skey) provides a 2025 model, but restricts its published weights to non-commercial research. Neither was measured in this increment. Future selection needs a fresh independent test cohort and suitable model rights.

## Reproduce the scores

1. Validate each frozen benchmark with `tools/verified_analysis_benchmark.py validate` and `--verify-audio`.
2. Create an unlabelled run manifest with the tool's `manifest` operation and the required split.
3. Run the packaged Mac app with `--analysis-audit <manifest> <new-output-folder>`.
4. Score the report with the tool's `score` operation, `--report` and `--output`.
5. For the external key candidate, run `--key-candidate-audit <manifest> <model-folder> <new-output-folder>`.
6. Compare its report with `tools/compare_key_candidate.py <benchmark> <baseline-report> <candidate-report> <new-output-file>`.

Keep each run's source, binary, model, manifest and report hashes. Keep failed runs. Do not reuse a scored holdout for tuning. New tuning requires a new independent test cohort.

Evidence is under `TestBuilds/r116`. Rhythm candidate measurements and physical device acceptance remain open. No automatic learned-key adoption is enabled.
