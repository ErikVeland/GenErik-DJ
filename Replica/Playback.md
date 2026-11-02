# Playback master tempo and early Play

Documentation reviewed against the shared implementation on 30 October 2026. [Current readiness and verification](Status.md) is the implementation status record. Dated measurements below apply only to their recorded source and workload.

The implemented journey follows R1/S20: one deck plays against shared musical time, and a synced incoming deck accepts Play before the next bar. The source position waits, then starts at the boundary. S15 supplies the master-BPM entry and rotary gesture. S35/S38 supply the green-Play and moving lead-in sequence.

This is a working development model. Exact TDJ1 sound, wheel response, timing edges and unresolved interactions still require reference comparisons. The [fidelity specification](../Analysis/Traktor-DJ-1x/15-performer-fidelity-specification.md) remains authoritative. The performer has settled second-Play cancellation. Remaining original timing and sound details stay open.

## Performer route

1. Select and load tracks using the existing up-for-A/down-for-B slider.
2. Wait for the private PCM cache to finish preparing. The original audio remains unchanged.
3. Press A's Play. The shared clock adopts its prepared BPM unless a master tempo was already selected.
4. Keep B synced and press its Play before the intended bar.
5. B's Play becomes green. A pale marker moves towards B's held source position.
6. The audio renderer begins B at the scheduled bar. Waveform following starts after the source starts.
7. Tap master BPM to reveal its wheel. Rotate it to change the shared pace. Double-tap the wheel to restore the sync master track's original prepared BPM. Tap BPM again to dismiss this build's wheel.

Double-tap reset is performer-requested (30 October 2026). The current shared-clock model has no separate master-deck selector, so reset uses the earliest-started playing synced deck. When it pauses or ends, the remaining playing synced deck becomes the reset reference. If neither is playing, a paused synced deck takes priority over a ready synced deck; equal start times prefer A. With no eligible synced track, reset leaves the tempo unchanged. The track's prepared grid BPM includes manual tempo corrections. Synced followers use the existing tempo-change path, preserving source positions and beat phase; unsynced decks retain their speed. Short single-contact taps anywhere on the wheel, including its centre, qualify; drags, holds, cancellation and extra contacts clear the tap sequence. Tap thresholds remain development choices.

Steps 3 and 7 include provisional initialisation and dismissal details. They do not establish original defaults. The complete development assumptions are in [the policy manifest](Calibration/transport-development-policy.json).

## Audio and musical time

`SampleTransport` wraps a C renderer. `PlaybackController` feeds that same renderer through one `AVAudioSourceNode` created by the Objective-C++ `TDJNativeAudioSource` bridge. The render block calls the C transport and recording capture directly; it does not enter a Swift rendering closure. Both decks share the output sample timeline and final mix path. There is no separate incoming-deck delay correction.

The control producer sends bounded commands through a single-producer/single-consumer ring. The render callback performs no allocation, decoding, logging or blocking wait. A bounded message ring acknowledges commands and retires replaced assets outside the callback. Atomic snapshots supply UI state. The UI polls at about 30 Hz and does not schedule audio.

Tempo changes retain the current beat phase. A queued launch stores a target master beat. The renderer derives the corresponding output frame from the current tempo segment. It can start the source inside a buffer. The target does not round to a buffer boundary.

Normal early Play targets the next four-beat boundary. If the reference track ends before that bar at its current speed, the implemented fallback targets the next beat. This is an explicit development assumption for the unresolved near-boundary rule. No arbitrary timing epsilon or delay measured from a tutorial video is used. Quantize Size has not been connected to Play because its original scope remains unresolved.

The selected source frame remains fixed during the lead-in. A pickup, fractional source position or selected third beat is not relabelled as source beat one. Initial clock phase uses the first reference's grid/downbeat. Later clock ownership and re-anchoring still need original captures.

`PCMCache` decodes private stereo Float32 files in chunks. Production playback reads them through fixed 32 MiB per-asset pools, with a global 128 MiB cap that includes retained and retiring assets. Unlocked playback uses linear variable-speed interpolation. Keylock reads native-pitch samples into the per-deck stretch processor, with pre-roll compensation. Existing recordings and NI exports are not rewritten. The loader prepares the initial source window before the deck becomes ready. A separate urgent worker performs bounded read-ahead; analysis and library work run at lower priority. Cold jumps prepare their target while current audio continues. Memory-mapped playback remains available only for reference comparisons. No disk preparation runs in the render callback. The [Keylock notes](Keylock.md) describe the local render check. Five-minute synthetic iPad baselines have been measured on older recorded sources. Current-source gig duration, acoustic latency and memory-pressure acceptance remain open; see Status.md.

## Known limits and explicit gaps

