# Controller catalogue tools

These tools reproduce the R169 source inventory, R175 completion states and reviewed factory MIDI profiles.
They use Python 3.9 or later and the standard library. No package installation is required.
The repository has no controller-generation script in `package.json`, so these tools run directly.

## Sources

`sources.lock.json` pins all 317 Mixxx reference files by Git revision, Git blob hash and SHA-256.
It also retains the 121 reviewed Serato iOS model rows and their source-page hash.
`curated.py` records independently checked manufacturer MIDI facts for the next popular models.
`cdj.py` records factory MIDI facts for six club players, with separate tables for each generation.
`players.py` adds nine XDJ and earlier CDJ profiles. It also records the shared CDJ-400/CDJ-400-K variant reference.
`controllers.py` adds XDJ-AZ, RX3, XZ, DDJ-FLX6, DDJ-800 and DDJ-SB3 core profiles from hashed factory tables.
It keeps their pad channels, loop messages, mixer direction and feedback differences explicit.
`ddj_family.py` adds SX3, SX2, SX, RX, RZ and RZX core profiles. SR2 retains a source record and an explicit bank-routing gap.
The original SX deck-D filter stays unmapped because its published CC32/64 pair conflicts with Browse.
R180 extends those tables to DDJ-1000SRT, SZ2, SZ and XDJ-RX2. `legacy_xdj.py` keeps the original RX separate.
The RX recipe remains manual because the factory table has no Load message. The table also specifies no MIDI output.
REV7 retains a web-reviewed source record. Motor, platter, display and lifecycle work remains open.
`entry.py` adds SB2, SB, RB, RR, 200 and WeGO4 facts. It retains their deck, pad and mixer differences.
SB, SB2 and RR send their documented application-connect message. SB Vinyl Off touches can release a scratch without starting one.
SX, SX2, RX, RZ, RZX, SZ and SZ2 also send the published application-connect packet. Each session sends it once and repeats it after reconnects.
The downloaded references have SHA-256 hashes. Two manuals retain web-reviewed text and null document hashes.
Their records state this evidence limit. A document URL is not a content hash.

The source boundary includes every pinned Mixxx definition, the published Serato iOS list, reviewed manufacturer additions, existing NI adapters and Beatpad.
It does not assert coverage of every controller ever sold.
Virtual endpoints, protocol families, accessory models and DVS-only models retain separate roles.

## Regenerate the catalogue

Run these commands from the repository root.
The first command downloads public references when the cache is absent.
It verifies each pinned Git blob before writing the manifest.

```sh
python3 tools/controller_profiles/fetch_reference.py TestBuilds/r169/upstream
python3 tools/controller_profiles/build_catalogue.py \
  --cache TestBuilds/r169/upstream \
  --catalogue docs/coordination/controller-catalogue.json \
  --runtime Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json
python3 tools/controller_profiles/report.py
python3 -m unittest discover -s tools/controller_profiles -p 'test_*.py'
```

To verify the original Serato HTML snapshot, add `--serato TestBuilds/r169/serato-ios.html` to the build command.
The tool rejects a different page hash or different model rows.
The locked rows allow offline reproduction without that HTML file.

Do not update the revision or source hashes without reviewing the resulting protocol changes.
Preserve earlier snapshots and failed validation evidence.

## Conversion rules

- Translate explicit XML input and output facts to existing app actions.
- Preserve A/B/C/D targets, channels, message kinds, inversion and documented relative encoding.
- Require a matching group, key, channel and low byte for each high-resolution CC pair.
- Reject conflicting physical addresses and unknown encodings.
- Retain a disposition for every source input and output row.
- Translate only explicitly reviewed script handlers, then verify the hash-locked source before generation. Never execute controller JavaScript.
- Select an imported recipe automatically only when it has the required core controls and a reviewed lifecycle.
- Track complete theoretical implementation separately from physical verification.

Manufacturer adapters can select reviewed core controls automatically.
Their extra pad modes, displays, FX, motors, audio routing and hardware acceptance remain separate work.
Inpulse 200, Inpulse 300, Starlight and the existing Inpulse 500 adapter send reviewed startup/shutdown messages.
They require one paired physical output. A failed startup leaves their controls inactive.
`reviewed.py` translates their documented jog and touch handlers through existing native actions.
Unknown handlers, including the unresolved Inpulse 200 `scratchPad` reference, stay unmapped.

## Club players

CDJ-3000, CDJ-3000X, CDJ-2000NXS2, CDJ-1500X, CDJ-2000NXS and CDJ-900NXS have automatic MIDI core profiles.
XDJ-1000MK2, XDJ-700, XDJ-1000, CDJ-2000, CDJ-900, CDJ-850, CDJ-350, CDJ-400 and CDJ-TOUR1 also have automatic core profiles.
The order balances established models and recent releases. It does not claim measured global sales ranks.
The hardware must enter Software Control / USB-MIDI mode. The app does not select that hardware mode.

Player inputs accept all 16 MIDI channels on their own physical endpoint.
Two players receive separate A/B assignments, even when their MIDI channel settings match.
The app retains connected assignments, then restores saved endpoint identities, then allocates free decks.
Deck selection swaps occupied assignments. It releases held touches and clears input state before rebinding.
Player enable choices and learned mappings remain specific to each endpoint identity.
Changed endpoint identities receive available assignments. The app does not infer a physical unit from its model name alone.
C/D require the existing four-deck trial. Extra players remain outside automatic assignment when both base decks are occupied.

The decoder treats published jog speeds as speeds. It keeps their exact stop and direction values.
Needle position zero is a release message. It must not seek to the file start.
Fixed loop and jump buttons retain their own beat counts. They use the app's existing timing and Sync rules.
Variable-size jump buttons use the app's selected beat size because their MIDI messages do not report the hardware selection.
Tempo uses the app's existing ±8% range. Hardware tempo-range switching remains open.
The CDJ-350 reverse platter follows its published asymmetric range. Physical verification of that assumption remains open.
CDJ-400 uses a centre-64 browse encoder. XDJ-1000 and XDJ-1000MK2 keep separate jump-address tables.
The 350/400 loop buttons divide and restore the original loop length. Their inactive-loop action starts the app's selected loop size.
CDJ-400 Reloop also restores the original length. Track changes and replaced loops invalidate the saved division state.

These tables specify MIDI input. They do not establish HID authentication, screen output, lighting or audio aggregation.
Those functions and unimplemented modes remain explicit gaps in the catalogue.

## Theoretical completion

