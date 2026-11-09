# R91 preview-strip navigation

Erik reported that the small strip did not feel like TDJ1 in build 144. The NI tutorial shows a preview workflow: drag the red window, release it, then tap a beat in the detailed waveform. The strip does not seek audio by itself. See `Analysis/Traktor-DJ-1x/07-ni-tutorial-video-findings.md`, S15 at 2:19–2:48.

The window now keeps the finger offset when grabbed inside its border. A touch outside the window selects that preview position. Release retains the preview. The actual playhead remains visible while the preview is elsewhere. Pinch zoom retains its original scale and contact identities. A remaining pinch finger cannot become a drag. Cancellation restores the previous preview or playhead following. Old contacts cannot move a reloaded track.

Detailed waveform taps now tolerate the existing small movement threshold before they become scratches. A new test reproduced the old defect: a 0.001-width movement started touch playback before release. The fix preserves the beat tap and its grid-aligned jump.

Eight focused host tests passed across eleven cases. These cover navigation, pinch ownership, cancellation, reloads, tap jitter, load position and ready-state following. The failed reproduction and passing evidence remain in `TestBuilds/r91/`. The verification record binds those results to the tested source. No A10X touch acceptance is claimed.

On the iPad, drag the red window from its edge, release it and tap a beat in the detailed waveform. Check that audio continues during preview and that the jump remains in Sync. Pinch the strip, lift one finger and move the other. Check that no unintended navigation follows. Use the playhead return control to resume following.
