# Traktor DJ 1.x reference capture and open questions

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

The current desk research is complete as a baseline. Exact 1.6.8 interaction and audio fidelity require reference captures. This protocol defines them without depending on an acquired executable.

The [NI tutorial review](07-ni-tutorial-video-findings.md) establishes many touch paths. The [period review](08-period-reviews-and-quantised-play.md) adds historical menu/default evidence and explicit deferred-Play support. Installed-build response and precise scheduler rules still need capture.

**Device modification and jailbreak work remain parked.** Do not treat this protocol as permission to resume them after a date or to reset the gig device. Prefer a separate reference device for destructive, fresh-install, cloud-conflict, low-space, purchase-restore, or crash-recovery tests.

## Capture preparation

Use existing local copies for preparation now. Later, record the app's version/build, device/OS, output hardware, firmware, cables, power, and relevant settings before any interaction trial.

Use a camera or screen recording that makes finger or hardware actions identifiable. Screen recording alone may omit touch locations. Capture the master output and, where relevant, the monitor output separately. Record the path's latency. A screen video's frame timestamp is not sample-level audio evidence.

Use isolated test music with known beat and source coordinates. Synthetic fixtures in `fixtures/` provide controlled inputs. They were generated on the Mac and have not been imported into the iPad. The fixture manifest gives intended beat sample positions and hashes.

Do not infer a touch timestamp from a waveform alone. Use a visible input marker, external input trace, or repeatable physical test where practical. Keep quantised wait separate from input latency.

## Capture sessions

| Session | Content | Output |
| --- | --- | --- |
| C01 | About/version, complete preferences, every drawer and modal, hardware disconnected | Screen inventory with actual labels, defaults and dimensions |
| C02 | First-deck start, both stopped, silent clock, global tempo, reset, Sync combinations | Clock origin and tempo-ownership rules |
| C03 | Early Play at every phase and every quantise value | T01–T04 and T15–T16 with audio/video |
| C04 | Cancel/replace queued actions, tempo changes while waiting, source changes | T05–T11 and pending-event decision table |
| C05 | Half-sync, re-Sync, grid phase/downbeat/BPM corrections | T12 plus exact grid editor controls |
| C06 | Single touch scratch/hold, pinch zoom, stripe preview and commit | Gesture thresholds, action edges and navigation states |
| C07 | Cue creation/deletion/recall, loop creation/resize/move/store/exit | Cue schema and loop state transitions |
| C08 | Freeze, Loop Slicer, zoom-dependent slices, Flux with overlaps | T13–T14 and slice/Flux ownership rules |
| C09 | SuperSlicer modes, all touch zones, two-finger and release behaviour | Complete action-to-sound map if already unlocked |
| C10 | EQ, filter, every effect, lock, simultaneous effects, reset and tails | Menu manifest, parameter curves and audio comparisons |
| C11 | Master/Monitor, cue mix, split output, first-use interface panel | Routing matrix and leakage tests |
| C12 | Z1, S2 MK2, S4 MK2, AUDIO 2 MK2 where available | Model-specific mapping, feedback and takeover tables |
| C13 | Browser, recommendations, playlist/folder operations, missing media | Library and recommendation behaviour |
| C14 | Recording, tracklist timing, history, export, delete/rename on test data | Audio/XML/history semantics and file lifecycle |
| C15 | Existing cloud metadata, offline use, controlled cross-device sync | Actual sync fields, file identity and conflicts |
| C16 | Background, lock screen, interruptions, route changes and relaunch | State restoration and interruption matrix |
| C17 | Help/notifications, extra-FX unlock status, share and integration screens | Complete secondary-flow inventory without purchases or public uploads |
| C18 | Representative complete set on a test setup | Duration, workflow, drift/glitch evidence and stability limits |
| C19 | Original suggestions across fixed reference tracks, tempo/key/genre/timbre contexts and deck states | Ranked output and compatibility feedback, REC01/03–06/09–10 |
| C20 | Performer-observed ranking adaptation with previous mixes and track combinations | Learning and persistence observations, REC02/07–08, without resetting the gig device |

