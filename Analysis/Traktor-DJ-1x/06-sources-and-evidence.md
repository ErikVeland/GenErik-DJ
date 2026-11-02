# Traktor DJ 1.x sources and evidence

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

Sources checked on 21 October 2026. NI manuals were downloaded without modification and hashed. Page numbers below are the printed manual pages. For the S4 manual, printed and PDF page numbers coincide.

## Primary documentation

### S1 Traktor Kontrol S4 MK2 manual

[NI original PDF](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/traktor_kontrol_s4_mk2_manual_english.pdf) · [local PDF](sources/traktor-kontrol-s4-mk2-manual-en.pdf) · [text extraction](sources/traktor-kontrol-s4-mk2-manual-en.txt)

NI-authored, October 2013 PDF metadata. Chapter 5, printed pages 73–95, specifically covers the iOS Traktor DJ app. Those pages were read. Pages 77 and 92 were also rendered and inspected for the EQ drawer, stacked deck layout, effect slots, XY pad, and lock icons. Chapters about desktop Traktor are not evidence for the iOS app.

Relevant sections: browsing 5.1.1, quantise 5.1.2, gain and EQ 5.1.4–5.1.5, filter 5.1.6, monitoring 5.1.7, navigation and tempo 5.1.8, transport 5.2.1–5.2.4, cues 5.2.5, loops 5.2.6, Freeze 5.2.7, FX 5.3.

The useful facts are control mappings, capability distinctions, state colours, and behaviour. The manual is a historical reference, not a test result from 1.6.8.

### S2 Traktor Kontrol S2 MK2 manual

[NI original PDF](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/traktor_kontrol_s2_mk2_manual_english.pdf) · [local PDF](sources/traktor-kontrol-s2-mk2-manual-en.pdf) · [text extraction](sources/traktor-kontrol-s2-mk2-manual-en.txt)

NI-authored. Chapter 5, printed pages 66 onward, covers iOS Traktor DJ. Relevant browsing, deck control, transport, cues, loops, Freeze, and FX sections were read. The S2 exposes four physical Hotcue buttons. That is not a four-cue limit for the app. Some passages mistakenly say S4 in the S2 chapter. The CUE description also differs from S1. Preserve these as documentation issues and verify the actual controller behaviour.

### S3 Traktor Kontrol Z1 manual

[NI original PDF](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/traktor_kontrol_z1_manual_english.pdf) · [local PDF](sources/traktor-kontrol-z1-manual-en.pdf) · [text extraction](sources/traktor-kontrol-z1-manual-en.txt)

NI-authored. Chapter 4, printed pages 15–19, was read. It covers the app's mixer, gain, monitoring, filter and FX modes, and MODE plus headphone CUE for deck Play/Pause. Desktop gain ranges and filter-model switching in Chapter 3 must not be transferred to the iOS specification.

### S4 NI support on Z1 mode and parameter persistence

