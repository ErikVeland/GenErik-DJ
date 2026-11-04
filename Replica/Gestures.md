# iPad performance gestures

Current build and acceptance: [project status](../docs/coordination/README.md). Historical measurements apply only to their recorded source.

## Implementation added 26 October 2026

The shared app now has functional performance workflows behind the touch controls. This remains a development reconstruction. It is not a verified 1:1 reproduction of Traktor DJ 1.6.8.

- A native iPad contact surface tracks finger identities, contact order, movement, release and cancellation. Each control owns its contacts. Removing the surface or changing its size cancels active touches.
- The waveform supports beat-tap jumps, paused seeking, temporary playing-deck manipulation and upward browsing. Grid dragging uses the same contact surface and preserves the original grid on cancellation.
- Two contacts define a loop. Translation moves it in beat steps. Pinching changes length in powers of two. LOOP toggles a default loop or exits the active loop.
- Stripe pinching changes scale without running its single-finger navigation path at the same time. Mac trackpad magnification remains available as a fallback.
- Eight per-track cue slots store positions or loop regions. Filled slots recall their contents. Delete mode removes a slot. `performance.json` retains cues, loop length, quantisation, Slicer Quantize and Freeze on Load.
- Freeze divides the visible region into eight playable slices. Holding a slice repeats it. A newer held contact takes priority. Releasing it retriggers the remaining contact's slice. Loop Slicer displays the active loop across the waveform.
- Flux retains a continuing source position during loops and temporary gestures. Release restores that position when the temporary operation owns the return.
- SuperSlicer now has three family selectors and three vertical action regions. Named turntablism and pitch regions follow primary 1.5 footage. Response laws and loop-stutter actions remain provisional. See the geometry correction below.
- Filter touch activates X cutoff and Y resonance. Release bypasses an unlocked filter. Lock retains it. Cancel bypasses it. Resonance persists through restart.
- EQ faders support independent contacts, centre reset and a second-contact temporary value. Three FX slots provide XY control, locks, tap/hold-drag selection and retained parameter values. Delay, Reverb, Flanger, Gater and Beatmasher 2 have independent DSP implementations.
- The gesture settings include a guide for the implemented controls. This is not the recovered Notification Centre or its original discovery/completion logic.

Looping, timed jumps, slice audition and Flux run on the audio renderer. UI refresh does not determine their execution frame. Commands use deck generations to reject stale actions. Keylock's input reader wraps its look-ahead inside the active loop or slice, including interpolation at the boundary. Reverse/rate gestures also wrap at that boundary. Delay continues through pause and is included in the master recording.

## Further source-backed corrections

The Quantize Size menu now uses the four documented choices: 1/4 Beat, 1/2 Beat, 1 Beat and 1 Bar, with a half-beat default (S21, later menu corroboration S30). Earlier development values Off, 2 and 8 migrate to the documented default without removing cues. This does not alter ordinary Play scheduling.

The FX drawer exposes three selector tabs and one shared XY pad, following the H5 launch-era reference. A pad gesture keeps its original slot until all contacts release. Tab changes during that gesture are deferred. Tapping an inactive tab selects it. Tapping the active tab opens its effect menu. Effect selection and buttons persist without requiring a later XY gesture. The temporary second-contact EQ value also restores when both contacts lift together.

A downward two-finger loop-dismissal route follows the historical S24 tutorial instruction. It commits after both contacts release; cancellation restores the prior loop. Thresholds and target-build equivalence remain unverified. `Validation/gesture-reference-workflow-tests.log` records five passing menu, EQ, pad-ownership, loop-release and cancellation checks. `gesture-reference-settings-tests.log` separately covers cue-preserving preference migration and FX persistence.

The [29 October primary-frame review](../Analysis/Traktor-DJ-1x/sources/loop-dismissal-primary-frames-2026-10-29/review.json) supports S24's downward motion but cannot settle contact count or release timing. Official S16 describes a two-finger tap and must not be cited as downward-swipe evidence. Neither demonstration establishes target 1.6.8 behavior. No gesture rule changed after this review.

## Validation

`Validation/gesture-performance-tests.log` records focused engine and workflow tests. They cover loop wrap, Flux continuation, timed jump boundaries, stale commands, invalid loop rejection, stopped audition, reverse, Stop cleanup, cue/settings persistence, loop/slice look-ahead isolation, effect tails, finite output, filter release/lock/restart, two-finger cancellation, overlapping slice holds and paused seeking.