Run the clock and launch sessions first. Incorrect timing assumptions would force changes across cues, loops, Freeze, hardware, and the UI.

## Priority open questions

| ID | Question to settle | Evidence needed | Affected scope |
| --- | --- | --- | --- |
| Q01 | Does the installed menu/default match the historical evidence? | S21 baseline; C01/C03 confirmation without resetting the gig device | F027–F030 |
| Q02 | Which rules govern Play, cue, Hotcue, Freeze, Loop Slicer, loop enter/exit and Pause? | Per-command matrix; vary Slicer Quantize independently | Transport model |
| Q03 | Which action edge accepts a command: down, up, completed tap? | Input and audio trace | Perceived timing |
| Q04 | What defines a bar origin when one or neither deck plays? | C02/C03 phase trials | Next-bar launch |
| Q05 | What cancels or replaces a pending event? | T05–T11 | Recovery and stale commands |
| Q06 | Does tempo change move a queued deadline? | T08 | Musical scheduler |
| Q07 | Is a pending source position captured or live? | Cue/seek after queuing | Transport semantics |
| Q08 | Does quantise change affect an already pending event? | T10 | Scheduler policy |
| Q09 | What happens within the near-boundary input window? | Repeated phase-offset trials | Exact launch feel |
| Q10 | Does Sync align beat phase, bar phase, or both for each action? | Offbeat and beat-3 cues, shifted downbeat | Musical phrasing |
| Q11 | How does master tempo initialise, persist and reset, and what is the wheel's exact response? | Touch entry/rotation D S15. C02 for clock and calibration | Central tempo workflow |
| Q12 | Is Keylock default-on, and what pitch does it lock? | Tonal capture and state inspection | Stretch/pitch fidelity |
| Q13 | What thresholds, conflict rules and loop-dismissal gesture govern the documented touch paths? | Core paths D S15/S16. C06/C07 for exact response | Touch arbitration |
| Q14 | What are preview cancellation and precise commit timing at each playback state? | Drag/release/beat-tap commit D S15. C06 for remaining rules | Navigation |
| Q15 | How does the grid marker occupy the eight documented cue slots? | Eight slots D S11. C07 for occupancy and lifecycle | Cue storage |
| Q16 | What are CUE's exact stopped/playing/held/released behaviours? | S2 and S4 trials, C07 | Conflicting manual descriptions |
| Q17 | What loop lengths, anchors and edge rules apply to documented two-finger creation/move/resize? | Gestures D S16. C07 for response | Loop engine |
| Q18 | How many touch slices apply at each scale and state? | S18 documents S4/S2 loop access as eight/four. C08 for touch | Slice mapping |
| Q19 | What ends Flux when several actions overlap? | C08 input/release sequence | Continuing position |
| Q20 | What are every SuperSlicer mode, vertical zone and multitouch rule? | C09 | Later 1.x performance |
| Q21 | What effects are actually installed, locked or unavailable? | C10/C17 menu capture | Effect scope |
| Q22 | How do FX locks and the demonstrated filter lock retain and release state? | Filter lock D S16. C10 for precise rules and FX | Persistent sound |
| Q23 | Does controller connection unlock multiple FX or change available modes? | Touch-only versus S2/S4 comparison | Hardware-dependent capability |
| Q24 | What is the processing order and each control's curve? | C10 calibrated signal tests | Audio fidelity |
| Q25 | Where are cue/recording taps, and which transport actions preserve each effect tail? | Delay-after-Stop D S16/S17. C10/C11/C14 for routing and other tails | Monitoring and recordings |
| Q26 | What UI controls exist for gain, autogain, limiter, crossfade and latency? | C01/C10. Record absence as well as presence | Technical specification |
| Q27 | What ranking, thresholds and tie rules underlie key/BPM recommendations? | Entry and green indicators D S15. C13 for ranking | Selection flow |
| Q28 | What creates history and recording-tracklist entries? | C14 audible/cued/brief/repeated tracks | Session data |
| Q29 | What units and origin does XML starttime use? | Timed test recordings and known loads | Export compatibility |
| Q30 | What does the exported GUID identify? | Same track across repeated exports and copies | Stable identity |
| Q31 | Which preparation data syncs through actual 1.6.8 iCloud? | C15 preserved collection and device comparison | Cloud/persistence |
| Q32 | Which background, route and relaunch states survive? | C16 | Lifecycle reliability |
| Q33 | Which settings and parameters persist per deck, track or app? | Before/after unload and relaunch matrix | State model |
| Q34 | What are the actual output latency, tempo accuracy and drift? | C03/C18 electrical audio captures | Audio performance |
| Q35 | What is the original stretch and effect sound across realistic material? | C10 matched reference corpus | DSP calibration |
| Q36 | How do reference track, performance tempo, key, timbre and genre affect suggestion candidates and order? | C19, REC01/03–06/09–10 | Core recommendation fidelity |
| Q37 | Which history events and retained state produce the ranking adaptation observed by the performer? | R2, C20, REC02/07–08 | Required personalisation behaviour and persistence |
| Q38 | What do existing tracklist identifiers and start-time values mean, and how do they relate to recommendation history if at all? | Preserved copies, metadata lineage and later reference observation | Avoid inventing a training-data path |

