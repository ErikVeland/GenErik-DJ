# Native reverb validation — 2026-11-02

The frozen implementation passes the completed native functional, allocation-call, mathematical-bound, AddressSanitizer and UndefinedBehaviorSanitizer checks described below. This is Linux offline evidence for the actual app effect headers. It does not certify an A10X callback deadline or a perceptual improvement over Valhalla.

## Inputs and reproducibility

- Host: `Linux-6.18.57-x86_64-with-glibc2.39`.
- Compiler: `gcc (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0`.
- Baseline: verified GitHub commit `546ef6fa65e904fb58ee8d3c803fc5ce4a6048be`.
- Candidate TDJReverb.h: `2db24a84d207ae633fd9dc54b3cd93a69a160dd464d7975cd76a37b1f4878143`.
- Candidate TDJEffects.h: `12e09c0fe80eb0c9e50eb0a3c731118cf279dcec0dc4697a811f397e23d936d2`.
- The JSON contains the native probe hash, every included header hash, build commands, individual timing trials, diagnostics, and WAV hashes.
- Python requires NumPy and SciPy. On macOS the script selects `xcrun clang`; it also supports Linux Clang/GCC.

```sh
python3 -m pip install numpy scipy
python3 Scripts/check-reverb-a10x.py --source-root . --output /tmp/reverb-evidence --repetitions 5
```

`--baseline-root ../baseline` adds paired comparisons against a separate baseline checkout. The output directory must not already exist. `--skip-audio` skips acoustic diagnostics and WAV generation; `--skip-sanitizers` explicitly omits sanitizer coverage. No timing threshold is used as an invented device certification.

## Completed functional checks

- 45 six-slot cases: all Reverb, all Iceverb, and alternating Reverb/Iceverb, at 8/44.1/48/96/192 kHz with 16/128/512-frame control intervals.
- Rapid and interrupted X ramps, type and bypass changes, reset, finite output, silent old histories after reset, and exact dry output at zero settled wet.
- Polarity and amplitude homogeneity, including 64-times input scaling: observed error zero. These check for unintended nonlinear clipping in the tested kernel; they do not promise an unclipped final mix at arbitrary input levels.
- Six release scenarios at 8/48/192 kHz, both algorithms: pre-disable return capture, continuing release, re-engagement from that return, Y-zero fade and clear, deadline bounds, X edits not extending an existing deadline, and no render allocation/free.
- Type switches during an audible release, including to Delay and High Pass, retain only the short captured-sample transition. Old tank state is invalidated immediately; output is silent after the 5 ms bridge when the dry input is silent.
- Maximum-Iceverb impulse and 250 ms DC-input tests, followed by silence for a total of 60 seconds, at 8 and 192 kHz. Every late ten-second energy bin decreases; no nonfinite sample or coefficient/motion bound failure.
- Interrupted gain/injection ramps remain within the unit disk. Observed maximum squared gain/injection norm is 1; maximum squared matrix-rotation norm is 1.0000000000000004, within floating-point tolerance.
- Constructor checks accept the additional finite-positive test rates 1, 1000 and 384000 Hz and reject zero, negative, NaN, infinity and unrepresentable DBL_MAX rates. These synthetic compatibility checks are not audio-quality claims at those rates.

Direct allocation instrumentation wraps calls inside the included effect headers, not the entire app, Swift runtime or Apple audio framework. It observed zero render allocation/free calls. The largest direct reset/control `memset` was 16 bytes. The candidate made zero counted sqrt/pow/exp/exp2/sin/cos calls from sample processing during the stress test; parameter preparation remains outside this count.

### Sanitizer limitation and preserved failure

The first AddressSanitizer/UBSan run could not complete LeakSanitizer shutdown in this container. The runtime could not open `/proc/.../task` and reported a fatal LeakSanitizer error. The complete failed attempt is preserved in `linux-leak-sanitizer-failure.json`; it has not been relabelled as a pass.

The completed rerun in `linux-result.json` used `--disable-leak-detection`. AddressSanitizer and UBSan passed all executed cases, with leak detection explicitly disabled. The direct allocation/free checks remained enabled. Darwin disables LeakSanitizer by default because its runtime does not support the same leak configuration. This report makes no LeakSanitizer pass claim.

## Timing evidence and regressions

