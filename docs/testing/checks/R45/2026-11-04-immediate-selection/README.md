# R45 immediate deck selection

Erik reports that the second slot still loads too slowly and requires an immediate display update. Feedback assumes build 106, the last recorded iPad installation.

The native load path closed the browser before it published a track for the deck. Publication waited for source lookup, opening waveform decoding and workspace registration. The selected metadata was already available at the browser boundary.

The model now publishes a separate, observable selection before starting asynchronous work. The deck shows the selected title, artist, artwork request and duration. It hides the previous waveform, overview, preparation controls and elapsed position while the source opens. Real waveform data replaces the preparation state at the existing audio-load handoff. The audio engine keeps its existing track identity and preparation rules.

Each selection belongs to the native load owner. Replacement, cancellation, stop and failure clear only the applicable selection. A failed preparation restores the existing deck display. Older requests cannot clear newer feedback. App-managed loads retain their existing immediate publication path.

## Verification scope

Focused runtime checks cover synchronous publication on both decks, failure restoration, replacement ownership, cancellation, existing waveform and Play behaviour, deferred analysis and exact other-deck sample output. Failed attempts and diagnostics remain in this folder. The production package manifest is restored after each focused run.

The first regression run records seven missing-selection assertions. The first implementation build exposed an optional album argument and stopped. The corrected concurrent run passed 14 functions and failed two loading functions. Those two functions pass together in the isolated diagnostic run. Later diagnostics identify `PCMStreamingError.capacity`: each stream reserves 32 MiB from a process-wide 128 MiB pool. Concurrent test models exceeded that four-stream limit. The final loading checks use explicit `--no-parallel`. The app retains its existing memory limit. All failed runs remain recorded.

All 11 focused functions pass in the final serial run, covering 15 cases in 63.884 seconds. The other-deck check compares 4,096 stereo frames exactly against a control while deck B waits for its source.

The iPad build must come from merged main. Compilation, source identity, framework resolution and signing support installation. Erik checks immediate physical display feedback, actual audio readiness, queued Play, replacement and clean audio. These checks do not establish physical iPad acceptance.

The STE linter was unavailable at the configured skill path. Prose received a manual check.

Build 107 from main source `88d74ace0` passed source identity, framework resolution and signing checks. It installed on the test iPad, and iPadOS accepted launch. Device actions stopped. Erik performs physical acceptance.
