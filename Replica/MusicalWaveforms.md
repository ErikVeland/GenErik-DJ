# Musical waveform preparation

The diamond control above each loaded waveform opens **Musical structure**. The compact deck has the same control.

The overview shows section colours across the track. The detailed waveform keeps its frequency colours and adds a narrow labelled section strip. Hollow diamonds show analysis landmarks. They do not replace numbered hot cues or intercept waveform gestures.

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
