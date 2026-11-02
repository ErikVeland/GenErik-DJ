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

The current preparation pass detects conservative energy-change boundaries and the last sustained audible content. It can suggest the first grid downbeat when tempo confidence is sufficient. It does not classify verse, chorus, vocal entry, build, drop or mixing suitability from loudness. Neutral section labels make this uncertainty visible.

The role, behaviour, landmark, region and confidence models support richer analysis. A trained structure and vocal analyser, library-based evaluation, and A10X performance and accessibility measurements remain required for the full automatic feature described in the supplied design. No new trained model is included in this change.

Manual labels and landmarks provide the complete display and interaction while automatic classification remains limited. Preparation is held stable in memory during playback and cached off the main actor. Playback performs no new audio analysis.
