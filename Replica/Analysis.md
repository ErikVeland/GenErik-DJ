# Analysis status

## Current work — 8 November 2026

Audio and control responsiveness on A10X remain the main priority. R76 adds stage timings and source/cache records to the current Beat This path. It does not change confidence, preparation authority or musical results. See the [measurement and optimisation rollout](../docs/coordination/analysis-optimisation.md) for scope, limits and remaining verification. Same-audio Traktor accuracy and A10X speed comparisons remain open.

## Historical assessment — 30 October 2026

Analysis is the current development priority. BPM, key, energy and automatic downbeat must meet the performer's TDJ1 requirement before a fidelity claim. Playback retains scheduling priority while background analysis runs.

## Correction to the readiness report

The earlier assessment incorrectly described the historical independent-dsp-0.1 engine as current. The overnight independent-dsp-0.2 work already implemented automatic downbeat inference, multiband tempo/grid consensus, tuning-aware key analysis and musical energy metadata. The old baseline and its failure table are historical evidence, not present results.

Fresh measurement of the unchanged overnight engine passes straight, fractional and pickup tempo/downbeat cases, key-labelled triads, silence and both energy comparisons. In that historical v0.2 rerun, strong offbeat percussion returned no BPM or downbeat; the current v0.2.1 fix below resolves that case. This is a specific reproduced failure, not an absent detector.

## Targeted follow-up

The independent-dsp-0.2.1 follow-up changes tempo phase initialization. A circular average can cancel when on-beat and offbeat events balance, leaving a middle-band fit unavailable and rejecting the combined tempo score. The replacement selects a modal local phase cluster before the existing weighted whole-track fit. Acceptance thresholds remain unchanged.

The new end-to-end regression fails on the overnight source and passes with the fix. It covers all four bar positions at original and 20 dB reduced gain. An unaccented beat pattern must retain its tempo without fabricating a downbeat.

The source and test are integrated for internal development. The original analysis source is retained under Validation/AnalysisPriority-2026-10-30-01/before/. Engine versioning distinguishes new analyses; existing preparation is not rewritten by this promotion.

## Latest rerun — 30 October 2026

The documentation refresh rebuilt a frozen copy of current code and reran 12 selected analysis/provenance/storage tests, all passing, plus the full synthetic benchmark: 50 checks passed, zero failed. Source inputs stayed unchanged during both checks. Raw outputs are retained in Validation/DocumentationRefresh-2026-10-30-01/. This was a targeted rerun, not a new complete package regression.

## Verification

| Check | Result |
| --- | --- |
| Original 10-track synthetic corpus | All 50 labelled measurements pass, including four positive downbeat cases and two energy comparisons |
| Strong-offbeat bar position and gain regression | Eight positive cases pass |
| Identical beat accents | Tempo retained; downbeat and its confidence remain unknown |
| iPad interface target | Compiles for ARM64 iOS 17 simulator; no device operation |
| Full package regression | Not clean: 341 successful individual tests, five decoding failures, then an audio-engine startup crash |
| TDJ1 reference gate | Closed; synthetic diagnostics intentionally return exit 2 |

The latest importer integration full regression repeats these failures; its log is in Validation/TDJPreparationIntegration-2026-10-30-01/. The full-run failed tests are aacDecodeAndEmbeddedMetadata, aacPlaybackCacheProducesAudioWithoutRewritingTheSource, concurrentMusicDecodesCannotReplaceAnotherCompletedPreparation, musicAssetDecodingProducesLosslessStereoPCMAndCleansFailedOutput, and concurrentImportsCommitOneVerifiedLibraryEntry. They report Core Audio 1718449215 or AVFoundation -11800. The later presentationClearsAfterCancelledPlaybackHasStopped run aborts in AVAudioEngine startup with comp != nullptr. These errors are retained; their environmental cause is not independently established here. The earlier default-parallel run was interrupted after stalled progress. Neither is a complete passing suite.

## Remaining analysis acceptance

- Compare exact BPM/octave, initial phase, full-track drift, key and automatic bar origin on paired real-music outputs from TDJ1 1.6.8.67.
- Include broken beats, syncopation, live drums, pickups, breakdowns, ambient music, detuning, mastering variants, long tracks and tempo drift. Key and energy quality need real-library evidence; passing triads and gain variants is insufficient.
- Preserve manual grids, key overrides, cues and loops during reanalysis. Legacy estimates remain until tracks are reanalysed or reimported through the version-aware workflow.
- Measure target-iPad analysis cost and downstream Sync/suggestion behaviour while playback and controls remain responsive. No analysis speedup or target-device performance is claimed by this change.
- The current grid is constant-tempo and the downbeat heuristic assumes four beats. Unknown results remain valid uncertainty but fail positive labelled cases.

The complete measured reports, failures, source guard hashes and patch are in Validation/AnalysisPriority-2026-10-30-01/. Passing these synthetic checks does not establish Traktor quality or full 1:1 fidelity.

The [overall status](Status.md) separates implemented features, retained older device evidence and unresolved current-source acceptance. Original TDJ1 preparation import is now integrated; physical iPad and paired-audio acceptance remain open.

## Original preparation and track-by-track comparison

The [original-preparation importer](TraktorPreparation.md) reads TDJ NML17 XML or gzip in the production app and CLI. A unique hexadecimal iTunes persistent ID must match the native Music ID, and the audio duration must agree. Original bytes, raw fields, source digest, matching identity and normalised BPM/key/grid/cues remain separate from detected analysis. Manual corrections and cue deletions survive reimport and reanalysis. Complete supported native-library references use waveform-only decoding; absent energy remains unknown.

The actual current iCloud collection has 5,995 unique native IDs and the older export 10,881. Both passed production inspection and archive import, with unchanged originals. The 27 focused tests pass; real matching audio is still required. Current inspection reports retain ten example references, explicitly without claiming audio matches. The NML files do not record an original app build or energy values, so they cannot alone pass the strict TDJ1 1.6.8.67 reference gate.

The current profile maps milliseconds, zero-based chromatic key codes and an unambiguous grid origin. Unknown key codes, competing grids and unsupported positions remain unresolved; physical TDJ display verification remains open. Neither title similarity nor a persistent ID alone establishes identical historical audio bytes.

An automatic comparison report showing both engines' values, tempo octave error, phase and whole-track drift remains to be implemented. A TDJ value is a comparison reference, not verified musical ground truth or proof of its automatic detector. The importer and independent analyser must retain their distinct provenance.

Host iPad compilation/linking succeeds. The requested physical run is blocked by denied Apple device-service access and disabled sandbox approvals. Full logs, source guard and real-data summaries are in `Validation/TDJPreparationIntegration-2026-10-30-01/`.
