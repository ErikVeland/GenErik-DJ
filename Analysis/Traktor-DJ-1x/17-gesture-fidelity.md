# Traktor DJ 1.x iPad gesture fidelity

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

The performer explicitly requires **all original iPad gestures to work 1:1**, including selection, gridding, zoom and two-dimensional filter control. This is a completion requirement, not an optional polish pass. [R5, 25 October 2026]

The target remains **1.6.8 / 1.6.8.67**. Historical sources establish capabilities within their recorded scope. They do not settle every target-build contact, release or timing rule. Source IDs resolve in [Sources and evidence](06-sources-and-evidence.md).

## Current result: incomplete

The 26 October implementation adds native contact tracking, cue slots, timed jumps, two-finger loop creation/movement/resize, Freeze and Loop Slicer, Flux, filter locks, touch faders and three FX slots. Ten focused engine/workflow tests pass. See [implementation and limits](../../Replica/Gestures.md). Original-app comparisons and physical iPad acceptance remain outstanding. Functional development workflows do not establish 1:1 fidelity.

The 28 October update restores the flag-opened cue drawer, three FX tabs sharing one XY pad, separate Equalizer/Filter tabs and vertical EQ/volume faders. All eight base and three named DLC effects have independent DSP implementations. Grid markers, preview return, contact-mode cancellation and blank Freeze regions have additional regression checks. Original Mac Z1 filter/FX routing has synthetic report tests. The machine-readable contract records these routes and supporting checks while retaining unverified fidelity status.

A button, menu, mouse interaction, keyboard shortcut or controller mapping does not replace the original iPad gesture. A two-dimensional filter must reproduce both cutoff and resonance, activation, release, lock and persistence, as well as their audible response. Similar appearance alone is insufficient.

## Gesture coverage and acceptance

The [machine-readable contract](contracts/gesture-fidelity.json) retains source IDs, inventory links, implementation gaps and reference trials for each row. `partial` means a development route exists, not verified fidelity. `unresolved` identifies missing reference rules, not permission to omit the behavior. This checklist supplements the full inventory and must expand when further original gestures are recovered.

| ID | Gesture family | Implementation | Required comparison |
| --- | --- | --- | --- |
| G01 | Browser access | partial | Swipe from original eligible regions; compare threshold, direction, cancellation and drawer animation. |
| G02 | Selection and directional loading | partial | Select without loading; drag each way; reverse, abandon and repeat; test stopped, playing and queued destinations. |
| G03 | Browser navigation and playlist selection | partial | Compare scrolling, selection retention, search, sort, edit ticks, playlist creation and dismissal without disturbing playback. |
| G04 | Artwork suggestions entry | partial | Tap each destination artwork while either or both decks play; compare context and return selection. |
| G05 | Tempo wheel | partial | Rotate through angle wrap in both directions; lift, recontact and use the other deck simultaneously. |
| G06 | Stripe inspection | partial | Move the window during playback, release, then dismiss; compare audible position and restored viewport. |
| G07 | Stripe pinch zoom | partial | Pinch and spread the red window; compare anchor, bounds, navigation side effects and scale after mode changes. |
| G08 | Beat-tap timed jump | partial | Inspect another region and tap a beat; compare acceptance, quantisation, audible jump and view follow. |
| G09 | Waveform scrub and paused seek | partial | Drag while playing and paused; compare source motion, sound, snap and release with Flux on/off. |
| G10 | Grid entry, phase and exit | partial | Enter grid edit, move waveform against grid, release and leave; compare phase, viewport, playback and saved state. |
| G11 | Downbeat and tempo correction | partial | Select each downbeat and correct tempo; compare bar origin, tap timing, precision and cue/loop effects after reload. |
| G12 | Grid pinch, snapping and four-beat inspection | partial | Establish presence and touch mapping on target build; distinguish viewport zoom from BPM/grid-spacing changes. |
| G13 | Hotcue create, recall, delete and stored loops | partial | Compare all slots, empty/occupied taps, deletion entry, cue types, quantisation, paused triggering and loop recall after reload. |
| G14 | Two-finger loop creation | partial | Touch two beat positions in both contact orders; compare endpoints, snapping, minimum separation and preset-loop interaction. |
| G15 | Two-finger loop movement | partial | Hold both fingers and translate forward/back; compare retained length, movement steps, sound and file boundaries. |
| G16 | Loop pinch resize | partial | Pinch/spread an active loop; compare discrete lengths, retained anchor and transition into translation. |
| G17 | Loop release and boundary behavior | unresolved | Resolve dismissal contacts and timing; compare exit with Flux on/off and loops near track boundaries. |
| G18 | Freeze and Loop Slicer | partial | Freeze while playing, tap/hold slices, vary zoom and move region; repeat inside a loop with each quantise setting and Freeze on Load. |
| G19 | Flux and overlapping releases | partial | Overlap scrub, cue, slice and loop holds; release in both orders and compare audible and continuing positions. |
| G20 | SuperSlicer modes | partial | Establish installed modes/unlock state; compare Scratch, Brake, Reverse, Slice and Pitch-shift zones, contacts and release. |
| G21 | EQ drawer, reset and multitouch | partial | Open original drawer; drag bands and volume independently, tap centres, and test second-finger temporary values/release against reference. |
| G22 | Two-dimensional filter | partial | Sweep X and Y separately/together; compare centre, edges, sound, initial contact, lift, bypass and restart. |
| G23 | Filter lock and hidden drawer | partial | Lock during a held gesture; lift, hide/reopen drawer, unlock and recontact; compare sound and retained coordinates. |
| G24 | FX drawer, selection, XY and locks | partial | Open drawer, tap effect, hold/drag selector down, shape XY, lock/release and hide; compare slots, tail and persisted Y. |
| G25 | Crossfader and headphone touch | partial | Move fader while touching EQ/filter on either deck; compare cue toggles, monitor blend and control ownership. |
| G26 | Hardware and touch coexistence | partial | Move Z1 filter X while touching Y; compare feedback, takeover, mode changes and retained Y. |
| G27 | Recording, settings and help routes | partial | Compare recording start/stop, saved-set selection/loading/export and gesture help entry/dismissal on target build. |
| G28 | Multitouch arbitration and interruption | partial | Exercise both decks and overlapping controls; add/remove contacts, leave bounds, cancel touches, interrupt app and rotate during a hold. Compare reference outcomes without stuck controls or unintended actions. |

