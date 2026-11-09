# R94: Mac analysis speed and reference agreement

On 9 November 2026, Erik requested a speed and accuracy check using the Mac app.
The release Mac app completed 12 tracks with 78.23 minutes of audio. The complete diagnostic took 432.93 seconds.
Deep analysis was fast, but it did not improve the final aggregate agreement counts against the saved references.
These are comparison results, not independently established musical accuracy.

## Tested app and workload

- Mac mini, M4 Pro, 14 CPU cores, 24 GB RAM, external power.
- macOS 27.3, build 26C5035r. Xcode 27.2, build 27B5019j.
- Committed source: `f134882829809a0b139439c42cd382812d9abb55`.
- Application source hash: `616f7f2cc6848a8df5d591c34e386a15e658a13b9460e2a7c89ed30179bdd6d9`.
- Release app hash: `fc92c8ceed8f27aca946a09f7604a5614e4f534af1646b7ce34958c530dea306`.
- First-pass model: Beat This small0, CPU only on the current Mac path.
- Deep model: Beat This final0, generation 1, conversion 1, preprocessing 1, decision policy 1.
- Deep execution allowed CPU and Neural Engine. This does not establish per-operation hardware placement.

The diagnostic ran inside the packaged Mac application executable through its production serial analysis worker.
It completed all first passes before deep work. It did not open the normal workspace, replace preparation or contact either iOS device.
The output folder started empty. Each completed deep result was reopened immediately and compared with its original value.
Filesystem and operating-system model caches were not cleared. These are fresh analysis results, not a cold-storage benchmark.

The sample includes five earlier difficult examples, five deterministic tempo strata, one extended track and one long mix.
The tempo-stratum selection used seed 94. It is a small selected sample, not a representative or held-out accuracy corpus.

Nine tracks had compatible metadata and duration references from the saved Traktor collection.
Their legacy reference hashes do not prove current file identity. The manifest records each current audio file's SHA-256.
Blue Monday '88 had a 182.28-second duration mismatch. Stayin' Happy differed by 0.224 seconds and exceeded the 0.15-second check.
Both were excluded from reference scoring. The long wedding mix had no compatible reference.
The Traktor app version and reference musical correctness remain unverified.

## Speed

| Work | Total wall time | Audio processed per second | Median per track | p95 per track |
| --- | ---: | ---: | ---: | ---: |
| Fresh first pass | 310.24 s | 15.13 s | 21.92 s | 44.48 s |
| Additional full-track deep pass | 108.00 s | 43.46 s | 5.40 s | 27.12 s |
| Reopen all 12 saved deep results | 0.0193 s | Not an inference measure | 1.00 ms | 4.65 ms |

The first deep invocation took 30.88 seconds, including startup work. Its measured inference time was 1.90 seconds.
The remaining deep invocations had a median of 5.28 seconds. The current deep timer does not separate all startup and preprocessing costs.
The complete process took 7 minutes 13 seconds, including report writes and other overhead outside attempt timers.
All 164 deep windows completed. All 12 saved results reopened unchanged, with no additional model inference or source hash read.

The first pass also computes waveform, rhythm features and key. The deep pass refines beats and downbeats only.
The 23-minute mix uses the existing 90-second first-pass model limit, while its deep pass covers the whole file.
It took 41.82 seconds for the first pass and 24.05 seconds for deep analysis.
The other 11 tracks ran at 12.35 times real time for the first pass and 39.50 times for deep analysis.
Do not treat the two tiers as equal workloads or use the long-mix average as the typical song rate.

First-pass model inference consumed 154.57 seconds. Decode and feature extraction consumed 123.52 seconds.
The enclosing Beat This stage consumed 181.24 seconds, including inference. Do not add parent and child timers.
Hashing consumed 0.54 seconds. On this sample, hashing was not the main cost.

Process lifetime peak RSS was 519.5 MiB. Recorded thermal states remained nominal.
This peak includes retained diagnostic results. It is not a per-track or iPad memory measurement.

## Reference agreement

Tempo uses an absolute 0.1 BPM limit with no half/double credit. Timing checks use 25 ms.
Full-track drift follows consecutive reference beats without wrapping errors back into one beat.
The stricter 20 ms accuracy target from the original audit remains unqualified.

| Measure | First pass | Raw deep candidate | Final grid after acceptance |
| --- | ---: | ---: | ---: |
| Grid available | 9/9 | 6/9 | 9/9 |
| Tempo within 0.1 BPM | 8/9 | 6/9 | 8/9 |
| Beat phase within 25 ms | 7/9 | 6/9 | 7/9 |
| Downbeat phase within 25 ms | 4/9 | 3/9 | 4/9 |
| Maximum full-track grid error within 25 ms | 7/9 | 6/9 | 7/9 |
| Exact key | 5/9 | No key model in this tier | 5/9 |

