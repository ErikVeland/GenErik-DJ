# Traktor DJ 1.x user journeys and acceptance criteria

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

The [performer fidelity specification](15-performer-fidelity-specification.md) governs these journeys. Preserve original outcomes and quirks. Proposed acceptance requirements do not authorise product changes. The performer's observed adaptive suggestions are required reference behaviour [R2/R3]; their focused journey and comparisons are in [next-track suggestion fidelity](16-next-track-suggestion-fidelity.md).

These journeys define the experience to reconstruct. A documented capability does not establish every touch gesture. **D**, **L**, **R**, **P**, and **V** follow the [evidence key](README.md). Where a path is uncertain, capture the actual path before treating these as reference-app instructions.

The checks below are proposed acceptance criteria unless an explicit source or user requirement supplies the outcome. Complete the relevant capture record with screen state, inputs, sound, timing and persisted state.

## Prepare music and a set

### J01 First launch and local music

Start with a fresh test installation on a separate device when available. Allow or deny music access, inspect the library state, then follow the available recovery path.

Acceptance: the user can understand how to make music available. A denied permission must have a usable recovery path in the rebuild. Capture prompts, tutorial entry, initial preferences, and analysis behaviour. Do not use the gig device for a fresh-install test. F008, F013, F131–F136. **V/P**.

### J02 Find a known track

Swipe upward to open the browser. Navigate a category, search for a track or artist, or sort by a documented field. Return to the previous category.

Acceptance: selection, scroll position, keyboard dismissal and back navigation follow a consistent path. Playing audio continues. Capture unavailable-item states. Categories, search, sorting, list drag and fast-scroll handle are **D S15 0:21–1:19**. Detailed response rules remain **V**. F001, F004, F009.

### J03 Load the first deck

Touch a track and move its load slider upward for A. Inspect the deck and press Play. Collection analysis runs in the background.

Acceptance: the correct file and preparation data load. Capture initial position, tempo, Sync/Keylock, progress and first audible event. The touch load gesture is **D S15 1:21–1:31**. Controller loading returns to deck view in S1. Remaining initial-state rules are **V**. F002–F003, F013, F016, F032.

### J04 Choose the next track from recommendations

Tap the destination deck's artwork to open recommendations. Inspect the green key/tempo compatibility indicators. Load a candidate through the directional slider.

Acceptance: preserve the demonstrated entry, ordered candidates, compatibility feedback and reported adaptation to previous mixes. Match concrete examples from the performer's experience. Compare context changes, back navigation and any effect of a changed master tempo. F005–F006, F144–F146. Touch path and key/BPM basis **D S15 1:34–2:04**. Timbre is a declared input **D S41**. Genre/history contributions and observed adaptive rankings are **R2**. Exact scoring, learning events and retained state remain **V**. Use REC01–REC10 in the [suggestion fidelity contract](16-next-track-suggestion-fidelity.md).

### J05 Build a performance playlist

Choose Edit in the browser track list. Tick tracks and choose Add to Playlist. Select an existing playlist or create one. Inspect naming, reorder and removal separately.

Acceptance: preserve batch addition and playlist choice. Capture naming, duplicates, removal, ordering, save/cancel and persistence. F010–F012. Creation/addition route **D S15 2:51–3:18**, other operations **V**.

### J06 Correct a wrong beatgrid

Load a track with a known grid error. Open grid editing. Adjust phase and downbeat. Inspect a later section before leaving the editor.

Acceptance: distinguish phase offset from incorrect BPM. NI directly describes moving the waveform, BPM half/double/tap, and four-beat inspection. Capture precision, commit rules, snapping and cue consequences. F044–F050. **D S11 1:15–1:51**, remaining response rules **V**.

### J07 Prepare cue points

Locate a musically useful point. Open the eight-slot cue drawer and tap an available slot. Recall it, inspect deletion, then reload the track.

Acceptance: preserve source location, slot identity and persisted state. Capture deletion, stopped recall and quantised wait. F053–F060, F069. Eight slots and tap-to-set **D S11 2:01–2:16**, other touch details **V**.

