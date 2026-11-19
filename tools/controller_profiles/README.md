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
The generator checks the bundled resource byte count before it writes the generated outputs.
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

### Original Launchpad Mini pages (R326)

`launchpad_mini.py` keeps the original Mini's reset/buffer setup and fixed A/B/C/D page-A Play/cue rows.
All eight page selectors guard the shared grid. Page-H individual library/load controls stay on their source page.
CC111 guards cue deletion. Note104 page selection stays distinct from CC104.
The source loop pads toggle on press and conditionally on release. They remain inactive until a native action preserves that behaviour.
Other pages, full lights/lifecycle and physical acceptance remain open. No other Launchpad model inherits these addresses.

### MK2 and Mini MK3 Launchpad cores (R327)

`launchpad_rgb.py` preserves the initial fixed A/B tall layout from each pinned script.
The independent manufacturer tables qualify the grid, MIDI message kinds, mode commands and Mini MK3 MIDI interface.
MK2 selects Session layout. Mini MK3 selects Programmer mode only on its MIDI port, then returns to Live on disconnect.
Both modifiers guard normal deck controls. Halve/double and individual library controls remain independent, as the source requires.
The eight core lamps retain source palette values. Per-size loop lamps and RGB cue colours need richer feedback state.
Dynamic layouts, conditional Load, alternate modes, full feedback and physical acceptance remain open.
The original full-size Launchpad requires desktop drivers and a qualified iPad bridge. It cannot use these class-compliant contracts.

### CDJ-101 timed player input (R328)

`cdj101.py` declares `inputProtocol: cdj101`. `ControllerCDJ101Decoder` normalises browser direction and short-click Load.
Only raw65 moves forward. Every other seven-bit browser value moves back, as the source specifies.
An owned push release before200 ms emits logical Note126. Repeated presses cannot restart that interval.
The callback records arrival time before queuing input. A delayed main-thread drain retains the original interval.
Input state resets on disconnect. Output expansion passes the existing frame limit before dispatch.
Native player assignment separates software decks from wire channels1/2. Source143 ticks at45 RPM becomes193.05 effective native ticks.
Full spinback/Shift/outer-wheel behaviour, output ownership, complete lifecycle and physical acceptance remain open.

### Manual vendor input protocols (R329)

Manual application retains the closed `inputProtocol` tag against that source ID, alongside its saved bindings.
SMK-25 II and CDJ-101 use the byte input port on unnamed endpoints. Known factory identities retain their own wire protocol.
A profile change resets fragments, bank/click state and held contacts. Ordinary and legacy profile replacements clear the manual tag.
Restoration checks metadata size, source count and binding ownership. Hardware startup/output remains separate from manual input conversion.

### DDJ-SR2 manual normal core (R330)

`ddj_sr2.py` declares the independent manufacturer table and `inputProtocol: ddjSR2`.
`ControllerSR2Decoder` starts with unknown Load ownership on each side. Positive selector state qualifies A/C or B/D.
Current-selector release, external input or invalid selection clears that side. Selector boundaries release owned contacts and pickup without clearing physical Shift.
Only shared Note70/71 can produce logical Load126. The raw deck TRANS-parameter Note126 and shifted Load remain inactive.
The manual recipe retains all28 explicit14-bit pairs and distinct shifted release aliases. Normal pad addresses remain separate from other hardware pages.
The pending-source inventory cannot override a reviewed recipe. The missing cold query keeps automatic selection off.
Full Vinyl/Shift/pad/FX modes, output/lifecycle/routing, calibration and physical acceptance remain open.

### Original KeyLab 88 input (R331)

`keylab.py` names the original88-key profile explicitly. The generic source inventory record does not qualify smaller or later keyboard variants.
`ControllerKeyLabDecoder` validates bounded broadcast MMC and emits native pulses. MMC does not provide physical hold duration.
Ordinary piano notes, mod-wheel CC1 and alternate CC transport assignments remain inactive.
Sound/Multi uses the pinned275 ms timing. Released snapshots choose the two cue layouts or the inactive sampler layer.
Selected controls use logical channels0..3. Fixed C/A/B/D faders and globals use logical channel4.
Deck/layout changes release owned contacts and reset affected pickup/debounce. Source-specific state resets on reconnect.
The explicit XML input dispatch takes priority over conflicting component MIDI fields. No output or persistent preset is written.
Complete menus, extra cues, samplers/recording, delayed display/lights, calibration and physical acceptance remain open.

### Kontrol One native base (R332)

`kontrol_one.py` keeps independent wire addresses and a fixed native base layout.
`ControllerKontrolOneDecoder` marks hardware channel changes before dispatch. Boundaries release owned contacts and reset non-modifier pickup/debounce.
Seven physical modifiers retain separate identities across channels. Jog and knob directions use separate source rules.
The actual scratch arrays select150 ticks and45 RPM. The unused header scratch value is not used.
Labelled Sync, native normalised knob steps and direct loop controls replace source custom/timed software behaviours.
The direction-step guard admits gain/EQ only at reviewed Kontrol One knob addresses. Other profiles retain the existing limit.
Complete banks/Shift latches, kills, source loop editing, dynamic output ownership and physical acceptance remain open.

### MIDI Fighter Spectra default banks (R333)

