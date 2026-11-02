# Adaptive beatgrid reliability baseline — 2 November 2026

The pre-change working-source identity and per-file SHA-256 hashes are in `source.json`. Git HEAD alone is insufficient: this checkout includes staged and unstaged application work.

## Evidence and scope

- `../audio-priority-2026-10-29.md` retains native and Swift host passes, interrupted runs and callback failures.
- `../CombinedPreparation-2026-10-31-01/host-qualification.json` retains the preparation host baseline.
- `../RecordingNativeRebase-2026-10-31-01/` retains the 448-test host candidate, the failed 22.94 ms control trial and subsequent passes.
- `../GenErikAudioCheck-2026-10-29-01/` retains signed27/signed28 physical checks. These use earlier source and cannot qualify this change.

The historical 300-second Swift host workload uses stereo 48 kHz output with 512-frame callbacks: a 10.667 ms callback budget. Exact control completion must meet the existing 20 ms limit. Historical reports retain route, hardware, callback counts and capture/AIFF frame counts. They do not establish current-source results.

## Release gate

Require zero callback failures, invalid samples, recording drops and unexplained control deadline misses. Captured recording frames must equal the reopened AIFF frame count. Retain the exact workload, source, output route, duration and reports for each new run. Preserve every failed input.

An engine stop or output-route change fails or invalidates a run. Do not count an interrupted run as a clean pass. Do not widen thresholds or change fixtures to obtain a pass.

Host tests, sustained host output, physical-device timing, listening and user acceptance are separate claims. Physical touch, A10X headroom, listening and user acceptance remain open. The user owns the iPad. No device operation is authorised by this baseline.
