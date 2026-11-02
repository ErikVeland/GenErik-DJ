# Keylock stress investigations and retained results

Documentation reviewed against the shared implementation on 30 October 2026. [Current readiness and verification](Status.md) is the implementation status record. Dated measurements below apply only to their recorded source and workload.

## Historical design and validation record

The remainder preserves earlier design steps and measurements. Proposed declarations and old budgets are historical; current constants and acceptance are described in Status.md and the production headers.

The stress tests found and fixed three reconstruction defects. They did not select new TDJ1 workflow rules. The gig iPad was not accessed or used for a test.

## Fixes

**Consume every generated sample.** Tempo changes previously discarded unused samples from a 64-frame DSP output block. Odd callback sizes exposed waveform jumps and pitch wobble. The renderer now consumes the whole block before applying the latest DSP rate. The clock and source-position timeline still use the new tempo immediately. This DSP interval is not a new quantise setting.

**Retain phase through native speed.** Repeatedly crossing the source BPM previously reset the stretch processor. Initial native-speed playback still bypasses it exactly. Once stretching is active, it stays active while Keylock remains enabled, including at native speed. A live off/on reversal during the existing fade retains the processor. Original NI unity sound and toggle ramps remain unmatched.

**Retain tempo-weighted sample ticks.** Repeated conversion between beats and frames accumulated clock rounding error. Sixteen of 472 starts in the 30-minute baseline landed one sample late. The clock now retains tempo-weighted sample ticks between tempo segments and converts to beats for public state. The same replay then produced 472 exact starts. No timing epsilon or new boundary tolerance was added.

The development **Stop audio** control also drains saturated command/message rings after pausing device output. It can then submit Stop after a command burst. A regression checks that both playing and queued decks stop and remain silent. This control is development scaffolding, not a recovered NI transport policy.

The C transport now uses `-O3` in development and release builds, matching the existing C++ DSP optimisation and standalone harness.

## Measurements

| Check | Observed result |
| --- | --- |
| Rapid automation, 127-frame callbacks | Worst half-second 440 Hz pitch error fell from 17.752 to 0.032 cents. Maximum sample jump fell from 0.02866 to 0.00579 |
| Rapid automation, 127 / 128 / 511 frames | Pitch error below 0.043 cents after warm-up. No low-energy windows, non-finite samples or observed render-time C++ allocations |
| Thirty minutes of rendered handovers | 472 queued starts, zero frame or source-position errors |
| Five minutes paced under load | 79 queued starts, zero frame or source-position errors, zero C++ allocations. Render CPU time stayed within the 128-frame budget |
| Concurrent controls/snapshots, 15 seconds | 27,918 accepted controls, 64,688 safe backpressure rejections, 47,326 complete snapshots and zero invalid snapshots |
| Native Mac callback, 120 seconds under load | 11,251 callbacks at 512 frames / 48 kHz, 31 queued starts, zero render deadline overruns, buffer errors or non-finite samples |
| Native callback duration | Maximum 3.938 ms wall time and 3.925 ms thread CPU time against the observed 10.667 ms buffer duration |
| AddressSanitizer / UndefinedBehaviorSanitizer / ThreadSanitizer | No findings in the instrumented signal, handover and concurrent-control runs |

These synthetic development measurements do not establish NI sound equivalence. Tone metrics exclude the first half-second. Pitch, energy and jump thresholds are reconstruction test criteria, not recovered NI limits.

The final standalone run rendered 35 minutes 51 seconds, including rapid-tone and concurrent cases. Sustained and paced starts were checked against an independent integer reference for the integer BPM sequence. Each pressure worker performs arithmetic over a 16 MiB working set. This adds CPU and memory traffic. It does not exhaust memory or test severe memory pressure.

### Deadline limits

The normal-priority command-line loop logged **44 wall-time overruns** during its five-minute, 128-frame paced run. Maximum wall time was 28.563 ms. Maximum thread CPU time was 1.500 ms against a 2.667 ms buffer budget. These missed wall deadlines remain in the results. They are reported separately from functional correctness.

