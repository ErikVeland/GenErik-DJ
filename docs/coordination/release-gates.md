# Test candidate and gig acceptance

The goal is Erik's personal TDJ1 successor for real performance. The reference workflow comes from 13 years of use. The minimum recorded device is the 2017 10.5-inch A10X iPad Pro. Existing deployment targets and performance limits remain unchanged.

## Gate 1: Preserved source

- [x] Commit the shared source, tests and feature notes.
- [x] Include remote main, full-library search, beatgrids and reverb in one integration branch.
- [x] Retain the old branches and local evidence.
- [x] Push the integration branch and record the review location. Draft PR #3: https://github.com/ErikVeland/GenErik-DJ/pull/3.
- [ ] Complete the historical private-candidate/request reconciliation, or explicitly list unresolved items.

## Gate 2: Combined application

- [x] Build the exact combined Release application for Mac and the generic iPad simulator.
- [x] Complete the serial regression run and retain every failure or crash. The combined run passed 688 tests.
- [ ] Verify search/layout merge behaviour and the new feature interactions.
- [ ] Resolve reproduced blocking defects with focused regressions. Do not relax tests or limits to obtain a pass.
- [x] Record the exact source, commands, result counts and known issues.

## Gate 3: Audio and performance

- [ ] Run the existing short and sustained workloads on the frozen combined source.
- [ ] Combine two decks, fixed/adaptive Sync, scratch, loops, slices, Flux, six FX slots, background analysis/search and recording.
- [ ] Require zero unexplained callback faults, invalid audio, source misses, recording drops and control deadline misses under the existing gates.
- [ ] Retain route changes and interrupted runs with their true status.
- [ ] Cover queued loading, cancellation, recovery, Brake and outgoing/incoming deck ownership.

The retained adaptive workload uses 10.667 ms per 512-frame callback at 48 kHz and 20 ms for exact control completion. Other workloads retain their own recorded limits. Do not copy a limit between different block sizes or scenarios without its context.

## Gate 4: Real setup and musical quality

- [ ] Agree on a device window before operating Erik's iPad or replacing an installed build.
- [ ] Verify the signed test build and its exact source identity.
- [ ] Test the real library, playlists, preparation imports, headphone cueing, output route and required controller.
- [ ] Listen to real music through scratch, Sync, key lock, loops, effects, recovery and Brake.
- [ ] Compare reverb texture, output balance and tails at actual app settings.
- [ ] Inspect portrait/landscape layouts, warnings, touch targets and reduced-motion behaviour.
- [ ] Verify recording, tracklist and transfer using the actual device.

Synthetic recognition results do not prove real-song structure accuracy. Silent stress tests do not prove good sound. A passing Mac test does not prove A10X acceptance.

## Gate 5: Erik's rehearsal and acceptance

- [ ] Rehearse a representative set on the intended performance setup.
- [ ] Record the session duration, build, routes, controller and music/preparation conditions.
- [ ] Resolve any audible defect, unintended transport action, lost preparation or blocked performance control.
- [ ] Confirm that the familiar gestures, visual treatment, sound and optional features meet Erik's expectations.
- [ ] Retain a known working build and rollback route before considering use at a gig.

No fixed duration or generic test count can promise perfection. Gate completion requires evidence and Erik's judgement. The current combined candidate has not passed these gates.