`spectra.py` pins the manufacturer guide and independent XML/script. Startup selects the hotcue bank with channel4 Note1 velocity127.
`ControllerSpectraDecoder` keeps selected-deck cues separate from fixed C/A/B/D filter switches. Bank/deck boundaries release owned contacts and reset cue input state.
Only positive selectors change the deck. Stale bank releases cannot clear another current bank. Normal Note Off always releases.
Logical cue channels cannot be injected by raw input. Duplicate momentary CCs and unimplemented marker/sampler/stem addresses stay inactive.
Automatic startup requires one paired output and fails closed. No persistent preset is written.
Custom settings, EQ kills, full RGB/ground feedback, lifecycle and physical acceptance remain open.

### DUO and DUO MKII manual performance inputs (R334)

`mixars_duo.py` uses the manufacturer table that the MKII product page also links. The two model identities remain separate.
Manual profiles provide both cue banks, Sync, native loop push and fixed A/B Load. Distinct shifted release aliases preserve normal rearm.
Sampler, fader-start, mixer/PFL and unspecified relative encoders remain inactive. Fader-start Note0 must never become Play.
The documented non-Serato hardware mixer route needs separate deck outputs. This route is not implemented, so automatic selection stays off.
No output, lifecycle or PRIMO/QUATTRO compatibility is inferred. Physical USB/driver/audio acceptance remains open.

### P1-Nano MIDI1 manual input (R335)

`p1nano.py` follows the independent XML/script groups for A/B/C/D, with the source's documented DAW1 Bitwig configuration.
`ControllerP1NanoDecoder` retains selected transport, latched Flip, full14-bit faders and independent knob parameter selection.
The `p1NanoEncoder` codec preserves source counts in0.01 normalised units. Neutral0/64 does not adjust a value. The codec is bounded and unavailable to MIDI learning.
Profile validation admits it only for reviewed P1-Nano gain/EQ/filter addresses. Raw logical channels, master-fader guesses and custom touchscreen traffic remain inactive.
Deck/control changes release owned contacts and reset pickup/debounce. Reconnect resets decoder modes; the manual protocol tag remains bounded and persistent.
Source captions differ from executable lane groups. Motor/display output, complete lifecycle and physical acceptance remain open. Automatic selection stays off.

### DDM4000 manual MIDI mixer (R336)

`ddm4000.py` retains four independent source strips and a fixed native crossfader. Hardware sections must use MIDI mode on channel1.
PFL input uses Notes63/73/83/93. Four separate light mappings use same-number CCs with127/0 values.
The source helper staggers component initialisation at40 ms; it does not enforce that interval between every live light message. Full source light initialisation remains open.
MIDI CC light echoes, hardware trim, microphone, sampler, curve/reverse and assignment inputs cannot become unrelated actions.
The DDM4000 requires a DIN MIDI interface and separate audio routing. It has no USB MIDI or digital audio interface. Automatic selection stays off.
Full modes/output/lifecycle and physical acceptance remain open.

### Timed factory setup and SCS.3m (R338)

`scs3m.py` adds fixed native A/B mixer controls behind transient flat/absolute mode setup.
`startupDelaysMilliseconds` is optional. Its count must match startup messages, with at most1,000 ms per step and5,000 ms total.
`ControllerMIDISetupSequence` measures each wait from actual send completion. The input polling loop advances at most64 packets per call across at most16 pending sources.
Known timed inputs and ordinary output remain inactive until setup finishes. Failure/disconnect cancels pending work. Explicit discovery can retry.
Queued input before the hardware-ready deadline cannot dispatch. Manual application requires an established automatic paired session.
SCS.3m uses nine packets and five20 ms waits. Full software modes, meters/lights, shutdown/lifecycle and physical acceptance remain open.

### BCR2000 factory preset and direct state (R339)

`bcr2000.py` selects factory preset1 with the exact two-byte Program Change. It never writes a preset or factory reset.
Twelve normal inputs retain fixed group2 EQ/filter, explicit keylock state and a shared global Shift guard. Ten CC outputs retain parameter/keylock feedback.
Direct keylock state uses the existing explicit playback setter. It bypasses pickup and positive-edge toggling. MIDI learning does not expose this action.
Global CC Shift bindings can share a bounded `shiftInput` identity. Channel-specific CC identity stays invalid.
Setup validation now requires two bytes for Program Change/channel pressure and three for other supported channel messages.
Complete modes, Shift-lamp synchronisation, lifecycle and physical acceptance remain open.

### SC5000M captured Computer-mode input (R340)

`sc5000m.py` pins the public author captures, working mapping/proxy and iOS investigation independently of the LC6000 specification.
`ControllerSC5000MDecoder` retains fresh-press LAYER selection, shared Shift, per-deck pad modes and original release ownership.
The manual111-binding core supports normal transport/loops/browser, Hot Cue1–8 and source-sized auto-loop pads. Roll/Slicer pads stay inactive.
Motor/platter counters, pitch bend and absent Note40 touch never become jog or tempo input. No motor or screen command is sent.
The closed manual protocol tag persists with bindings. Deck, mode, fragments and held state reset on replacement/reconnect.
Motor/hand inference, platter/pitch calibration, screen/touch bulk protocol, complete output/lifecycle/audio and physical acceptance remain open.

### Separate Prime player normal contracts (R341)

