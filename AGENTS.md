# GenErik DJ working rules

## Product priority

The main goal is a performance-ready app on the 2017 A10X iPad Pro, with uninterrupted audio and consistently responsive UI throughout a live set. TDJ1's performance is Erik's reference standard. Any audible gap, dropout, UI stall, visible stutter or delayed performance control is a blocking defect.

Preserve Erik's TDJ1 touch-first workflow. Audio and UI performance take priority over features, analysis quality, visual polish and repository cleanup. Background work must yield, pause or cancel before it compromises live performance. Verify improvements on the actual A10X. Keep existing deadlines and limits. Build success, host timings and a tidy repository do not establish performance readiness. Read `docs/coordination/README.md` and the request ledger before starting work.

The single-screen browser redesign and Performance/Browse/Expand shortcuts apply only to the closed/front phone screen. Preserve the existing iPad and Duo inside layouts. Portrait orientation alone must never select the front-screen design.

## Current development loop

Erik is the sole developer and acceptance tester. The active target is iPad only until he says otherwise. Follow `docs/testing/README.md`: feedback, one focused change, one incremental signed iPad build, install, hand back and stop. Use `tools/ipad_test.py`. Do not package the Mac app, run simulator builds, run broad regression sweeps or start other chats/agents in the routine loop. Keep release qualification separate and user-directed. Preserve a build number and feedback history for each iteration.

## Coordination and Git hygiene

- Use `main` as the consolidated source for every test build. The working folder is `/Users/veland/GenErik DJ`.
- Make changes serially on short-lived `feature/` branches in that folder. Merge each change into `main` before a build or handover. Do not commit directly to `main`.
- Other project chats are stopped. Do not resume them without Erik's instruction.
- Give each change a request ID from `docs/coordination/requests.md`. Record remaining work and its verification scope.
- Before editing, inspect the current branch and working changes. Preserve work owned by other tasks.
- Do not start concurrent implementation chats or create routine worktrees. Use a separate worktree only when Erik explicitly requests concurrent work.
- Keep historical worktrees inactive. Merge their committed work into `main` before calling it the latest test source. Preserve local edits and ignored build evidence before any cleanup.
- Keep changes coherent and committed. Do not silently leave source or tests untracked.
- Do not delete old branches, private candidates or validation evidence before verifying their disposition.
- Bind verification results to the source that ran. Preserve failed and incomplete results.
- Do not call an implementation complete, device-tested or gig-ready from build success alone.
- Use the micro-release loop in `docs/coordination/micro-releases.md` for small test releases. Full gig acceptance does not block a test build.
- A request to build, update or deploy to the test iPad authorises that operation. Ask about timing only when a testing hold or active performance makes the current authorisation unclear.

## Writing style

Use the `ste-writing` skill for prose deliverables, documentation, PR descriptions, commit messages, release notes, error messages and code comments. Use STE-flavored mode for general prose. Use strict mode for procedures and errors. Do not apply it to code, identifiers or command syntax. Use the skill's linter when it is available and a measurable check helps.