The earlier native test used a real `AVAudioSourceNode` callback and its own two pressure workers. It had no measured overruns at 512 frames. It ran the complete DSP, checked samples and replaced this client's buffers with silence before output. It changed no system volume, device format or routing property. That earlier result did not establish 128-frame operation. The follow-up below tests that buffer size directly.

The first native run lacked its own workers. It is retained separately and is not used as the loaded result. Sanitizer timings are not performance acceptance measurements.

## Native 128-frame follow-up

The real output was **Scarlett Solo USB at 48 kHz** on macOS 27.2, build 26B118. Both the Core Audio device readback and actual `AVAudioSourceNode` callbacks were 128 frames. No larger callback was split to simulate that setting. The original 512-frame buffer was restored and read back after every run.

**Mapped-page preparation is now outside the audio callback.** Previously, `tdj_asset_map` mapped the private PCM file without reading its pages. The first playback read could page them in on the audio thread. It now requests read-ahead and performs each page's first read before returning. The existing background track-loading task does this work before the deck becomes ready. The mapping stays read-only. PCM, grid, key and ranking data do not change.

The clean five-minute run is a measured improvement. A short repeat still logged one HAL overload and timestamp gap. The overall result remains qualified.

| Native 128-frame test | Callbacks | Exact queued starts | Wall overruns | HAL / timestamp gaps | Maximum wall time |
| --- | ---: | ---: | ---: | ---: | ---: |
| Before page preparation, 300 s | 112,497 | 79 | 2 | 3 / 3 | 7.024 ms |
| After page preparation, 300 s | 112,501 | 79 | 0 | 0 / 0 | 1.212 ms |
| Short repeat with strengthened checker, 60 s | 22,493 | 16 | 0 | 1 / 1 | 2.660 ms |

The buffer duration is **2.667 ms**. The five-minute run's median wall-time upper bound was 0.050 ms. Its 99th-percentile upper bound was 0.125 ms, using 25-microsecond bins. Samples were finite. Buffer, control-submission, acknowledgement, held-source and source-timeline checks passed.

The matched runs use a read-only mapped 64-second synthetic stereo file. It contains harmonics, kick transients, noise hats and continuous broadband noise. Both decks keep Keylock enabled. The producer requests 96–156 BPM with a 16 ms sleep between batches. Incoming positions move in seven-second steps modulo 48 seconds. Two pressure workers each perform arithmetic over a 16 MiB working set. This adds CPU and memory traffic without exhausting RAM.

**VM evidence supports the preparation change, but does not prove every earlier stall had that cause.** During playback, process page-ins fell from **1,658 to 288**. Each of the three baseline gap windows included a page-in. Counters are sampled on the producer, outside the audio callback. They cover the entire test process and cannot identify the faulting thread. Clean mapped pages remain reclaimable. Preparation does not pin whole tracks or guarantee residency under severe memory pressure.

**The native launch checker also had a bug.** In the captured case, the next buffer began at frame 6,676,864 with clock ticks 128 beyond the bar target. One sample at that tempo spans 149 ticks. The boundary therefore fell after the previous buffer's last sample and before this buffer's first sample. Playback correctly started at 6,676,864. The old checker wrapped an unsigned calculation and reported 6,676,863. The checker now retains its preceding launch prediction across that boundary. It still detects genuinely missed or late launches. Compile-time checks cover the captured case and a tempo change at that point.

A new regression renders the fractional crossing and checks actual audio onset. All **50 regression tests pass**. A separate two-hour rendered replay produced **1,890 exact queued starts**, zero functional failures and zero observed C++ render allocations. Its normal-priority CLI loop recorded 35 wall overruns and zero CPU overruns. This was rendered time, not a two-hour hardware run.

**Timing acceptance and profiling are separate.** Early native probes called the thread-CPU clock twice per callback and used allocation-profiler TLS. The default test now omits those operations and scheduling queries. CPU time and allocation counts are `null` when unmeasured. Optional `profile` mode records them for diagnosis. The scheduling probe confirmed an active real-time policy with a 2.667 ms period and constraint. Removing profiling alone did not eliminate the faults. All failed and clean results are retained.

