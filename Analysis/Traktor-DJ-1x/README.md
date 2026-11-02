# Traktor DJ 1.x reconstruction research

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

Reference date: 21 October 2026, Australia/Brisbane.

The target is the original Native Instruments Traktor DJ for iPad. The installed reference is **1.6.8, build 1.6.8.67**, bundle `com.native-instruments.traktordj`. Traktor DJ for iPhone, Traktor DJ 2, Traktor Pro, and the older desktop Traktor DJ Studio are separate products.

The next-track suggestion engine is a core performer feature, supported by analysis and gridding. Current development prioritises analysis accuracy across BPM, key, energy and downbeat before further feature work; runtime audio and live controls retain scheduling precedence. The performer reports genre-aware suggestions and observed rankings that adapt with previous mixes. Direct waveform control and a shared musical timeline connect track choice to entry, loops, jumps, Freeze and Flux. Preserve that complete experience, including early Play for a synced bar boundary. [R1–R3]

**Fidelity is the governing requirement.** Reproduce everything as it is, including ordinary functions and original quirks. The performer's 13 years of TDJ1 use is reference evidence. Unknown behaviour stays open. Existing **P** proposals are non-normative hypotheses, not authorisation to change the product. Start with the [performer fidelity specification](15-performer-fidelity-specification.md) and [next-track suggestion contract](16-next-track-suggestion-fidelity.md).

**Jailbreak and device modification are parked until after the next gig.** This research used public material and existing local evidence. It did not operate the iPad, change its setup, or run acquisition tools. No automatic resumption has been scheduled.

## Read the research

| File | Purpose |
| --- | --- |
| [Product and technical specification](01-product-and-technical-specification.md) | What made the app distinctive, version boundaries, UI structure, audio and data requirements, rebuild architecture |
| [Feature and interaction inventory](02-feature-and-interaction-inventory.md) | A numbered inventory of capabilities and behaviours, with evidence and remaining checks |
| [Transport sync and queued starts](03-transport-sync-and-queued-starts.md) | Master tempo, keylock, beat phase, bar phase, early Play, cancellation, Flux, and a proposed event model |
| [User journeys and acceptance criteria](04-user-journeys-and-acceptance-criteria.md) | Workflows from music preparation through a live set, recording, recovery, and hardware operation |
| [Reference capture and open questions](05-reference-capture-and-open-questions.md) | A later capture protocol, exact unresolved details, measurement methods, and a completion gate |
| [Sources and evidence](06-sources-and-evidence.md) | Primary documentation, local evidence, historical leads, source conflicts, and reading scope |
| [Original NI tutorial video findings](07-ni-tutorial-video-findings.md) | Timestamped findings, confirmed touch workflows, master-tempo wheel, launch-scene limits, and evidence frames |
| [Period reviews and quantised Play](08-period-reviews-and-quantised-play.md) | Original iPad quantise menu/default, separate Slicer Quantize switch, and explicit period support for deferred Play |
| [Later 1.x Play and cancellation review](09-later-1x-play-and-cancellation.md) | 2017–2019 source checks, later menu evidence, and remaining Play-policy/cancellation gaps |
| [Archived forums and original in-app help](10-archived-forums-and-in-app-help.md) | Recovered NI help screenshots, period Freeze report, archive access limits and unresolved Play rules |
| [Non-English walkthroughs](11-non-english-walkthroughs.md) | French version-labelled quantise change, Spanish/German video coverage, Japanese guide and remaining timing gaps |
| [French and Spanish frame review](12-french-spanish-frame-review.md) | Adjacent preference transitions, ordinary Play scenes, Spanish moving lead-in marker and cancellation limits |
| [Search for a controlled Play test](13-search-for-a-controlled-play-test.md) | New public count-in example, course access limits, candidate coverage and the still-missing paired test |
| [Hollin Jones count-in frame review](14-hollin-jones-count-in-frame-review.md) | Adjacent Play/marker/scroll transitions, one continuous orange indicator event and limits on identifying a second press |
| [Performer fidelity specification](15-performer-fidelity-specification.md) | Governing exact-replication rules and specialised performer contracts, led by suggestions, analysis and gridding |
| [Next-track suggestion fidelity](16-next-track-suggestion-fidelity.md) | Tempo, key, timbre, reported genre/history inputs, observed adaptive rankings and exact-output comparisons |
| [Complete iPad gesture fidelity](17-gesture-fidelity.md) | Required gesture coverage, source audit, unresolved mechanics and paired iPad acceptance |
| [Music analysis fidelity](18-music-analysis-fidelity.md) | Exact BPM, key, energy and automatic downbeat acceptance, current engine and historical baseline scope |
| [Machine-readable gesture contract](contracts/gesture-fidelity.json) | Gesture implementation gaps and reference trials; parity remains incomplete |
| [Machine-readable performer contracts](contracts/performer-fidelity.json) | Behavioural contracts and complete mapping of the full feature inventory |
| [Machine-readable suggestion contract](contracts/next-track-suggestions.json) | Required original inputs, unresolved policies, history evidence and reference comparisons |
| [Source manifest](sources/manifest.json) | Provenance, sizes, and SHA-256 hashes of downloaded NI manuals |
| [Tutorial manifest](sources/tutorial-manifest.json) | Video identity, caption provenance, review coverage, frame timestamps and hashes |
| [Period-review manifest](sources/period-review-manifest.json) | Firsthand period sources, platform scope and evidence-frame provenance |
| [Later 1.x manifest](sources/later-1x-manifest.json) | Later video coverage, rejected candidates and frame provenance |
| [Forum/help manifest](sources/forum-help-manifest.json) | Original help screenshots, forum coverage and archive retrieval limits |
| [Non-English manifest](sources/non-english-manifest.json) | Language and review scope, visible version label, caption hashes and evidence frames |
| [Frame-review manifest](sources/frame-review-manifest.json) | Single-frame inspection ranges, event brackets, exclusions and image hashes |
| [Controlled-Play search manifest](sources/controlled-play-search-manifest.json) | New walkthrough coverage, caption/frame provenance, duplicate exclusion and unresolved test criteria |
| [Hollin frame-review manifest](sources/hollin-frame-review-manifest.json) | Retained native captures, contact sheets, event brackets and excluded initial capture pass |
| [Performer fidelity provenance](sources/performer-fidelity-manifest.json) | NI timbre announcement, direct performer observations and contract scope |
| [Performer fidelity validation](sources/performer-fidelity-validation.json) | Contract, inventory, source and local-link consistency checks |