Five trials alternate baseline/candidate order. Each trial processes three seconds of synthetic stereo material through six real effect wrappers, split into two three-slot deck chains. Timing includes parameter preparation, processing, and ordinary host scheduling. Continuous X changes occur every block: 3000 updates/s at 16 frames or 375 updates/s at 128 frames, per slot. The churn case adds type and bypass changes.

At 128 frames, candidate median block times are 1.4–7.4% lower for settled controls and 0.5–1.0% lower for continuous X changes. Type/bypass churn costs 3.0–4.3% more. At 16 frames, continuous X changes cost 1.5–2.4% more and churn costs 2.1–2.6% more. Those regressions remain part of the evidence.

Wall and tail timing are noisy and sometimes materially worse. In the six-Iceverb/continuous-X/128-frame case, median whole-trial wall time is 12.45% higher and median p99 increases from 139 to 266 microseconds, despite p50 decreasing about 1%. The data cannot isolate the cause of that difference. The worst observed candidate block is 4.867 ms in the 16-frame alternating/continuous-X case. These observations rule out treating this host run as a real-time deadline guarantee.

The table reports medians of each trial's p50/p99 and the largest observed candidate block. Positive p50 or wall deltas mean slower. Times are microseconds; block timing is for all six effects combined.

| Layout | Controls | Frames | Baseline p50 | Candidate p50 | p50 delta | Wall delta | Baseline p99 | Candidate p99 | Candidate max |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 6 Reverb | Settled | 16 | 8.96 | 8.63 | -3.69% | +0.14% | 30.5 | 43.3 | 1169.2 |
| 6 Reverb | Settled | 128 | 75.04 | 69.47 | -7.43% | -1.71% | 169.2 | 172.1 | 2144.5 |
| 6 Reverb | Continuous X | 16 | 10.06 | 10.29 | +2.38% | +1.94% | 35.0 | 30.1 | 732.5 |
| 6 Reverb | Continuous X | 128 | 74.15 | 73.77 | -0.51% | +0.61% | 193.4 | 192.1 | 1138.3 |
| 6 Reverb | X/type/bypass | 16 | 8.97 | 9.20 | +2.57% | +1.86% | 25.1 | 23.1 | 943.0 |
| 6 Reverb | X/type/bypass | 128 | 69.68 | 71.79 | +3.02% | -0.83% | 177.7 | 151.2 | 2180.1 |
| 6 Iceverb | Settled | 16 | 9.13 | 9.14 | +0.10% | +1.05% | 26.2 | 38.1 | 1865.4 |
| 6 Iceverb | Settled | 128 | 75.10 | 72.83 | -3.03% | -4.02% | 171.7 | 183.4 | 583.1 |
| 6 Iceverb | Continuous X | 16 | 10.09 | 10.25 | +1.50% | +2.54% | 33.6 | 35.8 | 2139.4 |
| 6 Iceverb | Continuous X | 128 | 74.17 | 73.43 | -1.00% | +12.45% | 139.4 | 265.6 | 2636.3 |
| 6 Iceverb | X/type/bypass | 16 | 8.99 | 9.21 | +2.45% | -4.13% | 36.1 | 25.1 | 3101.0 |
| 6 Iceverb | X/type/bypass | 128 | 68.50 | 70.99 | +3.63% | -0.59% | 187.4 | 162.3 | 1229.8 |
| Alternating | Settled | 16 | 9.38 | 9.16 | -2.35% | -3.51% | 32.3 | 40.9 | 1265.8 |
| Alternating | Settled | 128 | 74.28 | 73.23 | -1.41% | -2.28% | 167.3 | 162.8 | 3579.6 |
| Alternating | Continuous X | 16 | 10.11 | 10.26 | +1.49% | +3.61% | 40.4 | 53.6 | 4867.2 |
| Alternating | Continuous X | 128 | 74.06 | 73.70 | -0.49% | +4.17% | 167.5 | 186.2 | 1769.6 |
| Alternating | X/type/bypass | 16 | 8.98 | 9.17 | +2.11% | +2.90% | 26.6 | 31.7 | 1505.9 |
| Alternating | X/type/bypass | 128 | 68.99 | 71.94 | +4.27% | +2.30% | 168.6 | 195.4 | 457.0 |

