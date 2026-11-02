# GenErik DJ working rules

## Product priority

Preserve Erik's TDJ1 touch-first performance workflow. Continuous clean audio and immediate performance controls take priority over new features. Read `docs/coordination/README.md` and the request ledger before starting work.

## Current development loop

Erik is the sole developer and acceptance tester. The active target is iPad only until he says otherwise. Follow `docs/testing/README.md`: feedback, one focused change, one incremental signed iPad build, install, hand back and stop. Use `tools/ipad_test.py`. Do not package the Mac app, run simulator builds, run broad regression sweeps or start other chats/agents in the routine loop. Keep release qualification separate and user-directed. Preserve a build number and feedback history for each iteration.

## Coordination and Git hygiene

- Use `feature/project-integration` as the current integration branch. Do not commit directly to `main`.
- Other project chats are stopped. Do not resume them without Erik's instruction.
- Give each change a request ID from `docs/coordination/requests.md`. Record remaining work and its verification scope.
- Before editing, inspect the current branch and working changes. Preserve work owned by other tasks.
- Use an isolated worktree for separate concurrent work. Do not let multiple chats edit the shared checkout.
- Keep changes coherent and committed. Do not silently leave source or tests untracked.
- Do not delete old branches, private candidates or validation evidence before verifying their disposition.
- Bind verification results to the source that ran. Preserve failed and incomplete results.
- Do not call an implementation complete, device-tested or gig-ready from build success alone.
- Use the micro-release loop in `docs/coordination/micro-releases.md` for small test releases. Full gig acceptance does not block a test build.
- A request to build, update or deploy to the test iPad authorises that operation. Ask about timing only when a testing hold or active performance makes the current authorisation unclear.

## Writing style

Use the `ste-writing` skill for prose deliverables, documentation, PR descriptions, commit messages, release notes, error messages and code comments. Use STE-flavored mode for general prose. Use strict mode for procedures and errors. Do not apply it to code, identifiers or command syntax. Use the skill's linter when it is available and a measurable check helps.
