# R128: Downbeat recovery and first-pass cost

Continue from R124 in the authorised analysis worktree. Erik requested Mac app tests and the same full-track comparisons. Preserve manual, imported and accepted preparation. No device installation is part of this check.

## Frozen validation scope

Use the previous 394 rhythm excerpts for development. Reserve 100 previously unscored GTZAN recordings before R128 tuning. Audio and recording identities differ from the prior cohorts. All 100 artists overlap earlier cohorts because R124 consumed the remaining artist-disjoint components. Do not describe this set as artist-disjoint.

The new GTZAN reference hash is `d4a7b34a0240d4a5522427eaa7261669faa4ee47fc0be697b6dbd490631855f4`. Selection uses a fixed hash seed and genre balance, without analysis results.

Reserve 80 Ballroom excerpts as additional diagnostics. The reference hash is `842fd06fcfb5716664d018ceecca0aa57fabec52b937a98a37805a10aab61d47`. Exclude published recording replicas and exact audio duplicates. Keep three-beat metres in the diagnostic set. Artist identity is unavailable.

Ballroom was part of upstream model training. Its scores measure new policy behaviour on new diagnostic inputs, not generalisation to unseen model data. The [model authors describe this distinction](https://github.com/CPJKU/beat_this#available-models). The [Ballroom annotation authors describe manual bar labels and corrected beat times](https://github.com/CPJKU/BallroomAnnotations#annotation-strategy).

Do not score either new reference set until the native candidate is frozen. Enable the recovery policy only if review downbeat event F1 improves on the new GTZAN recordings. Preserve first-pass and playback timelines in the replay comparison. Record paired losses as well as gains. Keep a failed candidate and its evidence if qualification fails.

## Fixed implementation hypotheses

The R124 first pass spent 151.91 seconds in beat-model inference and 125.38 seconds in decoding and feature extraction on the original 12 tracks. The Mac path requested CPU-only execution. Test the existing foreground Neural Engine path on capable Macs, with the existing CPU fallback and cancellation rules. Older hardware retains the CPU path.

A CPU sample of the production app found repeated Swift array-access checks in the spectral transform loop. Use bounded buffer access and reusable prefix storage. Retain the transform, sample coverage, arithmetic and musical decisions. Compare harmonic features directly against the previous app.

For rhythm, retain every candidate accepted by the existing fitter. Recovery runs only after that fitter fails. Permit one to three beat intervals, with each inferred interval within the existing 12% tolerance. Limit inserted beats to 5% of observed beats, allowing one insertion on a short excerpt.

If the original bar peaks still fail, compare downbeat logits within each four-beat group. Require a positive winning peak, a logit margin of at least two, at least four supporting groups, and 90% agreement on one bar position. Reject ambiguous two-beat and unsupported three-beat patterns. Keep compression, anchor, tempo, cancellation and audio-coverage bounds.

Recovered grids remain review candidates. They have no numerical confidence estimate because calibration version 2 did not use this decoder. Existing candidates retain their calibrated evidence. Deep generation and decision policy 12 identify the change while retaining compatible prediction windows.

## Required measurements

Replay the previous rhythm cohorts and the frozen new inputs through the packaged Mac app. Compare a fresh accelerated first pass with the baseline first pass. Repeat the same 12 full tracks and both drift fixtures. Verify source hashes, saved-result reopening, unchanged key features, bounded timing and preparation authority. Record app and source identities for each result.

Fresh host timing comparisons remain observational. Mac results do not establish Duo throughput, physical result sharing or A10X live acceptance.