The [later 1.x source pass](09-later-1x-play-and-cancellation.md) leaves Q02/Q05 open. Its final trial section refines T04/T05 with paired controls and a source-phase comparison. S30 extends the historical menu baseline for Q01 without establishing installed-build defaults.

The [forum/help pass](10-archived-forums-and-in-app-help.md) also leaves Q02/Q05 open. S31 supplies partial original-help evidence for C17/F131. Archive access failed, so no claim rests on an unread archived NI post. These results do not authorise a trial on the gig iPad.

The [non-English pass](11-non-english-walkthroughs.md) records an exact early menu version, 1.0.3.182 [S34]. It shows quantise selection changes without establishing ordinary Play's response. Q02/Q05 and installed 1.6.8 behaviour remain open.

The [frame review](12-french-spanish-frame-review.md) documents a moving lead-in marker in S35. For C03, separately capture Play colour, marker travel, waveform motion and first audio. Q02/Q05 remain open because there is no matched preference trial or identifiable pair of accepted pending Play inputs.

The [controlled-test search](13-search-for-a-controlled-play-test.md) adds a public automatic-count-in example [S38]. No qualifying paired quantise/Play test or pending second press was found in the reviewed coverage. Locked course chapters remain unreviewed. Q02/Q05 remain open, and no trial on the gig iPad is authorised by these findings.

The [Hollin frame follow-up](14-hollin-jones-count-in-frame-review.md) finds one continuous orange indicator event and no distinct second activation. The indicator begins after green Play, so its timing is uncalibrated. For C03/C04, keep physical contact evidence separate from added indicators. Q02/Q03/Q05 remain open.

## Transport test matrix

Avoid treating a single successful launch as proof of the general rule. Vary these dimensions systematically:

| Dimension | Values to exercise |
| --- | --- |
| Playback state | Both stopped, A only, B only, both playing, end-of-file |
| Sync | Both on, A on/B off, A off/B on, both off, half-sync |
| Quantise | Every installed value, plus any actual off state |
| Slicer Quantize | On/off independently of size; establish which actions it affects |
| Input time | Early, mid-beat, late, near-boundary before/after |
| Source position | Bar beat 1, beat 3, fractional beat, pickup, near file end |
| Master tempo | Constant, small change, large change, half/double relationship |
| Performance mode | Normal, loop, Freeze, Loop Slicer, Flux, SuperSlicer |
| Input path | Touch, controller button, simultaneous touch and hardware |
| Pending changes | Second press, cue, seek, quantise change, Sync off, new load |
| Output route | Built-in test output, supported stereo interface, separate monitor |

