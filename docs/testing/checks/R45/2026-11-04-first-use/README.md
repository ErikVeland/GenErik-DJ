# R45 first-use loading checkpoint

## Behaviour

Native Music playback no longer waits for a full export, whole-song waveform scan or complete PCM conversion. The native provider validates the current local Music item on a dedicated playback queue. The opening decoder reads up to half a second of real audio. The deck displays those bins before the audio pool is allocated or primed.

The existing bounded read-ahead engine requests decoded stereo blocks on its serial service worker. The audio callback only reads published PCM blocks. Decoder ownership lasts until the stream worker retires the asset. Decoder failure retains the existing stream error path.

Play retains its load owner. A second tap cancels the pending request. A replacement cannot consume an older Play request. Background waveform decoding extends the real waveform and writes the optional PCM cache. Unknown waveform regions remain shaded and show “Reading waveform…”. They contain no invented waveform data.

Full musical analysis still uses the existing native export path after readiness, while decks are idle. Playback and performance touches cancel that analysis. Native source bindings distinguish pending native identity from verified content hashes. Existing Music source records keep their track IDs, preparation, Traktor references and cue keys. Metadata length differences do not replace the existing track. Waveform replacement retains the bar-analysis version. Sample-rate changes reject before changing the saved preparation.

The decoder still needs source metadata, a real opening buffer and read-ahead reserve. This checkpoint removes full-track gates. It does not establish a physical iPad latency budget or gig acceptance.

## Focused evidence

- The cold-stream test first failed because the old path created a complete PCM cache before it returned. The same test passes with direct decoding.
- Seven core tests pass. They cover cold playback, real opening coverage, complete waveform/PCM samples, stable identity and manual preparation through content analysis/import, native aliases, cancellation, and exact asset-reader seeks.
- The existing-track test retains a Traktor record, cue, manual preparation and bar version with the Creep cache length of 22,746,240 frames at 44,100 Hz, despite a different opening decoder length. This is a synthetic preservation check, not a new Creep listening claim.
- Seven interface test functions pass, covering ten cases. The first-use case proves real bins and retained Play before export or whole PCM preparation. Later analysis retains the ID, cue, manual grid and audio generation. Replacement, existing R45 readiness and deferred analysis cases also pass.
- The native stream checks pass. The new decoder case verifies no reads at asset creation, bounded priming, sample-exact output, failure and single release. Existing stream checks retain zero-miss comparisons and a responsive callback during a blocked worker read.
- Five loading-order assertions, Swift parsing and source whitespace checks pass.
- The production package manifest was restored after each focused test run. Both focused manifests and all failed and successful outputs remain here.

The initial expanded core command stopped on a missing artist argument in the new test. That test setup was corrected. Its failed log remains preserved.

The R43 chat separately owns the actual compressed Creep probe at `../../R43/2026-11-04-main-install/compressed-creep.json`. It reports exact asset-reader/file-backend samples over seven ranges. Those files are not owned or staged by this checkpoint.

## Handover

Erik reassigned the final merge, build and installation to the consolidation chat. This chat commits only R45 files on the current `feature/r43-main-install` branch, preserving parent `f141c8543`. It does not switch branches, merge, push, build the iPad app or access the device after that instruction.

The final combined iPad build, installation, launch, first-use timing, Music permission handling, long-source pressure, touch response and clean other-deck audio remain for the consolidated handover and Erik's acceptance.