`prime_players.py` pins separate JP13/JP14/JP07 factory assignment files for SC6000, SC6000M and SC5000.
Each manual79-input profile uses a separate `denonPrimePlayer` tag with the bounded common transport decoder. SC5000M's stored tag and111-input recipe stay unchanged.
Tests check each factory component/address independently. Model-specific jog sensitivity, motor/touch, pitch LED direction and parameter addresses are excluded.
Firmware assignments establish normal addresses, not a complete host SDK. Cold-start Computer-mode setup, other pad modes, output/displays/audio and physical acceptance remain open.

### RANE ONE MKII corroborated manual subset (R342)

`rane_one_mk2.py` pins an independent owner archive and compares26 unconditional rows with the earlier staff export.
The45-binding manual subset retains Load, Sync/explicit off, keylock, bends, normal loops and source-valued browsing.
Global Shift guards normal controls. Shifted releases rearm known actions. The dedicated Sync-off message remains explicit and layer-independent.
Absent normal Play/main Cue/motor handling, pitch pairing, external mixer audio and conditional custom-class dispatch stay inactive.
The public exports do not include the RaneOneMK2 class. Complete output/lifecycle/audio and physical acceptance remain open. No source code or mapping executes in the app.

### nanoKONTROL2 transient native mode (R343)

`nanokontrol2.py` pins Korg's published protocol and the independent upstream functional addresses.
Search validates the model/echo and discovers its global channel. A matching native acknowledgement enables fixed channel16 input and four PFL lamps.
The12-input native mixer keeps dedicated volumes independent of held Marker modifiers. PFL buttons become logical notes, so their first presses work.
Setup requests use only the paired physical output. Failure and shutdown send native exit when the channel is known. No scene write, reset or persistent programming is sent.
Known native inputs and ordinary feedback stay blocked before confirmation or after failure/exit. Unpaired manual setup is rejected. Clearing learned mappings exits mode and requires fresh setup.
Source refresh reconnects paired setup sessions even while readiness gates input. Full software layers, reply timeout/recovery, lifecycle and physical acceptance remain open.

### nanoPAD2 independent native scenes (R344)

`nanopad2.py` pins the independent project12 protocol and upstream cue/loop layout. It replaces the earlier four-input manual recipe with31 automatic logical bindings.
`ControllerKorgNativeDecoder` shares bounded handshake framing through a closed model enum. nanoKONTROL2 retains project13 and its existing control table/API aliases.
Native pad releases retain their original scene address. Scene barriers release owned contacts and preserve held Clear. Loop resize stays blocked during unsupported held-loop moves.
Fifteen first-bank cues and14 third-bank loop controls are active. Later cues9–16, timed reloop, fourth-bank controls and XY/touch-scale stay inactive.
The paired output sends exact Scene lamps after confirmation. Setup or live lamp failure disables that source and attempts native exit. No saved scenes are written.
Full modes, reply timeout/recovery, lifecycle and physical acceptance remain open.

PRIME4 and4+ retain separate manual profiles from the public owner mapping. A source-local adapter owns software deck selection, pad modes and original button releases. Logical channels and Load addresses cannot be injected through raw sibling channels. Mixer ownership, jog/screens, complete lifecycle and audio stay open. Public repository metadata explicitly names both models; it is not a manufacturer SDK. The XML omits some unneeded toggle-button release mappings, so source checks distinguish exported rows from native standard release handling.
Manual profile replacement must fit the existing256-binding saved-set limit before it changes any state. An over-capacity request retains every existing mapping. Automatic factory recipes retain their separate512-input bound.

MP2015 uses its manufacturer table, with explicit port MIDI enable and channel1 setup. The mixer saves those settings; native setup does not change them. Optional PFL lights use NoteOn0/127, with four independent addresses. Fixed mixer control requires separate audio to avoid double EQ/level processing. Hardware filter types, source routing and complete USB audio/lifecycle remain open.

Original RANE ONE uses a separate public owner export with Play0 and RaneOne class metadata. ONE MKII's explicit Sync-off3 and loop-out-or-double55 do not apply to the original export. Numbered cue targets do not establish held main Cue. Keep motor/platter/setup, full pitch, custom pads and mixer/audio ownership open. Neither model selects automatically.

Original PRIME GO and PRIME2 use independent JP11/JC16 assignments. Public GO owner exports without custom classes corroborate its fixed Computer-mode core. Use one inverted14-bit tempo pair31/75 per deck; do not import two independent speed controls from the later export. PRIME2 keeps manual selection, separate held Shift identities and unqualified tempo/browse. Neither profile activates pads, jogs, Color FX or screens, or infers GO+ compatibility. Automatic GO input does not establish automatic audio routing or physical acceptance.

SC Live2, SC Live4 and Mixstream Pro Go retain separate JP20/JP21/NH10 manual profiles. SC Live globals use cue-mix18/headphone19/master20; Mixstream Go uses9/10/15. SC Live2 alone has explicit inverted paired tempo. SC Live4 exposes only its fixed mixer until Layer31/cold Load ownership is qualified. NH09 is not Pro+ and NH10's copied MIXSTREAM PRO object name alone does not establish identity. Internal MCU setup, host USB gadget mode and a complete host SDK are separate evidence claims.