The earlier combined regression suite passed 91 tests in `Validation/combined-final-tests.log`. Packaging and subsequent combined validation are coordinated with the main recreation chat. `Validation/gesture-ipad-compile.log` records an earlier SDK compilation. `Validation/gesture-preview.png` is an earlier rendered Mac layout, not an iPad runtime test.

## Remaining work before a 1:1 claim

The [gesture fidelity contract](../Analysis/Traktor-DJ-1x/17-gesture-fidelity.md) remains open. Original contact thresholds, zoom anchor and bounds, loop dismissal finger count, grid pinch/snap behavior, cue action edges, release ownership, slice scale, quantise menus, FX slot routing, locks, exact effect curves/sound, later DLC choices and original help behavior require reference comparisons. The implemented thresholds, eight visible slices, loop scale steps and temporary-contact priority are explicit development policies.

A second Play press cancels an incoming synced deck's pending start, as confirmed directly by the user on 28 October 2026. The playing deck's samples and musical clock remain unchanged in the native regression. Other queued-state mutations retain their unresolved-policy gates. Red Sync now performs the user-confirmed immediate smallest jump to the nearest beat, including backward correction. Its focused software checks pass; physical and original interaction-edge comparisons remain pending. Saved-loop recall schedules the jump and loop activation together using the selected quantum. Its exact original trigger policy remains unverified. The effects list now contains all eight base names and all three named 1.4 unlockables. Their independent DSP implementations still require original-app sound and parameter comparisons. Original loop movement, scratching and rate changes also need click/transition and pitch-quality comparisons.

Manual multitouch, original-app comparison, hardware routing and gig-length acceptance remain open. Automated physical GenErik diagnostics exist for older source fingerprints and do not close those gesture requirements. The parked gig iPad was not contacted. Functional code and regression tests do not close those gaps.

## Further implementation — 28 October 2026

Grid markers now have a distinct stored cue type and white display, as described in S1 §5.2.5. The first available slot is used for a newly prepared track; this allocation rule remains a development policy. Existing cues are preserved, full banks are not overwritten, and deleting a grid cue does not delete the beat grid or recreate the cue on reload. Legacy development preparations retain their cue contents. Cue, loop and grid positions appear on the detailed waveform with at most eight markers per deck.

The Notification Center now sits beside the decks rather than in a modal sheet. Eleven known S31 lesson topics are available. Original discovery and completion rules remain unverified. A held waveform contact cannot turn into an unrelated scrub when its mode changes. Effect-selector timing uses the monotonic clock and keeps its initiating contact through release or cancellation.

The shared effect catalog contains the eight documented base effects plus the three named 1.4 unlockables: Iceverb, Transpose Stretch and Reverse Grain. All eleven are available to each of the three slots. The algorithms are independently implemented; their mobile parameter curves and NI sound are not recovered. See [effect implementation and limits](Effects.md).

Original Z1 MODE+ON now changes each deck's filter/FX routing, ON toggles the selected effect, and its knob changes X while retaining Y. A vertical touch movement also preserves an X value changed by hardware. The most recently touched/selected bank is the development routing policy. Synthetic packet tests pass; native iPad accessory communication and physical-controller acceptance remain open. See [mixer notes](Mixer.md).

The flag button opens the eight-slot cue drawer, following H5. A separate return button recentres a playing-waveform preview without sending a seek command. An extra grid contact cancels an uncommitted grid shift. Freeze ignores slices outside the file, preserves a valid held slice when a newer contact lands on a blank slice, and never turns a blank slice release into a normal seek. `Validation/cue-preview-freeze-contact-tests.log` records three passing regression tests for these contact and playback behaviours.

## Grid-editor pinch zoom

Two contacts in the grid editor now change the waveform view scale through the deck's existing zoom state. Adding the second contact first cancels an uncommitted single-contact phase preview and restores its original viewport centre. Stationary additional contacts do not change scale, the stored grid or audio. The pinch retains its original contact identities and span across view redraws. Lifting one contact or adding a third ends ownership until every contact lifts. Cancellation and a track or mode change cannot turn the remaining contact into a phase edit, seek or audition.

The scale uses the stripe's existing development limits: one second through the track's duration, with the full duration as the lower bound for tracks shorter than one second. Horizontal contact separation controls scale around the existing viewport centre. Cancellation retains the last view scale. These bounds, anchor and contact policies are explicit development choices; exact 1.6.8 comparisons and magnetic snapping remain open. The route does not change BPM or grid spacing.

`Validation/grid-pinch-zoom-tests.log` records the focused stationary-contact, pinch ownership, cancellation, unchanged transport/grid and scale-bound checks. Native physical-iPad comparison remains outstanding.