## Input and state comparison protocol

For each trial, retain the reference build, hardware, track, grid, source position, playing/paused/queued state, Sync, Flux, loop/slice mode, zoom, settings, drawer state and existing contacts. Record finger identities and positions, contact order, movement, lift order and cancellation. Distinguish touch acceptance, visual feedback, scheduled execution and audible result.

Compare intermediate states as well as the final result. Include original hit regions, movement thresholds, axis curves, snapping, anchors, bounds, touch-down/up action edges and timing. Measure tolerances from the reference rather than inventing equivalence thresholds. Test both decks independently and together. Retain reference and replica video/audio and event traces where available.

Run each applicable trial while stopped, playing and awaiting a synced launch. Include recontact, extra fingers, reverse direction, out-of-bounds movement, interrupted touches, overlay transitions, rotation and restart. Investigate unsupported combinations against the original rather than assigning preferred behavior.

The EQ second-finger temporary-value technique is a research lead from period coverage, not a confirmed target-build rule. Grid pinch must be resolved separately from stripe zoom. Loop dismissal finger count remains unresolved in the recovered tutorial evidence. Do not silently promote these details to facts.

## Initial source-audit findings — 25 October 2026

These findings record the pre-implementation state. The updated machine-readable contract and implementation notes describe the changes made on 26 October.

- `ReplicaView.swift`, `ReplicaView`: a simultaneous upward drag on the deck stack can observe gestures from child surfaces. Check filter, grid, stripe and loop interactions before accepting browser gesture ownership.
- `ReplicaView.swift`, `StripeView`: navigation drag and magnification run simultaneously. Compare pinch anchoring and unintended viewport movement on iPad.
- `ReplicaView.swift`, `DeckView`: waveform drag only edits grids. There is no beat-tap jump, scrub, two-finger loop or Freeze handler. The mixer overlay adds a high-priority no-op drag whose runtime arbitration is unverified.
- `ReplicaView.swift`, `LoadSlider`: the 22-point release threshold is a development choice, not a recovered original measurement.
- `MixerView.swift`, `DeckMixerView`: X and Y update independently through the shared mixer. Release persists preferences, but the filter enable button does not implement original lock/release behavior. Generic EQ sliders and a Reset EQ button do not establish original centre-tap or multi-finger support.
- `ReplicaModel.swift`: filter Y is retained and persisted, but this does not prove original per-deck defaults, pickup, bypass or shutdown semantics.