[How to use the MODE button](https://support.native-instruments.com/support/solutions/articles/69000879505-how-to-use-the-mode-button-on-the-traktor-kontrol-z1)

The Traktor DJ section confirms filter cutoff on X, resonance on Y, FX parameter on X, and wet/dry on Y. Z1's knob controls X. Touch controls Y. The selected Y value persists through effect bypass and app shutdown. It also documents MODE plus ON, and the blue/orange hardware feedback.

### S5 NI getting started video and available transcript

[Official NI video](https://www.youtube.com/watch?v=3U7LqCkYeWc) · [transcript mirror](https://filmot.com/sidebyside/3U7LqCkYeWc/en/es/English/Spanish/Getting+started+with+Traktor+Kontrol+S4S2+and+Traktor+DJ+%7C+Native+Instruments/Native+Instruments)

Published 30 September 2013. The English transcript was first read through the mirror. The follow-up review also read the complete caption track exported from NI's YouTube watch page. It confirms tempo/grid alignment, classic mixing, simultaneous FX, beatjumps and Flux. Caption provenance is authored or unspecified. This video was not inspected frame by frame. Timestamped findings are in [the video review](07-ni-tutorial-video-findings.md).

### S6 NI external audio routing

[How to use Traktor DJ with an external audio interface](https://support.native-instruments.com/support/solutions/articles/69000879525-how-to-use-traktor-dj-with-an-external-audio-interface)

Read the complete instructions. The app has separate stereo Master and Monitor pairs under Preferences → Audio Setup. A loudspeaker control exposes master/cue levels and balance. The article documents first-connection guidance and the AUDIO 6/10 Direct Thru setup issue. No firmware or routing changes were made in this research.

### S7 NI original-app interface compatibility

[Traktor DJ iOS audio interface compatibility](https://support.native-instruments.com/support/solutions/articles/69000879440-traktor-dj-ios-audio-interface-compatibility)

The page explicitly says Traktor DJ 1. It identifies Core Audio, class-compliant audio devices, supported NI controllers, and incompatible older interfaces. Its listed **1.7.0** minimum for S2 MK2, S4 MK2, and AUDIO 2 MK2 conflicts with 2013 S2/S4 documentation and the local 1.6.8 reference. Do not use those version minima as settled facts. General class compliance does not prove a particular unit works with a particular cable and OS.

### S8 NI connection guide

[How to connect an NI controller or interface to iOS](https://support.native-instruments.com/hc/en-us/articles/210280705-How-to-Connect-your-NI-Controller-Audio-Interface-to-an-iOS-Device)

Read for the distinction between an audio interface and a surface controller, power requirements, and adapter families. This page mixes newer hardware and app generations. Do not infer original-app S2 MK3 or S3 control support from it.

### S9 NI AUDIO 2 identification

[AUDIO 2 troubleshooting](https://support.native-instruments.com/support/solutions/articles/69000879468-traktor-audio-2-troubleshooting-guide)

Confirms that the later AUDIO 2 MK2, rather than MK1, offers iOS Traktor DJ integration.

### S10 NI SuperSlicer announcement

[Introducing SuperSlicer](https://www.youtube.com/watch?v=oRNAV-GlH18)

NI announcement dated 19 August 2014. Its description ties SuperSlicer to 1.5 and names Scratch, Brake, Reverse, Slice and Pitch-shift. The follow-up review checked its sparse auto-generated captions and selected frames near 0:16, 0:48 and 1:04. A Features settings category is visible. The mainly musical presentation does not establish the full gesture or parameter mapping. See [the review limits](07-ni-tutorial-video-findings.md).

### S11 NI preparation tutorial

[Preparation tutorial](https://www.youtube.com/watch?v=i5OZGtHZz_E)

NI tutorial dated 10 April 2013. The complete auto-generated English caption track was read. The eight-slot cue drawer was also inspected at approximately 2:05.27. It directly documents background collection analysis, grid correction, BPM half/double/tap, four-beat inspection, eight cues, hot-loop recall, and historical bidirectional metadata exchange without audio transfer. Exact deletion, scheduler and later-build rules remain open. [Timestamped findings](07-ni-tutorial-video-findings.md).

### S12 NI performing and browsing tutorials

[Performing](https://www.youtube.com/watch?v=B_8eahCGr1k) · [Browsing](https://www.youtube.com/watch?v=U2exstE0GmQ) · [Essential mixing](https://www.youtube.com/watch?v=tHX-IvmbfJE) · [Advanced S2/S4 usage](https://www.youtube.com/watch?v=4Gu9yFE5-Oo)

This group remains a compatibility alias for earlier citations. The follow-up review read the complete caption tracks and inspected selected demonstrations. The individual sources are now S15–S18 below. Performing, Browsing and Essential Mixing use auto-generated English captions. Advanced controller captions are authored or unspecified. Selected visual inspection is distinct from a complete audio or frame-by-frame review.

### S13 NI statement on waveform performance and Mixcloud

[NI press release PDF](https://www.native-instruments.com/fileadmin/ni_media/downloads/press/NI_The_Future_Of_DJing_A_Guy_Called_Gerald_Press_Release.pdf)

Dated 18 September 2014 within the release. It explicitly describes waveform manipulation, beat jumping, loop slicing, and recording/uploading mixes through Traktor DJ. A search engine's recent crawl date is not its publication date.

### S14 NI 1.4 press release reproduced by DJWORX

[NI release within the article](https://djworx.com/traktor-dj-1-4-drops-mixcloud-integration-effects/)

The NI-authored release is identified and reproduced in the article. It establishes the 30 April 2014 release of 1.4 with Mixcloud, new effects, and usability changes. Publisher commentary is separate. Specific extra effect names and unlock mechanics remain historical leads until the installed menus are captured.

### S15 NI browsing tutorial reviewed

[NI original](https://www.youtube.com/watch?v=U2exstE0GmQ). Published 11 April 2013. Complete caption track read. Master-tempo, directional load-slider and recommendation scenes inspected visually. The touch tempo wheel is explicit at 2:08–2:19. Timed navigation is explicit at 2:19–2:36. Sorting, search, playlist creation and Notification Centre are also described. See the [timestamped findings](07-ni-tutorial-video-findings.md) and [provenance manifest](sources/tutorial-manifest.json).

### S16 NI performing tutorial reviewed

[NI original](https://www.youtube.com/watch?v=B_8eahCGr1k). Published 11 April 2013. Complete caption track read. Selected loop, launch and FX scenes inspected, including frame stepping around 2:06–2:08. The video documents touch loops, Freeze, drawer entry, FX selection, EQ reset, multitouch and filter locking. Its launch scene does not expose a clear input timestamp or quantise value. Loop-dismissal finger count remains ambiguous.

### S17 NI essential mixing tutorial reviewed

[NI original](https://www.youtube.com/watch?v=tHX-IvmbfJE). Published 11 April 2013. Complete caption track read. NI attributes incoming-track timing to the app near 1:30–1:40 and explicitly describes a delay tail continuing after deck Stop near 3:44–4:04. Neither passage establishes an exact one-bar queue interval. This review did not make an independent audio measurement.

### S18 NI advanced controller tutorial reviewed

[NI original](https://www.youtube.com/watch?v=4Gu9yFE5-Oo). Published 30 September 2013. Complete caption track read. It documents four/eight loop-slice access on S2/S4, a default Flux state in that demonstration, navigation commit, and holding/releasing SHIFT+SYNC around grid editing. These statements are scoped to the demonstrated controller workflow.

### S19 NI original playlist and unavailable entry

[NI playlist](https://www.youtube.com/playlist?list=PLkFqg7ZvTWb0m0zXdsmXcVbTrkAowoaDE). Its current UI lists eight videos and one unavailable entry. Showing unavailable entries reveals `qaRgoKxWFo0`. The [watch page](https://www.youtube.com/watch?v=qaRgoKxWFo0) states that it is private. Its title and content were not available. The Preparation tutorial independently explains the historical collection-sync distinction. Do not identify the private entry solely from its position in the playlist.

## Firsthand period reviews and walkthroughs

These sources record direct use of the original app. They provide historical observation, not measurements of the installed 1.6.8 build. See the [period findings](08-period-reviews-and-quantised-play.md) and [manifest](sources/period-review-manifest.json) for scope and provenance.

### S20 Dubspot / Endo iPad tutorial, part 1

[Original video](https://www.youtube.com/watch?v=5Rd73mY60FE). Published 30 April 2013. Full auto-generated English captions read; selected master-tempo and launch frames inspected. The key Play passage is 7:23–7:37. No calibrated input/audio trace.

### S21 Digital DJ Tips iPad review video

[Original talkthrough](https://www.youtube.com/watch?v=Oc4OBDCZnpc). Published 21 February 2013. Full auto-generated English captions read; Playback preferences inspected and captured. Settings/default evidence is at 4:13–5:05; Loop Slicer commentary at 10:19–10:34.

### S22 Digital DJ Tips iPhone review

[Phil Morse's review](https://www.digitaldjtips.com/reviews/traktor-dj-iphone/). Published 2 May 2013; page says updated 2 November 2021. The Music library section supplies cross-platform corroboration only. It is not iPad-build evidence.

### S23 Digital DJ Tips iPad written review

[DJ Hombre's launch review](https://www.digitaldjtips.com/reviews/traktor-dj-ipad/). Published 21 February 2013; updated 25 October 2021. Read the central-tempo and settings passages. This promotes H4 for the specific firsthand claims used here; it does not adopt every review judgement.

### S24 Dubspot / Endo iPad tutorial, part 2

[Original follow-up](https://www.youtube.com/watch?v=kc99WythujM). Published 8 May 2013. Focused auto-caption review of transport, loops and slicing. The loop-dismissal instruction at 10:29–10:34 remains a lead requiring visual confirmation. No full audiovisual review claimed.

### S25 Resident Advisor iPad review

[Mark Strauss's hands-on review](https://ra.co/reviews/12524). Published 26 February 2013. Read the global-tempo/Sync passage. The page's separate “Released February 2012” field conflicts with its narrative and publication chronology; do not use it as the app's launch date.

### S26 AMAZONA iPad review

[Review, page 1](https://www.amazona.de/test-native-instruments-traktor-dj-app/) and [tempo/start observations, page 2](https://www.amazona.de/test-native-instruments-traktor-dj-app/2/). Published 7 March 2013. The tempo and measure-start discussion was read in German and paraphrased in English. No exact engine timing was measured by this research.

### S27 DJ TechTools launch-day first look

[Dan White's first look](https://djtechtools.com/2013/02/21/traktor-dj-on-ipad-exclusive-first-look/), read through its [publisher CDN copy](https://s11234.pcdn.co/2013/02/21/traktor-dj-on-ipad-exclusive-first-look/). Published 21 February 2013. The initial article pass inspected the written Freeze/preferences passage and left the embedded Ean Golden walkthrough unreviewed.

The later controlled-test search located the embedded [Ean Golden video](https://www.youtube.com/watch?v=xrgPQ045L1c), *Traktor DJ: Feature Walkthrough and Demo*. Its complete English auto-captions were read. A partial visual check near 1:21 was obscured by browser UI and is not used for timing. The caption account covers master tempo and sync but supplies no explicit Quantize Size-to-Play or pending-cancellation rule. Exact app build was not established.

### S28 Groove Logic TV later original-app walkthrough

[Original video](https://www.youtube.com/watch?v=TefuhGYDp0Q). Published 17 August 2018. Complete English auto-captions read, with selected original-app frames inspected near 1:36 and 8:02. No exact app build shown. No explicit Play-quantise or pending-cancellation account located in the reviewed captions.

### S29 DarkWizardStudios original-app performance

[Original video](https://www.youtube.com/watch?v=KadcG76j8AU). Published 21 April 2019. Sparse auto-captions read. Selected scenes inspected at 0:00, 1:59.66 and 4:59.15. No complete visual review or independent audio measurement. The title/description does not establish that a quantise preference is tested.

### S30 Stuart Ritchie later app comparison

[Original comparison](https://www.youtube.com/watch?v=di7uSZVBAlE). Published 1 January 2017. Caption review scoped to the introduction and original Traktor section, approximately 0:00–8:42. Playback frame captured at 7:41.354. Treat the selected UI as evidence, not every narrator claim. Exact build and the two requested timing rules remain unestablished. See [later findings](09-later-1x-play-and-cancellation.md).

### S31 Original NI help reproduced by Bonedo

[Numinos's launch-day review and help gallery](https://www.bonedo.de/artikel/test-native-instruments-traktor-dj/), dated 21 February 2013. NI-authored in-app text is visible in the Notification Centre index and a scrolled Freeze/loop instruction card. Two browser-rendered images were inspected and captured. These are partial original-help screenshots, not a recovered help bundle or a complete catalogue. Exact app build is not shown. See [the help review](10-archived-forums-and-in-app-help.md) and its manifest for original image URLs.

### S32 Period firsthand Freeze-quantisation report

[DJ TechTools forum discussion](https://forum.djtechtools.com/t/traktor-ios-for-controllerism/53725), posts dated 22–23 February 2013. The user reports Freeze triggering at half-beat intervals and an improvement after choosing quarter-beat quantisation. Read the complete four-post discussion. This corroborates Freeze scope and settings location. It does not prove an ordinary Play rule, factory default, installed-build behaviour or pending cancellation. This is not an NI forum archive.

### S33 NI Community repost of an old quantise request

[Quantize Value feature request](https://community.native-instruments.com/discussion/3376/quantize-value-ability-to-change-from-just-whole-beat). The post repeats an earlier forum request and links to the old request and a Traktor 3.5.2 release thread. The iPad comparison does not identify its app version. Its six-value list must not replace the four-value 1.x menu observed in S21/S30. The current post was read, but the linked old request could not be retrieved. Not used as original-app timing evidence.

### S34 French original-app walkthrough with visible version

[Tutoriels MAO walkthrough](https://www.youtube.com/watch?v=7XMkgFc5QI0). Uploaded August 2017. Local UI displays 24 August and search displays 23 August. Complete French auto-captions read. Selected settings frames show **Version 1.0.3.182** and a changed quantise selection. Recording load/playback is supported by captions and selected frames near 17:42–17:52. No ordinary Play policy or cancellation rule confirmed. See [non-English findings](11-non-english-walkthroughs.md).

### S35 Spanish Playtools / Deep Josh walkthrough

[Original iPad demonstration](https://www.youtube.com/watch?v=apeU94YMVhE). Search dates it 28 February 2013, while the local YouTube UI displays 1 March. No caption track was available through export. Selected visual scenes near 2:05, 4:10, 5:12, 7:17, 8:19 and 9:22 identify the original app and several performance/help views. Spoken content was not reviewed. Exact version and both Play rules remain unestablished.

The [frame follow-up](12-french-spanish-frame-review.md) extends S34/S35 coverage. It records adjacent preference changes and first/later Play in S34. S35 shows a moving lead-in marker before waveform scrolling on Deck B. The video UI sequence is documented. Physical input acceptance, first audio, quantise mapping and pending second-press behaviour remain unmeasured.

### S36 German RECORDING.de introduction

[Original introduction](https://www.youtube.com/watch?v=PvdhHKVMyLk), linked by the author's [15 March 2013 review](https://recording.de/threads/test-traktor-dj-fuer-das-ipad.244806/). YouTube's local UI also displays 15 March. Complete German auto-captions read, with an opening transport frame inspected near 0:32.83. The Play/master-tempo explanation does not establish a quantise setting comparison or pending-start cancellation. The separate embedded performance was identified but not reviewed in this pass.

### S37 Japanese OTAIRECORD feature walkthrough

[Original-app written guide](https://otaiweb.com/traktor2/traktordj.html). Publication date and exact version not established. Read the main feature walkthrough in Japanese. It explains the tempo wheel and synced decks following master tempo. It supplies no rule for ordinary Play quantisation or cancellation. Embedded videos were identified, not reviewed as Japanese-language instruction. No unverified audio-interface or stability claims were promoted.

### S38 Hollin Jones / macProVideo original-iPad course

[Public lesson 11](https://www.youtube.com/watch?v=mS8s2SOSGKQ), *Understanding Beat Matching*, and the publisher's [32-lesson course catalogue](https://www.macprovideo.com/course/native-instruments-traktor-dj-for-ipad). Complete English auto-captions of lesson 11 read. Selected frames at 3:07.753, 3:12.753 and 3:17.753 show an incoming-deck sequence, including an explicit automatic-count-in annotation. Exact app build and upload date were not established in this pass. This is not a calibrated timing or audio-onset test. The course marks lessons 2/6/7 locked; lesson 6 opened a subscription offer, and no playable lesson 2 content was recovered. Their contents remain unreviewed. See the [controlled-test search](13-search-for-a-controlled-play-test.md).

The [frame follow-up](14-hollin-jones-count-in-frame-review.md) reviews 120 retained adjacent captures from 3:10.320 to 3:14.287. It brackets green Play and source-waveform scrolling and identifies one uninterrupted orange indicator event. No distinct second activation is identifiable. The indicator follows the green transition, so it is not a calibrated input timestamp. An initial variable-layout capture pass was excluded and removed. No audio onset or installed-build trial was measured.

### S39 Mike Russell original-iPad DJ-drop walkthrough

[How To Sync, Scratch & Mix DJ Drops](https://www.youtube.com/watch?v=WxfpLsXGya4). Complete English auto-captions read; original-iPad loop-preparation frame inspected at 0:44.650. Narrates loop playback and a tempo-follow example. No explicit size-versus-Play or pending-cancellation account was found in the captions. No continuous visual review, audio measurement or exact build identification.

### S40 Jeremy Lim original-iPad loops and cues

[Original video](https://www.youtube.com/watch?v=DIcQFURRf0g) and [author's accompanying tutorial](https://jeremylimmusic.com/tutorials/remix-songs-loops-cues-ipad/), dated 27 February 2013 on the article. Complete English authored/unspecified captions read; selected original-iPad frame inspected at 2:24.144; main written tutorial read. Its zoom-dependent quantising discussion concerns loop creation. It does not establish ordinary Play scheduling or a pending second-press rule. Exact app build not shown in the reviewed scene.

### S41 NI original iPad launch announcement reproduced by Rekkerd

[Announcement dated 21 February 2013](https://rekkerd.org/native-instruments-releases-traktor-dj-app-for-ipad/). The main announcement and quoted NI release were read. The recommendation passage names tempo, key and timbre analysis. This establishes a declared original-iPad capability, not its algorithm or measured accuracy. The text also describes live grid creation and feature-aware help. It does not describe personal-history learning. That behaviour is separately supplied by the performer's direct account, R2. No later DJ 2 claim is imported.

## Local evidence

### L1 Reference identity

[App metadata](../traktor-dj-metadata.json) and [runtime report summary](../reference-runtime-evidence.json).

Observed version 1.6.8, build 1.6.8.67, iPad bundle `com.native-instruments.traktordj`, Store ID 592052832. Existing runtime evidence reports arm64. The iMazing size field is 70,647,808 bytes. That value is not an IPA size, RAM budget, or unpacked asset inventory.

The reference device is an iPad Pro 10.5-inch, iPad7,3, iPadOS 17.7.11. Its installed state does not establish general support for that OS.

### L2 Existing recording exports

[Export observations](../export-format-observations.json) and [acquisition report](../document-acquisition.json).

There are 27 XML files with 1,039 track entries in total. The document root identifies a Native Instruments tracklist. Track attributes are `artist`, `guid`, `name`, `restype`, and `starttime`. The observed resource type is `local`. GUID strings have 16 characters. Timestamp units and ID semantics remain unresolved.

The 26 WAV exports checked are stereo, 44,100 Hz, 16-bit uncompressed PCM. This is an export observation, not proof of internal DSP precision or every available recording format. The backups were not modified or re-analysed in this pass.

### R1 User's performance requirements

The request on 21 October 2026 identifies master tempo and pressing Play before the synced next bar as important behaviour. It also parks the jailbreak until after the next gig. These are direct requirements. Exact UI feedback and event rules still need capture.

### R2 Performer's next-track suggestion account

On 21 October 2026, the performer identifies suggestions as the key feature and reports BPM, key, genre and learning from previous mixes and track combinations. In a direct follow-up answer, the performer explicitly confirms observing TDJ1's rankings adapt. Record adaptive history-aware suggestions as required original behaviour, not a proposed enhancement. The exact internal learning method and feature weights have not been recovered. The [suggestion fidelity contract](16-next-track-suggestion-fidelity.md) preserves that distinction without weakening the behavioural requirement.

### R3 Exact replication and performer reference authority

The performer states 13 years of hands-on TDJ1 work and requires replication of everything as it is. Preserve original behaviour, defaults, UI, sound, timing, persistence and quirks. Existing proposed models remain non-normative where the original is unresolved. This request does not authorise device access or resumption of jailbreak work. [Governing fidelity specification](15-performer-fidelity-specification.md).

### R4 Eight core performer requirements

On 23 October 2026, the performer identifies recommendations, key/BPM analysis, grid correction, reliable master-tempo sync, early Play and Z1 integration as core requirements. The performer then explicitly adds integration with the iTunes / Apple Music library and recording sets as AIFF with transfer to Mac.

These are requirements for the modern replica. In a follow-up on the same date, the performer explicitly limits library integration to local/synced iTunes and Apple Music music, excludes subscription streaming, and requests this integration as the next implementation task. AIFF is explicitly required, while the existing acquired recordings are WAV files under L2. Preserve both facts without relabelling those exports.

The latest early-Play wording says "next beat". R1 describes the next synced bar. Retain both accounts and resolve the exact boundary and settings against the reference. The current development renderer's fixed next-bar rule does not settle that question.

On 24 October 2026, the performer explicitly requires the same integration with the iPad's own local/synced library. Mac support alone does not satisfy the requirement. Native iPad library access, playlists, preparation and deck use must pass on an authorised test device. This is a completion requirement, not permission to modify the parked gig iPad.

### R5 Complete iPad gesture parity

On 25 October 2026, the performer explicitly requires all Traktor DJ 1.x iPad gesture support 1:1, highlighting selection, gridding, zoom and two-dimensional filter controls. This establishes required coverage, not the unresolved mechanics of individual gestures. The [gesture fidelity contract](17-gesture-fidelity.md) records those distinctions and implementation gaps.

## Historical leads that need stronger or direct evidence

These sources locate features to inspect. They are not the normative basis for uncertain technical details.

| Key | Source | Lead |
| --- | --- | --- |
| H1 | [1.5 coverage](https://djworx.com/traktor-dj-1-5-superslicer-beyond/) | SuperSlicer purchase, history playlists, grid snapping improvements |
| H2 | [Retained app description and release notes](https://synthyfrog.com/app/traktor-dj/) | 1.6.8 iCloud replacement for Dropbox, music access, Audiobus, device requirements |
| H3 | [1.4 announcement coverage](https://www.macmusic.org/news/view.php/lang/en/id/12806/) | Iceverb, Transpose Stretch, Reverse Grain, free unlock prompt, playlist and subfolder editing |
| H4 | [Launch review](https://www.digitaldjtips.com/reviews/traktor-dj-ipad/) | Written review now S23; its original iPad video is S21. NI sources independently cover wheel/grid gestures |
| H5 | [Launch review](https://www.musicradar.com/news/tech/review-native-instruments-traktor-dj-for-ipad-571281) | Original eight effect names, split output, early single-effect limit |
| H6 | [Audiobus coverage](https://cdm.link/traktor-dj-ios-adds-audiobus-connect-apps-alone/) | Audiobus as a source rather than filter |
| H7 | [2017 1.6.8 coverage](https://www.hispasonic.com/noticias/regresa-traktor-dj-para-ipad/42994) | iCloud data, recommendation refinements, music-permission distinction |
| H8 | [Collection converter author's help](https://dark-controller.com/wp-content/uploads/2024/01/TraCoConverter_Help.html) | `collection.nml.gz` in iCloud Drive. This is the converter developer's account, not an acquired local collection |
| H9 | [Touch workflow review](https://ask.video/article/audio-plug-in/review-traktor-dj-for-ipad) | Loop creation/move/resize now directly supported by S16. Exact dismissal and background behaviour remain open |

H2 and H7 place 1.6.8 in June 2017. Some later coverage calls it a new update in March 2018. Use the version number for the reference. The later article date does not prove a second release.

### H5 direct review — 28 October 2026

The full 21 February 2013 review describes the author's first week with the app. Its eight base-effect names and shared-pad/tab layout are direct launch-era observations. The retained [interface image](sources/period-review-frames/H5-MusicRadar-2013-interface.jpg) shows simultaneous half-width FX/mixer panels, separate EQ/filter tabs and four vertical faders. The adjacent JSON records the public image URL and hash. This strengthens those observations; it does not establish later 1.6.8 defaults, mobile parameter curves or hidden-lock touch semantics.

## Evidence rules

1. Keep capability, touch gesture, controller mapping, and measured sound as separate claims.
2. A tutorial description only establishes its topic. It does not establish all events in the video.
3. Do not use DJ 2 quantise menus as proof of 1.x values.
4. Do not import current Traktor Pro transport, flexible grids, Link, DVS, stems, streaming, or settings into this target.
5. A picture of a lock establishes a visible control, not its exact press/hold semantics.
6. When an observation conflicts with a historical manual, keep both and identify version, hardware, and settings.
7. Use external words sparingly. The reconstruction models, test cases, and implementation proposals are original work.