## SuperSlicer geometry correction — 29 October 2026

The frozen waveform now has three family selectors in a left gutter: Loop Stutter, Turntablism and Pitch. The five-item mode menu is removed. NI's official 1.5 announcement shows this family structure. Its 21-second frame labels the turntablism regions Brake, Scratch and Reverse from top to bottom. Its 32-second frame labels the pitch regions Pitch Up, Slice and Pitch Down. The 48-second frame shows the loop-arrow family selected during the loop-stutter demonstration. Selected primary frames and source hashes are retained in [the primary review](../Analysis/Traktor-DJ-1x/sources/superslicer-primary-frames-2026-10-29/review.json). This establishes historical geometry, not complete target 1.6.8 parity.

The selector gutter sits outside the waveform contact surface. Waveform drawing and touch coordinates therefore share the same remaining width. The existing Canvas adds two horizontal dividers and the confirmed action labels. Each deck keeps its own family selection. Selecting another family cancels the current audition. A held contact must lift before it can start a gesture in the new family. Existing valid-contact priority, blank-slice handling, quantisation, cancellation and release routes remain in use.

Contact Y chooses the action. A move between regions also changes the action when horizontal slice selection stays fixed. The central Pitch Slice region sends one compound touch with native rate 1, so an earlier pitched or reversed rate cannot remain active. Scratch retains its existing direct-position route. Reverse retains rate -1. Brake retains the development law `max(0,1-y)`. Pitch Up and Pitch Down retain the corresponding portions of the development law `2^((0.5-y)*2)`. Here `y` is the full-surface coordinate. These are provisional responses, not recovered NI algorithms or curves. In particular, the top Brake region does not establish the original stopping response.

Loop Stutter uses a user-authorized educated guess: the top, middle and bottom rows repeat the full, half and quarter length of the playable slice. The labels are Slice, ½ Slice and ¼ Slice. Shorter rows change the repeat length without changing pitch. File bounds and a one-frame minimum remain hard limits. Moving within one row and slice does not retrigger; changing rows uses the existing compound touch and Slicer Quantize policy. These lengths are provisional and are not claimed as measured original behavior. The eight-slice scale, equal-third action hit boundaries, default Loop Stutter family, 44-point selector gutter, icon artwork, selection retention and contact-transition rules are reconstruction choices. Original unlock/default/persistence rules and exact target-build boundaries remain open. G20 therefore remains partial.

`Validation/superslicer-geometry-focused-tests.log` records nine passing focused tests, including three streamed cold-audition cancellation cases. New checks cover all named action regions, normal-rate restoration at fixed X, overlapping release, cancellation, family changes, deck isolation and blank contacts. Existing Freeze/two-finger-loop and grid-contact checks also pass. The offscreen previews in `Validation/SuperSlicerGeometry-2026-10-29-01` use the actual ReplicaView at 1024×768 and were visually inspected. They show geometry only. They are not physical iPad input, listening or original-app comparison evidence. Audio/core code is unchanged.

## Requested QoL controls — 30 October 2026

The shared wheel accepts a double tap to reset to the prepared source BPM of its selected sync reference. Selection currently uses the earliest-started playing synced deck, then paused/ready fallback, because there is no separate master-deck selector. Loop length now has per-deck saved sizes, direct selection and halve/double controls, including resizing an active loop. Delay exposes per-slot SYNC/FREE timing. These requested extensions are implemented; original gesture equivalence and current-device manual input acceptance remain open. See Playback.md and Effects.md.

## SuperSlicer Scratch and Brake correction — 2 November 2026, R22

Erik confirmed forward/back Scratch movement and a reachable Brake stop. This correction supersedes the fixed-rate Scratch route and Brake response described above.

Scratch anchors at the selected waveform position with rate zero. Horizontal movement sets speed and direction from source distance and elapsed time, limited to four times speed in either direction. Later updates preserve the native playback cursor. An unchanged horizontal position in a contact event sets rate zero. Missing events do not create a timed stop. A new contact owner or entry from another action starts at rest and resets the movement baseline. Release and cancellation use the existing transport and Flux routes.

Brake maps the top region from normal speed to zero. The bottom tenth of that region holds zero speed. This stop band, the linear curve and Scratch sensitivity are implementation choices for Erik to test. Pitch curves and Loop Stutter lengths retain their existing provisional policies. This change does not establish exact NI DSP equivalence.

Focused results, source identity, the signed build and deployment status are recorded against R22 and the numbered iPad build. Physical sound and gesture acceptance remain with Erik.
