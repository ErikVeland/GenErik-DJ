# GenErik DJ architecture

## Start small. Start simple.

Keep it simple, stupid. Build the instrument a working DJ needs for the next mix.
Add a feature when a real DJ task needs it. Feature parity, available screen space and technical possibility do not justify another control.

TDJ1 is the base for sound, touch and feel. Preserve Erik's familiar gestures and one adaptable workspace.
A DJ must be able to play a complete two-deck set without enabling an expansion or understanding its setup.

This guide turns the [north star](docs/product-direction.md) into architecture and review rules.
It defines the intended feature boundary and reviews the current source separately.
It does not certify exact TDJ1 fidelity or gig readiness.

## Order of priorities

1. Keep clean, continuous audio at the intended speed.
2. Keep immediate, fluid multi-touch control.
3. Make musical time, peaks and mixing cues clear at a glance.
4. Keep the live workspace simple and familiar.
5. Add only the capability needed for a demonstrated DJ task.

Any crackle, dropout, unintended pause, slowdown or stop blocks acceptance.
A missed touch, delayed control, visible stutter or UI stall also blocks acceptance.
An optional feature must yield, pause or stop before it compromises these priorities.

The active performance target is Erik's 2017 A10X iPad Pro.
Build success and host tests cannot replace his listening and touch checks.
Use the existing [acceptance gates](docs/coordination/release-gates.md) and [test loop](docs/testing/README.md).

## Waveform clarity

Clarity is a north star alongside simplicity. Readability takes priority over literal amplitude accuracy.
The waveform must help a DJ choose and execute the next mix within a short glance.
TDJ1 remains the reference for readable peaks, beat/bar emphasis and an uncluttered surface.

| Read first | What the DJ needs | Display rule |
| --- | --- | --- |
| Beats and bars | Align the incoming phrase and recognise the next beat one | Keep bar lines stronger than ordinary beats. Use the accepted grid, independently of waveform level. |
| Kick and bass | Choose the bass handover and avoid competing low ends | Give the primary silhouette the most space. Keep attacks, decay and gaps distinct. |
| Phrase changes and vocal-range content | Choose an entry that supports the outgoing track | Keep harmonic and vocal-range texture readable inside the primary shape. Use existing phrase context and verified preparation. |
| Upper percussion and fine detail | Read rhythm and texture without losing the bass pattern | Keep the high-frequency core narrow. Quiet traces must not become dominant through display gain. |
| The whole track | Locate a useful passage without losing the live position | Keep the overview simple. Retain detail, timing and gesture ownership while the DJ changes zoom. |

Read the bands like performance stems. Their visual weight can serve a mixing task rather than match their physical amplitude.
Use shape, relative width, brightness and contrast consistently.
Keep peaks visible around the inner layers, including dense recordings and the temporary full-mix preview.
Retain stable scaling across the track. Do not amplify each screenful until it fills the pane.
Do not fabricate attacks or flatten a real transient pattern to make the display look uniform.

Kick and bass share the primary low-frequency layer.
The middle layer supplies harmonic and vocal-range texture. The high core supplies percussion and fine detail.
These roles guide visual reading. Current frequency bands do not identify isolated instruments or prove that a vocal is present.
Use verified stem envelopes when they already exist and share the track clock, grid and source identity.
Do not start separation, add stem lanes or add live controls solely for waveform appearance.

Section colours convey phrase context. Band width and contrast must retain the musical hierarchy within those colours.
Labels, ribbons and markers must leave transient shapes readable and must not intercept an active waveform gesture.
Show unresolved timing or preparation honestly. Preserve the existing waveform while optional detail prepares.

R168 strengthens the peak silhouette, narrows supporting layers, limits quiet-band amplification and retains stereo content without cancellation.
It preserves the three layers, palette, headroom, beat/bar drawing and gesture routes.
The waveform keeps its current level summaries and drawing paths. Extra preparation remains outside active playback.

### Acceptance in a real mix

Use a bass-heavy dance track, human-played disco, a sparse vocal passage and a bright passage without bass.
Include a dense mastered track and a stereo-wide recording.
Check the normal deck view, a reduced deck pane, the overview and a zoom change.

1. Find the next beat one and the bass handover with a short glance.
2. Read the kick attacks and quiet gaps without relying on labels.
3. Distinguish primary bass from supporting texture when section colours change.
4. Check that a bass-absent passage does not look like full bass.
5. Keep waveform touches and another performance control active together.
6. Check audio, scrolling and touch on the A10X before accepting the display.

