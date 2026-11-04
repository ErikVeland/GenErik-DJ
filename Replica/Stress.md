# Performance verification

Use focused checks during the [iPad loop](../docs/testing/README.md). Keep full qualification separate and explicit.

| Area | Check |
| --- | --- |
| Transport edges and waveform motion | `Scripts/check-transport-transitions-native.sh` |
| Stream ownership and retirement | `Scripts/check-streaming-native.sh` |
| Adaptive timing | `Scripts/check-adaptive-beatgrid-native.sh` |
| Recording shutdown | `Scripts/check-recording-stop-native.sh` |
| DSP and host cost | `Scripts/check-reverb-a10x.py`, `Scripts/check-effects-quality.py` |
| Combined host workloads | `Scripts/run-runtime-validation.py`, `Scripts/stress-keylock-native.sh` |

Bind each result to the source, binary, workload, sample rate and buffer size that ran. Preserve failures. Host timing does not establish A10X performance. Automated silent output does not establish audible quality or physical touch response.

[Release gates](../docs/coordination/release-gates.md) define device acceptance. [Historical stress results](https://github.com/ErikVeland/GenErik-DJ/blob/archive/pre-cleanup-2026-11-04/Replica/Stress.md) remain available with their original limits.
