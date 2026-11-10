# R154 — Settings designed around DJ tasks

Status: build 217 installed, 10 November 2026. iPadOS accepted launch. Device acceptance is pending.

The incremental iPad compile, embedded-framework checks and signature checks passed. Build 216 was cancelled before installation while resolving a documentation merge. Its log and record are retained. Build 217 ran from committed consolidated main at `edb79975a`. No simulator, Mac packaging or broad test sweep ran.

Erik requested implementation for real use instead of mockups. His rule applies in both directions: live adjustments belong in the utility drawer, while lasting choices belong in Settings. Loop sizing is the reference example.
Feedback baseline: build 215, assumed from the latest recorded iPad install.

## Intent

Make settings easy to find, understand and change while preserving the TDJ1 workflow.
Separate live controls, saved defaults, track preparation and maintenance actions.
Use the existing iPad workspace. Keep clean audio and simultaneous touch control first.

## Findings from the source

- `SettingsBrowser` and `PlaybackSettings` expose different Playback options. Default loop size appears in the browser page. Keylock and the four-deck trial appear in the other view.
- The deck gear opens `PlaybackSettings(model:)` without a deck argument. Its location suggests a deck-specific scope that its contents do not have.
- Playback mixes quantisation, end-of-track behaviour, control visibility, waveform appearance and accessibility.
- Features repeats visibility controls and describes them by their development history rather than their use.
- Browser has one loading-protection toggle. Notifications combines notification visibility with a button labelled Reset Undiscovered Features that opens help.
- Mixcloud has a dedicated page but no sign-in. Recording sharing already belongs to Recordings.
- Library combines source management, key import, cloud status and recovery revisions in one long page.
- The settings sidebar has a fixed 300-point width. Content has a 520-point maximum width and 30-point padding. These dimensions do not adapt to the available pane space.
- The output shortcut already provides useful live access. Automatic controller routing and recording restrictions must survive the redesign.

These are source findings. This review does not establish how the current screens feel on the iPad.

## Organisation

| Destination | Groups and controls |
| --- | --- |
| Sound & Headphones | Connected output and automatic/manual routing; master and headphone channel assignments; stereo or separate headphone output; direct access to headphone controls |
| Decks & Playback | Loading protection; Keylock on track load; Freeze on load; default loop length; quantisation and slicer quantisation; vinyl stop and duration; end-of-track behaviour and auto-mix lead time |
| Layout & Touch | Show Beat Jump, Tempo fader, Cue and headphone buttons; SuperSlicer visibility; waveform section colours; large resize handles; notification visibility |
| Library & Preparation | Music refresh, audio import and linked collection; imported key review; iCloud preparation status and Sync now; saved preparation versions and restore |
| Controllers | Connected devices first; beat pulse and track-end warning per model; device-specific kit import; custom MIDI setup, learning and feedback mappings in a separate detail page |
| Help & About | Gesture guide; version and build number; notices; clearly marked experimental features, including the existing four-deck trial |

Retire Features, Browser, Notifications and Mixcloud as top-level categories. Preserve their working functions in the destinations above. Explain recording sharing in Recordings help.

Do not introduce new audio buffer, sample-rate, analysis-quality or performance-tuning switches as part of this work.

## Live controls and scope

Keep the speaker shortcut for master level, headphone level, Cue/Master blend and recording. Show the current route there. Provide a direct link to Sound & Headphones for setup. Both entry points must use the same state and routing rules.

Keep current-track Sync, loops, cues, Freeze and Flux on the performance surface. Keep current-track Keylock with the deck's controls. Label the saved preference Keylock on load and state its existing A/B scope. Do not silently extend it to C/D.

Give each deck panel its deck name and track title. Put Use playhead as last drop and Use detected drop beside that track's preparation controls. They do not belong among app-wide preferences.

Replace the deck gear's broad global form with clearly scoped deck controls and links to Playback defaults and Layout & Touch. Never imply a local change when it changes all decks.

Every setting must state its scope when ambiguous: this track, this deck, all decks, or this controller. Distinguish a current value from a default used on the next load. Preserve saved Sync choices and grid alignment.

## Display and interaction

Use a category list and one detail pane when there is enough room. When the settings pane is narrow, show the categories first and use a clear Back control. Select this behaviour from available pane width, not portrait orientation or phone assumptions.

Keep settings inside the adaptable workspace. Preserve deck transport access and the pane's previous size when returning to performance. Category selection and scrolling must not resize the workspace or steal an active deck gesture.

Use consistent rows: label on the left, current value or switch on the right. Show units beside numeric values. Prefer inline choices for short lists and a detail page for long or complex choices. Avoid nested disclosure groups.

Use restrained dark panels, readable labels, subtle separators and cyan selection. Do not rely on colour alone. Give touch targets at least 44 points. Keep larger text readable without clipping controls.

Put one short explanation below a setting only when its effect is not clear. Show dependent controls beside their parent: stop duration under Vinyl stop, lead time under Auto-mix, and channel assignments under routing.

Keep unavailable settings visible with a specific reason. For example: Finish recording to change output. Do not offer an enabled headphone fader when the selected route provides no headphone cue.

Save ordinary preferences immediately. Use confirmation only for consequential replacement actions such as restoring preparation or replacing MIDI mappings. Retain existing import review and loaded-track protection.

Add lightweight settings search with DJ terms and aliases, including pitch lock/Keylock and headphones/cue. Results open the actual row with its context. Search must not scan the music library or trigger preparation work.

## Safe implementation sequence

1. Unify settings destinations and rows. Preserve storage keys, values and defaults. Remove the conflicting global Playback forms.
2. Separate deck-specific controls from saved defaults. Verify each setting's existing application timing before changing its label or location.
3. Refine sound setup, preparation detail pages and controller setup using the shared layout.
4. Add search and finish text, accessibility and narrow-pane behaviour.

Each step is one focused iPad iteration with its own signed build and feedback record. Do not combine this redesign with an audio engine rewrite or a change to saved preferences.

## Acceptance and remaining work

Erik authorised implementation without a mockup. The first build consolidates six settings categories, adapts navigation to pane width, and replaces the global form in the deck gear with scoped live controls. It retains the existing loop buttons and saved preferences.

Remaining refinements: settings search, separate preparation detail pages, and a separate MIDI mapping page. These are not in this first build. Touch target and larger-text review remain part of physical acceptance. No new search or preparation background work was added.

For each implementation iteration, verify changed bindings and saved-value compatibility with focused checks. Then build from consolidated main using `tools/ipad_test.py`, install the numbered iPad build and hand back.

On the A10X, check finding and changing a setting, returning to performance, resizing the pane, and keeping another touch active. Check persistence after reopening. Check automatic routing, recording locks and unavailable states where affected.

Any crackle, pause, delayed touch or visible stall blocks acceptance. Build success does not establish performance readiness. Physical review and the refinements listed above remain open.

## Source references

- `Replica/Sources/TDJInterface/BrowserSections.swift`
- `Replica/Sources/TDJInterface/PlaybackSettings.swift`
- `Replica/Sources/TDJInterface/PerformanceControls.swift`
- `Replica/Sources/TDJInterface/RecoverySettingsView.swift`
- `Replica/Sources/TDJInterface/MixerView.swift`
- `Replica/Sources/TDJInterface/ReplicaView.swift`
- `Replica/Sources/TDJInterface/ControllerSettingsView.swift`
- `Replica/Sources/TDJInterface/ControllerFeedbackSettingsView.swift`
- `Replica/Sources/TDJInterface/CloudPreparationSettings.swift`
- `Replica/Sources/TDJInterface/KeyImportReviewView.swift`