The target is documented software support for every physical model in the catalogue.
A model needs complete protocol, control, lifecycle, feedback and audio-routing implementation, with automated fixtures for that scope.
Partial mappings stay partial until those criteria pass.

Physical verification has a separate status. It is not required for theoretical completion of every controller.
An implemented controller can remain physically unverified.
The shared A10X audio and touch baseline still requires actual device evidence.
Use representative connected controllers to check hardware assumptions when they are available.

## Reuse and distribution review

Mixxx source files use GPL-2.0-or-later. The lock file links the exact upstream files and licence.
The app does not bundle or execute those scripts.
Independently normalised protocol facts do not, by themselves, settle distribution obligations.
Complete source-reuse review before release and retain all applicable notices.
Manufacturer documents retain their owners’ rights.

## Validation scope

Python checks verify identity, source completeness, row accounting, address conflicts and deterministic generation.
Focused Swift checks verify catalogue decoding, automatic matching, four-deck targets, learning, feedback edits and device lifecycle messages.
Native iPad compilation checks the active target without simulator packaging.
These checks do not replace a signed app, physical-controller tests or A10X audio and touch acceptance.

MC6000MK2 uses factory A/C/B/D transport channels and native MIDI pitch-bend tempo.
Its side-wide Shift identifiers survive bank changes. The identifiers apply only to declared Shift note inputs.
The zero/127 browser encoder rejects other counts. Its jog decoder treats zero as neutral.
Optional feedback `offNumber` selects a separate CC trigger for binary lights. The LED identifier stays in the value byte.
Existing outputs without this field retain their previous packets. Invalid fields cannot enter the catalogue.

MC7000 keeps the pinned jog threshold `0x64` in a dedicated decoder. Do not substitute another controller’s signed midpoint.
Its tempo inputs use explicit low controller 119 and independent decoder state per deck. Physical calibration remains open.

The original Mixtrack and Pro retain their separate source tempo curves and original-generation mixer/touch addresses.
The original model requires the qualified name `Numark MIXTRACK`. A generic `MIXTRACK` endpoint cannot select it automatically.

The original Party Mix has sensorless wheels. Its core profile maps native wheel-side jogging and leaves timed Scratch open.
Four Hot Cues per deck require the Hot Cue pad mode. Other modes block those actions. Pad lights remain open.

DDJ-T1 uses the original factory manual and its own signed jog pairs. The S1 platter addresses do not apply.
Ambiguous needle endpoints and mixer LED channel variables remain unmapped. Deck/Shift buttons emit no MIDI.

Pioneer pad accessories retain the `accessory` role and do not consume club-player deck allocation.
XP1/XP2 use alternating pad channels. SP1 uses consecutive pad channels and separate mode note ranges.
XP software-mode negotiation remains open. Only SP1 sends its published application-connect packet.

Party Mix II uses separately pinned community references. It has actual touch messages and different Browse/mode addresses.
The newer secondary source declares AI-assisted development. Advanced lamp/jog setup and heartbeat commands remain outside the native recipe.
The original Party Mix profile remains unchanged. Live, III and Pro need separate source review.

Loop-pad modes use a bounded beat argument and a separate native action. Changing pad size keeps an active loop.
Reselecting its actual grid length exits it. Existing fixed-loop and loop-toggle actions retain their behaviour.
Party Mix generations keep different loop modes and beat sizes. Pro FX shifted roll notes remain unmapped.

Terminal Mix 2/4 retains its shared profile ID and separate physical-model records. Saved family settings keep their key.
Its loop encoder accepts only 65/63. Pitch and crossfader centre rules follow the pinned common helper.
Reviewed shared names use the existing model splitter. Do not invent a physical model for a combined source name.

## Relative jog calibration

A relative jog input can specify counts per revolution in `argument` (16–65536).
Absolute speed reports cannot specify this value. Missing values use the generic 1024-count sensitivity.
R203 records published DDJ-T1, Terminal Mix and Party Mix counts. Other profiles require calibration review.
The player retains raw counts, flushes movement before touch release or Load, and stops idle movement after 50 milliseconds.
Physical calibration and A10X acceptance remain open.

## Reviewed classic Numark scripts

Total Control and Omni Control reuse the pinned XML and reviewed normal-mode jog/browser facts.
Their jog addresses differ. Both source scripts use the `NumarkTotalControl` namespace.
Global browser facts require a Library or Playlist group. Relative jog facts can retain a published resolution.
The recipes leave unsupported script modes unmapped and record the remaining work in their scope.

## Reviewed MIX channel correction

The MIX shifted-wheel script routes MIDI channels 4 and 5 to decks A and B.
Its XML incorrectly labels both groups as Channel1. The reviewed handler includes the exact channel-to-deck table.
The importer rejects channels outside that table and retains the original source row beside the corrected binding.
The shifted resolution retains the source's fourfold seek multiplier. MIX ULTRA receives no inherited recipe.

## DJ2GO2 Touch source differences

The Touch recipe preserves its own exact identity, MIDI addresses, status query and component-helper tempo direction.
Its jog decoder keeps raw 64 positive. The browser accepts only single 1/127 steps.
Published note ranges separate Hot Cues, automatic loops and manual loops without a software pad-mode guess.
Manufacturer labels assign Gain and Browse press. The source script instead assigns filter and preview functions.
The official indexed guide supports the labels, but direct PDF downloads failed. The related source records a null hash.
The non-Touch model receives no inherited controls. Remaining Cue preview, deletion, sampler and audio routing work stays explicit.

## Momentary Cue preview

R207 uses `cuePreviewA/B` for the three reviewed Numark mappings with standard press/release Cue messages.
The native player reuses the existing NI Cue contact contract. Play latches a preview, and release or disconnect returns to Cue.
Generation and gesture ownership checks protect replacement tracks and newer touches. Saved Sync remains unchanged.
`cueReturnA/B` retains its existing return/set behaviour for custom bindings and profiles awaiting review.

## Reviewed Pioneer Cue migration

R208 changes release-capable Cue note bindings to `cuePreviewA/B` in the reviewed Pioneer data and code profiles.
It preserves every address, channel, setup message, feedback binding and profile ID.
The automatic-profile fixture checks both standard release forms across all 57 profiles with a Cue control.
Player reassignment releases the old Cue contact. Existing saved custom mappings retain their explicit action.
Pioneer pad accessories have no transport Cue. XDJ-RX remains a manually selected partial recipe.

## Standard Cue note contract

