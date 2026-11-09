# Analysis accuracy: R103

R103 follows the [R94 Mac measurement](mac-analysis-audit.md). Use the same 12 files and nine compatible saved references. The manifest and audio hashes remain unchanged.

Erik clarified the reference status on 9 November 2026. The Traktor grids combine automatic results and his manual corrections. The keys are Traktor's automatic results. Individual grid provenance is unknown. Report agreement with these references, not independently verified musical accuracy.

## Changes under test

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

The first release Mac comparison used policy 2. Exact key agreement rose from 5/9 to 6/9. Tempo stayed at 8/9 and downbeats at 4/9. First-pass work took 326.53 seconds. Deep work took 97.40 seconds. This attempt did not resolve the tempo octave. Its report and tested app remain preserved.

The final policy 3 Mac comparison is pending. Keep the failed checks and intermediate probes in `TestBuilds/r97`. This directory retains the initial request number from before the ledger collision was resolved as R103. No iOS deployment or live-performance acceptance is part of this check.
