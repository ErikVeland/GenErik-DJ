# Traktor DJ 1.x feature and interaction inventory

Scope reviewed on 30 October 2026: this document records original-product requirements or dated reference research. It does not certify current replica implementation. See [current shared implementation and verification](../../Replica/Status.md). Original evidence dates and unresolved fidelity requirements are retained.

Each row identifies a capability or an interaction contract. **D** establishes the stated scope only. The final column identifies what still needs measurement on 1.6.8. **V** rows are candidates to investigate, not confirmed features. **P** rows specify the proposed rebuild. Source keys resolve in [Sources and evidence](06-sources-and-evidence.md).

The [performer fidelity specification](15-performer-fidelity-specification.md) sets the priority and replication rules. This full inventory retains ordinary functions as well as performer distinctions. **R2** is the performer's account of genre/history-aware suggestions and observed adaptive rankings. Existing **P** entries remain hypotheses until matched to original behaviour or separately requested. [R3]

## Music browsing and preparation

| ID | Capability or interaction | Evidence | Remaining reference check |
| --- | --- | --- | --- |
| F001 | Swipe upward to browse Songs, Playlists, Artists, Albums and Genre | D S15 0:21–0:38, S1 | Gesture threshold, installed labels, counts and empty states |
| F002 | Touch a track and move its load slider up for A or down for B | D S15 1:21–1:31 | Release/cancel, repeated selection and load protection |
| F003 | Return from browser to deck view after a load | D S1 §5.1.1, controller path | Whether touch loading follows the same rule |
| F004 | Browse while the other deck plays | D S1 browsing workflow | Audio continuity during search and rapid scrolling |
| F005 | Tap destination-deck artwork to open recommendations | D S15 1:34–1:51, S1 | Context after later selection changes, preview and back navigation |
| F006 | Recommend by key/BPM and show green compatibility indicators | D S15 1:51–2:01, S1 | Ranking, thresholds, ties, half/double tempo, unavailable songs |
| F144 | Use timbre analysis in the original recommendation engine as announced by NI | D declared capability S41 | Descriptors, ranking influence and installed implementation |
| F145 | Use genre in next-track suggestions as experienced by the performer | R2 | Exact input source and influence; preserve original behaviour |
| F146 | Adapt recommendation rankings from previous mixes and track combinations | R2, explicitly observed adaptation | Learning signals, ranking rules, model/history state and persistence; internal ML method unrecovered |
| F007 | Warn visually when loading over a playing deck | D S1 flashing controller LOAD | Touch protection, confirmation, preference, overwrite rule |
| F008 | Read the device's music collection | D S1 category workflow | Media permission, local-only items, unavailable files |
| F009 | Search tracks/artists and sort by name, album, artist, key or BPM | D S15 0:38–1:19 | Matching rules, sort direction, keyboard and selection retention |
| F010 | Create a playlist through Edit, track ticks and Add to Playlist | D creation route S15 2:51–3:18 | Naming, empty playlist, save/cancel and installed differences |
| F011 | Batch-add ticked tracks to an existing or new playlist | D addition S15 2:51–3:18 | Removal, reorder, duplicates and deletion meaning remain V |
| F012 | Edit playlist folders or subfolders | V H3 | Actual hierarchy and allowed operations |
| F013 | Analyse the collection in the background when the app starts | D S15 0:51–1:02, S11 0:48–1:06 | Progress, cache reuse, interruption and manual reanalysis |
| F014 | Retain cues and analysis after unloading | D stored cues in S1 | Track identity, app restart, music resync |
| F015 | Preview tracks from the browser without loading | V | Whether present, routing, start/stop and scroll rules |

## Clock transport and quantisation