R209 extends native preview to the remaining reviewed factory Cue notes and imported `cue_default` note bindings.
The importer requires ordinary, non-inverted note semantics. It preserves Control Change and inverted bindings as Cue return/set.
All 81 automatic factory profiles with standard Cue notes have both note-release forms in the native fixture.
Hercules DJ Console Mac Edition keeps its existing Control Change Cue action until release behaviour is verified.
The three Pioneer pad accessories have no transport Cue. This migration changes no setup, feedback or input addresses.

## NS4FX banks and modifier pickup

R210 reuses the pinned NS4FX XML, script and component helper facts. It executes no controller script.
The native recipe uses the labelled 9/41 tempo pair and component deck channels, with source inconsistencies recorded in its reference.
The wrapped jog decoder retains the source's 1240-count resolution. Physical calibration remains open.

Optional `bankChanges` entries identify a positive note report with `channel`, `number`, `onValue` and `decks`.
The schema permits at most 16 unique addresses and one to four unique decks per scope.
Each report flushes pending controls, releases that side's contacts and resets its pickup and decoder state.
The other side retains its state. Learned deck actions keep the same bank protection.
Player profiles cannot use this metadata because player assignment already has its own lifecycle.

Shift changes reset pickup only for affected layer controls. Independent controls retain their state.
A release without a matching held controller contact cannot end a waveform gesture.
Core protocol fixtures, native transport checks and iPad compilation cover these rules. Hardware acceptance remains open.

## MC7000 physical Shift identities

R211 adds published active Note 8 bank reports to the existing MC7000 recipe.
Shift input 0 spans channels 0/2 and decks A/C. Input 1 spans channels 1/3 and decks B/D.
Each side keeps its logical scope when a held button changes MIDI channel.
Bank reports reset pickup and contacts on that side through the shared contract.
The source MIDI addresses, tempo pair, unusual jog threshold, setup and feedback remain unchanged.
Saved custom bindings retain their stored fields. Physical acceptance remains open.

## Mixstream Pro counter and model boundaries

R212 adds the original Mixstream Pro after Computer Mode selection, supported by the hashed manufacturer guide.
Transport channels 2/3 differ from mixer channels 0/1. Tempo uses the explicit 31/75 pair.
Jog 55/77 is an absolute counter. It primes, combines boundary changes and rejects jumps above 45 counts before emitting relative movement.
The source scale is 10 milliseconds per count. Native movement uses the equivalent 180-count resolution, pending physical calibration.
The structured format requires an explicit low byte and stays outside partial MIDI learning.

Profile names now retain plus characters. Optional `excludedAliases` bounds a profile against known, unverified model variants.
The schema permits at most 24 non-empty names with at most 128 characters each.
The original Pro excludes Pro+ and Go even when a generic base port name also appears.
No pads, screen or variant compatibility is inferred from the shared family user guide.

## Paused count jogs and Sync

Relative jog packets retain fractional intent on a paused deck. Native transport timing still aligns each requested seek when Sync is enabled. Other transport actions, track generations and resolution changes reset the saved intent. This prevents small movements from rounding away indefinitely. Physical platter calibration remains separate.

## FLX10 factory-table migration

FLX10 retains its original profile ID and aliases in a generated data recipe. The catalogue name stays separate from that stored ID. Four deck targets, bank reports, physical Shift identities, Load and core feedback use the factory MIDI list. The official function diagram supplies context-dependent loop buttons and four/sixteen-beat jumps. Shifted jog reports edit the grid and remain unmapped. Saved custom mappings keep their stored actions. Full modes, stems, screens, remaining feedback, cleanup, routing and jog calibration remain open.

## Original DDJ-1000 factory-table migration

The original 1000 retains its profile ID in a separate factory-table recipe. Normal Sync, tempo and four-beat loop use Note 88, CC 0/32 and Note 20. The earlier code used shifted addresses. Note 114 on channel 2 reports either left-bank change. Channel 3 reports either right-bank change. These switch events protect pickup and contacts without inferring the initial active bank. The SRT and FLX10 retain separate recipes and source hashes. Context-dependent loops reuse the native loop contract. Screens, remaining modes, feedback, cleanup, routing and calibration remain open.

## Manufacturer inventory additions

`manufacturer_inventory.py` records manufacturer-confirmed products outside the pinned software inventories. These records establish model existence only. They do not create runtime recipes or imply protocol compatibility. Keep the wider market-audit flag separate from the bounded source-inventory completion flag. Catalogue additions must retain incomplete implementation and acceptance states until their own protocol work passes.

## Jogvision factory commands

Jogvision uses a separately reviewed recipe. CC 126 sets Scratch mode and CC 127 requests current analogue and keypad-mode reports. The pinned script's LED-clear comment for CC 127 is inaccurate. Do not copy its shutdown track-eject side effect. Modifier guards cover both Shift and Mode. The factory separates Hot Cue, sample and delete note ranges. The native jog path uses the pinned 400-count resolution. AIR filtering, extra modes, rings, complete feedback, cleanup, routing and physical calibration remain open.

## Inpulse 300 MK2 source boundaries

The MK2 recipe reuses hardware facts from the pinned community revision and the separate manufacturer guide. It does not copy the fork's software four-deck bank or stem/FX code. Conflicting pad address zero and the fork's custom IN action remain unmapped. Normal/shifted touch channels stay separate. A held jog retains its intended frame when its count resolution changes. Momentary edge detection uses active source ownership across alternate release addresses. Full modes, feedback, cleanup, routing and physical calibration remain open.

## Inpulse 200 MK2 source boundaries

The separate recipe uses a published iOS mapping and pinned controller definitions. Keep its physical two-band EQ and gain assignments. The second author's custom three-band EQ, software banks and jog packet throttling do not enter the runtime. Seven-bit tempo retains exact centre and pickup protection. Shift guards tempo repositioning. Separate delete-page releases rearm the corresponding Hot Cue without firing a cue or delete action. Other pad pages remain separate. Do not infer the 300 MK2's tempo LSB, jog resolution or startup packets. Full modes, feedback, cleanup, routing and physical calibration remain open.

## Beatmix 2/4 factory facts

The shared factory table covers original Beatmix 2/4 hardware and appears on the MK2 product page. Keep the stored family profile ID and exact model aliases. Use factory 1/127 jog counts and 800-count resolution. The pinned script's value-minus-64 handler conflicts with that table. Play and Sync feedback addresses differ from input addresses. Native pad functions retain four cues and four fixed loops. Separate sample pages stay unmapped. Bank events rearm shared pitch pickup and release contacts on their own side. Physical Shift survives bank changes. Shifted releases rearm normal buttons without executing unsupported alternatives. The optional delayed query, full cleanup, remaining modes, routing and physical calibration remain open.

