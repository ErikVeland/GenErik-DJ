# R139: Untouched downbeat and Dune beat phase

The native Mac app now corrects Untouched’s automatic downbeat and Dune’s automatic beat phase. The corrections use audio and model evidence. The analyser contains no track names, reference offsets or audio-specific rules.

| Corrected reference check | R129 baseline | R139 candidate |
| --- | ---: | ---: |
| Untouched downbeat error | 668.581 ms | 9.386 ms |
| Dune beat-phase error | 170.080 ms | 18.629 ms |
| Dune maximum full-track grid difference | 362.337 ms | 18.629 ms |
| Dune tempo | 80.009 BPM | 79.988 BPM |

Untouched keeps its first-pass tempo and every beat position. The deep pass changes the bar offset by two beats. Dune keeps the confirmed 80 BPM metrical level. Its bar remains unresolved.

Erik’s corrections establish relative beat and bar positions. Exact onset times, precise tempo and keys remain unverified. The table measures agreement with those corrected references. [Correction record](../testing/analysis-human-bar-corrections-r129.json).

## Decisions and versions

Untouched’s neural downbeat sequence changes by two beats after the opening. The new rule requires four consistent opening bars, strong opening evidence and a stable beat grid. Automatic adoption also requires agreement with the first-pass beat timing. Conflicting later evidence caps the bar score at 0.69. This score is not a calibrated probability. Conflicting automatic review proposals are removed.

Dune’s old deep pass halved the tempo while retaining the early DSP phase. The new pass measures a precise audio pulse at the neural tempo. It requires sustained coverage and either agreement across audio bands or support from the neural beat sequence. Dune’s measured pulse has 4.145 ms median residual, 75% beat occupancy and nearly complete track coverage. About 60% of neural beat events support that phase within 40 ms.

Deep generation and decision policy are 14. First-pass configuration is grid 4, beat fitting is version 3, and bar analysis is version 2. Model weights, conversion and preprocessing remain unchanged. Compatible prediction windows remain reusable. Older automatic tempo-only results can receive the improved phase. Accepted deep results avoid repeated first-pass bar upgrades.

The automatic corrections preserve manual, locked, imported and newer preparation. They do not edit the Traktor source. Sharing, serialisation, cancellation and upgrade guards passed focused host tests. Physical sharing remains untested in this iteration.

## Native Mac validation

The same 12 original tracks completed fresh first and deep passes. All results reopened unchanged. Among nine reference tracks, beat-phase agreement within 25 ms rose from 7/9 to 8/9. Downbeat agreement rose from 6/9 to 7/9. Tempo agreement stayed 9/9 and key agreement stayed 6/9. Other playback timelines stayed unchanged within 1 ms.

The remaining downbeat checks are Dune’s unresolved bar and the 26.067 ms reference difference on 99 Problems. The latter retains the correct relative bar choice and sits just outside the 25 ms test threshold.

The candidate was frozen before fresh-reference scoring. The 180 fresh excerpts had no paired gains or losses in first-pass, final-playback or review beat/downbeat F1.

| Fresh cohort | Recordings | Bar labels | Final beat F1 | Final downbeat F1 | Review downbeat F1 |
| --- | ---: | ---: | ---: | ---: | ---: |
| GTZAN | 100 | 98 | 61.25% | 55.46% | 59.92% |
| Ballroom | 80 | 80 | 64.51% | 62.54% | 68.73% |

These values are unchanged from the baseline. GTZAN recordings and audio identities differ from earlier cohorts, but artists overlap. Ballroom overlaps upstream model training and remains diagnostic evidence. The measured accuracy gain in this iteration is on the two corrected original tracks.

All 574 earlier policy replays retained playback timelines and scores. All 1,146 beat windows and 574 key windows were byte-identical to their inputs. Both adaptive-tempo fixtures remain within 2.493 ms across 128 beats. Key choices stayed unchanged throughout the comparisons.

Feature comparisons found small numerical differences. Original-track waveform differences were at most 0.0000005. Chroma and timbre differences were below 0.000000003. The result record retains the measured differences. It does not claim bit-identical features.

Thirty-five focused Swift tests and six report tests passed. Four historical Creep fixtures were restored from the inactive worktree with recorded hashes. Earlier missing-fixture failures and failing regression tests remain preserved.

## Timing and limits

The full 12-track first pass took 169.11 seconds, compared with the saved R129 run’s 128.97 seconds. Deep analysis took 160.58 seconds, compared with 149.20 seconds. Background host work and large spikes in unchanged decoding stages affected this comparison.

A subsequent sequential check used the old and new Mac apps on the same three tracks. First-pass time was 48.56 versus 50.75 seconds. Excluding model loading, it was 29.71 versus 28.87 seconds. Feature preparation alone was 14.74 versus 16.49 seconds. These measurements do not establish an isolated speed gain or a repeatable regression. The new phase measurement adds work to ambiguous deep results.

Dune’s bar, calibrated full-track confidence, Duo throughput, physical iPad sharing and live A10X acceptance remain open. No device installation or listening acceptance was part of this run.

## Evidence and source

[Machine-readable results](../testing/analysis-phase-r139-results.json) contain paired scores, source hashes, timings and validation limits. The raw evidence is under `TestBuilds/r139/` in the authorised analysis worktree and the consolidated folder.

The tested package is `Candidate03.app`. Its source commit is `fd925a2f18394f0b6ed9d9ea0ed9ddc5f113abb0`. Its source SHA-256 is `0b1164e3c3b3621499c3c6dea3a487d8222a91e3b70ec45c7ca0ab2a8062dfbe`. Its app SHA-256 is `57aa6484367bfb33da90e0ccd9c2533ef70160a5e1d0df0f8ef663dc9ebba522`. Frozen model resources retain their R129 hashes.

Candidate01 did not correct either automatic grid. Candidate02 established both corrections. Candidate03 adds accurate audit flags and retains the same analysis policy. All three packages and attempts remain preserved.

The initial Python audio probe used 220-frame bins. Swift uses 221 at 44.1 kHz. The corrected probe and native Mac results supersede that initial estimate. The GTZAN selection description also contained a copied request number. Only that description changed. Audio identities, labels, selection seed and all other fields stayed unchanged. The original reference and both file hashes remain preserved.