Run a focused covering set first. Expand combinations where behaviour differs. Keep individual trials short enough to identify the cause of a difference.

## Touch measurement record

For each gesture, capture:

- Target region and starting view scale.
- Number of contacts and their order.
- Contact-down positions and timestamps.
- Movement distance, direction, velocity and duration.
- Whether the action starts on down, movement threshold, hold timeout or up.
- Whether movement is relative or jumps to an absolute value.
- Whether a second contact changes the first action.
- Which contact release ends or commits the action.
- Movement outside the target and touch cancellation.
- Competing touches on the other deck, header or newly opened drawer.
- Audible effect, display response and persisted result.

Thresholds, acceleration curves, smoothing, animation durations and touch targets are not established by the manuals. Measure them from the reference before claiming pixel or gesture fidelity.

## Audio measurement record

Use the synthetic fixtures for clock and routing. Use a broader, locally owned reference corpus for sound quality: drums, sustained bass, vocals, cymbals, pads, stereo ambience and material with natural timing variation.

Record source hash, decoded source format, test BPM/grid, all processing states, route, sample rate, capture format and alignment method. Keep raw captures. Do not normalise away gain, phase, latency or dynamics differences before measuring them.

For timing, detect the known pulse onsets and compare beat intervals, launch phase, source location and drift. For Keylock, compare pitch and transient shape at multiple ratios. For EQ/filter, use tones, sweeps and noise at controlled levels. For FX, capture parameter endpoints, middle values, beat divisions, bypass and tails.

The test fixtures are deliberately simple diagnostic signals. They cannot by themselves establish musical sound quality or reproduce the original's stretch algorithm.

## Persistence and export measurements

Use copies of test tracks and metadata. Distinguish four operations:

1. Unload and reload a track in the same session.
2. Quit and relaunch the app normally.
3. Make a library source temporarily unavailable on a test device.
4. Synchronise or restore preparation data on separate test devices.

For recording XML, create short recordings with track loads at deliberately different known times. Compare `starttime` against load, Play, first audible master signal, and elapsed recording time. Vary cue-only playback and repeated tracks to identify the entry rule. Do not infer units merely because values are integers.

For track identity, compare repeated exports of the same source and a separate copy of that audio. Do not assume a 16-character GUID is a hash of the file, a media-library ID, or a desktop Traktor ID.

## Completion gate for a faithful rebuild specification

The specification can claim full observed coverage only when:

1. Every visible screen, menu, preference, help flow and hardware-dependent variation is indexed.
2. Every applicable feature row has a source or direct capture, with actual absence recorded for rejected candidates.
3. Each journey has reproducible initial state, inputs, expected states and an audio outcome where relevant.
4. T01–T16 settle the clock, queued transport, cancellation and Flux rules.
5. Loop, cue, Freeze and SuperSlicer mappings include their complete release and exit behaviour.
6. Effects and mixer controls have measured ranges, curves, routing, persistence and tails.
7. Local storage, recording, history and any supported sync flows have demonstrated identity and failure rules.
8. Supported hardware has exact mappings, feedback and route tests for named configurations.
9. Lifecycle and recovery have defined outcomes for the tested OS/device combinations.
10. Suggestions reproduce reference candidates, ordering, compatibility feedback and the performer's observed history-dependent adaptation. REC01–REC10 retain the contexts and outputs.
11. Analysis and grid correction reproduce the reference musical coordinates and their effects on timed actions and suggestions.
12. Remaining unknowns are explicitly accepted scope limits rather than hidden assumptions. No essential behaviour can be called faithfully reproduced while its required outcome remains unresolved.

The current dossier does not pass that full-observation gate. It provides the desk-research foundation, a comprehensive candidate inventory, and the concrete work needed to reach it while preserving the performance device.
