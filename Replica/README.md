# GenErik DJ replica — native development build

Documentation reviewed against the shared implementation on 30 October 2026. [Current readiness and verification](Status.md) is the implementation status record. Dated measurements below apply only to their recorded source and workload.

This build starts the independent TDJ1 reconstruction with audio analysis, grid preparation, adaptive suggestion infrastructure, playback and a shared master tempo. It shares Swift and C code between a Mac development app and an iPad target. The reference remains Traktor DJ **1.6.8 / 1.6.8.67**.

The [performer fidelity specification](../Analysis/Traktor-DJ-1x/15-performer-fidelity-specification.md) governs this work. The confirmed performer priority is key, ±8% BPM, similar energy, then previous pairing. Original ranking details still need reference comparison. This build is **not yet a matched TDJ1 replica**.

**BPM, key, energy and automatic downbeat are all required at TDJ1 quality before a 1:1 contender claim.** The current independent multiband analyser includes automatic downbeat detection, tuning-aware key estimation and musical energy features. These remain unverified against real-music TDJ1 outputs. Analysis is the current development priority; see [current analysis status](Analysis.md). The [analysis fidelity contract](../Analysis/Traktor-DJ-1x/18-music-analysis-fidelity.md) and executable `tdj-tool benchmark-analysis` keep exact tempo, full-track drift, key, bar alignment and energy failures visible. Synthetic diagnostics cannot satisfy the real-music reference gate.

## Current verification — 30 October 2026

Analysis is the current development priority. The shared engine is `independent-dsp-0.2.1`: multiband tempo/grid consensus, automatic four-beat downbeat inference, tuning-aware key estimation and normalized musical energy. The fresh rerun passes 12 selected analysis/provenance/storage tests and all 50 labelled checks across the 10-track synthetic corpus. It does not establish real-music or original-app accuracy. The reference benchmark intentionally exits 2 while paired TDJ1 annotations are missing.

The importer integration full package attempt recorded 341 successful individual tests, five decoding failures and an AVAudioEngine startup crash. It is not a complete passing regression. See [analysis results](Analysis.md) and [overall status](Status.md).

The most recent retained physical baseline is the separate signed27 diagnostic app on GenErik, the 2017 10.5-inch A10X iPad Pro. Its source `ab5a7455…` passed five-minute panel workloads with 48 kHz and 44.1 kHz source fixtures: zero measured audio/control failures, source misses or recording drops. Worst callbacks were 5.867 ms and 6.111 ms against 10.667 ms. Hardware output was silenced and controls were automated; these are not listening, real-library or manual-touch acceptance.

That installed diagnostic baseline predates the latest shared FX, loop, tempo-wheel and analysis changes. Its passing results do not verify the current combined source. A stable current build needs fresh combined-device acceptance before gig use.

The original-preparation follow-up passes 27 focused tests and production import of the real 5,995- and 10,881-entry collections, with unchanged originals. ARM64 iPad code compiles and an unsigned iOS 17 app links. Physical iPad testing is blocked by device-service permissions; these results are not a real-audio accuracy or on-device pass. See [import evidence and limits](TraktorPreparation.md).

## iPad gesture parity requirement

The [current live Mac check](Validation/LiveMacControls-2026-10-29-01/manifest.json) verifies the native Music catalog, search, playlist selection, local preparation, directional deck loading, playback and AIFF finalisation. It also verifies the three SuperSlicer family selectors and FX/mixer panels. The lock-screen blocker is cleared. Slow Music-service startup, original fidelity and physical iPad acceptance remain open.

All original Traktor DJ 1.x iPad gestures must work 1:1. The app now implements contact-aware waveform/grid control, stripe zoom, eight saved cue slots, two-finger loops, Freeze/Loop Slicer, Flux, XY filter locks, touch EQ and three FX slots. **Original gesture and sound fidelity remain unverified.** The [implementation notes](Gestures.md) identify working routes, tests and remaining differences. The [gesture contract](../Analysis/Traktor-DJ-1x/17-gesture-fidelity.md) stays open until paired iPad comparisons pass.