| Behaviour | Current build | Original fidelity status |
| --- | --- | --- |
| Master wheel | Tap BPM, rotate the visible wheel, synced rates follow | Entry/gesture documented. Scale, limits, inertia and dismissal unmatched |
| Normal early Play | Queue synced B against synced playing A, launch at next bar | Required journey works. Exact conditional and edge rules remain open |
| Green Play before source movement | Queued state is green with a moving pale marker | Qualitative sequence supported. Geometry, animation and audio-to-display offset unmatched |
| Master changes while B waits | Musical target remains fixed, output deadline changes | Development model tested. Original rule still requires comparison |
| Second Play before B starts | Cancels the pending incoming start; reference deck continues | Direct performer confirmation, 28 October 2026 |
| Pause reference while B waits | Reference pauses; the clock continues and B starts at its queued beat | Development policy; original behaviour unverified |
| Seek, Sync change or grid edit on queued B | Reports unresolved | No original pending-source policy selected |
| Playing destination load | Refused in development | Original warning/protection gesture still needs capture |
| Sync off | Preserves an audible speed, uses native speed before first playback | Exact original retention and defaults remain open |
| Sync realignment while playing | Immediate smallest jump to the nearest admissible beat; backward allowed | Performer-confirmed policy implemented. Original colour threshold and remaining gesture edges need comparison |
| Keylock | Implemented independently per deck, enabled at development startup | Source pitch is retained. NI sound, pitch anchor, defaults and touch route remain unmeasured |
| Pause, EOF, both stopped | Development rules recorded in the manifest | Original quantisation, restart and silent-clock semantics remain open |
| Audio-route change, interruption, view close | Stop development audio, clear queued starts | Lifecycle guard, not a recovered NI rule |

The displayed half-sync threshold is provisional. The app does not claim original phase-colour thresholds or complete original resync fidelity. A master-tempo change also does not invent a new recommendation-ranking rule.

## Reproducible timing evidence

Run `.build/debug/tdj-tool transport-probe Validation/Playback` after building. It writes two four-second PCM WAV files and a [trace manifest](Validation/Playback/transport-traces.json). A generated reference tone occupies the left channel. The incoming tone occupies the right channel, so its silence and onset can be measured independently.

At 48 kHz, Play is accepted at frame 36,000 / master beat 1.5. Both scenarios target master beat 4:

| Scenario | Scheduled source start | First nonzero incoming sample |
| --- | --- | --- |
| Remain at 120 BPM | 96,000 | 96,001 |
| Change to 128 BPM at frame 60,000 | 93,750 | 93,751 |

The extra sample is the generated sine's zero-valued first sample. It is not a scheduler delay. The [regression suite](Validation/playback-tests.log) also checks several buffer sizes, three output rates, source-position retention, end-of-file bounds, stale generations, queue backpressure, retained PCM identity and the live-view state model.

These files contain synthetic signals. They measure the reconstruction renderer at its mix output. They do not measure touch recognition, speaker latency or the original TDJ1 engine.

The native Mac check used the bundled synthetic clocks. A started at output frame 0 and B started at 96,000, one bar later. The lead-in showed green Play and a pale marker before B's waveform advanced. After stopping, rotating the master wheel from 120 to 129 BPM updated both synced rates to 1.075. A resumed through the native output at that speed. The captured snapshots are [the bar launch](Validation/native-bar-launch.json) and [the master-tempo change](Validation/native-master-tempo.json).

The first native Play exposed a Swift actor-isolation trap in the audio closure. The callback now explicitly uses `@Sendable`; the native checks above passed after that fix. This check confirms native callback execution and displayed state. It does not certify speaker routing, acoustic onset or performance under load. **Stop audio** saves a local development snapshot to `.workspace/last-playback-stop.json` when device output was active.

The generic build scripts do not operate devices. Separate authorised GenErik diagnostic runs exist, as recorded in Status.md. The gig iPad remains untouched and jailbreak work remains parked.

## Performer timing clarification — 25 October 2026

The performer requests next-beat alignment with a preference for a four-beat bar start where possible. They explicitly confirm waiting for the next bar when Play is pressed just after beat 2. The renderer retains normal next-bar scheduling. If the reference will end before that bar at its current speed, it schedules the next beat instead. This fallback interprets the stated preference and remains to compare with original end-of-track behaviour. The incoming source stays silent and stationary until its scheduled sample.

## Prepared output startup — 29 October 2026

The controller reads the source node's maximum after engine preparation and passes known bounds into initial streamed-cache construction. A cold LOAD after a route-bound change is prepared again before bounded retry. The existing retirement message releases rejected LOAD generations without disturbing another active generation.

Resuming already active logical playback holds engine start until current, pending and Flux source coverage is prepared and adopted. Zero-frame consumer progress runs while awaiting worker reads. Both decks sharing one asset prepare as a combined request. Source geometry and host bounds are rechecked after preparation, and the native renderer must confirm its adopted coverage before engine start; mixer/FX updates do not restart it. Stop, route changes and interruptions cancel startup. A successful cold action can request startup again if the earlier active deck stopped while preparation was pending. A second Play that cancels an incoming action cannot replay captured old intent.

The real-engine startup/cancellation checks and current 60/300-second combined results are in [the current audio priority report](Validation/audio-priority-2026-10-29.md). Hardware output was silenced for these Mac checks. Sync restoration is implemented. Its exact original interaction edges and current-source target-iPad acceptance remain open.
