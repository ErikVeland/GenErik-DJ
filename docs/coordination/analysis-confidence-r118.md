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