## Core requirements added on 23 October 2026

The [eight core performer requirements](../Analysis/Traktor-DJ-1x/15-performer-fidelity-specification.md#eight-core-performer-requirements) include two explicit additions:

**Library integration is required on both Mac and iPad.** The iPad must browse its own synced Music library and playlists through the same preparation and deck-loading workflow, without depending on a Mac. The feature remains incomplete until the [iPad device acceptance checks](MusicLibrary.md#required-ipad-device-acceptance) pass on an authorised test device.

| Requirement | Current implementation | Completion check |
| --- | --- | --- |
| Integrate with the performer's local/synced iTunes / Apple Music library | Native song and playlist browsing, search, selected-song preparation, source identity links and existing analysis/deck loading are implemented. Subscription streaming is excluded. | Verify the complete route against the local Mac library and later on a safe test iPad. See [Music library notes](MusicLibrary.md) for measured scope. |
| Record sets as AIFF and transfer them to a Mac | Master-output recording, saved-set browsing and native AIFF sharing are implemented. The development default is 48 kHz, 24-bit stereo. | Local format, duration, audio and copied-file checks pass. Physical iPad-to-Mac transfer and original gestures remain unverified. See [recording notes](Recording.md). |

AIFF is the requested replica output. Existing acquired TDJ1 exports are WAV files, which do not establish original AIFF support. The library and AIFF recorder now have development implementations. Native sharing provides a transfer route, but device acceptance remains unfinished.

## Run on the Mac

From this directory:

```sh
./Scripts/check.sh
./Scripts/run-mac.sh
```

The app writes its library, playback cache and archived preparation references only to `.workspace/`, or the directory explicitly supplied in `TDJ_WORKSPACE`. It imports copies of selected local audio. It does not scan backups, read an iPad, invoke acquisition tools or modify source recordings. The pinned Keylock DSP source is included in the project. No package download or network service is required to build or run it.

Use **Music library** in the development toolbar to browse local/synced songs and playlists. Search or select a playlist, choose songs, then use **Add selected**. **Select available** selects the available songs in the current results. Choose **Done** to return to the prepared collection and use its normal deck-load slider. **Refresh** reads changes made in Music.

Use **Import Traktor preparation** to select an original TDJ1 `collection.nml.gz` or `collection.nml`. Exact native-library matches reuse supported original preparation with provenance; complete new matches generate a waveform without independent musical analysis. See [import details, real-data verification and limits](TraktorPreparation.md).

Use **Import audio** in the development toolbar for standalone files. Swipe upward on the deck area, or choose Songs, to open the collection. Select a track to reveal its load slider. Drag the slider upward for A or downward for B. Selection alone does not load.

The collection also offers Playlists, Artists, Albums and Genre. Choose **Edit**, select tracks, then **Add to Playlist** to create or extend a local playlist. Search includes album metadata. These playlists are saved in the app workspace. See [collection behavior and validation](Collection.md).

The [combined validation report](Validation/combined-performer-validation.md) records the 26 October regression results and remaining reference/device acceptance gaps.

The subsequent [responsiveness pass](Responsiveness.md) removes UI file reads and transport waits on background persistence. [Performance measurements](Validation/performance-priority.md) cover native Mac audio under FX and analysis load. They do not replace the required reference-iPad benchmark.

Tap the destination artwork area for suggestions. The app uses your confirmed order: key, ±8% BPM, similar energy, then previous pairing. Audible deck overlap adds retained pairing history. See [policy and limits](PerformerSuggestions.md).

Use the flag control to enter this build's grid editor. Drag the waveform against the grid, correct BPM with half/double/tap, and select a downbeat. The stripe changes the inspected region. Pinch the stripe to change waveform scale. These changes retain the detected analysis separately from manual preparation.

## Set recording

Choose **Record** to capture the current stereo master output. Choose **Stop recording**, then **Recordings → Share AIFF** to transfer the saved set through the system share panel. Saved sets remain available after restart in the workspace's `Recordings/` folder.

The writer runs outside the audio callback. It produces uncompressed, big-endian, 24-bit stereo AIFF at the transport sample rate (48 kHz by default). Stop audio and audio interruptions also finalise the current recording. The controls are development access, not matched original gestures. [Recording notes](Recording.md) describe tests, transfer acceptance and limits.

## Playback and master tempo

Load A and B. Press A's Play control to start the reference. With both decks synced, press B's Play before the next bar. B's Play turns green during the wait. Its pale lead-in marker advances while the source remains stationary and silent. The audio renderer starts B at the bar boundary.

Tap the master BPM in the top bar to open the tempo wheel. Rotate the wheel to change the shared tempo. Synced decks follow it. This development model keeps a queued launch attached to its musical target when tempo changes. UI refresh timing does not control the launch.

Play on an already playing deck pauses it. Pressing Play again on a queued or preparing incoming deck cancels that pending start, as confirmed by the performer. Other unresolved pending interactions remain gated. **Stop audio** is a development-toolbar control that stops both decks and clears pending audio. It is not claimed as an original TDJ1 control.

**Keylock now preserves source pitch when the master tempo changes.** It starts enabled separately on A and B in this development shell. Use the note icon in the development toolbar to toggle either deck. The small lock indicator beside its key shows the acknowledged state. Keylock and Sync are independent.

The touch control, original default, pitch anchor, toggle ramp and persistence still need TDJ1 reference captures. The development menu is temporary access to the implemented function. It is not presented as TDJ1's touch route. Changing Keylock on an already queued deck remains gated. With Keylock off, tempo changes pitch as before.

The [Keylock notes](Keylock.md) describe the pinned DSP, delay compensation, signal tests, generated listening examples and sound limits. This is an independent implementation. **NI's exact stretch/pitch sound is not matched or claimed.** Cue and saved-loop recalls now prepare cold targets without disturbing current audio. Immediate nearest-beat Sync restoration is implemented, including backward correction; original display thresholds and interaction edges remain unverified. The [playback notes](Playback.md) and [development policy manifest](Calibration/transport-development-policy.json) identify provisional rules and gated interactions.

The Import command, grid-entry control, layout, drag sensitivity, downbeat buttons, tap estimator, gesture thresholds and touch-load dismissal are development scaffolding or uncalibrated details. They must be matched to the original before a fidelity claim. Four-beat inspection exists in the core without inventing a confirmed touch equivalent.

## Implemented

| Area | Working implementation | Fidelity limit |
| --- | --- | --- |
| Audio analysis | Chunked PCM decoding, waveform peaks/RMS, multiband consensus tempo/grid estimation, automatic four-beat downbeat inference, tuning-aware key estimation and musical energy descriptors | Independent DSP. Original accuracy, octave choice and sound descriptors are not recovered |
| Original preparation | Production TDJ NML17 XML/gzip import, exact native-ID/duration matching, raw provenance and protected grid/key/cue reuse | Physical iPad validation and paired real-audio comparison remain open; see [import notes](TraktorPreparation.md) |
| Musical data | Separate source analysis, corrected BPM/grid, downbeat and key override | Automatic downbeat inference is implemented and may return unknown when bar evidence is ambiguous. Real-music accuracy remains unverified |
| Grid editing | Waveform/grid coordinate transform, BPM half/double/tap, four-beat inspection and persistence | Exact original sensitivity, rounding, action edges and commit rules remain open |
| Collection | Native local/synced Music library songs and playlists on Mac/iPad, search, selected imports, source metadata/identities, background analysis and private audio copies | Content SHA-256 remains the internal identity. Native IDs link source items without replacing preparation. iPad library runtime and original collection gestures remain unmatched |
| Suggestions | Ordered key, ±8% BPM, similar-energy and prior-pair comparison | Order/range/direction are user-confirmed. Key tiers and energy estimation remain unverified |
| Adaptation | Audible master overlap creates deduplicated pairing history, retained across restart | Exact original learning thresholds remain unresolved |
| Performer routes | Two stacked deck views, artwork entry, selection without loading and directional load slider | This slice covers preparation. Full touch arbitration and original screen geometry remain unmatched |
| Persistence | Atomic library/preparation/event/model/calibration snapshot, schema checks, corrupt-file rejection and separately archived TDJ reference provenance | This schema is new. Original NI files remain read-only |
| Set recording | Master-output AIFF capture, saved-set discovery and native sharing | Original gesture/format defaults, device transfer and gig-length reliability remain unverified |
| Mixer | Crossfader, deck volume, three-band EQ, XY filter and separate headphone bus | Independent DSP and unverified hardware routing; see [mixer notes](Mixer.md) |
| Z1 | Opt-in Mac HID input/output, calibrated crossfader, mixer and MODE+CUE transport | Synthetic packet tests only. iPad transport and hardware FX acceptance remain unfinished |
| Playback | Shared stereo render path, bounded streamed PCM pools, independent deck positions and pause/resume | Unlocked resampling, mix gain and original lifecycle rules remain uncalibrated |
| Keylock | Per-deck pitch preservation, linked stereo DSP, compensated pre-roll, unity bypass and independent Sync state | Signalsmith Stretch is a reconstruction choice. NI's algorithm, sound, pitch anchor and touch route remain unmatched |
| Master tempo | Tap-to-open rotary wheel, phase-continuous tempo changes and synced speed ratios | Wheel response/range and initial clock ownership remain provisional |
| Early Play | Incoming synced deck waits for the next bar, retains its source position, shows a moving lead-in and starts inside the correct render buffer | Exact-boundary acceptance, Quantize Size's scope and original second-press rules remain unresolved |

Key and genre remain separate. Genre comes from embedded metadata when available. No genre classifier is substituted. A sustained single tone or silence can return no tempo/key rather than fabricate confident musical data.

Cue/loop performance, Freeze, Flux and all eleven named effects have development implementations. Original behaviour and sound, physical hardware acceptance and cloud preparation sync remain incomplete. The Mac Z1 HID transport has not been tested on hardware. Grid editing can retain the audible source position during playback, but the original clock response to grid changes still needs measurement.

## Stress validation

The [stress report](Stress.md) records the rapid-tempo, sustained handover, concurrent-control and silent native Mac audio checks. These tests fixed discarded DSP samples, phase resets at native-speed crossings, accumulated clock rounding and the development Stop path under saturated controls. The [earlier stress validation](Validation/keylock-stress-validation.json) preserves those results. The [native 128-frame follow-up](Validation/native-128-validation.json) adds page preparation during background loading and fixes the test checker at fractional bar boundaries. The five-minute test passed with 112,501 callbacks and 79 exact starts. A short repeat retained one HAL overload and timestamp gap, so reliability remains qualified.

The [HAL isolation follow-up](Stress.md#remaining-hal-isolation) passed five minutes after the user closed the shared Scarlett client: 112,504 real 128-frame callbacks, 79 exact logical starts and zero HAL overloads, timestamp gaps or render deadline overruns. The original 512-frame buffer was restored. Earlier failures remain retained, and their cause is unproven. No speculative playback fix is retained.

## Performer suggestions

The app and `tdj-tool suggest` use the confirmed performer policy without a calibration file. See [PerformerSuggestions.md](PerformerSuggestions.md).

## Earlier experimental calibration

The following describes the separate research scorer. Use `tdj-tool suggest-calibrated` to exercise it. It is no longer the default app route.


`SuggestionEngine` requires an explicit `SuggestionCalibration`. No production defaults are supplied for unknown TDJ1 weights, compatibility thresholds, accepted learning events, minimum duration, transition symmetry or tie handling. A profile also records whether its provenance is synthetic development or original reference evidence. That label does not certify equivalence.

The [synthetic profile](Calibration/SYNTHETIC-DEVELOPMENT-ONLY.json) exercises the implementation. Its numbers are deliberately **not TDJ1 facts**. Tests demonstrate that a qualified combination changes ordering, that loads/previews need not train under that example policy, and that adaptation survives a restart. These tests do not establish the original rules.

For a separate synthetic workspace:

```sh
.build/debug/tdj-tool import --workspace .workspace-synthetic \
  ../Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav \
  ../Analysis/Traktor-DJ-1x/fixtures/clock-b-120.wav \
  ../Analysis/Traktor-DJ-1x/fixtures/clock-b-128.wav
.build/debug/tdj-tool install-calibration --workspace .workspace-synthetic \
  Calibration/SYNTHETIC-DEVELOPMENT-ONLY.json
```

The import output provides track IDs. `tdj-tool suggest-calibrated --workspace DIRECTORY REFERENCE_ID b` returns candidates. `record-event` accepts an explicit `PerformanceEvent` JSON file. It does not infer transitions from NI XML exports. Calibration installation rebuilds memory from the retained event journal and saves calibration and learned state together. Restart the development app after installing a profile.

Retain source/library context and original ranked results for [REC01–REC10](../Analysis/Traktor-DJ-1x/16-next-track-suggestion-fidelity.md). Match those results before enabling a profile as reference behaviour. A new model that makes appealing suggestions is insufficient.

## iPad source and validation

`iPad/GenErikDJ.xcodeproj` wraps the shared interface in a separate development app, bundle `org.generikdj.replica.development`. Do not deploy it to the gig iPad.

```sh
./Scripts/check-ipad.sh
```

That command cross-compiles the shared core/interface for the ARM64 iPad simulator SDK. It does not start a simulator, enumerate devices, sign an app or deploy anything. The wrapper is also type-checked separately during validation. The complete unsigned app also builds for the generic simulator platform with `bash Scripts/build-ipad-app.sh`; this does not install or launch it. `Validation/ipad-complete-release-build.log` records the release build. Its generated plist includes iPad-only support, background audio and the Music-library permission text. Physical iPad runtime acceptance remains pending.

The scripts use SwiftPM's smaller native build path, two compiler jobs and local caches. This worked around the first build's storage failure with the installed Xcode beta. The toolchain warns that this build path is deprecated.

The agent's restricted process sandbox also blocked Apple's AAC codec service. Apple's own `afconvert` failed there and succeeded in an approved local check outside that process sandbox. AAC validation therefore needs the normal local process environment. The analyser handles decoder errors without querying the crashing frame-position getter.

See [build validation](Validation/build-status.json), [Keylock validation](Validation/keylock-validation.json), [regression tests](Validation/keylock-stress-tests.log), [iPad compilation](Validation/keylock-stress-ipad-compile.log), and [rendered preview](Validation/preview.png). The earlier [playback validation](Validation/playback-validation.json) remains the record of that phase. Checks cover analysis, grids, metadata, preserved originals, adaptive ordering, restart, stale events, bar launches, pitch, stereo polarity, tempo changes, pending silence and PCM playback. They are not original-app fidelity measurements.

## Source layout

- `Sources/TDJCore/`: analysis, musical coordinates, library, history and calibratable ranking.
- `Sources/CTDJTransport/`: audio-frame clock, command/message rings and stereo source rendering.
- `Sources/TDJInterface/`: shared preparation interface and workflow state.
- `Sources/TDJPreview/`: Mac app and headless preview rendering.
- `Sources/TDJTool/`: local analysis, import, calibration and history tools.
- `Tests/`: signal, persistence, ranking and performer-route checks.
- `Validation/`: build results and preview artifacts from this development pass.

Audio decoding uses Apple's [AVAudioFile](https://developer.apple.com/documentation/avfaudio/avaudiofile). Build targets use [Swift Package Manager](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html). These are implementation references, not evidence of NI internals.

The gig iPad remains untouched. Jailbreak work remains parked.


Library scaling and schema migration are described in [Storage.md](Storage.md).
