# R118: Distributable key model and rhythm confidence

## Fixed evaluation decisions

Use MusicalKeyCNN at revision `61d8fc170f262410f66a12057adffc5aceea0b2c`. Its repository includes the checkpoint under the MIT licence without a separate weight restriction. Retain the licence notice and the exact weight, conversion and preprocessing identities. S-KEY weights remain restricted to non-commercial research. InceptionKeyNet does not provide the trained checkpoint needed for this comparison.

The native Mac development run measured 86/100 exact keys, compared with 49/100 for the existing detector. The following key acceptance rule is fixed before inspecting held-out results: a learned candidate may replace an automatic key only when its top-class score is at least 0.8. Preserve manual and imported key preparation. Keep lower-score candidates as evidence. The top-class score is not a calibrated probability.

For key reliability, use the three development bins fixed in R116: below 0.5, 0.5–0.8 and at least 0.8. Record observed correct/total counts and a smoothed estimate. Do not call a confidence estimate a guarantee or infer whole-track accuracy from excerpt scores.

Rhythm development remains separate. R118 reserves 100 additional GTZAN excerpts from artist, recording and audio groups disjoint from all 200 R116 excerpts. Their selection checksum is `49a6c71ada45fbf03b9eccdcf260aaa835b443e4da337b0737a6a146efbd55ce`. Keep their labels out of analysis inputs. Freeze rhythm policy before scoring this set.

All changes use the existing authorised worktree. Merge source into consolidated main before a Mac package. Preserve current controller work and all previous evidence. No device installation is part of this request.

## Work sequence

1. Validate the key conversion and native frontend against identical decoded PCM.
2. Measure the fixed key model on development, held-out and original-track inputs.
3. Test bounded rhythm candidates and estimate reliability on development data.
4. Freeze the rhythm policy, then run Mac comparisons on existing and independent cohorts.
5. Repeat the original 12 tracks and both drift fixtures with the final app.
6. Bind results to source, models, audio and reports. Record limitations and failed runs.

## Frozen rhythm policy 9

Keep all valid bounded adaptive proposals, including those with a strong constant-tempo fit. Add the 8 ms timing correction measured on development references. Apply it only to review proposals. Retain the existing tempo-octave rule. Do not replace full playback grids automatically.

The packaged policy 8 development run offered 52 maps. Hypothetical acceptance measured 70.00% beat F1 and 59.74% downbeat F1 at 25 ms. Actual playback remained at 63.39% and 53.16%. The proposal fitter and timing correction are fixed before independent scoring.

Use two reliability bins from that completed Mac run. Of 43 proposals with strong constant-fit evidence, 26 reached both beat and downbeat F1 of at least 0.95. None of nine other proposals reached that target. Laplace-smoothed estimates are 60.0% and 9.1%. These estimates apply only to comparable 20–35 second excerpts. Longer tracks retain an unknown confidence. The [calibration record](../testing/analysis-confidence-r118-rhythm.json) includes counts, source hashes and sampling intervals. Model consistency is not musical certainty.

Policy 9 adds this calibration and fixes retention of accepted learned keys and pending deep review proposals. Accepted user preparation remains protected. Previous inference windows stay reusable. The key checkpoint, conversion weights, frontend and 0.8 acceptance threshold remain fixed.

## Model rights and conversion