## MC2000 factory facts

Use the factory command table and channel-range diagram for this separate two-deck recipe. The right gain uses channel 1 CC 12. Jog touch uses Note 81. Use hexadecimal addresses when a decimal column conflicts. LED messages have separate trigger controllers and identifiers. Keep native fourteen-bit pitch, centre pickup and standard held Cue. Do not copy the source's gain-as-filter, arbitrary jog sensitivity, Shift lock, crossfader Sync, forced PFL or startup mixer-level resets. Manual and adjustable loop boundaries, remaining modes, complete feedback, cleanup, routing and physical calibration stay open.

## Mixon 4 factory facts

Keep separate deck/mixer channels 4–7, pad channels 0–3 and global channel 10. The published TSI confirms normal jog/touch addresses and unflipped absolute pitch inputs. The reviewed TSI reader remains a local evidence tool. The app receives only protocol facts. Use the factory single-step 65/63 loop decoder and RGB values 3/67 for full/dim blue Hot Cues. Preserve the app's C/D opt-in and existing hardware deck restrictions. Factory bank reports protect pickup and contacts on their own side. Do not infer Mixon 8 Pro support. Extra modes, assignments, complete feedback, cleanup, routing and physical direction/calibration remain open.

## Dicer source boundaries

The native accessory recipe retains the stored ID, five cues and separate cue/loop/orange channels. Shifted delete releases rearm normal pads. Shifted green pads select fixed loops. Orange Cue uses native held preview. The source reset packet covers startup and shutdown. Do not copy the old script's roll implementation, transformer timers, forced gain changes or rewind effects. Its own notes describe loop erasure, timing drift and an audio pause. Default rolls, browser step buttons, extra effects, complete feedback and physical acceptance remain open.

## NS6II core and USB release reports

Use XML dispatch for actual input addresses and the pinned script for scales and source behaviour. NS6II has paired tempo, 1,000-count jogs and shared pad addresses. Native pad pages require explicit mode guards. Leave shared pad lights unmapped until output mode guards exist. Physical Shift also contributes to a shared modifier for Load/browser alternatives.

Bank records keep their existing positive-event behaviour. Optional `releaseShiftChannels` explicitly enables an ownership-loss release on that report address. The array names declared physical Shift scopes. A release clears contacts on the recorded decks and removes only those Shift inputs from local and shared layers. Other held modifiers remain active. Empty arrays enable contact-only release. Ordinary bank note releases stay ignored. Bounds, duplicates and undeclared Shift scopes fail catalogue validation.

## N4 state and bank reports — R227

`n4.py` retains the reviewed XML dispatch, source scales and explicit mixer address gaps.
The original endpoint alias remains valid. Native momentary physical-side Shift replaces the source's software latch.
The shared browser also uses those stable physical Shift identities.
The upper four buttons retain the published custom loop layout. The lower four buttons provide the initial Hot Cue page.
Do not copy unit-specific EQ offsets, software cue pages or the invalid commented shutdown packet.

`cueStateA/B` applies latched PFL state directly, including zero. It uses no toggle edge or pickup.
Do not send N4 PFL feedback because the hardware echoes those lights into its inputs.
`loopEnableA/B` enables the selected native loop and leaves an active loop enabled.
The NS6II Loop page also uses this explicit action.

A bank definition defaults to Note and requires an explicit positive `onValue`.
An explicit `kind: control` may omit `onValue` to accept every raw report at its own address.
Control Change bank reports cannot declare note-release Shift cleanup.
The receiver resets only the declared side. Ordinary Note release behaviour remains unchanged.

## NEON accessory pages — R228

`neon.py` uses the factory MIDI table and manufacturer-hosted Reloop/Serato guides.
The first Hot Cue page has distinct pad addresses on channels 7–10. Other hardware modes cannot trigger those cues.
Shifted delete releases only rearm the corresponding pad. Pressure messages do not retrigger cues.
Manual Loop pad 1 toggles the loop. Pads 5/6 capture native boundaries, and pad 7 uses Reloop/Exit.
The active-loop boundary-edit mode and shared encoders remain open.

Do not infer C/D Sync addresses from the conflicting factory rows.
Do not map shared Load/encoder messages without the Sampler context.
The setup packet enables hardware C/D selection. App deck availability remains authoritative.
NEON is an accessory with no audio interface. Other modes, colours and full cleanup remain open.

## Compact Vestax controls and browser buttons — R229

`vestax_compact.py` keeps separate Spin and Typhoon XML/script source hashes.
Both native recipes use fixed touch scratching with 300 counts per revolution.
Typhoon accepts both published jog/touch addresses. Spin uses only the addresses its script handles.
The Typhoon Filter hold guards its jogs. It does not enable an unimplemented filter mode.
Typhoon retains four-beat loop/halve/double buttons. Spin retains manual In/Out and Reloop/Exit.
Seven-bit tempo preserves the source polarity and uses an exact native centre at 64.
Alternative modes, complete lights, cleanup, routing and physical calibration remain open.

Use explicit `browsePrevious/Next` and `browsePreviousGroup/NextGroup` for momentary browser buttons.
Each press queues exactly one signed step through the existing browser queue.
Do not interpret a positive note velocity as an absolute encoder position.
Dicer now uses the same contract for its orange-page track and group buttons.

## Original RP-8000 MIDI accessory — R230

`rp8000.py` uses the original factory manual and published Scratch Live/Traktor mappings.
The manual supplies all eight cue addresses. The mappings confirm loop lengths, centre-64 browsing and five cue-light pairs.
CH-1–4 maps to A/B/C/D. Hardware TT Link assigns those channels automatically.
Independent units on the same channel need different hardware channel selections. Automatic endpoint assignment remains open.
The app's deck availability still guards C/D.

Distinct pad addresses keep Sample and User modes separate. Held mode-button releases only rearm pads.
Do not map optional analogue/motor MIDI messages as native transport or platter input.
Do not infer MK2 or Straight support from the original table.
Remaining modes, three cue-light pairs, displays, full cleanup and DVS/audio routing remain open.

## Scratch pulses, startup and saved metadata — R231

