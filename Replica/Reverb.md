# A10X reverb implementation

This candidate develops Reverb and Iceverb for the minimum 10.5-inch iPad Pro (2017/A10X). Its aim is a denser, more musical space within a fixed processing budget. The existing audio deadlines and exact 20 ms control-completion gate remain unchanged. Better-device variants can be developed later; this implementation does not change sound quality in response to CPU load.

The change is based on `546ef6fa65e904fb58ee8d3c803fc5ce4a6048be`. Reverb production changes are confined to `Sources/CTDJTransport/TDJReverb.h` and `TDJEffects.h`. Two one-line Swift type annotations in `DeckToolViews.swift` and `LocalMusicLibrary.swift` resolve existing compiler ambiguities exposed by the complete Apple build. Public effect IDs, saved X/Y values, three slots per deck and the existing touch/lock controls remain compatible. An existing saved preset will use the revised sound.

## Sound design

The network retains eight prime-length delay lines and a normalised Hadamard feedback matrix. Four all-pass stages on each input channel spread transients before they enter the tank. Revised delay spacing and diffuser gains create a more populated initial response; smaller discrete early taps avoid a few echoes dominating the onset.

| Control or stage | Reverb | Iceverb |
| --- | --- | --- |
| Nominal midband decay target | `0.35 * 24^X` seconds | `1.5 * 12^X` seconds |
| Bass decay target | `min(1.8, mid * (0.62 - 0.20 * X))` | `min(2.6, mid * (0.48 - 0.15 * X))` |
| Treble decay target | `min(2.0, mid * (0.40 - 0.12 * X))` | `min(5.0, mid * (0.48 - 0.10 * X))` |
| Predelay | 11 ms | 19 ms |
| Bass/treble shelf turnover | 220 Hz / 6.5 kHz | 300 Hz / 9 kHz |
| Input high-pass / low-pass | 110 Hz / 12 kHz | 190 Hz / 15 kHz |
| Feedback movement | Subtle | Greater depth |

Frequencies are capped where necessary for low sample rates. Decay values are design targets, not a guarantee that a broadband or finite-width-band T60 fit returns the same number. Each line's coefficient depends on its length, and the two shelves overlap through their transition bands.

Two disjoint pairs in the feedback matrix move slowly at different rates. Motion targets are calculated every 32 samples using a polynomial-shaped triangle and Cayley rotation coefficients. Interpolation between the endpoints is contractive; it is not exactly unitary on every intermediate sample. The tank keeps fixed read positions, avoiding the extra reads and pitch shifts of moving fractional delay taps.

The character is deliberately restrained at the input and in the bass. Broadband wet energy is lower than the baseline on the synthetic examples. No global makeup gain is applied merely to replace removed bass and early-echo energy. Audition files distinguish actual app output from an offline wet-energy-matched comparison.

## Fixed work and memory

Construction allocates and prefaults delay storage. Rendering, coefficient preparation and resetting do not allocate, free, lock, perform file I/O or clear delay-sized memory. Reset invalidates fixed-size history counters; reads return zero until new history exists. Small state values are periodically flushed to zero to avoid very small residuals persisting indefinitely.

The sample loop has eight feedback lines, eight input all-pass stages, six early reflection taps and two pair rotations. Controls add fixed-size coefficient updates while a ramp is active. There are no per-sample `sqrt`, `pow`, `exp`, `sin`, `cos` or `tan` calls in the reverb path. Parameter preparation still performs a bounded number of elementary-function calls when X or the effect type changes. Reverb preparation and rendering skip generic beat/delay calculations they do not use.

Feedback gain `g` and injection gain `q = sqrt(1 - g*g)` are prepared together and interpolated with the same progress. The segment between two points inside the unit disk stays inside it, so interrupted ramps preserve `g*g + q*q <= 1` to floating-point tolerance. Shelf ratios remain between zero and one. These are local DSP invariants; they do not prove arbitrary full-chain peak headroom or all time-varying behaviour.

All six existing slots can remain active. There is no spare tail engine, overlap engine, new background DSP worker, convolution buffer or dynamic quality tier. This matters during release: bypass no longer promises an immediate CPU reduction, because its existing kernel continues producing the audible tail.

