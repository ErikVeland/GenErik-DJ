# R425 UI label layout

Erik reported split words, such as RESET displayed as RESE and T, on 19 November 2026.
Build 225 is the last recorded installed iPad build. This attribution is an assumption because the report did not include a build number.

The shared workspace now defaults to one line for labels, with a minimum text scale of 80%.
The shared performance button styles also enforce this rule when used outside that workspace.
Track, playlist and recording titles use one line. Longer titles truncate at the end.
Help, purchase terms, recovery instructions and error details retain multiple lines.

Grid editing uses the header width previously shared with track details.
The grid controls retain their full text width and at least 44-point touch targets.
When the row cannot fit, the bar scrolls horizontally within the existing 44-point header.
The waveform geometry and the audio engine are unchanged.

## Verification

Source review and whitespace checks passed before the signed build.
Build 227 compiled from committed main at `82f66c1ec` in 332.6 seconds.
Runtime framework checks and deep strict signing passed.
The iPad connection timed out during installation. The signed app remains saved for deployment without a rebuild.
No device launch or rendered layout acceptance is claimed. Erik's acceptance remains open.
Check RESET, TAP MODE, DONE, Sync, effects, mixer labels, browser titles and Settings in both iPad orientations.
Also check narrow panes and the four-deck layout when that trial is enabled.
Phone front, Duo inside and Mac layouts share the source rule, but their rendered acceptance remains open.
Check full error and purchase text, simultaneous touch and continuous audio.

The request ledger contained committed merge markers. This change removes those markers and preserves both sets of historical rows.