`scratch.py` retains actual XML dispatch and hashed script/component/factory-guide sources.
The factory guide confirms loop on/off. The shared push handler applies received PFL on/off state directly.
Native cue-state actions preserve it. Conflicting PFL output channels remain unmapped.
Shared pad addresses need Cue/Sampler/Roll mode guards. Pad lights need separate output mode guards.
Hardware master and headphone gain controls remain outside the software mixer.

Only explicit `pulse: true` note buttons bypass rising-edge suppression.
Pulse inputs must use absolute encoding and cannot be momentary, Shift or release-only bindings.
Each positive encoder note applies once. Standard note releases never invoke a pulse action.
Physical Shift selects single-step browsing and Load. Unshifted presses toggle the loop.

Factory startup prepares bindings, connects input and then sends bounded setup packets.
A failed connection sends no setup and removes the failed factory session. Later discovery can retry.
CoreMIDI replies enter the inbox and drain after startup completes.
Preserve mode, release, Shift, explicit low-byte and pulse metadata when restoring custom mappings to a new endpoint ID.
FX, rolls, sampler, complete lights, curve/reverse, cleanup, DVS, passthrough and audio routing remain open.

## Reviewed automatic audio outputs — R232

An automatic data profile may declare `audioOutput: masterAndHeadphones` only after an audio-layout review.
This layout means master channels 1–2 and headphone channels 3–4. The native renderer already supports it.
The schema rejects other layouts and declarations on manually selected profiles.
The audio-device policy still requires a known wired model and one unambiguous output.
Legacy FLX4/400 and native NI/Beatpad policies remain unchanged.

Scratch uses the master/headphone assignments in its cited Mixxx audio setup.
This output declaration does not implement DVS, passthrough or input routing.
Do not infer the declaration for other four-channel devices. Review hardware mixing, output order and connection requirements separately.
Physical audio output and A10X acceptance remain open.

## VCI-300 paired counters and nine-bit tempo — R233

`vci300.py` retains original VCI-300 dispatch and direction-specific feedback from pinned XML and script sources.
`cyclic14BitJog` consumes each fresh pair once, primes its first position and wraps signed differences at half range.
Native fixed touch scratching uses 1,600 counts per revolution. It does not run downloaded source curves or timers.
`vci300Tempo` extracts `(high << 2) | (low >> 5)` and normalises centre 256 exactly.
Both decoders discard an orphan low byte. Each result requires a fresh high byte.
This is stricter than the source tempo cache, which assumes complete hardware pairs.

Seven Shift bindings populate five existing scopes. Local Shift and Scroll also contribute to a composed jog scope per side.
This blocks unsupported search/scroll gestures until every relevant hold releases. No new modifier schema is needed.
Shift rearms tempo pickup as a native safety policy. The source pitch handler does not guard Shift.
Scroll/PFL loading retains native cue policy rather than changing exclusive PFL.
Source scopes, remaining functions and physical limits appear in the catalogue and coverage record.

## VCI-100MKII four-target core — R234

`vci100mk2.py` retains the pinned XML dispatch and script-defined 2,400-count jog resolution.
Its fourteen-bit pitch, level and crossfader low bytes sit sixteen controller numbers above their high bytes.
The explicit low-byte contract already supports these pairs.
`vci100MK2Tempo` consumes a fresh pair and returns `raw / 16384`.
This preserves the source centre and endpoint asymmetry after translating Mixxx rate direction once.
Factory-only selection prevents automatic learning from assuming the standard low-byte offset.

Fixed global-channel Shift notes populate independent physical-side scopes and one combined loop-size guard.
Bank reports reset contacts and pickup without clearing physical Shift.
Alternate release aliases preserve normal button edges and held Cue, including releases after a bank change.
The native core omits source library-focus changes, quantised pitch, brake/slip timers and unsupported alternate functions.
Bounded shutdown clears reviewed Play, Sync, Key Lock and PFL lights. Complete cleanup and routing remain open.

## Portable Hercules native cores — R235

`hercules_portable.py` keeps Starlight and DJControl MIX dispatch separate.
Both scripts specify 248-count jogs with single-step 1/127 reports. Native fixed touch scratching replaces the source Vinyl toggle.
Alternate-channel release aliases finish held contacts without enabling accelerated search, stutter or cue-master/split functions.
The shifted right-wheel handler derives deck B from MIDI channel five. This takes precedence over the XML's incorrect group label.

Starlight loop notes are 16–19. MIX loop notes are 48–51, with the other page reserved for samples.
Both retain four cues and source-defined bass/filter controls. Only MIX adds master/headphone amounts.
No Load or browsing input is invented. These functions remain available through app touch controls.
Starlight restores its base light behaviour on shutdown. MIX retains its separate all-lights-off command.
The existing automatic recipes gain reviewed native behaviour. Automatic model counts remain unchanged.

## Original Inpulse 200 native core — R237

`inpulse200.py` uses the original factory table, pinned Mixxx dispatch/script and the official DJUCED guide.
Its normal loop buttons use native manual In and Out/Exit. The long-In report enables a four-beat loop idempotently.
The typed Out/Exit action reuses existing native loop methods. Ordinary Out bindings on other controllers keep their existing behaviour.
Factory paired mixer controls preserve low bytes. Factory signed jog magnitudes take precedence over the source's single-step clamp.
Native resolution retains 248 counts, with 62 for four-times shifted search.

Physical Shift scopes protect normal controls and pickup. Distinct pad pages cannot trigger cues in sample, roll or effect modes.
Confirmed right-deck dispatch follows XML and channel-based handlers where the factory shifted B note table repeats A's channel.
Conflicting shifted PFL/Load/long-press rows remain unmapped.
The explicit master/headphone layout follows the official guide. Hardware master/headphone knobs do not change software gain again.
Remaining modes, complete feedback, cleanup, firmware capture and physical calibration stay open.

## VCI-400 mode guards and lifecycle — R238

`vci400.py` retains direct four-target Load dispatch and 4,096-count touch jogs from pinned XML and script facts.
Native mode starts at Hot Cue rather than the source's unsupported Roll page.
Cue and fixed-loop pads require their own per-deck mode. Pads remain inactive in unimplemented modes.
Deck D's eighth pad follows published XML dispatch despite the script's missing constructor entry.
Pad LEDs remain unmapped until feedback can respect mode context.

`binaryDirection` emits one signed step for any seven-bit displacement from centre 64.
The inverted loop-size input retains source halve/double direction. Native preselection also works before loop activation.
Bank loss/selection releases only its physical side and preserves global Shift.

