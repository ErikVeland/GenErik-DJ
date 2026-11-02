# Non-English walkthroughs: Quantize Size and queued Play

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

Reviewed on 21 October 2026 from public sources on the Mac. The gig iPad was not connected or operated.

**Neither Play rule is settled by this pass.** The strongest new evidence is a version-labelled French settings demonstration. It shows the quantise selection changing, but does not establish how that change affects ordinary Play or a pending second press.

The [adjacent-frame follow-up](12-french-spanish-frame-review.md) now recovers intermediate French selections and a Spanish moving lead-in marker. It extends this pass's coverage without resolving either Play policy.

## French: exact early version and a changed quantise setting

[Tutoriels MAO's walkthrough](https://www.youtube.com/watch?v=7XMkgFc5QI0&t=1122s), **S34**, shows **Version 1.0.3.182** in the lower-left corner of Playback preferences. At **18:42.413**, the four choices are **¼ Beat, ½ Beat, 1 Beat and 1 Bar**, with **½ Beat selected**. At **18:57.413**, **1 Beat is selected**. The latter frame also shows the separate Slicer Quantize and Freeze on Load controls. These are observed selections, not a factory-default test. **D, S34**.

![Version-labelled French quantise menu](</Users/veland/GenErik DJ/Analysis/Traktor-DJ-1x/sources/non-english-frames/S34-french-quantise-version-1122.413.jpg>)

![One-beat selection and separate slicer preference](</Users/veland/GenErik DJ/Analysis/Traktor-DJ-1x/sources/non-english-frames/S34-french-one-beat-and-slicer-1137.413.jpg>)

The complete French auto-captions were read. The **18:38–18:58** explanation does not connect these settings to ordinary Play. Selected scenes near **5:39–5:44** establish no pending-input test.

The August 2017 upload date does not establish 1.6.8 behaviour. The manifest preserves the differing local-UI and search date displays.

## Other languages and actual review coverage

| Source | Coverage | Result for the two Play questions |
| --- | --- | --- |
| **Spanish, S35:** [Deep Josh / Playtools](https://www.youtube.com/watch?v=apeU94YMVhE) | Original iPad interface identified. Selected frames near 2:05, 4:10, 5:12, 7:17, 8:19 and 9:22. No caption track available through the browser export | Inspected scenes show transport, loops, EQ/FX and help. No setting-versus-Play comparison or identifiable pending cancellation established. Spoken content was not reviewed |
| **German, S36:** [RECORDING.de introduction](https://www.youtube.com/watch?v=PvdhHKVMyLk) | Complete German auto-captions read. Opening transport frame inspected near 0:32.83. Linked firsthand review identified | Play and central tempo are discussed around 0:21–0:49. Captions give no explicit Quantize Size → ordinary Play rule or pending-second-press account |
| **Japanese, S37:** [OTAIRECORD written walkthrough](https://otaiweb.com/traktor2/traktordj.html) | Main feature walkthrough read in Japanese, including transport, loops, master tempo and browser. Embedded videos identified only | Explains that synced decks follow the master-tempo wheel. Supplies no Play-quantise or cancellation rule. This is a written guide, not a reviewed Japanese video |

The Spanish upload appears as 28 February 2013 in search and 1 March in the local YouTube UI. The German UI and linked article display 15 March 2013. Neither inspected video supplies an exact version label.

## Additional workflow confirmed

At **17:21–17:45**, S34 explains loading a saved recording into a deck. Selected frames at **17:42.413** and **17:52.413** show it loaded, then advanced to seven seconds. This supports recording playback through a deck, closing the capability gap in **F124**. Exact installed-build gestures remain untested.

![Saved recording playing in the lower deck](</Users/veland/GenErik DJ/Analysis/Traktor-DJ-1x/sources/non-english-frames/S34-french-recording-playback-1072.413.jpg>)

## What cannot be inferred

1. A changed quantise checkmark proves the preference changed. It does not prove which transport commands use it.
2. A later settings frame cannot establish the preference during an earlier launch.
3. Two Play presses separated by playback do not establish cancellation during a pending interval.
4. A sampled frame with a stopped deck cannot establish whether a prior command was accepted, cancelled or never sent.
5. Auto-captions can confuse Play, cue triggering and slice triggering. A specific timing claim needs clear context and visual corroboration.

The proposed per-command policy and paired reference trials remain appropriate. **Q02 and Q05 stay unresolved.** Historical next-bar Play support from S20 remains intact. This pass neither disproves that journey nor transfers a different app's timing rules into the reconstruction.

## Additional leads and limits

A [Turkish-language candidate](https://www.youtube.com/watch?v=mVVdP-VkRMY) has no available captions. A selected frame near 12:20 shows a phone-style original interface. The exact app edition was not verified, so it is excluded from iPad timing evidence. Its third-party automated summary was used only to locate the video.

Searches also covered Italian and Portuguese leads. No additional source from those searches was established as evidence for either rule. Previously reviewed German S26 already supports measure-aligned entry, without settling its preference mapping.

This was complete caption review for S34/S36 and selected visual review for the listed videos. It was not continuous audiovisual review or an audio timing measurement. The [manifest](sources/non-english-manifest.json) records scope, source identity, caption hashes and saved frame provenance. Full captions remain temporary research inputs.