These are source findings and runtime risks, not observed iPad failures. This pass made no speculative gesture-policy changes and did not operate a device.

## Completion gate

1. Resolve each original gesture's presence and version using evidence. Retain justified absence where applicable.
2. Implement the confirmed touch sequence and its sound, timing, feedback and state transitions.
3. Pass the same sequence on the replica on an authorised multitouch iPad, with reference results retained.
4. Pass overlap, cancellation and persistence checks. Desktop tests and simulator compilation are supporting checks only.
5. Keep the overall status incomplete while any required behavior is missing or unmatched.

The gig iPad remains untouched. This requirement does not authorise acquisition, deployment, jailbreak work or live trials on that device.

## Pending gesture evidence review — 28 October 2026

**Grid pinch:** H1 reproduces the publisher's 1.5 App Store notes, which explicitly add grid-editor pinch-to-zoom and magnetic snapping. Presence is therefore established for the 1.5 feature set. The notes support a view-zoom route, but do not specify its anchor, bounds, contact transitions or magnetic snap threshold. They do not document changing BPM by pinching. The grid editor now implements a view-only pinch route. It cancels draft phase preview on second contact and uses the existing stripe bounds as an explicit development policy. Original anchor, bounds and magnetic snapping remain unmatched. The user's target-app clarification is still pending. Source: [H1 and its quoted release notes](https://djworx.com/traktor-dj-1-5-superslicer-beyond/).

The grid-pinch implementation retains the stationary extra-contact regression. A second finger must cancel an uncommitted single-finger phase shift before starting zoom. Pinch tests must also cover staggered contact entry, lifting one finger, an extra third contact, cancellation, track/mode changes and resize. A view-only zoom must not write the beat grid, seek the audio or start an audition. Exact anchor and restoration behaviour still require the original comparison.

**Loop dismissal:** the [29 October primary-frame review](sources/loop-dismissal-primary-frames-2026-10-29/review.json) corrects the earlier grouping of S16 and S24. Official S16 narration describes a two-finger tap; its obscured contacts do not establish a downward swipe. Historical S24 shows downward hand motion and the loop indicator changing from green to gray after withdrawal, supporting that motion beyond its narration. Finger count, exact release sequence and recognition thresholds remain obscured. Screenshot compositor lag prevents frame-exact timing conclusions. Neither 2013 demonstration establishes 1.6.8 parity. Keep the current two-contact development route distinct from verified target behaviour; G17 remains open. Sources: [S16 official tutorial](https://www.youtube.com/watch?v=B_8eahCGr1k), [S24 original follow-up](https://www.youtube.com/watch?v=kc99WythujM).

**SuperSlicer:** direct review of NI's 1.5 announcement now confirms three stacked family selectors and three vertical action regions. The 21-second frame reads Brake, Scratch and Reverse from top to bottom; the 32-second frame reads Pitch Up, Slice and Pitch Down. The first selector's loop-stutter association follows the adjacent demonstration and remains a contextual inference. The [archived primary frames and hashes](sources/superslicer-primary-frames-2026-10-29/review.json) record the observations and resolution limits. Source: [NI's SuperSlicer announcement](https://www.youtube.com/watch?v=oRNAV-GlH18).

The 29 October reconstruction replaces the flat mode menu with that family/region structure. Nine focused software checks pass, including streamed cold-action cancellation, action changes at a fixed horizontal position, overlapping contacts and deck isolation. Two actual-view offscreen previews were inspected. Equal-third hit boundaries, icon spacing, the initial family and existing rate laws remain development choices. The user later authorised an educated guess for unresolved Loop Stutter lengths. The implemented development policy repeats the full, half or quarter playable slice in the top, middle or bottom region, with at least one frame and no pitch change. Twelve private offline checks passed before guarded integration, including clipped slices, row changes, cancellation, Flux and exact other-deck output. The repeat lengths remain provisional rather than verified original behavior. Original scratch/brake/pitch sound, release ownership, unlock/default/persistence rules and target 1.6.8 equivalence remain open; G20 stays partial. See [implementation and validation](../../Replica/Gestures.md).