Digital Jockey2 Master Edition uses its own manufacturer appendix. Strip the USB-MIDI CIN prefix when reading its tables. Channel0 carries both decks with a60-address offset. Separate Shift inputs guard normal controls and standard release aliases rearm buttons. Normal PREVIEW means deck PFL, while main Cue uses18/54. TraxCC13 uses binary-offset64. Do not inherit Interface Edition pitch polarity, jog calibration, shifted layers or lamps. The desktop-driver requirement blocks a native iPad USB claim. Full driver/bridge, modes/output/lifecycle/audio and physical acceptance remain open.

SP-404MKII uses the ordinary DJ-mode chart in the current manufacturer manual, independently agreed by version4. CC22 is direct saved Sync state, CC23 is direct PFL state, and CC24/25 are held pitch bends. Preserve channel0/1 and the single channel0 crossfader. Direct Sync state bypasses pickup and edge priming, with repeat-idempotent on/off. State actions stay outside ordinary button learning. This subset does not use the separate proprietary Serato control screen, state-valued Play20, return-to-start21, BPM steps, sample/Chromatic/FX/Looper modes or output packets. Selection remains manual with separate audio and physical acceptance open.

Euphonia uses its independent E10 table on the current AlphaTheta support host. All four strips use wire channel0 with non-uniform CC numbers, including CH4 Mid5C/Low52. PFL notes0A–0D are latched state, not momentary software toggles. Keep direct state, ordinary mixer pickup and C/D opt-in separate. The table describes input to the computer and does not establish feedback. Manual app mixer control requires separate audio with hardware/software ownership unresolved. Source selectors, isolator/send/FX, display/settings, automatic audio and all outputs remain inactive.

MixTrack Go and Party Mix III use separate pinned2026 public mappings. Shared fixed fields must agree within each model's XML and handlers. Go alone wires Sync/PFL/jog/touch with an approximate242-count jog estimate. Party Mix III adds independently wired EQ, while its copied/unwired Sync/PFL/jog, right mode constant, volume28 and shared pads stay inactive. Identity/status startup requests are transient. Do not copy the source's delayed lamp routine, software modes or paused scrub multipliers. Both use exact shifted release aliases and inverted paired tempo. Native linear14-bit normalisation does not claim the source's exact8192-centre curve. Bluetooth MIDI disables controller audio, so no split-output route is automatic. Full lifecycle/audio and physical acceptance remain open.


## Original nanoKONTROL and PLX-CRSS12 accessories

`nanokontrol_scene.py` defines the original nanoKONTROL's32 read-only scene-aware mixer bindings. The separate model04 decoder queries current assignments without changing saved scenes. Existing saved raw mappings remain active until explicit replacement. This model never uses nanoKONTROL2 native mode.

`plx_crss12.py` defines68 automatic PLX-CRSS12 MIDI accessory bindings from the E1 manufacturer table. PAD MODE1 supplies eight Hot Cues per hardware-selected deck. Shift aliases only rearm normal cues. The extra while-held5–8 rows have conflicting channel/status columns and stay inactive. Turntable transport, pitch, motor/platter, display, feedback colours, DVS/audio and full lifecycle remain open. No output or setting write is inferred.

The [public-source audit](../../docs/coordination/controller-public-source-audit.json) records scoped Rane/Denon SDK and protocol searches. An unavailable protocol remains a gap.


`hercules_mk4.py` replaces the generic MK4 import with a documented38-input manual core and eight transport/PFL lamps. Relative pitch and sensorless wheels retain signed magnitude. Normal K buttons use the native1/2/4/8 loop layout. The manufacturer guide and independent MK4-specific mapping govern the facts. Desktop driver/bridge access, native iPad USB, other modes, full lifecycle and audio routing remain open.


`djm_a9.py` supplies30 manual A9 inputs from the current E10 table. Its CH2 CUE B/fader rows conflict with other controls. CH1/2 faders and all CUE B controls stay inactive. CUE A uses direct state in default TOGGLE mode. Separate app audio, C/D opt-in and manual channel1 selection remain explicit. No MIDI output or source/audio switch is inferred. Follow the current migrated support articles for exact document filenames.


`slab.py` defines139 automatic general-MIDI bindings for an explicit fixed DJ layout. All eight normal pad pages have native cue, loop, jump or transport functions. The upper/lower physical halves address fixed deck pairs. Page presses retire old holds; both Shift transitions retire holds and gate the layout. Shifted pads and aftertouch remain inactive. Encoders and DIAL browsing use1/65 signed-bit direction. Mode1 strip uses channel7 CC14/46. This does not emulate Serato Studio. Output colours, screens, other modes, full lifecycle and audio routing remain open.


`djm_a7.py` defines32 manual inputs from the independent A7 EN100 table, including all four faders. PFL requires channel1/TOGGLE. Use a separate app audio path until hardware/software mixer ownership is implemented. No factory button-type default, MIDI output, stored setting or audio route is inferred. The A7 table does not repair A9's conflicting rows.

`xdj_an.py` defines99 XDJ-AN inputs and ten binary lamps from the independent E1 table. Both decks must enter Software Control before a paired-output command selects MIDI Control. Input readiness follows local send success, without claiming device acknowledgement. Source-local mode loss releases holds and cancels owned queued movement. Saved raw mappings remain active until explicit replacement. The separate Core decoder owns setup state. Other modes, jog calibration, full feedback, audio routing, cold notifications and physical/A10X acceptance remain open.

