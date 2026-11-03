# GenErik DJ project control

Updated 4 November 2026, Australia/Brisbane. This is the current project entry point.

**Current working mode:** [Erik's minute-scale iPad loop](../testing/README.md). iPad only, Erik as sole developer/tester. The broader release gates below are separate from routine iterations.

**Proposed next programme:** [TDJ1 gesture fidelity and unified touch space](../superpowers/plans/2026-11-03-touch-fidelity.md), led by R02/R30. It prioritises stable essential controls, direct panel manipulation and source-bound gesture acceptance. This is a plan, not a completed feature or permission to replace the current test build.

## Goal

Current completion scope: [remaining app work](completion-programme.md) and [all NI and class-compliant MIDI controllers](controller-coverage.md), with an allowed hardware bridge where necessary. Original Z1 is first for Erik's hardware testing.

Build Erik's personal successor to the DJ software he has used for 13 years. Preserve the TDJ1 touch workflow and make the sound, preparation and performance controls dependable enough for his real gigs. Visual polish and personalised features must support that workflow.

The release standard is Erik's acceptance on his real setup. A successful build or synthetic test is supporting evidence, not that acceptance.

## Current position

- Latest test-iPad candidate: build 80, application source `62efd9076de38ab9b3a706f68162befaf8db14b1`, installed and launched on the 10.5-inch iPad on 4 November. R02/R30/R32 unify direct library reveal/hide/resize, remembered session sizes per orientation and full expansion on every add-track request. The dock and R34 remain unchanged. All 1,501 focused assertions and signing passed. Erik checks gestures, search/loading and clean audio. Device acceptance remains pending. See `../testing/checks/R30/2026-11-04-library-panel/result.json`.
- Previous test-iPad candidate: build 78, application source `e6cf72aa26b36e75a91b30f44ca2e0a479b5ff14`, installed on the 10.5-inch iPad on 3 November. R02/R30/R31 add fixed right-hand FX/EQ/loop/Play stacks and a centred crossfader outside the resizable work area. The committed R34 false-chorus fix is unchanged. All 1,322 focused geometry assertions and signing passed. Automatic launch timed out. Erik opens the app manually and checks both stacks, fader, panel resizing and clean audio. Device acceptance remains pending. See `../testing/checks/R30/2026-11-03-stable-dock/result.json`.
- Active development branch: `feature/project-integration`.
- Latest installed Duo candidate: build 70, application source `4dfc867f889bf33a5cda2fdeeb2bc2ee57c6ccdc`, installed and launched on 3 November. R09/R29/R30 add musical suggestions and section hot cues, missing-BPM/key analysis on deck load, larger waveforms, vertical controls and optional Cue/headphone buttons. Erik acceptance is pending. See `../testing/checks/R09/2026-11-03-musical-structure/result.json`.
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