### J08 Save an intro or outro loop

Choose a useful loop. Store it in a cue slot. Leave the track, reload it, and recall the saved loop.

Acceptance: recover both start and loop extent, with the reference activation/exit behaviour. Capture whether changing loop size later changes the saved loop. F056, F061, F069. **D S1 §5.2.6**, persistence details **V**.

## Mix and control timing

### J09 Make the basic two-track transition

Play A. Keep B out of the master mix. Load and position B, enable the required Sync state, start B and bring it into the mix.

Acceptance: preserve the intended tempo, beat alignment and audible mix. Capture load protection, channel levels, crossfader movement, meter states and return to browsing. F002, F016, F023–F026, F085–F086. **D S1/S5**.

### J10 Press Play early for the next bar

Play A with an established bar phase. Cue B at its intended start. Select the relevant quantisation and press Play before the next bar. Move to EQ while B waits.

Acceptance: reproduce the user's early commitment and next-bar entry. Record pending indication, waiting position/silence, action edge and first audible sample. Run T01–T04. F027–F031. **R R1; D historical explanation S20**. Exact conditional rules remain **V**. Do not assume the quantise preference governs Play.

The S35 frame review adds historical visual feedback: a moving lead-in marker precedes source-waveform scrolling while Play is green. Include **F143** in this journey. Measure that display transition separately from first audio and command acceptance.

S38 independently shows this sequence in the [Hollin frame review](14-hollin-jones-count-in-frame-review.md). Its orange indicator appears after Play has changed colour. Calibrate such indicators before using them to time contact or release. No second-press policy is established.

### J11 Correct a queued launch before it fires

Queue B. Try the ordinary correction action, including a second Play press where appropriate. Repeat with a different cue, a seek and a track change.

Acceptance: capture which action cancels, replaces or leaves the launch intact. The rebuild must not let stale commands start an old track. Run T05–T07 and T10. F031, F139. **V/P**.

### J12 Change master tempo during a transition

Play both decks in Sync. Tap master BPM and turn the tempo wheel. Repeat with B queued and then with B unsynced.

Acceptance: preserve the documented wheel entry and smooth adjustment. Establish control scope, clock continuity, Keylock pitch, any ramp and queued launch boundary. Run T08. F017–F022, F034. Touch control **D S15 2:08–2:19**, complete clock rules **V**.

### J13 Stop and restart the last deck

Stop the only playing deck. Wait for a non-integer number of bars. Restart it or start the other deck.

Acceptance: determine whether clock phase continues, resets or is adopted from the new deck. Repeat while another command waits. Run T09/T15. F032–F033. **V**.

### J14 Recover from half-sync

Use a supported controller to create the documented out-of-time scratch condition without Flux. Inspect Sync, then press Sync again.

Acceptance: capture red app Sync and flashing controller Sync, followed by the documented realignment. Measure jump direction and timing. Run T12. F025–F026. **D S1 §5.2.3**.

### J15 Mix by ear using the controller

Disable Sync and Keylock. Set track speed with the tempo fader. Use jog pitch bend to align the incoming track, then blend it in.

Acceptance: the controller supports the documented classic workflow. Capture independent versus global tempo behaviour and the effect of re-enabling either switch. F020–F024, F034–F035. **D S1/S5**, exact response **V**.

### J16 Preview another part of the playing track

Drag the red stripe window while audio plays. Release it, then tap the desired beat in the detailed waveform. Inspect cancellation separately.

Acceptance: preserve preview versus commit. The touch drag/release/beat-tap route is **D S15 2:19–2:36**. On S4, SHIFT+jog chooses a destination and CUE commits. Exact quantisation and touch cancellation remain **V**. F040–F043.

## Perform with loops cues and slices

### J17 Loop and change length

Touch a loop region with two fingers. Hold and move it with two fingers, then pinch to resize. Inspect the exit gesture separately.

Acceptance: preserve creation, movement and resizing. Capture anchor, snapping, lengths, boundaries and exit timing. A pinch on the stripe zooms, while a pinch on a held loop resizes it. F061–F068. Touch gestures **D S15/S16**, exact loop-dismissal finger count remains **V**.

