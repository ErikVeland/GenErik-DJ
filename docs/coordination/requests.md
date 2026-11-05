# Requests

Every request ID is retained. “Implemented” describes source availability, not Erik's hardware acceptance. See [current build](README.md), [known issues](known-issues.md) and [the full historical ledger](https://github.com/ErikVeland/GenErik-DJ/blob/archive/pre-cleanup-2026-11-04/docs/coordination/requests.md) for original feedback, measurements and provenance.

| ID | Priority | Request | Current state and remaining work |
| --- | --- | --- | --- |
| R01 | First | Continuous, clean audio during real performance | Primary acceptance requirement, reinforced by R49. Any gap or dropout blocks acceptance. Current-source A10X listening and sustained stress remain open. |
| R02 | First | Keep the TDJ1 touch-first workflow | Touch workflow implemented. Physical gesture equivalence remains open. |
| R03 | First | Persistent Sync and audible waveform manipulation | Sync and waveform transport corrections included. Verify interaction edges on hardware. |
| R04 | First | Reliable loading and a usable browser | Loading and browser repairs included. Verify large-library loading and touch. |
| R05 | First | Music library and playlists available on opening | Native local library and playlists implemented. Verify catalog timing and preparation. |
| R06 | First | Record a set and retrieve its tracklist | AIFF and tracklists implemented. Verify recording, sharing and actual captured audio. |
| R07 | First | Adaptive beatgrids without compromising audio | Adaptive grids implemented. Combined Sync/loop/Flux/FX device acceptance remains open. |
| R08 | Next | Best practical A10X reverb, inspired by the desired Valhalla qualities | Native reverb included. A10X six-slot cost and listening acceptance remain open. |
| R09 | Next | Musical waveform colours, waypoints and event countdowns | Section colours, landmarks and guidance implemented. Musical labels remain estimates. |
| R10 | Next | Optional vinyl stop | Optional vinyl stop implemented. Verify curve, feel and clean audio. |
| R11 | Next | Sensible unattended end-of-track recovery | Replay/auto-mix recovery implemented. Verify boundaries, fallback and manual takeover. |
| R12 | Next | Trust Mixed In Key and preserve personal preparation | Key authority, JSON review and ID3 import included. Native exports and write-back remain open. |
| R13 | Next | Personal branding and polished performance UI | Branding and performance UI included. Readability and physical acceptance remain open. |
| R14 | Next | Original Z1/controller support | Original-Z1 mapping and bridge tools exist. Physical connection/routing remains open. |
| R15 | Later | Beat Jump, musical loop movement, key shift and key matching | Beat navigation, key shift and matching implemented. Listening acceptance remains open. |
| R16 | Later | Suggestions, filtering, queueing and preparation continuity | Suggestions, queue and preparation protection included. Real-library quality remains open. |
| R17 | Later | Stems, MIDI Learn, phrase guidance, advanced FX and streaming integrations | MIDI Learn and six FX slots exist. Stem model bundled. Stem inference/playback remains open. Streaming deferred. |
| R18 | First | One manageable branch and tracked work | One consolidated main branch. Serial feature branches required. |
| R19 | First | No missed work or forgotten requests | Private candidates preserved externally. Semantic review of meaningful patches remains open. |
| R20 | First | A test build Erik can trust enough to rehearse with | Numbered signed iPad builds available. Rehearsal and gig acceptance remain open. |
| R21 | First | Minute-scale personal iPad test loop | Cached build/install/feedback loop implemented. Erik is the acceptance tester. |
| R22 | Next | Finish the SuperSlicer scratching DLC | Scratch, holds, Brake and Flux cases implemented. Physical feel remains open. |
| R23 | First | All NI controllers and class-compliant MIDI hardware, including Serato/Pioneer/other ecosystems; Z1 Mk1 first | MIDI input/feedback profiles and bridge code exist. Verify each actual controller. Z1 first. |
| R24 | Next | Put Extra Controls in a section under Features | Extra Controls settings section included. Physical review remains open. |
| R25 | First | Make the A/B loader work in the recommended tracks panel on GenErik Duo | Recommended-track A/B loader corrections included. Duo touch acceptance remains open. |
| R26 | First | Show only songs with audio files available on this device | On-device audio filtering included. Verify actual Music-library availability. |
| R27 | Next | Fill the Duo inner screen | Duo inside sizing corrected. Physical full-screen acceptance remains open. |
| R28 | First | Make the closed/front phone layout usable, with one deck at a time | Front-phone one-deck view and A/B slides implemented. Physical folding and gestures remain open. |
| R29 | First | Analyse every unanalysed track selected for a deck immediately | Missing analysis is scheduled on deck loading. Verify affected tracks and timing. |
| R30 | Next | Flexible deck/library layout, usable performance controls and clear section labels | Resizable workspace, anchored transport and compact Actions pane included. Physical acceptance remains open. |
| R31 | Next | Four-beat grid icon, aligned controls, app name and device-specific header spacing | Grid icon, alignment and header spacing updated. Physical review remains open. |
| R32 | First | Add-track icons must open the full browsing pane | Every add-track request expands browsing. Verify touch and orientation size memory. |
| R33 | First | Detect reliable tempo after a long intro, including rhythm near the ending | Late-rhythm windows included. Real-track tempo reliability remains open. |
| R34 | First | Stop false chorus labels in Danger Mouse’s 99 Problems, then install an iPad test build | False-chorus correction included. Replaced by later vocal/structure refinements. Listening remains open. |
| R35 | First | Genre-aware and version-aware structure analysis, refined through a large real-song review | Genre/version analysis included. Labelled accuracy and preparation cost remain open. |
| R36 | First | Clear section assignments without question marks throughout the performance UI | Question-mark suffixes removed. Automatic/manual provenance retained. |
| R37 | First | Detect verses, hooks and choruses, starting with Danger Mouse’s 99 Problems, and check genres/versions | Vocal/word recurrence included. Verse/hook/chorus listening acceptance remains open. |
| R38 | First | Resolve dense remixes, including extended and 12-inch versions, across genres | Dense-remix retry windows included. Unresolved tracks and A10X preparation cost remain open. |
| R39 | First | Full-width closed/front-phone song browsing and recommendations with accessible performance controls | Full-width Songs/Suggestions/Prep applies to the phone front screen only. Physical acceptance remains open. |
| R40 | First | Performance, Browse and Expand shortcuts for closed/front-phone browser space | Performance/Browse/Expand shortcuts apply to the phone front screen only. Physical acceptance remains open. |
| R41 | First | Fix the immediate iPad launch crash reported after build 89 | Missing whisper framework search path repaired. Signed builds pass framework resolution. |
| R42 | First | Limit the single-screen browser and shortcuts to the closed/front phone screen; restore iPad and Duo inside layouts | iPad/Duo inside layouts restored. Narrow portrait iPad must retain the iPad design. |
| R43 | First | Correct first-beat and automatic bar-start failures, starting with TLC Creep (Tin Tin Out Remix) | Automatic opening bar correction included. Creep result retained. Physical alignment remains open. |
| R44 | First | Make the waveform follow the finger 1:1, with natural throw momentum | Direct waveform drag, hold and momentum included. Physical feel and audio remain open. |
| R45 | First | Show waveforms and accept Play immediately when loading, including tracks that need analysis | Immediate metadata and progressive native waveform loading included. Physical timing remains open. |
| R46 | First | Consolidate all latest work into main and provide one current test source | Existing branch work consolidated into main. Historical evidence preserved. |
| R47 | First | Consolidate work and remove waste for the A10X iPad | Build 111 installed. Duplicate waveform geometry removed. Physical performance acceptance remains open. |
| R48 | First | Clean the whole repository and remove avoidable runtime work | Cleanup merged and build 112 installed. Source, focused tests, geometry, native transport, repository hygiene and signing checks pass. Physical A10X performance acceptance remains open. See [cleanup report](../maintenance.md). |
| R49 | First | Make uninterrupted audio and consistently responsive UI on A10X the main project goal | Governs every change. TDJ1 is Erik's performance reference. Audio gaps, dropouts, UI stalls, visible stutter and delayed controls block acceptance. Actual A10X measurements, listening, touch and sustained real-setup rehearsal remain required. |
| R50 | First | Profile the actual A10X with both decks, FX, recording and background analysis; fix measured faults and install the next build | Build 114 profiled with two decks, five active FX slots, recording and the existing read-only analysis comparison. Main-thread CPU was 25.8 seconds in the 30-second steady run and 36.8 seconds in the 45-second combined run. Clock reads are isolated from the large deck layout. Four focused Swift tests pass, including four dependency cases and six rendered cases. The UI fix shipped in build 115. Comparison on the latest installed build remains open. Audio deadline/underrun counts were not exposed by Instruments. Evidence: ignored `TestBuilds/r50/build-114/`. Earlier 112 setup evidence remains preserved. |
| R51 | First | Browser cannot reach full height on the iPad during build 112 setup | Height limit removed. Dragging can fill the workspace below the toolbar, with the right-hand controls retained. Normal opening size and orientation memory remain. Fast release at full height retains that height. Build 113 installed and launched. All 3,142 focused geometry checks pass. Erik’s touch acceptance remains pending. Resume R50 profiling after the browser check. |
| R52 | First | Remove the Actions label, place its icon flush in the waveform corner, show at least five beats by default and align the side controls with both decks | Build 114 installed and launched. The icon is flush with the waveform, and default zoom spans five beats. Side buttons fill the visible deck area and the crossfader follows the divider, including unequal deck sizes. All 2,661 focused geometry checks, six core waveform tests and six rendered deck cases pass. Physical acceptance and R50 profiling remain open. |
| R53 | First | Open with only the decks visible and the browser hidden | Build 116 installed and launched. Initial browser visibility is false. Explicit music, drag and add-track controls still open the browser. The focused browser workflow check passes. Erik’s launch check remains open. |
| R54 | First | Consolidate the latest updates into main and install them on the Duo | Main already included every local and fetched branch tip and matched GitHub. Signed build 117 from main at `1b8354598` installed on the Duo, and iOS accepted launch. Erik’s front and inside layout, browser and audio checks remain open. [Build record](../testing/builds/117.json). |
| R55 | First | Load songs when the browser opens and keep the Music library list between launches | Build 117 showed an empty list during loading. Both browser layouts now show the loading state until the current list is ready. iOS shows the saved list while Music refreshes it. Check the first load and the next launch on the Duo. |
