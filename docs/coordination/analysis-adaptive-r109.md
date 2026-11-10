# Adaptive timing and downbeat checks: R109

R109 continues [R103](analysis-accuracy-r103.md) with the same 12 audio files. Erik explicitly requested Mac app comparisons and authorised this separate working folder. Physical iPad and Duo acceptance remains separate.

## Adaptive timing fix

The drift fixture already had an accurate whole-track map. A fallback then replaced it with a map from a 24-second window. That map also received an unrelated beat-number shift. Its final segment extrapolated through the rest of the track. At beat 120, the result was 2.990862 seconds early.

The fixed-tempo fallback now retains the whole-track adaptive map. It cannot substitute a local adaptive map. The map remains a candidate that requires review. Analysis does not accept it as performance preparation.

The new bar-position test exposed a related error. The detector copied a fixed-grid bar offset into the adaptive map, although their beat origins differed. Six accented drift cases failed. Adaptive bar detection now measures rhythm and harmonic evidence at the map's actual beat times. It converts the result to that map's beat origin.

The first-pass configuration changes from `beat-this-small0-grid-2-tuned-hpcp-2` to `beat-this-small0-grid-3-tuned-hpcp-2`. Matching analysis can refresh automatic adaptive candidates from known versions 1 and 2. Newer and unknown versions do not receive this refresh. Manual, edited, locked, imported, accepted adaptive and accepted deep preparation remains protected. Model weights, deep inference IDs, checkpoint formats and key policy remain unchanged.

## Downbeat reference correction

Erik first reported that he did not recall manually correcting the four disputed references. He then confirmed that the Traktor downbeat for **99 Problems** starts one beat early.

GenErik places that bar one beat later, consistent with Erik's correction. This supports the bar choice. It does not verify the exact onset timing, tempo or key. The R103 grid remains about 29.6 ms from the corrected reference timing.

The [reference correction record](../testing/analysis-reference-corrections.json) binds this report to the audio hash. Preserve the original comparison and report the correction separately. Do not insert track-specific reference rules into the engine.

## Alternative model experiment