## Release and transitions

The UI already preserves Y when a touch ends or an unlocked effect is disabled. The wrapper detects that edge before advancing the wet ramp, captures the actual current return, and fades new excitation out over 5 ms.

The release deadline is `ceil(sampleRate * min(30, 1.5 * nominalDecay + 0.12))` frames. It is captured once, so editing X during release cannot extend it. Its final 20 ms fades to exact dry output and invalidates the history. At the maximum nominal Iceverb setting, the deadline is 27.12 seconds. This upper bound is a resource policy, not a silence detector.

Explicit Y=0 fades a released return out over 5 ms. Re-enabling continues from the current return and fades the input back in. Switching type invalidates the old tank immediately and uses the existing 5 ms held-sample transition to avoid an abrupt boundary, including when the normal wet ramp has already reached zero. The old algorithm does not continue processing during that transition.

## Reproducible checks

Install Python 3, NumPy and SciPy, and use the platform C compiler. On macOS the harness selects `xcrun clang`; on other hosts it selects an available Clang/GCC compiler.

```sh
python3 Scripts/check-reverb-a10x.py \
    --source-root . \
    --baseline-root /absolute/path/to/baseline/Replica \
    --output /absolute/path/to/new/reverb-evidence \
    --repetitions 5
```

The baseline should be the exact commit named above. The output directory must be new. Without a separate baseline, the harness can run candidate safety and acoustic checks; comparison claims require the paired baseline. Source and probe hashes are recorded in the report.

The checks cover 8, 44.1, 48, 96 and 192 kHz, block sizes 16/128/512, six Reverbs, six Iceverbs and mixed layouts. They include rapid X automation, type/bypass churn, zero wet, polarity, old-history invalidation, allocation/math instrumentation, release edges and long maximum-decay impulse/DC tests. Paired timing alternates the baseline/candidate order. AddressSanitizer and UndefinedBehaviorSanitizer runs are separate from timing. Apple's sanitizer runtime is run without leak detection where it is unsupported; direct effect-header allocation/free instrumentation remains enabled.

Impulse analysis includes normalised echo density, frequency-band decay fits, stereo correlation, mono energy and spectral shape. These diagnostics can reveal defects and trade-offs. They do not rank aesthetic preference. The synthetic WAV examples include the unchanged dry input, baseline, actual candidate output and a separately labelled wet-energy-matched candidate. Matching is an offline listening aid and is not part of the app.

`Tests/TDJCoreTests/ReverbQualityTests.swift` also exercises the public transport path: finite dense stereo tails, polarity, decay control, release, explicit zero return, type transitions and invalidated history. The GitHub workflow runs the native checks, focused Swift effect tests and an unsigned iPad Release build with an Apple toolchain. A hosted Mac build is not physical A10X timing qualification.

## Acceptance still required

Use the exact tested source for listening on real music and for the existing combined device workload: both decks, all six slots, aggressive controls, recording and normal background pressure. Measure the actual output format and callback period rather than assuming a requested buffer duration. Preserve the existing audio-error limits and exact 20 ms control-completion gate, and retain failures alongside passes.

The present work does not establish subjective superiority over Valhalla, a globally optimal A10X algorithm, or safe gig use. No target device is queried, installed or operated by this workflow. Device acceptance belongs to the next agreed hardware testing window.

## Design references

- Valhalla DSP: [Diffusion, all-pass delays and metallic artefacts](https://valhalladsp.com/2011/01/21/reverbs-diffusion-allpass-delays-and-metallic-artifacts/).
- Valhalla DSP: [Modulation in reverbs](https://valhalladsp.com/2009/07/30/modulation-in-reverbs-reality-and-unreality/).
- Schlecht and Habets: [Time-varying feedback matrices in feedback delay networks](https://pubmed.ncbi.nlm.nih.gov/26428777/).
- Apple: [Analysing audio performance with Instruments](https://developer.apple.com/documentation/audiotoolbox/analyzing-audio-performance-with-instruments).

These references inform general design choices. This implementation does not use proprietary Valhalla code or claim to reconstruct its algorithms.
