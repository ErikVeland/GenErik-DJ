# R87: Neural Engine analysis and audit review

Erik requested faster Duo analysis, then clarified that Neural Engine use and musical accuracy are the priority.
This review applies the supplied analysis audit to the current source. It supplements R76, not its accuracy gates.

## Findings and first increment

Beat This already uses a learned beat/downbeat model. Two restrictions prevented Neural Engine execution:

- Runtime inference selected `cpuOnly`.
- The bundled ML program used Float32 computation. Float32 input/output alone is not the problem.
  Apple explains that a Float32 ML program executes on CPU/GPU, while Float16 computation permits Neural Engine execution.
  See [typed execution](https://apple.github.io/coremltools/docs-guides/source/typed-execution.html).

The first increment adds a separate Float16 small0 model with Float32 input/output.
Foreground library analysis on physical iOS devices with an available Neural Engine requests `cpuAndNeuralEngine`.
The A10X, host tools and background work retain the existing Float32 CPU model.
This selects permitted compute units. It does not prove where each operation executes on the Duo.

Jobs remain serial at their existing CPU priority. The app cancels foreground analysis when it enters the background,
including when continued processing time is available. The replacement job uses the CPU path.
Playback cancellation, inference window size, long-mix limits, saved results and manual preparation retain their existing rules.
A failed accelerator load, failed prediction or non-finite output retries with the original CPU model.
Cancellation does not trigger fallback. The session retains its loaded model across windows within a track.
Measurements distinguish requested/effective compute configuration, model variant and fallback count.
The effective configuration means the configuration successfully loaded, not measured hardware utilisation.

This is a speed/efficiency change, not a claim of improved accuracy. Float16 can change model output.
The existing model and its weights remain available for fallback and comparison. No library-wide refresh is requested.

## Audit mapped to ML opportunities

| Audit area | Current implementation | Proposed ML/Neural Engine work | Required evidence |
| --- | --- | --- | --- |
| Stage 1: baseline | R76 measures stage time, resource context and source/cache paths. | Add compute configuration and model variant. Inspect the Duo execution plan or Core ML trace. Compare CPU and Neural Engine on identical uncached windows, then complete tracks. | Median/p90/p95 time, cold model load, steady inference, cancellation, memory and thermal behaviour. Host timings are not Duo timings. |
| Stage 2: cheap reuse | Saved preparation and Traktor references can bypass musical inference. New reference preparation can still hash/decode. | Keep this deterministic. Reuse supported fields independently and defer waveform work where safe. | Same source identity, preserved field authority, fewer bytes decoded and no manual-data changes. Neural Engine inference cannot remove file I/O. |
| Stage 3: fresh Pass 1 | Full decode/DSP plus a separate Beat This input path. small0 is the current model. | First enable the compatible small0 model. Then share streaming low-rate features. Evaluate the larger Beat This `final0` model only for ambiguous tracks or targeted windows. | Same-audio device timing and held-out musical results. A larger model is a candidate, not an automatic accuracy upgrade. |
| Stage 4: accuracy and confidence | DSP/model agreement and key scores use heuristic thresholds. | Calibrate tempo, beat phase, downbeat and key separately. Evaluate a learned key estimator against current chroma profiles. Preserve half/double tempo and competing-key candidates. | Human-labelled, held-out data; exact tempo-octave accuracy; precision with coverage; key confusion and abstention. Do not train and score on the same tracks. |
| Stage 5: flexible grids | Beat This predicts beat times, but its main grid fit is fixed-tempo. An adaptive candidate path already exists. | Retain model beat/downbeat evidence through the track. Fit robust piecewise timing from it, with segment support and uncertainty. | Full-track drift, continuity, outlier resistance and supported tempo changes. Neural Engine speed does not correct a fixed-grid fitter. |
| Stage 6: structure and cues | DSP features, Apple SoundAnalysis vocal evidence and CPU Whisper feed section heuristics. | Evaluate music-trained embeddings or a section-boundary/role model. Cache per-window embeddings. Use Whisper Core ML encoder support only where vocal evidence justifies transcription. | Boundary accuracy separate from verse/chorus labels, vocal/instrumental cases, phrase recurrence, latency and manual-cue preservation. |

The audit incorrectly says 170–180 BPM is outside 60–200 BPM. It is inside that range.
The real issue is tempo-octave interpretation, plus coverage outside the range where relevant.

## Where additional ML is useful

### Beat and downbeat accuracy

The upstream project supplies small and full models. The full `final0` checkpoint is a concrete comparison candidate,
while the current small0 keeps cheap tracks fast. See [upstream model descriptions](https://github.com/CPJKU/beat_this#available-models).
A second pass should be triggered by missing evidence, competing tempo interpretations or poor local consistency.
It should process targeted windows first, then expand coverage only when needed.
Do not turn every track into an ensemble job. Preserve a supported beat grid when only its bar phase remains uncertain.

### Musical key

A learned key estimator could supplement the current chroma-profile method, especially for detuning, modal ambiguity
and changing harmony. It needs a separate model selection/conversion experiment. No replacement key model has been selected.
Retain trusted Traktor, Mixed In Key and manual authority. Score stable-key regions separately from tracks that change key.
A generic sound classifier cannot supply this decision without a trained musical-key output.

### Sections, genre and vocal evidence

Music-trained representations such as [MERT](https://arxiv.org/abs/2306.00107) are research candidates for reusable embeddings.
They are not ready-made verse/chorus decisions, and Core ML conversion, memory and task-specific heads remain to be evaluated.
Section boundaries, section roles, genre and cue suitability need separate confidence and acceptance checks.

The bundled Whisper path explicitly disables GPU use and has no bundled Core ML encoder in the inspected source.
Setting `use_gpu = true` would target the GPU, not unlock the Neural Engine.
[whisper.cpp documents a Core ML encoder path](https://github.com/ggml-org/whisper.cpp#core-ml-support), which needs a compatible
encoder artifact and framework integration. It does not move every decoding stage to the Neural Engine.
Music-role inference should not depend on reliable transcription of every lyric.

Apple SoundAnalysis already performs learned classification. Its built-in model owns its compute scheduling.
Do not claim it is CPU-only or replace it solely because the app exposes no compute selector.

### Stems

Source separation may help difficult vocal or harmonic cases, but it adds substantial work.
The repository contains a stem-model asset path, not an accepted live separation pipeline.
Keep separation as a later, measured offline option. It must not become a prerequisite for ordinary BPM/key preparation.

## What should stay outside the Neural Engine

Source hashing, exact audio matching, file decoding, persistence and sync conflict rules remain deterministic CPU/I/O work.
FFT/resampling and robust grid fitting should use the existing numerical path unless a measured replacement helps.
The Neural Engine executes supported model graphs. It does not accelerate arbitrary Swift code.

## Duo preparation and iPad playback

The intended direction is for the Duo to perform expensive preparation and for the A10X to consume accepted results.
R86 currently synchronises immutable preparation revisions with explicit restoration at the next launch.
It does not automatically assign tracks, skip queued work after a remote result arrives, or merge accepted results into the active library.
Those capabilities need a separate focused increment before describing the system as distributed analysis.

That increment needs exact audio identity, per-stage algorithm/model versions, source provenance, resumable local queues,
and revalidation before accepting a remote result. Remote analysis must not override manual grids, keys, cues or deliberate clears.
Keep received candidates separate until accepted. Changed source audio must invalidate the relevant stage caches.

## Rollout order

1. Verify the current small0 Neural Engine path on the Duo. Compare the same uncached audio against CPU results.
2. Make accepted remote preparation reusable without repeating musical analysis, with manual authority preserved.
3. Reduce duplicate decoding and cache versioned low-rate features.
4. Compare the larger beat model on ambiguous examples and calibrate acceptance separately from raw model scores.
5. Evaluate learned key and section models in separate increments.
6. Add flexible timing and optional vocal/stem work only after their own labelled checks.

Keep the proposed 98% tempo/beat-phase and 95% downbeat/key precision targets, with coverage reported beside them.
Keep the proposed p95 20 ms drift target. None of these targets is established by the current comparison.
Any audible interruption, delayed control or visible stall blocks performance acceptance.

## Retained evidence

Evidence is under ignored `TestBuilds/r87/` and remains bound to the model artifacts and tested source.
The first conversion attempt failed with incompatible NumPy scalar conversion. The compatible environment uses NumPy 1.26.4.
The first compute-plan script used an outdated method name. Its failed output is retained beside the corrected run.

- The new artifact uses the existing pinned checkpoint, SHA-256 `6074be2c4d490c5f6101fcc374a1ec72ae93456e23bb6019783b849f5dc7d47b`.
- Conversion: coremltools 9.0, torch/torchaudio 2.7.1, Python 3.12, NumPy 1.26.4.
- The host compute plan prefers the Neural Engine for all 746 reported operations. This is not observed Duo execution.
- Blue Monday '88 and Groove Is In The Heart produced identical beat/downbeat times in the host comparison.
- 3CAG retained 260 beats and 75 downbeats. Some times differ by one 20 ms frame.
- These three songs compare numerical behaviour against the existing model, not musical correctness against human labels.
- No Duo speedup, new accuracy percentage or A10X performance acceptance is claimed.

Build 148 installed on the Duo, and iOS accepted launch. No further device actions followed.
Six focused tests passed across seven cases on the final source. They cover fallback, cancellation, worker context and background transitions.
The build record and `verification.json` contain the same source digest. Actual Duo timing and listening checks remain open.

## Handover

Erik handed R87 to the “Choose analysis data sync” chat on 8 November 2026. Source and build records are merged into main and pushed. The prior implementation turn is complete. Continue from Erik’s build 148 feedback. TestFlight build 147 predates R87 and does not include the Neural Engine changes.