| ID | Capability or interaction | Evidence | Remaining reference check |
| --- | --- | --- | --- |
| F016 | Play and pause each deck independently | D S1 §5.2.1 | Touch-down/up action edge, quantised start and stop |
| F017 | Tap master BPM and rotate the shared tempo wheel | D S15 2:08–2:19, S1 | Increments, limits, touch response and any tap/numeric input |
| F018 | Let synced decks follow the shared tempo | D S1/S5 | Behaviour with one deck unsynced or stopped |
| F019 | Use a playing-deck tempo fader to change global tempo | D S1 §5.1.8 | Two playing decks, assignment and takeover rules |
| F020 | Select controller tempo ranges 8%, 12%, 25%, 50% | D S1 §5.1.8 | Exact preference and actual endpoint ratios |
| F021 | Reposition controller tempo fader with SHIFT | D S1 §5.1.8 | Relative scale, dead band, pickup and discontinuities |
| F022 | Reset original track tempo with S4 RESET | D S1 §5.1.8 | Effect on clock and the other synced deck |
| F023 | Enable/disable Sync per deck | D S1 §5.2.3 | Default, persistence, behaviour before first playback |
| F024 | Align tempo and beatgrid phase through Sync | D S5 | Whether continuous correction or action-based alignment |
| F025 | Display half-sync when tempo matches but phase differs | D S1 §5.2.3 | Exact thresholds, red state, recovery timing |
| F026 | Press Sync in half-sync to restore alignment | D S1 §5.2.3 | Direction of jump, click suppression, immediate/quantised |
| F027 | Choose a quantise size for Hotcue triggering | D S1 §5.1.2; historical menu/default S21; version-labelled early menu S34 | Installed differences, scope and persistence |
| F028 | Offer quarter-beat minimum in the historical controller workflow | D S1 §5.1.2 | Installed 1.6.8 list. Do not import DJ 2 values |
| F029 | Cycle quantise size with S4 QUANT and show the chosen value | D S1 §5.1.2; touch preferences S21 | Controller order/wrap, installed path |
| F030 | Press Play early and start on the next synced bar | R R1; D period explanation S20 | Preference relationship, bar anchor, pending silence and queue rules |
| F031 | Cancel, replace, or retrigger a queued Play | V/P | Second press, Pause, cue, seek, unload, Sync off |
| F143 | Show a moving lead-in marker before the incoming source waveform scrolls | D S35 near 4:14–4:16; S38 near 3:11–3:13, adjacent-frame reviews | Installed conditions, geometry, audio onset and cancellation feedback. Quantize Size mapping remains V |
| F032 | Start the first track when no other deck plays | D Play capability, exact timing V | Clock stopped/running, adopted tempo, startup latency |
| F033 | Continue or reset the clock when all decks stop | V | Phase and tempo on restart, background/resume |
| F034 | Enable/disable Keylock independently | D S1 §5.2.1 | Default, touch control, pitch anchor and audio quality |
| F035 | Mix manually with Sync and Keylock off | D S1 §5.1.8, S5 | Jog nudge gain, release, independent tempo behaviour |

## Waveform navigation and beatgrid editing

| ID | Capability or interaction | Evidence | Remaining reference check |
| --- | --- | --- | --- |
| F036 | Show main waveform plus a whole-track stripe | D S1 figures | Colour mapping, amplitude scale, playhead geometry |
| F037 | Pinch the red stripe window with two fingers to zoom waveform detail | D S15 2:39–2:48, S1 | Anchor, bounds and per-deck persistence |
| F038 | Scrub the main waveform by touch and return in musical time on release | D S16 0:31–0:45 | Motion curve, inertia and conditions for Flux-style return |
| F039 | Seek a paused deck and retain its selected position | D controller path S1 §5.1.8 | Exact touch path and snap behaviour |
| F040 | Drag the red stripe window to preview another region while playback continues | D S15 2:19–2:36, S1 | Audio preview, markers and cancellation |
| F041 | Release the stripe window, then tap a waveform beat to commit a timed jump | D S15 2:19–2:36. Controller CUE path S1 | Exact quantise rule and cancellation |
| F042 | Exit stripe navigation without seeking | D controller MOVE path S1 | Touch dismissal and restored view position |
| F043 | Set controller beatjump size with the loop-size control when no loop is active | D S5 3:28–3:46, S1 | Touch availability, bounds and quantisation |
| F044 | Open a dedicated grid editor, temporarily with held SHIFT+SYNC on S2/S4 | D S18 2:11–2:26, S1 | Touch entry, commit/cancel and installed layout |
| F045 | Move the waveform against the grid to correct phase | D S11 1:15–1:32, S1 | Sensitivity, fine/coarse controls and persistence |
| F046 | Select the correct downbeat within the bar | D S1 §5.2.3 | Exact four-beat selector and meaning of each choice |
| F047 | Scan in four-beat steps within grid editing | D controller path S1 | Touch equivalent and beginning/end clamp |
| F048 | Correct analysed BPM through half, double and tap functions | D S11 1:32–1:42 | Precision, touch sequence and effect on stored cues |
| F049 | Pinch or magnetically snap within grid editing | V H1 | Whether pinch changes view or grid spacing in each mode |
| F050 | Represent variable-tempo or multiple grid regions | V | Whether supported at all. Do not inherit Pro flexible grids |
| F051 | Retain waveform scale and position between modes | V | Freeze, loop, grid, unload and restart transitions |
| F052 | Arbitrate simultaneous touch gestures | P, original rules V | Scratch versus pinch, two-finger loop, second deck, overlays |