The final short repeat's remaining HAL event is open. It had no measured renderer overrun or launch error. Its timestamp jumped by 896 frames. The cause is not established. Renderer timing excludes small telemetry updates after the timer and does not cover every downstream host operation. No analogue output was recorded. This result does not certify a full gig, every background load, NI sound equivalence or iPad performance.

The native harness selects the buffer before constructing the graph and checks for a route change during setup. It retains the PCM file for the asset lifetime. It renders the full DSP, checks the samples, then zeros this client's output buffers. It changes no system volume, sample rate or output routing.

The rebuilt Mac app is signed, reopened and stopped with both decks empty. The iPad core/interface and app wrapper compile against the SDK. No simulator, physical iPad, acquisition helper or deployment tool ran. The gig iPad remains untouched.

The fix changes storage preparation. Master tempo, Keylock processing, held lead-in, next-bar Play and pending-action gates are unchanged. Quantize Size's effect on Play and second-Play cancellation remain unresolved.

- [Five-minute result after page preparation](Validation/keylock-native-128-prefault.json)
- [Remaining short-repeat HAL event](Validation/keylock-native-128-final-checker.json)
- [Matched baseline](Validation/keylock-native-128-corrected.json)
- [VM correlation](Validation/keylock-native-128-vm-correlation.json)
- [Full validation and historical results](Validation/native-128-validation.json)

## Remaining HAL isolation

**The five-minute isolated-output test passed at 128 frames. The cause of the earlier intermittent HAL fault remains unproven.** No experimental playback change is retained. All implementation, test and calibration sources match the preceding validated phase byte for byte. The current 50-test regression suite passes. Master tempo, Keylock mathematics, held lead-in, queued Play and unresolved-action gates are unchanged.

A read-only Mac HAL query previously found **Ultimate Lemmings actively using the same Scarlett Solo USB output**. The device was available to multiple processes, with no exclusive owner. This is a confound, not proof that Lemmings caused the fault. The [historical process/output association record](Validation/hal128-mac-audio-output-associations.json) contains that observation. The user then closed Lemmings and requested the isolated rerun. The agent neither quit nor reopened another app. Mac metadata showed no active output clients [before](Validation/hal128-isolated-before-mac-output.json) or [after](Validation/hal128-isolated-after-mac-output.json) the test. Both snapshots had zero query errors and confirmed Scarlett as the default. These endpoints do not exclude a transient client during the interval. The query reads Mac process metadata and the existing default output. It neither captures audio nor enumerates the global device inventory.

The [isolated result](Validation/native-128-isolated-recheck.json) covers 300.042 seconds, 112,504 callbacks and 79 checked queued starts. All callbacks were 128 frames at 48 kHz. It recorded zero HAL overloads, timestamp gaps, invalid timestamps, source or mixer deadline overruns, clock errors, held-source errors and sample errors. The maximum complete mixer cycle was **0.921 ms**, below the **2.667 ms** buffer period. It issued 15,131 tempo commands under the two original background load workers. Profiling, VM polling, activity hints, extra memory churn and residency locks were off. The original 512-frame buffer was restored and read back successfully. This is a clean five-minute result, not a full-gig reliability claim or proof that Lemmings caused the earlier failures.

### Retained measurements

All hardware callbacks below were 128 frames at 48 kHz. Each test that changed the buffer restored and read back the original 512 frames. Failed and deliberately stopped runs remain in the evidence. Exact starts refer to the reconstruction's independent sample-clock check, not an acoustic measurement.