Exact startup clears three inactive mode lights and lights Hot Cue on each of four decks.
Shutdown clears every mode light. The total setup budget is thirty-two validated messages.
A fixture accepts that total and rejects thirty-three messages. No source timers or scripts run in the app.
EGE, CC transport aliases, shared bank-dependent controls, full feedback/cleanup, audio routing and physical calibration remain open.

## CMD Micro held pitch buttons — R239

`cmd_micro.py` retains exact two-deck dispatch, 128-count centre-64 jogs, direct Load and 4/8-beat toggle pads.
Tempo keeps exact centre and source inversion. The source's inverted LED condition resolves to native on 1/off 0.
Only published Play/PFL feedback is included. Shutdown clears those four indicators.

Typed held pitch buttons use a native four-percent temporary rate. Both directions cancel; the last release restores normal speed.
Duplicate/orphan releases and stale source generations cannot alter a newer command.
Later touch/rate commands retire the hold. New presses are ignored while a deck waits for its quantised start.
Normal-speed restoration alone is allowed through the queued performance gate, with existing validation and Sync alignment.
Source timers and optional key-bend mode do not run in the app.
Full lights, cleanup, routing, calibration and physical acceptance remain open.

## iDJ Live II contact gate and separate Cue buttons — R240

`idj_live2.py` retains the source's 640-count scratch resolution and exact state-query SysEx.
Native scratch mode stays fixed. `requiresTouch` limits relative jogs to contact held by that source and target deck.
The profile validator requires a matching contact input and rejects this flag on non-jog actions.
`touchGate` uses the source's midpoint threshold for note velocity; Note Off always releases it.
It is a factory encoding and cannot be selected by automatic MIDI learning.
Custom mapping reconnect preserves the gate, threshold encoding and resolution.

Typed Cue Set and Cue Goto keep distinct physical button functions. Goto preserves transport state through the native jump path.
Held pitch buttons reuse R239 ownership and release handling. Crossfader inversion follows XML.
Only published Play/Sync feedback is mapped. Shutdown clears those indicators and the fixed Scratch indicator.
Original iDJ Live/Pro, software scratch-mode toggle, library expansion, full feedback, routing and hardware acceptance remain open.

## LC6000 control ports and direction-first jogs — R241

`lc6000.py` links the factory MIDI specification and a pinned source mapping.
`portAliases` allows reviewed profiles to select one exact control port from a device with several MIDI ports.
Matching uses endpoint port names separately from the common device name. Duplicate or unknown ports remain unresolved.
Profiles without this declaration retain the single-input discovery rule. Player allocation and reassignment remain shared.

`lc6000Jog` retains direction from CC 55 and decodes each CC 54 movement as forward value or reverse value minus 127.
Movement before direction is ignored. CC 17/49 stay unmapped because their published handlers do nothing.
Native scratching retains 1,024 counts per revolution, pending physical calibration.
Paired pitch keeps explicit low CC 40. Hot Cue and fixed-loop pads have separate mode guards; Shift release aliases rearm edges.
Startup and shutdown use fourteen bounded messages in total. The WD display protocol does not receive control feedback.
Source JS and timers do not run in the app. Display/strip, software Vinyl/zoom/range modes, full feedback/cleanup and physical acceptance remain open.

## Original VCI-100 scratch time scale — R242

`vci100.py` keeps original-model dispatch separate from Hile, 3DEX and MKII.
Separate Cue Set/Goto/Preview and held pitch buttons reuse the native typed actions.
The contact-gated platter and independent ring retain distinct CC addresses.
Source scratch calibration is 384 counts at 45 RPM. Native resolution is 518.4 at its 33⅓-RPM reference.
The motion fixture checks 4/3 seconds of source movement for 384 input counts.
Tempo applies Mixxx rate inversion once and keeps exact centre/pickup.
Shared selector keys, FX, balance, lights/cleanup, routing and physical calibration remain open.

## Xone K1/K2/K3 factory layout — R243

`xone_k.py` combines the factory manuals with the pinned shared mapping's default channel-15 middle deck columns.
K3 factory-map compatibility is explicit in the manufacturer guide. K2/K3 latching layers must be off; K3 firmware must be compatible.
Other MIDI channels, user maps and X-Link layouts remain outside this recipe.
Native lower pads stay on a fixed four-cue page. The right large button acts as Shift; the left page indicator stays red.
The K1 left-button SHIFT label differs from this source-derived layout.

Separate lower-right-encoder and combined modifier scopes protect the Load/Play chord.
Release aliases preserve button edges. Source ownership and saved mapping metadata reuse the existing path.
Native Shift is momentary. Low EQ rearms pickup after Shift instead of copying the source's persistent quick-effect latch.
Red feedback uses Note Off velocity 127. Startup/shutdown total sixteen messages and clear all declared indicators.
Outer FX columns, other pages, full feedback, firmware/device checks, K2 audio routing and physical acceptance remain open.

## Ready measured pitch travel and hardware layers — R244

`ready.py` pins the author's protocol, source profile, XML and script.
`readyTempo` consumes fresh CC 9/63 pairs and maps the measured 0–1023 range. Out-of-range pairs are ignored.
The recipe keeps source inversion and pickup; midpoint calibration remains open.
Hardware Shift/Mode layers use distinct addresses. Note Off aliases release Cue and rearm normal buttons.
Fixed native scratching keeps 1,024 counts and arms Vinyl at startup. New Shift-search contacts are blocked; release stays valid.
Hot Cue, Auto Loop and manual-loop pages have independent per-deck guards. Other pages remain inactive.
Native cues retain existing one-press behaviour. Source held previews and mode-dependent pad feedback remain open.
Startup clears sixteen RGB pads; MODE indicators are firmware-owned. Lifecycle setup totals 28 messages.
Buddy, source Vinyl/search modes, full pads/FX/feedback/cleanup, audio routing, calibration and physical acceptance remain open.

## Mixer One explicit mixer targets — R246

`mixer_one.py` retains all four published mixer channels and side-specific gain/EQ/level/PFL addresses.
Global controls use both source address sets. C/D honour existing app availability.
Clear Meter reports rearm deck pickup without inferring a bank target.
Startup clears unsupported EQ-kill lights and known meter addresses. Shutdown clears PFL and meters.
The lifecycle total is 32 messages. Live meter values, inverse mute restore, EQ kill and crossfader curve/balance remain open.
No source JS, timers, guessed meter values or audio-routing declarations run in the app.

## U-Mix Control Pro 2 full-value contact and pitch feedback — R247