### J18 Rearrange a track with Hotcues

While a track plays, trigger prepared cues at early and late offsets. Repeat at each quantise setting and with Sync off.

Acceptance: map source destination and execution timing separately. Capture repeated taps, holds, cue on an offbeat, and whether paused recall starts playback. F027–F028, F053–F060. Capability **D S1**, timing details **V**.

### J19 Use a temporary action with Flux

Enable Flux. Perform a cue, scratch or loop action for several bars, then release. Repeat while changing tempo.

Acceptance: return to the continuing song position described by NI. Capture which control ends the temporary action and what happens with overlapping actions. Run T13–T14. F078–F080. **D S5**, overlapping rules **V**.

### J20 Play a frozen waveform

Tap the snowflake to freeze a region while audio continues. Trigger slices, change scale and move assignments. Tap the snowflake again to leave.

Acceptance: preserve the held display versus continuing audio and zoom-dependent scale. Entry/exit are **D S16 0:49–1:11**. Exact slice trigger, release and re-entry rules remain **V**. F071–F075.

### J21 Play slices within a loop

Activate a loop, then enable Freeze. Tap or hold loop slices. Change loop length or move assignments. Toggle Freeze to leave slicing.

Acceptance: preserve the loop constraint and distinguish slicing exit from loop exit. F076–F077. Touch route **D S16 1:31–1:51**. S18 documents eight controller parts on S4, four on S2, and default Flux in that demonstration. Detailed returns remain **V**.

### J22 Perform with SuperSlicer

Open SuperSlicer if it is already unlocked on the reference. Inspect each mode and action zone. Perform short, long and overlapping gestures, then release.

Acceptance: inventory the exact Scratch, Brake, Reverse, Slice and Pitch-shift mappings. Capture each source and continuing playhead, resulting sound and recovery. Do not buy or restore anything on the gig device during current research. F081–F084. Capability names **D S10**, gestures **V**.

## Shape sound and monitor

### J23 Blend with EQ and the filter

Open the deck's EQ drawer from the right. Change EQ and tap its centre to reset. Open Filter, adjust X/Y and inspect its lock control.

Acceptance: preserve centre reset and the documented filter lock. Capture ranges, hit areas, retained state and badges. F086–F094, F100/F104. **D S16 3:11–4:01, S4**, exact response **V**.

### J24 Apply and latch an effect

Tap FX to open its drawer from the left. Tap a displayed effect, or hold and drag its selector downward for more choices. Inspect pad, lock and bypass behaviour separately.

Acceptance: preserve the selector gesture and record pad, lock, bypass and tail states. Filter locking is demonstrated, but it does not establish identical FX-lock semantics. The demonstrated delay survives deck Stop. F095–F100, F104–F105. **D S16/S17 and S4**, other latch/tail rules **V**.

### J25 Combine and recall controller effects

Connect a supported S2/S4 in the later reference session. Select three effects in the app. Enable and adjust them, save the group and recall it.

Acceptance: reproduce simultaneous FX, shared dry/wet control and the single saved-group limitation from S1. Capture processing order and whether touch can perform the same combination. F101–F102. **D S1 §5.3**.

### J26 Cue privately while the room hears the other deck

Use a compatible multichannel interface. Route Master and Monitor to different stereo pairs. Select B for cueing while A remains audible in the master.

Acceptance: headphone selection must not leak B into the room. Exercise cue/master mix and levels at both endpoints. Capture first-connection guidance and route persistence. F106–F109, F111–F112. **D S6**.

### J27 Use a split-output cable

On a suitable test setup, inspect split output and connect its intended outputs. Isolate left and right source signals to identify downmix and routing.

Acceptance: establish the original mono/stereo trade-off, channel mapping and available swaps. Avoid deriving an iPad menu from NI's desktop cable instructions. F110. **V**.

### J28 Combine Z1 knobs with touch

Change EQ/volume through Z1. Use MODE+ON for Filter/FX, and touch the pad's Y control. Use MODE+CUE for deck transport.

