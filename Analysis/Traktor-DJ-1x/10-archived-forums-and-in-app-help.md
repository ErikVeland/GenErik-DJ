# Archived forums and original in-app help

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

Reviewed on 21 October 2026 from the Mac. The gig iPad was not connected or operated.

**The two Play rules remain unresolved.** Original NI help screenshots were recovered, but their visible instructions concern navigation and performance gestures. No inspected passage establishes that Quantize Size controls ordinary Play, or that a second press cancels a pending start.

## What the original help establishes

[Bonedo's launch-day review](https://www.bonedo.de/artikel/test-native-instruments-traktor-dj/), dated 21 February 2013, reproduces the original app's help. These are NI-authored UI instructions hosted by a reviewer, not a newly acquired help bundle. Exact app build is not shown. **D, S31**.

The index visibly groups unused techniques under **Undiscovered Features**. Its tempo lesson explicitly concerns master tempo. Other visible entries cover browser access, compatible-track loading, track navigation, loop release, grid correction, Freeze triggering, cues, effects, effect/filter locks and recording. This is a partial index. The recording entry is clipped, and additional entries can be offscreen.

![Original Notification Centre index](</Users/veland/GenErik DJ/Analysis/Traktor-DJ-1x/sources/help-frames/S31-original-notification-index.jpg>)

The second recovered image shows instructions to enter Freeze, then **“Press and hold the Slices to slice the Loop.”** Its title and first step are above the captured area. The visible instructions concern a loop's slices. They do not describe the ordinary transport button. **D, S31**.

![Original Freeze help instructions](</Users/veland/GenErik DJ/Analysis/Traktor-DJ-1x/sources/help-frames/S31-original-freeze-help.jpg>)

Selected help scenes in S21 near 1:48–1:58 and S20 near 2:46 were also inspected. They show navigation, the index and grid correction. This is not a complete review of every help card. No conclusion about the absence of another Play lesson follows from these screenshots.

## Forum findings and archive access

| Material checked | What it actually supplies | Limit |
| --- | --- | --- |
| NI's old forum root | Currently resolves to the replacement Community home | It does not recover the old discussion text |
| Wayback availability lookup for the old NI forum | HTTP 429 on initial access and a later retry after backoff | No archived post was read through this lookup. Further retries stopped |
| Wayback CDX discovery request | Web reader could not retrieve results | No archive inventory or assertion that a post never existed |
| [NI quantise feature-request repost](https://community.native-instruments.com/discussion/3376/quantize-value-ability-to-change-from-just-whole-beat), S33 | Repeats a request from the previous forum and links to old threads | Its iPad comparison is unversioned and lists six values. It does not establish a 1.x Play or cancellation rule. The linked old request could not be retrieved |
| [NI downbeat discussion](https://community.native-instruments.com/discussion/5248/traktor-dj-for-ipad-downbeat-beatgrid-cue-sync-points-reset) | A user's downbeat question and proposed correction | No queued-Play test or exact version. Not used as transport evidence |
| [DJ TechTools discussion, 22–23 February 2013](https://forum.djtechtools.com/t/traktor-ios-for-controllerism/53725), S32 | Firsthand report that reducing quantise to ¼ beat helps Freeze triggering, with settings reached through the browser | A period corroboration, not an NI forum archive. Its tentative default statement is not a factory-default test |

The word *play* in the Freeze discussion means triggering slices. It cannot establish the scheduling policy of ordinary Play. Similarly, a report that Hotcues launch a stopped deck cannot establish how the transport button handles a second pending input.

## Effect on the reconstruction

| Rule | Status after this pass |
| --- | --- |
| Early ordinary Play can wait for a synced bar | Historical support retained from S20 and the user's requirement |
| Quantize Size controls ordinary Play's launch interval | **V — unresolved, Q02** |
| Second Play before launch cancels the pending start | **V — unresolved, Q05** |
| Historical quantise preference affects Freeze triggering | Period firsthand corroboration added, S32. Exact Slicer Quantize interaction remains open |
| Complete help catalogue and completion behaviour | **V — partial screenshots only, F131/C17** |

Keep Play scheduling independent of the general quantise preference in the provisional model until a source or controlled observation establishes their relationship. Keep cancellation as an explicit unverified policy. The paired trials in [the later review](09-later-1x-play-and-cancellation.md) remain the test plan for a separate reference setup.

The [forum/help manifest](sources/forum-help-manifest.json) records coverage, failed archive access, source boundaries and screenshot hashes. It contains no acquired app files or device captures.
