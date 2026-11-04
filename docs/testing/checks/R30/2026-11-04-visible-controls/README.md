# R02/R30 visible controls and useful deck space

Feedback assumes iPad build 107, the last recorded installation. Erik reports that Controls shows nothing, Flux remains hard to find, blank space remains below artwork and between the right-hand controls, and a line crosses the empty-track label.

## Findings

The extra panel started closed. Its controls used icon-only Freeze and Hotcue buttons inside a lazy grid. Its content kept its minimum height, leaving unused space below. The deck reserved 52 points beneath the cover through its whole height. The right-hand crossfader occupied the gap between the fixed button stacks but drew a narrow dark track. The empty waveform deliberately drew a centre line behind its label.

The mounted host baseline displays the old controls after opening. It does not reproduce the reported physical iPad blank panel. ImageRenderer alone omits the scroll content, so the visible-control checks use a mounted NSHostingView. Device acceptance remains required.

## Change

Loading a track opens the extra controls. The header entry says Flux / Cues. Eager rows show labelled Freeze, Cues and Flux buttons. Flux is always available. Buttons fill the panel height, with scrolling when the deck is too short. Optional Cue, headphone and Return controls retain room.

The expanded waveform, overview and section strip use the width below the cover. Compact decks keep a cover lane to avoid covering their controls. The fixed right-hand buttons and crossfader mapping retain their geometry. A wider outlined travel lane with A/B marks makes the crossfader visible. Empty waveforms have a black background with no centre line.

## Focused checks

The initial geometry check fails on hidden initial controls and the reserved artwork column. The initial rendered check fails on hidden initial controls, missing Freeze/Cues text, unused panel height and the empty background.

Mounted renders at 180 and 344 points check Flux, Freeze and Cues with text recognition. Pixel checks cover the lower control area and the black empty state. Saved before/after images support visual inspection. A fixed-dock image supports crossfader review. Geometry checks cover panel resizing, cancellation, held input gates and the existing dock/fader anchors.

No simulator build, Mac app package, full regression run or additional agent is part of this iteration. Compilation, source identity, framework resolution and signing support the iPad installation. Erik checks actual button access, panel gestures, crossfader feel, empty appearance and clean audio.

All 2,785 geometry assertions pass: 23 access, 1,432 panel and 1,330 dock/workspace checks. The final mounted render check passes at both heights in 3.551 seconds. The final dock image was inspected.

Build 108 from merged main source `d7a84fc59` passed compilation, source identity, framework resolution and signing checks. It installed on the test iPad, and iPadOS accepted launch. Device actions stopped. Physical acceptance remains open.
