# R59 static beat-grid baseline

The replacement must estimate a steady tempo, place the beats on the source timeline, and identify the first beat of each bar. Score these separately. Keep a saved grid when the performer locked or corrected it. Keep analysis outside playback and cancel it when a deck needs the resources.

## Local comparison

The current analyser found no BPM or downbeat on 3CAG. The saved preparation gives 71.0019 BPM and a downbeat at 2.58016 seconds. A local frequency-band probe found repeatable timing near 71 BPM and competing pulse rates near 142 and 95 BPM.

The candidate uses Beat This small0 to find beat and downbeat times. It fits a fixed four-beat grid to those times. The first fit selected 142.012 BPM on 3CAG because the faster grid also covered the slower beats. Adding support for consecutive beats and bars gave 71.007 BPM. The fitted bar phase was 22 ms from the saved grid. The first supporting downbeat occurred at 12.74 seconds. The earlier opening still needs a listening check. [Beat This paper](https://arxiv.org/abs/2407.21658).

| Track | Saved BPM | Current analyser BPM | Fitted BPM | First supporting downbeat error against saved bar phase |
| --- | ---: | ---: | ---: | ---: |
| 3CAG | 71.0019 | Unresolved | 71.0073 | 19 ms |
| Blue Monday ’88 | 130.4750 | 130.5259 | 130.5298 | 184 ms |
| Groove Is in the Heart | 121.5480 | 121.5513 | 121.5515 | 18 ms |
| I Like It | 68.0000 | 90.6895 | 68.0003 | 26 ms |
| 99 Problems | 93.2857 | 135.2906 | 93.2804 | 654 ms |

The error compares the first supporting downbeat with the nearest bar in the saved grid. The five saved grids are references for this comparison. Check the large phase differences by listening to those versions. Both analysers place the Blue Monday ’88 bar near 0.20 seconds. Its saved grid starts at 0.38 seconds.

The Core ML export reproduced all 260 beats and 75 downbeats from the upstream model on 3CAG. The test ran on the Mac CPU and used the upstream audio preprocessing. A Swift and Accelerate prototype matched the upstream spectrogram on 30 seconds of already resampled 3CAG audio. The largest absolute difference was 0.000079 across 1,501 frames. Native decode and resampling, full-track integration, A10X cost and the effect on playback remain open.

## Next verification

1. Confirm the reference bar phase for Blue Monday ’88 and 99 Problems.
2. Include those tracks, 3CAG, steady fixtures and ambiguous rhythm in the comparison.
3. Match native preprocessing and grid output against the local candidate.
4. Verify cancellation, saved-grid protection and playback on the A10X before enabling the replacement.

Local evidence remains under ignored `TestBuilds/r59/`. See `static-fit-refined.log`, `current-analyser.log`, `coreml-3cag-parity.log` and `native-frontend.log`. The Core ML export and the scripts that produced the measurements are stored there.
