# Requests and work ledger

Updated 2 November 2026. Owner for triage and integration: this coordination chat.

**Included** means code is on `feature/project-integration`. **Partial** means some requested behaviour remains unfinished. **Open** means acceptance or implementation has not been established. None of these labels claims gig acceptance.

| ID | Priority | Request | Implementation | Remaining work / completion evidence |
| --- | --- | --- | --- | --- |
| R01 | First | Continuous, clean audio during real performance | Included: scratch/slow-drag fixes, route handling and streamed speed preparation. | Exact-source combined stress, route/interruption checks, real-music listening and A10X rehearsal. Any unintended stop, click, crackle or dropout fails acceptance. |
| R02 | First | Keep the TDJ1 touch-first workflow | Included: two decks, waveform gestures, cue/grid editing, loops, slicers, Flux, XY filters, EQ and FX. | Paired physical gesture and sound comparisons. Check cancellation, overlapping touches and both decks. No extra clutter as a substitute for the original workflow. |
| R03 | First | Persistent Sync and audible waveform manipulation | Included: Sync and transport corrections reported by the sync/audio chats. | Verify sustained two-deck Sync, manual takeover, slow/reverse manipulation and recovery interactions on the combined candidate. |
| R04 | First | Reliable loading and a usable browser | Included: load-slider ownership/travel, Songs default, responsive panes, full-library search and labels. | Combined load/cancellation and search tests, physical slider feel, portrait/landscape layout, real library at scale. |
| R05 | First | Music library and playlists available on opening | Included: native catalogue, matching, source order, preparation and analysis paths. | Current Mac/iPad end-to-end checks: first open, permissions, large playlists, refresh, missing/protected tracks and selection priority. |
| R06 | First | Record a set and retrieve its tracklist | Included: AIFF, audible-timeline tracklist, location/date naming, browsing and sharing. | Long recording, stop/finalisation, interruptions, correct timestamps and physical iPad-to-Mac transfer. Preserve every captured frame. |
| R07 | First | Adaptive beatgrids without compromising audio | Included: analysis candidates, bounded maps, safe activation, corrections, Undo and locks. | Task 6 remains open. Test fixed/adaptive Sync, loops, slices, Flux, FX and background work together. Real drifting tracks and A10X acceptance. |
| R08 | Next | Best practical A10X reverb, inspired by the desired Valhalla qualities | Included: reverb branch and its DSP checks/evidence. | Compare actual app output level and texture on real music. Matched audition gain is not production gain. Combined six-slot cost, headroom and listening acceptance. |
| R09 | Next | Musical waveform colours, waypoints and event countdowns | Partial: manual structure/landmarks/regions, display, countdowns and end warnings included. | Automatic verse/chorus/vocal/build/drop recognition, mixing suitability and validated rhythmic-ending detection. Current energy boundaries do not establish semantic recognition. |
| R10 | Next | Optional vinyl stop | Included: default-off Brake, duration/drag control, pitch slowdown and separate Play cancellation. | Combined recovery/Sync/loop interactions, listening and physical feel. |
| R11 | Next | Sensible unattended end-of-track recovery | Partial: default replay, 8/16-bar auto-mix, fallback, manual takeover and settings included. | Latest combined/streamed checks. Drop certainty, inaudible incoming decks and lack of a recommendation must behave safely. A manual marker is needed when automatic drop evidence is uncertain. |
| R12 | Next | Trust Mixed In Key and preserve personal preparation | Partial: authority/provenance, protected corrections, conflict retention and preview/apply included. | Direct native Mixed In Key ingestion, review UI, verified track matching and governed Traktor write-back. Current interchange requires declared attribution. |
| R13 | Next | Personal branding and polished performance UI | Included: branding and recent browser/header changes. | Inspect the actual packaged app at intended iPad sizes. Check readability, touch targets, dark-room use, warnings, accessibility and Erik's approval. Older logo iterations are historical. |
| R14 | Next | Original Z1/controller support | Partial: Z1 report mapping and Mac HID connection code exist. | Real connection, mapping, calibration, audio routing and supported iPad connection remain unaccepted. Code existence does not establish iPad accessory compatibility. |
| R15 | Later | Beat Jump, musical loop movement, key shift and key matching | Mixed: beat navigation and timing consumers already exist. | Reconcile the requested controls against current UI before defining missing work. Manual key-shift/key-match completion is not established by this audit. |
| R16 | Later | Suggestions, filtering, queueing and preparation continuity | Mixed: suggestion ranking, pairing history, queue and preparation protection exist. | Reconcile remaining requests, real-library recommendation quality and Mac/iPad continuity. Do not duplicate working features. |
| R17 | Later | Stems, MIDI Learn, phrase guidance, advanced FX and streaming integrations | Roadmap requests. | Scope each separately after the performance foundation is stable. No completion claim. |
| R18 | First | One manageable branch and tracked work | Included and pushed: source checkpoint and merges on `feature/project-integration`, draft PR #3. Clean status and source-bound results verified. | Preserve the old branches until their disposition is verified. Historical private work remains separately tracked by R19. |
| R19 | First | No missed work or forgotten requests | Partial: chat inventory, handovers, 18 private candidates and historical differences recorded. | Compare meaningful private patches and unreadable/older history against current implementation. Classify each as included, superseded, research, open or intentionally deferred. Do not mark complete from a filename inventory. |
| R20 | First | A test build Erik can trust enough to rehearse with | Open. | Complete the release gates. Give the build a source identity and an honest known-issues list. Erik's listening and rehearsal determine acceptance. |
| R21 | First | Minute-scale personal iPad test loop | Included: one cached signed build, numbered saved app, deployment without recompilation and tracked feedback. Build 45 compiled/signed in 54.86 seconds. Old broad CI is manual-only. | Install/launch could not be confirmed because the device connection timed out. Reconnect/unlock the iPad and deploy saved build 45. Erik performs acceptance testing. |

## Evidence index

- R01/R03: **Fix waveform audio artefacts**, **Fix persistent sync behavior**, `Replica/Responsiveness.md` and `Replica/Status.md`.
- R04: **Implement adaptive beatgrids** later load-fix turn, PR #1 and `LibrarySearchScopeTests.swift`.
- R05/R06: **Support Apple Music Playlists**, **Fix iPad Load Gesture**, **Tracklist File Format**, `Replica/MusicLibrary.md` and `Replica/Recording.md`.
- R07: **Implement adaptive beatgrids**, dated beatgrid plan and retained adaptive validation report.
- R08: **Valhalla Reverb Appeal**, **Reverb Quality Upgrade**, PR #2 and `Replica/Reverb.md`.
- R09: **Add waveform event countdown**, `Replica/MusicalWaveforms.md` and the waveform handover.
- R10: **Fix colour-coded waveforms** later Brake turn and the Brake handover.
- R11: **Add recovery mix-in options** and its dated implementation plan.
- R12: **Sync Mixed In Key with Traktor** and `Replica/KeyGovernance.md`. Final handover reports 13 focused governance tests passed. Combined results remain separate.
- R02/R14/R15/R16/R17: `Analysis/Traktor-DJ-1x/`, `Replica/Status.md`, source inspection and the adaptive plan's follow-on list.

Chat IDs are retained in `chat-inventory.json`. Some older imported histories cannot be read through the chat tool. This ledger records that coverage gap rather than claiming an exhaustive historical review.
