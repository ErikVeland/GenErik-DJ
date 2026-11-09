# R96: reliability audit of build 155

Build 155 does not yet meet the uninterrupted-audio requirement. This audit found two reproducible control failures and a separate output-recovery gap. It does not claim exhaustive coverage.

## Source and evidence

The audit used application source commit `cc736d0a10ce46e3c929b56c3c25580ca5b7f31b` from installed build 155. Its source hash was `d3e325c73b8a2b5f6af9e67a760cb895b3ec41b367d114fed7187991a6e3c615`. The source hash matched the build record before the probes ran.

Two focused host probes exercised three cases. All three cases failed their required outcomes, with six failed expectations. The tests filled the existing 127-command queue deliberately. This establishes failure behaviour under pressure, not its frequency during an actual set.

The probe source, log and identity record remain under `TestBuilds/reliability-155/`. The temporary test file was removed from the package after the run. Application source, the installed app and the iPad were unchanged.

## Reproduced blocking failures

1. Channel volume and master volume can remain at zero after the operator restores them. A full command queue rejects the return movement. Only the crossfader has a retained-value retry. After the queue drained and control maintenance ran, both tested volume values remained zero. The deck remained playing, and rendered audio remained silent. See `PlaybackController.swift:338` and the Z1 mapper in `Z1Protocol.swift:64`.
2. A waveform release can be discarded while the queue is full. The gesture session cancels its hold task and clears its local active flag before submission succeeds. The native deck remains touch-active at zero performance rate. In the probe, it stayed held after release and subsequent control maintenance. Grid restoration cannot complete while that hold remains. See `WaveformTouch.swift:64`, `PlaybackController.swift:316` and `PerformanceModel.swift:28`.

Apply reliable delivery to final mixer and effect values and to release/cancel operations. Preserve ordering, deck generation and explicit user intent. Cover Z1, MIDI, touch, filter/FX release and lifecycle cancellation. A larger queue alone does not guarantee delivery.

## Output recovery gap found in code

`PlaybackController.swift:588` stops audio on every audio-engine configuration-change notification. Its iOS interruption observer also stops audio without distinguishing interruption start from end. `stopAudio()` pauses output, stops both decks and ends recording. No automatic route reconstruction or interruption-end recovery appears in these handlers.

The manual output-routing control correctly rejects changes during playback. That protection does not handle external device changes or operating-system interruptions. Physical route-change behaviour was not exercised in this audit. The app cannot produce sound through a disconnected output, but it needs explicit recovery that preserves transport and Sync intent.

## Remaining performance evidence

- Analysis cancellation is cooperative. The synchronous Core ML prediction call cannot observe cancellation inside that call. Play pressed during an in-flight prediction can overlap CPU work until it returns. The overlap and its A10X impact remain unmeasured. See `BeatThisAnalyzer.swift:74` and `AnalysisExecution.swift:42`.
- Streamed playback fades down if required samples are missing, then fades back when samples return. This avoids an abrupt transition but still produces an audible gap if starvation occurs. Current A10X starvation-free operation under sustained combined load remains unverified. See `TDJTransport.c:2077`.
- Normal playback does not enable callback deadline metrics. `PlaybackController.swift:175` creates them only in validation mode. Build 155 has no current-source A10X combined-workload deadline, memory or thermal acceptance record.

## Required order

1. Fix retained control values and reliable gesture release, with the three failed cases as regression checks.
2. Audit every operation that can retain mute, filter, effect, touch or brake state after a rejected command.
3. Implement and test deliberate audio-route and interruption recovery.
4. Measure cancellation overlap and streamed playback on A10X with both decks, FX, recording, browsing and loading.
5. Complete sustained listening and touch acceptance on the actual A10X and Z1.

R01 and R49 remain the acceptance authority. The fixes in R89–R93 remain test candidates. No across-the-board reliability or gig-readiness claim follows from build 155.
