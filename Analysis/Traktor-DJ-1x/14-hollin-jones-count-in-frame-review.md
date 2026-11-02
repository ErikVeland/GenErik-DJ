# Hollin Jones: count-in frame review

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

Reviewed 21 October 2026 from the public [Understanding Beat Matching lesson](https://www.youtube.com/watch?v=mS8s2SOSGKQ&t=190s), source S38. The gig iPad was not connected, operated or changed.

**One uninterrupted orange indicator event is visible over Play. No distinct second activation before launch is identifiable.** This sequence does not establish whether a second Play press cancels a pending start.

## Coverage and method

The retained pass contains **120 adjacent frame-step captures**, from **3:10.320 to 3:14.287**. The observed player step is approximately 33.333 ms. This is a count of reviewed captures, not a claim about the original recording's unique encoded frames or touch-sampling rate.

The video remained paused during inspection. Native screenshots captured the fixed 2560 × 1440 full-screen player. Play-region contact sheets cover every retained frame. A marker strip covers frames 020–090, and additional waveform sheets inspect the request and launch boundaries. The source video was not downloaded, and no audio-onset measurement was made.

An initial 120-capture pass changed layout during browser screenshot resizing. It is excluded from event analysis. Those images and their contact sheets were removed. An exclusion log preserves their metadata and hashes. The retained native pass replaces them.

YouTube's timeline crosses the lower part of the recorded Play control in some frames. The triangle's main body remains readable. The orange indicator itself temporarily covers the underlying button. The written count-in annotation also covers part of the waveform's left-hand area. These limits matter when counting inputs or interpreting hidden state changes.

## Visible sequence

Deck A is already playing, both Sync controls are green, and both deck headers display 122.0 BPM. Deck B initially shows its source-start waveform at 0:00. No Quantize Size preference is visible.

Times below are video-player positions. They are not calibrated touch or audio timestamps.

| Video position | Frame | Observation |
| --- | --- | --- |
| 3:11.153 | 025 | Deck B Play is grey. The source-start waveform is stationary |
| 3:11.187 | 026 | A pale vertical marker first appears left of the source start. Play is brighter grey, still not clearly green |
| 3:11.220 | 027 | Play is clearly green. The pale marker advances while the source waveform remains fixed |
| 3:11.287 → 3:11.320 | 029 → 030 | The orange indicator first appears over Play, after the green transition |
| About 3:12.520 | 066 | The orange indicator has faded. Play is green and the lead-in continues |
| 3:13.120 | 084 | Last inspected frame with the source-start waveform still stationary |
| 3:13.153 | 085 | First inspected frame with the source waveform scrolling left through the play position |
| Through 3:14.287 | 119 | Play remains green and the source waveform continues to advance |

The first-clear-green to first-scrolling interval is approximately **1.93 seconds in the video UI**. This documents a visible waiting interval. It does not measure input latency, first audible output or a universal launch delay.

![Selected states from the adjacent-frame review](</Users/veland/GenErik DJ/Analysis/Traktor-DJ-1x/sources/hollin-frame-review-2026-10-21/S38-sequence-overview.jpg>)

## Is there a second press before launch?

Across the retained Play-region sequence, the orange indicator appears once, persists with expanding rings, then fades. No separate reappearance or clearly renewed pulse is identifiable before the source waveform begins scrolling. The exposed Play triangle is green after the first transition. The marker strip shows forward progress toward the source start, with no visible restart. No cancellation is established.

This is **not proof that only one physical input occurred**. The recording supplies an on-screen indicator, not a raw touch log or a view of the performer's finger. The solid indicator obscures Play for part of the waiting interval. Multiple inputs cannot be inferred from its duration or concentric rings.

The timing also rules out treating the indicator's onset as an exact contact timestamp: the first clear green Play frame precedes the first orange-indicator frame by **three reviewed steps, about 0.10 seconds**. The indicator's recording/annotation path is uncalibrated. Its disappearance must not be equated with finger release either.

The supported conclusion is therefore narrow: **the clip demonstrates a visible lead-in and eventual launch, but no identifiable second-press cancellation trial.** It cannot distinguish cancellation, ignored input or retriggering under a deliberate second press.

## Effect on the reconstruction

- **F143 gains independent visual support from S38:** a moving lead-in marker precedes source-waveform scrolling, with Play already green.
- **Q03 stays open:** the source does not establish whether the original app accepts touch down, touch up or another action edge.
- **Q05/F031 stay open:** no pending second-press policy was demonstrated.
- **Q02 stays open:** no preference is shown or changed. The observed waiting interval cannot identify Quantize Size's scope.
- **J10/C03:** capture physical input, Play colour, marker motion, source-waveform motion and first audio separately. Calibrate any added touch indicator before using it as timing evidence.

The [manifest](sources/hollin-frame-review-manifest.json) records all retained frames, derived contact sheets, event brackets and exclusions. The [validation result](sources/hollin-frame-review-validation.json) records file, hash, dimension and link checks. Exact installed 1.6.8 behaviour remains untested.
