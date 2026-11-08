# R76: analysis measurement and staged optimisation

Erik supplied the analysis optimisation and QA audit on 8 November 2026. R76 tracks its staged implementation.
R49 keeps audio and control responsiveness first. R70 retains the same-track A10X comparison against Traktor.
Use one focused change and one signed iPad build per feedback cycle.

## First increment: measure the current path

This increment adds measurements without changing the analysis configuration, thresholds, preparation authority or scheduling policy.
It does not trigger a forced library refresh. Existing cached results remain cached.
The following stages have separate wall timers:

| Stage | Scope |
| --- | --- |
| Identity lookup | Saved native or managed track lookup |
| Traktor lookup and validation | Reference discovery/match, then decoded-duration validation |
| Source preparation | Music-library access or export, including provider wait |
| Source hash | File hashing, including interrupted reads |
| Source stat verification | File size/date checks after source processing |
| Decode and features | Waveform, rhythm and harmonic feature accumulation in the existing decode loop |
| DSP rhythm | Rhythm decision after feature accumulation |
| Key finalisation | Key/tuning decision after harmonic feature accumulation |
| Beat This | Input setup, model load/compile, decode/spectrogram, inference and grid fitting |
| Persistence | Library validation, waveform storage, index encoding and write |
| Pass 2 | Total, cache lookup, PCM preparation, structure analysis and arrangement persistence |

Each attempt records its run, job, app build, device model, operating system, configuration, source type and outcome.
It includes available audio duration, source size, audio hash, model ID, cache hits and thermal state at both endpoints.
Cancellation latency runs from the cancellation request until the attempt returns, including cleanup.
Cancelled and failed attempts retain completed stage timings. Review notices do not count as operational failures.

Saved Traktor reuse and new Traktor audio preparation both retain Traktor provenance.
Their cache paths and `sourceHashComputed` flags separate them in the report.
Partial field reuse is not implemented in this increment. Failures before source classification retain `unknown`.
The benchmark report also includes optional per-track performance records. Existing accuracy gates remain unchanged.

## Measurement limits

- CPU time covers all app threads during the attempt. It is not isolated analyser CPU time.
- Peak RSS is the process lifetime peak reported by the operating system. It is not a per-track peak.
- Byte counters cover hash reads, library writes and waveform writes. Decoder/model I/O and Pass 2 writes are not fully counted.
- No physical storage-byte total or per-track sampled memory peak is claimed. Those require separate device profiling.
- Decode includes streaming DSP and harmonic features. Key finalisation does not include that shared cost.
- Parent stages contain child stages. Stage times must not be added together.
- Attempt wall time excludes measurement-log flushing and library-wide queue construction. Measure total run time separately.
- A saved hash identifies retained preparation. Only `sourceHashComputed` reports a hash read in this attempt.
- Thermal endpoints can miss a thermal change within an attempt.
- Timings do not measure audio dropouts, missed control deadlines or visible stutter.

## Log storage and reporting

The workspace stores `analysis-measurements.jsonl`. The app buffers up to 128 records and appends batches of at most 16.
It starts batches only while playback, recording, deck touch, deck preparation and imports are idle.
A small file write already in progress is not interruptible. Device checks must establish its actual cost.
Cancellation leaves records buffered until a later idle analysis run. App termination can lose those buffered records.
No frame-level measurement logs are written.

The file stops accepting batches at 32 MiB. It never rotates or overwrites saved evidence.
A full or unavailable file produces one diagnostic and stops further writes for that app session.
Buffer overflow increments an omitted-attempt count. Do not treat an incomplete log as a complete baseline.

1. Copy the measurement log and `analysis.log` into the numbered build's evidence folder while the iPad is idle.
2. Retain the matching build record and its source hash.
3. Run the report command below.
4. Inspect input warnings, failures, cancellations and omitted-attempt diagnostics before comparing times.

```sh
python3 tools/analysis_measurements.py TestBuilds/r76/device/analysis-measurements.jsonl \
  --output TestBuilds/r76/device/performance-report.json
```

Add `--manifest PATH` to restrict the report to exact hashes in an existing `tdj1.analysis-benchmark/v1` manifest.
The report lists hashes without successful attempts. It does not infer labels or reference accuracy.
It reports median, p90 and p95 wall time, real-time factor and seconds per audio minute.
Groups separate builds, devices, configurations, model, pass, source, cache path, hash status and outcome.
Percentiles describe attempts. Unique hash counts expose repeated tracks.

Before another baseline, archive the full log and remove only that exported device copy. Restart the app to enable logging again.
Do not remove the library, preparation or waveform caches to manufacture an uncached test.

## Remaining rollout and verification