Deep analysis produced eight candidates across all 12 tracks and accepted seven over automatic first-pass grids.
It did not produce an opening-supported fixed grid for I Like It, 99 Problems, ...In The End or the long wedding mix.
Their first-pass results remained available. A completed deep pass without a grid is an abstention, not a successful correction.

Specific results:

- Groove Is In The Heart improved from 16.1 ms to 3.4 ms maximum reference-grid error. The replacement was accepted.
- 3CAG improved from 20.5 ms to 10.0 ms in the raw candidate. It did not pass the stronger beat/bar agreement gates.
- ...In The End retained 160.018 BPM against 79.986 BPM in the saved reference. The octave disagreement remains unresolved.
- Big Ole Freak retained a roughly half-bar disagreement despite deep beat/bar agreement scores of 1.0.
- The CeeLo Green remix and Untouched retained roughly one-beat downbeat disagreements.
- 99 Problems retained about 670 ms of bar-phase disagreement. Its deep pass produced no supported fit.
- Celebration Generation changed from 6.1 ms to 13.2 ms maximum reference-grid error. Both remain below the comparison limit.

The references need listening checks before these disagreements can be classified as detector errors.
Internal agreement scores are not calibrated probabilities. The new beat model does not improve key estimation.

## Track timings and tempo

| Track | Audio minutes | First pass seconds | Deep seconds | Reference BPM | First BPM | Deep BPM | Deep accepted |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 3Cag (feat. Radie Peat) | 3.14 | 16.76 | 30.88 | 71.002 | 71.006 | 71.001 | No |
| Blue Monday '88 | 7.12 | 33.45 | 7.77 | Unscored | 130.531 | 130.530 | Yes |
| Groove Is In The Heart | 3.90 | 21.15 | 4.40 | 121.548 | 121.553 | 121.551 | Yes |
| I Like It | 4.22 | 18.67 | 4.02 | 68.000 | 68.000 | No fit | No |
| 99 Problems (Produced By Rick Rubin) | 3.91 | 21.78 | 3.52 | 93.286 | 93.280 | No fit | No |
| Big Ole Freak | 3.58 | 17.13 | 3.01 | 71.500 | 71.500 | 71.499 | Yes |
| Stayin' Happy (Pharrell Vs The Bee Gee's) | 4.82 | 24.37 | 5.52 | Unscored | 102.999 | 102.999 | Yes |
| Fuck You (Rhythm Scholar Remix)(Explicit) | 4.28 | 22.07 | 5.28 | 130.001 | 130.004 | 130.005 | Yes |
| Celebration Generation | 5.07 | 26.58 | 5.96 | 151.595 | 151.596 | 151.585 | Yes |
| Untouched | 4.26 | 18.73 | 3.81 | 176.999 | 177.000 | 177.000 | Yes |
| ...In The End | 10.97 | 47.74 | 9.77 | 79.986 | 160.018 | No fit | No |
| The Wedding DJ - Coming Out Of My Head 120 | 22.96 | 41.82 | 24.05 | Unscored | 119.976 | No fit | No |

## Reproduction and evidence

The app accepts `--analysis-audit MANIFEST_JSON NEW_OUTPUT_DIRECTORY`.
The manifest uses `tdj1.analysis-benchmark/v1`. The output directory must not exist.
The app writes results after each track and retains failures. It does not import the reference preparation.

1. Build the committed source with `Replica/Scripts/package-mac.sh`.
2. Run the packaged executable with the audit arguments.
3. Summarise the report with `tools/mac_analysis_report.py`.

```sh
'Replica/Build/GenErik DJ Development.app/Contents/MacOS/tdj-preview' \
  --analysis-audit /absolute/path/manifest.json /absolute/path/new-run
python3 tools/mac_analysis_report.py /absolute/path/new-run/report.json \
  /absolute/path/reference-provenance.json /absolute/path/new-summary.json
```

The app entry point needed a filename change after the diagnostic added a second Swift source file.
The Mac packager also lacked whisper.framework. The first launch failed before analysis.
The packager now embeds and signs that framework with a relative runtime search path.
This local development app still uses SwiftPM resource bundles from its release build directory.
The aborted shared-folder build, compiler failure and failed launch remain preserved.

Evidence is under `TestBuilds/r94/`. `verification.json` records source, app and evidence hashes.
`run-02/report.json` contains raw analysis and per-stage records. `final-summary.json` contains the scored comparisons.
Four report-scoring tests passed. They cover octave errors, bar offsets, accumulated drift and missing references.
The source hash was checked again after the run and remained unchanged.

No same-device Traktor speed test, structure/vocal-label accuracy, CloudKit round-trip, normal library-queue throughput or live UI/audio test was performed.
Mac results do not establish Duo throughput, A10X performance or readiness for a live set.