Synthetic checks and rendered fixtures establish geometry and regressions. They do not establish superiority to TDJ1 or physical A10X acceptance.

## Base feature set versus expanded feature set

**Base** means the familiar instrument needed for an ordinary two-deck set.
It includes contextual tools, such as EQ and cues, without showing every control at once.

**Expanded** means an extra control, workflow or performance capability for a specific need.
New expansions start off. Setup, imports and maintenance stay outside the ordinary live surface.

The table defines the product boundary. The last column records current behaviour, including exceptions.
Defaults describe a fresh preference store. Saved choices can produce a different layout after an update.

| DJ task | Base instrument | Expanded capability | Current source |
| --- | --- | --- | --- |
| Mix the next track | Two decks, A and B, with familiar Play and Sync controls | Four decks with A/C and B/D selection | Two decks by default. Four decks require the trial build and a saved opt-in. [S1](#s1) |
| Find and load music | Library, search, playlists, recommendations and the TDJ1 load gesture | Library administration, linked collections and preparation imports | Browse in the existing pane. Source and import setup have detail pages. [S2](#s2) |
| Match tempo and timing | Shared tempo control, persistent Sync and Keylock | Separate Tempo fader and conventional Cue button | Added buttons start hidden. Keylock on load starts on for A/B. [S3](#s3) |
| Move through a track | Detailed waveform, overview, direct seeking and beat-based touch jumps | Dedicated Beat Jump buttons | Buttons start hidden. Direct waveform control remains available. [S3](#s3) |
| Extend or reshape a phrase | Touch loops, loop sizing, saved cues, Freeze, Flux and contextual SuperSlicer | Freeze on load and Vinyl stop | Cue pads and drawers open when needed. SuperSlicer visibility starts on. Freeze on load and Vinyl stop start off. [S3](#s3), [S4](#s4) |
| Blend the sound | Crossfader with EQ, filter and FX in deck drawers | Specialised hardware modes and per-stem FX | Drawers start closed. FX start bypassed. The effect menu includes all eleven implemented effects. [S4](#s4) |
| Check the incoming track | Headphone cue, blend and level through the sound controls or connected hardware | Extra deck Headphone cue button and manual channel setup | Extra button starts hidden. Routing setup stays under Sound & Headphones. [S2](#s2), [S3](#s3) |
| Read and prepare music | Waveform, usable beat grid, BPM, key, visible uncertainty and contextual corrections | Deep library analysis, section editing, key imports, iCloud sharing and saved-version recovery | Preparation and maintenance use dedicated pages and workers. Device acceptance remains open. [S2](#s2), [S5](#s5) |
| Record or review a set | Start recording from the sound panel. Find recordings and history in the browser. | Share or reload a saved recording when required | Recording requires a DJ action. Sharing stays with the selected recording. [S2](#s2) |
| Handle the end of a track | The DJ chooses the next transition | Replay the best section or auto-mix the next track | R166 starts new settings off. Existing files retain explicit choices or legacy replay behaviour. [S6](#s6) |
| Remix with separate parts | Play the original full mix | Live Vocal/Instrumental separation, authored stems, Pattern Player and hardware sample workflows | R166 adds a saved, default-off live-stem gate. Mix or Off cancels preparation. Physical acceptance remains open. [S7](#s7) |
| Use physical controls | Touch remains sufficient. Original Z1 remains the reference hardware workflow. | Other controller adapters, MIDI learning, timecode, inputs, kits and hardware screens | Setup stays in Controllers. Some adapters activate on connection. Physical acceptance varies by model. [S8](#s8) |

Base membership does not require permanent visibility.
An effect menu can contain several choices while the live surface keeps one shared XY pad.
An expansion does not earn a permanent button merely because it exists.

## User stories in real sets

### Base instrument

| Situation | User story | Success looks like |
| --- | --- | --- |
| A busy dance floor | As the DJ, I find and load B while A plays, then blend the next track. | Audio continues. Loading and browsing preserve the familiar workspace. |
| Both hands on the glass | As the DJ, I hold a loop with one hand and adjust EQ with the other. | Each control keeps its own touches. Neither action stalls or cancels the other. |
| An incoming phrase starts early | As the DJ, I choose a waveform position and start the incoming deck with Sync enabled. | Usable grid timing governs the start. A temporary gesture does not disable my saved Sync choice. |
| The outgoing phrase is too short | As the DJ, I make a loop and resize it while I prepare the next mix. | Direct gestures and live loop controls remain reachable without opening global Settings. |
| A vocal needs space | As the DJ, I open EQ or FX, shape the transition, then close the drawer. | The waveform regains its space. I do not need a page of permanent knobs. |
| Headphones in a loud booth | As the DJ, I check B privately and adjust the cue blend. | Cue state and routing stay clear. Output setup does not interrupt an unrelated gesture. |
| An uncertain older recording | As the DJ, I inspect and correct its timing before I depend on Sync. | The app shows unresolved timing. It preserves my correction through later analysis and imports. |
| A recorded practice set | As the DJ, I start recording, play the set, then review or share it afterwards. | Recording controls stay in the sound panel. File management stays in the browser. |

### Expansions, only when needed

| Situation | User story | Boundary |
| --- | --- | --- |
| A deliberate four-track routine | As the DJ, I enable four decks for a routine that needs them. | Two decks remain the normal starting point. The trial needs separate A10X acceptance. |
| A preference for physical-style controls | As the DJ, I enable Beat Jump buttons or a Tempo fader because they suit my technique. | Each choice adds only its own controls. It preserves direct waveform gestures. |
| A planned vocal transition | As the DJ, I choose separate vocal control for that transition. | I enable the trial before its handle appears. Mix cancels preparation and retains audio already prepared. |
| A short interruption at a function | As the DJ, I choose replay or auto-mix before stepping away briefly. | The mode states what it will do. New settings require my choice. Existing settings keep their behaviour. |
| Preparation before a gig | As the DJ, I analyse tracks, review imported keys and share preparation across devices. | Long work stays outside live control paths. A set must not depend on a live cloud connection. |
| A different booth controller | As the DJ, I connect the required controller and configure only its relevant options. | Its hardware functions do not add unrelated controls to the ordinary touch layout. |

These stories describe intended outcomes. They are review criteria, not claims that all device checks have passed.

## How the architecture protects simplicity

### One workspace, with detail when needed

Keep waveforms, loops, beat jumps, navigation and movable panes within one adaptable workspace.
Use an existing gesture, drawer or component before adding another visible control.
Keep the meaning and position of familiar controls stable when optional features stay off.

Put immediate performance actions beside their deck or in the sound shortcut.
Put lasting defaults in Settings. Put preparation beside the track or in Library & Preparation.
Put recovery, imports and mapping administration on detail pages.
State whether a change affects this track, this deck, all decks or one controller.

The six current settings groups already support this separation.
Do not add a new top-level category for every feature.
Do not add a global Simple/Advanced mode or a setup wizard without a demonstrated need.

The phone front-screen design applies only to that screen.
Portrait orientation alone must not replace the iPad or Duo inside layout.

### Keep decisions behind clear boundaries

| Boundary | Responsibility | Rule for new work |
| --- | --- | --- |
| `TDJInterface` | SwiftUI views, touch ownership, presentation and application coordination | Views present state and forward intent. Keep musical decisions in testable policies or core contracts. |
| `TDJCore` | Library, preparation, analysis, timing and transport control | Test behaviour without rendering a view or calling a real external service. |
| `CTDJTransport` | Sample clock, bounded commands, PCM streaming, mixing, FX and recording capture | Keep allocation, decoding, logging, file access and blocking waits outside the render callback. |
| `CTDJAudioSource` | Native bridge from AVAudioSourceNode to the renderer | Keep audio execution independent of SwiftUI redraws and UI polling. |
| External adapters and workers | Controllers, storage, imports, cloud and analysis | Pass small typed dependencies into policies. Bound work and support cancellation. |
| Tools and diagnostics | Preparation tools, previews and runtime checks | Keep diagnostic controls outside the ordinary performance surface. |

An optional view must not start expensive work merely because SwiftUI creates it.
A hidden panel does not establish that its worker has stopped.
Test the disabled state as well as activation, cancellation and return to the base workspace.

Preserve existing timing and resource limits.
Use the [bounded streaming design](Replica/PCMStreamingDesign.md) and [scheduling rules](Replica/Responsiveness.md).
Required playback reads take priority over optional analysis, artwork, library work and cloud transfer.

### Musical state must remain trustworthy

The beat grid is the transport timing authority.
Keep Sync enabled until Erik explicitly disables it.
Starts, restarts, seeks and gesture releases must preserve or restore alignment when Sync has a usable grid.
Temporary manual control must preserve the saved Sync choice.
Show missing or unaccepted timing as unresolved. Loading shows the file start at the playhead.

Keep manual and imported preparation separate from detected proposals.
Do not silently replace accepted corrections to make a new analysis feature appear successful.

[R162](docs/coordination/persistent-sync.md#r162-human-groove-and-bar-alignment) specifies human groove and bar alignment.
The reviewed commit contains requirements only. Uncommitted R162 transport work is outside this assessment.

## Rules for an expansion

1. Name the real DJ situation and the problem it causes.
2. Check whether an existing gesture, drawer or control can solve it.
3. Add only the smallest capability that solves that problem.
4. Keep new optional controls and behaviour off until the DJ chooses them.
5. Keep setup outside the live surface and show dependent controls together.
6. Preserve saved choices and preparation when loading older settings.
7. Verify the focused behaviour, then check audio and touch on the A10X when implementation changes.

Record an exception when connection or content selection activates a capability automatically.
For example, selecting a matching controller may activate its adapter without a separate switch.
That exception must serve the selected workflow and must not populate the base workspace with unrelated controls.

For an optional feature, **off** means no added live controls, active feature processing or automatic playback changes.
A collapsed drawer, bypassed effect, unavailable build and untested feature are different states.
Document those states accurately. Do not describe all of them as default-off.

Do not reset existing preferences to enforce a new default.
Any migration needs its own request, scope and acceptance checks.

## How well the current app follows this guide

Source review: **11 November 2026**, against application source at `dec70c08`.
R163 changed documentation only. The historical findings below describe that reviewed source.
The assessment excludes uncommitted R162 transport work present during this review.

**Overall judgement: the performance surface is broadly aligned with the TDJ1 simplicity ethos.**
The strongest evidence is the two-deck default, hidden added transport buttons, contextual drawers and task-based Settings.
The main drift lies in activation defaults and the breadth of supporting systems.
This supports Erik's testing impression, but does not replace physical acceptance.

### What already works well

- Four decks need an explicit saved choice and an eligible trial build.
- Beat Jump buttons, Tempo fader, Cue and extra Headphone cue start hidden.
- Mixer, FX and cue pads use space when the DJ opens them.
- Live deck utility controls and lasting preferences now have distinct destinations.
- Preparation, mapping and saved-version administration have detail pages.
- Cloud sharing and native analysis include playback or loading guards. These do not establish performance acceptance by themselves.

### Drift and scope growth

| Finding | Why it matters to a working DJ | Recommended response |
| --- | --- | --- |
| **Live stems lack a saved opt-in.** A handle appears on eligible loaded iPad decks. Selecting Mix does not cancel separation. [S7](#s7) | A trial occupies the base surface even when unused. Closing the drawer or bypassing its output does not stop its worker. | Gate activation and cancel processing on disable through a separate request if Erik retains live stems. Keep the trial deferred behind the two-deck baseline. |
| **Replay starts enabled.** Eligible playback automatically prepares recovery. [S6](#s6) | End-of-track behaviour can change without the DJ choosing an expansion. | Confirm whether replay is an intended base safeguard. Otherwise, make it opt-in through a separate change. Preserve saved choices. |
| **The Notification centre visibility choice appears disconnected.** The toolbar creates its button unconditionally. [S9](#s9) | A switch adds complexity without delivering its promised control. | Wire the existing choice to visibility or remove the ineffective choice after review. |
| **Several contextual features start enabled.** SuperSlicer and section colours are examples. [S3](#s3) | An inaccurate blanket default-off claim hides deliberate exceptions. | Keep useful TDJ1 context. Review actual crowding before hiding familiar tools or changing defaults. |
| **Supporting scope has expanded substantially.** Stems, Pattern Player, timecode, hardware screens, many adapters and shared analysis extend beyond two-deck touch mixing. [S5](#s5), [S8](#s8) | Hidden features still cost maintenance, storage and verification effort. They can compete for performance. | Require a concrete DJ need for further work. Retain existing work, but prioritise the two-deck baseline before expansion acceptance. |
| **Application coordination remains broad.** `ReplicaModel` owns library, playback, controller and preparation state. [S10](#s10) | Another hidden feature can increase coupling even if its UI stays small. | Keep new policies behind small contracts. Extract only the boundary a requested change needs. Avoid a general rewrite. |

These findings recommend follow-up decisions. They do not authorise feature removal, default changes or a cleanup programme.
R155 two-deck acceptance remains open. Four decks and live stems remain deferred in the [completion programme](docs/coordination/completion-programme.md).

## R166 response to the real gaps

Erik chose opt-in replay for new settings and preservation of existing saved behaviour.
The source changes address the three observed gaps together. A10X acceptance remains open.

| Gap | Source change | Verification boundary |
| --- | --- | --- |
| Live stems appear without an opt-in | Add Live stem separation under Help & About → Test features. Its saved value starts off. | No handle or worker starts while off. Other stem and controller workflows keep their existing activation rules. |
| Mix bypasses output while preparation continues | Cancel the retained worker on Mix, saved Off, or experiment disposal. Preserve the existing single-track, 90-second limit. | Stop publication after cancellation. Keep both decks playing. Prepared audio remains available for the same track. |
| Replay starts enabled | New settings start Off. Explicit saved modes survive. Older files without a recovery field retain replay. | Check new, legacy and explicit Off/Replay/Auto-mix settings through save and reload. |
| Notification centre ignores its switch | Bind toolbar visibility to the existing saved value. Preserve its default and the Settings gesture-guide route. | Check hiding, showing and reopening the app. Do not discard notices when hiding their button. |

Cancellation is cooperative. A running Core ML call can finish before the worker stops.
The output returns to the original mix immediately. The worker must not publish a cancelled result or start another separation window.
The existing stem strip shows Stopping separation during cancellation.
It shows Prepared for cached audio and Original mix outside available coverage after preparation stops.
Closing the drawer alone preserves the selected performance mode. It does not disable the feature.

The current trial retains prepared audio until relaunch. It does not support another separation run within that launch.
This change does not add a new cache manager, engine reset path or background service.

## Where future gaps are likely

These are predictions from the current features and boundaries, not additional observed defects.
Review the relevant row when a request changes that area.
The highest near-term risks combine four decks, live stems, controller layers and simultaneous touch.

| Expansion trigger | Likely UX or UI gap | Real DJ situation | Smallest useful guard |
| --- | --- | --- | --- |
| More decks and controller layers | The visible deck and action target disagree. Controls shrink to fit more information. | The DJ edits C's loop while believing A is selected. | Keep A/C and B/D selection explicit. Verify action ownership. Preserve two-deck geometry when the expansion stays off. |
| More drawers and gestures | Open panels compete for waveform space or take another control's touch. | An EQ adjustment dismisses a loop or becomes a seek. | Reuse panel ownership and cancellation rules. Check the changed gesture with one other active touch. |
| More hidden capabilities | Useful options become difficult to find. Setup requires knowledge of internal feature names. | The DJ cannot find headphone cue before a set. | Place options under existing DJ tasks. Use plain labels and the existing guide before adding shortcuts or another settings category. |
| More modes and bypass states | Closed, bypassed, stopping and disabled look the same. | The DJ selects the original mix but the iPad continues expensive preparation. | Define each state's output and worker lifetime. Use the existing status area for necessary feedback. |
| More asynchronous preparation | Old results affect a new track or undo a more recent choice. | A late result changes the deck after the DJ loads another track. | Bind work to track identity, generation and request. Test cancellation while a result waits to publish. |
| More saved preferences | An update enables features unexpectedly or erases a deliberate choice. | The next gig opens with extra buttons or different track-end behaviour. | Separate fresh defaults from legacy decoding. Check missing fields and every existing saved mode. |
| More deck and global options | A control's scope becomes unclear. A default looks like a live value. | The DJ changes Keylock on load but expects the playing track to change. | Label scope and application timing. Keep immediate deck actions beside the deck. |
| More controller adapters and automatic routes | Connection changes control ownership, layers or cue routing unexpectedly. | A reconnect sends headphone cue to the wrong output. | Keep adapters behind the existing contracts. Check the affected model, route locks and reconnect path physically. |
| Larger libraries and deeper analysis | Progress updates, cache work or long source reads compete with live control. | Loading a long track makes the crossfader stutter. | Keep playback reads urgent. Bound, pause or cancel optional work. Check the affected workload on the A10X. |
| More cloud and imported preparation | A set depends on connectivity, or imported results overwrite accepted corrections. | A network failure removes useful preparation before a transition. | Retain local playback and accepted preparation. Show unresolved state where the DJ needs it. Keep sync outside active performance. |
| More compact controls and gesture-only actions | Touch targets shrink, labels clip, or essential actions become inaccessible. | A quick booth adjustment hits the neighbouring control. | Preserve 44-point targets and meaningful labels. Check the affected pane with larger text and existing accessibility controls. |
| More phone and foldable layouts | A phone shortcut or orientation rule replaces the iPad workspace. | Rotating the iPad moves familiar controls during a mix. | Select layouts from device and screen context. Keep the phone front-screen boundary explicit. |

### Review each expansion before it reaches the live surface

1. Name one DJ task and the smallest change that serves it.
2. State its default, saved scope and activation trigger.
3. Compare the base workspace before and after, with the feature off.
4. Define output and worker behaviour for enable, bypass, close, disable and cancellation.
5. Select one high-risk interaction with an existing feature.
6. Check legacy settings and reject stale asynchronous results where relevant.
7. Verify the changed flow, audio and touch through the focused A10X test loop.

Do not turn this review into a full combination sweep for each small change.
Choose checks from the changed boundaries and record what remains unverified.
Do not add a feature registry, preset system, warning panel or onboarding flow merely to support this checklist.

## Evidence and related guides

The source links support the table and assessment. They do not establish original-app equivalence or current-device performance.

| Reference | Owning source |
| --- | --- |
| <a id="s1"></a>S1 | [Workspace and four-deck gate](Replica/Sources/TDJInterface/ReplicaView.swift), [trial availability](Replica/Sources/TDJInterface/PlaybackSettings.swift) |
| <a id="s2"></a>S2 | [Browser, recordings and six settings groups](Replica/Sources/TDJInterface/BrowserSections.swift), [settings design and remaining checks](docs/coordination/settings-r154.md) |
| <a id="s3"></a>S3 | [Layout and playback defaults](Replica/Sources/TDJInterface/PlaybackSettings.swift), [loop, quantisation and Freeze defaults](Replica/Sources/TDJCore/PerformancePreparation.swift) |
| <a id="s4"></a>S4 | [Deck drawers and presentation](Replica/Sources/TDJInterface/ReplicaView.swift), [live controls](Replica/Sources/TDJInterface/PerformanceControls.swift), [effect state](Replica/Sources/TDJInterface/EffectsView.swift), [effect scope](Replica/Effects.md) |
| <a id="s5"></a>S5 | [Cloud idle guards](Replica/Sources/TDJInterface/CloudPreparationModel.swift), [native analysis scheduling](Replica/Sources/TDJInterface/NativeMusicModel.swift), [library campaign](docs/coordination/library-analysis-r156.md) |
| <a id="s6"></a>S6 | [Recovery default](Replica/Sources/TDJCore/Recovery.swift), [automatic recovery preparation](Replica/Sources/TDJInterface/RecoveryModel.swift) |
| <a id="s7"></a>S7 | [Live-stem handle and closed drawer](Replica/Sources/TDJInterface/ReplicaView.swift), [selection and processing](Replica/Sources/TDJInterface/LiveStemExperiment.swift), [trial limits](docs/coordination/stems-on-device.md) |
| <a id="s8"></a>S8 | [Controller scope and verification limits](docs/coordination/controller-coverage.md), [controller setup](Replica/Sources/TDJInterface/ControllerSettingsView.swift) |
| <a id="s9"></a>S9 | [Visibility key](Replica/Sources/TDJInterface/DeckToolsModel.swift), [settings binding](Replica/Sources/TDJInterface/PlaybackSettings.swift), [unconditional toolbar button](Replica/Sources/TDJInterface/ReplicaView.swift) |
| <a id="s10"></a>S10 | [Application coordination](Replica/Sources/TDJInterface/ReplicaModel.swift), [package boundaries](Replica/Package.swift), [source layout](Replica/README.md) |

Use the [request ledger](docs/coordination/requests.md) for delivery state and remaining work.
Review this guide when a request changes the base workspace, an expansion gate or automatic playback behaviour.