| Stage | Remaining work and evidence |
| --- | --- |
| 1: baseline | Collect exact-source A10X timings and measure instrumentation overhead. Label a fixed real-audio corpus. Verify Traktor DJ 1.6.8.67 outputs separately from human ground truth. Time both apps on the same uncached audio. Profile physical I/O, per-track memory and live audio/control deadlines. |
| 2: cheap reuse | Resolve identity and metadata duration before audio work. Reuse supported fields independently. Keep source verification separate from waveform creation. Verify manual grids, keys, cues, loops, locks and deletions. |
| 3: fresh Pass 1 | Use measured costs to reduce duplicate decode/hash work. Keep streaming memory bounded and feature caches versioned. Compare full-track and staged analysis on labelled audio. Keep DSP and Core ML serial on A10X until measurements justify a change. |
| 4: confidence | Store independent candidate evidence, ambiguity and decision reasons. Calibrate against held-out human labels. Keep accepted results separate from candidates. Distinguish missing beat grid, unknown downbeat and operational failure. Review notice policy separately. |
| 5: flexible timing | Compare half/double candidates and robust local beat fits. Require held-out timing improvements, segment support, continuity and outlier checks before promoting a map. Keep fixed-grid fallback and independent downbeat evidence. |
| 6: structure | Keep Pass 2 separate after saved matching results. Version stage caches, boundary confidence and role confidence. Verify cancellation during playback, recording, deck loading and touch. |

The audit's range statement needs correction: 170–180 BPM is inside 60–200 BPM.
Tempo-octave selection remains an open issue. Expanding a range alone cannot resolve it.

The proposed precision targets remain unmeasured: 98% for tempo/beat phase and 95% for downbeat/key.
Report coverage, abstention, genre, exact octave selection and p95 full-track/segment drift beside accuracy.
The proposed drift target is 20 ms. Preserve ambiguous labels and distinguish Traktor comparison from human ground truth.
Extend corpus tags for high tempo, sparse/late rhythm, tempo changes, key changes, damaged audio and source-identity failures.
Synthetic checks cannot satisfy the reference gate. A build or launch cannot establish A10X readiness or Traktor parity.

The current increment ends after the signed iPad installation and handover. Further changes follow Erik's feedback and the baseline evidence.

## Focused verification

Ten Swift tests passed, including both parameterised Traktor reuse cases. Five Python report tests passed.
They cover worker context, failed work, cancellation, buffered writes, fresh/saved matching, Pass 2 and the synthetic reference gate.
These are host correctness checks, not device performance measurements.
Logs and the tested source hashes are retained under `TestBuilds/r76/`. The numbered build record binds the signed app to its source.

Signed [build 136](../testing/builds/136.json) installed on the A10X iPad. iPadOS accepted launch. No further device actions followed.
Runtime framework and signature checks passed. The source hash matches the focused test evidence.
A10X timing, logging overhead, playback/touch acceptance and paired Traktor measurements remain open.

## R78: first read-only A10X timing observation

Build 137 reached 5728 completed Pass 1 attempts. The next full-track job made the counter appear stationary.
The three preceding fresh attempts processed about 23 minutes of audio each. Their wall times were 466.3, 499.1 and 353.7 seconds.
Beat This inference used 389.0, 388.5 and 265.4 seconds. Hashing used 0.6, 1.2 and 2.7 seconds.
These samples identify model inference as their main measured cost. They do not establish whole-library speed or a paired Traktor comparison.

Echoes saved at 18:54:33 Brisbane time, about 7 minutes 22 seconds after its source opened. The next source opened immediately.
The News and Echoes completed with a beat-grid review notice. Neither is an accuracy success.
All device operations were read-only. The app continued without a restart or source change.
The measurement log, report, file metadata and logs remain in `TestBuilds/r78/`. Preserve the gig preparation hold.

## R85: finish shorter-track structure before long mixes

Erik reported phase 1 still at 5737 on the last installed iPad build, assumed to be 142.
The old queue sorted by duration but required every phase 1 job to finish before phase 2 could start.

The new queue runs both passes for tracks up to 19 minutes before either pass for longer mixes.
A Music catalog duration over 19 minutes keeps a mix in the later group, even when its saved analysis is shorter.
Unknown durations stay at the end of the shorter-track group. The queue still gives loaded tracks priority within each group.
Explicit deck preparation keeps its separate priority over library analysis.

The badge counts the current group. The later group is labelled “Mixes over 19 min”.
iPadOS background progress still counts all jobs in both groups. Saved results are reused after a restart.
The change does not alter the analyser, saved preparation, or playback cancellation rules.

Pre-update device logs and the catalog snapshot are preserved under `TestBuilds/r85/`.
The log confirms the old global phase order. It does not identify the live operation behind the reported counter.
The iPad check must confirm that shorter-track phase 2 advances before the long mixes start.
Full-library completion, audible continuity and touch response remain Erik's checks.

Eight focused host tests passed across 15 cases. They cover the 19-minute boundary, empty and all-mix queues,
loaded managed/native mixes, saved excerpt duration, phase order, progress totals, cancellation and saved-result reuse.

The older `launchReanalysesSavedTracksAndResumesWithoutRepeatingCompletedWork` test still has nine failed assertions across three cases.
The same failures reproduce on unchanged `main` at `aaab02b8c`. The test expects legacy analysis to be replaced,
which conflicts with the current policy that reuses complete grids and keys. The test remains unchanged.
The first baseline attempt could not compile the new queue tests against the old API. Both baseline attempts are preserved.
Focused logs, source hashes and failure evidence remain under `TestBuilds/r85/`.

Signed [build 143](../testing/builds/143.json) installed on the A10X iPad. iPadOS accepted launch.
No device actions followed. Erik checks the new phase order and playback.
