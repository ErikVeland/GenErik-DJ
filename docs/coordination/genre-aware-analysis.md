# R35: Genre-aware musical structure and version review

Erik set this direction on 3 November 2026. He chose an even spread across genres and version types for the first review.

The engine must recognise musical form across genres and recording versions. It must also give clear, useful performance labels.
Removing false chorus labels is an initial guard. Replacing every role with an unassigned vocal label does not meet the recognition goal.

## Structure contract

Use three levels of musical information:

1. Whole-song form, such as intro, verse, hook, chorus, bridge and outro.
2. Phrases within each section, with bar counts where the grid supports them.
3. Events within phrases, such as fills, vocal entries, bass returns and short breaks.

A fill or a brief change in texture must not automatically split a verse into several top-level sections.
Recognise both repeated material and changes in instrumentation. Similar backing music alone does not establish a repeated hook.

Genre and version are separate inputs. Genre tags and title words are hints, not ground truth.
Combine metadata hints with audible rhythm, harmony, vocals, instrumentation and repetition.
Allow several genre interpretations and changes within a mashup or remix.
Audio evidence must outweigh a genre template or a title such as “Extended Mix”.

## Proposed musical expectations

These are requirements for evaluation. They are not claims about the current detector.

| Musical family | Structure evidence to evaluate |
| --- | --- |
| Hip-hop and R&B | Rap verses and returning hooks over shared backing. Vocal rhythm and delivery changes. Instrumental breaks and bridges. |
| House and disco | Instrumental mixing intros/outros, recurring grooves, vocal refrains, breakdowns and returns. Live disco timing must remain possible. |
| Techno and trance | Groove development, layered arrivals, builds and breakdowns. Do not force a pop chorus onto instrumental repetition. |
| Drum and bass, jungle and breaks | Breakbeat phrasing, half/double-tempo ambiguity, breakdowns, drops and changed rhythmic feels. |
| Pop and rock | Verse, pre-chorus, chorus, bridge, solo, pickups and live timing. Allow songs without a conventional chorus. |
| Reggae, dancehall, Latin and Afro styles | Repeated rhythms with distinct vocal sections, percussion breaks, call-and-response and changes in rhythmic feel. |
| Ambient and downtempo | Textural sections and gradual development. Do not invent a beatgrid, drop or chorus without supporting evidence. |
| Mashups and hybrids | Several source structures and transitions within one file. A single global genre cannot control every section. |

The sampling families are deliberately broad. They do not define a final genre taxonomy or model routing system.

## Recording versions

Evaluate radio edits, album versions, extended mixes, 12-inch mixes, club mixes, dubs, instrumentals, a cappellas, live recordings and mashups.
A version can have several attributes. A 12-inch dub is both a format/version hint and a vocal/instrumental arrangement choice.

Detect long mixing passages from the audio. Do not label every opening as a short pop intro.
Match related recordings without copying timestamps from another version.
Remixes can change tempo, key, order, length and section function. Each file needs its own analysis and identity.

The first saved-device candidate set has no explicit 12-inch titles. Eight examples from the mounted local archive supplement that gap.
These include Chic, Donna Summer, Michael Jackson, Madonna and New Order.
Missing or unusual tags remain visible in the review data.

## Review process

Start with a source-bound baseline before changing the recognition rules.
The first set has 96 recordings spread across ten sampling families, plus eight explicit 12-inch examples.
Rotate available version types within each family. Retain failures and source-duration mismatches.

Keep exact file hashes, engine/configuration identity, detected tempo/key, section predictions and raw scores.
Review flags identify suspicious results. They are not confirmed errors or ground-truth labels.
Imported Traktor fields are comparison candidates until recording identity and the reference values are verified.
The initial review supplies no independent section annotations and cannot produce a section-accuracy percentage.

Review boundaries and roles separately. Record correct assignments, missed sections, wrong roles, extra boundaries and unresolved passages.
An unresolved true chorus counts as a recognition miss. A detector cannot improve its score merely by withholding every assignment.
Inspect performance by genre and version, not only as a library-wide average.

