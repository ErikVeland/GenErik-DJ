# TDJ1 next-track suggestion fidelity

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

## Performer clarification — 25 October 2026

The performer now specifies the suggestion priority explicitly: **key, BPM range, energy, then whether the track has been paired with the reference before**. The confirmed BPM range is **±8%**. Energy should be **similar**, not progressively higher. These are ordered priorities, not additive weights. A lower-priority criterion must not outweigh a higher-priority match.

This instruction supersedes the earlier absence of a chosen ranking policy and the earlier assumption that genre needs an independent ranking weight. Retain genre metadata, but do not insert it ahead of or between the requested priorities. The implemented policy uses the current shared tempo for a playing synced reference and corrected source BPM otherwise. Previous pairing is treated as undirected.

Exact key outranks relative major/minor and adjacent fifths in the current implementation. Energy is an independent local estimate from loudness, brightness and onset activity, grouped into ten levels. These detail choices still need listening/reference validation. The user's priority order, ±8% range and similar-energy direction are confirmed requirements, not unknowns awaiting calibration.


**Preserve the next-track suggestions that the performer has relied on for 13 years, including the observed adaptation of rankings after previous mixes.** The target is the original TDJ1 behaviour, candidate order and workflow. A fresh recommender with broadly suitable results is insufficient. [R2, R3]

## What the reference establishes

| Component | Reference | Replication obligation |
| --- | --- | --- |
| Contextual access through deck artwork | NI Browsing tutorial and app manual, S15/S1 | Preserve the entry gesture, reference context and destination deck |
| Tempo and key compatibility with visible feedback | S15/S1 | Match the original candidates, indicators and ordering |
| Timbre analysis as an input to recommendations | NI launch announcement reproduced by Rekkerd, S41 | Retain this declared part of the original engine; its numerical representation and ranking contribution remain to recover |
| Genre's role in the suggested next tracks | Performer account, R2 | Preserve the reported behaviour; exact source and influence of genre remain to recover |
| Previous mixes and track combinations affecting suggestions | Performer account, R2 | Preserve the personal performance history contribution |
| Rankings adapting with use | Performer explicitly confirms observing TDJ1 rankings adapt, R2 | Adaptive behaviour is required fidelity, not an optional enhancement |
| Exact machine-learning method, features and model state | No internal implementation recovered | Recover equivalent behaviour against reference observations. Do not invent an NI algorithm or call a static compatibility sort a faithful reproduction |

The [NI announcement](https://rekkerd.org/native-instruments-releases-traktor-dj-app-for-ipad/) identifies tempo, key and timbre for the original iPad engine. Timbre means qualities of the sound. It is distinct from a genre label. The announcement supports that capability claim, not an exact implementation or an accuracy guarantee. [S41]

The performer's report of adaptive behaviour stands independently of the public wording. It is not discarded because the announcement omits a description of personalisation. [R2]

## Original behaviour to match

The performer's journey is:

1. Establish the current musical context in TDJ1.
2. Open the original suggestion view through its existing gesture.
3. Receive the original ranked choices from the available music collection.
4. Recognise compatible choices through the original feedback.
5. Choose and load the next track through the original workflow.
6. Continue mixing, with previous usage contributing to subsequent suggestions as reported.

The context selection when both decks play, the precise point at which a mix contributes to learning, and the persistence of that learning require reference examples. None of those details is assigned a new rule here.

## Input distinctions that must survive reconstruction

| Input | Meaning | Detail to recover from the original |
| --- | --- | --- |
| Library and track identity | The actual available recordings, edits and versions | Identity rules, duplicates and unavailable music handling |
| Source BPM | Tempo analysis attached to a recording | Rounding, corrections and half/double interpretation |
| Performance tempo | The tempo in the current mixing context | Whether and how it affects candidate eligibility and ranking |
| Key | The original detected or corrected harmonic information | Notation, compatibility relationships and effect of playback/keylock state |
| Timbre | Sound-related analysis named by NI | Descriptors, comparison method and role in ordering |
| Genre | Stylistic information reported by the performer | Tag source or inference, missing labels, multiple genres and cross-genre behaviour |
| Previous mixes | Earlier performance context and track combinations | Session boundaries, order, repetition, duration and whether overlap matters |
| Learned state | The retained state behind observed adaptive rankings | Update timing, persistence, reset conditions and relationship to history |
| Current deck context | Which track supplies the reference and which deck receives the choice | One-deck, two-deck, stopped-deck and browsing behaviour |

These are distinctions for investigating and implementing the original engine. They are not new settings or promises that every input acts independently. Preserve the original coupling where it exists.

## Personal history and adaptive rankings

The target must retain the reported difference between an engine that only knows track properties and one whose suggestions have adapted to the performer's mixing history. This is a required behavioural distinction. [R2]

Do not choose a new learning rule in advance. Loading a track, listening in headphones, actually performing a transition and completing a recorded mix are different events. Which events TDJ1 uses, and how it weights them, remain to recover. Likewise, a combination appearing in a past mix does not establish how the original evaluates that combination.

Do not assume rankings are driven only by total play counts, that every unselected candidate is disliked, that all transitions are symmetric, or that a new mix immediately changes the next list. Those would be replacement policies until matched to the reference.

No new model-training controls, score explanations, preference sliders, recommendation providers or cloud dependencies are specified. The original UI and behaviour remain the target.

## Existing history evidence

Existing copied recording exports include WAV files and companion tracklists containing names, artists, opaque identifiers and start-time values. That establishes a retained record of performed material. It does **not** establish that TDJ1 feeds those XML files to its recommendation engine. Timestamp units, identity semantics and the engine's actual history store remain unresolved. [L2]

Keep original copied exports unchanged. If they later help reconstruct a past session, retain their provenance and distinguish reconstructed context from actual captured recommendation output. Do not infer trained model state from a tracklist alone.

## Reference comparisons

These are evidence requests for a later authorised reference session, not permission to operate the gig iPad now. Prefer existing material and the performer's recall of concrete examples first.

| Case | Comparison | Evidence to retain |
| --- | --- | --- |
| REC01 | A familiar reference track and its expected next-track suggestions | Ranked track identities, library snapshot, visible context, settings and build |
| REC02 | A pair or sequence whose recommendation position changed after repeated mixing | The performer's account and any before/after output with history provenance |
| REC03 | Similar BPM with different keys, then related keys at different BPM | Original candidates and indicators; do not invent compatibility thresholds |
| REC04 | Same reference under different current performance tempos | Original ordering and eligibility changes, if any |
| REC05 | Similar tempo/key with different genre and sonic character | Separate observations for genre and timbre; no assumption that one represents the other |
| REC06 | One deck playing, both playing, then a stopped reference deck | Which context the original uses and how the view reacts |
| REC07 | Load or preview a track without actually mixing it | Whether the original changes history or later suggestions |
| REC08 | A completed mix, ordinary restart and later return to the same reference | Update timing and persistence of observed adaptation |
| REC09 | A corrected BPM, key or grid before reopening suggestions | Which corrected properties affect the original results |
| REC10 | A repeated track or a different edit of the same recording | Identity, recent-use and duplicate behaviour as the original exhibits it |

The [machine-readable suggestion contract](contracts/next-track-suggestions.json) preserves these comparisons and leaves unknown policies unassigned.

## Completion rule

A compatibility filter alone does not complete the suggestion engine. Neither does a new learning model that produces appealing choices. Completion requires the original access flow, candidate handling, ranking, feedback, history-dependent adaptation and persistence to match the agreed reference cases.

The original algorithm remains unrecovered. There is no claim of an implemented or validated replica yet. The gig iPad remains untouched.