`umix_pro2.py` keeps Pro 2 separate from original Pro and Control 2.
`fullVelocityGate` implements the source's exact contact value, including expanded note ranges.
It shares note validation with midpoint `touchGate`, while preserving each rule and excluding both from automatic learning.
The receiver preserves their zero-valued releases. Saved factory overrides retain the encoding.
Native scratch/rim resolution is 340 counts. Centred pitch and cue-clear release aliases preserve source dispatch.

Held pitch feedback reads the owned direction state for the current source generation.
Opposing holds remain independently visible. Later touch/rate ownership and new generations cannot leave old indicators active.
The source's inverted Sync condition resolves to on 100/off 0. Native Play indication is steady.
Startup/shutdown total 32 messages. Source beat pulses, quarter-nudge scaling, held cue previews, clip/end indicators, EQ kill, Tap, routing and physical acceptance remain open.

## Original Instinct factory conflicts and audio layout — R248

`instinct.py` uses the official MIDI/audio table before conflicting community rows.
Normal jog CC48/49 stays separate from contact-gated pressure CC50/51, with source 128-count calibration.
Native signed decoding at raw64 for the pressure stream is an explicit inference pending capture.
Factory tempo steps are 1/127; zero is ignored. Native four-cue and manual-loop pages use explicit press addresses.
The EQ rotation wording needs calibration; source polarity is retained.
Factory LEDs use on0/off127 at the same control addresses. Native pad/loop feedback stays open.
The documented master1/2/headphones3/4 layout uses the shared known-device route and sample/recovery fixtures.

Full factory startup clear and native-owned shutdown total 51 messages. The validated lifecycle limit is now 64, with a 65-message rejection fixture.
This work runs at discovery/disconnect, without source JS, timers or new audio-render work.
P8/iPad variants, other controls/modes, pressure/EQ calibration, firmware-specific light behaviour and physical acceptance remain open.

## Compact factory volume and Shift tempo — R249

`hercules_compact.py` uses factory deck level and two-band EQ, correcting the source pregain assignment.
`compactTempo` preserves signed-square Shift jog response and inverse Mixxx rate polarity through existing native relative tempo handling.
The factory-only codec requires seven-bit CC input and tempo actions. Zero leaves the saved tempo unchanged.
The source's tempo-corrupting state query and forced default-rate reset are omitted. Physical knobs retain pickup.
Normal wheels use native nudge/paused seek. No fabricated touch contact, source timers or JS run in the app.
Hardware pages use distinct pad addresses. Alternate releases preserve Cue and rearm one-press controls.
Transport LEDs use explicit normal/shift addresses. Only reviewed feedback/Auto/Record addresses receive lifecycle clears.
Synthetic scratch, advanced functions, full feedback/cleanup, EQ calibration and physical acceptance remain open.

## BCD3000 standard-mode core — R250

`bcd3000.py` uses the original factory MIDI/audio tables and pinned standard-mode source.
The reviewed profile replaces the alternative Advanced mapping for automatic core selection.
Factory CC outputs retain distinct LED addresses. Startup/shutdown clear only documented LEDs1–25.
Startup enables factory acceleration and queries analogue values. Both wheels use native nudge/paused seek with the source 100-count scale.
SET CUE, held preview/bend, three-band EQ, pitch, levels, reloop and PFL retain separate native actions.
DATA4 stays unmapped. It is neither Master nor Balance. Physical output gains stay hardware-owned.
The factory standard/Core Audio master/headphone layout uses shared route/sample/recovery checks.
Windows Advanced mode, latched scratch, Set Loop hold/release, remaining controls and physical acceptance stay open.
BCD2000 is a separate non-class-compliant USB device. Its catalogue connection requires a driver or MIDI bridge, which this work does not implement.

## Original DJ2GO factory core — R251

`original_dj2go.py` follows Numark Rev B, retaining signed relative magnitude and stationary zero for both wheels and Browse.
Native wheel nudge/paused seek uses 60 physical counts. No touch sensor, source scratch timers or custom 85RPM response is invented.
Load acts on press. Pitch buttons retain the factory held-bend meaning. Native tempo preserves the centre detent, polarity and pickup.
Factory volume, Master, Headphone gain and all eight LED addresses remain distinct.
Cue preview feedback reads the generation-owned native contact and active touch. It is independent of PFL.
Back uses previous native group and Enter uses Open Group. Full hierarchy semantics and source alternate layers/flashes stay open.
DJ2GO2/Touch remain separate. No audio interface or extra startup protocol is assumed.

## Original AIR factory pitch and pressure jogs — R252

`hercules_air.py` uses the original factory MIDI/audio tables before conflicting or incomplete source behaviour.
`airTempo` consumes fresh seven-bit CC52/88 or53/89 pairs, with zero/nonzero low reports as one Boolean bit.
The full eight-bit range keeps source polarity and native pickup. Automatic learning excludes this factory-only codec.
Normal and pressure jogs retain full factory signed magnitudes and source 128-count calibration. Pressure requires factory full-value contact.
Native fixed pressure scratch, held bend and manual Loop page use existing native actions. Pressure updates do not retrigger held pads.
The factory all-LED clear replaces broken source startup/shutdown. No source timers or JS run in the app.
Hardware headphone volume receives no duplicate software change. The cited master/headphone split uses native routing.
Other modes, HP Cue/Mix selection, full feedback, Scratch toggle, EQ calibration and physical acceptance remain open.

## SC2000 channels and trigger feedback — R253

`sc2000.py` keeps default CH1/2 as A/B and CH3/4 as C/D. Other channel pairs need separate assignment.
One source-local physical Shift input spans all eight wire channels, preserving its release after a channel change.
Bank reports release contacts and rearm pickup without dropping held Shift. A blocked held button still needs release before a fresh press.
Factory value64 contact, 2,048-count centre64 jogs and full pitch messages use existing native contracts.
Native core retains eight cues, manual/automatic loops, size buttons, direct Load and a filter encoder that follows its factory label.
Separate CC74/75 feedback carries factory LED identifiers. Shutdown clears 52 native-owned states. Initial feedback supplies their starting states.
No source deck-count mutation, timers, generic USB Audio Device alias or audio interface is invented.
Other channels, full dimmer/FX/lifecycle coverage, source custom modes, calibration and physical acceptance stay open.

## Mixage family core — R254