| Test | Actual wall seconds | CPU profiling | Exact starts | HAL / timestamp gaps | Maximum mixer cycle, ms |
| --- | ---: | --- | ---: | ---: | ---: |
| [Normal mapped path](Validation/keylock-native-128-arrival.json) | 300.0 | No | 79 | 27 / 26 | 97.630 |
| [Keylock bypass](Validation/keylock-native-128-keylock-bypass.json) | 180.1 | No | 47 | 0 / 0 | 2.344 |
| [Full Keylock profile](Validation/keylock-native-128-stage-profile.json) | 180.5 | Yes | 47 | 0 / 0 | 0.847 |
| [PCM resident](Validation/keylock-native-128-pcm-resident-control.json) | 300.1 | No | 79 | 1 / 1 | 11.934 |
| [Activity hint](Validation/keylock-native-128-activity.json) | 300.1 | No | 79 | 0 / 0 | 1.014 |
| [Activity repeat](Validation/keylock-native-128-activity-sustained.json) | 237.6 | No | 62 | 9 / 8 | 15.069 |
| [Pure silence control](Validation/hal128-silence-control.json) | 180.0 | Yes | 0 | 0 / 0 | 0.049 |
| [Memory churn profile](Validation/hal128-render-stall-profile.json) | 243.9 | Yes | 64 | 13 / 12 | 12.091 |
| [DSP heap resident](Validation/hal128-dsp-heap-resident-control.json) | 300.2 | Yes | 79 | 3 / 2 | 5.312 |
| [DSP + PCM + code backing resident](Validation/hal128-all-resident-control.json) | 169.4 | Yes | 44 | 21 / 21 | 4.230 |
| [Isolated output, normal Keylock path](Validation/native-128-isolated-recheck.json) | 300.0 | No | 79 | 0 / 0 | 0.921 |

The pure-silence control executes no transport or Keylock inside the callback. Its zero start count is not a transport test. It passed 67,504 callbacks, including a close/reopen of the stopped Mac replica. The mixer cycle stayed below 49 microseconds. This establishes a clean lightweight control in that interval. It does not prove the hardware or another client caused the full-render failures.

The churn cases add a worker that allocates, touches and releases 512 MiB about once a second. The original two 16 MiB arithmetic workers remain. This is a diagnostic load, not a recovered TDJ1 behaviour. The process catches a churn allocation failure and shuts down through normal restoration.

The profiled failing run captured a 12.076 ms callback interval using 0.266 ms of thread CPU time. It also captured a roughly 21 ms interval between a cheap render and the next callback. The DSP-heap-resident case retained 2.047 MiB of transport/DSP pages and still recorded a 5.292 ms interval using 0.143 ms of CPU. A later callback arrived with only 0.348 ms until its presentation timestamp, compared with about 2.94 ms in preceding callbacks. These observations point to waits or scheduling delays as investigation targets. They do not identify the responsible thread, page or driver.

**Profiling is intrusive.** Older traces time the initial thread-CPU query as part of the interval preceding the render result. A probe can itself stall during memory churn. The current checker separately times the C render body and both CPU probes. Default acceptance mode runs neither thread-CPU queries nor VM-counter polling. Do not interpret a profiled low-CPU stall alone as proof of an unprofiled render defect. Unprofiled runs independently retained real HAL and timestamp failures.

### Changes kept in the checker

The checker now observes the entire main-mixer render cycle, checks its deadline and verifies its cycle count against the source callback. It also checks complete source timing and timestamp validity. A bounded history retains the preceding 64 callbacks for up to 16 gaps. Source, core-render, presentation and mixer timestamps distinguish execution from late delivery. Hardware timestamps and HAL notifications remain separate from the reconstruction's logical clock checks.

CPU and allocation metrics are null when unmeasured. A result cannot pass after a detected evidence-write failure. The wrapper refuses to overwrite retained results and saves the exact test source, diagnostic header and build hashes before execution. Creating `OUTPUT.json.stop` requests a normal shutdown within about one second. Signal shutdown also saves evidence and restores the buffer.

The temporary macOS latency-critical activity passed a five-minute run but failed a longer repeat. It was removed from the app. Its experimental source and results remain under `Validation/`. Optional activity and residency flags remain test-only. The shipped DSP, playback controller and iPad path were restored. Direct executable-page wiring returned `EPERM` before any buffer change. Read-only executable-file backing was tested separately. Executable permissions were never changed.