The pinned [MusicalKeyCNN licence](https://github.com/a1ex90/MusicalKeyCNN/blob/61d8fc170f262410f66a12057adffc5aceea0b2c/LICENSE) permits distribution under MIT terms. The same repository includes `checkpoints/keynet.pt`. No separate checkpoint restriction was found. The app includes the copyright and licence text. It also includes the librosa ISC notice for the generated filter coefficients.

The Core ML weights occupy 925,808 bytes. The model uses a native constant-Q frontend and bounded windows of up to 120 seconds. Model weights, preprocessing, conversion, acceptance policy and calibration have separate identities. Accepted learned keys survive later first-pass analysis for the same audio. Imported and manual key authority remains unchanged.

The original-to-Torch maximum logit difference was 0.000000477. FP16 Core ML differed by at most 0.001146 and retained the reference key. On identical decoded PCM, native features differed from librosa by at most 0.00000804. The mean difference was 0.000000356. MP3 decoding produced larger feature differences, recorded separately. These checks do not establish identical decoding across platforms.

The Mac compute plan preferred the Neural Engine for all 24 key-model operations. Production requests CPU and Neural Engine compute units. This is placement evidence, not measured Duo utilisation. Audio feature preparation remains the dominant added cost. The production worker retains background priority and cancellation checks to protect performance work.

On all 12 original tracks, bounded-window Torch inference retained the whole-track Torch key. The largest logit difference was 0.109. This checks boundary effects on identical native features. It does not verify the musical key. The bounded method remains part of the versioned model profile.

## Key validation

Exact matches require both tonic and mode. Unresolved keys stay in the denominator. The automatic column applies the acceptance rule fixed before the held-out comparison.

| Cohort | Previous detector | Raw learned model | Final automatic result | Corrected / worsened |
|---|---:|---:|---:|---:|
| Development, 100 excerpts | 49/100 | 86/100 | 60/100 | 11 / 0 |
| Held out, 78 excerpts | 41/78 | 67/78 | 56/78 | 15 / 0 |

The production Mac pass matched every standalone prediction and score exactly. All 178 saved results reopened. The rule accepted 38 development and 40 held-out predictions. Two accepted held-out predictions were wrong, but the previous detector was also wrong on those tracks. Zero paired losses does not mean every accepted result was correct.

The three key confidence estimates are 60.0%, 85.37% and 97.5%. Held-out correctness in those groups was 8/13, 21/25 and 38/40. Brier loss fell from 0.138 for raw model scores to 0.107 for the fixed estimates. This calibration applies to the tested stable-key excerpt domain. It does not establish cross-genre or whole-track reliability.

## Rhythm validation

Each table entry is beat / downbeat micro-F1 at 25 ms. These are event scores, not the percentage of correct tracks. The review columns assume acceptance of every offered proposal. Actual playback retains the first-pass grid.

| Cohort | Actual playback | Previous policy 7 review | Policy 9 review |
|---|---:|---:|---:|
| Development, 100 excerpts | 63.39 / 53.16 | 66.20 / 55.69 | 70.00 / 59.74 |
| Earlier holdout, 100 excerpts | 57.56 / 53.70 | 59.10 / 54.96 | 62.46 / 57.36 |
| Fresh independent set, 100 excerpts | 63.06 / 59.21 | 65.60 / 61.85 | 66.85 / 62.11 |

Policy 9 offered 52, 52 and 54 proposals respectively. On independent data, 27 proposals improved beat F1 and 17 worsened it. Downbeat F1 improved for 18 and worsened for 13. Aggregate gains therefore do not justify automatic acceptance.

The stronger confidence group met the strict joint target on 26/43 development, 19/44 earlier-holdout and 21/48 independent excerpts. Its fixed estimate was 60%. The independent observed rate was 43.75%, with a 95% Wilson interval of 30.70–57.73%. The estimate is too high on this set. The weaker group reached 0/9, 0/7 and 1/6 respectively. Its fixed estimate was 9.09%.

Independent Brier loss was 0.258 for the fixed estimates. Treating model bar consistency as a probability would give 0.587. This comparison shows an improvement over that unsuitable proxy. It does not establish well-calibrated confidence. The app keeps these estimates out of automatic full-grid decisions. Tracks outside the 20–35 second calibration domain have no rhythm confidence estimate.

All 300 rhythm results reopened. Every replay reused its original beat prediction windows. The development replay also reused learned-key windows from policy 8. No final policy was tuned after independent scoring.

## Original tracks, speed and saved work

The final Mac app completed the same 12 original files and reopened every result. First-pass tempo, beat anchor, bar position, key and adaptive proposals matched R116. The separate tempo-octave rule retained 80.009 BPM for track 11. No full deep-grid proposal replaced playback timing automatically.

The only automatic key change was Blue Monday '88, from D major to D minor. That file has no verified key reference in this set. Against nine saved references, agreement remained 9/9 for tempo, 6/9 for key, 7/9 for beat phase and 4/9 for downbeat phase. These comparisons do not establish musical truth.

Erik's corrected bar reference for 99 Problems remains 26.428 ms from the automatic grid. It still fails the strict 25 ms comparison. His correction verifies bar choice, not the exact onset. Other disputed original-track downbeats remain open.

Both 128-beat drift fixtures retained their original adaptive maps. Maximum error stayed at 2.493 ms. Beat 120 stayed below 1.497 ms, and the delayed fixture retained bar position 2. Both results reopened.

First-pass work took 257.34 seconds. Deep work took another 203.94 seconds for the same 78.23 minutes of audio. Key feature preparation accounted for 108.89 seconds, while key-model inference took 0.226 seconds. Other host work was active. These measurements are observational, not a controlled speed comparison. The deeper key pass adds analysis work.

Fresh beat predictions matched 111 of the 164 R116 windows byte for byte. Maximum logit difference was 0.1484375. The first-pass results stayed stable, but exact deep numerical reproducibility remains unresolved. In contrast, all 600 reused rhythm-benchmark windows retained identical bytes and required no beat inference.

A separate repair check used a copy of Blue Monday's four key windows. One window was damaged and the last window was absent. The Mac app recomputed those two windows, reused the other two, and restored the identical final result. All four window files matched the originals. This checks repair of saved work, not physical device suspension.

Thirty-six focused Swift tests passed, including imported-key protection, manual corrections, version upgrades, retention and analysis sharing. Twenty benchmark Python tests and six report tests passed. The report scorer now counts the saved final key and records first-pass agreement separately.

## Source and evidence

The final application used source `02e3acd541a8decfd93e83653fb3c3953e29f833`, merged into consolidated `main` before packaging. Its source SHA-256 is `5b951c69f5be75881a83feb760d84c2dcb6f2d0d0f2fccf836e73a138232bdb4`. Report-tool changes use `42a67fab332d9882a6c55a6f0df631dc8a7d6c12`.

The [results record](../testing/analysis-results-r118.json) includes model, source, app, resource, audio-reference and report identities. It separates actual automatic results from hypothetical review acceptance. Failed attempts and incorrect-input parity checks remain saved with the other evidence.

Raw reports, app archives, converted models, checkpoints and both built resource bundles remain under ignored `TestBuilds/r118` in the authorised worktree. The consolidated folder also holds compact evidence and compressed reports. The development app uses the worktree's resource path. Its archive is not a standalone Mac distribution package. This task performed no iPad or Duo installation.

## Remaining acceptance scope

- Improve rhythm evidence and calibrate on additional development data. Reserve a new test set before further tuning.
- Add full-track listening references, changing keys, tempo transitions and meters beyond the supported four-beat fit.
- Review disputed bars and keys on the original tracks. Erik's correction for 99 Problems verifies bar choice only.
- Measure the production queue on the Duo and verify transfer to the iPad on both devices.
- Verify cancellation, playback and controls on the actual A10X under sustained background work.

Published human excerpt labels are separate from Erik's listening checks and the original Traktor comparisons. Key training uses GiantSteps MTG, while evaluation uses GiantSteps Key recordings. Artist overlap with model training is not established. Short excerpts cannot establish whole-track accuracy or live performance readiness.
