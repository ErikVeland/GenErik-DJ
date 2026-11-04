# GenErik DJ project control

Updated 4 November 2026, Australia/Brisbane. This is the current project entry point.

**Layout scope:** The single-screen browser redesign and Performance/Browse/Expand shortcuts are for the closed/front phone screen only. Preserve the existing iPad and Duo inside layouts. R42 supersedes the earlier broad portrait interpretation.

**Current working mode:** [Erik's minute-scale iPad loop](../testing/README.md). iPad only, Erik as sole developer/tester. The broader release gates below are separate from routine iterations.

**Proposed next programme:** [TDJ1 gesture fidelity and unified touch space](../superpowers/plans/2026-11-03-touch-fidelity.md), led by R02/R30. It prioritises stable essential controls, direct panel manipulation and source-bound gesture acceptance. This is a plan, not a completed feature or permission to replace the current test build.

## Goal

Current completion scope: [remaining app work](completion-programme.md) and [all NI and class-compliant MIDI controllers](controller-coverage.md), with an allowed hardware bridge where necessary. Original Z1 is first for Erik's hardware testing.

Build Erik's personal successor to the DJ software he has used for 13 years. Preserve the TDJ1 touch workflow and make the sound, preparation and performance controls dependable enough for his real gigs. Visual polish and personalised features must support that workflow.

The release standard is Erik's acceptance on his real setup. A successful build or synthetic test is supporting evidence, not that acceptance.

## Current position

- Latest test-iPad candidate: build 98, application source `73997dbc26632be6e82032fe88f4f99372672d96`, installed on the 10.5-inch test iPad on 4 November. iPadOS accepted the launch request. R43 detects TLC Creep (Tin Tin Out Remix) at 136.017769 BPM with its anchor at 0.180574 seconds. The grid-options menu can detect from prepared audio and replace a protected import on request. Nineteen focused cases and full-source/cache agreement pass. Current iPad controls, launch repairs and phone-only changes remain included. Bar recognition, physical menu operation, listening and audio acceptance remain open. See `../testing/checks/R43/2026-11-04-creep-grid/`.
- Previous test-iPad candidate: build 96, application source `40b1f51fe47fdea8cf0090cfe9a07ae50805c7b4`, installed on the 10.5-inch iPad on 4 November. iPadOS accepted the launch request. R02/R30 correct build 94’s hidden action access and small FX/EQ defaults. Controls has full/compact entry buttons. FX/EQ use larger adaptive defaults, retain manual sizes and can request usable deck height. The main Features page exposes large handles. The fixed dock/full-height fader, held musical mapping, R34/current R38 analysis, R41 launch repair and R42 browser layouts remain included. All 4,590 focused assertions and artifact checks passed. Erik checks control access, sizes, held gestures and clean audio. Acceptance remains pending. See `../testing/checks/R30/2026-11-04-panel-access/result.json`.
- Previous test-iPad candidate: build 95, application source `1e6ddabecf089c8aec05c1f6b52f1884da25a377`, installed on the 10.5-inch test iPad on 4 November. iPadOS accepted the launch request. R38 adds ranked vocal-window retries and combined word/voice evidence for dense remixes. The 28-source review changes vocal-form coverage from nine to 15 recordings, with the nine previous inventories unchanged. All 48 focused checks, source timelines, boundaries, signing and framework-resolution checks pass. Current controls, section editor and launch repairs are preserved. Listening, preparation cost and physical audio acceptance remain pending. See `../testing/checks/R38/2026-11-04-dense-remixes/`.
- Previous test-iPad candidate: build 94, application source `65378bbffb3c3cbf36e759b11d4a824216a054de`, installed on the 10.5-inch iPad on 4 November. iPadOS accepted the launch request. R02/R09/R30 bring the section editor into its deck with direct resizing, hiding and session height memory. Draft identity survives hiding; stale track/load sessions cannot save. Quiet 12-point grips are default, expanded handles remain in the loaded-deck gear menu, and empty decks keep their action trays closed. The fixed dock/full-height fader, native musical mapping, R34 and restored iPad/Duo browser remain intact. All 4,569 focused assertions, compilation, framework resolution and signing passed. Erik checks touch, form/keyboard, clean audio and continued operation. Acceptance remains pending. See `../testing/checks/R30/2026-11-04-section-space/result.json`.
- Previous test-iPad candidate: build 93, application source `d66b403f331e2eaa3383465050698393934c7d6a`, installed on the 10.5-inch iPad on 4 November. R42 restores the existing iPad/wide-phone column browser from pre-redesign source `811d75fd3`. The new browser and workspace shortcuts are closed/front-phone-only. The runtime launch repair remains included. All 130 browser/presentation and 1,330 dock checks, runtime framework resolution, compilation and signing pass. iPadOS accepted the launch request. Erik checks the restored layout and clean audio. No Duo deployment. See `../testing/checks/R42/2026-11-04-front-screen-only/result.json`.
- Previous test-iPad candidate: build 92, application source `7e27819e6b76c528b5c1b502343e40942a605779`, installed on the 10.5-inch iPad on 4 November. iPadOS accepted the launch request. R02/R04/R25/R30 add direct Sources/Details drawer sizing, remembered session widths per orientation and retained loader coordinates. Full-width Songs/Suggestions/Prep, layout shortcuts, the fixed dock, full-height fader, A/B divider and R34/R35/R37/R41 remain included. All 4,429 focused assertions, compilation, framework resolution and signing passed. Build 90 remains uninstalled. Erik checks touch, clean audio and continued operation. Acceptance remains pending. See `../testing/checks/R30/2026-11-04-browser-columns/result.json`.
- Previous test-iPad candidate: build 91, application source `c16ccd775d9ef9ca0b2dd06ad6d685b270698ea0`, installed on the 10.5-inch iPad on 4 November. R41 adds the missing app Frameworks search path. The actual saved app passes framework resolution and signing. The build/deploy helper now rejects unresolved bundled frameworks. iPadOS accepted the launch request. Erik must confirm that it stays open, then check the browser, shortcuts and clean audio. No further device actions after launch. See `../testing/checks/R41/2026-11-04-launch-crash/result.json`.
- Previous test-iPad candidate: build 89, application source `61ff7478b4817fc73662ffe40ac7dc67f9b0c22f`. R40 added browser-size shortcuts. The device crash report confirms a DYLD failure before the interface appeared. The launch request was accepted, but the executable could not resolve its embedded whisper framework. R41 corrects this in build 91. Browser, shortcut and audio acceptance remain pending.
- Previous test-iPad candidate: build 88, application source `c7316fb9e1bae49c25a5ca6a316172807e043d13`. R39 added full-width song browsing. Its device crash report confirms the same unresolved whisper framework as build 89. The earlier launch-command result did not establish a running app. Retest the browser in build 91.
- Previous test-iPad candidate: build 87, application source `9b41326410293ba7ffc5db6b12fc0ddb3dedf876`, installed and launched on the 10.5-inch iPad on 4 November. R02/R30 add a direct A/B divider with a dedicated 44-point grab lane and remembered session proportions per orientation. Both compact decks remain reachable. Held-contact mapping, dock anchors, the full-height crossfader and R34/R35/R37 analysis remain intact. All 3,665 focused assertions and signing passed. Erik checks divider feel, size memory, held gestures and clean audio. Device acceptance remains pending. See `../testing/checks/R30/2026-11-04-deck-divider/result.json`.
- Previous test-iPad candidate: build 86, application source `301e1799bd77e56cb6b0eeb005bd258ae6973f33`, installed and launched on the 10.5-inch iPad on 4 November. R37 adds offline verse, hook and chorus detection. The exact Danger Mouse source has three verses and three main hooks, plus an opening hook and outro. Thirty-eight focused checks pass. The 28-recording genre/version review has valid boundaries and nine changed role inventories. Some dense remixes remain unresolved. The current panel fixes are included. Erik checks role accuracy, preparation time, cue preservation and clean audio. See `../testing/checks/R37/2026-11-04-vocal-form/`.
- Previous test-iPad candidate: build 85, application source `ec3eaaa82d6f4cc9f91615d77e4c526febc57c41`, installed and launched on the 10.5-inch iPad on 4 November. R02/R30/R31 give FX, EQ and MORE the library’s direct show/hide/resize gestures and remembered session widths per deck/orientation. Independent panel commands and retained contact mapping preserve held gestures. The dock, full-height crossfader and R34/R35 remain intact. All 2,977 focused assertions and signing passed. Builds 83 and 84 remain uninstalled after review corrections. Erik checks panel feel, held gestures and clean audio. Device acceptance remains pending. See `../testing/checks/R30/2026-11-04-performance-panels/result.json`.
- Previous test-iPad candidate: build 82, application source `e0a26d64018f799f923cb6dc9c26a290952b8d90`, installed and launched on the 10.5-inch iPad on 4 November. R01/R02/R30 retain held waveform/EQ/filter/FX coordinates through panel resizing and stretch the crossfader across the full A Play-to-B FX gap. Fixed button anchors, library gestures and R34/R35 analysis remain intact. All 1,545 focused assertions and signing passed. Erik checks gesture continuity, fader travel and clean audio. Device acceptance remains pending. See `../testing/checks/R02/2026-11-04-held-touch/result.json`.
- Previous test-iPad candidate: build 80, application source `62efd9076de38ab9b3a706f68162befaf8db14b1`, installed and launched on the 10.5-inch iPad on 4 November. R02/R30/R32 unify direct library reveal/hide/resize, remembered session sizes per orientation and full expansion on every add-track request. The dock and R34 remain unchanged. All 1,501 focused assertions and signing passed. Erik checks gestures, search/loading and clean audio. Device acceptance remains pending. See `../testing/checks/R30/2026-11-04-library-panel/result.json`.
- Previous test-iPad candidate: build 78, application source `e6cf72aa26b36e75a91b30f44ca2e0a479b5ff14`, installed on the 10.5-inch iPad on 3 November. R02/R30/R31 add fixed right-hand FX/EQ/loop/Play stacks and a centred crossfader outside the resizable work area. The committed R34 false-chorus fix is unchanged. All 1,322 focused geometry assertions and signing passed. Automatic launch timed out. Erik opens the app manually and checks both stacks, fader, panel resizing and clean audio. Device acceptance remains pending. See `../testing/checks/R30/2026-11-03-stable-dock/result.json`.
- Active development branch: `feature/project-integration`.
- Latest installed Duo candidate: build 97, application source `fd13c60a74e1f1e194e53070ed3c989081913830`, installed on 4 November for R28 closed/front testing. iPadOS accepted the launch request. One full-width selected deck, persistent A/B status/switching, direct Songs/Suggestions, fixed selected-deck controls and a horizontal crossfader replace the front two-deck layout. The existing wide workspace/browser/dock sources remain unchanged. All 1,648 focused assertions, compilation, framework resolution and signing pass. The 90-second Wi-Fi attempt timed out; a 240-second retry succeeded. No iPad operation. Erik checks physical front usability, folding/inside layout and clean audio. See `../testing/checks/R28/2026-11-04-one-deck/result.json`.
- Prepared combined candidate: build 75, source `31f38a45cac9d1b9f4077401a379a3f976bf46c9`. It adds R33 late-rhythm recovery and includes the current R30/R31/R32 UI and controller work. Compilation/signing and seven focused rhythm checks passed. Installation is pending Duo reconnection after CoreDeviceError 4016.
- Remote backup: `origin/feature/project-integration`. Review: [draft PR #3](https://github.com/ErikVeland/GenErik-DJ/pull/3), against `main`.
- Prepared controller candidate: build 51, application source `a437cec2bc37506fa24c63e666e97ec53d570ed8`. Installed vinyl-stop candidate: build 55, installed and launched on 3 November. Erik's acceptance is pending.
- Shared uncommitted work was backed up and committed as `7a974c385`.
- Current remote main, full-library search, adaptive beatgrids and A10X reverb are included by merge history.
- Browser merge resolution preserves full-library search and the iPad layout constraints.
- Earlier chats were stopped. Later user-requested Scratch and gig-blocker work is recorded separately. This chat has not spawned agents. Shared builds and device handovers must remain coordinated.
- Historical combined source `335cec6b7` passed 688 Release tests. Later Scratch/controller changes have their own focused checks and signed iPad build records. Routine Mac/simulator/full-suite runs are disabled by the current iPad loop policy.
- Build 53's automatic launch timed out while the iPad was locked. Build 55 later installed and launched. Erik's listening and acceptance remain open.

## One working system

| Record | Purpose |
| --- | --- |
| [Requests](requests.md) | Every identified feature/request, implementation state, remaining work and evidence. |
| [Release gates](release-gates.md) | The checks that separate saved code, a test candidate and gig acceptance. |
| [Verification](verification.md) | Results tied to the exact combined source. |
| [Known issues](known-issues.md) | Blocking uncertainties and unfinished acceptance, with the next evidence needed. |
| [Pause snapshot](2026-11-02-pause-snapshot.md) | Historical position before integration. It is not the current branch status. |
| `chat-inventory.json` | Chat discovery record. It is not an exhaustive transcript review. |
| `private-candidate-inventory.json` | Historical local candidates and their differences. These require disposition, not blind merging. |
| `private-history-reconciliation.json` | Exact comparison against Git history: 285 historical matches, 624 private-only file versions and no missing files. |
| `handovers/` | Tracked copies of waveform, Brake and adaptive validation handovers, with original paths and hashes. |

The repository's older feature notes and `Replica/Status.md` retain dated evidence. This entry point controls current priorities and release status.

## Development feedback

Use [the micro-release loop](micro-releases.md) for each small change. Release a focused test candidate before starting the next feature. Historical reconciliation runs separately and does not block test releases. Full release gates govern gig acceptance.

## Order of work

1. Preserve and combine the existing work. Keep original branches and evidence.
2. Establish the exact combined candidate's build and regression results. Diagnose failures before changing code.
3. Resolve audio, transport, recording and interaction defects before adding features.
4. Reconcile historical requests and private candidates. Give each remaining item an explicit disposition.
5. Complete a coordinated test build and real-device acceptance, followed by Erik's rehearsal.
6. Finish remaining personalisation in small changes that pass the same gates.

No broader feature implementation or device session starts automatically from this list. Current ownership is this coordination chat. Other chats remain stopped unless Erik explicitly resumes them.

## Preservation

Local backup: `Backups/Coordination-2026-11-02/`. It contains the pre-integration changed/new files, their hashes, the tracked patch and Git references. It is ignored by Git.

Old feature branches and PR #2 remain intact as provenance. There is one active integration branch. No source branch, private candidate, original recording or validation directory was deleted.

Eighteen private candidate folders remain local. Their 909 differing text files include older experiments and snapshots. The inventory does not prove they are all obsolete or all integrated. Request R19 tracks that reconciliation explicitly.