Acceptance: preserve app/hardware feedback and independent X/Y control. Verify whether the transport combo changes headphone cue selection. Capture retained Y after bypass and an ordinary app relaunch. F094, F099, F113–F115, F117. **D S3/S4**, conflict rules **V**.

## Record preserve and recover

### J29 Record and keep a mix

Start recording, perform a short transition and stop. Locate the recording and tracklist. Copy exports to a new research folder in a later authorised session.

Acceptance: audio finalises correctly and paired metadata remains associated. Compare format, naming, timestamps, repeated entries and recording tap point. Existing files prove WAV/XML exports, not the full UI path. F121–F125. **L L2**, UI **V**.

Replay branch: select a saved recording, load it into a deck, then start playback. This capability has historical support in S34's captions and selected recording frames. **D F124**, exact installed touch path, scrubbing and monitor routing **V**.

### J30 Recover the played-track history

Inspect history after a test set with a brief play, repeated track, cued-only track, both decks audible and a reload without playback.

Acceptance: establish session boundary, ordering, duration threshold and duplicate rules. Do not assume recording XML and history use identical thresholds. F123, F127. **V H1**.

### J31 Share a recording

Inspect available export/share targets. Exercise local export on a test setup. Inspect the historical Mixcloud flow only as far as needed to identify its states.

Acceptance: a failed upload must not lose the local recording in the rebuild. Capture metadata selection, progress, cancellation and retry. Do not upload publicly or authenticate a new service as part of this research. F125–F126. Historical Mixcloud **D S13/S14**, current availability **V**.

### J32 Preserve preparation across devices

Inspect the reference's cloud settings and any existing copied cloud metadata. On separate test devices later, prepare one track, allow synchronisation and verify it on the second device.

Acceptance: identify which grid/cue/BPM/key fields move, which files do not, and how conflicts or missing audio are resolved. Keep iCloud distinct from historical Dropbox/Pro exchange. F128–F130. **V H2/H7**.

### J33 Resume after backgrounding or interruption

On a test session, switch away from the app, lock/unlock the screen and return. Separately exercise an audio interruption and an ordinary relaunch.

Acceptance: record audio, clock, queued actions, recording state and restored UI. An OS-specific observation must retain its OS and app versions. F133–F134. **V/P**.

### J34 Recover from a disconnected interface

Use a controlled test output. Disconnect and reconnect the interface while idle, then while playing and recording in separate trials.

Acceptance: record whether audio pauses, routes elsewhere, resumes, or requires action. Capture cue isolation, clock continuity and file finalisation. F120, F137. **V/P**.

### J35 Correct a live mistake

Attempt an accidental load, an unwanted cue jump, a wrong loop, and an effect left active. Use the ordinary recovery path for each.

Acceptance: document protection, reversibility, visible state and the fastest route back to an intentional performance. Keep confirmed protections separate from proposed improvements. F007, F031, F055, F067, F100, F104. **D partial/V/P**.

### J36 Perform a representative complete set

Use the user's normal set length and workflow after the reference is available for testing. Include repeated browse/load cycles, several tempo changes, private cueing, loops, effects and recording.

Acceptance: every shorter journey remains usable together. Record glitches, drift, thermal state, storage growth, unexpected UI changes and recovery actions. Do not claim a duration or stability result before this trial exists. F130, F139–F140. **P**.

## Journey record fields

For each captured journey, retain:

```text
Journey ID
App version and build
Device and OS
Controller model, firmware, cable and power
Audio route, sample rate and measured output latency
Track IDs and source hashes
Initial preferences, tempo, Sync, Keylock, Flux and quantise
Exact touch or hardware inputs with timestamps
Visible states before, during and after each input
Master and monitor audio captures
Resulting source, audible and continuing positions where observable
Persistent state after unload or relaunch
Source of expected result
Pass, fail or unresolved with evidence links
```

A journey passes only when its measured sound, state transitions and persistence agree with the expected behaviour. A similar screenshot alone is insufficient for transport, monitoring or recording fidelity.
