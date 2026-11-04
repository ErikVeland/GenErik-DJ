# Held performance gestures and full-height crossfader — R01/R02/R30

Date: 4 November 2026, Australia/Brisbane.

Waveform, EQ, filter and FX touches capture their window-space frame at touch-down. Panel resizing does not remap or cancel those contacts. New fingers use the current layout. The waveform retains its original source span. Each EQ finger retains its original fader inset.

Compact decks reject new contacts without closing existing FX/EQ input gates. Explicit panel close, track/mode changes, viewport rotation, app interruption and real view removal still use the existing cancellation paths. The native contact registry rejects stale and duplicate contacts.

The crossfader fills the complete gap from the bottom of A Play to the top of B FX. Its vertical padding is zero. The button anchors remain fixed. A/B markers sit inside their FX buttons to keep labels out of the track.

## Verification

`green.log` records 1,330 dock/workspace, 179 library and 36 held-contact assertions with zero failures. The contact check compiles production coordinate, EQ, filter and FX state. It covers stationary and moving fingers, separate frames for new contacts, partial release, cancellation, stale contacts, full collapse, cross-deck isolation, viewport changes and waveform span.

`fader-red.log` retains the 16 failing gap-fill assertions from the old floating fader. `contacts-red.log` retains the missing-interface baseline. `per-finger-red.log` retains three failures before per-finger mapping/inset handling. Temporary compiled mutations produce 10 failures for moving coordinates, one for a changing EQ inset, and two for an uncaptured waveform span. The production files were not mutated.

R34/R35 analysis/preparation sources and the original 99 Problems fixture are byte-identical to the baseline. No audio renderer, musical analysis or native transport code changed.

## Execution decisions

Pre-flight: Task 3 consumes Task 2's resizable library and Task 1's fixed dock. Layout uses contact permission separately from explicit panel presentation. This avoids treating a small waveform as a request to cancel held sound.

Task 3: Ruling: apply captured geometry to all four requested iPad surfaces in this single authorised release. The plan's separate opt-in releases are combined at Erik's explicit request. Cost if wrong: device feedback must isolate which surface still needs correction.

Task 3: Ruling: additional fingers capture current geometry while held fingers retain their own frames and EQ insets. This follows the design's rule for new contacts and avoids remapping an existing finger. A waveform gesture retains one source-span snapshot. Cost if wrong: an unusual overlapping-contact sequence needs a focused follow-up.

Task 3: Ruling: the requested crossfader span replaces the earlier centred 96-point track. Exact button boundaries define its height. Cost if wrong: Erik can correct the intended endpoints in the next iteration.

Final review: self-review under the project rule against parallel agents. Explicit cancellation, view identity, input gates, new-contact admission, per-finger state, action routing and source integrity were reviewed. Physical input and listening acceptance remain open.

## Erik's device check

Hold a waveform gesture while resizing the library or extra panel with another finger. Repeat with EQ, filter and FX on both decks. Confirm that stationary fingers retain their value, movement stays smooth and release behaves normally. Try a second finger, reverse release order, and full library expansion. Confirm that explicit close and rotation still clear temporary gestures. Listen for clean audio. Check that the crossfader spans the whole gap and reaches both ends.
