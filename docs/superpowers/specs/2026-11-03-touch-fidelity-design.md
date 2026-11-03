# TDJ1 gestures and a unified touch space

Date: 3 November 2026, Australia/Brisbane.

Status: proposed design for Erik's requested plan. No product implementation or device operation is part of this planning change.

Requests: R02 and R30 lead. R01/R03/R04/R13/R22/R25/R27/R31/R32 support acceptance. R20 remains the final rehearsal gate.

## Intent

Make GenErik DJ feel like one instrument under the fingers. Preserve TDJ1's musical gestures. Let Erik reveal, hide and resize panels directly without losing essential controls or interrupting audio.

Two outcomes remain separate. TDJ1 fidelity requires comparison with the original. Flexible panel resizing is a QoL extension and must be labelled as such.

## Starting evidence

- The initial planning base was integration commit `513453461`, included in main merge `5409bba59`. R34 landed during planning through source `629365b4b` and handover `9602dcc20`.
- Build 77 is now recorded as installed on the 10.5-inch test iPad. Automatic launch timed out, so launch and Erik's acceptance remain unconfirmed.
- Build 70 remains the latest confirmed Duo installation in the reviewed records. Builds 73 and 75 were prepared but not confirmed installed there. Track these devices separately.
- This planning change edits documentation only. Preserve R34's analysis fix and any ongoing test edits. Confirm the actual launch/build on the intended device before choosing the touch baseline.
- All 28 gesture families in the retained fidelity checklist remain partial or unresolved. Existing software tests do not close those comparisons.
- The current library divider resizes continuously. FX/EQ overlays use fixed half-widths. Extra controls use a visibility switch. Section editing opens a sheet.
- Current native surfaces cancel touches when their size changes. This protects against stuck actions but prevents seamless resizing during a held performance gesture.

Read the [gesture contract](../../../Analysis/Traktor-DJ-1x/17-gesture-fidelity.md), [request ledger](../../coordination/requests.md), and [iPad loop](../../testing/README.md) before execution.

## Requirements supplied by Erik

1. Prioritise TDJ1 gesture fidelity.
2. Use one touch space with direct panel reveal, hiding and resizing.
3. Keep the right-hand FX/EQ/loop/Play stacks and centre crossfader stable.
4. Preserve clean continuous audio and immediate performance control.
5. Keep the existing one-change, one-build, install, hand-back loop. Erik is the acceptance tester.

## Proposed design decisions

These are builder recommendations for review, not claims about original TDJ1 behaviour.

### Stable performance dock

Reserve a right-hand dock outside the resizable work area. Keep deck A's four-button stack above the centre crossfader and deck B's stack below it. Keep explicit A/B labels. Panel motion must never cover or intercept this dock.

For a fixed window and orientation, dock control centres must remain within one point of their original positions through library and panel changes. Essential targets are at least 44 by 44 points. Use 48-point button heights where the accepted device geometry permits them.

Remove the current vertical-to-horizontal rail switch during library resizing. Reduce optional content before reducing essential targets. If a viewport cannot fit the dock, record that geometry as unsupported by this two-deck layout. R28's separate one-deck phone design owns that case. Do not rotate the controls or shrink targets silently.

Only the work area beside the dock changes when the library opens. This is a deliberate spatial change from the current layout. Verify deck-to-control association on Duo before continuing.

Give the A and B work regions their own shared divider within that work area. Erik can give one waveform more space without moving the dock. Each compact deck retains an A/B label, overview and expansion route. Keep this divider distinct from musical waveform input.

### One panel behaviour

Use a shared extent model for the library, browser side columns, FX, EQ/filter and extra controls. Keep each panel attached to its existing edge. Do not introduce floating windows or free dragging across decks.

| Operation | Proposed behaviour |
| --- | --- |
| Reveal | Pull the panel's edge or use its existing button. A hidden panel retains an accessible reveal tab. |
| Resize | Drag its grab edge. The boundary follows the finger at one point per point of travel. |
| Settle | Keep any usable size chosen by a slow drag. Snap only out of an unusably small extent or after a deliberate flick. |
| Hide | Push the grab edge to closed, flick closed, or use the same toggle button. |
| Restore | Reopen to the last usable size for that panel and orientation. |
| Cancel | Restore the extent from gesture start without changing musical state. |
| Add track | Maximise library space on every explicit A/B add-track request, including when the library is already open. |