## Cue points and loops

| ID | Capability or interaction | Evidence | Remaining reference check |
| --- | --- | --- | --- |
| F053 | Store and recall cues in eight app Hotcue slots | D S11 2:01–2:16, S1/S5 | Labels, stopped-deck behaviour and grid-slot occupancy |
| F054 | Tap an available cue slot to set a Hotcue on the beat | D S11 2:01–2:16, S1 | Exact action edge, snapping policy and overwrite prevention |
| F055 | Delete a stored cue | D SHIFT+cue S1 | Touch edit/delete mode, confirmation and undo |
| F056 | Store a loop in a cue slot and recall it with a jump plus loop activation | D S1 §5.2.6, S11 2:16–2:21 | Stored fields, pending recall and edit rules |
| F057 | Distinguish cue, loop and grid marker by type/colour | D S1 §5.2.5 | Actual touch palette and editable types |
| F058 | Use a grid marker in the cue system | D S1 §5.2.5 | Slot occupancy, deletion consequences and recreation |
| F059 | Provide load and fade marker categories | D controller colour legend S1 | App creation/editability. Legend alone does not prove controls |
| F060 | Use transport CUE for stop/cue/audition behaviour | D S1 §5.2.2 | S1 and S2 descriptions conflict. Measure exact states |
| F061 | Activate a preset-length loop | D S1 §5.2.6 | Touch button edge, default length, placement anchor |
| F062 | Create a loop with manual IN/OUT | D S1 §5.2.6 | Touch availability, minimum length and rounding |
| F063 | Touch the desired loop region with two fingers to create a loop | D S16 1:18–1:22 | Contact order, chosen endpoints and snapping |
| F064 | Hold a loop and pinch inward/outward to change its length | D S16 1:26–1:31, S1 | Supported lengths and retained anchor |
| F065 | Hold a loop with two fingers and move it | D S16 1:22–1:26, S1 | Step size, audible jump, backwards and endpoint rules |
| F066 | Move a loop by one beat using press-and-turn | D S2 §5.2.6 | Installed hardware mapping and touch equivalent |
| F067 | Exit a loop and continue playback | D capability S1. S16 caption ambiguity | Exact dismissal finger count, exit timing and Flux return remain V |
| F068 | Change default loop size and quantise settings | D historical preferences S21 | Installed menus and persistence scope |
| F069 | Recall a saved cue or loop after reloading the track | D storage capability S1 | Restart, resync, cloud conflict, missing file |
| F070 | Handle loops crossing the start or end of a file | V/P | Clamp, shorten, refuse, wrap, silence or exit |

## Freeze Loop Slicer Flux and SuperSlicer

| ID | Capability or interaction | Evidence | Remaining reference check |
| --- | --- | --- | --- |
| F071 | Toggle the snowflake to freeze waveform scrolling while audio continues | D S16 0:49–1:11, S1 | Region anchor and slice count in each touch state |
| F072 | Let normal playback leave a Freeze region | D S1 §5.2.7 | Waveform follow behaviour after the playhead leaves |
| F073 | Make slice scale depend on waveform zoom | D S1 §5.2.7 | Slice boundaries, subdivisions, minimum/maximum scale |
| F074 | Tap or hold Loop Slicer regions and trigger mapped controller slices | D S16 1:31–1:49, S1 | Release, gate/one-shot and quantisation in each mode |
| F075 | Move Freeze assignments by a group or slice | D S1 §5.2.7 | Touch drag, controller steps and playhead interaction |
| F076 | Enable Freeze inside a loop for Loop Slicer, then toggle Freeze to leave slicing | D S16 1:31–1:51, S18 1:10–1:39 | Touch slice count, release and loop-exit rules |
| F077 | Distinguish Loop Slicer and Freeze visually | D controller green/blue S1 | App colours, icons, waveform and mode indicator |
| F078 | Enable Flux per deck, with Flux default-on in NI's controller slicing demonstration | D S1, S18 1:22–1:28 | Touch control, app-wide default and persistence remain V |
| F079 | Keep a continuing position during Flux manipulation | D S5 | Scratch, cue, loop and combined-operation return rules |
| F080 | Resume at the continuing position after release | D S5 | Which release owns the return with overlapping fingers |
| F081 | Offer SuperSlicer in later 1.x with a Features category visible in its announcement | D S10 description and 0:16 frame | Installed unlock, exact entry, purchase/restore and offline state |
| F082 | Apply SuperSlicer Scratch, Brake, Reverse, Slice and Pitch-shift | D names S10 | Exact mapping, rates, intervals, release and touch count |
| F083 | Offer SuperSlicer mode buttons and vertical action zones | V H1 | Full mode list, zone boundaries, two-finger override |
| F084 | Exit performance modes without losing the intended musical position | P, original transitions V | Flux off/on, loop active, paused, queued command |
| F141 | Provide a separate Slicer Quantize switch | D visible S21 | Exact scope, default and persistence |
| F142 | Provide Freeze on Load | D visible S21 | Trigger conditions and installed behaviour |

