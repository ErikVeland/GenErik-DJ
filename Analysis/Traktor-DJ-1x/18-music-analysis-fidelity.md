# Music analysis is a condition of TDJ1 fidelity

Current implementation status is in [the shared status record](../../Replica/Status.md) and [analysis results](../../Replica/Analysis.md). The older v0.1 baseline below remains historical evidence.

## Performer requirement — 29 October 2026

The performer reports that TDJ1 consistently identified BPM, key, energy and downbeat correctly across their music. All four must reach that standard before this reconstruction can be considered a contender for a 1:1 recreation. These are core instrument requirements. Interface, playback, suggestion ordering and manual preparation cannot compensate for incorrect automatic analysis.

This is confirmed performer evidence and a requirement. It is not a claim that the original has been independently measured at 100% accuracy on every possible recording.

## Required outcomes

| Dimension | Required behaviour | Unacceptable substitute |
| --- | --- | --- |
| BPM | Correct musical tempo and octave; sufficient precision to retain alignment across a whole track | A related half/double tempo, a rounded display value, or a short section that appears aligned |
| Key | Correct tonic and mode for harmonic mixing, with tuning and ambiguous material handled reliably | Treating a relative key or neighbouring fifth as an exact detection |
| Energy | Useful musical intensity and similarity across the performer's library | Primarily ranking mastering level, recording gain or playback volume |
| Downbeat | Correct beat one and bar alignment, including pickups, intros and breakdowns | Naming the first transient beat one, assuming offset zero, or using a manually corrected bar as proof of automatic detection |

Automatic source results must remain distinct from manually corrected grids and keys. Preserve the performer's preparation when improving or re-running analysis. Keep analysis version, source identity and measurement provenance together. Ambiguous material needs an honest unknown result rather than fabricated certainty; withholding a required answer still fails a labelled positive benchmark case.

Analysis must remain background work. It must not compromise the existing combined-audio and responsive-control priority on the minimum iPad.

## Current implementation audit — 30 October 2026

The overnight `independent-dsp-0.2` implementation added multiband consensus tempo/grid estimation, automatic downbeat inference, tuning-aware spectral key estimation and musical energy features. The older `independent-dsp-0.1` baseline below does not describe the current implementation. A status report that said automatic downbeat detection was absent was incorrect.

The `independent-dsp-0.2.1` follow-up fixes phase initialization when balanced on-beat and offbeat onsets cancel a circular average. It selects a local modal phase cluster before the existing weighted grid fit. The acceptance thresholds are unchanged. The current synthetic corpus passes all labelled measurements; the TDJ1 reference gate remains closed.

- Tempo uses multiband onset consensus and a whole-track fitted constant grid. It does not provide a variable-tempo beat map.
- Downbeat inference compares recurring four-beat spectral/energy accents and requires agreement across alternating bars. Ambiguous results remain unknown. This is a four-beat heuristic, not a recovered NI detector or proof of arbitrary-meter support.
- Key uses tuning-aware high-resolution pitch profiles, harmonic-peak suppression, key templates and section agreement. Real-music key accuracy remains unmeasured.
- Musical energy uses normalized onset/rhythmic/spectral features instead of absolute loudness. The gain and intensity diagnostics pass. Legacy analyses retain their older estimates until reanalysed.

Automatic `detectedDownbeatOffset` and `downbeatConfidence` metadata remain separate from manual preparation. Unknown is not equivalent to a detected downbeat. The current source, regression evidence and remaining acceptance work are recorded in `Replica/Analysis.md` and `Replica/Validation/AnalysisPriority-2026-10-30-01/`.

## Original preparation import

The production [TDJ1 NML17 preparation importer](../../Replica/TraktorPreparation.md) preserves original references separately from detected analysis and matches native IDs plus duration. Both real iCloud collections parse and archive successfully. Ten paired-audio comparisons and physical iPad verification remain pending. These exports lack energy and an original build identifier, so import success cannot unlock the strict reference gate or establish automatic detection accuracy.

