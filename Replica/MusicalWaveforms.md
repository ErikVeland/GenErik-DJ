# Musical waveform preparation

## Clarity comes first

Readability takes priority over exact amplitude. Read the bands like performance stems, with kick and bass as the primary shape.
Use the middle layer for harmonic and vocal-range texture. Keep snare attacks clear through the middle and upper layers.
The current bands describe frequency content. They do not isolate drums, bass, instruments or vocals.

R168 retains peaks from either stereo channel, rather than cancelling opposite-polarity content through a mono average.
It retains the original layer widths, gain and brightness after Erik rejected the first visual candidate.
Prepared bands taper their preceding decay for up to 30 ms before a strong attack.
The attack keeps its height and time. Each band handles its own lead-in, so a kick does not dim unrelated snare frequencies.
The detector follows rises in band energy. It does not create or reposition beats.
The full-mix fallback retains its original balance.
Its inner layers show level contrast until frequency detail is ready.
Source audio, beat positions, colours, layer count and gestures stay unchanged.

The display retains track-wide scaling, 64-frame bins, four summary levels and the existing headroom.
The contrast pass prepares in place before the level summaries. It adds no drawing pass, stem processing or performance control.
Band preparation still yields to playback and touch through the existing idle and cancellation guards.
Use the [clarity contract](../ARCHITECTURE.md#waveform-clarity) for DJ priorities and physical acceptance.

## Current workspace

The diamond control above each loaded waveform opens **Musical structure**. The compact deck has the same control.

The waveform uses the section colours by default. The same palette connects the detailed waveform, overview and header. The header background shows the current section colour. A narrow timeline at its top follows the detailed waveform, with matching section boundaries. Current-section and next-event guidance share the track information area.

The detailed waveform has no separate section strip or section labels over its audio detail. Its three layers retain different brightness levels within each section colour. Frequency colours remain available through **Section colours in waveform** in Playback settings. Missing section preparation uses frequency colours until preparation is available.

The bottom overview fills the deck width. Current time, ending guidance and time left overlay that strip on dark text backgrounds. These overlays pass touches through to the overview. Hollow diamonds show analysis landmarks. They do not intercept waveform gestures. The analyser also fills free hot-cue slots with section starts. Generated cues carry the section name and colour. Existing cues stay in place. There are eight slots, so extra sections retain their arrangement labels without a numbered cue. Deleted generated cues stay deleted after reload. Section edits refresh the names and colours of remaining generated cues.

## Preparation

- Rename sections, assign musical roles and arrangement behaviours, split sections, and move shared boundaries.
- Add named landmarks at the preview position. Choose their kind and enter their mixing reason.
- Enable Region to describe a mix-in or mix-out span. Its end means **finish by**.
- Accept, dismiss or adjust analysis suggestions. Edits lock the affected preparation against later analysis.
- Promote a landmark into the first free hot-cue slot. Vocal pickups retain their exact position.

Save applies section and landmark changes. Promotion is an immediate hot-cue action. Cancel closes the editor without applying other draft changes.

Preparation is cached in the workspace's `Arrangements` directory. It stays separate from hot cues, saved loops and beat grids. Existing tracks receive preparation when their cached waveform loads. Library reanalysis is not required.

## Performance display

The deck shows the current section and a countdown to the next section or landmark. Countdown bars use the actual fixed or adaptive beat grid. With an unreliable grid, the display uses seconds and a steady warning.

The default ending preparation cue is 32 bars. The editor also offers 48, 64 and 96 bars. Amber starts at 16 bars. A restrained red accent starts at 8 bars, with stronger steady emphasis at 4 bars. The pulse follows deck beat phase and stays at or below two pulses per second. Pause, reverse playback, reduced motion and decks outside the main output use steady information.

Ordinary loops show **LOOP ACTIVE** and the distance remaining after release. Slip loops use the advancing underlying playhead. The display distinguishes musical time from file time. A corrected rhythmic-ending landmark adds a **DRUMS END** countdown. A tail after the musical ending displays **TAIL**.

## Automatic-analysis coverage

Loading a track starts one local structure pass from its complete playback cache. The pass measures one-second spectra, pitch classes, bass attacks and level changes. Apple Sound Analysis supplies vocal-activity evidence. Preparation runs serially at utility priority, outside the audio callback. Switching away cancels work when neither deck uses that track.

The analyser groups sustained changes and compares repeated harmonic and timbral passages. It suggests intro, verse, pre-chorus, chorus, bridge, instrumental and outro roles, plus build, drop, breakdown and thinning behaviours. Verse and chorus are inferred from vocal evidence, repetition and relative intensity. They are not outputs from a trained song-form model. A `?` marks inferred labels. Silence and loudness-only preparation retain neutral labels.

The existing palette remains: mint intro, blue verse, yellow pre-chorus/build, orange chorus/drop, purple bridge/breakdown and muted green outro. Musical roles take colour priority over behaviour. Instrumental passages use behaviour colours, or neutral grey when sustaining.

Suggested landmarks include vocal entries, arrivals, main returns and breakdowns. Mix regions favour sustained bass rhythm and low detected vocal activity. Their reasons state when vocal evidence is absent. The end of a region means **finish by**. Rhythmic endings follow the last bass attacks before an audible tail. Musical and rhythmic endings remain estimates that Erik must check against real music.

Old arrangement caches upgrade on track load. Existing preparation stays visible while **ANALYSING STRUCTURE** appears. Completed results use cache version 2. Locked sections, accepted or dismissed landmarks, and manual endings remain authoritative. An incomplete cache or classifier failure retains existing preparation and reports a retry message. These operations do not change beat grids, keys, hot cues or source audio.

Focused checks cover repeated vocal refrains, instrumental breakdown/build/drop passages, mix regions, ending tails, silence, manual corrections, actual cached PCM and cancellation. They do not establish accuracy across Erik's library or performance on A10X. Erik's Duo test and real-track review remain required.

A deck load now runs full musical analysis when analysis was deferred, BPM is absent or invalid, or the effective key is absent. Complete tracks keep the fast path. Analysis retains manual grids, trusted keys and cues. A completed pass reports when BPM or key remains unresolved. The structure pass waits until deck preparation has finished.