Use corrected examples for development. Keep related versions together when dividing development and held-out tracks.
The current title-based family grouping is conservative and needs review. Covers and differently named remixes can defeat metadata grouping.
Before final evaluation, confirm families with source identities, fingerprints or listening.

Evaluate future candidates on the same files and reviewed labels. Report exact role precision, recall and coverage, boundary errors,
beat/downbeat alignment, half/double-tempo errors and exact key results. Keep automatic outputs separate from personal corrections.

Research candidates include [All-In-One](https://arxiv.org/abs/2307.16425), which jointly models rhythm and functional structure.
The [Harmonix Set](https://github.com/urinieto/harmonixset) supplies a public example of beat, downbeat and structure annotations.
Its pop focus does not replace the extended mixes and genre coverage in Erik’s library.
No new model or dependency is installed by this baseline.

## Performance presentation

Show a direct section name on the waveform, cue and countdown.
Use the most specific role supported by the evidence. Keep a descriptive label when the musical role is unresolved.
Keep automatic/manual provenance and detailed review information in preparation views.
Do not display a fixed heuristic score as a probability of correctness.

R36 removes the repeated question marks. It does not raise the engine’s stored confidence or relabel unknown passages as choruses.
Actual confidence must improve through the reviewed corpus, stronger models and measured errors.

## Delivery

Keep the iPad performance loop focused. Each accepted engine change gets one numbered signed iPad candidate.
Keep corpus research and comparison reports separate from routine app regression testing.
Do not run analysis on the audio callback. Measure preparation cost and playback continuity on the target iPad.
Erik remains the acceptance tester.

## First production iteration: 4 November

Build 81 adds a metadata-guided audio profile for rhythmic intros and outros in dance styles and explicit DJ versions.
It requires sustained low-vocal rhythm and a supported tempo, then consolidates subdivisions within the edge passage.
Title and genre join the arrangement cache identity. Existing cue frames and manual preparation retain their authority.
The 104-entry comparison retains 99 successful analyses and five failures. The profile applies on 22 entries.
Ten recordings received a source/feature review. No independent full song-form accuracy is established.
See `../testing/checks/R35/2026-11-04-dj-mix-sections/README.md`.

## Vocal roles: R37

The next iteration adds an offline vocal-word pass. Repeated words distinguish a refrain from a recurring backing loop.
Rap or short sampled refrains can receive Hook. Sustained sung refrains can receive Chorus.
The chorus score uses the refrain itself, so extended instrumental edges cannot dilute that evidence.
Substantial changing lyrics and sustained voice evidence support Verse.

The exact Danger Mouse source now has three verses, three main hooks, a short opening hook and an outro.
The new pass replaces older acoustic vocal subdivisions where repeated words establish the new form.
It preserves existing cue frames and manual preparation. Recognition pauses during playback and resumes when both decks are idle.
The 190 MB model ships offline. It is pinned by checksum, and no lyrics are saved.

The review records misses across the sampled genres and versions. It has no independent listening annotations or section-accuracy percentage.
Dense remixes and language recognition remain limits. This is a first vocal-role improvement, not a completed genre classifier.
See `../testing/checks/R37/2026-11-04-vocal-form/` for source-bound predictions and the device handover.

## Dense remixes: R38

Version 6 retries recordings whose first pass has no vocal form. It starts with the strongest measured vocal windows,
retains full-source positions and combines word recognition with music-aware voice evidence. Guided phrases can support longer lyric lines
and quieter vocals. Existing first-pass assignments, cue frames and manual preparation retain their authority.

The same 28-source comparison changes coverage from nine to 15 recordings. Six new results include an extended mix,
a club mix and two 12-inch versions. The nine previous inventories are unchanged, and both explicit instrumental controls retain no vocal roles.
The study remains development evidence without independent listening annotations. Some dense recordings remain unassigned.
See `../testing/checks/R38/2026-11-04-dense-remixes/`.