`rev7.py` defines70 manual DDJ-REV7 E2 inputs. It keeps both Hot Cue banks separate and requires Utility LOOP options OFF. Motor/platter34/41, Silent Cue, state-coded loop35, other modes and all output remain inactive. Manual profile IDs retain bank-change rules across reloads. The metadata stays bounded and does not infer an applied profile from endpoint names. Mode presses retire old holds. Mode-button releases preserve new holds, including the corrected XDJ-AN pad-mode metadata.

`rmx_ignite.py` defines22 manual native deck-A accessory inputs on MIDI channel1. Sample A-D become Hot Cues1-4. Six straight roll buttons choose latched native loops. Triplet/dotted lengths stay inactive. The layout provides level/EQ/filter/effect amount, held bends, Sync and browsing through a separate app audio path. Hardware FX/sampler behaviour remains independent. The clock does not control app transport. No output, bypass, stored setting or audio route is inferred.

The source lock also pins204 rows and57 platform limitations from the19 November2026 djay hardware page. `read_djay` separates product rows, NEW badges and limitation rows. Two explicit naming variants resolve to existing records. Other models retain independent records. `comparisonSupport.djay` stores competitor evidence. It does not set our runtime or theoretical-support flags. Use `build_catalogue.py --djay PATH` to verify the optional HTML snapshot against the pinned hash and rows. Fresh checkout regeneration uses the locked facts without requiring the ignored cache.

`mix_ultra.py` defines48 automatic normal Mix Ultra inputs from three pinned independent owner sources and manufacturer semantics. Cue uses set/return/stop. Qualified level/pitch/crossfader pairs use14-bit values. Other absolute controls use their seven-bit MSBs. Conflicting physical Shift-side attribution uses a source-wide OR guard. Both Shift transitions retire contacts. Sync/PFL, other pad modes, service-mode overlap, full feedback, pairing/audio and physical acceptance remain open. No firmware patch, executable map or setting/output write is imported.

DJM-900NXS2 uses an independent Version1.00 table. Its default TOGGLE PFL states use CC70-73.
All four faders are explicitly CC17-20. This does not repair another model’s conflicting table.
The manual profile requires separate app audio. Hardware audio ownership and external deck routing remain open.

DJM-S9 uses its official Version1.00 table for42 manual mixer/browser/loop-size inputs.
Its pad rows conflict with the channel header. Status9q and4BEAT LOOP utility choices remain unqualified.
These messages stay inactive. Shared Shift guards normal browser/loop-size controls. Use separate app audio.

V10 and V10-LF retain separate public evidence. V10 has24 manual controls; LF has nine.
Only physical CH1-4 map to native A-D. CH5/6, four-band mids and mode-dependent filters remain inactive.
LF reuses only the trim/fader/master facts that Beat Link Trigger explicitly shares.
No downloaded LX or show code is copied, executed or bundled. Source-reuse review remains open.

DJM-450 has18 manual inputs from its independently reviewed three-page Version1.00 table.
Use explicit channel1/TOGGLE and separate app audio. No factory defaults or sibling wires are inferred.

The current manufacturer article explicitly shares the FLX6 E1 table with FLX6-GT.
GT reuses the existing core through a distinct automatic profile. Hardware utility mode remains user-selected.
The exact current PDF hash matches the earlier review. No clone, generic alias or mode-setting command is added.

AIR+ uses its own manufacturer packet table, default channel1/14-bit setup and master1/2-headphones3/4 route.
Both normal and scratch streams retain the independently specified765-count scale. Normal motion becomes scratch during contact.
The dedicated scratch stream requires contact. Four Hot Cues per side retain velocity edges.
Physical and reported Shift inputs use source-local OR guards with independent side scopes.
Sixteen owned lamps clear individually. Update_All_Controls stays unused. Independent AIR+-specific DEX facts resolve normal EQ/gain polarity over the conflicting table wording.
Physical polarity/taper/jog acceptance remains open.

4Set uses its own manual virtual-MIDI contract: A/B notes on channel1, C/D notes on channel2, all CC on channel1.
Default7-bit pitch stays separate from the documented alternate low-bit format. Both jog streams use250 counts.
Sixteen steady lamp recipes require separate manual feedback selection. Driver/bridge, native iPad USB/audio and full modes remain open.
No deck, Shift, jog-lock/sensitivity, curve or update-all-controls command is sent.

Original NS6 uses99 manual inputs and32 CC lamp recipes from its own public mapping.
Existing cyclic14BitJog decoding retains explicit CC0/32 pairs,16384 wrap and3600 positions per revolution.
Deck channels2-5 stay separate from shared channel1 mixer/browse controls. Side reports retire counters and holds.
Use the exposed desktop-driver/bridge MIDI port and separate app audio. No NS6II inheritance or TEST platter setup runs.

Original DN-MC6000 uses112 manual inputs and40 separately selected CC-trigger lamp recipes.
PC MIX, MIDI/USB source selectors and explicit MIDI block1-4 are required. Deck channel order is A/C/B/D.
The native layout explicitly assigns physical mixer CH1-4 to A-D. Global Load A/B stays on channel1.
Raw64 contact uses release-aware gates. Model-specific2000-count jog facts reuse the existing Denon decoder.
PAN is not inferred as cue/master blend. No fader query, meter, dimmer or setting command is sent.