## Executable acceptance benchmark

`Replica/Sources/TDJCore/AnalysisBenchmark.swift` evaluates exact source analyses. `tdj-tool benchmark-analysis MANIFEST_JSON REPORT_JSON` writes a report and exits with status 2 when the reference-corpus gate does not pass. Exit 0 means only that the supplied reference corpus passed the specified automated checks; it is not a universal fidelity certificate. Invalid manifests or report-write errors exit 1.

Every input has an exact SHA-256 and a ground-truth annotation. A mismatched or unreadable input fails and remains in the report. Every dimension is explicitly labelled, absent or unlabelled. Missing labels are blockers. Pure silence and unpitched inputs cannot supply positive detection coverage.

The benchmark measures exact BPM error, beat phase, whole-track grid drift, exact key, automatic bar alignment and labelled pairwise energy similarity/ordering. It retains detected values, raw algorithm confidence, analysis/configuration identity, runtime, source hash, all expectations and every result. Confidence values are not treated as calibrated probabilities or used to override wrong answers.

Whole-track grid checks retain the same beat correspondence rather than re-wrapping phase at each endpoint. Consecutive `beatTimesSeconds` and `barTimesSeconds` annotations can describe tempo-varying recordings. A constant-tempo estimate cannot receive a pass merely because its average BPM matches that recording. Beat and bar maps start at their annotated origins and include consecutive beats/bars across the inspected recording; sparse checkpoints are not interchangeable with consecutive maps.

Current strict engineering regression limits are 0.02 BPM error, 10 ms initial beat-phase error, 20 ms whole-track grid error, 20 ms whole-track bar error, and at most one level of distance for a labelled similar-energy pair. These are explicit test settings, not recovered TDJ1 tolerances or a claim that passing them proves equivalence. Retain the report's limits when comparing engine versions.

For `tdj1Reference`, the reference build must be 1.6.8.67. The corpus must contain positive tempo, key and downbeat examples, similar-energy and ordered-energy pairs, and coverage for four-on-floor, broken beat, syncopation, live drums, ambient material, pickups, breakdowns, half/double ambiguities, detuning, mastering variants, long tracks and tempo drift. Tempo-drift coverage needs consecutive beat and bar maps. Additional required tags can extend coverage; removing tags from a manifest does not remove the fixed reference requirements.

For gain/mastering pairs, compare the same musical content at different levels and retain the relationship annotation. Also include quiet but rhythmically intense music and loud but musically calm music. Energy labels need performer/reference review; a synthetic gain-invariance diagnostic does not recover NI's energy model.

## Historical development baseline — independent-dsp-0.1

The deterministic generator is `Replica/Scripts/make-analysis-benchmark.py`. It creates ten stereo PCM inputs: steady and fractional tempo clocks, a pickup preceded by an off-grid transient, strong offbeat percussion, major/minor triads, a detuned triad, a gain variant and silence. Its annotations come from synthesis. None are TDJ1 outputs.

The retained original run is `Replica/Validation/AnalysisFidelity-2026-10-29/baseline.json`. It records the old engine; use the current status and newer retained reports for present results. The source inputs and the manifest are in that directory's `inputs/` folder. They can be reproduced in a fresh directory by invoking the generator with that directory as its sole argument, then running the benchmark command against its `synthetic-manifest.json`.

Synthetic success must never unlock the reference gate. Paired real-music evidence, listening acceptance, downstream sync/suggestion checks and target-iPad workload validation remain necessary. No original-app access or device operation is authorised by this document.

## Completion rule

Keep the analysis requirement open until BPM, key, energy and automatic downbeat all pass the agreed real-track comparisons against the original reference. Preserve failures and compare future candidates on identical source hashes, annotations and limits. A plausible new heuristic, passing synthetic tests or a visually accurate shell does not close this requirement.
