# GenErik DJ project control

Updated 2 November 2026, Australia/Brisbane. This is the current project entry point.

**Current working mode:** [Erik's minute-scale iPad loop](../testing/README.md). iPad only, Erik as sole developer/tester. The broader release gates below are separate from routine iterations.

## Goal

Build Erik's personal successor to the DJ software he has used for 13 years. Preserve the TDJ1 touch workflow and make the sound, preparation and performance controls dependable enough for his real gigs. Visual polish and personalised features must support that workflow.

The release standard is Erik's acceptance on his real setup. A successful build or synthetic test is supporting evidence, not that acceptance.

## Current position

- Active development branch: `feature/project-integration`.
- Remote backup: `origin/feature/project-integration`. Review: [draft PR #3](https://github.com/ErikVeland/GenErik-DJ/pull/3), against `main`.
- Combined application source: `335cec6b77644f23d43c08fc236ba9d7db446a17`.
- Shared uncommitted work was backed up and committed as `7a974c385`.
- Current remote main, full-library search, adaptive beatgrids and A10X reverb are included by merge history.
- Browser merge resolution preserves full-library search and the iPad layout constraints.
- Other recent project chats, including **Valhalla Reverb Appeal**, were observed idle after the user stopped them. No other chat was restarted.
- Combined Release regression passed all 688 tests in 9 suites. Packaged Mac and full iPad simulator Release builds passed. See `verification.md` for source identity and limits.
- The combined candidate has not been installed or accepted on the physical iPad.

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
