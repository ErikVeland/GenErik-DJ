# TDJ1 performer fidelity specification

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

## Analysis quality requirement — 29 October 2026

BPM, key, energy and automatic downbeat must match the consistently correct results the performer reports from TDJ1 before this reconstruction can be considered a contender for 1:1 fidelity. This is a core acceptance requirement. The current independent analysis prototype does not meet it. Manual grid correction and reasonable suggestions do not replace reliable automatic analysis. The [music analysis fidelity contract](18-music-analysis-fidelity.md) records the audit, executable benchmark and required real-music comparisons. Audio output and responsive musical control retain scheduling priority.

## Audio and performance priority — 28 October 2026

The combined audio output thread has first priority at all times. Performance controls must stay responsive while analysis, search, artwork, import and recording run. These background features must yield resources to playback. Descriptions below of recommendations as a central feature do not give recommendation work scheduling priority over audio.

Acceptance requires no audio defects under the combined workload on the agreed minimum iPad. Mac stress results and successful iPad builds remain development evidence. They do not complete target-device acceptance or authorise access to the parked gig iPad.

## Performer clarification — 25 October 2026

The performer now specifies the suggestion priority explicitly: **key, BPM range, energy, then whether the track has been paired with the reference before**. The confirmed BPM range is **±8%**. Energy should be **similar**, not progressively higher. These are ordered priorities, not additive weights. A lower-priority criterion must not outweigh a higher-priority match.

This instruction supersedes the earlier absence of a chosen ranking policy and the earlier assumption that genre needs an independent ranking weight. Retain genre metadata, but do not insert it ahead of or between the requested priorities. The implemented policy uses the current shared tempo for a playing synced reference and corrected source BPM otherwise. Previous pairing is treated as undirected.

Exact key outranks relative major/minor and adjacent fifths in the current implementation. Energy is an independent local estimate from loudness, brightness and onset activity, grouped into ten levels. These detail choices still need listening/reference validation. The user's priority order, ±8% range and similar-energy direction are confirmed requirements, not unknowns awaiting calibration.


**Reproduce TDJ1 as the performer knows it.** The next-track suggestion engine is a required performance feature. Combined audio output and responsive musical control take priority over its background work. Analysis and gridding supply the musical information that makes track choice, timed entry and direct waveform performance useful together.

The working reference is the original iPad app, installed version **1.6.8, build 1.6.8.67**. The performer has used TDJ1 for 13 years and explicitly reports observing its recommendation rankings adapt. That experience is reference evidence, alongside the existing app metadata, exports, NI documentation and historical demonstrations. [R2, R3, L1]

## Complete iPad gesture parity — 25 October 2026

All original iPad 1.x gestures are required 1:1, including selection/loading, gridding, zoom, two-dimensional filters, loops, slicing, FX and simultaneous control. Generic controls or controller equivalents do not complete touch support. The [gesture fidelity contract](17-gesture-fidelity.md) records the implementation gaps and required iPad comparisons. Gesture parity remains incomplete until these checks pass. [R5]

## Eight core performer requirements

The performer confirmed these priorities on 23 October 2026. They are required for the modern replica, alongside the full replication scope. [R4]

1. Song recommendations, including the reported adaptation to previous mixes.
2. Song analysis, including key and BPM.
3. Beatgrid correction.
4. Reliable sync to the shared master tempo.
5. Press Play ahead and enter in sync on the next beat, preferring a four-beat bar start where possible. On 25 October 2026 the performer confirms that pressing just after beat 2 should wait for the next bar. The current implementation prefers a bar the reference can reach and falls back to the next beat if the reference ends before it. The end-of-track fallback is an implementation interpretation of “where possible”, not an original-app measurement.
6. Z1 controller integration.
7. Integration with the performer's local/synced iTunes / Apple Music library on both Mac and iPad. Each device must use its own library through the same selection, preparation and deck-loading workflow. Subscription streaming is excluded.
8. Record sets as AIFF and transfer the recordings to a Mac.

Library integration must support choosing music from the performer's library for the analysis, recommendation and deck workflows. A standalone file-import command does not fulfil this requirement. The performer explicitly limits this requirement to local/synced music and excludes subscription streaming. Preserve access to available local audio, distinguish songs that need downloading or syncing, and retain source identities through preparation and restart.