The [authors' model catalogue](https://github.com/CPJKU/beat_this#available-models) provides `final0`, `final1` and `final2`, trained with three different seeds. They share an architecture and training data. Agreement between them does not establish musical correctness.

The experiment used all 12 unchanged files, the official Python frontend and postprocessor, and all three full-size checkpoints. Its `final0` control and both alternatives selected the same dominant bar positions for **99 Problems**, **Big Ole Freak**, the **CeeLo remix** and **Untouched**. No replacement model was selected. The other three disputed tracks still need listening review.

| Checkpoint | SHA-256 |
| --- | --- |
| final0 | `8c328b45f59d8dd3dff219253ff6a8d6482be57d0133a29140e2febbf8eb8331` |
| final1 | `365b553f43750717c907f32fbc42910f3b264d616654583df6e44472c93ead80` |
| final2 | `8f810c0a44d3a979b0372b00fa61b4e3f83a8f2a6d963c7791b9d4852cdd1abc` |

This experiment uses Python, FFmpeg decoding and the Mac GPU. It is not a measurement of app speed or Neural Engine performance. The app comparison uses the production release executable separately. Failed environment attempts and successful results remain in `model-probe`.

## Focused verification

Twenty focused host tests passed across 56 cases. Eleven refresh cases include older, current, newer, unknown and protected results. They cover ten drifting-audio cases, all four bar positions, delayed starts, offbeat percussion, octave decisions, preparation protection and deep checkpoint reuse. The original drift fixture failed before the fix. Six additional adaptive bar cases failed before the bar-coordinate fix.

The final focused checks ran on source `ae7653bf2796df25c7aca236071628af6b622a9d`. The analysis source and tests remained unchanged after integration with the latest main branch. Source and log hashes are in `focused-source-02.json`. Earlier passes and failed checks remain preserved.

## Mac comparison

The first release Mac comparison completed on `3ca8f6316bdaa3277d44d1c2aa750bff9138e03c`. All 12 files and 164 prediction windows matched R103. Tempo, key and strict phase agreement counts stayed unchanged. First-pass work took 363.72 seconds and deep work took 101.97 seconds. The slower total came mainly from unchanged decoding and feature work. It does not establish a causal slowdown.

The final version guard then restricted refresh to known older results. The final Mac run completed on `1476c45a1ab97e535c6685e34ab2e7ddaf336f33`, merged into `main` before packaging. The original manifest, audio hashes and scoring limits remained unchanged.

| Measure against nine original saved references | R103 | R109 final |
| --- | ---: | ---: |
| BPM within 0.1 | 9/9 | 9/9 |
| Exact key | 6/9 | 6/9 |
| Beat phase within 25 ms | 7/9 | 7/9 |
| Downbeat within 25 ms | 4/9 | 4/9 |
| Maximum full-track grid error within 25 ms | 7/9 | 7/9 |

All 164 prediction windows matched R103 byte for byte. All 12 saved results reopened unchanged. Final musical results matched within floating-point rounding. Nine full grids and one tempo-only correction were accepted. “…In The End” retained 80.009 BPM and an unresolved downbeat.

The separate corrected-reference summary moves the **99 Problems** reference forward one beat. Its downbeat difference falls from 672.79 ms to 29.61 ms. The engine position is unchanged. The strict 25 ms count therefore remains unchanged.

| Measured work | R103 | R109 first attempt | R109 final |
| --- | ---: | ---: | ---: |
| First pass | 325.75 s | 363.72 s | 272.92 s |
| Deep pass | 96.94 s | 101.97 s | 97.26 s |
| Combined analysis | 422.70 s | 465.69 s | 370.18 s |
| Entire audit process | 437.64 s | 480.24 s | 385.00 s |

The Mac was shared with other development work. These individual runs do not establish a causal speed change. Thermal state remained nominal. The final run used a fresh analysis cache and ordinary operating-system caches.

## Packaged-app adaptive check

The same release app then analysed the original drift fixture and a delayed, accented variant. Each contains 128 beats with known changing intervals.

| Check | Original failure | R109 release app |
| --- | ---: | ---: |
| Beat 120 timing error | 2990.862 ms | 1.474 ms |
| Maximum error across 128 beats | 3267.393 ms | 2.493 ms |
| Delayed fixture maximum error | Not measured | 2.493 ms |
| Delayed fixture downbeat offset | Host regression failed before fix | Correct offset 2 |

Both maps retain 33 anchors and remain unaccepted candidates. The original file hash matches the archived baseline reproduction. The ten focused audio cases also passed with both starts and all four accented bar positions.

## Source and remaining work

- Tested source: `1476c45a1ab97e535c6685e34ab2e7ddaf336f33`.
- Source SHA-256: `e6ed1571f5f5f3499053c8ebfc3d0bc58bac0681e0ce067504890c65ba084aa8`.
- App SHA-256: `c04792d8232e371e9bdfd4b1a187b0c8f265a61c75ce6f4d7e0d2a8bde4f10cd`.
- Music run: `9721D375-FFE3-4506-940B-3D3859ABB3EF`.
- Adaptive run: `5E14FEE4-94E0-49DB-BBD8-1EEF7F8DB4E8`.

Listening review remains open for **Big Ole Freak**, the **CeeLo remix** and **Untouched**. “…In The End” still needs a reliable beat phase and downbeat. The three relative-key disagreements from R103 remain unresolved. Actual Duo throughput, physical result sharing and A10X live performance remain outside this Mac check.

The app uses local SwiftPM resources. It is a local diagnostic package, not a portable distribution.

Evidence is retained in `TestBuilds/r109` in both the primary checkout and the authorised working folder. Preserve failed checks, the tested app, both manifests, the original reference comparison and the separate correction record. A successful host or Mac check does not establish live performance readiness on the A10X.