## Evidence labels

- **D — documented:** stated or visibly shown in NI documentation or an identified firsthand period walkthrough. Historical evidence does not by itself prove identical behaviour in the installed build.
- **L — local evidence:** supported by existing device metadata or copied exports. No new live test was performed.
- **R — performer report or requirement:** supplied by the user, including observed behaviour from long-term use. Preserve it as reference evidence and required fidelity. Do not invent unreported internal mechanics.
- **P — proposed:** an original implementation or acceptance requirement for the rebuild. This is not a claim about NI's internal code.
- **V — verify:** a candidate feature or exact interaction still needs direct observation or stronger primary evidence.

Source keys such as `S1 §5.2.3` resolve in [Sources and evidence](06-sources-and-evidence.md). The inventories distinguish capability evidence from gesture evidence. A hardware mapping does not establish an identical touch gesture.

## The important findings

1. Next-track suggestions are the lead performer requirement. NI names tempo, key and timbre. The performer reports genre/history contributions and directly observed ranking adaptation. Preserve the original ordered results and adaptation. [S1, S15, S41, R2]
2. Background analysis, direct grid-phase correction, downbeat selection and BPM half/double/tap operations provide the original musical coordinates. Their response and downstream effects require fidelity. [S11, S15, S1]
3. The original has a central tempo workflow. NI's Browsing tutorial explicitly shows tapping master BPM and rotating a tempo wheel. [S15 2:08–2:19]
4. Tempo matching, phase alignment, quantised execution, downbeat selection, and keylock are different functions.
5. NI documents a **half-sync** state: tempos match but beat phase does not. The app shows red Sync, and a controller's Sync button flashes. A Sync press restores alignment. [S1 §5.2.3]
6. **Freeze** and **Loop Slicer** are different. Freeze can let the playhead leave the frozen region. Loop Slicer operates inside a loop. Zoom determines slice scale. [S1 §§5.2.6–5.2.7]
7. **Flux** preserves a continuing musical position while the audible playhead is temporarily manipulated. [S1 §5.2.4, S5]
8. The 2013 manuals describe three effect slots with eight choices per slot. Later 1.x material adds effects and SuperSlicer. Do not read “three banks of eight” as 24 distinct effects. [S1 §5.3, S10, historical leads H1–H3]
9. The user's **early Play press and next-bar launch** now has explicit period support. Exact queue rules remain open. [R1, S20]
10. The historical iPad quantise menu/default is now captured. See the period review for settings and scope. [S21]

The follow-up video review adds direct support for the load slider, browser search/sort, artwork-to-recommendations flow, eight cues, playlist creation, stripe navigation/zoom, touch loop manipulation, EQ reset, filter lock and delay tails. It distinguishes complete caption review from selected visual inspection. The gig iPad was not accessed.

The forum/help pass recovers original NI help screenshots and a period report about Freeze quantisation. Neither settles Quantize Size's relationship to ordinary Play or pending-start cancellation. Archive retrieval was limited by HTTP 429 and reader failures. No archived NI timing post was recovered.

The non-English pass adds an exact early version label, **1.0.3.182**, to the four-value quantise menu. French footage shows its selection changing from half a beat to one beat. The mapping to ordinary Play and pending-start cancellation remain unresolved.

The adjacent-frame follow-up recovers the intermediate French selections and a Spanish incoming-deck lead-in. Play appears green while a pale marker advances toward the source start, before waveform scrolling. This adds a concrete UI requirement. It does not settle the quantise mapping or second-press policy.

The controlled-test search adds Hollin Jones's public original-iPad beat-matching lesson. It explicitly labels an automatic count-in. No reviewed candidate demonstrates both a Quantize Size comparison and a second Play press during the lead-in. The course's locked preferences/playback lessons remain unreviewed leads.

The Hollin frame follow-up inspects 120 adjacent captures. It finds one uninterrupted orange Play-indicator event and about 1.93 video-UI seconds between first clear green Play and source-waveform scrolling. No distinct second activation is identifiable. The indicator appears after the button changes, so it cannot supply a calibrated input timestamp. Cancellation and quantise mapping remain unresolved.

## What this enables

This is a substantial research baseline for an independent implementation. It supplies a scope, behavioural model, journey catalogue, and a reference test programme. It does **not** establish that every interaction has been observed, that the exact NI audio algorithms are known, or that a faithful clone is already specified down to every sample and pixel.

The main remaining evidence is ordinary reference use: screen and audio captures, installed-build settings, exact gestures, and edge cases. The first sessions should settle queued Play's precise rules, the master clock, installed quantise differences, touch arbitration, effect latching, and persistence. See the capture protocol for the sequence. No decompilation is required to observe those behaviours.
