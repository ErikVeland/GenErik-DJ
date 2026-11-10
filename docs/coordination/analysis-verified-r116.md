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

The benchmark counts missing outputs as failures. Beat and downbeat scores use one-to-one event matching at 25 ms, including annotated opening beats. Exact tempo octave and exact key scores remain separate from lenient scores. Confidence and coverage must be reported together.

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

Deep policy 4 adds a review candidate when the constant-grid fit fails. It requires consistent four-beat bars and consecutive beat intervals. It compresses the complete model sequence to at most 256 anchors, with at most 8 ms deviation. Unsupported bar lengths and sequences that exceed the anchor limit remain unresolved. The candidate does not replace playback preparation or an existing adaptive candidate. It has no calibrated confidence value. The sharing path carries it as analysis evidence.

Explicit acceptance can create a missing base grid. Policy 4 upgrades only unresolved policy 3 results with the same inference profile. A resolved constant fit receives no benefit from this policy change. Changed model weights and later policies remain eligible under the existing version rules.

Evidence is under `TestBuilds/r116`. Rhythm candidate measurements and physical device acceptance remain open. No automatic learned-key adoption is enabled.
