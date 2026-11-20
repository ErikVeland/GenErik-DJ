# R506 extended A10X performance preparation

Erik requested immediate code improvements before a multi-hour rehearsal with the original Z1 and Beatpad. Build 232 is the starting point. Work stays serial and ends with one signed iPad build and handover.

## Design and scope

- Protect optional work for the whole performance, including silence and stopped decks. End Performance releases the hold. Playback read-ahead and required track loading keep their current priority.
- Avoid rewriting unchanged access state on each playback start. Keep the saved session and developer access rules.
- Bound retained detailed waveforms by bytes as well as track count. Preserve drawings in active views.
- Rotate long AIFF recordings on the existing serial writer. Preserve every accepted frame and produce matching tracklists. Keep file operations outside the audio callback.
- Save bounded session diagnostics with build identity, audio and streaming counters, memory and thermal observations. Keep reports off the audio callback and avoid frequent file writes.

The existing renderer, deadlines, audio buffers, Sync choice and controller mappings remain the basis. Broad DSP rewrites and reduced waveform quality are not part of this preparation pass.

## Verification plan

Reproduce background admission during a stopped performance and redundant access writes. Verify recording rollover with a reduced test boundary, exact joined samples, tracklists and failure preservation. Check cache budgets and diagnostic bounds. Run the focused affected regressions, then compile, sign and install from committed main. Retain failures under `TestBuilds/r506/`.

These checks cannot establish sustained A10X sound, touch or thermal acceptance. Erik performs that rehearsal after installation.

## Implementation

The first playback or recording start protects the performance. The saved session restores that protection after an app restart. Cloud preparation, Mac transfers, library analysis, deck analysis, arrangement analysis and detailed waveform generation yield or wait. Cached preparation stays available. End Performance releases the hold after decks, touches, pending starts, sample pads, the loop recorder and recording have stopped.

Repeated starts no longer rewrite unchanged access state. Playback refresh avoids unchanged recording, source-preparation and viewport notifications. Native Z1 feedback is prepared only while its accessory session receives data. Background file queues release temporary Objective-C objects after each work item.

The detailed band-waveform cache retains at most four tracks and 32 MiB of bin data. The existing range-index cache remains limited to 16 MiB. Both release retained cache entries after an iPad memory warning. Active views retain their current drawings. These limits do not bound the whole app or audio read-ahead memory.

The serial recorder rotates before the AIFF size limit, with 16 MiB reserved for export artwork and metadata. Each numbered part retains 24-bit audio and a text tracklist with local times. Later parts carry the latest known title for each deck. A separate session tracklist retains continuous times. A failed part creation preserves incomplete audio and reports failure. Playback continues through the existing recording-buffer contract.

Preparing a recording from the Recordings browser waits until End Performance. This action analyses the full file and could otherwise compete with playback for hours of audio. Prepared recordings remain loadable through the normal library.

Settings → Help & About provides the performance report. It retains the first sample, lifetime peaks and up to 720 recent samples at 30-second intervals. The report includes build identity, audio timing counters, streaming counters, recording drops, memory footprint, thermal state and connected controllers. Report writes run off the main thread. Monitor gaps are scheduling observations, not display-frame or touch measurements. The report spans the app session. Treat idle gaps between ended performances separately when reading this field.

## Combined handover

Erik authorised direct coordination with the recording-export chat for one combined build. R510 owns the export formats, artwork, metadata and sharing. R506 owns the performance changes and final iPad build. Both changes must be committed and merged into main before installation.

## Verification results

The initial session tests reproduced background admission during a stopped performance and redundant access-file writes. Both passed after the fix. The corrected rollover fixture reproduced the old single-file boundary. Failed fixture attempts and the corrected baseline remain under `TestBuilds/r506/`.

The first combined compilation found a missing `try` in the new cache test. The corrected run compiled the application and tests. That run was interrupted during interface checks. A process sample showed active background analysis. It does not establish a deadlock.

The recording-preparation regression reproduced an import during a protected session. The new guard prevents that work. The existing recording-preparation workflow now explicitly ends the performance before importing.

The broader final run stopped while Apple's Mac neural-model compiler awaited a synchronous reply. The log and process sample remain under `TestBuilds/r506/`. Analysis-dependent interface cases did not complete. A separate affected-scope run passed all 49 core checks and 33 of 34 interface checks. The remaining check contained a stale expectation that Beatpad 2 had no audio route. R291 already added a separate documented route. The corrected test checks both identities and rejects wireless routing. Production routing is unchanged.

The final affected-scope rerun passed all 83 tests: 34 interface checks and 49 core checks. Parameterised export and controller cases are included. The scope covers session protection, bounded diagnostics and waveform memory, controller routing/recovery, recording continuity/failures, and exports. Neural-model compilation and musical accuracy are outside this rerun.

Evidence: `TestBuilds/r506/focused-verified.log` and `focused-final-source.json`. Application source SHA-256: `83fedc5d88c757f649f4b0f026493873932a075896925aa8890eb42dcf95a374`. The source record also retains the test hash. Authored-source whitespace checks pass. Upstream LAME licence text retains its original whitespace. Build 233 passed compilation, signing and runtime-framework checks from main commit `266cbad8b`. Its source hash matches the focused test record. Three installation attempts failed with CoreDevice error `0xE8000003`, including one attempt with released Xcode tools. Erik was asked to unlock the iPad and reconnect USB. The saved app remains ready. See [build 233](../testing/builds/233.json).

## Remaining physical checks

Run the extended rehearsal on the A10X with the original Z1 and original Beatpad. Check continuous audio, touch response, browser opening, recording, cue/master routing and reconnect recovery. Share the performance report after the set. Check the numbered recording parts if the set crosses the AIFF boundary.

Cancellation remains cooperative. A model prediction already in progress can finish before its cancellation check. Host tests cannot prove thermal stability, controller wiring or sustained audio and touch acceptance on the iPad.
