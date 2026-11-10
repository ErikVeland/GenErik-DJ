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

Implementation and acquisition are in progress. No new accuracy result or model improvement is claimed yet.
