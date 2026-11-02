# Later 1.x: Play quantisation and queued-start cancellation

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

Reviewed on 21 October 2026 using public sources from the Mac. The performance iPad was not connected or operated.

**Neither requested timing rule is confirmed by this pass.** Later footage extends the menu evidence, but does not establish whether Quantize Size controls ordinary Play or whether a second Play press cancels a pending start. Q02 and Q05 remain open.

## Direct performer confirmation, 28 October 2026

The performer subsequently answered the original-app question: pressing Play again while an incoming synced deck waits **cancels the pending start**. Q05 is resolved by this direct report for that context. Native transport tests cover cancellation without moving the incoming source or interrupting the other deck. The historical public-source review below retains its original limits. Q02, ordinary Play’s relationship to Quantize Size, remains open.

## Later sources inspected

| Source | Scope actually reviewed | Result for the two questions |
| --- | --- | --- |
| [Stuart Ritchie, 1 January 2017](https://www.youtube.com/watch?v=di7uSZVBAlE&t=135s), S30 | Captions for introduction and Traktor section, approximately 0:00–8:42. Selected Playback frame near 7:41 | Shows the menu, with ½ Beat selected. No setting-versus-Play comparison or identifiable pending second press established |
| [Groove Logic TV, 17 August 2018](https://www.youtube.com/watch?v=TefuhGYDp0Q), S28 | Complete English auto-captions. Selected original-app frames near 1:36 and 8:02 | Discusses Sync/master tempo, cues, loops and Flux. No explicit answer to either timing question |
| [DarkWizardStudios, 21 April 2019](https://www.youtube.com/watch?v=KadcG76j8AU), S29 | Sparse auto-captions, mainly music. Selected frames at 0:00, 1:59.66 and 4:59.15 | Original-app interface is visible. Its description's “settings” does not establish a quantise-preference test. Inspected scenes lack the required input sequence |

None of the inspected material shows an About/version value. Publication dates must not be converted into exact app versions. S30 predates the existing historical leads for 1.6.8.

## Menu continuity into January 2017

At [7:41.354](https://www.youtube.com/watch?v=di7uSZVBAlE&t=461s), Playback shows **1/4 Beat, 1/2 Beat, 1 Beat and 1 Bar**, with **1/2 Beat checked**. The compact lower deck is playing. This is a current selection, not a fresh-install default test. **D, S30**.

![January 2017 original-app Playback preferences](</Users/veland/GenErik DJ/Analysis/Traktor-DJ-1x/sources/later-1x-frames/S30-2017-quantise-menu-461.354.jpg>)

This frame does not identify the launching input's master phase or the preference at that earlier instant. It cannot establish Play's scheduling policy. Only demonstrated UI is used here. The narrator's separate X1/F1 compatibility assertion is not adopted as a hardware specification. [S30]

## Why the public-source pass did not resolve cancellation

NI describes Play toggling playback and pausing an **already playing** deck. It does not describe the interval between an accepted early press and launch. [S1 §5.2.1]

Keep these observations distinct:

1. A second press pauses a deck after it starts.
2. A second press cancels a start before it fires.
3. A second press replaces or retriggers a pending start.

The first cannot establish the second or third. No clear pair of accepted Play inputs inside a confirmed pending interval was found in the inspected material. Cancellation, retriggering and an ignored second press remain possible reference outcomes.

## Other material checked

- [DJWORX's 19 August 2014 1.5 article](https://djworx.com/traktor-dj-1-5-superslicer-beyond/) supplies no Play/cancellation rule in its release summary or SuperSlicer discussion. Its embedded video is the already indexed NI announcement, S10.
- [Hiropon's 6 June 2019 comparison](https://www.hiropon.jp/?p=852), updated 12 October 2021, distinguishes the original app from DJ 2. The inspected article gives no queued-Play cancellation account. Its general similarity claims cannot transfer DJ 2 timing rules to 1.x.
- [Justin Nizza's 24 January 2016 video](https://www.youtube.com/watch?v=hPqcSOy6jN4) was rejected: its captions identify the app as edjing.

## Consequences for the rebuild

Retain the documented early Play requirement and the queued transport state. Implement the performer-confirmed second-Play cancellation for a waiting synced incoming deck. Keep `Play follows Quantize Size` marked **V — unresolved**. The [transport model](03-transport-sync-and-queued-starts.md) records this distinction. Installed 1.6.8 menu values, defaults and persistence remain untested. The reference trial below can provide recorded confirmation and resolve the other timing details.

## Refined later reference trial

These refinements to T04/T05 are for a separate test setup. They do not authorise operating the gig iPad now.

1. Establish a repeatable single-press control with the incoming cue on beat 1. Record grid/downbeat, Sync, Quantize Size and source position.
2. Repeat identical early inputs at all four sizes. Keep Slicer Quantize fixed. Compare launch boundaries in master-beat coordinates.
3. Repeat with the cue on beat 3 to distinguish next-bar and source-phase policies.
4. During an observed waiting interval, press Play again before its target. Record both contacts and acceptance feedback.
5. Observe through that target and one further bar. Record source movement and audio separately. Silence alone can result from mixer or effect settings.
6. Compare with single-press controls and second presses deliberately made after launch. Repeat before classifying cancellation or retriggering.

At 120 BPM, a four-beat bar spans two seconds. Begin cancellation trials with a clearly established long waiting interval where possible. Do not assume selecting 1 Bar creates that interval until step 2 demonstrates it.

## Provenance and limits

This pass reviewed captions and selected frames with the per-source limits above. It did not independently measure audio timing or inspect every frame. Absence from these passages does not establish absence from the app.

The [later-source manifest](sources/later-1x-manifest.json) records dates, review coverage, caption hashes, frame timestamps and image hashes. Full captions remain temporary research inputs. No executable acquisition, decompilation, device change or jailbreak operation occurred.
