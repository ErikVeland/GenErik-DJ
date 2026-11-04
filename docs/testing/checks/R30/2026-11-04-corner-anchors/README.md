# R02/R30 fixed deck corners

Feedback assumes iPad build 108. Erik specifies the artwork/load controller at the top left, current time at the bottom left and time left at the bottom right. Controls and information must give the waveform as much room as possible.

The deck now has a full-width header, a waveform/control area and a full-width bottom band. Artwork no longer moves down when the deck shrinks. Track information and section, Sync, grid and Flux/Cues controls occupy the header. The overview and compact section summary share the bottom centre. Times occupy its outer corners. Opening the side controls does not change the time anchors.

The separate 44-point section row is removed. Section editing remains available through the header diamond. At a 344-point deck height, normal detailed waveform height grows from 220 to 268 points. A 180-point deck provides 104 points instead of about 54. Flux moves to the first drawer row, followed by Freeze/Cues and loop length. Short drawers scroll. Existing fixed transport and crossfader anchors stay unchanged.

## Focused checks

The original source fails three rendered time-position assertions and two geometry assertions. Final mounted renders cover both decks at 180 and 344 points. Text recognition checks the current and remaining time corners with the side panel open and closed. Pixel checks cover the artwork position, occupied control area and black empty state. Geometry checks cover small and large allocations, control access, panel resizing and fixed dock anchors.

Before/after images, failed runs and the focused package manifest remain here. The production manifest is restored after each host check. These checks do not replace Erik's physical iPad acceptance. Erik checks album-art/load taps, times, waveform area, section/grid access, drawer gestures, fixed transport, crossfader and clean audio.

All 2,798 geometry assertions pass: 36 access/allocation, 1,432 panel and 1,330 fixed-dock checks. Both rendered deck cases pass at two heights and both drawer states in 12.826 seconds. Final A/B images were inspected.
