# Performer suggestion policy

Documentation reviewed against the shared implementation on 30 October 2026. [Current readiness and verification](Status.md) is the implementation status record. Dated measurements below apply only to their recorded source and workload.

On 25 October 2026, the performer specified this order:

1. Key.
2. BPM within ±8%.
3. Similar energy.
4. Whether the tracks have been paired before.

The app and `tdj-tool suggest` now use that order directly. A weighted average is not used. A pairing preference cannot compensate for a worse key, tempo tier or energy match. No calibration installation is needed for this user-defined policy. The older experimental scorer remains available through `suggest-calibrated`.

## Current comparison rules

Key uses corrected metadata when available. Exact key comes first, followed by relative major/minor and adjacent fifths, then other keys, then missing keys. The key relationship details are implementation choices, not measured NI rules.

Deck and browser labels use Open Key notation, matching the saved S20 display (`12m`). Musical key identities and recommendation comparisons retain their tonic/mode values. The numeric circle and relative major/minor suffixes follow Native Instruments' [Open Key explanation](https://www.native-instruments.com/blogs/blog/harmonic-mixing-rules-and-how-to-break-them). This display change does not alter the confirmed ranking policy.

For a playing synced reference, the BPM target is the shared master tempo. Otherwise, it is the reference's corrected source BPM. All candidates inside ±8% share the same BPM tier. Outside the range, candidates are ordered in one-percentage-point distance bands. Missing BPM follows known BPM. No half/double interpretation is applied automatically.

New analyses use musical energy features: onset activity contributes 50%, rhythmic confidence 25%, normalized spectral activity 20% and brightness 5%. Absolute recording level is excluded from this formula. The result is rounded into levels 0–10. Candidates with the smallest level difference come first. Legacy analyses without musical energy metadata retain the older waveform/cached fallback, which includes loudness; reanalysis is required to replace that estimate. Silence and unavailable analysis do not receive fabricated energy values. The synthetic gain and intensity comparisons pass, but real-music and NI equivalence remain unverified. See [current analysis status](Analysis.md).

Prior pairing is a boolean from saved transition events, in either direction. Repetition does not add an unrequested popularity weight. Stable collection order breaks complete ties. Loaded tracks and the reference itself are excluded.

## Recording real pair history

The audio renderer counts frames where both decks contribute non-silent audio to the master mix. The model saves one transition event per loaded generation pair after observing this counter. File loading, queued silence and headphone-only playback do not qualify. The journal survives restart.

This is the current definition of a performed pair. Exact original minimum overlap duration and transition direction remain unmeasured. Historical XML exports are not silently treated as trained state.

## Tests

`Tests/TDJCoreTests/PerformerSuggestionTests.swift` verifies ordered priorities, inclusive ±8% boundaries, current performance tempo, corrected keys, unknown analysis, undirected pairing, stable ties and restart.

`Tests/TDJInterfaceTests/PairHistoryWorkflowTests.swift` verifies that actual rendered overlap creates one retained event. Mixer tests check that cue-only audio does not qualify.
