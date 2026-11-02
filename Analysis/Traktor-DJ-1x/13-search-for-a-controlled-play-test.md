# Search for a controlled Play test

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

Reviewed 21 October 2026. Mac-only public research. The gig iPad was not connected, operated or changed. Jailbreak and device acquisition remain parked.

Follow-up: the [Hollin adjacent-frame review](14-hollin-jones-count-in-frame-review.md) extends this source coverage. It identifies one continuous orange indicator event but no distinct second activation during the visible lead-in. The timing rules below remain unresolved.

## Result

**No qualifying walkthrough was found in this pass.** The new public material adds support for an automatic incoming-track count-in. It does not establish that Quantize Size controls ordinary Play, or that a second Play press cancels a pending start. Q02 and Q05 remain open.

The strongest new public example is Hollin Jones's **Understanding Beat Matching**, lesson 11 of macProVideo's *Native Instruments 216: Traktor DJ for iPad*. Its captions describe waiting for the right moment to introduce the second track at 1:33–1:38. Near 3:12, an on-screen annotation says **“Traktor counts in automatically.”** [S38]

Selected frames show Deck A playing while Deck B is at its source start, then Deck B's green Play button and a pale line before the source start, then both decks with advanced waveforms. These are three sampled UI states, not adjacent-frame timing measurements or an audio-onset measurement. The sampled scene does not show the quantise preference or an identifiable second Play input during the lead-in.

![Public lesson's automatic count-in annotation](</Users/veland/GenErik DJ/Analysis/Traktor-DJ-1x/sources/controlled-play-search-2026-10-21/S38-count-in-192.753333.jpg>)

[Watch near 3:07](https://www.youtube.com/watch?v=mS8s2SOSGKQ&t=187s). The exact app build is not visible in the reviewed scene. This is historical original-app evidence, not an installed 1.6.8 test.

## Candidates checked

Complete caption reading is separate from complete visual or audio review. None of these videos received a continuous audiovisual review in this pass.

| Candidate | Reviewed coverage | What it contributes | Why it does not qualify |
| --- | --- | --- | --- |
| **S38 Hollin Jones: Understanding Beat Matching** | Complete English auto-captions; selected launch frames at 3:07.753, 3:12.753 and 3:17.753 | Explicit automatic count-in account and visible incoming-deck sequence | No size comparison or identifiable pending second press in the reviewed scene |
| **S27 Ean Golden: Feature Walkthrough and Demo** | Newly located embedded video; complete English auto-captions; partial visual check near 1:21 | Shared master tempo, sync, Freeze and preparation explanation | No requested paired test identified in caption coverage; selected visual check was partly obscured and is not timing evidence |
| **S39 Mike Russell: How To Sync, Scratch & Mix DJ Drops** | Complete English auto-captions; selected original-iPad scene at 0:44.650 | Loop preparation, ordinary playback and a narrated tempo-follow example | No Quantize Size comparison or pending-cancellation explanation identified in captions; selected frame is loop preparation |
| **S40 Jeremy Lim: Remix Songs with Loops and Cues** | Complete English authored/unspecified captions; selected original-iPad scene at 2:24.144; author's accompanying article | Distinguishes ordinary and loop cue use; describes zoom-dependent loop snapping | Its quantising discussion concerns the loop-creation grid. It does not establish a Quantize Size-to-Play rule |
| **Gaga Darsalia: Essential Mixing Tutorial** | Complete English auto-captions | Narration and sequence match NI's previously reviewed Essential Mixing tutorial, S17 | Treat as a duplicate lead, not an independent timing test |

The [macProVideo course catalogue](https://www.macprovideo.com/course/native-instruments-traktor-dj-for-ipad) lists **the Preferences** (lesson 2, 3:25), **Playing Back Tracks** (lesson 6, 4:49), and **Understanding the Master Tempo** (lesson 7, 3:23). The live lesson list marks these with lock icons. Selecting lesson 6 opened a subscription offer instead of the lesson. Selecting lesson 2 did not yield playable content in the checked view. No account, purchase or subscription was created. Those chapters remain **unreviewed leads**; their titles do not prove they contain either requested test. [S38]

## What would qualify

A useful match must identify the original iPad app and show all of the following in connected footage:

1. At least two visible **Quantize Size** selections, with Slicer Quantize treated separately.
2. Ordinary incoming-deck **Play** trials at those selections, with the other deck running and sync/clock conditions visible. Cue position and press phase must be comparable or measurable.
3. A clearly separate second Play press **after the first request and before the scheduled launch**.
4. The outcome through the scheduled boundary: cancellation, ignored input, replacement/retriggering or playback followed by pause. A green Play button alone does not identify audio onset or prove that the waiting interval has ended.

French S34 establishes preference changes, while Spanish S35 establishes a visible lead-in. They cannot be joined into one experiment. The new S38 count-in example does not bridge that gap either.

## Search scope and evidence limits

The pass checked focused public web results for original-iPad Play, Quantize Size, count-in and cancellation, then YouTube's own original-iPad quantise results. Most indexed quantise instruction concerned Traktor Pro, DJ 2 or the older desktop DJ Studio. Those products were excluded. The strongest original-app leads were inspected directly rather than accepted from titles or search snippets.

This is a bounded search result, not proof that no such recording exists. Caption silence cannot exclude an unspoken visual test outside the selected frames. Locked lessons were not bypassed, and no claim depends on their unseen contents.

The [search manifest](sources/controlled-play-search-manifest.json) records identities, caption hashes, review scope, exclusions and retained frame hashes. Full third-party captions remain temporary research inputs. No complete video was downloaded.

## Effect on the rebuild specification

- Preserve early Play and synced next-bar launch as the user's requirement, with existing period support [R1, S20]. S38 adds independent support for an automatic count-in in historical original-app footage.
- Keep Quantize Size's ordinary-Play scope unresolved [Q02].
- Keep pending second-press behaviour unresolved [Q05/F031].
- Keep cancellation and the relationship between global quantise and Play as explicit implementation proposals until verified. No feature row or installed-build claim was promoted in this pass.