On 24 October 2026, the performer explicitly confirms the same requirement for the iPad library. The iPad must read its own synced songs and playlists without requiring a running Mac or manual Files export. A successful Mac demonstration or iPad SDK compilation does not complete this requirement. Completion requires the same workflow to pass against a real iPad library on an authorised test device. This clarification does not resume access to the parked gig iPad. [R4]

Recording must capture the performed master mix as an AIFF file and provide a transfer route to the Mac. Acceptance includes opening the transferred file on the Mac and checking its format, duration and audio against the recorded set. Sample rate, bit depth and the preferred transfer route remain unspecified.

AIFF is an explicit requirement for the replica. The existing acquired exports are WAV files. That local evidence does not establish original AIFF support or remove the requested AIFF output requirement. [R4, L2]

## Fidelity rules

1. Preserve original behaviour, sound, timing, gestures, visual feedback, defaults, persistence and quirks.
2. Follow the confirmed suggestion order: key, BPM within ±8%, similar energy, then previous undirected pairing. This supersedes the earlier assumption of independent genre weighting; earlier reports below remain historical reference evidence.
3. Resolve missing details against the reference. An unresolved field stays unresolved until it can be matched.
4. Preserve version boundaries. Launch-era behaviour does not automatically describe installed 1.6.8.
5. Keep internal implementation choices separate from observable product behaviour. A different implementation must still reproduce the reference results.
6. Do not add modern recommendation services, new ranking controls, explanations, gestures, modes or workflow changes without a separate user request.
7. Do not silently repair an original quirk or replace an awkward interaction with a preferred design.
8. Existing **P** material in the research dossier is an engineering hypothesis or test proposal. It does not establish original behaviour or authorise a product change.
9. Retain ordinary DJ functions in the full replication scope. This document focuses on the specialised ways TDJ1 combines them for a performer.
10. Keep the gig iPad untouched. No acquisition, jailbreak, reset, import or live trial is authorised by this specification.

The [complete inventory](02-feature-and-interaction-inventory.md) remains the overall scope. The contracts below identify the performer-specific behaviours that must survive implementation. Their machine-readable form is [performer contracts](contracts/performer-fidelity.json).

## Next-track suggestions

The performer needs a useful next record from their own music, in the context of what is playing and how they have mixed before. Preserve the original route, candidate ordering and adaptation. A replica that only filters by BPM and key does not fulfil the reported TDJ1 experience. [R2]

| Contract | Feature to preserve | Performer value | Reference and exact boundary |
| --- | --- | --- | --- |
| PF001 | Open suggestions through the destination deck's artwork, with the correct musical reference and destination | Find the next record within the mixing flow | D S15, S1; source selection when both decks play remains to capture |
| PF002 | Suggest compatible tracks using tempo and key, with the original compatibility indicators | Judge an entry without manually comparing the whole collection | D S1, S15; ranking weights, limits and tie order remain to capture |
| PF003 | Preserve the timbre-based contribution advertised for the original recommendation engine | Retain its sensitivity to how tracks sound together | D S41, NI announcement; descriptors and contribution to ranking remain unknown |
| PF004 | Preserve genre's role in suggestions as reported by the performer | Keep the original sense of stylistic connection and possible transitions | R2; do not substitute a new genre classifier or invent a genre restriction |
| PF005 | Let previous mixes and track combinations affect suggestions, including the observed adaptive rankings | Carry the performer's accumulated mixing experience into the next choice | R2, explicit observed behaviour; learning method, update triggers and stored state remain to recover |
| PF006 | Reproduce the original suggestion ordering and response to reference track, musical data and history changes | Preserve the recommendations the performer expects, rather than a broadly similar list | D/R scope from S15 and R2; exact ranked outputs require reference examples |

The detailed [next-track suggestion contract](16-next-track-suggestion-fidelity.md) defines the input distinctions, observed-learning requirement and reference comparisons. It does not prescribe replacement scoring weights or a new learning algorithm.

## Analysis and gridding

Analysis supplies musical coordinates. Editing the grid corrects those coordinates at their source, so the performer can trust subsequent actions. These functions are part of the instrument, not a disposable preparation stage.