Actual-device assessment still needs the complete app, both decks and six effects, control activity, device thermals, callback timing and audible output on the A10X. Apple Silicon CI validates another compiler/architecture but does not replace that device measurement.

## Acoustic diagnostics

The following are diagnostics of a 0.5-amplitude mono impulse sent equally to both input channels. Band decay uses causal third-order Butterworth bandpasses and a Schroeder -5 to -25 dB fit extrapolated to RT60. Echo density is the fraction of locally centered samples exceeding one standard deviation, normalized by the Gaussian expectation. These are not listening preference scores, and no Valhalla recording was compared.

| Mode / X | 20–50 ms density, baseline → candidate | 50–100 ms | 100–150 ms | First three 40 ms windows above 0.9, ms |
|---|---:|---:|---:|---:|
| room-short / 0.15 | 0.024 → 0.294 | 0.678 → 0.731 | 0.874 → 0.791 | 130 → 140 |
| room-medium / 0.55 | 0.011 → 0.276 | 0.674 → 0.745 | 0.901 → 0.891 | 125 → 130 |
| room-long / 0.95 | 0.011 → 0.245 | 0.668 → 0.734 | 0.906 → 0.912 | 125 → 120 |
| ice-medium / 0.55 | 0.013 → 0.154 | 0.515 → 0.713 | 0.859 → 0.889 | 140 → 125 |

The first 50 ms is denser in these cases. That improvement does not extend uniformly to every window: short-room density at 100–150 ms falls from 0.874 to 0.791, and its sustained 0.9 crossing is 10 ms later. Medium-room crossing is 5 ms later; long-room and Iceverb crossing is earlier. Time windows, decaying amplitude and normalization affect these estimates.

| Mode | Bass 80–250 Hz RT60, s | Mid 500–2000 Hz RT60, s | High 4–10 kHz RT60, s | Late mono energy ratio |
|---|---:|---:|---:|---:|
| room-short | 0.56 → 0.45 | 0.57 → 0.54 | 0.47 → 0.40 | 0.467 → 0.493 |
| room-medium | 1.91 → 1.36 | 1.90 → 1.84 | 1.16 → 1.18 | 0.482 → 0.482 |
| room-long | 6.39 → 3.06 | 6.12 → 5.99 | 2.26 → 3.65 | 0.487 → 0.490 |
| ice-medium | 5.43 → 3.02 | 5.44 → 5.28 | 3.12 → 4.30 | 0.489 → 0.497 |

Bass energy decays sooner relative to the middle band; long tails keep more upper-band energy than the baseline. The measured band fits differ from internal design targets because the shelves overlap. Late stereo correlation stays near zero and mono energy is approximately half the mean stereo energy, with no gross cancellation in these impulse cases. Long-room peak/median spectral-bin level drops 3.63 → 2.30 dB and Iceverb 2.72 → 1.39 dB; short-room spectral flatness declines 0.852 → 0.771. These mixed diagnostics should be interpreted through listening, not optimized as a score.

## Audition files

The script generates 18 stereo, 24-bit, 48 kHz WAV files: percussion, plucked/sustained chords and a synthetic full mix. Each is eight seconds long: four seconds of input followed by four seconds of tail. X is 0.72.

- `Dry`: the common dry reference.
- `Baseline` and `Candidate-App`: actual app effect outputs at Y=0.65, with no wet makeup gain.
- `Candidate-Matched`: candidate wet-return energy is matched to baseline over the complete eight-second excerpt. The identical dry signal is retained. This is energy/RMS matching, not LUFS or perceptual loudness certification.
- `Baseline-FullWet` and `Candidate-App-FullWet`: actual app outputs at Y=1. The app uses an additive return, so Y=1 still includes the dry signal.

The matching gain exists only in the audition rendering. It has not been added to the production algorithm. A shared output scale prevents audition-file clipping if needed; for the current examples every shared output scale is 1.

| Excerpt | Offline matched candidate wet gain | Gain, dB |
|---|---:|---:|
| percussion | 1.4265 | +3.09 |
| chords | 1.5344 | +3.72 |
| mix | 1.8034 | +5.12 |

The lower original return level is a material change, not evidence by itself of a smoother or better sound. Compare the matched version for texture and the App versions for the actual product balance. All output file hashes are recorded in the JSON. Audio is generated on demand and not stored in the source repository.