## Mixer filter and effects

| ID | Capability or interaction | Evidence | Remaining reference check |
| --- | --- | --- | --- |
| F085 | Mix two deck levels through the crossfader | D S1 §5.1.3 | Vertical touch geometry, curve, centre attenuation |
| F086 | Set per-deck volume independently | D S1 §5.1.3 and p77 | Touch scale, numerical range and smoothing |
| F087 | Adjust per-deck gain using supported hardware | D S1 §5.1.4 | Touch gain access, autogain, headroom, reset value |
| F088 | Reset S4 channel gain by pressing its encoder | D S1 §5.1.4 | Exact reference value and interaction with autogain |
| F089 | Open EQ from the right with Low, Mid, High and Volume. Tap centre to reset EQ | D S16 3:11–3:35, S1 | Reset hit area, exact drag law and volume-reset behaviour |
| F090 | Process three EQ bands | D S1 §5.1.5 | Crossover, boost/cut, kill depth and clipping response |
| F091 | Open a dedicated filter XY surface | D S4 | Entry/exit and whether it replaces the EQ view |
| F092 | Use X for low-pass/high-pass cutoff | D S1/S4 | Centre dead band, frequency curve, enable/disable |
| F093 | Use Y for filter resonance | D S4 | Curve, limits and touch pickup behaviour |
| F094 | Retain filter Y through bypass and app shutdown | D S4 | Per-deck scope, default X and state restoration |
| F095 | Open FX from the left, tap an effect, or hold and drag its selector down for choices | D S16 2:27–2:49, S1 | Installed choices and selection persistence |
| F096 | Offer three effect slots with eight choices in early documentation | D S1 §5.3 | Installed menu differs by version/unlock state |
| F097 | Use FX X for effect-specific parameter | D S1 §5.3.2, S4 | Per-effect ranges, beat divisions and interpolation |
| F098 | Use FX Y for wet/dry or intensity | D S1/S4 | Wet/dry law and position on enable |
| F099 | Retain FX Y through bypass and app shutdown | D S4 | Per-effect/per-slot/per-deck scope |
| F100 | Lock the filter in place and inspect separate FX lock controls | D filter lock S16 3:38–4:01, visible FX controls S1 | Exact toggles, retained values and FX-lock semantics remain V |
| F101 | Engage three FX simultaneously through S2/S4 | D S1 §5.3, S5 | Touch-only limit, routing order, shared dry/wet |
| F102 | Store one FX group with SHIFT+MODE and recall with MODE | D S1 §5.3.2 | Stored contents, per-side scope and restart persistence |
| F103 | Offer later extra effects | D generic addition S14, names V H3 | Iceverb, Transpose Stretch, Reverse Grain, unlock prompt |
| F104 | Keep sound active when its drawer is hidden | D hardware control S4 | Latch, display badges, touch-only behaviour |
| F105 | Continue the demonstrated delay tail after stopping its source deck | D S16 2:58–3:11, S17 3:44–4:04 | Other effects and bypass/pause/seek/crossfade tail rules remain V |

## Monitoring audio routes and controllers

| ID | Capability or interaction | Evidence | Remaining reference check |
| --- | --- | --- | --- |
| F106 | Send Master and Monitor to separate stereo output pairs | D S6 | Channel selectors, pair order, invalid combinations |
| F107 | Select a deck for headphone pre-listening | D S6 | Independent A/B toggles, cue tap point and master isolation |
| F108 | Blend cue and master in headphones | D S3/S6 | Blend curve, endpoint behaviour, both decks unselected |
| F109 | Adjust master and headphone levels | D S3/S6 | Hardware versus software volume and persistence |
| F110 | Offer a split-output cable mode | V H5 | Exact mono channels, downmix, balance and swap option |
| F111 | Explain a newly connected audio interface | D S6 | First-use panel, subsequent connections, dismissal |
| F112 | Stream audio through class-compliant Core Audio devices | D S7 | Exact tested model, OS, power and adapter combination |
| F113 | Integrate original Z1 controls | D S3/S4 | Firmware, takeover, connect order, charging |
| F114 | Use Z1 MODE+ON to switch Filter/FX control | D S4 | Separate deck state and LED transitions |
| F115 | Use Z1 MODE+CUE A/B for Play/Pause | D S3 §4.1.7 | Whether combo also changes headphone cue state |
| F116 | Integrate S2 MK2 and S4 MK2 transport and performance controls | D S1/S2 | Exact 1.6.8 mappings and unsupported controls |
| F117 | Mirror hardware changes in app UI | D S1/S3 | Touch-to-hardware feedback and parameter pickup |
| F118 | Integrate AUDIO 2 MK2 | D S7/S9 | Control subset, routing, headphone signal and power |
| F119 | Route into Audiobus or Inter-App Audio workflows | L1 entitlement, V behaviour H2/H6 | Source/filter/output role, remote transport, sample rate |
| F120 | Recover from hardware disconnect or audio-route change | V/P | Pause/continue, speaker fallback, clock and recording state |

