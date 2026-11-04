# R43: Creep remix beat grid

TLC’s **Creep (Tin Tin Out Remix)** reproduces the reported problem.
The iPad uses an imported Traktor grid at 68.0085 BPM with its anchor at 0.633356 seconds.
The app protects that preparation as manual. Its independent analysis also returns half tempo: 68.019 BPM with no established bar start.
The source has a steady kick pulse about 0.441 seconds apart, around 136 BPM.

The opening fixture exposes a second failure. Analysing only its first 32 seconds finds the faster tempo but anchors it at 14.738 seconds.
The failed checks remain here. The frozen feature data comes from the exact local MP3 and retains its hash.
The iPad record matches the track metadata, duration and numerical analysis. Its separate CAF file was not copied.

## Change

The detector smooths bass energy, compares supported tempo multiples and fits the attack times.
A repeating envelope without enough attack support can no longer bypass the existing local search with maximum confidence.
Existing adaptive candidates stay on their existing path.
Analysis configuration advances to 0.3.3. No title or artist rule selects this result.

The grid editor’s existing options menu now contains **Detect grid from audio**.
It reads the prepared audio cache through the serial background worker and applies a fixed grid only after an explicit request.
Both decks must be idle. Playback or performance touches cancel detection.
Track identity, load generation, locks, loops and preparation must still match before the result can apply.
The original Traktor record remains available through **RESET**. Existing saved grids do not change during installation.

## Verification

The full-source result is **136.017769 BPM**, with its anchor at **0.180574 seconds**.
The prepared-cache path agrees within one source sample. The opening pulse reference is 0.1836 seconds.
Bar position remains unestablished. The 1.21 ms fitted residual describes the accepted local window, not the whole recording.

Nineteen focused cases pass: three dense-grid/cache cases, nine offbeat controls and seven late-rhythm controls.
They cover gain changes, beat-zero retention, silence, incomplete caches, cancellation and opposite-phase stereo.
Native cache cancellation stops after about 0.06 seconds on the host. This does not measure A10X cost.

Limited source comparisons cover the original R&B recording, a house extended mix and a hip-hop recording.
Harrison stays near 126 BPM. Original Creep and Jay-Z retain their old tempo/anchor results with lower support confidence.
Those two results remain unresolved. The explicit detection action declines confidence below its acceptance threshold.
The Michael Jackson baseline read fails with the existing EOF decoder error, so that comparison is incomplete.
These comparisons establish no independent accuracy score.

The earlier distinctive-snare bar-selection defect remains open.
Physical menu operation, listening, preparation cost, clean playback and scratching need Erik’s iPad check.

## Reproduce

Run `python3 docs/testing/checks/R43/2026-11-04-creep-grid/check.py` for the twelve dense-grid and offbeat cases.
Run `python3 docs/testing/checks/R29/2026-11-03-late-rhythm/check.py` for the seven late-rhythm cases.
`NativeGridProbe.swift` retains the native full-source/cache probe. Input audio and raw caches remain local under `TestBuilds/ipad/R43/`.