`mixage.py` uses the pinned author's explicit three-model list and measured 620-count jog scale.
`sources.py` expands the old family record into Interface Edition, Interface Edition MK2 and Controller Edition.
The shared default hardware channel 1 recipe retains full pitch messages, per-side Shift and normal/Shift mixer addresses.
Native fixed touch scratching uses both pressure/movement address sets. Alternate releases preserve Cue/bend and rearm one-press base controls.
Four shifted cues, shifted filter pickup, idempotent Loop Enable, Reloop, manual In/Out and sign-only loop sizing use native actions.
Separate browser encoders use immediate Open Group without source multi-click timers.
Only 26 known LED/meter addresses receive lifecycle clears. The source's invalid 0–254 note loop is not copied.
Full modes, live meters, CUP, FX, source cue/loop customisations, alternate channel, family audio routing and physical acceptance stay open.

## Original Inpulse 300 paired mixer and loop layout — R255

`original300.py` completes core controls in an existing automatic profile without increasing automatic model counts.
Factory paired crossfader/mixer/pitch retain fourteen-bit values on normal and Shift channels.
Full signed jog values keep the source 248-count scale and 62-count Shift scale. Physical Shift rearms pickup and preserves held releases.
Eight distinct Hot Cue addresses retain native one-press behaviour and shifted-clear release aliases.
Working source channel 5 resolves the factory shifted B contact typo. Other disputed shifted PFL/Load rows stay unmapped.
The source's custom loop layout uses native four-beat enable and a new typed idempotent Loop Disable action.
Original manual/adjustable loops, Vinyl/inertia state, other modes, FX, pad/beatmatch feedback, full routing/cleanup and physical acceptance remain open.

## Total/Omni core and fine-tempo response — R256

`total_omni.py` keeps separate jog orders: Total A25/B24, Omni A24/B25. The Total factory diagram confirms its fixed addresses.
Native wheel nudge/paused seek retains source 128-count scale without synthetic scratch timers or gamma curves.
`fineTempo512` preserves signed source rate increments 1/512 through existing native relative tempo handling and inverse polarity.
It shares strict seven-bit input validation with `compactTempo`. Both factory-only codecs remain tempo-only and excluded from automatic learning.
Manual In emits Loop Disable, then Loop In. Native audio fixtures verify that order before Out creates a new loop or exits it.
Source LED addresses remain separate from input addresses. Native PFL uses on 100/off 0 and Sync uses a steady native state.
Startup clears source 48–86, and shutdown clears eight owned outputs. The total is 47 messages.
Both profiles were already automatic. This increment expands native core coverage without increasing automatic model counts.
Source advanced modes, Tap, EQ kill, FX, animations, full browser/loop behaviour, audio routing and physical acceptance remain open.

### Input-only pad modes (R310)

An `inputModes` row can omit both `onValue` and `offValue` when only the input protocol is qualified.
The mode state still changes before action dispatch. The connection sends no mode-light packet.
Specify both values for reviewed mode feedback. An incomplete pair is invalid.
Party Mix Live uses input-only modes for its Cue and Loop pads. Sampler and Effect mode selections block those actions.
This does not supply cue deletion, held Pad Mode behaviour or automatic audio routing.

### Runtime resource size (R319)

The native loader accepts at most 4 MiB of UTF-8 JSON. Keep this limit unchanged.
The generator writes compact runtime JSON and checks its byte count before it writes either output.
Oversized output fails generation. The review catalogue retains its readable format.
R319 caught a 4,196,910-byte resource that caused the native loader to reject all data profiles.
Compact JSON reduced it to 2,235,212 bytes without changing the earlier profile data.
Importer size checks and native catalogue-load checks cover this boundary.

### RMX-90 DVS manual mixer (R320)

`reloop_rmx90.py` records32 factory mixer/PFL inputs. Set MIDI on, MIDI CH1 and MIDI TYPE TRIGGER before manual selection.
Use a separate software audio path. External deck routing and hardware/software mixer bypass remain unavailable.
The recipe does not send pickup SysEx or infer FX encoder decoding, lamp output or sibling RMX addresses.

### DJ-505 manual normal controls (R321)

`roland_dj505.py` records normal four-target controls from the pinned Mixxx XML and script.
Its explicit low-byte addresses differ from the usual plus32 pairs. The pinned Mixxx rate formula confirms pitch direction.
The manual recipe sends no partial software-mode SysEx or keepalive. Shared Load ownership, crossfader calibration, jogs, pads, TR-S and full routing remain open.

### CMD MM-1 automatic mixer core (R322)

`cmd_mm1.py` records31 default controls across496 explicit bindings for all16 configurable MIDI channels.
Only named MM-1 endpoints select the recipe. The fixed strip order is C/A/B/D, with EQ/filter roles and headphone PFL.
Shift and Ctrl have independent guard identities. Either blocks normal deck and browser actions.
Dynamic software layers, lamp/meter output and physical acceptance remain open. No generic CMD alias or audio route is inferred.

### Fixed SMC-Mixer and iControls mixer cores (R323)

`fixed_midi_mixers.py` keeps the two default USB-MIDI contracts separate. Both use C/A/B/D physical strip order.
SMC-Mixer encoders use the literal raw65 decrement rule. iControls encoders retain signed counts divided by100.
The native decoders reject foreign message kinds and values. Only the reviewed continuous mixer actions can use them.
Shared transport and software modes remain inactive. No unqualified lamp, reset or audio packet is emitted.
The generated report states the automatic-core and complete-theoretical remainders separately.

### SMK-25 II vendor input (R324)

`smk25ii.py` declares `inputProtocol: smk25II`. Its bindings describe logical messages after `ControllerSMK25Decoder` conversion.
The decoder accepts complete7-byte vendor messages and the source's standard strips. It retains fragments and A/B selection per source.
Channel9 sampler notes cannot trigger deck cues. A bank change releases owned contacts and resets only deck pickup.
Factory inputs already use the byte port. Ordinary controllers retain their existing decoder. Frame limits apply before action dispatch.
Firmware-immediate pad releases do not establish physical hold duration. Samplers, recording, Bluetooth, output/lifecycle and physical acceptance remain open.

### Independent MIDI Fighter default cores (R325)

`midi_fighter.py` keeps Classic Default pads separate from the Twister normal mixer.
Classic uses the actual source initialiser's C/A/B/D rows. Its manufacturer map independently confirms the default notes.
Twister retains CC switch kinds, six independent Shift guards and shifted headphone level. Fixed A/B targets replace software-selected deck banks.
Other hardware modes, full output/lifecycle and physical acceptance remain open. No firmware or persistent preset is written.