## Recording history persistence help and lifecycle

| ID | Capability or interaction | Evidence | Remaining reference check |
| --- | --- | --- | --- |
| F121 | Record the performed mix internally | L2, D S13 | Tap point, start edge, limits, output format options |
| F122 | Save a WAV recording and companion tracklist | L2 | Naming, pairing, rename, delete and finalisation |
| F123 | Write tracklist names, artists, IDs and start times | L2 | Timing units, threshold, deck distinction and repeats |
| F124 | Browse saved recordings and load a recording into a deck for playback | D S34 17:21–17:52, captions and selected frames | Installed touch path, scrubbing and cue routing. Dedicated preview behaviour remains open |
| F125 | Export recordings through shared documents | L2 | UI export workflow, XML handling and destination options |
| F126 | Upload a recorded mix to Mixcloud | D historical S13/S14 | Current availability, login, metadata and failure handling |
| F127 | Create history playlists while performing | V H1 | Session boundaries, duration threshold, order and duplicate rules |
| F128 | Back up/sync grid, cue, BPM and key metadata through iCloud | V H2/H7 | Enabled state, conflict rules, identity and actual file |
| F129 | Historically exchange preparation metadata with Traktor Pro through Dropbox in both directions, without audio files | D S11 2:21–2:46 | Later removal, version scope and current availability |
| F130 | Keep local performance usable while cloud is unavailable | P, reference V | Offline launch, library and cues after long disconnection |
| F131 | Offer step-by-step feature guidance in Notification Centre | D S15 3:23–3:29; original help screenshots S31 | Complete catalogue/messages, completion triggers, replay and dismissal |
| F132 | Expose all app preferences and defaults | V full tree. Historical screens D S10/S21 | Installed tree and defaults with hardware connected/disconnected |
| F133 | Continue playback when app is in background | V | OS/version, lock screen, interruptions and route changes |
| F134 | Restore a session after ordinary relaunch | V | Loaded decks, playback, clock, positions, effects and drawers |
| F135 | Handle local files that disappear or cannot decode | V/P | Message, disabled controls, retained preparation data |
| F136 | Handle library permission denial or revoked access | V/P | First launch, retry path and audible session impact |
| F137 | Handle interrupted, failed or low-space recordings | V/P | File recovery, error state and audio continuity |
| F138 | Support the reference's display orientations and layouts | V | Portrait/landscape, rotation, supported iPad sizes |
| F139 | Reconcile simultaneous touch, hardware and queued events | P, original rules V | Ordering, priority, stale-event rejection and visual feedback |
| F140 | Preserve a stable local performance session during long use | P, original limits V | Thermal load, memory, waveform cache growth and glitches |

## Settings inventory to capture

Do not create settings merely because another Traktor product has them. Capture actual labels, defaults, legal values, visibility conditions, and persistence for:

- Master tempo controls, reset, adjustment precision, and any sync options.
- Quantise size, Slicer Quantize, Freeze on Load, default loop size, tempo range, keylock, and Flux defaults.
- Audio device, Master/Monitor outputs, split output, output levels, and any latency controls.
- Autogain, limiter, EQ/filter options, crossfade curve, or other mix settings **if present**.
- Analysis and library refresh behaviour, BPM range, key notation, and reanalysis **if present**.
- Recording format, destination, file management, and upload options **if present**.
- iCloud, any residual Dropbox option, data backup, and restore behaviour.
- Hardware-specific options, in-app unlocks, restore purchases, help, notifications, and About/version.

For each setting, record whether it belongs to the app, a deck, a track, the current session, or a connected controller. A remembered parameter is part of the experience even when there is no visible preference for it.
