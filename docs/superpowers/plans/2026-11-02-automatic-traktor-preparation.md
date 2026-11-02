# Automatic Traktor Preparation Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for each test-first task. Coordinate existing chat ownership. Do not create another chat.

**Goal:** Import available Traktor preparation automatically at launch with a quiet progress bar and clear missing-source feedback.

**Architecture:** An ordered set of explicitly accessible sources feeds the existing background validator and immutable archive. A coalesced model job controls progress and initial native-analysis ordering. The personal iPad build includes an optional read-only collection snapshot.

**Tech Stack:** Swift 6, SwiftUI, existing serial background executors, iOS 17.

**Spec:** The user reports that the import command does nothing and requests automatic launch import with a non-intrusive bar. Combined Audio Out and performance controls remain first priority. GenErik stays untouched while the user tests.

## Global Constraints

- Preserve all native audio inputs, original runtime control body, clocks, drivers and timing gates.
- Do not query, replace, launch or stop GenErik during the current testing hold.
- Do not claim access to NI's private iOS/iCloud container.
- Read original collection bytes without changing them.
- Preserve explicit and legacy manual selections and already-loaded preparation.
- Do not block performance controls or put parsing, hashing or file operations on Main.

## Review Focus

- Missing or invalid new sources must not erase an existing usable archive.
- Concurrent launch/foreground/manual requests must not silently disappear or run parallel imports.
- Native musical analysis must wait for initial preparation discovery.
- A malformed or cancelled replacement must not publish a partial collection.
- Progress must not resize performance controls, steal touches or invent percentages.

## Task 1: Core automatic source selection — second chat

- [ ] Add ordered automaticTraktorSources to LibraryService and automaticSources to storage discovery.
- [ ] Observe behavioural RED for explicit seed discovery using the old discovery logic.
- [ ] Add backward-compatible pointer origin. Protect manual and legacy selections.
- [ ] Validate and archive changed auto sources on the existing background worker. Preserve owned commit semantics.
- [ ] Pass source precedence, idempotence, replacement, cancellation and missing-source tests.
- [ ] Freeze Core inputs and release the shared build window.

## Task 2: Model job and launch ordering — root

- [ ] Reproduce the silent busy-import no-op through the existing public model API.
- [ ] Add separate preparation state and one coalesced job. Queue explicit requests behind current preparation work.
- [ ] Preserve unrelated importing state. Cancel/join only background native analysis when appropriate.
- [ ] Ensure native library opening waits for initial preparation; resume analysis after the preparation job.
- [ ] Test background progress, concurrency, missing/error feedback, native-analysis ordering and unchanged playing audio.

## Task 3: Quiet progress and personal snapshot — root

- [ ] Add a thin linear progress overlay in existing footer bounds, with no input interception or layout shift.
- [ ] Use actual operation state and actual record counts. Do not show fabricated percentages.
- [ ] Supply app-owned Documents inbox candidates and an optional bundled snapshot from the iPad entry point.
- [ ] Bind and package the current authorised Mac collection bytes and their manifest. Keep the original read-only.
- [ ] Compile and inspect the import-progress UI in a host-only render.

## Task 4: Combined verification and handoff

- [ ] Review the combined diff and exact source, project, tests and seed identities.
- [ ] Run relevant Release regressions, full serial Release and all generic builds.
- [ ] Run background-work/audio checks with original gates. Retain every failure.
- [ ] Keep existing Mac startup and interrupted-endurance failures visible until resolved.
- [ ] Prepare a signed test build without installing during active user testing.
- [ ] Request an update window only after the concrete build is ready if GenErik remains under the hold.
