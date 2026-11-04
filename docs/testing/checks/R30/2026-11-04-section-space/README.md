# In-space section editor and quiet handles — R02/R09/R30

Date: 4 November 2026, Australia/Brisbane.

The section diamond opens a bottom-attached editor inside its deck. It no longer opens a system sheet. The fixed dock and full-height crossfader remain outside the editor. Its edge supports direct resizing, hiding and reopening. Each deck and orientation retains its editor height for the session.

Hiding and resizing keep the same draft and view identity. Cancel discards the draft. Save uses the existing arrangement validation and manual locks. Save and landmark promotion require the captured track ID and load token. Replacing, unloading or reloading that track closes the old session. Opening and closing send no seek, zoom or preview-return command. The form scrolls within the chosen height.

Quiet handles use a 12-point lane and a faint line. Double-tap toggles the panel. The Settings option **Large panel handles** restores the labelled 44-point controls. VoiceOver also uses those expanded controls. Both policies keep their grab lanes separate from musical inputs. The compact geometry reclaims horizontal and vertical space.

FX, EQ and action trays now start closed. Empty decks cannot open a blank tray. Unloading a track closes its panels and editor. A loaded deck can pull or double-tap the right edge to show its action controls. Chosen widths remain remembered.

## Verification

All 4,569 focused assertions pass. These include 114 editor/quiet-workspace assertions and the existing dock, library, contact, panel, divider and browser checks. The workspace checks cover both 12-point and 44-point geometry, draft identity, size memory, cancellation, load replacement, empty trays and retained musical mapping. The older geometry checks also retain expanded-mode coverage.

A temporary compiled mutation that ignores the load token fails two assertions. Restoring the empty tray as initially visible also fails two assertions. Production source was not mutated. `red.log` retains the missing-interface baseline. `green.log` and `browser-preservation.log` retain the passing checks.

The dock rendering and full-gap fader geometry, native contact bridge, analysis/preparation code, recording fixture, framework launch paths and restored iPad/Duo browser files match the baseline. Final review was self-review under the project rule against parallel agents.

Ruling: attach the editor inside the selected deck. It overlays that deck while retaining its musical view underneath. Cost if wrong: Erik may prefer the editor to share the whole work area.

Ruling: use a quiet 12-point edge by default and keep 44-point grips as an option. Cost if wrong: the thin edge may need adjustment after physical testing.

## Erik’s check

1. Check the empty decks and the closed action trays.
2. Load a track, then reveal and resize the action controls.
3. Open the section diamond and resize or hide the editor.
4. Reopen it and check the draft and remembered height.
5. Check Cancel, Save, section edits and landmark promotion.
6. Replace the loaded track and confirm the old edit closes.
7. Hold a musical gesture while resizing and check clean audio.
8. Enable Large panel handles and check the expanded controls.