### Isolated test reproduction

The completed five-minute rerun used the normal mapped source, two original pressure workers, varied source cues and 96–156 BPM automation. CPU profiling, VM polling, memory churn, activity hints and residency locks are off by default. Use a fresh result path for any repeat because the wrapper preserves existing evidence:

```sh
bash Scripts/stress-keylock-native.sh Validation/native-128-isolated-repeat.json 300 128 dense
```

Verify that another process is not using the Scarlett output before calling a repeat an isolated test. The script does not quit other applications or request exclusive device access. The completed run changed no routing, volume or sample rate.

The [isolation report](Validation/hal128-isolation.json) records source hashes, raw results, limits and the completed rerun. The Mac bundle was rebuilt and reopened with both decks empty during the preceding investigation. No implementation sources changed for this test, so its 50 passing tests and SDK compilation remain current. No simulator, acquisition, deployment or physical iPad tool ran. The gig iPad remains untouched.

## Reproduce

From `Replica/`:

```sh
bash Scripts/stress-keylock.sh --output Validation/KeylockStress/Final \
  --seconds 1800 --paced-seconds 300 --concurrent-seconds 15 --workers 2

TDJ_STRESS_SANITIZERS=address,undefined bash Scripts/stress-keylock.sh \
  --output Validation/KeylockStress/AddressUndefined \
  --seconds 60 --paced-seconds 0 --concurrent-seconds 3 --workers 0

TDJ_STRESS_SANITIZERS=thread bash Scripts/stress-keylock.sh \
  --output Validation/KeylockStress/ThreadSanitizer \
  --seconds 60 --paced-seconds 0 --concurrent-seconds 3 --workers 0

bash Scripts/stress-keylock-native.sh Validation/native-512-recheck.json 120
bash Scripts/stress-keylock-native.sh Validation/native-128-tone-recheck.json 300 128
bash Scripts/stress-keylock-native.sh Validation/native-128-recheck.json 300 128 dense
bash Scripts/stress-keylock.sh --output Validation/KeylockStress/VariableCues \
  --seconds 7200 --paced-seconds 0 --concurrent-seconds 0 --workers 0 --varied-cues 1
./Scripts/check.sh
```

`--seconds` is rendered musical time. `--paced-seconds` follows wall time. The native command takes an output path, wall duration, optional device-buffer frame count and optional `dense` signal mode. It opens a silent Mac audio client. With `128`, it temporarily requests that buffer size and verifies restoration afterward. It changes no system volume, sample rate or output routing. `--device-info` reads only the current Mac output. Append `profile` after `dense` for intrusive CPU/allocation diagnostics. Use the default mode for timing acceptance. VM polling is off by default. Append `vm` for producer-side process counters. `latency-activity`, `memory-churn-512`, `lock-dsp`, `lock-pcm` and `lock-code-backing` are explicit diagnostic options. `silence-control` bypasses transport/DSP and labels those checks as unexecuted. The native command uses no iOS tools. Scripts atomically replace their executable so later builds do not truncate an active test.

## Evidence and fidelity

- [Final stress results](Validation/KeylockStress/Final/stress.json)
- [Native callback result under load](Validation/keylock-stress-native.json)
- [Clock baseline](Validation/KeylockStress/ClockBefore/stress.json) and [fixed replay](Validation/KeylockStress/ClockAfter/stress.json)
- [Rapid-tempo audio before](Validation/KeylockStress/Before/rapid-tempo-127.wav) and [after](Validation/KeylockStress/Final/rapid-tempo-127.wav)
- [Current build/source validation](Validation/hal128-isolation.json)

The lead-in, held source, green Play, shared tempo wheel and next-bar route remain in place. Quantize Size's effect on Play, second-Play cancellation and pending Keylock changes remain unresolved and gated. Hardware mapping, adaptive ranking, grid preparation and source keys are unchanged. The [performer fidelity specification](../Analysis/Traktor-DJ-1x/15-performer-fidelity-specification.md) still governs original matching.
