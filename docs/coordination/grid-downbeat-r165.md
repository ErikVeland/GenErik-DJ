# R165: Set the grid downbeat from the current playhead

The old editor showed four small numbered controls. They did not move the playhead or make the two-step edit clear.

In grid edit, Erik taps the intended beat to move the live playhead there. The editor stages that beat as the downbeat. **Done** saves the downbeat and any grid-phase change.

The edit stays a draft until Erik taps **Done**. Loading another track clears the downbeat draft.

## Remaining checks

- Run a focused check for fixed and adaptive grids.
- Build and install the next iPad test app through the current test loop.
- Check that a beat tap moves the live playhead and marks that beat as beat one.
- Check that Done saves the downbeat and any phase change together.
- Check that the saved downbeat remains after reloading the track.
- Check the edit flow while audio continues and confirm that touch response remains immediate.

No build, automated check or A10X device test has run for this change.