Provide a 44-point hit area around a narrow visible grab edge. That hit area belongs to a dedicated boundary lane. It must not overlay an active waveform, XY pad, fader, loader or transport target.

Initial development values: 200-point minimum expanded side-panel width and 128-by-128-point minimum XY pad. Use a 132-point minimum expanded library height. These are usable-size candidates, not NI measurements. Test them at actual device sizes. If space is insufficient, retain a compact reveal tab and hide the interactive contents rather than scaling them below their target sizes.

For extent release, retain the exact extent at or above its minimum. Below the minimum, close below half the minimum and otherwise expand to the minimum. A flick requires at least 12 points of travel and 600 points/second. Opening flicks restore the remembered usable size. Closing flicks close. Clamp every result to the actual available space. These shared defaults can change through Erik's feedback.

FX and EQ may be open together. Clamp their combined widths so they cannot overlap each other or the dock. Close one panel without moving the other. Preserve waveform and overview identity behind the panels. A small waveform may become a non-interactive compact strip with a clear expansion route.

Remember extents per panel and orientation for the current session. On ordinary relaunch, a safe usable default is sufficient for this phase. Do not change preparation storage to persist workspace geometry.

### Musical contact ownership

A contact owns its original surface until release or explicit cancellation. Crossing a panel boundary cannot turn a filter movement into a resize, a resize into a scratch, or a loop into browsing. Extra fingers and contact order must not transfer ownership accidentally.

Panel geometry may change while another surface is held. Capture a performance contact's window-space origin and mapping at touch-down. A stationary finger must retain its musical value through that change. Preserve the active waveform span and reference position for the gesture. New contacts use the new geometry.

Implement this mapping as an opt-in policy first. Keep current cancellation as the default for unmigrated surfaces. Prove waveform, EQ, filter and FX independently before removing their resize cancellation. Rotation, app interruption, track replacement and actual surface removal still use explicit cancellation and require fresh contact.

Closing a panel releases its temporary gestures through the existing musical cancellation route. It must not disable unrelated latched effects or alter another deck. Match the original's locked-filter/FX hide behaviour through paired evidence before claiming G23/G24 closed.

Never make audio timing depend on panel animation. Do not add analysis, file work, allocation or UI state to the audio callback for layout changes.

### Performance editing in place

Keep grid and cue editing within the deck workflow. Replace the section-editor sheet with a docked editor in the work area, retaining the dock and the other deck's transport access. Preserve track identity, preview/return state, zoom and manual preparation when opening or closing it.

System file pickers, sharing, permissions and infrequent configuration can retain system presentation. They do not need to become performance panels. Do not rebuild all settings to satisfy this project.

## Fidelity rules

For each gesture family, retain the original version, initial state, contact sequence, intermediate visual state, audible result, release/cancellation, persistence and supporting evidence. Test both decks and the relevant playing, paused and queued states.

Classify each result as matched, intentionally different with Erik's agreement, or unresolved. A deliberate QoL difference is not a 1:1 match. Keep unknown thresholds and curves visible rather than guessing and closing the row.

Use existing footage and Erik's demonstrations first. Missing original evidence blocks the fidelity claim, not all unrelated implementation. Do not operate the original app or the parked gig iPad without authorisation.

## Acceptance boundaries

Touch-space acceptance requires stable essential controls, consistent direct panel manipulation, retained musical state, usable targets, cross-deck multitouch and clean audio on the intended device. Test portrait, landscape, panel combinations, reduced motion, interruption and relaunch.

TDJ1 gesture acceptance additionally requires all required G01–G28 comparisons to close, with explicit dispositions for any agreed differences. The final physical session must use the exact combined source being accepted.

Neither boundary closes analysis quality, sound equivalence, controller compatibility, recording recovery or gig readiness automatically. Those retain their own ledger and release gates.

## Scope after touch work

Resolve real-track BPM/key/downbeat/energy and semantic-label failures next, including R29/R33/R34. Then verify recorded audio and transfer, reverb/effect sound, Z1 hardware, external metadata adapters and rehearsal. Stems and wider controller coverage follow their own contracts. Streaming remains deferred.

Audible faults, unintended transport, lost preparation and inaccessible essential controls can interrupt this order immediately. New controller profiles and cosmetic expansion do not displace the touch programme by default.