| Contract | Feature to preserve | Performer value | Reference and exact boundary |
| --- | --- | --- | --- |
| PF007 | Analyse the music collection in the background through the original workflow | Make the collection ready without preparing every track individually | D S11, S15; scheduling, progress and cache rules remain to capture |
| PF008 | Derive and retain the original waveform, source BPM, key, beatgrid and downbeat information | Supply the timing and harmonic information used across the app | D S11, S41; analysis algorithms and accuracy remain to match |
| PF009 | Correct grid phase by moving the waveform against the grid | Fix the rhythmic reference directly | D S11; sensitivity, precision and commit rules remain to capture |
| PF010 | Identify the correct first beat within the bar | Make bar-aligned operations refer to the intended downbeat | D S1; exact touch path and stored representation remain to capture |
| PF011 | Correct detected BPM with half, double and tap operations | Resolve common tempo interpretation errors in place | D S11; rounding, gesture timing and downstream effects remain to match |
| PF012 | Inspect the grid in four-beat increments through the documented controls | Check alignment across the track efficiently | D S11/S1; distinguish confirmed controller controls from unverified touch equivalents |
| PF013 | Create or adjust beatgrids while music continues | Prepare and repair without abandoning the performance flow | D S41 and grid tutorials; exact output response to each edit remains to match |
| PF014 | Preserve prepared grids, cues, loops, BPM and key through the original storage and version-specific exchange paths | Retain preparation work between sessions and supported devices | D/L S11, L2, H2/H7; historical Pro/Dropbox exchange and later iCloud behaviour are separate |

Genre metadata, timbre analysis and harmonic key are separate inputs. A genre label is not evidence of a timbre descriptor. A source BPM estimate is not the current master tempo. These distinctions must remain intact in implementation.

## Shared musical time and early commitment

| Contract | Feature to preserve | Performer value | Reference and exact boundary |
| --- | --- | --- | --- |
| PF015 | Tap master BPM and rotate the shared tempo wheel; synced decks follow the original tempo rules | Change the pace of the mix through one musical control | D S15, S1; range, resolution, acceleration and ownership rules remain to capture |
| PF016 | Distinguish matched tempo from matched phase, show half-sync and restore alignment through Sync | Recognise and correct timing displacement | D S1; R user 29 October: immediate smallest jump to the nearest beat, backward allowed. Colour threshold and interaction edges remain to match |
| PF017 | Accept an early ordinary Play request for the documented synced measure entry | Commit the incoming entry and move hands to other controls | R1, D S20; exact conditions, boundary origin and setting dependency remain open |
| PF018 | Show the original moving lead-in marker and green Play state before source-waveform scrolling | See that a launch is committed and approaching | D S35, S38; preserve the sequence without hard-coding a delay measured from a video |
| PF019 | Preserve the original Quantize Size choices and the separate Slicer Quantize setting | Keep the original timing controls and their distinct roles | D S21/S34/S1; per-command scope remains open, especially ordinary Play |
| PF020 | Reproduce what actually happens when a pending action receives another Play, cue, seek, load, Sync or tempo action | Make a correction using familiar behaviour | R3 fidelity requirement; cancellation and replacement rules remain unresolved, not selected by this document |

The [transport specification](03-transport-sync-and-queued-starts.md) separates source BPM, master tempo, phase, bar origin, quantised execution, snapping, Keylock and Flux. Those are implementation distinctions, not permission to expose extra controls.

## Direct navigation and loop performance

| Contract | Feature to preserve | Performer value | Reference and exact boundary |
| --- | --- | --- | --- |
| PF021 | Move the stripe's view window, inspect another region, zoom it and commit a timed jump through the documented beat tap | Look ahead before changing what is playing | D S15; preview, seek and cancellation must remain distinct |
| PF022 | Scrub the waveform by touch and reproduce its original release/return behaviour | Perform directly on the audio surface | D S16; motion response, Flux conditions and action edges remain to match |
| PF023 | Use two fingers to define the desired loop region | Capture the visible musical passage directly | D S16; finger order, snapping and endpoints remain to capture |
| PF024 | Hold and move a loop with two fingers | Reposition the repeated passage during performance | D S16; movement steps and audible transitions remain to match |
| PF025 | Hold and pinch a loop to change its length | Change repetition scale through a physical gesture | D S16; retained anchor and available lengths remain to match |
| PF026 | Store a loop in the cue system and recall its location and active loop state | Reuse a prepared performance passage immediately | D S11/S1; preserve the original eight-slot system, types and colours without inventing trigger rules |

## Freeze Loop Slicer Flux and SuperSlicer

