# French and Spanish frame review: Play and the visible lead-in

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

Reviewed on 21 October 2026 from the Mac. The gig iPad was not connected or operated.

**The Spanish incoming-deck start shows a visible lead-in before the waveform scrolls.** This adds a concrete UI behaviour to the reconstruction. Quantize Size's relationship to ordinary Play and second-press cancellation remain unresolved.

## Method and coverage

Paused YouTube playback was advanced with the player's single-frame keys. Observed steps were approximately 33 ms for French S34 and 40 ms for Spanish S35. The audit contains **210 frame-step captures across six sequences**, including overlapping inspection passes. One obscured French capture was excluded and removed. Initial French detail crops that clip the selected row are marked unsuitable for bracketing that change.

Times below identify video-player positions, rounded to useful frame brackets. They are not input timestamps or audio measurements. Browser overlays obscure parts of some captures. The Spanish physical-camera inset and mirrored app screen have no measured alignment. Contact down/up and engine acceptance therefore cannot be timed from their apparent separation.

| Source | Adjacent-frame coverage |
| --- | --- |
| French S34 | Preference changes near 18:47–18:50, first Play near 3:33, later Play near 20:46 |
| Spanish S35 | First-deck start near 2:49, incoming Deck B start and lead-in near 4:13–4:16 |

Coarser surrounding frames located the events. This is targeted frame review, not a frame-by-frame review of either complete video. Exact capture ranges and exclusions are in the [manifest](sources/frame-review-manifest.json).

## French: intermediate preference selections recovered

The earlier half-beat and one-beat snapshots missed intermediate changes. Adjacent frames in [the French walkthrough](https://www.youtube.com/watch?v=7XMkgFc5QI0&t=1127s) show this sequence in **version 1.0.3.182**:

| Last frame before change | First clear frame after change | Selection |
| --- | --- | --- |
| 18:47.513 | 18:47.547 | ½ → ¼ Beat |
| 18:48.747 | 18:48.780 | ¼ → ½ Beat |
| 18:49.447 | 18:49.480 | ½ → 1 Beat |

These are preference changes. No matched incoming-deck launches are demonstrated at those different selections. Both compact decks appear stopped in the surrounding preference views. [S34]

The first ordinary Play transition is near **3:33.1**. One browser overlay prevents classification of a frame between the last clear grey and first clear green button. A later start, after the settings demonstration, changes grey to green near **20:45.9**. That start occurs in the beatgrid editor with the other deck stopped. Later frames show tap-tempo changes. It does not provide a second size-versus-launch comparison. [S34]

## Spanish: a visible lead-in before source scrolling

In [the Spanish walkthrough](https://www.youtube.com/watch?v=apeU94YMVhE&t=253s), Deck A is already playing and both Sync indicators are green before Deck B's start. The inspected sequence supplies these observations:

| Video position | Visible state |
| --- | --- |
| 4:14.136 | Deck B Play remains grey. Source-start waveform is stationary |
| 4:14.176 | A pale vertical marker appears to the left of the source-start marker |
| 4:14.216 | Play is clearly green. The pale marker continues toward the source start |
| 4:15.416 | The moving marker reaches the source-start region |
| 4:15.456 onward | The waveform begins scrolling through the play position. Play stays green |

The green-to-scrolling interval is approximately **1.2 seconds in the video UI**. This supports a visual lead-in state. It does not establish first audible output, the exact scheduling boundary, or the internal transport implementation. The quantise preference is not shown during this sequence. [S35]

![Spanish incoming deck during the visible lead-in](</Users/veland/GenErik DJ/Analysis/Traktor-DJ-1x/sources/frame-review-2026-10-21/S35-deck-b-lead-in-context-254.696.jpg>)

![Spanish incoming deck after waveform scrolling begins](</Users/veland/GenErik DJ/Analysis/Traktor-DJ-1x/sources/frame-review-2026-10-21/S35-deck-b-playing-context-255.895976.jpg>)

The first-deck start near **2:49.67** also changes Play from grey to green, followed by waveform movement. That first-deck case has different clock conditions and cannot substitute for the incoming-deck trial. [S35]

## Does a second press cancel?

**No cancellation trial is established.** The Spanish inset shows a touch approach and withdrawal around Deck B's start. Perspective, finger occlusion and the uncalibrated composite prevent a reliable count of accepted inputs. No clearly separate second Play contact is identifiable during the visible lead-in, and playback proceeds.

That observation does not distinguish cancellation, an ignored second press, retriggering, or ordinary pause after playback has begun. The French scenes also provide no identifiable pair of accepted Play presses inside a confirmed waiting interval. **Q05 remains open.**

## Consequences for the reconstruction

- **F143 added:** reproduce the observed moving lead-in marker as a distinct UI capability. Exact installed-build geometry and conditions remain untested.
- **Q02 remains open:** French preference changes and Spanish lead-in footage cannot be combined into one controlled experiment.
- **J10/C03 refined:** record Play colour, lead-in marker position, waveform motion and first audio separately. A green button does not by itself establish that source audio has begun.
- **F031/Q05 remain unresolved:** do not promote the proposed cancellation policy to documented behaviour.

No device trial, app acquisition, decompilation or jailbreak operation occurred. All captured images came from public videos viewed on the Mac.