Spin2 and XW-J1 have distinct30-input manual layouts from one explicitly shared, pinned author mapping.
Transport, PFL, Hot Cues2/3, loop/size, touch jogs, browsing, Shift-Load and channel5 crossfader retain qualified wires.
The375-count scale is the author's estimate and remains provisional. Fixed native touch scratch replaces the software toggle.
Conflicting mixer/EQ/pitch rows, undefined Hot Cue1 and output/lifecycle lists stay inactive. No downloaded code runs.

PRIMO uses63 unambiguous manual inputs from its own manufacturer appendix.
N transport/mixer channels1-4, P loop channels5-8 and G channel16 stay separate.
Earlier Cue/mode, bend/mode, PFL/pad, relative-format and pitch low-byte gaps remain inactive.
FILTER texture selection and separate app audio are explicit. No button-light values, banked Load or encoder formats are guessed.

`tsi_facts.py PATH` reads a local TSI file and prints used binding facts as JSON.
It bounds XML/base64, frames, arrays and strings. It rejects malformed or ambiguous structures and document declarations.
It does not execute, rewrite or import the mapping. Unknown fields stay uninterpreted. Generic MIDI templates do not qualify unused device controls.
The independent format reference is [TraktorMappingFileFormat](https://github.com/ivanz/TraktorMappingFileFormat/wiki/File-Format-Specification).

Original BeatMix uses50 automatic core inputs from its own manual and factory TSI for firmware1.1.4+.
The used bindings correct right Low to channel2/CC69 and global controls to channel5.
Qualified Scratch-mode jogs and browsing use3F/41. Normal jog templates remain inactive.
Pitch retains the qualified54/70 MSBs. Full14-bit arrival order, output, audio routing and physical calibration remain open.
Same-wire linefaders and global sound controls stay usable during Shift. No Beatmix2/4 protocol is inherited.

VCM-100 uses72 manual inputs across documented MIDI channel1 and optional channel2.
Both PGM decks share the selected channel. Rear modes A/B/C share normal core packets.
Level rotaries control deck volume. Mode-A centre notes, balance, search, CUP/Preview and output remain inactive.
The generic Vestax PC-CONTROLLER identity cannot safely identify this model. Select the profile manually and configure app audio separately.
Optional `holdInput` identities0-127 keep independent momentary controls separate within each source, MIDI group and action target.
VCM-100 assigns one identity per channel choice. Unspecified identities retain existing cross-channel aliases and Shift releases.
Only momentary actions can use this field. It does not create a MIDI channel, wire address or automatic identity match.

XW-DJ1 uses its own manufacturer41-input automatic core and14 steady lamps. It does not inherit XW-J1 or Spin2.
Shared channel1 Note46 is Shift. Channel3 CC16/17 jogs explicitly use raw-minus64 and300 positions per revolution.
Both documented crossfader buses are accepted. Normal transport, three cues, loop/size, contact, filter and sound controls retain their wires.
Shift-Play loads, Shift-Sync uses native keylock, outer Shift-loop buttons set boundaries and shifted jogs browse.
Native SET stores Cue. CUP release-play, hot-cue deletion, three-slot FX and fast search remain open.
The manufacturer qualifies master1/2 and headphones3/4 on its exposed wired route. Physical iPad USB/Lightning/audio acceptance remains open.

Canonical inventory names treat Rane SEVENTY A-Trak Edition and SEVENTY A-TRAK SIGNATURE EDITION as one physical model.
The Serato benchmark identity, djay source name/platforms and existing manual profile remain on that record.
Standard SEVENTY and both SEVENTY-TWO generations remain separate. This name reconciliation does not add automatic support.

Inpulse 200 MK3 uses its independent manufacturer factory XML from the public DJUCED6.8.1 package.
The65-input automatic core and18 normal lamps retain source channels and explicit512-count multi-step jogs.
CC5 is normal High, CC4 is normal Mid and shifted CC5 is gain. Shifted volume controls target samplers and remain inactive.
No physical Shift wire is inferred. Factory hardware channels separate normal/shifted controls. Qualified alternate releases preserve native holds.
Master/headphone knobs stay under hardware control. Output-only MASTER_VOL_L/R and conflicting shifted B-Cue feedback remain inactive.
No installer, downloaded script, mapping action, source reset, query or firmware runs. Exact software modes and physical iPad acceptance remain open.

T10 uses85 manual supplemental controls from its own439-control factory MIDI document.
Physical Shift Note4, mixer/EQ, eight cues, loops, keylock and library controls retain independent deck/shift/pad channels.
The manufacturer states that motorisation cannot be disabled. No stationary-platter mode is invented.
Play, main Cue, tempo, platter/wheel, RPM/motor modes, startup/shutdown, output and automatic audio stay inactive.
No motor packet, downloaded mapping action or hardware write runs. Use app touch transport and separate audio.
The manual subset does not establish a complete T10 integration. Full modes/lifecycle and physical acceptance remain open.

Xone:96 uses nine manual inputs on default MIDI channel16: four linefaders, direct main Cue states and the crossfader.
Physical CH1-4 map A-D. C/D require the existing four-deck option. Source-selector reports rearm only their deck's pickup.
MIDI output to Cue/filter changes real hardware state, so feedback and hardware writes remain disabled.
Analogue gain/four-band EQ/filter/headphone controls, auxiliary Cue/PHONES2 and external deck routing remain outside this subset.
The manufacturer confirms class-compliant iPadOS/iOS USB. Configure app audio separately. Physical acceptance remains open.

PX5 and24C use distinct manual fader subsets on MIDI channel16.
PX5 uses channel fadersCC0-3 and crossfaderCC4. Native explicitly maps physical CH1-4 to A-D.
24C uses channel fadersCC5/6 and crossfaderCC4. Shared frequencyCC7 and unqualified button notes stay inactive.
No Xone96/23C alias, analogue EQ/gain/headphone control, hardware write or automatic audio route is inferred.
Use deliberate manual ownership and separate app audio. Complete external mixer routing and physical acceptance remain open.


VMS5 uses its own public manufacturer TSI and independent DEX wire facts. The manual subset has40 inputs.
Explicit source-local software banks route shared transport, tempo and cyclic jogs to A/C and B/D.
One press changes a bank once. Releases rearm it. Changes retire owned holds and reset both banks' pickup/counters.
Fixed C/A/B/D mixer strips retain their targets and pickup. C/D require the app option.
Initial/reconnected banks are A/B. Post EQ and deliberate analogue/software mixer ownership are required.
The source2730-count jog scale conflicts with a manufacturer2000-point claim. Calibration remains provisional.
Unqualified Shift, Vinyl/keylock, PFL, FX/pads, library encoder and hardware output stay inactive.
No downloaded code, query, installer, firmware or audio command runs. Full modes and physical acceptance remain open.


VMS4.1 Traktor has an independent24-input manual mixer subset from its separately listed manufacturer MIDI table.
MIDI channel1 carries four gain/EQ/linefader strips, master28, normal crossfader31, Cue mix34 and Cue gain35.
Native explicitly assigns physical MIDILOG1-4 to A-D. Pickup and four-deck gating retain existing app controls.
Generic transport labels conflict with the Traktor faceplate. No sibling transport/bank/jog/Shift or hardware write is inherited.
Use Post EQ for software EQ and deliberate analogue/software ownership. External audio and physical acceptance remain open.


Public ProMixer XML adds independent manual AFX44-input and Mixtrack Edge51-input subsets.
Only MIDI address facts are transcribed. No source XML, executable, installer or mapping action is bundled or run.
AFX retains six Cue pads, eight fixed loops1/4-32, loop/transport pads and strict browse/load on A/B.
Known mode reports retire owned holds. Generated EQ/level aliases101-108 and unqualified tactile/FX/C-D modes stay inactive.
Edge retains normal transport, three cues, manual loops, PFL, two-band mixer and strict1/127 browse.
One shared Shift input retires owned holds and supports alternate releases without firing unsupported actions.
Overflow commands137/142-144/164 do not become raw notes. Jog/tempo modes, feedback, audio and physical acceptance remain open.
Both profiles stay manual. The earlier AFX sign-in audit remains specific to its historical source.


DJM-S3 uses18 independent manufacturer-table CC inputs in a manual profile.
Cached table text qualifies gain/EQ/Color/faders, direct Cue states and cross/master/headphone/blend.
Direct table PDF bytes/screenshots were unavailable. No source byte hash or visual table claim is made.
The operating manual page21 visually confirms MIDI1/TOGGLE defaults. Source notes reset only their strip's pickup.
No DJM450/250/S9 alias, stored-setting write, hardware output or automatic audio route is inferred.
Full modes/lifecycle, external deck outputs, analogue ownership and physical acceptance remain open.

R390 adds `legacy_djay_docks.py` and two distinct21-input manual profiles from pinned public factory presets. They require exposed MIDI ports. Original30-pin/Lightning authentication and audio remain open. Unqualified rotary streams, private custom classes and hardware writes stay inactive.232 source checks, nine native tests and the iPad framework pass. Earlier273 recipes remain identical.

R391 adds `vci300_mkii.py`. The official versioned Mixxx manual explicitly states unchanged MIDI mapping. The distinct MKII profile reuses the reviewed61 inputs/24 lamps and existing lifecycle bytes.234 source checks,12 native tests and the iPad framework pass. Audio and hardware-specific calibration remain open. The original profile and all earlier recipes remain identical.

R392 pins all487 public VirtualDJ product entries in `sources.lock.json`. `virtualdj_inventory.py` retains product URLs/categories and explicit name resolutions. Two passive timecode media stay outside digital-device model counts. The18 audio interfaces/DVS kits do not become MIDI controllers. The catalogue adds210 records and now tracks552 physical models. All276 runtime recipes remain byte-identical.237 source checks pass. Wider manufacturer coverage, all238 first-protocol gaps and complete feature parity remain open.

R393 adds `legacy_djm_mixers.py` with independent900NXS,850 and750MK2 manufacturer references. Each manual profile has32 absolute inputs and direct Cue states. Only750MK2 has its documented source-selector pickup resets.240 source checks, eight native tests and the iPad framework pass. Earlier276 recipes remain identical. Hardware processing, full modes and external audio remain separate.


R394 adds independent900SRT32-input, original75028-input and250MK218-input manual mixers in `more_legacy_djm_mixers.py`. A small shared field builder retains each caller's explicitly reviewed strip layout and Color presence. SRT uses C/A/B/D. Original750 has no strip Color or inherited MK2 selector.250MK2 table evidence remains cached text without table bytes/screenshots; its own operating manual is pinned.243 source checks, ten native tests and iPad framework compilation pass. Earlier279 recipes remain identical.


R395 adds separate original2000 and2000NXS manufacturer facts in `djm2000_mixers.py`. Each manual profile has32 Zone1 mixer inputs, with required Zone1 MIDI1/Toggle and editable touchscreen Zone2 MIDI2. No source report or touchscreen action is inferred.246 source checks,11 native tests and iPad framework compilation pass. Earlier282 recipes remain identical.


R396 adds `legacy_pioneer_transport.py`: T1 manual60-input/14-lamp mappings with three-layer mixer aliases and release-only alternate Cue; MEP7000 automatic26-input controls with independently qualified speed jogs, centred pitch and direct loading. T1 feedback needs separate manual opt-in and has no automatic startup/shutdown.249 source checks,12 native tests and iPad framework compilation pass. Earlier284 recipes remain identical.


R397 adds independent `instinct_p8.py` facts:86 inputs,256-count wheel/contact streams, native count/1024 Shift pitch, four cue pads per side, loops, A/B plus opt-in Shift C/D mixer fields and22 bounded lamps. Both Shift edges use the existing per-side cleanup contract.252 source checks,11 native tests and iPad framework compilation pass. Earlier286 recipes remain identical.


R398 adds `universal_dj.py`:111 inputs and30 lamps from independently reconciled manufacturer djay/Traktor archives and current factory XML. Explicit pitch pairs1/33,2/34 and55/71,56/72 stay separate. Current mixer consensus resolves the older PDF errors. The fixed A/B USB core keeps Bluetooth/tablet and automatic audio open.255 source checks,11 native tests and iPad framework compilation pass. Earlier287 recipes remain identical.


R399 adds `wave_usb.py`:42 inputs and14 lamps, composed MODE Shift from both manufacturer djay mappings, Shift loading/browse and512-count contact/wheel jogs from the manufacturer VirtualDJ definition. Current DJUCED720 calibration, ambiguous PFL, ring/setup and Bluetooth/tablet remain open.258 source checks, ten native tests and iPad framework compilation pass. Earlier288 recipes remain identical.


R400 adds independent `twitch_basic.py` facts from the public Novation programmer guide:139 Basic inputs,44 static lamp mappings, source-local A/C and B/D loads, contact-gated signed SWIPE and absolute DROP. Automatic software banking is limited to paired load-only profiles. Advanced arbitration, full modes/audio and physical calibration remain open.261 source checks,19 native tests and iPad framework compilation pass. Earlier289 recipes remain identical.


R401 adds independent `akiyama_charts.py` manual facts:98 Quattro,200 Quark SC and125 TTWO inputs. Separate manufacturer charts qualify each channel layout, normal controls, selected mixer fields and alternate release wires. Disputed pitch/jog/output rows remain inactive. No hardware write is sent.264 source checks,11 native tests and iPad framework compilation pass. Earlier290 recipes remain identical. Automatic setup and complete modes/audio/calibration remain open.


R402 adds `launchpad_programmer.py`: independently reviewed X, Pro MK3 and original Pro grids, each with64 inputs/52 static lamps in a native four-quadrant DJ layout. X/Pro MK3 use documented MIDI interfaces, Programmer/Live setup and two104-byte clear packets. Bounded startup-abort metadata attempts Live recovery after partial setup failure. Original Pro remains manual on its independent Standalone/channel1 contract.267 source checks,31 native tests and iPad framework compilation pass. Earlier293 recipes remain identical. Full modes/feedback/lifecycle and physical acceptance remain open.


R403 adds `apc_mini_mk2.py` from the independent manufacturer protocol:74 Session-channel1 inputs,52 channel7 full-brightness lamps, Control-port qualification, Shift cleanup, nine native faders and bounded introduction/range-clear messages. `native_dj_grid.py` reuses only app functions across separately reviewed wire grids; all296 earlier recipes remain identical.270 source checks,20 native tests and iPad framework compilation pass. Other modes/channels, full lifecycle and physical acceptance remain open.


R404 adds independent `apc40_generations.py` facts:114 MKII/113 original inputs and68 feedback bindings each. Separate product/grid/colour contracts use public momentary unbanked Mode1 and bounded Generic exit. A narrowly validated paired-unbanked contract permits global channels with all16 Shift cleanup selectors; track channels remain explicit.273 source checks,37 native tests and iPad framework compilation pass. Earlier297 recipes remain identical. Complete modes/state/ring/lifecycle and physical acceptance remain open.


### Compact application resource (R452)

The existing generation command writes the full review JSON and a sibling `factory-controller-profiles.compact.json` file. SwiftPM excludes the full review JSON from the application bundle. Native loads the compact file.

The compact file shortens input field names and omits only Note/absolute/non-inverted defaults. It removes three profile metadata fields that native already ignored: definition, gaps and hardwareMode. Scope, source, aliases, all input options, output values and setup packets remain unchanged. The full form retains its required fields. Mixed recognised full/compact keys are invalid.

Keep the existing4MiB,512-profile,512-input and128-output limits. Add any new input field to both the compact producer and native decoder. Unknown producer fields stop generation. Source tests must expand the compact file to the full reviewed values. Native binding comparisons must remain exact. See the [storage contract](../../docs/coordination/controller-catalogue-storage.md).

R452 reduces the application resource from4,157,594 to2,051,892 bytes for377 unchanged recipes. All24,689 native input bindings match. Physical/iPad/A10X timing remains unverified.