| Contract | Feature to preserve | Performer value | Reference and exact boundary |
| --- | --- | --- | --- |
| PF027 | Freeze waveform scrolling while the track can continue playing and leave that visible region | Keep a useful passage under the fingers | D S16/S1; viewport and play position must remain separate |
| PF028 | Play the visible Freeze regions, with musical scale determined by zoom | Improvise with material that was not preassigned to cue slots | D S1/S16; exact touch slice count and trigger/release rules remain to match |
| PF029 | Enable Freeze within an active loop to enter Loop Slicer | Reshape a repeating passage through its visible regions | D S16/S18; retain the distinct mode and original exit behaviour |
| PF030 | Maintain the continuing song position during Flux operations and return according to the original rules | Temporarily alter the audible passage while preserving its continuing progression | D S5/S1; overlapping actions, release ownership and mode combinations remain to match |
| PF031 | Preserve Freeze on Load and its original conditions | Reproduce the original prepared performance state after loading | D control visible in S21; exact trigger and persistence remain open |
| PF032 | Preserve installed SuperSlicer modes and their response | Retain later 1.x Scratch, Brake, Reverse, Slice and Pitch-shift performance | D names S10; exact installed unlock, zones, rates, gestures and release map remain to capture |

## Touch effects and simultaneous control

| Contract | Feature to preserve | Performer value | Reference and exact boundary |
| --- | --- | --- | --- |
| PF033 | Control filter cutoff on X and resonance on Y through its XY surface | Shape two sound dimensions with one gesture | D S4/S1; curves, centre behaviour and pickup remain to match |
| PF034 | Open FX from its drawer and use its original selection gestures and XY mapping | Select and shape an effect within the deck workflow | D S16/S4/S1; per-effect parameter response and installed choices remain to match |
| PF035 | Lock the filter through the original control and reproduce the separate FX lock behaviour | Leave a chosen sound state active while moving a hand elsewhere | D filter lock S16; FX lock details remain open |
| PF036 | Retain the documented Y values through bypass and shutdown, and preserve original hidden-drawer behaviour | Return to the same sound state | D S4; track, slot, effect and deck persistence scopes remain to capture |
| PF037 | Use multitouch across the original EQ, filter and FX surfaces, including the original EQ reset | Work more than one musical adjustment at once | D S16; finger ownership, limits and overlapping gestures remain to match |
| PF038 | Continue the documented delay tail after stopping its source deck | Use the tail as part of the transition | D S16/S17; do not assume every effect or stopping action has the same rule |
| PF039 | Preserve documented controller-era simultaneous FX and stored FX-group gestures | Recall and perform the original effect combinations | D S1/S5; touch-only limits and installed version scope remain to capture |

## Supporting performer workflows

| Contract | Feature to preserve | Performer value | Reference and exact boundary |
| --- | --- | --- | --- |
| PF040 | Swipe into browsing and use the contextual up-for-A/down-for-B load slider | Place the chosen record on the intended deck through the original gesture | D S15; release, cancellation and playing-deck protection remain to capture |
| PF041 | Surface feature-aware instructions through the original Notification Centre | Learn an unused performance gesture within the instrument | D S15/S31/S41; preserve actual messages and completion triggers |
| PF042 | Load a saved recording into a deck through the original recording workflow | Revisit the performed mix using the deck | D S34; exact installed route and any separate preview behaviour remain to capture |
| PF043 | Let supported hardware and touch cooperate on the same parameters, including Z1 X control with touch Y control | Combine physical controls with the original touch surface | D S3/S4/S1; exact feedback, takeover and mapping remain to match |

Library integration and AIFF recording with transfer to Mac are now explicit core performer requirements. Recording, headphone monitoring, basic transport and the remaining ordinary functions also stay in the full inventory. Preserve the original behaviour where established, and distinguish the requested AIFF output from the locally observed WAV exports. [R4, L2]

## Conditions for claiming fidelity

For each contract, retain the reference build, initial state, action sequence and visible/audible result. Compare the replica against that same sequence. Preserve track identity, library analysis, settings, hardware and performance history when they can affect the result.

For suggestions, retain the ranked candidate identities and compatibility feedback, not just a statement that the suggestions seemed sensible. For grids, retain the corrected positions and the actions that consume them. For sound, retain reference audio and its output path. For touch, distinguish contact, visible feedback, command acceptance and musical execution.

An unresolved contract cannot be closed by choosing a plausible policy. A prototype that mixes tracks or produces reasonable recommendations does not satisfy the request to reproduce everything as it is.
