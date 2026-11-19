# Controller coverage

Request R23. Updated 18 November 2026. Erik owns an original Z1 and allows a hardware bridge when direct iPad access is unavailable. The A10X iPad remains the app target. Erik remains the sole acceptance tester.

## R248 original Instinct factory-backed core

The original Instinct gains an automatic core and an explicit audio-layout declaration. P8 and iPad-specific variants remain separate.
The factory specification gives master outputs 1–2 and headphone outputs 3–4.
The existing known-device routing path applies that layout and preserves manual, ambiguous and unavailable-device handling.
No hardware gain-button behaviour is inferred from the channel layout.

Factory normal jogs use CC 48/49. The pinned pressure script adds CC 50/51 and a 128-count scratch scale.
Pressure motion requires the factory contact notes 26/52 and cannot act as an unheld platter report.
Both streams use native signed decoding. The pressure stream's signed boundary is inferred from the factory normal-wheel format.
The script treats raw 64 inconsistently; a physical capture remains necessary to qualify that boundary and scratch calibration.
Factory pitch-lever values are 1/127. Zero is ignored, avoiding the legacy handler's treatment of every other value as an upward step.
Native tempo steps and four-percent held bends keep saved Sync and deck tempo ownership. Source fast/slow and opposing-button tempo reset remain open.

The native cue page uses all four factory Cue keys per deck. Published manual-loop press addresses retain In, Out, Reloop and Halve.
Native EQ polarity follows the pinned source while the factory's rotation wording remains a calibration question.
Factory LED addresses and active-low values replace conflicting community rows: on 0, off 127.
Pad/loop feedback, source held cue previews, headphone gain buttons, FX and samples remain open.
Startup clears all 43 factory-listed light addresses, then enables fixed Scratch indication. Shutdown clears the seven native-owned indicators.
The 51-message lifecycle requires a 64-message total bound. The validator accepts 64 and rejects 65; discovery/disconnect receives this work, with none added to audio rendering.

All 39 targeted Swift checks, 81 importer/report checks and native iPad compilation pass.
The audio fixtures include master/headphone samples, interruption/disconnect recovery and repeated detection without sample changes.
The bundled resource matches the source. All 164 other recipes remain unchanged.
Factory coverage reaches 113 profiles for 119 physical models, plus six other native models.
The repository check retains twelve existing historical-link failures.
Source identities and results appear in `TestBuilds/r248/validation.json`.
Physical USB/audio proof, pressure/EQ calibration, firmware-driven light cleanup and A10X acceptance remain open. No signed app or installation was produced.

## R247 U-Mix Control Pro 2 core and owned pitch indicators

Pro 2 gains an automatic two-deck core from pinned XML and its short companion script.
Original Pro and Control 2 retain separate identities.
Full-value contact follows the published handler: only 127/127 presses; lower values release.
The same rule handles expanded MIDI note values and bypasses generic zero-value button coercion.
Midpoint contact on iDJ Live II retains its separate existing rule.

Native scratching keeps 340 counts per revolution, with distinct platter and rim addresses.
Centred fourteen-bit pitch preserves pickup and applies source polarity once.
Play, held Cue, Sync, PFL, Key Lock, levels, EQ, direct Load, browsing and four native cues retain published dispatch.
Shifted-channel cue-clear releases rearm ordinary cues; clear presses remain inactive.
The source's quarter-strength nudge multiplier and held Hot Cue preview behaviour remain open.

Native held pitch uses the shared four-percent temporary rate. The two direction indicators show owned holds independently.
Opposing holds light both indicators while cancelling to normal speed. New source generations and later touch/rate control retire old feedback.
A real-file native fixture checks that the final old releases cannot overwrite a later rate, with saved Sync retained.
Play uses the known beat-light address as a steady indicator. Beat pulses and jog-direction lights remain open.
The source's inverted Sync condition resolves to native on 100/off 0.
Startup clears unsupported EQ-kill, Cue, end-of-track and Tap indicators. Shutdown clears twenty declared outputs.
The total lifecycle budget is 32 messages. Clip indication, full feedback/cleanup and audio routing remain open.

All 53 targeted Swift checks, 80 importer/report checks and native iPad compilation pass.
The bundled resource matches the source. All 164 other recipes remain unchanged.
Factory coverage reaches 112 profiles for 118 physical models, plus six other native models.
The repository check retains twelve existing historical-link failures.
Source identities and results appear in `TestBuilds/r247/validation.json`.
Physical calibration and acceptance remain open. No signed app or installation was produced.

## R246 Mixer One four-target native mixer core

Mixer One gains an automatic mixer/accessory core. Published XML gives each target its own wire channel from 0xB5 through 0xB8.
Each physical side uses its documented gain/EQ/level/PFL addresses. C/D retain the app's deck-availability limits.
The global master/headphone/cue-mix/crossfader strip retains both published channel-5/channel-7 address sets.
PFL feedback uses the XML's own note addresses and on/off values.

Native pickup protects continuous controls. Published Clear Meter reports rearm all four deck targets without inferring a new deck.
Startup clears the twelve unsupported EQ-kill indicators and eight meter addresses.
Shutdown clears all declared PFL and meter indicators. The lifecycle total is exactly 32 messages.
Live VU feedback remains open. Fader position is not used as an audio-level measurement.
The source's inverse master-mute restore, EQ-kill actions and crossfader curve/balance control remain unmapped.
These controls need native ownership/state contracts before they can safely change a live mix.

All 36 targeted Swift checks, 79 importer/report checks and native iPad compilation pass.
The bundled resource matches the source. All 164 other recipes remain unchanged.
Factory coverage reaches 111 profiles for 117 physical models, plus six other native models.
The repository check retains twelve existing historical-link failures.
Source identities and results appear in `TestBuilds/r246/validation.json`.
Audio routing, full control/feedback coverage and physical acceptance remain open. No signed app or installation was produced.

## R245 RANE FOUR experimental-source audit

The existing RANE FOUR record now links a pinned community mapping and its source history.
The learned XML contains useful transport, mixer and paired-tempo addresses for two targets.
It does not establish cold-start bank routing for a four-deck controller.

The README calls MIDI channel 0 the right platter, while the script XML assigns it to Channel 1.
The larger XML assigns different press/release functions to deck B's Sync address.
The jog script contains duplicate handlers, uninitialised state and a section explicitly labelled as not working.
Its script XML also names handlers without establishing a working scratch implementation.
The commented state-query and LED examples are not qualified RANE lifecycle messages.

Automatic selection remains disabled. No guessed jog decoder, calibration, bank dispatch, startup packet or motor behaviour was added.
RANE ONE and PERFORMER retain separate identities and protocols.
A qualified bank report, captured platter direction/count contract and consistent physical dispatch remain necessary.
All 78 importer/report checks pass. All 165 runtime recipes remain byte-for-byte unchanged.
The catalogue still has 305 records. The repository check retains twelve existing historical-link failures.
Pinned source hashes and results appear in `TestBuilds/r245/validation.json`.
No new native build, signed app, installation or physical acceptance was produced.

## R244 measured Reloop Ready native core

Ready gains a native core from the author's measured protocol, source profile, XML and companion script at a pinned revision.
Buddy keeps a separate identity. The source has captured hardware evidence; this work has no physical Ready acceptance.

Pitch uses explicit CC 9/63 pairs with measured travel 0–1023. Native decoding waits for a fresh pair and rejects values outside that travel.
The recipe preserves source inversion and pickup. It does not stretch a 16,383-step range across a 1,024-step fader or invent a calibrated midpoint.
Master, headphone, cue mix, crossfader, channel levels, two-band EQ, gain and filter controls reuse native contracts.
Direct Load and normal transport keep their published addresses. Shifted Note Off aliases release Cue and rearm ordinary buttons.
Source clone, censor, key-sync and delete presses cannot trigger their normal alternatives.

Native fixed touch scratching retains 1,024 counts per revolution. Startup enables each Vinyl indicator.
New touch contacts during unsupported Shift search stay blocked. Existing contacts can still release.
The software Vinyl toggle and percentage-based fast Shift search remain open.

Hot Cue, 1/2/4/8-beat toggle loops and manual loops use independent pad-mode guards on each deck.
Native half/double buttons work on the two loop pages. Other pages stay inactive.
Native Hot Cues retain the app's existing one-press behaviour; source held cue previews remain open.
Mode-dependent pad feedback, loop movement, reloop-and-stop, other pages, FX and shifted folder control remain open.
Startup clears all sixteen RGB pads. MODE indicators are firmware-owned and receive no host packets.
Eight reviewed feedback controls and fixed Vinyl indicators have explicit shutdown packets. Total lifecycle messages: 28.

All 21 targeted Swift checks, 77 importer/report checks and native iPad compilation pass.
The bundled resource matches the source. All 164 earlier recipes remain unchanged.
Factory coverage reaches 110 profiles for 116 physical models, plus six other native models.
Automatic core coverage reaches 62 of the 122 pinned Serato benchmark models.
The repository check retains twelve existing historical-link failures.
Validation results and source identities appear in `TestBuilds/r244/validation.json`.
Full feedback/cleanup, audio routing, physical fader/jog calibration and A10X acceptance remain open.
No signed app or installation was produced.

## R243 factory-layout Xone K1/K2/K3 native core

K1, K2 and K3 gain one reviewed family recipe. Factory manuals confirm the shared note/controller layout and default MIDI channel 15.
The K3 factory map retains K2/K1 values and colours. The published shared mapping requires compatible K3 firmware.
K2/K3 hardware latching layers must be off. Custom unit maps, other MIDI channels and X-Link layouts remain unqualified.

The two middle columns control decks A and B. Play, Cue, PFL, Sync, three-band EQ, levels and browser controls retain source dispatch.
The right large button acts as Shift. Hold the lower-right encoder and press a deck's Play button to Load that deck.
Independent and combined modifier scopes prevent the Load chord from also toggling Play.
Releasing either modifier preserves the other. Modifier state stays local to the physical MIDI source.
Shifted top encoders adjust gain. Shifted bottom encoders adjust master or headphone level.
Low EQ returns to its normal function after Shift and rearms pickup; the source's persistent quick-effect latch is not copied.

The native lower button grid stays on four Hot Cues per deck. The left large button lights the fixed Hot Cue page.
This follows the published mapping's page use; the K1's printed left-button SHIFT label does not describe this native layout.
The source's intro/outro, loop, supershift and outer FX-column modes remain open.
Red Play/PFL/Sync/cue lights use the factory Note Off velocity 127. Shutdown clears every declared indicator.
The sixteen-message startup/shutdown total stays within the existing lifecycle budget.

All 15 targeted Swift checks, 76 importer/report checks and native iPad compilation pass.
The bundled resource matches the source. All 163 earlier recipes remain unchanged.
Factory coverage reaches 109 profiles for 115 physical models, plus six other native models.
This reaches 121 automatic core models overall, including 61 of the 122 pinned Serato benchmark models.
These are core mappings, with hardware acceptance and full feature parity still open.
The repository check retains twelve existing historical-link failures.
Source identities and results appear in `TestBuilds/r243/validation.json`. No signed app or installation was produced.
K2 audio routing, firmware/device checks and physical acceptance remain open.

## R242 original VCI-100 native core

The original VCI-100 gains an automatic two-deck native core. Hile, MixVibes 3DEX and MKII retain separate identities.
The catalogue now names the reviewed original rather than inheriting the first alternative mapping's 3DEX label.
Cue Goto, held Preview and Set remain three separate physical buttons per deck.
Play, Sync, PFL, direct Load, held pitch buttons, three-band EQ, levels and browser buttons retain published dispatch.
Tempo accounts for source inversion once, with exact centre and pickup.

Platter CC 16/17 requires physical contact. Ring CC 18/19 keeps a separate native nudge action.
The source calibrates scratch at 384 ticks per revolution and 45 RPM. Native 33⅓-RPM motion therefore uses 518.4 counts.
A direct motion check verifies that 384 counts cover 4/3 seconds of source audio rather than 1.8 seconds.
Native nudge response replaces the source's arbitrary three-times jog multiplier. Physical feel remains unverified.

Shared loop/hotcue selector keys, source acceleration, FX, balance, lights/cleanup and audio routing remain open.
The recipe sends no guessed feedback or setup packets.
All 24 final targeted Swift checks, 75 importer/report checks and native iPad compilation pass.
An initial check assumed an order for independent jog callbacks; the corrected fixture compares their actions.
The bundled resource matches the source. All 162 other recipes remain unchanged.
Factory coverage reaches 108 profiles for 112 physical models, plus six other native models.
The repository check retains twelve existing historical-link failures.
Validation results and source identities appear in `TestBuilds/r242/validation.json`.
No signed app, installation or physical acceptance was produced.

## R241 LC6000 PR-port native player core

LC6000 PRIME gains a native player recipe from Denon's factory table and a pinned published mapping.
Each physical control port uses the existing player allocator. Two connected players can control A and B independently.
Only exact PR port names qualify. WD display ports, duplicate PR inputs and ambiguous PR outputs remain inactive.
Other profiles retain their existing single-input rule. Startup reaches the paired PR output on the same device.

Factory CC 55/54 wording does not fully describe jog dispatch. The pinned script uses CC 55 as direction state and CC 54 as movement.
Forward movement uses the received value; reverse movement subtracts 127. Native decoding waits for direction before applying movement.
Direction persists across ticks and remains separate for each source. The source's CC 17/49 handlers are no-ops and remain unmapped.
Native touch scratching retains the published mapping's 1,024-count calibration. Physical calibration remains open.

The recipe retains paired pitch, held pitch bend, Cue, direct Load, Play, Sync, Key Lock, manual loops, loop size and browsing.
Native Load acts on the button press. Held-Select waveform zoom and preview loading remain outside this core.
Hot Cue pads and 1/8-to-16-beat toggle loops require their own mode. Roll and Slicer cannot trigger either page.
Shift guards unsupported alternatives. Release aliases rearm ordinary button edges after a shifted release.
Startup clears other pad-mode lights and enables Hot Cue and fixed Vinyl indicators. Shutdown clears the nine declared indicators.
Pad feedback remains unmapped because it changes with mode. Display SysEx, needle strip, software Vinyl/range modes and full feedback/cleanup remain open.

All 56 final targeted Swift checks, 74 importer/report checks and native iPad compilation pass.
The bundled resource matches the source. All 162 earlier recipes remain unchanged.
Factory coverage reaches 107 profiles for 111 physical models, plus six other native models.
Automatic core coverage reaches 60 of the 122 pinned Serato benchmark models.
The repository check retains twelve existing historical-link failures.
Validation results and source identities appear in `TestBuilds/r241/validation.json`.
The player has no automatic audio-output declaration. Physical USB naming, routing and A10X acceptance remain open.
No signed app or installation was produced.

## R240 iDJ Live II touch-gated native core

iDJ Live II gains an automatic two-deck core from pinned XML and its companion script.
The original iDJ Live and iDJ Pro keep separate identities. Their protocols are not inferred from this recipe.
Native fixed scratching retains 640 counts per revolution. Every jog tick requires contact from the same physical MIDI source.
The published contact threshold is 64/127. Lower positive velocities release contact rather than acting as new presses.
The same midpoint rule handles CoreMIDI's expanded note values. Explicit Note Off always releases contact.
Saved custom mappings retain the contact gate, encoding and resolution after endpoint changes.

Cue Set records the playhead. Cue Goto recalls that point without changing play/pause.
These actions reuse the existing main Cue point and native jump path, including the saved Sync choice.
The recipe also retains direct Load, Play, Sync, held pitch buttons, two-band EQ, levels, browsing and inverted crossfader.
Startup sends the exact state-query SysEx and enables the fixed scratch indicator. Shutdown clears Play, Sync and Scratch lights.
The source's software scratch-mode toggle and skin-only library expansion remain unmapped.

All 56 final targeted Swift checks, 73 importer/report checks and native iPad compilation pass.
The bundled resource matches the source. All 161 other recipes remain unchanged.
Factory coverage reaches 106 profiles for 110 physical models, plus six other native models.
The repository check retains twelve existing historical-link failures.
Validation results and source identities appear in `TestBuilds/r240/validation.json`.
Remaining modes, full feedback, audio routing, calibration and physical acceptance remain open.
No signed app or installation was produced.

## R239 CMD Micro core and held pitch bend

CMD Micro gains an automatic two-deck native core from pinned XML and script dispatch.
It retains direct Load, Play, held Cue, Sync, PFL, 4/8-beat toggle pads, browsing and mixer controls.
Exact-centre tempo keeps source polarity and pickup. Native touch scratching retains 128 counts per revolution.
Published Play/PFL feedback uses on 1/off 0 after resolving the source's inverted indicator condition.

Held pitch buttons apply a temporary four-percent rate change. Opposing holds cancel each other.
Final release, Note Off and disconnect restore normal speed. Source generations isolate replacement tracks.
Later touch/rate commands retire an older hold, so its release cannot overwrite the newer control.
The saved Sync choice and deck tempo stay unchanged. Normal-speed restoration reuses native grid alignment.

The initial two-deck fixture sent a new bend while deck B was waiting for its quantised start.
New bends remain blocked while queued. A held bend can now return to normal speed while queued through the existing validated rate path.
Other queued performance changes remain blocked. The scheduled start and Sync choice remain unchanged.
The corrected fixture advances the offline audio clock until both decks are playing before bending both.

All 82 final targeted Swift checks, 72 importer/report checks and native iPad compilation pass.
The bundled resource matches the source. All 161 other recipes remain unchanged.
Factory coverage reaches 105 profiles for 109 physical models, plus six other native models.
The repository check reports twelve existing broken links in untouched historical files.
Validation results and source identities appear in `TestBuilds/r239/validation.json`.
Optional key-bend mode, Cue/Sync lights, complete cleanup, audio routing, calibration and physical acceptance remain open.
No signed app or installation was produced.

## R238 VCI-400 four-target native core

VCI-400 now selects a reviewed four-target native core automatically. EGE firmware retains a separate, unsupported identity.
Pinned XML gives each deck a direct Load input, avoiding a shared cold-start Load target.
Known transport-note variants retain Play and held Cue. C/D retain the existing app deck limits.

Native touch scratching retains 4,096 counts per revolution. Paired tempo and level controls keep their low bytes.
Bank loss and selection reports release Cue/platter contacts and reset pickup only on their own physical side.
These reports retain held global Shift. Shift guards source eject/brake alternatives and rearms tempo pickup.

Native pad mode starts at Hot Cue. Eight cues and fixed loops from 1/8 to 16 beats have explicit per-deck mode guards.
Roll and Sampler pages cannot trigger either action. Fixed-loop presses enable their size without toggling an active loop off.
The native recipe retains deck D's eighth published pad dispatch, which the script constructor omits.
Pad feedback remains unmapped because the source changes its meaning with the selected mode.

A centred direction encoding converts each non-zero loop-knob packet into one step, regardless of its magnitude.
Source positive direction halves the loop. Native loop-size preselection also works before activation.
The encoder ignores its centre and malformed values.

Startup clears all previous mode indicators before lighting Hot Cue on each deck. Shutdown clears all sixteen mode lights.
The setup budget increases from sixteen to thirty-two validated messages across startup and shutdown to fit these exact sequences.
Only discovery/disconnect uses these messages. The audio render path receives no new work.

All 62 final targeted Swift checks, 71 importer/report checks and native iPad compilation pass.
Fixtures cover mode isolation, all deck targets, held Shift, bank release, pickup, the setup bound and native scratch/loop behaviour.
The bundled resource matches the source. All 161 other recipes remain unchanged.
Factory coverage reaches 104 profiles for 108 physical models, plus six other models through native adapters.
The catalogue retains 305 records and 162 data recipes. Automatic core coverage reaches 59 of the 122 pinned Serato benchmark models.

CC transport aliases, shared bank-dependent Key Lock, scratch-button contact, brake/inertia code, other modes and full lights remain open.
Master/headphone controls, complete cleanup, audio routing, calibration and physical acceptance also remain open.
Source identities and validation results appear in `TestBuilds/r238/validation.json`. No signed app or installation was produced.

## R237 original Inpulse 200 factory-backed native core

The original Inpulse 200 retains its identity and gains a reviewed native recipe. Its earlier partial recipe already selected automatically.
The factory table adds physical Shift reports and high-resolution mixer pairs. The pinned script supplies its scratch scale and lifecycle packets.

The official DJUCED guide confirms manual In, Out/Exit and long-In four-beat activation.
A typed Out/Exit action uses the existing native loop engine. Long In enables a four-beat loop without toggling an active loop off.
Release aliases preserve normal and shifted loop-button edges. Native scratching retains 248 counts per revolution and four-times shifted search.
Factory signed jog magnitudes replace the community script's single-step clamp.

Normal gain, two-band EQ, filter, levels, tempo and crossfader retain paired precision.
Per-deck Shift rearms pickup and protects normal controls. Four cues remain separate from roll, sample and effect pages.
The manufacturer table contains conflicting shifted PFL/Load/long-press rows. Those rows remain unmapped.
XML dispatch and channel-based handlers retain confirmed right-deck addresses where the factory shifted table repeats the left channel.

The official guide documents master outputs 1–2 and headphones 3–4. The recipe declares that automatic layout explicitly.
Master/headphone knobs remain hardware-driven. Their MIDI messages do not apply another software gain stage.
Other models receive no inferred audio flag.

All 17 targeted Swift checks, 70 importer/report checks and native iPad compilation pass.
Native fixtures verify manual loop activation/exit, repeated long-In activation, wheel stop and preserved Sync.
Offline route/transport and sample-continuity fixtures now include the original Inpulse 200 alongside Z1 and Scratch.
The bundled resource matches the source. All 161 other recipes remain unchanged.
Factory counts remain 103 profiles for 107 physical models, plus six other models through native adapters.
Other modes, conflicting shifted rows, full feedback, cleanup, firmware capture, calibration and physical acceptance remain open.
Source identities and validation results appear in `TestBuilds/r237/validation.json`. No signed app or installation was produced.

## R236 MC3000 factory protocol audit

The catalogue now links Denon's original MC3000 manual to the existing model.
Factory pages 14–17 resolve several community-source conflicts:

- Master, microphone, headphone and monitor-pan controls do not send MIDI.
- Community assignments for those functions overlap factory effect-knob messages and must not enter the native recipe.
- Positive button reports use value 64. Deck-change notes are A 3, B 8, C 9 and D 10.
- The pitch slider sends standard fourteen-bit Pitch Bend messages.
- The factory state request is CC74/value57. Its documented scope covers sliders, volumes and faders.

The community mapping defines Load and tempo only for A/B despite other C/D controls.
The manual documents bank-dependent loading. Its channel diagram places shared Load controls on the first channel.
Cold-start bank reporting and shared Load dispatch still need qualification.
Automatic MC3000 selection remains disabled. No runtime recipe changes in this audit.
The source's 100 scratch ticks at 330 RPM must not become 100 ticks at native 33⅓ RPM.

The manual hash, rendered tables and source-bound audit evidence appear in `TestBuilds/r236/validation.json`.
All 69 importer/report checks pass. The existing 305 records, 162 recipes and automatic counts remain unchanged. Physical acceptance remains open.

## R235 separate Starlight and DJControl MIX native cores

Starlight and DJControl MIX now have reviewed native recipes for their distinct physical dispatch.
Their earlier partial recipes already selected automatically. This increment completes core behaviour without adding to the automatic model count.
Pinned script and XML hashes retain each model's source identity.

Native fixed touch scratching uses 248 counts per revolution and single-step 1/127 wheel reports.
Separate touch and wheel-edge inputs preserve the native player policy.
Shift blocks unsupported accelerated search. Alternate-channel releases finish held Cue and platter contact on the correct deck.
The right shifted wheel callback derives deck B from its MIDI channel despite an incorrect Channel1 group in the source XML.
Release-only cue-pad aliases rearm ordinary pads without executing the source delete function.

Both models retain Play, held Cue, Sync, PFL, paired inverted tempo, level, bass, filter and crossfader inputs.
Four cues and distinct 1/2/4/8-beat loop pages stay separate from sampler and effect pages.
MIX uses loop notes 48–51. Starlight uses notes 16–19.
Only MIX adds the source's master and headphone amount controls.
The reviewed sources define no Load or browser inputs. Loading remains available through the app's touch controls.

Both startup sequences enable the fixed scratch indicator and query current control values after input connection.
Starlight disables its base light show and restores it on shutdown. MIX uses its own all-lights-off shutdown.
The native recipes omit source effect presets, sampler-count changes, unsupported cue-master/split toggles and dynamic base lights.
Core Play, Sync, PFL and cue-pad feedback retain reviewed addresses. Fixed-loop lights and complete feedback remain open.

All 38 targeted Swift checks, 68 importer/report checks and native iPad compilation pass.
Offline fixtures verify wheel stop, fixed-loop size and the saved Sync choice for both models.
The first fixture compile failure remains preserved. Its correction uses the existing performance state contract.
The bundled resource matches the source. All 160 other recipes remain unchanged.
Factory counts remain 103 profiles for 107 physical models, plus six other models through native adapters.
The catalogue retains 305 records and 162 data recipes.
Full modes, feedback, cleanup, audio routing, Bluetooth pairing, physical calibration and A10X acceptance remain open.
Source identities and validation results appear in `TestBuilds/r235/validation.json`. No signed app or installation was produced.

## R234 VCI-100MKII four-target native core

The existing VCI-100MKII recipe now selects its own four-target core automatically.
Pinned XML and script handlers define A/B/C/D channels and physical A/C and B/D bank reports.
The original VCI-100 retains its separate record and implementation status.

A dedicated tempo decoder preserves fourteen-bit raw values, exact centre 8192 and the source endpoint asymmetry.
Every result requires a fresh high/low pair. Pitch, level and crossfader pairs declare their unusual sixteen-controller offset explicitly.
This prevents the standard thirty-two-controller assumption from pairing unrelated controls.
The tempo encoding requires the factory profile. Native pickup protects tempo across Shift and bank changes.

Physical Shift uses fixed notes on the global channel. Its scopes survive deck-bank changes.
Each bank report releases held Cue and platter contacts only on its own physical side.
Shifted release aliases rearm ordinary buttons and finish held Cue without executing unsupported alternate actions.
Both Shift keys guard loop-size buttons because the source changes their meaning under either hold.

Native fixed touch scratching retains 2,400 counts per revolution.
Other core controls include gain, three-band EQ, paired levels, crossfader, master/headphone amounts and Cue Mix.
Play, held Cue, Sync, Key Lock, two Hot Cues, native loops, browsing and Shift/Load retain reviewed dispatch.
C/D keep the existing app deck limits. Source focus movement, quantised pitch, pitch adjustment and brake/slip timers remain unmapped.
Feedback retains reviewed core addresses. Bounded cleanup clears Play, Sync, Key Lock and PFL, with remaining lights still open.

Factory coverage reaches 103 profiles for 107 physical models. Six other models retain automatic native adapters.
The catalogue retains 305 records and 162 recipes. All 161 other recipes remain unchanged.
Full modes, feedback, cleanup, audio routing, physical calibration and A10X acceptance remain open.
All 38 targeted Swift checks, 67 importer/report checks and native iPad compilation pass.
The tempo fixture checks every fourteen-bit value. Mixer fixtures reject unrelated standard-offset low bytes.
The exhaustive Cue check now selects press bindings, while dedicated fixtures verify release-only aliases.
The first run's fixture failures remain recorded. The bundled resource matches the source.
Source identities and validation results appear in `TestBuilds/r234/validation.json`.
No signed app or installation forms part of this increment.

## R233 VCI-300 cyclic jogs and nine-bit tempo

The existing VCI-300 record now selects a reviewed two-deck native core automatically.
Pinned XML dispatch and script handlers retain distinct A/B addresses on MIDI channel zero.
This review covers the original VCI-300. It does not alias the VCI-300MKII.

A dedicated jog decoder consumes a fresh high/low pair and primes the first position without movement.
It converts cyclic fourteen-bit positions into signed movement and preserves both wrap directions and the source half-range boundary.
Native fixed touch scratching retains 1,600 counts per revolution. Source mode toggles, search and nonlinear curves remain outside this increment.
The tempo decoder extracts nine bits, preserves centre 256 and reaches both endpoints through the source's unequal ranges.
Soft takeover protects tempo. Shift rearms pickup and clears incomplete pairs and counter positions.

Existing modifier scopes combine physical Shift and Scroll without new profile metadata.
Releasing either hold cannot enable a jog while the other hold remains active.
Deck Shift remains local. Held Cue and platter contacts retain physical release handling across modifier changes.
Scroll plus PFL loads the selected track. Native PFL retains the app's existing cue policy.
The source's exclusive PFL changes on Load are not reproduced.

Core controls include gain, three-band EQ, level, crossfader, Cue Mix, held Cue, Play, Sync, Key Lock and shifted tempo reset.
Three Hot Cues, manual loop boundaries, Reloop, four-beat loop toggle, loop size and track/group browsing retain reviewed addresses.
Feedback uses separate output addresses for Play, Sync, PFL, Key Lock, cue pads and loop state.
Bounded startup selects fixed scratch indicators and clears inactive modifier indicators. Complete dynamic lights and cleanup remain open.

Factory coverage reaches 102 profiles for 106 physical models. Six other models retain automatic native adapters.
The catalogue retains 305 records and 162 data recipes. All 161 other recipes remain unchanged.
Other modes, full feedback, displays, routing, calibration and physical acceptance remain open.
All 13 final targeted Swift checks, 66 importer/report checks and native iPad compilation pass.
The 399-check broader run found four fixture issues. Corrected fixtures pass in the final targeted run.
The broader run and its original test sources remain preserved. No broader all-pass result is claimed.
An offline playback fixture verifies native touch, wheel stop and the saved Sync choice.
The bundled resource matches the source. Source identities and verification results appear in `TestBuilds/r233/validation.json`.
No signed app, installation or A10X acceptance forms part of this increment.

## R232 documented Scratch master/headphone output selection

A connected Scratch audio device now selects master channels 1–2 and headphone channels 3–4 automatically.
The reviewed Mixxx audio setup documents this layout. The existing native renderer already supports the same layout for other reviewed hardware.
The factory record declares that output layout explicitly. Unknown layouts and manually selected profiles cannot enable it.
Matching still requires a known wired model and one unambiguous audio output. Other devices retain the existing output policy.

The Scratch record now distinguishes automatic output selection from unimplemented DVS and passthrough inputs.
NS6II and other models receive no inferred audio-layout flag. Their hardware mixing and connection requirements need their own review.
MIDI bindings, packets, mode guards and feedback remain unchanged for every model.

All 38 targeted Swift checks, 65 importer/report checks and native iPad compilation pass.
The bundled resource matches the source.
Offline sample comparisons cover repeated Scratch and Z1 detection without changing master or cue samples.
Reconnect fixtures preserve transport and Sync and retain the existing speaker-leak guard.
The catalogue retains 305 records and 162 data recipes. Only Scratch output metadata changes.
Source identities and validation results appear in `TestBuilds/r232/validation.json`.
No signed app, installation, physical output test or A10X acceptance forms part of this increment.

## R231 Scratch native core, pulse inputs and safe startup/reconnect

Numark Scratch now selects a native mixer/accessory core automatically. The pinned XML, script, shared component helper and factory guide have recorded hashes.
The recipe retains actual XML mixer and pad channels where constructor properties differ.
Native controls include gain/EQ/filter/faders, headphone cue state, Cue Mix, guarded cue pads and loop/browse controls.

The factory guide confirms loop on/off for the encoder press. This takes precedence over the community enable-only key.
Received headphone on/off reports set native cue state directly. Conflicting PFL output channels remain unmapped.

Loop direction notes are encoder pulses. An explicit pulse flag accepts each positive note without a release edge.
Only absolute, non-momentary note buttons may use that flag. Ordinary buttons retain their existing edge handling.
Physical Shift selects single-step browsing and Load. Sampler and Roll pages cannot trigger cues.
Alternate delete releases only rearm pads. Selector reports reset pickup on their own side without clearing physical Shift.

The shared startup path now prepares bindings and connects input before requesting controller state.
Failed input connection sends no setup packets and leaves no active factory session. A later discovery can retry.
CoreMIDI replies still enter the bounded inbox. The app drains them after startup completes.
The recipe omits the delay that the source comment ties to Mixxx engine initialisation. Physical cold-start timing remains unverified.

Saved custom mappings now retain mode, release, Shift, explicit low-byte and pulse metadata when an endpoint ID changes.
Reconnect fixtures cover Scratch pad guards and pulses, Platinum's CC 9/119 pair and MC7000's physical Shift scopes and stable identities.
These shared fixes also protect earlier reviewed profiles. No downloaded script or source timer runs in the app.

All 384 focused checks pass for the shared runtime changes.
The factory-aligned Scratch PFL/Loop recipe then passes all 46 confirmation checks. No other recipe changes between those runs.
All 64 importer/report checks and native iPad compilation pass.
Native offline playback covers mixer changes, cue state, loop toggling, repeated encoder pulses and persistent Sync.
The bundled resource matches the source.


Factory coverage reaches 101 profiles for 105 physical models. Six other models retain automatic native adapters.
The catalogue retains 305 records and 162 data recipes. Only the existing Scratch recipe changes.
FX, rolls, sampler, complete lights, reverse/curve controls, cleanup, DVS, passthrough and audio routing remain open.
Source identities and validation results appear in `TestBuilds/r231/validation.json`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R230 original RP-8000 MIDI accessory core

The original RP-8000 now selects a native MIDI accessory recipe automatically. MK2 and Straight variants do not inherit it.
The factory manual, Scratch Live archive, Traktor archive and extracted mapping members have recorded hashes.
The manual's MIDI table supplies eight cue inputs. The published mappings confirm loop lengths, encoder encoding and five cue-light pairs.
The native recipe provides eight cues, quarter-beat through 32-beat loops, browsing and Load on four hardware channel targets.
Held mode-button releases rearm their pads. Sample and User messages cannot invoke native cues or loops.

The hardware CH-1–4 selection maps to A/B/C/D. TT Link assigns those channels automatically, as the factory manual describes.
Independently connected turntables on the same channel need distinct hardware channel selections. Automatic endpoint-based deck assignment remains open.
The app's deck availability still guards C/D. Source fixtures cover both note-release forms, presets, feedback addresses and browse-before-Load order.

This increment covers the MIDI accessory section. Optional motor and analogue-control messages remain unmapped.
It adds no platter tracking, motor control or DVS/audio routing. Sample/Slicer/User modes, displays and remaining cue lights remain open.
All 30 targeted Swift checks, 63 importer/report checks and native iPad compilation pass.
Native offline playback covers cues, loop sizing, exit and persistent Sync. The bundled resource matches the source.
The catalogue retains 305 records and now contains 162 data recipes. All 161 previous recipes remain unchanged.
Factory coverage reaches 100 profiles for 104 physical models. Six other models retain automatic native adapters.
Source identities and validation results appear in `TestBuilds/r230/validation.json`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R229 compact Vestax cores and single-step browser buttons

Typhoon and Spin now select separate native core recipes automatically. Their stored IDs and endpoint aliases remain valid.
Both retain transport, held Cue, mixer/EQ, Load, exact-centre seven-bit tempo and 300-count jogs.
The native recipes use fixed touch scratching. Spin lights its Scratch indicator and clears the wheel-disable indicator.
Typhoon accepts both published touch and jog addresses. Its held Filter button guards that deck's jogs without changing the filter.
Spin uses only the touch and jog addresses handled by its pinned script. Unhandled XML aliases remain unmapped.

Typhoon toggles a four-beat loop and retains separate halve/double buttons. Spin uses manual In/Out and Reloop/Exit.
Both use explicit single-step browser actions for track and group buttons. A held or repeated MIDI press cannot jump 63 tracks.
The same actions now connect Dicer's orange-page track and group buttons. Browser movement reaches the existing queue before Load.
No downloaded script, busy wait or source timer runs in the app.

All 62 targeted Swift checks, 62 importer/report checks and native iPad compilation pass.
Tests cover release forms, button order, pickup and model-specific messages. The bundled resource matches the source.
Native offline playback covers held Cue, jog scale, release and persistent Sync on both Vestax models.
Alternative Scratch/filter modes, transport functions, complete lights, cleanup, routing and physical calibration remain open.
The catalogue retains 305 records and 161 data recipes. Only Typhoon, Spin and Dicer change their recipes.
Factory coverage reaches 99 profiles for 103 physical models. Six other models retain automatic native adapters.
Source identities and validation results appear in `TestBuilds/r229/validation.json`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R228 NEON native accessory core

NEON now selects its own accessory recipe automatically. It can provide eight Hot Cues on each of four deck targets.
The factory MIDI table, Reloop guide and Serato guide have recorded hashes and reviewed page images.
Each pad mode has a distinct address range. Sampler, Slicer, stored-loop and Flip messages cannot trigger native cues.
Velocity and aftertouch messages remain separate from pad presses. Shifted delete releases rearm pads without deleting or triggering a cue.

The Manual Loop page provides native loop on/off, boundary capture and Reloop/Exit.
The Serato guide confirms the on/off action for the first pad. It does not use the NS6II enable-only action.
Native In/Out capture replaces the active-loop boundary-edit mode. Encoder editing remains open.
Deck reports rearm the shared physical pad surface. Hardware C/D setup does not enable the app's four-deck trial.

The factory C/D Sync rows conflict with Slip. Sync remains unmapped pending a resolved source.
Common encoder and Load messages also occur in Sampler mode. Their context needs a separate mode guard before activation.
Stored loops, rolls, sampler, Slicer, Flip, DVS switching, pressure, pad colours and full cleanup remain open.
NEON has no built-in audio interface. It uses the app's existing audio configuration.

All 28 targeted Swift checks, 61 importer/report checks and native iPad compilation pass.
Native offline playback covers cue pads, loop toggling, Reloop and persistent Sync. The bundled resource matches the source.
Factory coverage reaches 97 profiles for 101 physical models. Six other models retain automatic native adapters.
The catalogue retains 305 records and now contains 161 data recipes. All 160 previous recipes remain unchanged.
Source identities and validation results appear in `TestBuilds/r228/validation.json`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R227 N4 native core and explicit state controls

The existing N4 recipe now selects automatically, including its original `N4 MIDI 1` endpoint alias.
The reviewed XML and script have recorded hashes. Actual XML dispatch wins over conflicting constructor properties.
Four targets retain 600-count jogs, paired tempo, mixer/EQ, Load, four cues and the source's custom loop-button layout.
The mixer address sequence has a gap between B and C. Independent fixtures check all four gain and level addresses.

Native momentary Shift replaces the source's software latch. Stable physical-side identities survive A/C and B/D bank changes.
Both Shift controls also guard the shared browser. Unsupported shifted functions cannot invoke normal actions.

N4 headphone cue notes carry latched state. A typed state action applies both on and off reports without toggle edges or pickup.
The app does not echo those PFL lights because the hardware echoes feedback into its inputs.
Control Change bank reports release old contacts and reset pickup on their own side for every reported selector value.
Existing note-based bank reports retain their explicit positive-value and optional USB release rules.
Only an explicit Control Change bank definition may omit its value filter.

A separate enable-loop action creates the selected loop without disabling an active loop on repeated presses.
NS6II's Loop-page third pad now uses that action. Its alternate shifted release only rearms the pad.
Other pad modes remain guarded. The previous bank receiver fails the new N4 held-contact fixture.
The 349 focused checks pass across the full run and corrected Cue-inventory fixture.
The full run passed 348 checks. Its only failure was the stale inventory count, corrected from 91 to 92.
All nine N4 and Cue-inventory confirmation checks pass. All 60 importer/report checks and native iPad compilation pass.
The bundled resource matches the source.
Native offline playback covers Cue return, bank releases, jog scale, latched PFL, repeated loop activation and persistent Sync.

The source's unit-specific EQ calibration, extra cue pages, FX, remaining modes, full feedback and cleanup remain open.
Hardware headphone and master controls retain their own audio path. Automatic routing and physical calibration remain open.

Factory coverage reaches 96 profiles for 100 physical models. Six other models retain automatic native adapters.
The catalogue retains 305 records and 160 data recipes. Only N4 and the explicit NS6II loop addition change their recipes.
Source identities and validation results appear in `TestBuilds/r227/validation.json`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R226 current AlphaTheta inventory additions

The manufacturer catalogue confirms three further models: DJM-A7, XDJ-AN and RMX-IGNITE.
Each has its own source-linked record. Product existence alone does not enable a runtime mapping.
CDJ-1500X already has a reviewed automatic MIDI core recipe and does not need another record.
The catalogue now contains 305 records for 298 physical models. The wider manufacturer audit remains open.
All 160 runtime recipes remain unchanged. All 59 importer/report checks pass.
Source identities and validation results appear in `TestBuilds/r226/validation.json`.
This inventory change adds no controller hardware or A10X acceptance claim.

## R225 NS6II native core and USB handover release

NS6II now has an automatic four-target recipe from the pinned XML, component helpers and script facts.
The recipe keeps actual XML dispatch addresses where constructor properties differ.
Native controls include transport, held Cue, mixer/EQ/filter, Load, paired tempo, eight cues and guarded loop pages.
The jog path retains the published 1,000-count scale. C/D retain the app's existing opt-in.

Physical Shift controls the corresponding deck side. Both Shift buttons also guard shared Load and browser alternatives.
Bank reports preserve held Shift while releasing old contacts and resetting pickup on that side.
Explicit USB selector reports also act on their own side. A loss report releases Cue and scratch contacts and clears that side's Shift inputs.
A held modifier on the other side remains active. Ordinary bank-release packets keep their previous behaviour.
Only profiles with explicit release metadata accept those loss reports.

The shared pad addresses require a selected native page. Cue pages expose eight cues, with alternate delete releases that only rearm the pads.
The Auto page provides fixed loops from one to 32 beats. The Loop page provides core loop and jump controls.
Unsupported sample, key, grid and alternate pages cannot trigger cues or loop pads.
Pad lights remain unmapped because their shared addresses require mode-aware output handling.
The recipe sends the published state query and lights the native Scratch and Cue-page indicators.

The source's software page cycling, roll variants, 64/128-beat loops, FX, screens and full cleanup remain open.
Hardware headphone mixing retains its own controls. Complete headphone/audio routing and physical calibration remain open.
The previous receiver fails the USB loss fixture. The fixed receiver passes all 340 focused controller checks.
All 59 importer/report checks and native iPad compilation pass. The bundled resource matches the source.
Factory coverage reaches 95 profiles for 99 physical models. Six other models retain automatic native adapters.
The catalogue retains 302 records and now contains 160 data recipes. All 159 earlier recipes remain unchanged.
No downloaded script runs in the app. Source identities and validation results appear in `TestBuilds/r225/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R224 Dicer native accessory core

The existing Dicer recipe now selects automatically as an accessory. Its stored ID and original endpoint aliases remain valid.
The pinned XML and script have recorded hashes. No downloaded script runs in the app.
The recipe maps five Hot Cues, shifted fixed loops, orange-page held Cue and Load on each Dicer.
Normal and delete-page lights retain the source addresses and values. Alternate delete releases rearm normal pads without deleting a cue.
Startup and shutdown use the source reset packet.

The old roll script warns of loop erasure, timing drift and a brief audio pause.
Those roll functions, transformer timers, gain changes and rewind effects do not enter the native recipe.
Default green-page rolls, browser step buttons, extra effects and complete feedback remain open.
A native playback fixture covers held Cue, release-to-return and saved Sync.

All 24 targeted controller checks, 58 importer/report checks and native iPad compilation pass.
The catalogue retains 302 records and 159 data recipes. Factory coverage reaches 94 profiles for 98 physical models.
Six other models retain automatic native adapters. All 158 other recipes remain unchanged.
Validation results and source identity appear in `TestBuilds/r224/validation.json`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R223 Mixon 4 native core controls

Mixon 4 now has its own automatic four-target recipe from the factory MIDI table and published Traktor mapping.
The factory documents and mapping archive have recorded hashes. The extracted TSI member has its own hash.
A reviewed external TSI reader confirms the normal jog/touch addresses and four unflipped absolute pitch inputs.
That reader stays in the evidence cache. It is not an app dependency or a runtime script.

Deck and mixer controls use channels 4–7. Hot Cue pages use 0–3. Global controls use channel 10.
The recipe maps held Cue, Play, Sync, Keylock, Load, PFL, mixer/EQ/filter, native pitch, loops, browsing and eight Hot Cues.
Other pad pages cannot trigger those cues. Shift releases rearm pads and normal buttons without firing unsupported alternatives.
The RGB table supplies full blue value 3 and dim blue value 67. Master and booth remain physical hardware controls.

Factory bank reports release contacts and rearm pickup only on their physical side. Global Shift survives those reports.
Shift guards unsupported alternatives and rearms affected pitch pickup. Normal contact releases can finish while Shift is active.
The documented initial-state query leaves deck restrictions and firmware settings unchanged. C/D retain the app's existing opt-in.
The recipe does not infer Mixon 8 Pro compatibility. Jog sensitivity uses the native default pending calibration.
FX, other pad modes, macro controls, assignments, complete feedback, cleanup, routing and physical direction/calibration remain open.

The first protocol run rejected an invalid loop-encoder encoding through the existing catalogue validator.
The recipe now uses the native single-step decoder for the factory's 65/63 loop encoder.
All 25 targeted controller checks, 57 importer/report checks and native iPad compilation pass.
The catalogue retains 302 records and now contains 159 data recipes. Factory coverage reaches 93 profiles for 97 physical models.
Six other models retain automatic native adapters. All 158 previous recipes remain unchanged.
Validation results and source identity appear in `TestBuilds/r223/validation.json`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R222 MC2000 factory core controls

MC2000 now has an automatic two-deck core recipe from the manufacturer's MIDI table and channel-range diagram.
The recipe maps transport, held Cue, Load, PFL, mixer/EQ, native 14-bit pitch, browsing, preset loops and four Hot Cues.
The community mapping revision and factory manual have recorded hashes. No downloaded script runs in the app.

Factory facts resolve several community conflicts. The right gain uses channel 1 CC 12, and jog touch uses Note 81.
The factory's hexadecimal master and Play LED addresses take precedence over its inconsistent decimal columns.
Feedback uses separate on/off trigger controllers. PFL retains its separate trigger family and channel-specific identifier.
Startup lights the Vinyl indicator and requests current control values on both channels. Shutdown clears that indicator.

Global Shift guards unsupported transport, pad and jog alternatives. Mixer controls remain independent.
Factory touch reports for Vinyl Off and jog lock can release an existing contact without starting a scratch.
Separate sample notes cannot trigger Hot Cues. Native 14-bit pitch retains exact centre and pickup protection.
Jog direction follows the factory table. Sensitivity uses the native default instead of the source's arbitrary 125-count tuning.
The source's gain-as-filter, Shift lock, crossfader Sync, forced PFL and startup mixer-level resets remain unmapped.
Manual loop boundaries, extra modes, full feedback, cleanup, routing and physical calibration remain open.

The catalogue retains 302 records and now contains 158 data recipes. Factory coverage reaches 92 profiles for 96 physical models.
Six other models retain automatic native adapters. All 157 previous recipes remain unchanged.
All 25 targeted controller checks, 56 importer/report checks and native iPad compilation pass.
Validation results and source identity appear in `TestBuilds/r222/validation.json`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R221 Beatmix 2/4 factory core and bank protection

The existing Beatmix 2/4 MK2 recipe now selects automatically for both original and MK2 models.
Reloop publishes the same family MIDI table on its MK2 product page. The stored recipe ID remains unchanged.
The catalogue links all four physical models to this reviewed definition.

The recipe maps four deck targets, held Cue, Load, mixer/EQ, pitch, browsing and the pinned mapping's four-cue/four-loop pad layout.
C/D retain the app's existing opt-in. Sample pages cannot trigger cues or loop pads.
Bank reports release old contacts and reset pickup only on that physical side. Held Shift keeps its physical-side identity.
Centred pitch now uses the existing pickup guard. Shift release rearms affected controls.
Release-only aliases allow normal pads and buttons to respond after a shifted release without firing unsupported alternatives.

The factory table specifies signed 1/127 jog counts and 800 counts per revolution.
Those facts take precedence over the pinned script's conflicting value-minus-64 handler.
The recipe also uses the factory's distinct Play and Sync LED addresses. Hot Cue lights use the documented blue value.
No downloaded script runs in the app. The source's long-press eject, fader-start and software FX modes remain unmapped.
The optional delayed state query and complete LED cleanup remain open. No immediate substitute query is sent.
Remaining modes, audio routing and physical calibration remain open.

Factory coverage reaches 91 profiles for 95 physical models. Six other models retain automatic native adapters.
The catalogue retains 302 records and 157 data recipes. All 156 other recipes remain unchanged.
All 314 focused controller checks, 55 importer/report checks and native iPad compilation pass.
Validation results and source identity appear in `TestBuilds/r221/validation.json`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R220 Inpulse 200 MK2 core controls and shifted pad releases

Inpulse 200 MK2 now has its own automatic two-deck recipe from a published iOS mapping and separate controller definitions.
The source files and manufacturer guide have recorded hashes. Downloaded scripts never run in the app.
The recipe maps transport, held Cue, Load, two-band EQ, filter, seven-bit tempo, browsing and four Hot Cues per deck.
It retains the physical gain knob. The second author's custom three-band EQ and software banks stay unmapped.

Per-deck Shift guards normal buttons, jogs, pads and tempo. Mixer controls remain independent.
The manufacturer describes Shift+tempo as a physical reposition without a software tempo change. Pickup rearms after Shift release.
Centred seven-bit controls now use the existing pickup guard. The centre value remains exactly neutral.
Normal Cue and touch releases can finish held contacts while Shift is active.

The delete pad page uses separate notes. Its positive messages remain unmapped because native cue deletion is outside this increment.
Release-only aliases clear stale normal-pad edge state without firing or deleting a cue.
Fixtures cover duplicate presses, both note-release forms and either Shift-release order.
Other pad pages, Assistant and the source's custom Automix action cannot trigger the mapped cues or transport.

Jog direction follows the published 1/127 definition. Sensitivity uses the native default until a controller-specific scale is established.
The recipe does not borrow the 300 MK2's 248-count scale, high-resolution tempo pair or startup exchange.
Manual loop boundaries, shifted seeking, full feedback, cleanup, audio routing and physical calibration remain open.

The catalogue retains 302 records and now contains 157 data recipes. Factory coverage reaches 90 profiles for 91 physical models.
Six other models retain automatic native adapters. All 156 previous data recipes remain unchanged.
Validation results and source identity appear in `TestBuilds/r220/validation.json`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R219 Inpulse 300 MK2 core and Shift contact continuity

Inpulse 300 MK2 now has its own automatic two-deck core recipe. It does not inherit the original 300 profile.
The source mapping revision, XML, script and manufacturer guide have recorded hashes.
Only reviewed hardware-address facts and count scales enter the runtime recipe. No downloaded script runs in the app.

Normal deck messages use channels 1/2. Hardware shifted messages use 4/5.
The recipe maps transport, held Cue, Load, PFL, mixer/EQ/filter, paired tempo, browsing and native preset-loop controls.
The native recipe omits the fork's Assistant-controlled software banks and stem/FX code.
The guide's manual IN/OUT and active-loop adjustment do not match the fork's IN-to-four-beat customisation. Those buttons remain unmapped.

The source assigns pad address zero on channel 6 to three unrelated actions. All pads remain unmapped until those facts are resolved.
This avoids a Hot Cue press also changing an effect or jumping the track.

The source's scratch resolution is 248 counts. Shift increases movement fourfold, represented by 62 native counts per revolution.
A reproduction found that changing resolution could replace the intended frame with an extrapolated playback frame.
The held motion ledger now keeps its original frame basis and scales incoming counts to that basis.
Normal and shifted movement remain continuous. Idle stop and Sync restoration retain their existing rules.

A second reproduction found that an alternate Cue release could suppress the next normal press.
Momentary contacts now use the existing active-source set for edge detection instead of stale per-address byte values.
Duplicate presses and orphan releases still cannot create extra contacts. A fresh press works after an alternate-address release.

The catalogue retains 302 records and now contains 156 data recipes. Factory coverage rises to 89 profiles for 90 physical models.
Six other models retain automatic native adapters. Full pads, boundary adjustment, extra modes, feedback, cleanup, routing and calibration remain open.
All 301 focused controller/NI checks, 53 importer/report checks and native iPad compilation pass.
Both failing reproductions remain in the evidence directory. All 155 earlier data recipes remain unchanged.
The compiled resource matches the source. Twelve historical broken links remain.
Source base: `ab207c2`. Evidence: `TestBuilds/r219/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R218 Jogvision factory setup and native core controls

Jogvision now selects an automatic core recipe on its default MIDI channels.
The recipe combines the hashed factory command list with the pinned XML and script facts.
It retains both existing aliases and the stored profile ID.

The recipe maps transport, held Cue, Load, mixer faders/EQ, paired tempo, browsing, loops and eight Hot Cues per deck.
The manufacturer uses distinct note ranges for cue pages, samples and shifted delete pages. Unsupported pages cannot trigger cues.
Shift and Mode jointly guard unsupported alternatives on each deck. Their releases remain independent.
A shifted Cue release can finish a normal held Cue. It cannot start an audition.

The native jog path retains the source-derived 400-count resolution. Platter and rim addresses remain separate.
The loop encoder uses native loop sizing. Modifier alternatives cannot trigger normal loop controls.
The source's Shift+Browse gain customisation remains unmapped. It is not a dedicated physical gain knob.

Startup sets Scratch mode, lights its indicator and requests current analogue and keypad-mode reports.
Factory CC 127 requests those reports. The source comment that calls it an LED clear is not followed.
Shutdown restores jog mode and clears the Scratch indicator. It never copies the source's track-eject side effect.

Native playback fixtures cover shifted Cue release, count movement, idle stop and Sync preservation.
The first protocol run found only an invalid test assumption about independent pending-control order. The fixture now compares deck-targeted results.
The catalogue retains 302 records and 155 data recipes. One partial recipe becomes an automatic core recipe.
Factory coverage rises to 88 profiles for 89 physical models. Six other models retain existing native adapters.
AIR filter, remaining modes, rings, full feedback, cleanup, routing and physical jog calibration remain open.

All 296 focused controller/NI checks, 52 importer/report checks and native iPad compilation pass.
The compiled resource matches the source. All 154 other data recipes remain unchanged.
Twelve historical broken links remain. Source base: `6a395a3`. Evidence: `TestBuilds/r218/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R217 manufacturer inventory omissions and completion scope

The catalogue now includes thirteen manufacturer-confirmed models omitted by the pinned software inventories.
They are RANE PERFORMER and FOUR, Reloop Buddy, Mixtour Pro, Mixtour and Beatpad 2, plus seven Denon systems and players.
Denon additions cover PRIME 2, PRIME GO/GO+, SC5000/SC5000M PRIME and SC6000/SC6000M PRIME.
Each record links to its reviewed manufacturer source. None inherits another model's mapping or gains an automatic-support claim.

There are now 302 records for 295 physical models. Factory MIDI core coverage remains 88 physical models through 87 profiles.
Six other models retain existing automatic native adapters. The 155 runtime data recipes remain unchanged.
The Serato source comparison remains 44 of 122 model records with automatic core controls.

The source-inventory completion flag retains its bounded meaning. A separate manufacturer-audit flag remains false.
The report now states that the wider market inventory and feature parity remain open.
The generator checks the new entries and their incomplete implementation state during regeneration.

All 51 importer/report checks pass. Runtime code and resource bytes remain unchanged, so no Swift rebuild forms part of this increment.
Pioneer SR2 initial Load-bank routing remains unresolved. Both attempted REV7 factory-table downloads returned missing-file responses.
Twelve historical broken links remain. Source base: `ab7eba2`. Evidence: `TestBuilds/r217/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R216 waveform touch takeover from a held MIDI jog

A native reproduction found that the old jog idle task could overwrite a later waveform touch.
The old physical release could also end that waveform contact.

A successful direct touch command now retires MIDI jog ownership on that deck.
It cancels the count-motion idle task and clears its saved motion. A stale controller release cannot end the new touch.
Synchronous hardware touch commands retain their ownership. A failed or blocked touch command cannot take ownership.
The controller can start a new contact after a fresh platter press.

This change uses the existing public touch contract and runs outside the audio callback.
It adds no timer, mode, mapping address or UI control. Other decks retain their ownership.
All catalogue recipes, setup packets, feedback and aliases remain unchanged.

All 291 focused controller/NI checks, 51 importer/report checks and native iPad compilation pass.
The original reproduction failed five assertions. Fresh-contact, blocked-command and independent-deck fixtures also pass.
All 155 data recipes remain unchanged. The compiled resource matches the source. Twelve historical broken links remain.
Source base: `105b4fd`. Evidence: `TestBuilds/r216/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R215 original DDJ-1000 normal controls and four-deck core

The original DDJ-1000 now uses a recipe from its own hashed MIDI list and control-function diagram.
The SRT retains a separate recipe. The existing profile ID, aliases and saved custom mappings remain stable.

The earlier code used shifted addresses for normal Sync, tempo and the four-beat loop button.
Normal Sync now uses Note 88. Normal tempo uses CC 0/32. The four-beat loop button uses Note 20.
The shifted tempo pair remains CC 5/37. Shifted master and tempo-range buttons cannot trigger unrelated normal actions.

Four transport channels target A/B/C/D. The recipe adds keylock, Load, browsing and C/D Hot Cues.
Loop In/Out set boundaries without an active loop. They halve/double the actual active span during a loop.
The four-beat button uses the native fixed-loop toggle. Four decks retain the app opt-in.

Unlike FLX10, the original 1000 reports either left-bank change as Note 114 on channel 2.
Channel 3 reports either right-bank change. Those switch events protect the corresponding physical side.
The recipe does not infer a cold active-deck state. Stable Shift identities survive a bank change and clear on release.

Vinyl On uses platter CC 34. Wheel CC 33 and Vinyl Off CC 35 use pitch bend.
Shifted CC 31/38 edit the grid and remain unmapped. A shifted touch release can end an existing contact.
Core light feedback now includes all four decks, normal Sync and keylock.
Screens, remaining pad modes, FX, grid editing, full feedback, cleanup, routing and jog calibration remain open.

The catalogue retains 289 records and now contains 155 data recipes plus five code profiles.
The 87 factory profiles cover 88 physical models. Six other models retain automatic controls through existing native adapters.
All 287 focused controller/NI checks, 51 importer/report checks and native iPad compilation pass.
Native playback confirms normal Sync, keylock, positive tempo direction and the four-beat loop.
All 154 earlier data recipes remain unchanged. The compiled resource matches the source.
The REV5 feedback helper matches the source base after correction of an intermediate migration error.
Failed reproductions and intermediate failures remain in the evidence directory. Twelve historical broken links remain.
Source base: `59985a7`. Evidence: `TestBuilds/r215/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R214 FLX10 four-deck core and published control functions

FLX10 now uses a data recipe from the hashed factory MIDI list and the official control-function diagram.
Its existing profile ID, exact aliases and saved custom mappings remain stable. There is one factory entry for this model.

Transport channels 0/1/2/3 target A/B/C/D. Normal Hot Cue channels are 7/9/11/13.
The recipe adds C/D, Load and browsing. Four decks retain the existing app opt-in.
Active bank reports release held contacts and rearm pickup only on that physical side.
Stable physical Shift identities work across the A/C and B/D banks.

The native loop buttons set In/Out when no loop is active. They halve/double the actual active loop span.
The four-beat button toggles a four-beat loop. Beat Jump moves four beats, or sixteen with Shift, independently of the selected loop size.
Tempo retains normal and shifted fourteen-bit pairs. Mixer controls remain independent of deck Shift.

Shifted jog messages edit the beat grid on the original software. They cannot scratch or bend in the native recipe.
A shifted touch release can end an existing contact. Shifted presses cannot start one. Vinyl Off motion uses the wheel-bend action.
Unimplemented shifted loop-adjustment gestures remain unmapped.

The recipe retains the published core light messages and adds corresponding C/D lights.
Full pad modes, stem controls, grid editing, screens, remaining feedback, lifecycle cleanup and audio routing remain open.
The manufacturer table gives relative counts without a revolution scale. Physical jog calibration remains open.

The catalogue still contains 289 records. It now contains 154 data recipes and six code profiles.
The 87 factory profiles cover 88 physical models. Six other models have automatic controls through existing native adapters.
The combined automatic-control total is 94 models. Earlier counts of 93/94 included those six native routes.
This corrects the earlier factory-coverage wording. FLX10 gains functions without adding a new supported model.
All 280 focused controller/NI checks, 50 importer/report checks and native iPad compilation pass.
The compiled resource matches the source. All 153 earlier data recipes remain unchanged.
Two failing reproductions and intermediate test failures remain in the evidence directory.
Twelve historical broken links remain. Source base: `ef67a80`. Evidence: `TestBuilds/r214/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R213 paused count jogs with persistent Sync

A reproduction found that individual small jog packets could round back to the same grid position indefinitely.
Paused relative jogs now retain the requested position between packets. The native transport still aligns each seek to the beat grid.
The saved Sync choice remains unchanged. No extra touch contact or background task is required.

The requested position stays within the track bounds, so reversal works after movement reaches the start or end.
Other performance actions, Play, explicit Sync changes, absolute jogs and touch takeover clear the fractional position.
A changed track generation or jog resolution starts from the current playhead.

Focused fixtures cover repeated small packets, reversal, track bounds, external jumps, touch takeover, Play, replacement tracks and resolution changes.
The Sync-off fixture retains fine movement. This shared correction applies across count-based factory jogs.
Catalogue recipes, addresses, aliases, setup packets and feedback remain unchanged.

All 270 focused controller/NI checks, 48 importer checks and native iPad compilation pass.
The compiled profile resource remains unchanged and matches the source. Twelve historical link failures remain.
Source base: `5de5edc`. Evidence: `TestBuilds/r213/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R212 Mixstream Pro core controls and jog counter

The original Mixstream Pro now selects its native core recipe after Computer Mode selection.
The manufacturer guide confirms that this mode sends and receives MIDI. Its PDF hash and page remain in the source record.
Pro+ and Go retain separate model boundaries. The family guide does not prove matching MIDI bytes for those models.

Transport and jog controls use channels 2/3. Mixer controls use 0/1. Global controls use channel 15.
The recipe maps Play, held Cue, Sync, Load, headphone cue, EQ, gain, filter, level and browsing.
Tempo retains its explicit CC 31/75 pair and native direction.

The source LED animation adds no required handshake, so the native profile skips it.
Six core light bindings retain the bright/dim values. Shutdown clears those lights.

Jog CC 55/77 reports an absolute counter. The decoder primes its reference before emitting movement.
It retains the source high-byte boundary rule, ignores duplicates and rebases after jumps above 45 counts.

The script scale implies 10 milliseconds per count. The native movement contract represents this as 180 counts per 1.8-second revolution.
This scale is a source-derived calculation. Physical calibration remains open.
A native playback fixture confirms 20 milliseconds of movement from two counts and an idle stop while held.

The structured counter requires an explicit low-byte address. Partial MIDI learning cannot create an incomplete mapping.
The name matcher now preserves the distinguishing plus character.
Explicit excluded aliases prevent Pro+ or Go from matching through a generic original-Pro port name.
The schema bounds those names. Shared positive aliases still fail closed when they identify more than one profile.

All 266 focused controller/NI checks, 48 importer checks and native iPad compilation pass.
The compiled resource matches the source. Only the existing Mixstream Pro data recipe changes.
The other 152 recipes remain unchanged. Counts remain 289 catalogue records.

Eighty-seven factory profiles now select core controls automatically, covering 94 physical models.
Pads, scratch mode selection, backspin, full feedback, screen, auxiliary inputs and audio routing remain open.

Twelve historical broken links remain. Source base: `078a637`. Evidence: `TestBuilds/r212/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R211 MC7000 bank pickup and held Shift

MC7000 now uses the existing bank protection for its published active Note 8 reports.
Left reports protect decks A/C. Right reports protect decks B/D.
A bank change releases old contacts and rearms pickup on that side. The other side retains its state.

The two physical Shift buttons now have stable identities across their virtual deck channels.
A held modifier follows the selected bank. Release on the new bank clears it before the player returns to the old bank.
The pinned source explicitly transfers this state because the hardware switches channels immediately.
The native mapping uses the existing shared button contract instead of copying script state.
Saved custom mappings retain their stored fields.

Two reproductions failed before the change. The native fixtures now cover held Shift, shifted manual loops, bank return and side-specific pickup.
All 255 focused controller/NI checks and 47 importer checks pass. Native iPad compilation also passes.
The compiled resource matches the source. Only the existing MC7000 data recipe changes.

The other 152 recipes, MIDI addresses, tempo pair, jog decoder, setup packets and feedback remain unchanged.
Counts remain 289 catalogue records, 86 automatic core profiles and 93 physical models with automatic controls.

Jog calibration, pad modes, full feedback, lifecycle details and audio routing remain open.
Twelve historical broken links remain. Source base: `e55377e`. Evidence: `TestBuilds/r211/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R210 NS4FX core controls and bank pickup protection

NS4FX now selects its native core recipe automatically. Its existing profile ID and exact model alias remain stable.
Four published MIDI channels target decks A/B/C/D. The app retains its existing four deck opt-in.

The source supplies transport, held Cue, Load, headphone cue, mixer controls, browsing and the 1240-count jog resolution.
The jog decoder reuses the reviewed Numark wrap logic. Tempo uses the labelled CC 9/41 pair and native direction.
The native recipe corrects source gain-group labels and the high-byte input/inputMSB routing error in the script.

Active bank reports rearm pickup and clear incomplete input pairs only on that side.
They finish held Cue and platter contacts on that side before the next bank receives movement.
Queued controls finish before the bank change. The other side retains its Cue, pickup state and decoder state.

Learned tempo mappings retain this protection. Unrelated notes and bank release packets cannot reset a side.
Bank metadata has bounded addresses and deck scopes. Player profiles cannot use this controller-bank contract.

Logical Shift changes rearm pickup only for affected controls. Independent mixer controls keep their state.
Unsupported shifted Load, rate range, search and headphone alternatives cannot change normal controls.
An unpaired touch release now needs an active controller contact before it can release touch.
This prevents a stale or initial hardware release from ending a waveform gesture.
The native checks preserve Cue on the second deck and a newer waveform touch after a bank switch.

Startup exits demo mode and enables Vinyl. Shutdown dims the four Vinyl lights within the setup bound.
Twelve core light bindings retain the published bright/dim values. Full light cleanup remains open.

Pads, pitch/key buttons, Vinyl toggle, screens, FX, other modes and audio routing also remain open.
The app does not copy sampler allocation, FX initialisation or automatic four deck activation from the script.
Physical response, calibration and A10X performance require acceptance on hardware.

Five failing reproductions remain in the evidence directory. All 253 focused controller/NI checks and 46 importer checks now pass.
Native iPad compilation passes, and the compiled resource matches the source.
Only the existing NS4FX recipe changes. The other 152 data recipes remain unchanged.

Counts remain 289 catalogue records. Eighty-six factory profiles now select core controls automatically, covering 93 physical models.
The release blocker remains open. Full theoretical mappings and physical acceptance remain separate gates.

Twelve historical broken links remain. Source base: `33c721f`. Evidence: `TestBuilds/r210/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R209 standard Cue preview across the factory catalogue

The remaining reviewed Denon, Numark, Hercules and Reloop note-based Cue bindings now use native held preview.
The XML importer also translates standard, non-inverted `cue_default` note bindings to this action.
Control Change and inverted bindings retain Cue return/set. The importer does not assume that these controls emit a release.
Hercules DJ Console Mac Edition retains its two Control Change Cue bindings until we verify their release behaviour.
The three Pioneer pad accessories have no transport Cue button.

The automatic-profile fixture now exercises both standard note-release forms across 81 factory profiles.
It covers normal controls on every available deck and preserves exact targets and message addresses.
Existing native checks cover preview audio, Play latch, return, disconnect, cross-deck playback, generation changes and gesture takeover.
Saved custom actions retain their meaning. Native NI and Beatpad connection routes remain separate.

All 240 focused controller/NI contract checks, 45 importer checks and native iPad compilation pass.
The compiled resource matches the source. Fifty-five data recipes change only their standard Cue input action.
The other 98 recipes remain unchanged. Setup, feedback, addresses, profile identities and source references remain unchanged.
Counts remain 289 catalogue records, 85 automatic core profiles and 92 physical models with automatic controls.

This completes the standard note-based factory Cue migration. It does not close full controller feature parity or the release blocker.
The remaining hardware modes, lifecycle gaps, screens, motor protocols, feedback and audio routing stay recorded in the catalogue.

Twelve historical broken links remain. Source base: `5f2f2a4`. Evidence: `TestBuilds/r209/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R208 conventional Cue preview across reviewed Pioneer profiles

The reviewed Pioneer/AlphaTheta controller, all-in-one and player recipes now use native held Cue preview.
This includes the seven code profiles and 50 automatic data profiles with a Cue control.
The three pad accessories have no Cue transport button. XDJ-RX retains its existing manual-selection boundary.
The original note addresses, channels, setup messages, feedback and profile identities remain unchanged.
Saved custom mappings retain their existing Cue return/set action.

All 57 automatic profiles accept Note Off and zero-velocity Note On releases.
The player assignment check releases the old deck before assigning a CDJ Cue button to deck C.
A FLX4 offline check produces Cue preview audio and returns to pause while preserving Sync.
The factory DDJ-T1 table explicitly states OFF=0 and ON=127. The other reviewed recipes use the same release-capable note contract.
These are protocol and offline checks, not physical tests of the listed hardware.

All 239 focused controller/NI contract checks, 44 importer checks and native iPad compilation pass.
The compiled resource matches the source. Fifty-one data recipes change only their Cue input action.
The other 102 data recipes remain unchanged. No hardware mode, startup packet, feedback binding or source reference changes.
Counts remain 289 catalogue records, 85 automatic core profiles and 92 physical models with automatic controls.
Other manufacturers still require a Cue migration review. Full mappings, remaining protocols, audio routing and physical acceptance remain release work.
Twelve historical broken links remain. Source base: `4cb14af`. Evidence: `TestBuilds/r208/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R207 native Cue preview and gesture ownership

DJ2GO2 Touch, Total Control and Omni Control now use a momentary Cue preview action.
A paused deck plays while Cue is held. Release returns to its Cue point without changing the saved Sync choice.
Play while Cue is held keeps playback running. Cue on a playing deck stops at its saved Cue point.
The native path reuses the existing NI playback contact contract and generation checks.
The existing Cue return/set action and saved custom mappings retain their meaning.

Disconnect releases a held preview. An old release cannot change a replacement track.
Platter and waveform takeover clear the Cue contact, so a later Cue release cannot end the newer touch.
Cue ignores an existing waveform touch. Preview on deck B remains available while deck A plays.
An existing NI Cue guard incorrectly rejected all actions whenever either primary deck played.
That guard now permits the shared NI Cue action during playback. Track-preparation and editing guards remain.
The NI source change compiles for iPad. Physical NI acceptance remains open.

Two offline reproductions failed before the change. Native preview now produces PCM audio while held.
The controller checks cover return, Play latch, disconnect, playing Cue, cross-deck preview, takeover and stale-generation release.
All 236 focused controller/NI contract checks and 44 importer checks pass. Two waveform checks cover the shared touch entry point.
Native iPad compilation passes, and the compiled resource matches the source.
Only the three reviewed Numark data recipes change. The other 150 recipes remain unchanged.
Counts remain 289 catalogue records, 85 automatic core profiles and 92 physical models with automatic controls.
Twelve historical broken links remain. Earlier failed and diagnostic runs remain in the evidence directory.
Source base: `e78a5c7`. Evidence: `TestBuilds/r207/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R206 DJ2GO2 Touch core controls and pads

DJ2GO2 Touch now has an automatic native recipe under its existing ID. The non-Touch DJ2GO2 remains separate.
Pinned XML, script and component helpers supply transport, Load, touch, MIDI addresses, tempo direction and setup.
The jog decoder retains the source's positive raw-64 boundary and 236-count sensitivity.
The browser accepts only 1/127 steps. Other values do not move the selection.
Manufacturer control labels set the Gain knobs to native Gain and Browse press to folder entry.
These replace the source's filter and preview customisations. The hardware has no channel level faders.

Each deck has four Hot Cues, four 1/2/4/8-beat toggle loop pads, manual In/Out and reloop.
Their published note ranges remain separate. Cue-delete and sampler notes cannot activate other pad functions.
Cue hold-preview, cue deletion, reloop-and-stop, samplers, preview mode, full feedback and audio routing remain open.
The existing native Cue action retains its current behaviour.
Startup sends the published status query. Shutdown clears 14 implemented lights within the existing setup bound.

The official guide's indexed Features text supports the control labels. Direct original and newer guide downloads returned 404.
Its source record has a null PDF hash and states that evidence limit. MIDI sources retain their pinned hashes.
The catalogue remains 289 records and 153 data recipes plus seven code profiles.
Eighty-five factory profiles now select core controls automatically, covering 92 physical models.
All 227 focused Swift checks, 44 importer checks and native iPad compilation passed. The compiled resource matches the source.
Only the existing Touch recipe changes. The other 152 recipes remain unchanged. Twelve historical broken links remain.
Source base: `5c4c34c`. Evidence: `TestBuilds/r206/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R205 Hercules DJControl MIX core controls

DJControl MIX now selects its existing core recipe automatically. MIX ULTRA retains a separate model boundary.
Pinned script facts add normal and shifted touch/jog controls, rim bending and application setup.
The native mapping retains the published 248-count sensitivity. Shifted motion uses 62 counts for the source's fourfold seek multiplier.
The source XML labels both shifted jog rows as Channel1. The script routes channels 4/5 to decks A/B.
The native binding follows that explicit script routing. Unsupported channels cannot acquire a deck override.

Startup lights Vinyl and requests the current control values. Shutdown uses the source's all-LED-off message.
Reconnect repeats startup once. Core transport, four Hot Cues, faders and the 22 existing feedback bindings retain their addresses.
Vinyl remains enabled. Its toggle, cue/master modes, pad loops, samplers, FX, full feedback and audio routing remain open.
Bluetooth pairing, physical response and A10X performance require acceptance on hardware.
The app does not copy the source's unrelated sampler allocation or FX parameter changes.

The catalogue remains 289 records and 153 data recipes plus seven code profiles.
Eighty-four factory profiles now select core controls automatically, covering 91 physical models.
All 222 focused Swift checks, 43 importer checks and native iPad compilation passed. The compiled resource matches the source.
Only the existing MIX recipe changes. The other 152 recipes remain unchanged. Twelve historical broken links remain.
Source base: `6acc64a`. Evidence: `TestBuilds/r205/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R204 Total Control and Omni Control core mappings

Both Numark models now select their existing core recipes automatically.
The pinned XML supplies Play, Sync, Keylock, Load, headphone cue, mixer and seven-bit tempo controls.
The reviewed scripts supply normal-mode signed jog counts and track browsing.
Total Control uses left/right CC 25/24. Omni Control uses 24/25. Their mappings remain separate.
The script's 128-count scratch reference supplies the relative sensitivity. Physical calibration remains open.
Browser handlers require a Library or Playlist group. A deck or Master group cannot acquire a browser action.

Neither source requires an application-connect handshake. The native profiles do not send unconditional zero-tempo LEDs.
Shutdown clears the six implemented output addresses. Feedback retains the XML's separate input/output addresses and value 100.
Directory mode, timed Scratch mode, cue preview, fine pitch, extended/manual loop semantics, FX and full feedback remain open.
The native player retains its Sync rules and bend policy. It does not reproduce the source's jog response curve.
Audio routing and physical acceptance remain open.

The defined catalogue remains 289 records and 153 data recipes plus seven code profiles.
Eighty-three factory profiles now select core controls automatically, covering 90 physical models.
All 219 focused Swift checks, 42 importer checks and native iPad compilation passed. The compiled resource matches the source.
Only the two existing Numark recipes change. The other 151 recipes remain unchanged. Twelve historical broken links remain.
Source base: `1a3b5f9`. Evidence: `TestBuilds/r204/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R203 relative jog movement and idle stop

Relative jog packets now retain their signed counts until the native player receives them.
A touched wheel follows its accumulated position and stops after 50 milliseconds without movement.
The final queued movement arrives before touch release or Load. A cancelled timer cannot reapply an old gesture.
Generation checks prevent an old timer from touching a replacement track.
Paused decks can seek with sensorless wheels under the existing Sync grid rule. Playing decks retain the existing temporary bend and saved Sync choice.
CDJ speed reports retain their existing continuous-rate path.

Published counts per revolution now calibrate DDJ-T1 (2430), Terminal Mix (800) and both Party Mix generations (340).
The factory manual and pinned scripts supply these values. Other relative profiles retain the generic 1024-count sensitivity.
That fallback requires model-specific calibration. It is not a measured hardware value.
The movement policy reuses the native waveform gesture contract and runs outside the audio callback.

Two offline reproductions failed before the fix: continued motion while held still, and no movement while paused.
The focused run covers 215 Swift checks, including eight new jog checks. The 40 importer checks and native iPad compilation pass.
An existing S1 assertion now expects the corrected movement-before-release order.
The compiled resource matches the source. Four data recipes gain calibration. The other 149 recipes remain unchanged.
Counts remain 289 catalogue records, 81 automatic core profiles and 88 physical models with automatic controls.
Twelve historical broken links remain. Earlier failing logs remain in the evidence directory.
Source base: `6949532`. Evidence: `TestBuilds/r203/`.
No signed app, installation, physical jog calibration or A10X acceptance forms part of this increment.

## R202 Terminal Mix 2 and 4 core controls

Terminal Mix 2 and 4 now share reviewed native core controls under their existing profile ID.
The catalogue retains separate physical-model records. Saved family disable settings and custom mappings retain their key.
Both models have four-deck source mappings. The native app keeps its existing four-deck opt-in.
Transport, Load, EQ, gain, level, headphone cue, eight Hot Cues, manual loops and signed jogs retain the pinned addresses.

The loop encoder accepts only the published 65/63 steps. Other values do not resize the loop.
Browsing retains full offset counts. Pitch retains the common helper’s exact 8192 centre and engine direction.
The crossfader retains its raw-64 centre detent. Other encoder and fader decoders retain their behaviour.
Core shutdown clears transport and headphone lights. Full pad cleanup, FX, sampler/scissor modes, cue deletion and advanced navigation remain open.
Fader/crossfader start, assignment/curve controls, remaining shifted functions, audio routing and physical acceptance also remain open.
The native profile does not copy the source 480-message LED sweep or enable four decks automatically.
Sources and helper SHA-256 identities are recorded in `tools/controller_profiles/terminal_mix.py` and the generated catalogue.
Counts remain at 289 records and 153 data recipes plus seven code profiles. Eighty-one profiles select core controls automatically, including accessories.
The catalogue records 88 physical models with automatic controls. This is core coverage, not complete feature parity.
All 207 focused Swift checks, 40 importer checks and native iPad compilation passed. The compiled resource matches the source.
Only the existing Terminal Mix family recipe changes. The other 152 recipes remain unchanged. Twelve historical broken links remain.
Source base: `aa85c90`. Evidence: `TestBuilds/r202/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R201 native loop-pad modes

Original Party Mix, Party Mix II and Mixtrack Pro FX now implement their published loop-pad modes.
Their sizes are 4/8/16/32 beats, 2/4/8/16 beats and 1/16 through 8 beats, respectively.
Mode guards keep these actions separate from Hot Cues and unsupported Sampler/FX modes.
Party Mix II Pad Mode hold and Pro FX shifted roll notes cannot trigger loop pads.

A new bounded loop-pad action changes size without stopping an active loop.
Pressing a pad that matches the actual active loop length exits that loop.
The comparison uses the beat grid and actual loop range. A manually set loop does not inherit a stale size choice.
The existing fixed-loop and loop-toggle actions retain their behaviour. The saved Sync choice remains unchanged.
Receiver fixtures cover all three mode maps. An offline playback fixture covers size changes, repeated presses, manual loops and invalid arguments.
Pad lights, remaining modes, advanced lifecycle, audio routing and physical acceptance remain open.
Sources remain the pinned original Party Mix, Party Mix II and Pro FX references recorded in their generator modules.
Counts remain at 289 records, 153 data recipes plus seven code profiles, and 80 automatic core profiles including accessories.
All 200 focused Swift checks, 39 importer checks and native iPad compilation passed. The compiled resource matches the source.
Only these three recipes change. The other 150 recipes remain unchanged. Twelve historical broken links remain.
Source base: `ab91aad`. Evidence: `TestBuilds/r201/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R200 Party Mix II core controls

Party Mix II now selects a separate native core profile from pinned community mappings.
Touch note 6 controls native Scratch. Both Note Off and zero-velocity Note On release the touch.
The original sensorless Party Mix profile remains separate. Live, III and Pro do not inherit the II recipe.
Core transport, Load, seven-bit tempo, gain, two-band EQ, levels and headphone controls retain their published addresses.
Browse press uses note 7. The older mapping retains an obsolete note 0 entry and a missing Scratch-button handler.
The native profile does not execute those scripts or inherit that handler.

Four Hot Cues per deck require Hot Cue mode. Other mode messages cannot trigger cues.
The newer FX mode address is 15. Pad Mode hold blocks unsupported delete gestures, and reconnects clear the hold state.
The hold address comes from the newer secondary mapping and remains physically unverified.
Setup sends the older published status request and mode indicators. Shutdown clears core Play, Sync and headphone lights.
Original-generation rear-lamp and Scratch-indicator writes are not part of this profile.

The secondary mapping declares AI-assisted development. Its advanced lamp/jog setup and heartbeat commands remain unimplemented.
Loop/Sampler/FX pad actions, cue deletion and pad lights, browser hold gestures, advanced lifecycle and full audio routing remain open.
All physical behaviour and source reuse/distribution review remain open.
Primary references: [mapping at f020c34](https://github.com/JakeDucati/mixxx_numark-party-mix-ii-mappings/tree/f020c34fa1b682ac4a862d0daa9621b958465525).
Secondary corroboration: [mapping at c06e361](https://github.com/cokeramirez/Party-Mix-MK2-MIXXX-advanced-mapping/tree/c06e36112728592bad996c51ed416f4af6d053eb).
Source revisions and individual SHA-256 identities are recorded in `tools/controller_profiles/party_mix2.py` and the generated catalogue.
The catalogue retains 289 records and now has 153 data recipes plus seven code profiles. Eighty profiles select core controls automatically, including accessories.
All 196 focused Swift checks, 38 importer checks and native iPad compilation passed. The compiled resource matches the source.
All 152 previous data recipes remain unchanged. Twelve historical broken links remain.
Source base: `27412ed`. Evidence: `TestBuilds/r200/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R199 Pioneer pad accessory core controls

XP2, XP1 and SP1 now select native accessory profiles. XP1 also gains a missing catalogue record.
These controls complement the app or another controller. The profiles do not invent Play, Tempo or mixer faders.
Each profile provides eight Hot Cues per deck, Sync, Load, browsing and its documented loop controls.
C/D retain the existing four-deck opt-in. Accessories do not consume the club-player deck allocation.

XP1 and XP2 use alternating pad channels for normal and shifted commands. SP1 uses consecutive deck pad channels and separate note ranges.
XP2 maps its upper eight pads in the factory row order. XP1 and SP1 retain ascending cue addresses.
Other pad modes and shifted delete messages cannot trigger those Hot Cues. Cue deletion and pad lights remain open.
The existing app capacity is eight Hot Cues per deck. XP1 lower pads and XP2 sampler pads stay unmapped.
XP loops use the labelled four-beat action. XP2 has dedicated half/double buttons.
XP1 retains manual Loop In/Out. Its contextual half/double behaviour remains open.
SP1 retains its signed loop-size encoder and current-size loop button.

SP1 sends the published application-connect packet. XP profiles send no undocumented connect packet.
XP automatic software-mode negotiation remains unimplemented. The catalogue records the required MIDI controller mode for other DJ software.
Core feedback retains each table’s Note Off or normal Note On behaviour. Complete pad/mode feedback and shutdown cleanup remain open.
Other pad modes, key controls, slip/censor, shifted functions, FX and physical acceptance remain open.
Factory tables: [XP2](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-XP2/DDJ-XP2_MIDI_Message_List_E1.pdf), [XP1](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-XP1/DDJ-XP1_List_of_MIDI_Message_E1.pdf) and [SP1](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-SP1/DDJ-SP1_List_of_MIDI_Messages_E.pdf).
SHA-256 identities are recorded in `tools/controller_profiles/pad_accessories.py` and the generated catalogue.
The catalogue now has 289 records and 152 data recipes plus seven code profiles. Seventy-nine profiles select core controls automatically, including accessories.
All 190 focused Swift checks, 37 importer checks and native iPad compilation passed. The compiled resource matches the source.
All 149 previous data recipes remain unchanged. Twelve historical broken links remain.
Source base: `d59310e`. Evidence: `TestBuilds/r199/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R198 DDJ-T1 core MIDI controls

DDJ-T1 now has a catalogue record and an automatic native core profile from Pioneer’s original manual.
Four deck channels retain transport, touch, paired tempo and signed high-resolution jogs. Global channel 7 carries mixer, Sync, headphone cue and Load.
The T1 uses jog pairs 1/33 and shifted 6/38. It does not use the S1 platter pair 2/34.
Normal and shifted tempo pairs remain separate. The loop encoder changes native size before the next loop button.
Gain, EQ, level, master, headphone mix/level, crossfader, filter and browsing retain their documented seven-bit addresses.
Deck and Shift buttons emit no MIDI. Shifted alternate addresses stay separate from normal inputs.

The needle table gives a range of 1–127 but labels its right endpoint 27. Needle position remains unmapped.
The mixer LED table uses an unresolved channel variable. Those feedback commands also remain unmapped.
Play and Key Lock feedback use the clear deck-channel table. No application-connect packet is documented or invented.
Move/Hot Cue/Delete modes, remaining shifted functions, complete loop/transport feedback, FX and audio routing remain open.
Jog calibration and physical acceptance remain open.
Source: [Pioneer Japanese manual](https://jpn.pioneer/ja/support/manual/manual_pdf.php?m_id=5799), printed pages 28–31.
SHA-256: `143d6f700323457b7acec969de1467d6b9783e64efe33e0fba49e362e41ca9b2`.
The catalogue now has 288 records and 149 data recipes plus seven code profiles. Seventy-six profiles select core controls automatically.
All 182 focused Swift checks, 36 importer checks and native iPad compilation passed. The compiled resource matches the source.
All 148 previous data recipes remain unchanged. Twelve historical broken links remain.
Source base: `ac8899a`. Evidence: `TestBuilds/r198/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R197 original Party Mix core controls

The original Party Mix now selects native core controls and four Hot Cues per deck automatically.
Each deck has an independent pad-mode latch. Loop, Sampler and FX modes cannot trigger Hot Cues.
Reconnects restore the source Hot Cue mode and clear old button edges. Hot Cue pad lights remain open.
Transport, XML Load notes 2/3, headphone cue, seven-bit tempo, two-band EQ, gain and levels retain their source addresses.
There is no invented Mid EQ control. Tempo accounts for the source non-inverted rate Pot and engine direction.

The source has no platter touch input. Native wheel-side jogging provides pitch bend without a false touch action.
The source’s timed sensorless Scratch mode remains unimplemented.
Startup disables the three party-light channels, sends the source manufacturer packet, dims Scratch and selects Hot Cue mode indicators.
Headphone cue feedback retains the source Note Off command and dim value. Other core lights use the source dim value of 1.
Loop/Sampler/FX pad actions, browser hold/focus gestures, party-light animation, full shutdown LED cleanup and audio routing remain open.
Physical response and source reuse/distribution review remain open. This profile does not select Party Mix II, III, Live or Pro.
Sources: pinned [XML](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark-Party-Mix.midi.xml) and [script](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark-Party-Mix.scripts.js).
SHA-256 identities are recorded in `tools/controller_profiles/party_mix.py` and the generated catalogue.
The catalogue retains 287 records and 148 data recipes plus seven code profiles. Seventy-five profiles select core controls automatically.
All 177 focused Swift checks, 35 importer checks and native iPad compilation passed. The compiled resource matches the source.
The other 147 data recipes remain unchanged. Twelve historical broken links remain.
Source base: `6540678`. Evidence: `TestBuilds/r197/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R196 original Mixtrack and Pro core controls

The original Mixtrack and Mixtrack Pro now select separate native core profiles.
They retain original-generation level controllers 8/9 and platter touch notes 78/77 on one shared MIDI channel.
They do not borrow Mixtrack II addresses. Transport, Load, headphone cue, EQ, signed jogs and fixed manual loops use native actions.
The crossfader retains the source inversion. Published LEDs use an on value of 100.
Startup lights native Scratch and file browsing, then clears the manual-mode indicators. Full indicator cleanup remains open.

The original XML rate input is inverted. The Pro script instead uses an asymmetric rate curve centred at raw 64.
Native profiles retain those separate source choices after the R191 engine-direction conversion.
The Pro reuses the existing centred-tempo decoder because its source formula has the same numeric contract.
Fixtures cover minimum, centre and maximum for both models. Physical tempo direction and jog calibration remain open.
Automatic detection requires the qualified name `Numark MIXTRACK` for the original model.
The generic `MIXTRACK` alias stays unmatched to avoid a wrong model selection.

Manual/auto loop toggles, directory latch, Delete/Hot Cue or EQ-kill modes, Scratch toggle, pitch-bend buttons and FX remain open.
Native transport and fixed manual loops do not reproduce the custom source scripts’ extra functions.
Complete feedback cleanup, audio routing and source reuse/distribution review remain open.
Pinned source identities are recorded in `tools/controller_profiles/original_mixtrack.py` and the generated catalogue.
Sources: original [XML](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20MIXTRACK.midi.xml), original [script](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark-MixTrack-scripts.js), Pro [XML](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20Mixtrack%20Pro.midi.xml) and Pro [script](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark-Mixtrack-Pro-scripts.js).
The catalogue retains 287 records and 148 data recipes plus seven code profiles. Seventy-four profiles select core controls automatically.
All 171 focused Swift checks, 34 importer checks and native iPad compilation passed. The compiled resource matches the source.
The other 146 data recipes remain unchanged. Twelve historical broken links remain.
Source base: `6b4d025`. Evidence: `TestBuilds/r196/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R195 Denon MC7000 core controls

MC7000 now selects a native core profile automatically from the pinned working mapping.
Its four sequential deck channels retain transport, global Load, gain, EQ, filter, level, headphone cue, loops and platter touch.
Tempo pairs controller 9 with low controller 119. Decoder state stays separate for each deck during interleaved messages.
Native tempo direction accounts for the source inversion and the R191 engine direction once.
Per-deck Shift blocks unsupported combinations and enables manual Loop In/Out and Reloop. Touch release still works during Shift.
C/D retain the existing four-deck opt-in. Reconnects clear Shift state.

The source jog rule uses `value < 0x64 ? value : value - 128`.
The native decoder preserves that unusual threshold exactly. It does not substitute the usual signed midpoint.
Fixtures cover raw values 0, 1, 63, 64, 99, 100 and 127. Other jog encodings keep their existing boundaries.
Independent byte-range confirmation and physical calibration remain open.
The official Traktor download was inspected, but it does not provide a readable jog-byte table.

Startup sends the pinned status request, initial deck indicators and native Scratch indicators. Shutdown dims the four Scratch indicators.
Core feedback retains the source dim value of 1. Pad modes, Vinyl toggle, deck-selection feedback, platter rings and screens remain open.
Other shifted functions, FX, meters, full lifecycle reset, hardware audio and source reuse/distribution review remain open.
Shift follows the pinned per-deck mapping. Bank changes while Shift is held need physical verification.
Sources: pinned [XML](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Denon-MC7000.midi.xml) and [script](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Denon-MC7000-scripts.js).
SHA-256 identities are recorded in `tools/controller_profiles/mc7000.py` and the generated catalogue.
The catalogue retains 287 records and 148 data recipes plus seven code profiles. Seventy-two profiles select core controls automatically.
All 166 focused Swift checks, 33 importer checks and native iPad compilation passed. The compiled resource matches the source.
The 147 other data recipes remain unchanged. Twelve historical broken links remain.
Source base: `3268049`. Evidence: `TestBuilds/r195/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R194 Denon MC6000MK2 core controls

MC6000MK2 now selects a native core profile automatically. Its transport channel order is A/C/B/D.
The profile includes transport, deck-local Load, gain, EQ, level, headphone cue, loops, signed jogs and fourteen-bit pitch-bend tempo.
Mixer addresses remain on the global channel. C/D still require the existing four-deck opt-in.
Each physical side shares Shift state across its two deck banks. A bank change cannot leave that Shift button held.
The browser encoder uses zero for forward and 127 for reverse. Other counts do not move the browser.
The jog decoder treats zero as neutral, as the pinned script requires. Touch-off messages cannot start a scratch.

Factory LED commands use a trigger controller and a separate LED identifier. They do not echo input notes.
Optional `offNumber` metadata retains different on/off trigger controllers with the same LED identifier.
Feedback covers Play, Sync, Key Lock, Auto Loop and headphone cue. Setup and shutdown set the four native Scratch indicators.
Existing feedback outputs retain their previous packet encoding. Invalid Shift identifiers and feedback trigger fields fail validation.

The dedicated factory command workbook corrects filter input addresses in the older manual.
Side-selected filters, Hot Cue/sample banks, browser buttons, Vinyl toggle, additional shifted functions, FX, meters and audio routing remain open.
Jog calibration and source reuse/distribution review remain open.
Source: [factory command archive](https://cdn.inmusicbrands.com/denondj/MC6000Mk2/MC6000MK2_MIDI_Command_List.zip), sheet `MC6000MK2`, input rows 6–174 and output rows 182–240.
Pinned [XML](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Denon-MC6000MK2.midi.xml) and [script](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Denon-MC6000MK2-scripts.js) confirm routing and decoder behaviour.
Archive, workbook and pinned source SHA-256 identities are recorded in `tools/controller_profiles/mc6000.py` and the catalogue.
The catalogue retains 287 records and 148 data recipes plus seven code profiles. Seventy-one profiles select core controls automatically.
All 160 focused Swift checks, 32 importer checks and native iPad compilation passed. The compiled resource matches the source.
The other 147 data recipes remain unchanged. Twelve historical broken links remain.
Source base: `7c9f4a5`. Evidence: `TestBuilds/r194/`. The first test compile failure remains recorded with the corrected run.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R193 Denon MC4000 core controls

MC4000 now selects a native core profile automatically. Exact aliases include Denon DJ MC4000.
The profile includes transport, Load, headphone cue, signed jogs, gain, EQ, filter, level, loops and browser controls.
Global Shift blocks unsupported deck combinations. Shift plus loop-size buttons sets manual Loop In/Out.
Touch release still works during Shift. Reconnects clear modifier state.

Factory pages 30–31 specify the MIDI addresses and LED echo commands.
The pitch table labels CC 9/41 as LSB/MSB. The pinned working mapping uses MSB 9 and LSB 41.
This recipe follows that working order and its explicit `rate_dir = -1`. The source conflict remains recorded in the catalogue.
Startup sends the pinned status request and lights native Scratch mode. Shutdown clears the owned jog indicators.
The factory assigns Key Lock to note 13 and Pitch Bend Up to note 11. The profile maps only Key Lock.

Pads and advanced pad modes, Vinyl toggle, other shifted functions, pitch-bend buttons, FX, meters and full audio routing remain open.
The master and booth controls operate hardware audio. This profile does not invent software Master messages.
Jog calibration, physical tempo direction and source reuse/distribution review remain open.
Sources: [factory manual](https://cdn.inmusicbrands.com/denondj/MC4000/MC4000-User-Guide-v1.2_00.pdf), pinned [XML](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Denon%20MC4000.midi.xml) and [script](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Denon-MC4000-scripts.js).
SHA-256 identities are recorded in `tools/controller_profiles/denon.py` and the generated catalogue.
The catalogue retains 287 records and 148 data recipes plus seven code profiles. Seventy profiles select core controls automatically.
All 152 focused Swift checks, 31 importer checks and native iPad compilation passed. The compiled resource matches the source.
The 147 other data recipes remain unchanged. Twelve historical broken links remain.
Source base: `8fee3ca`. Evidence: `TestBuilds/r193/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R192 Mixtrack II and Mixtrack Pro II core controls

Mixtrack II and Mixtrack Pro II now select separate native core profiles from the pinned shared mapping.
Both decks use physical MIDI channel 1. Distinct note/controller addresses keep their targets separate.
Independent Shift state still follows each deck. The shared physical channel does not merge those modifier states.

The profiles include transport, Load, headphone cue, signed jogs, EQ, level, manual loops and seven-bit tempo.
Shift changes Loop Half into Loop Double. Shift plus Pitch Bend Down toggles Keylock.
The receiver dispatches one loop action per press. Touch release still works during Shift, and reconnects clear Shift state.
Normal XML rate controls follow the corrected R191 tempo direction.
Published LEDs use an on value of 100. Setup lights native Scratch mode; shutdown clears the owned indicator addresses.

Pads/delete modes, Scratch toggle, pitch-bend buttons, other shifted functions, FX and full audio routing remain release work.
Platter response, source reuse and distribution review still require acceptance.
Sources: pinned [XML](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20Mixtrack%202.midi.xml) and [script](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark-Mixtrack-2-scripts.js).
SHA-256 identities are recorded in `tools/controller_profiles/mixtrack2.py` and the generated catalogue.
The catalogue retains 287 records and now has 148 data recipes plus seven code profiles. Sixty-nine factory profiles select core controls automatically.
Two exact recipes replace one combined partial recipe. All 146 other recipes remain unchanged.
All 148 focused Swift checks, 30 importer checks and native iPad compilation passed. The compiled resource matches the source.
Twelve historical broken links remain across 1,530 files.
Source base: `7be2c77`. Evidence: `TestBuilds/r192/`. The saved R191 candidate supplied the reviewed facts.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R191 native tempo direction for Mixxx-derived controls

The tempo audit found a translation error in the reviewed Numark profiles and converted XML rate controls.
The first translation copied the slider’s inversion without the engine’s direction multiplier.
Mixxx defaults to `rate_dir = -1`. Its rate ratio is `1 + rate_dir * rateRange * rate`.
GenErik tempo percentages increase with speed. The conversion now applies the engine direction once.
A source slider inversion therefore cancels that multiplier. A normal XML rate slider retains the multiplier.

The correction changes only tempo polarity in 54 runtime recipes and 121 tempo inputs.
The five reviewed Numark recipes now map raw minimum/maximum to native minimum/maximum tempo.
Converted normal XML rate controls use the opposite polarity, as the pinned Mixxx default requires.
Manufacturer-table profiles keep their existing raw MIDI interpretation. Other controls, lifecycle packets, feedback and aliases remain unchanged.
Receiver fixtures cover both fader endpoints across reviewed Numark profiles and a converted Hercules profile.
Earlier R187, R189 and R190 references to inverted Numark tempo pairs are superseded by this correction.
Physical controller verification remains open. These fixtures verify the source-to-native control contract.

Pinned engine sources: [rate calculation](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/src/engine/controls/ratecontrol.cpp) and [default direction](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/src/preferences/dialog/dlgprefdeck.cpp).
SHA-256: rate control `e15d822d3f2a9ff5307257a20b20db063b3ca75798e1cca1be5ae36886bbc0c0`.
SHA-256: deck preferences `f6109765b31bc1626daf858df7a9ea349fa04aaa2b65ac5e22041f6f52445169`.
Counts remain at 287 records, 147 data recipes plus seven code profiles, and 67 profiles that select core controls automatically.
All 143 focused Swift checks, 29 importer checks and native iPad compilation passed. The compiled resource matches the source.
Ninety-three data recipes remain unchanged. Twelve historical broken links remain across 1,528 files.
Source base: `4fc2c73`. Evidence: `TestBuilds/r191/`. Mixtrack II additions remain saved for the next increment.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R190 original Mixtrack Platinum core controls

The original Mixtrack Platinum now selects a native core profile automatically. Its profile remains separate from Platinum FX.
The four deck channels retain transport, deck-local Load, mixer, filter, headphone, loop and jog controls.
The tempo fader pairs high controller 9 with low controller 119. It does not use the standard low controller 41.
Optional pair metadata supports that published address and rejects identical or invalid controller pairs.
Existing standard pairs keep their decoding behaviour.

The jog decoder retains direction across a small raw-count change at the signed midpoint.
A large count jump can indicate an actual reversal. Per-deck histories remain separate and reconnects clear them.
This follows the pinned script’s wrap rule. Fixtures do not establish physical feel or calibration.

Startup sends the source demo-exit packet and lights the four jog indicators. Shutdown sends the source mode-reset packet.
Global Shift blocks unsupported base combinations while permitting the documented shifted Loop In/Out controls.
Touch release still clears a held platter. Pads, Scratch toggle, advanced shifted functions, FX, meters, screens and audio routing remain open.
Source reuse and distribution review remain release work.
Sources: pinned [XML](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20Mixtrack%20Platinum.midi.xml) and [script](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark-Mixtrack-Platinum-scripts.js).
SHA-256 identities are recorded in `tools/controller_profiles/platinum.py` and the generated catalogue.
The catalogue retains 287 records and 147 data recipes plus seven code profiles. Sixty-seven factory profiles select core controls automatically.
The reviewed original Platinum recipe replaces its partial recipe. All 146 other data recipes remain unchanged.
All 141 focused Swift checks, one explicit-pair validation check, 28 importer checks and native iPad compilation passed.
The compiled resource matches the source. Twelve historical broken links remain across 1,527 files.
Source base: `27755cf`. Evidence: `TestBuilds/r190/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R189 Mixtrack 3 and Mixtrack Pro 3 core controls

Mixtrack 3 and Mixtrack Pro 3 now select separate native core profiles automatically.
The pinned XML explicitly documents their shared MIDI controls. The Pro adds audio hardware.
The profiles retain deck channels 2/3, global browser/mixer channel 1 and inverted high-resolution tempo pairs.
They include transport, Load, headphone cue, signed jogs, EQ, filter, level and manual loop controls.

Each deck has its own Shift state. Holding left Shift blocks unsupported left-deck combinations and preserves right-deck controls.
Holding right Shift has the matching behaviour. Global controls retain their normal path.
Jog touch release still works during Shift. Disconnects clear both modifier states.
Optional profile fields define this scope. Earlier profiles and saved global Shift bindings keep their existing behaviour.

Platter touch uses the native Scratch path. Setup lights the published jog indicators and shutdown clears them.
Pad/sample modes, shifted functions, deck switching, Scratch toggle, FX and complete audio routing remain unimplemented.
Physical jog calibration and source reuse/distribution review remain release work.
Sources: pinned [XML](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark-Mixtrack-3.midi.xml) and [script](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark-Mixtrack-3-scripts.js).
SHA-256 identities are recorded in `tools/controller_profiles/mixtrack3.py` and the generated catalogue.
The catalogue retains 287 records and now has 147 data recipes plus seven code profiles. Sixty-six factory profiles select core controls automatically.
Two exact model recipes replace one combined partial recipe. All 145 other recipes remain unchanged.
All 134 focused profile checks, four Shift/takeover regression checks, 27 importer checks and native iPad compilation passed.
The compiled resource matches the source. Twelve historical broken links remain across 1,524 files.
Source base: `548fb78`. Evidence: `TestBuilds/r189/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R188 mode-gated Mixtrack Pro FX Hot Cues

Mixtrack Pro FX now has eight native Hot Cues per deck in its documented Hot Cue mode.
Each deck tracks its own mode. Auto Loop, Fader Cuts, Sample, Beat Jump and second Sample selections block Hot Cues.
Shifted delete-pad messages stay unmapped. Switching modes cannot turn those messages into cue triggers.
Pad releases still clear input state after a mode change.

Startup restores the source Hot Cue mode and its six mode indicators on each deck.
Mode presses update only the paired physical controller’s indicators. Repeated discovery preserves the active mode.
Reconnects reset the mode to the documented initial state. Other sources and UMP groups cannot change it.
Bounded profile data validates selector channels, initial modes, note lists and indicator values.
A mode-gated button must reference a valid selector on the same channel.

Pro FX non-Hot-Cue pad actions, cue lights, Scratch toggle, shifted functions, FX, meters and audio routing remain release work.
Platinum FX pads remain unmapped. Its additional bank and hold behaviour needs separate review.
The input-mode contract is optional. Earlier profiles and saved bindings keep their existing behaviour.
Source facts remain the pinned Pro FX XML and script recorded in R187.
Counts remain at 287 records, 146 data recipes plus seven code profiles, and 64 profiles that select core controls automatically.
Only the Pro FX data recipe changed. All 145 other recipes remain unchanged.
All 129 focused Swift checks, 26 importer checks and native iPad compilation passed. The compiled resource matches the source.
Twelve historical broken links remain across 1,522 files.
Source base: `3136dbc`. Evidence: `TestBuilds/r188/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R187 Mixtrack FX core controls and bounded SysEx setup

Mixtrack Pro FX and Mixtrack Platinum FX now select reviewed native core profiles automatically.
The profiles use MIDI addresses and protocol facts from the pinned Mixxx XML and scripts. The app does not execute those scripts.
Pro FX has two deck targets. Platinum FX has four. Existing deck-capacity guards still block inactive C/D inputs.

Startup sends the source demo-exit, model-specific pad-layout and status-request packets to the paired physical output.
Disconnect sends the documented shutdown packet. Reconnect repeats startup. Failed setup keeps core controls inactive.
Setup accepts complete SysEx packets of 4–128 bytes, with seven-bit payload bytes and a final `F7`.
The sender rejects malformed or oversized setup packets. Existing short-message setup remains valid.

Core controls include transport, Load, signed jogs, touch, inverted high-resolution tempo, loops, EQ, filter and mixing.
Pro FX headphone level/blend use channel 15. Platinum FX uses channel 16 and separate controller numbers.
Binary feedback retains the source dim value of 1. Normal Scratch mode follows native platter-touch behaviour.
Pad modes, Scratch toggle, shifted functions, FX, meters, screens and complete audio routing remain unimplemented.
Pads stay unmapped until the app can track their modes. Jog response still needs physical calibration.
Source reuse and distribution review remain release work.

Sources: [Pro FX script](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark-Mixtrack-Pro-FX-scripts.js) and [Platinum FX script](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark-Mixtrack-Platinum-FX-scripts.js).
XML and script SHA-256 identities are recorded in `tools/controller_profiles/numark.py` and the generated catalogue.
The source inventory still contains every locked XML definition. Reviewed native recipes remain separate records.
The catalogue retains 287 records and 146 data recipes plus seven code profiles. Sixty-four factory profiles select core controls automatically.
Two reviewed recipes replace earlier partial FX recipes. All 144 other data recipes remain unchanged.
All 124 focused Swift checks, 25 importer checks and native iPad compilation passed. The compiled resource matches the source.
Twelve historical broken links remain across 1,520 files.
Source base: `151dee5`. Evidence: `TestBuilds/r187/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R186 XDJ-AERO and XDJ-R1 core controls

XDJ-AERO and XDJ-R1 now select core MIDI profiles automatically.
Their factory manuals publish four deck channels and a separate channel-7 mixer.
Each deck has a browser encoder. Pressing its rotary selector loads the selected track into that deck.
The receiver applies pending Browse counts before Load. Global mixer buttons cannot trigger Load.

Both profiles include transport, tempo, binary-offset jogs, signed loop sizing, EQ, gain, filter and headphone controls.
R1 has three Hot Cues per deck. AERO has no mapped Hot Cues because its table provides sample controls instead.
The profiles retain documented binary lights and empty startup/shutdown lists.
MIDI control and MIXER MODE PC still require hardware selection. Complete audio routing remains open.
Shifted modes, FX/samples, deck-bank display feedback, screens and physical jog calibration remain release work.

The source documents are Pioneer factory operating manuals hosted by public mirrors. Their MIDI tables remain separate from app recipes.
AERO: [factory manual](https://www.recordcase.de/media/94/f5/e0/1745829305/Pioneer-XDJ-AERO-Manual-EN.pdf), pages 23, 26 and 29–32.
SHA-256: `72e14c9420b09e81fdc790bb00a609ad1f8d197890b4416205c4f98b84d171b3`.
R1: [factory manual](https://www.uns.nu/pdf/Pioneer_XDJ-R1_Manual.pdf), pages 22 and 27–34.
SHA-256: `5f41454ad19ac54527dd6f32c9e5e6e4d9812a53be7f6a82829042dbc02ec183`.
The catalogue now has 287 records and 146 data recipes plus seven code profiles. Sixty-two factory profiles select core controls automatically.
All 144 earlier data recipes remain unchanged. All 119 focused Swift checks, 24 importer checks and native iPad compilation passed.
The compiled resource matches the source. Twelve historical broken links remain across 1,518 files.
Source base: `8bf9d81`. Evidence: `TestBuilds/r186/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R185 DDJ-S1 and paired relative jog messages

DDJ-S1 now selects its documented core MIDI profile automatically.
Its platter and wheel-side jogs send signed 14-bit pairs. The decoder emits one count after a complete pair.
Orphan and repeated low bytes cannot move the deck. Reconnects clear incomplete pairs. Deck and control state remain separate.
Existing absolute pairs still emit their coarse high-byte value and refined low-byte value.

The S1 profile retains Sync Note 27, Load Note 61, five Hot Cues, shifted touch Note 104 and its channel-5 mixer.
It includes the native signed loop encoder, manual loops, tempo, waveform position, headphone cue and documented binary lights.
Shifted delete/mode functions, FX, hardware audio controls, jog/position illumination and complete audio routing remain release work.
Jog response still needs physical calibration. The paired count fixtures do not establish physical feel.
The table documents no application-connect packet. Startup and shutdown remain empty.

Source: [DDJ-S1 factory MIDI table](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-S1/DDJ-S1_MIDI_Messages_2.pdf), pages 2–3.
SHA-256: `61f299828b2abfa5cdc1b09a3b4253d4b99b9c17c53b2f387293754448a1ad7b`.
The catalogue retains 285 records and now has 144 data recipes plus seven code profiles. Sixty factory profiles select core controls automatically.
All 143 earlier data recipes remain unchanged. All 114 focused Swift checks, 23 importer checks and native iPad compilation passed.
The compiled resource matches the source. Twelve historical broken links remain across 1,516 files.
The first input run exposed discarded incomplete decoder state. The receiver now retains that state before waiting for another byte.
Source base: `c4e9265`. Evidence: `TestBuilds/r185/`. The source PDF remains in `TestBuilds/r184/manufacturer/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R184 ERGO and earlier WeGO systems

DDJ-WeGO3, WeGO2, WeGO and ERGO now select their documented core MIDI profiles automatically.
WeGO3 has two deck targets. The earlier WeGO models and ERGO have four published deck channels.
WeGO2 adds a separate catalogue record. The original benchmark names retain their source definitions.

WeGO3 Play uses Note 8. Earlier WeGO and ERGO Play use Note 11.
WeGO jogs use binary-offset counts. ERGO jogs use signed two’s-complement counts.
Shifted jogs use CC 39. ERGO Vinyl Off releases cannot start a scratch.
The earlier loop knobs use the signed native loop-size action from R183. WeGO3 has separate half/double buttons.
All four models have four Hot Cues per deck. Their mixers use global channel 7 and documented 14-bit pairs.
ERGO retains its separate gain, filter, master and headphone controls. No equivalent WeGO controls are invented.

The profiles retain empty startup lists. The tables do not document application-connect packets.
The earlier WeGO profiles use the factory VirtualDJ message tables. Other hardware message modes remain separate work.
Shifted delete/sample modes, FX, jog illumination, complete feedback and audio routing remain release work.
The DDJ-S1 source is cached for the next increment. Its paired relative jog needs a separate decoder contract.

Factory sources and hashes are recorded in `tools/controller_profiles/legacy_ddj.py` and the generated catalogue.
The catalogue now has 285 records and 143 data recipes plus seven code profiles. Fifty-nine factory profiles select core controls automatically.
All 139 earlier data recipes remain unchanged. All 106 focused Swift checks, 22 importer checks and native iPad compilation passed.
The compiled resource matches the source. The repository check retains 12 historical broken links across 1,513 files.
Source base: `1fc9af5`. Evidence: `TestBuilds/r184/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R183 OPUS-QUAD core MIDI controls

OPUS-QUAD now selects its documented core MIDI profile automatically.
The factory table supplies four deck channels, eight irregular Hot Cue addresses and a separate software mixer channel.
The profile retains shifted jog CC 41, signed loop-size CC 46 and Needle Position zero-release handling.
The loop encoder applies each packet before the next button. Each packet changes the loop size once, within the existing bounds.
Loop press toggles the current size. Shift press restores the last loop. Long IN selects four beats.
The native loop path preserves the saved Sync choice.

The profile includes transport, Load, manual loops, beat jumps, tempo, jog touch, EQ, gain, filter and headphone controls.
Play, Sync and Master Tempo use documented binary feedback. Colour-coded Cue/Hot Cue lights and jog indicators remain open.
Screens, FX, input/crossfader assignment, booth/zone audio and complete audio routing remain release work.
PC Control CC 100 remains a hardware-to-host report. It is not a startup command.
Select MIDI / PC control on the unit. Hardware mode selection remains outside the automatic profile.

Source: [factory MIDI table](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/OPUS-QUAD/OPUS-QUAD_MIDI_Message_List_E1.pdf), pages 2–3.
SHA-256: `cc65740ff56d1610ea8daa553559cb3d4e4d181754fe424973a2495507f5d695`.
[Factory hardware diagram](https://cdn.rekordbox.com/files/20230307164217/OPUS-QUAD_HardwareDiagram_en.pdf) confirms Beat Loop and shifted Reloop functions.
The catalogue retains 284 records and now contains 139 data recipes plus seven code profiles.
Fifty-five factory profiles select core controls automatically. All 138 earlier data recipes remain unchanged.
All 100 focused Swift checks, 21 importer checks and native iPad compilation passed. The compiled resource matches the source.
The repository check retains 12 historical broken links across 1,511 files.
Source base: `3389c36`. Evidence: `TestBuilds/r183/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R182 published DDJ application-connect messages

SX, SX2, RX, RZ, RZX, SZ and SZ2 now send their documented application-connect packet to the paired MIDI output.
Each factory table specifies channel 12, Note 9, with any data value indicating connection. The profiles send `9B 09 7F`.
The packet runs once when the session starts and again after a reconnect.
The tables define no disconnect value. The shutdown lists remain empty.

Failed startup keeps the factory controls inactive and reports the setup failure.
Fixtures cover all seven models, unrelated output ports, repeated discovery and reconnects.
The negative fixtures retain empty startup lists for models without that documented command.
XDJ PC Control messages remain hardware-to-host reports. Their hardware mode still requires selection on the unit.

All control, feedback, alias and deck facts remain unchanged. Only seven startup lists changed.
The catalogue remains at 284 records, 138 data recipes and seven code profiles. Fifty-four factory profiles select core controls automatically.
All 94 focused Swift checks, 20 importer checks and native iPad compilation passed. The compiled resource matches the source.
The repository check retains 12 historical broken links across 1,509 files.
Source base: `1961189` on `feature/controller-support`. Evidence: `TestBuilds/r182/`.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R181 entry-level Pioneer systems

DDJ-SB2, SB, RB, RR, 200 and WeGO4 now select documented core controls automatically.
SB, SB2 and 200 replace earlier partial recipes. The catalogue retains their original source definitions.

| Model | Deck targets | Pads and controls |
| --- | ---: | --- |
| DDJ-SB2 | 4 | Four physical pads address Hot Cues 1–4 and 5–8 in separate modes. Manual Loop pads keep their own messages. |
| DDJ-SB | 2 | The same two Hot Cue banks and separate Manual Loop messages. No gain knob is mapped. |
| DDJ-RB | 2 | Eight Hot Cues, loop in/out, four-beat long press and the documented mixer controls. No guessed Keylock button. |
| DDJ-RR | 4 | Eight Hot Cues, manual/automatic loops, needle position and the documented software mixer controls. |
| DDJ-200 | 2 | Eight generic pads use native Hot Cues. Transport, jog, tempo and the documented mixer controls are mapped. |
| DDJ-WeGO4 | 2 | Four Hot Cues, loops and a two-band mixer. Mixer messages use the global channel. Loop lights use separate output addresses. |

The SB, SB2 and RR profiles send their published application-connect message once to the paired output.
The table defines any value as connected. It defines no shutdown value, so these profiles send no invented disconnect message.
RR Back uses the table's explicit hexadecimal status byte, `96`, on the global channel.

SB Vinyl Off touch messages must not start a scratch. A release-only binding can end a touch that began in Vinyl On mode.
Only momentary note actions can use this binding flag. Invalid catalogue records fail validation.
The packet fixture checks that a Vinyl Off press cannot start another touch.

DDJ-200 has no hardware browser, Load, loop or Keylock buttons. Those functions use the existing app controls.
Its Bluetooth connection and pairing flow retain a separate verification scope.
WeGO4 has no mapped gain or mid-EQ knob. SB master/headphone-level controls remain hardware controls where the table specifies no MIDI message.
Remaining pad/FX modes, complete feedback, lifecycle details and audio routing remain release work.

The catalogue contains 284 records, 138 data recipes and seven code profiles. Fifty-four factory profiles select core controls automatically.
Three partial recipes changed. The other 132 earlier data recipes retain their control facts.
References and content hashes are in [`entry.py`](../../tools/controller_profiles/entry.py).
Source base: `ec6d566` on `feature/controller-support`. Evidence: `TestBuilds/r181/`.
All 91 focused Swift checks and 19 importer checks passed. Native iPad compilation passed and its resource matches the source.
The repository check retains 12 historical link failures.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R180 Serato-oriented DDJ and XDJ-RX models

DDJ-1000SRT, DDJ-SZ2, DDJ-SZ and XDJ-RX2 now select core MIDI controls automatically.
The original XDJ-RX has a separate manual recipe. The newer RX2 does not inherit its older speed protocol.

| Model | Implemented differences | Open functions |
| --- | --- | --- |
| DDJ-1000SRT | Four deck targets, separate pad channels, four-beat loop toggle and dedicated Beat Jump buttons. | Jog screens, remaining modes and audio routing. The unit has no mapped needle strip. |
| DDJ-SZ2 | Four deck targets, eight Hot Cues, linear needle strip, loops and software mixer controls. | Remaining key/pad modes, complete feedback, displays and audio routing. |
| DDJ-SZ | Four deck targets, eight Hot Cues, linear needle strip, loops and software mixer controls. | Remaining modes, complete feedback, displays and audio routing. |
| XDJ-RX2 | Four documented MIDI deck addresses, eight Hot Cues, relative jogs, manual/four-beat loops and mixer controls. | Hardware MIDI mixer mode, remaining modes, displays and audio routing. |
| XDJ-RX | Four documented MIDI deck addresses, four Hot Cues, absolute jog speeds and seven-bit tempo/mixer controls. | The table has no Load message or MIDI output. The recipe stays outside automatic selection. |

The 1000SRT loop button sets four beats and toggles the loop. A second press exits.
It preserves the saved Sync choice. Other Auto Loop buttons retain the app's selected loop size.
Invalid fixed-size arguments cannot toggle a loop.
The RX2 profile uses its documented relative jog stream. It ignores the alternative absolute stream to avoid duplicate motion.
The original RX wheel-side stream uses the published platter-speed curve, including its low-speed range.
Factory tables supply URLs, reviewed pages and content hashes in the generator modules.

REV7 remains outside automatic selection.
The 2024 factory MIDI table is available as web text. Local download attempts returned missing-file or access errors.
The table's relative JOG entry alone does not establish motorised-platter support.
Motor, platter, display and lifecycle protocols need review and implementation before automatic selection.

The catalogue contains 281 records, 135 data recipes and seven code profiles. Forty-eight factory profiles select core controls automatically.
All 130 earlier data recipes retain their control facts.
Source base: `8443be0` on `feature/controller-support`. Evidence: `TestBuilds/r180/`.
The first Swift run retained two old tests that excluded newly implemented models. Their model-boundary assertions now cover the new profiles.
All 84 focused Swift checks and 18 importer checks passed. Native iPad compilation passed and its resource matches the source.
The repository check retains 12 historical link failures.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R179 SX and RX-family controllers

Six earlier DDJ systems now select core MIDI controls automatically: SX3, SX2, SX, RX, RZ and RZX.
They use hashed factory tables and the existing native control actions. The order groups common models before larger specialist systems.
Global model-sales ranks remain unknown.

All six profiles cover four documented MIDI decks, Play, Cue, Sync, Keylock/Master Tempo, mixer controls, eight Hot Cues and browse/load.
Platter Vinyl On and Vinyl Off messages retain separate addresses. Both use the documented centre-64 relative encoding.
Tempo, EQ, gain and channel faders retain their 14-bit pairs.
Auto Loop, loop size, loop in/out and Reloop retain separate messages.
The RZX also maps its documented Tempo Reset button.

The five models with a needle strip use a linear zero-to-127 position. Zero means the file start, unlike the CDJ release sentinel.
Needle position now bypasses soft takeover. Its packet fixtures verify both endpoints against an app value at the centre.
RZX touch-screen gestures remain unmapped. They do not imply a needle strip.

The original SX factory table specifies CC32/64 for the deck-D filter. Its browser also uses CC64 on the same MIDI channel.
That filter remains unmapped until the source conflict is resolved. SX2 and later filter addresses do not inherit this pair.
No new decoder extension or guessed replacement address forms part of this increment.

Hardware-only master and headphone knobs remain hardware controls. RZ and RZX retain their documented software mixer messages.
Colour-pad feedback stays open except for the original SX's documented on/off lights. Other mapped button lights use published addresses.
Factory hardware modes, full lifecycle handling, advanced pad modes, displays and automatic audio routing remain release work.

SR2 now has a source record, without an automatic profile.
Its Load buttons use shared left/right packets. They do not name the selected deck.
Implement bank selection, safe initial state and bank-specific Load fixtures before automatic selection.
The reviewed SR2 factory table and its content hash remain in [`ddj_family.py`](../../tools/controller_profiles/ddj_family.py).

The catalogue contains 276 records, 130 data recipes and seven code profiles. Forty-four factory profiles select core controls automatically.
All 124 earlier data recipes retain their control facts. Hardware-mode metadata is now visible in the catalogue where documented.
Source base: `d8eef22` on `feature/controller-support`. Evidence: `TestBuilds/r179/`.
All 78 focused Swift checks, 17 importer checks and native iPad compilation passed.
No signed app, installation, controller hardware test or A10X acceptance forms part of this increment.

## R178 popular XDJ and DDJ systems

Six more systems now select core MIDI controls automatically in the requested controller worktree.
The order favours recent all-in-one systems and common DDJ models. It does not claim measured global model-sales ranks.

| Model | Core controls | Specific limits |
| --- | --- | --- |
| XDJ-AZ | Four documented decks, mixer, eight Hot Cues, manual/fixed loops, tempo reset, Beat Jump and needle position. | Pads 5–8 use separate channels. Faders follow the factory table's upper-zero direction. |
| XDJ-RX3 | Four documented MIDI deck addresses, mixer, eight Hot Cues, manual loops and needle position. | The hardware has two physical mixer channels. Select its MIDI mixer mode where required. |
| XDJ-XZ | Four documented decks, mixer, eight Hot Cues, manual/fixed loops, tempo reset and needle position. | Hardware PC/MIDI mode remains necessary. |
| DDJ-FLX6 | Four decks, mixer, eight Hot Cues, platter touch/jog and manual loops. | Merge FX, Jog Cutter, pad modes and displays remain open. No guessed Master Tempo button. |
| DDJ-800 | Four documented MIDI deck addresses, mixer, eight Hot Cues, Master Tempo and manual loops. | The hardware has two physical mixer channels. Displays and remaining modes stay open. |
| DDJ-SB3 | Four decks, mixer, eight Hot Cues, Keylock, Auto Loop and loop size controls. | FX Fade, Pad Scratch and remaining pad modes stay open. |

All six profiles map Play, Cue, Sync, tempo, platter touch/jog, wheel-side jog, browse/load, channel cue and documented mixer controls.
Tempo and DDJ mixer controls retain their published 14-bit pairs. XDJ mixer controls use seven-bit values.
Browse direction reaches the app before a subsequent Load press.
Only documented button lights are mapped. Colour-pad feedback remains open except for the SB3's documented on/off lights.
Long IN presses retain their separate four-beat message after the short IN message.
Tempo-range changes, shifted functions and full hardware feature parity remain open.

All factory and learned MIDI bindings now respect the existing four-deck trial capacity.
C/D inputs cannot control hidden decks in the base workspace. Pending controls also respect the capacity when they leave the queue.
Button releases still clear stored state. Held platter touches can release after the capacity changes.

Factory MIDI tables supply all six recipes. Their URLs, reviewed pages and SHA-256 hashes are in [`controllers.py`](../../tools/controller_profiles/controllers.py).
The new SB3 recipe replaces its partial imported recipe. The other 118 existing data recipes retain their control facts.
The catalogue now contains 271 records, 124 data recipes and seven code profiles. Thirty-eight factory profiles select core controls automatically.
Hardware mode selection, full lifecycle handshakes, advanced modes, complete feedback and audio routing remain theoretical-support work.
No model becomes fully supported from this core increment alone.

Source base: `5cae857` on `feature/controller-support`. Evidence: `TestBuilds/r178/`.
All 73 focused Swift checks and 16 importer checks passed. Native iPad compilation passed and its resource matches the source.
The repository check retains 12 historical link failures.
The first Swift run exposed an incorrect fixture expectation about the existing 14-bit decoder. The corrected fixture checks both bytes.
No signed app, installation, controller hardware test or A10X audio/touch acceptance forms part of this increment.

## R177 XDJ and earlier CDJ controls

Nine more players have automatic core MIDI profiles. The first three extend the XDJ range, followed by earlier CDJs and the specialist TOUR1.
The order balances likely use, recency and documented reuse. Global model-sales ranks remain unknown.

| Model | Hot Cues | Fixed beat loops | Beat Jump |
| --- | ---: | --- | --- |
| XDJ-1000MK2 | 8 | 1/2–16 beats | 1–32 beats, with explicit direction and size. |
| XDJ-700 | 3 | 1/2–16 beats | No mapped button. |
| XDJ-1000 | 3 | 1/2–16 beats | 1, 2 and 4 beats, with separate forward/reverse ranges. |
| CDJ-2000 | 3 | 4 beats | No mapped button. |
| CDJ-900 | 0 | 1–8 beats | No mapped button. |
| CDJ-850 | 0 | 1–8 beats | No mapped button. |
| CDJ-350 | 0 | Uses the app's selected size. Divide/restore buttons are mapped. | No mapped button. |
| CDJ-400 | 0 | Uses the app's selected size. Divide/restore buttons are mapped. | No mapped button. |
| CDJ-TOUR1 | 8 | 1/16–32 beats | Uses the app's selected size. |

Each profile covers Play, Cue, Master Tempo, platter touch/speed, wheel-side jog, tempo, browse/load and loop in/out/exit.
The XDJ models and TOUR1 map their Sync buttons. CDJ-350 maps BPM LOCK to the app's Sync action.
The original CDJ-2000, CDJ-900, CDJ-850 and CDJ-400 have no mapped Sync button.
They retain the app's saved Sync choice. Needle seek and Tempo Reset appear only where the model's table specifies them.
CDJ-400-K uses the CDJ-400 profile. Pioneer publishes shared firmware and software support for both variants.

The CDJ-350 decoder follows the asymmetric reverse-speed range in its reviewed factory table.
This remains a documented hardware assumption until a connected unit confirms it.
CDJ-400 browse uses a centre-64 encoder. The other additions use signed count messages.
Fast encoder turns retain their full count through bounded messages before Load.
The first XDJ-1000 and its MK2 have different jump addresses. The MK2 Slip button does not become a jump command.

On the 350/400, the minus button halves an active loop. The plus button restores its original length after repeated divisions.
With no active loop, either button starts a loop at the app's selected size.
The CDJ-400 Reloop action also restores that original length.
Changed loop points and track generations invalidate the saved division range.
These controls use native loop commands and preserve the saved Sync choice.

This increment replaces three partial recipes: CDJ-2000, CDJ-850 and CDJ-350 CH1.
The CH1/CH2 source definitions remain in the catalogue. Their shared physical model now uses one profile with automatic deck assignment.
The reviewed factory mappings omit earlier remaps such as Gain on the 850 brake knob and a fourth Hot Cue on the original 2000.
Explicit learned mappings retain their separate state.

The catalogue now contains 268 records and 119 data recipes, alongside seven code profiles.
Thirty-two factory profiles select core controls automatically, including 15 player profiles.
The two previously web-reviewed NXS manuals now have downloaded factory editions and content hashes.
XDJ-700 and CDJ-900 retain web-reviewed manual text with null document hashes.
All source definitions remain available. See [`players.py`](../../tools/controller_profiles/players.py) for references and reviewed pages.

Hardware PC or USB-MIDI mode is required. HID, screens, lights, remaining modes and automatic multi-device audio routing remain open.
No signed app, installation or physical acceptance forms part of this increment.
Source base: `12a7c06` on `feature/controller-support`. Evidence: `TestBuilds/r177/`.

All 66 focused Swift checks and 15 importer checks passed. Native iPad compilation passed.
Mixed-player fixtures cover every MIDI channel, exact matching, missing controls, browse direction and model-specific jump sizes.
The track fixture verifies repeated loop division, original-length restoration, Reloop and the saved Sync choice.
The native resource matches the generated profile file. The repository check retains 12 historical link failures.

## R176 club-player MIDI controls

Six club players now have automatic core MIDI profiles in the requested controller worktree.
The order balances established models and recent releases. It is an implementation order, not a measured global sales ranking.

| Order | Model | Hot Cues | Fixed beat loops | Beat Jump |
| ---: | --- | ---: | --- | --- |
| 1 | CDJ-3000 | 8 | 1/16–32 beats | GUI 1/2–64 beats. Physical buttons send 16 beats. |
| 2 | CDJ-3000X | 8 | 1/4–32 beats | GUI 1/2–64 beats. Physical buttons use the app's selected size. |
| 3 | CDJ-2000NXS2 | 8 | 1/16–32 beats | GUI buttons use the app's selected size. |
| 4 | CDJ-1500X | 8 | 1/2–16 beats | GUI 1/2–64 beats. |
| 5 | CDJ-2000NXS | 3 | Not mapped | Not mapped |
| 6 | CDJ-900NXS | 0 | 4 beats | Not mapped |

All six profiles cover Play, Cue, Sync, Master Tempo, platter touch/speed, wheel-side jog, tempo, browse/load and loop in/out/exit.
Reloop restores the existing loop points. Cue retains the app's existing set/return behaviour.
Needle position is available where the factory table specifies it. Its release message does not seek to the start.
Tempo Reset is available on the 3000, 3000X, NXS2 and original 2000NXS.
Tempo retains the app's existing ±8% range. Hardware range selection remains open.

The hardware must enter Software Control / USB-MIDI mode. The app then selects its profile without a mapping choice.
Two players receive separate A/B assignments, even when both use the same MIDI channel.
Connected assignments take priority over saved identities and newly connected players.
Saved endpoint identities retain their deck choices. New identities receive an available deck.
The deck picker swaps occupied assignments and releases held touches before rebinding.
Enable choices and learned mappings remain specific to each player identity.
Default controls follow a deck swap. An explicitly learned A/B target retains that choice.
C/D require the existing four-deck trial. The base mode does not assign extra players to hidden decks.

### Remaining club-player scope

These profiles implement MIDI input. HID, player screens, lighting and automatic routing across multiple audio interfaces remain open.
The factory MIDI input tables do not define those output protocols.
The pinned Mixxx HID definition names older CDJ-850/900/2000 devices. It does not establish modern CDJ HID support.
Full theoretical support also requires the remaining hardware modes, shifted controls, tempo ranges, memory cues and complete protocol fixtures.
Slip loops, triplet loops and hot-cue editing remain outside this core scope.
Variable-size jump messages do not report their hardware size. They use the app's selected beat size.

The catalogue now contains 262 records and 113 data recipes, alongside seven code profiles.
Twenty-three factory profiles select core controls automatically. The larger recipe count includes partial manual mappings.
These counts do not establish Serato feature parity or full zero-config support.

Factory references and reviewed pages are in [`cdj.py`](../../tools/controller_profiles/cdj.py) and the [JSON catalogue](controller-catalogue.json).
Four downloaded documents have content hashes. The two older web-reviewed manuals retain null hashes and explicit evidence notes.
The app bundles normalised MIDI facts and does not execute downloaded scripts.
Source base: `682e108` on `feature/controller-support`. Validation evidence: `TestBuilds/r175/`.

### Verification

All 56 focused Swift checks and 14 importer checks passed.
Fixtures cover each generation, all MIDI channels, two-player assignment, disconnect, reconnect, deck swaps, held touches and learned mappings.
The track fixture verifies fixed loop/jump sizes, needle seek, loop in/out, Reloop and the saved Sync choice.
Native iPad compilation passed. The bundled profile resource matches the source hash.
All 107 existing data recipes remain unchanged. This increment adds six profiles.
The repository check retains 12 existing historical link failures.
No signed app, installation, connected-controller check or A10X performance acceptance forms part of this increment.

## R175 theoretical support and separate physical evidence

Erik clarified the completion target on 12 November 2026. Implement documented theoretical support across the catalogue.
Physical verification is a separate confidence state. Owning or testing every controller is not a completion requirement.
Missing protocols, mappings, modes and audio routes still require implementation. An inventory entry does not establish support.

The catalogue now records separate theoretical criteria for protocol implementation, complete documented controls, lifecycle, audio routing and complete automated fixtures.
Its theoretical gate excludes physical test status. The shared A10X audio and touch baseline remains required by the project standards.
Use representative available hardware to check assumptions, rather than a universal device-ownership requirement.

This increment closes documented core lifecycle and jog gaps for Hercules Inpulse 200, Inpulse 300 and Starlight.
They select their existing core mappings automatically and send hash-locked startup/shutdown messages to the paired output.
Explicit translations route documented touch and signed relative jog messages through native actions. No upstream script executes.
Unresolved handlers and advanced modes remain listed. These three profiles remain partial theoretical implementations.

Seventeen factory profiles now select core controls automatically. The catalogue still contains 107 data profiles plus seven existing code profiles.
All 43 focused Swift checks and 13 importer checks passed. Simulated MIDI covers startup, Play, touch release and reconnect for all three additions.
Native iPad compilation passed. No app installation or physical-controller test forms part of this increment.
Full theoretical coverage remains unfinished because implementation and complete protocol-fixture gaps remain.
Source: branch `feature/controller-support`, based on `c457916`. Evidence: `TestBuilds/r174/`.

This request first used R174 in isolated commit `682e108`.
Main later allocated R174 to artwork work. This worktree now uses R175 for theoretical support and R176 for club players.
The evidence folders retain their original names.

## R169 complete source catalogue

The [complete catalogue](controller-catalogue.md) covers the published Serato iOS list, every pinned Mixxx definition, all existing NI variants and Beatpad.
The [machine-readable records](controller-catalogue.json) retain source hashes, model roles, connection routes, actions and unresolved input/output rows.
The catalogue is complete for this source boundary. Complete controller support remains a release blocker.

### Implementation and priority

The app bundles 107 bounded data recipes alongside seven existing code profiles.
Fourteen factory profiles select core controls automatically. Existing NI and Beatpad adapters retain their separate connection routes.
Most imported recipes remain partial. They require manual selection while script lifecycle and advanced behaviour remain unresolved.

This batch adds reviewed core profiles for XDJ-RR, OMNIS-DUO, DDJ-GRV6, DDJ-SR and Hercules Inpulse 500.
FLX4, FLX2, XDJ-RR, OMNIS-DUO and GRV6 cover the first five entries in the reviewed regional sales list.
Pioneer/AlphaTheta remains the first brand tier. Other model popularity ranks remain unknown.

| Added profile | Implemented core scope | Remaining scope |
| --- | --- | --- |
| XDJ-RR | Transport, tempo, mixer, cue, jog, browse/load, Hot Cues, loop toggle and supported lights. | Hardware MIDI mode, other pad modes, loop editing, FX, meters, display and audio routing. |
| OMNIS-DUO | Transport, tempo, mixer, cue, jog, browse/load, Hot Cues and Beat Jump. | Hardware Software Control mode, loop editing, FX, shifted modes, display and audio routing. |
| DDJ-GRV6 | Four deck targets, transport, tempo, mixer, cue, jog, browse/load, Hot Cues and supported lights. | Groove Circuit, FX, shifted modes, cue deletion, other pad modes, meters and audio routing. |
| DDJ-SR | Four documented target channels, transport, tempo, mixer, cue, jog, browse/load and Hot Cues. | FX, shifted modes, other pad modes, meters and audio routing. |
| Inpulse 500 | Two decks, mixer, filter, tempo, transport, cue, jog, browse/load, Hot Cues and mode startup/shutdown. | Loop encoder, guides, FX, shifted modes, other pad modes, meters and audio routing. |

The Inpulse 500 uses the maintained note-based jog-touch address, `91/92 08`.
This resolves the conflicting CC row in its printed table without assigning tempo CC `B1/B2 08` to touch.
Its software mode requires a paired physical output. Failed startup leaves the controls inactive.

The R164 FLX4/DDJ-400 Browse encoding was wrong. The factory table specifies `1/127` relative steps.
R169 corrects both profiles and records the focused checks. Jog encoders retain their separate `65/63` encoding.

### Boundaries and verification

The importer never executes downloaded controller JavaScript. Every source input and output row retains a conversion disposition.
It rejects unknown encodings, conflicting addresses and incomplete high-resolution pairs.
It preserves feedback ranges, including reversed LED polarity.
Source locks and [reproduction checks](../../tools/controller_profiles/README.md) prevent silent source drift or missing definitions.

The runtime retains A/B/C/D targets in input state, feedback, learning and reconnection.
Changing A controls or lights preserves C assignments. Startup and shutdown messages use the paired physical output.
The data format bounds file size, profile count, bindings, addresses and mode messages.
No new controller processing enters the audio render callback.

All 42 focused Swift checks, 10 importer checks and native iPad compilation passed before handoff.
The repository check retains 12 existing historical link failures. New-file formatting and prose checks passed.
Native compilation retains existing actor-isolation and weak-capture warnings outside the changed controller files.
Evidence stays in `TestBuilds/r169/`. No signed app, installation or physical-controller acceptance forms part of this work.

The catalogue records 81 models without an implemented protocol in the pinned references and 40 adapter-needed records.
Partial recipes also retain unresolved functions. These gaps block full support, even where core controls select automatically.
Physical identity, audio routes, jog calibration, pad modes, lights, screens, motors and A10X audio/touch require model-specific evidence.
Source-reuse and distribution review remains open. The original Z1 remains the physical acceptance baseline.

## R164 automatic MIDI profiles

This is the first implementation batch towards the 120-device target. It reuses the existing MIDI decoders, action routes and five Pioneer profiles. It adds FLX2 and DDJ-400. The seven profiles below configure controls and status lights automatically. Hardware acceptance remains open.

| Profile | New or reused scope | Automatic audio |
| --- | --- | --- |
| DDJ-FLX4 | Existing transport, mixer, jogs, Hot Cues and lights. Added tempo, filter, browse, load, loop toggle and size, shifted Beat Jump and both Shift buttons. | Main 1–2 and headphones 3–4. |
| DDJ-FLX2 | New profile from the manufacturer's E1 table. Transport, mixer, tempo, filter, jogs, Hot Cues and status lights. | Channel order remains unverified. |
| DDJ-400 | New profile reuses the verified common FLX4 addresses. Its master volume stays in hardware. | Main 1–2 and headphones 3–4. |
| DDJ-REV1 | Reuses the existing two-deck profile and lights. Restores the documented global Shift binding that its existing test expected. | Remains outside the automatic routing table. |
| DDJ-REV5 | Reuses the existing two-deck profile and lights. | Remains outside the automatic routing table. |
| DDJ-1000 | Reuses the existing two-deck profile and lights. | External mixer routing remains outside this change. |
| DDJ-FLX10 | Reuses the existing two-deck profile and lights. | External mixer routing remains outside this change. |

Fresh settings enable MIDI discovery. Known physical devices need no input picker, profile button or feedback switch. Exact model names and known manufacturer prefixes select a profile. Other Mk variants, virtual ports and ambiguous input ports do not activate a guessed profile. Feedback only uses an unambiguous output on the same physical device.

Factory mappings bind to the current endpoints without changing saved learned mappings. Custom mappings and explicit disable choices for known models survive new endpoint IDs. These saved choices apply per model. Two identical models share those choices. Existing source-specific custom mappings take priority.

Known factory MIDI 1.0 devices use the byte input so paired 14-bit CCs retain their original messages. Generic MIDI 2.0 input keeps the existing UMP path. Feedback stays at 30 Hz and sends changed values only. Idle discovery polls at 4 Hz. Connected input retains the existing 120 Hz drain. No controller work enters the audio render callback.

The FLX2, FLX4 and DDJ-400 filter knobs enable the filter away from centre and bypass it at centre. They preserve touch resonance. Browse and load use the existing iPad library command queue. Jog-touch release remains effective after a Shift change. Starts, seeks and jog release continue through the existing transport and Sync rules.

### Sources and priority

The [Coolblue sales list](https://www.coolblue.be/en/dj-controller/top-10) placed FLX4 first and FLX2 second when checked on 11 November 2026. This is a regional sales proxy. It does not establish global installed-base rankings. These models lead this batch. DDJ-400 follows because the documented message family offers direct reuse. The remaining five profiles already existed and migrate together.

- [FLX2 manufacturer MIDI table](https://assets.pioneerdjhub.com/DDJ-FLX2_MIDI_Message_List_E1.pdf), including separate global CFX controls and deck Shift buttons.
- [FLX4 manufacturer MIDI table](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-flx4/ddj-flx4_midi_message_list_e1.pdf).
- Maintained [FLX4](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Pioneer-DDJ-FLX4.midi.xml) and [DDJ-400](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Pioneer-DDJ-400.midi.xml) protocol references. No upstream scripts are bundled or executed.
- Documented audio pairs for [FLX4](https://manual.mixxx.org/2.5/en/hardware/controllers/pioneer_ddj_flx4) and [DDJ-400](https://manual.mixxx.org/2.5/en/hardware/controllers/pioneer_ddj_400).
- [REV1 manufacturer MIDI table](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-rev1/ddj-rev1_midi_message_list_e1.pdf), M11: channel 7, Note 63 for Shift.

### Verification and remaining work

All 34 focused host tests passed. Native iPad compilation passed. The repository check retained 12 existing historical link failures. New-file formatting passed with the requested block-comment style. Evidence stays in `TestBuilds/r164/`, including failed attempts and source hashes. No signed app or device installation forms part of this batch.

Physical MIDI identity, lighting, jog calibration, audio routing, reconnect behaviour and A10X sound and touch remain unverified. Hot Cue pad mode remains required. Other pad modes, complete FX banks, screens, motors and additional deck layers are not added here. The original Z1 remains the physical acceptance baseline.

R169 records the source boundary and core profiles for XDJ-RR, OMNIS-DUO and GRV6. Physical acceptance remains open.

The R169 source catalogue also records the Inpulse 500 jog-touch conflict and its maintained note-based mapping.

The older increment notes below retain their original evidence and limits. Use the later request sections for current implementation state.

## Scope

Cover all NI controllers and class-compliant MIDI controllers, including hardware marketed for Serato, Pioneer DJ/AlphaTheta and other systems. Z1 Mk1 remains first. The Traktor inventory below includes 18 model variants, not the whole expanded scope. NI keyboards/pads and other brands use the shared MIDI layer where their endpoints are reachable, and need verified native adapters for other protocols. See [controller implementation knowledge](controller-research.md) for sources and scope.

| Model family | Variants in scope | Published MIDI-mode position | App state |
| --- | --- | --- | --- |
| S2 | Mk1, Mk2, Mk3 | MIDI mode documented | Mk2 and Mk3 have native iPad mappings. Mk1 has a native HID and audio bridge. |
| S3 | S3 | MIDI mode documented | Native four-deck iPad mapping. |
| S4 | Mk1, Mk2 | MIDI mode documented | Mk2 has a native four-deck iPad mapping. Mk1 uses a native control and audio bridge. |
| S4 | Mk3 | No MIDI mode in NI's supported-mode table | A Linux bridge implementation is available for A10X. See [R123](#r123-s4-mk3-connection). |
| S5, S8 | Both | MIDI mode documented | Native controls, lighting, screen status and split audio through the Linux bridge. |
| X1 | Mk1, Mk2, Mk3 | MIDI mode documented | All three have native bridge adapters. |
| Z1 | Original, Mk2 | MIDI mode documented | The original Z1 has a native iPad mapping. Mk2 has a native HID and audio bridge. |
| F1, D2, Z2 | All three | MIDI mode documented | Native bridge adapters. D2 shows deck status. Z2 uses split audio. |
| MX2 | MX2 | MIDI mode documented | Native control, split audio and lighting through the Linux bridge. |
| DDJ-FLX4 | DDJ-FLX4 | Published MIDI message list | Opt-in profile maps transport, mixer, Hot Cue pads in Hot Cue pad mode, platter jog and touch, and wheel-side temporary rate bend. A separate output profile maps play, sync, headphone-cue and Hot Cue lights. Touch-rate calibration, endpoint access and hardware acceptance remain unverified. |
| DDJ-REV1 | DDJ-REV1 | Published MIDI message list | Opt-in profile maps dual-deck transport, mixer, tempo, loop controls, one momentary Shift layer, Hot Cue pads in Hot Cue mode, platter jog/touch and wheel-side jog. A separate output profile maps play, sync, headphone-cue and Hot Cue lights. Endpoint access and hardware acceptance remain unverified. |
| DDJ-REV5 | DDJ-REV5 | Published MIDI message list | Opt-in two-deck profile maps transport, mixer, tempo, loop controls, one momentary Shift layer, Hot Cue pads in Hot Cue mode, platter jog/touch and wheel-side jog. A separate output profile maps play, sync, headphone-cue and Hot Cue lights. Deck 3/4 controls and other pad modes are not mapped. Endpoint access, calibration and hardware acceptance remain unverified. |
| DDJ-1000 | DDJ-1000 | Published MIDI message list | Opt-in profile maps Deck 1/2 transport, mixer, tempo, four-beat loop, one momentary Shift layer, Hot Cue pads in Hot Cue mode, platter touch/jog and headphone controls. A separate output profile maps play, sync, headphone-cue and Hot Cue lights with one fixed Hot Cue colour. Deck 3/4 and shifted pad pages are not mapped. Endpoint access and hardware acceptance remain unverified. |
| DDJ-FLX10 | DDJ-FLX10 | Published MIDI message list | Opt-in two-deck profile maps transport, mixer, tempo, loop controls, Beat Jump, one momentary Shift layer, Hot Cue pads in Hot Cue mode, platter jog/touch and wheel-side jog. A separate output profile maps play, sync, headphone cue and Hot Cue lights with a fixed Hot Cue colour. Deck 3/4 and stem controls are not mapped. Endpoint access, calibration and hardware acceptance remain unverified. |

Sources: [NI controller setup guide](https://support.native-instruments.com/support/solutions/articles/69000879434-traktor-controller-setup-guide), [NI MIDI-mode guide](https://support.native-instruments.com/support/solutions/articles/69000880031-native-instruments-switching-your-controller-to-midi-mode), [MX2 product details](https://www.native-instruments.com/products/traktor-mx2), [DDJ-1000 MIDI message list](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-1000/ddj-1000_midi_message_list_e1.pdf).

MIDI mode on a computer does not establish a class-compliant iPad MIDI endpoint. NI's original TDJ support list is evidence about its app, not proof that our app has its accessory protocol.

## R100 automatic Traktor setup on iPad

Erik requires automatic connection, controls, audio routing and custom lights. Only the original Z1 is available for physical checks. Record protocol evidence and software checks separately from hardware acceptance.

| Model | Native iPad accessory identifier in TDJ2 | GenErik DJ status |
| --- | --- | --- |
| Z1 Mk1 | `com.native-instruments.traktordj.kontrolz1` | Native controls, automatic audio, blue beat pulse and amber track-end warning. Physical acceptance remains open. |
| S2 Mk1 | No identifier in the preserved TDJ2 build | Linux bridge carries native controls, four-channel audio and custom lighting. See [R126](#r126-s2-mk1). |
| S2 Mk2 | `com.native-instruments.traktordj.kontrols2mk2` | Automatic split audio, native deck and mixer controls, and blue and amber lights on pad 4. See [scope and checks](s2-mk2-native.md). |
| S2 Mk3 | `com.native-instruments.protocol.kontrols2mk3` | Automatic split audio and native deck and mixer controls. Pad 8 shows the blue beat pulse and amber warning. See [scope and checks](s2-mk3-native.md). |
| S3 | `com.native-instruments.protocol.kontrols3` | Automatic split audio, native four-deck controls and blue and amber jog rings. See [scope and checks](s3-native.md). |
| S4 Mk1 | No identifier in the preserved TDJ2 build | Linux CAIAQ bridge carries native four-deck controls, split audio and blue and amber lighting. See [R128](#r128-s4-mk1). |
| S4 Mk2 | `com.native-instruments.traktordj.kontrols4mk2` | Automatic split audio, native four-deck controls and blue and amber Hot Cue lighting. See [scope and checks](s4-mk2-native.md). |
| S4 Mk3 | No identifier in the preserved TDJ2 build | Linux bridge carries four-deck controls, lighting and four-channel audio. Hardware verification remains open. See [R123](#r123-s4-mk3-connection). |
| Z1 Mk2 | No identifier in the preserved TDJ2 build | Linux bridge carries four-deck mixer controls, audio and custom lights. See [R125](#r125-z1-mk2-and-x1-mk3). |
| X1 Mk3 | No identifier in the preserved TDJ2 build | Linux bridge carries four-deck transport, browse, FX and custom lights. See [R125](#r125-z1-mk2-and-x1-mk3). |
| X1 Mk1, X1 Mk2, F1, D2, Z2, S5, S8, MX2 | No identifiers in the preserved TDJ2 build | The app detects each named bridge and loads its factory mapping. See [R137](#r137-remaining-traktor-variants) for scope and open checks. |

The first increment recognises the four named NI audio devices when iPadOS selects them as the sole wired output. It assigns main to channels 1–2 and headphones to 3–4. The audio session checks for four channels before playback. The controller session is separate.

NI lists the four controllers in its [TDJ2 iPad compatibility guide](https://support.native-instruments.com/support/solutions/articles/69000879425-traktor-dj-2-ios-audio-interface-compatibility). The preserved TDJ2 2.4.1 package declares their accessory identifiers. Its audio table initialisation at `0x1003c6738` pairs each exact device name with zero-based output pairs `[0, 1]` and `[2, 3]`, in the same order as the original Z1. The output constants start at `0x1021b9128`, `0x1021b9158`, `0x1021b9188` and `0x1021b91b8` respectively. See [reference provenance](z1-native-accessory.md).

[Build 164](../testing/builds/164.json) installed on the A10X iPad. iPadOS accepted launch. Ten focused tests passed across thirteen cases. The new controller audio profiles have no physical listening result.

The [S2 Mk3](s2-mk3-native.md) and [S3](s3-native.md) adapters use the same beat and warning timing as the Z1.

## R123 S4 Mk3 connection

NI's iOS connectivity table gives the S4 Mk3 no supported iPad connection. The preserved Traktor DJ 2.4.1 app lists the S4 Mk2 accessory protocol and has no Mk3 entry. NI's MIDI-mode table also has no S4 Mk3 entry. USBDriverKit requires an M-series iPad, so it cannot provide raw USB access on the A10X. [NI iOS connectivity](https://support.native-instruments.com/support/solutions/articles/69000879456-how-to-connect-your-ni-controller-audio-interface-to-an-ios-device) · [NI MIDI-mode table](https://support.native-instruments.com/support/solutions/articles/69000880031-native-instruments-switching-your-controller-to-midi-mode) · [Apple USBDriverKit](https://developer.apple.com/documentation/usbdriverkit)

Mixxx uses the vendor HID interface `17cc:1720`, interface `03`, for input and LED output. Its desktop audio mapping assigns master to channels 1–2 and headphones to 3–4. These mappings require a connection that exposes the controls and audio to the app. [Mixxx HID preset](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor%20Kontrol%20S4%20MK3.hid.xml) · [Mixxx audio mapping](https://manual.mixxx.org/2.5/en/hardware/controllers/native_instruments_traktor_kontrol_s4_mk3)

The S4 Mk3 bridge keeps the controller in HID mode. It presents USB MIDI and four-channel USB Audio to the iPad. GenErik DJ detects the bridge automatically. The mapping covers four-deck playback, mixer controls, browse and load, Preview, jog touch, loops, Hot Cues, samples, Grid and two FX units. The jog rings use the shared blue beat pulse and amber warning. Motors, displays and capture remain open. [Bridge setup and verification limits](../../tools/controller_bridge/README.md#s4-mk3-audio-and-control-bridge)

The separate M-series DriverKit scheme adds a direct USB transport for the same app mapping. It needs a signed driver and hardware verification. [DriverKit build and verification](s4-mk3-driverkit.md)

Twenty-two focused Swift tests and thirteen bridge tests passed. Build 186 passed local iOS signing and runtime checks. The physical bridge and iPad were outside this verification. [Build record](../testing/builds/186.json)

## R125 Z1 Mk2 and X1 Mk3

Both models use their documented native HID reports through the Linux bridge. The app connects automatically when the matching bridge appears. The Z1 Mk2 bridge also supplies four audio channels. GenErik DJ assigns master to 1–2 and headphones to 3–4. The audio route also recognises the Z1 Mk2 when iPadOS exposes its wired audio output directly. Direct USB audio does not provide native HID controls. [Bridge setup](../../tools/controller_bridge/README.md#z1-mk2-and-x1-mk3-bridges) · [Z1 Mk2 audio specifications](https://www.native-instruments.com/products/traktor-z1)

- **Z1 Mk2.** A/B and C/D mixer layers, gain, EQ, channel faders, crossfader, headphone cue and blend, mixer FX and level meters. The Z1 controls its own master and headphone volume when it supplies the audio output. GenErik DJ uses filter and four mixer FX presets. The app does not map Stem mode or the OLED displays. [NI control guide](https://docs.native-instruments.com/online-guides/traktor-z1-mk2-manual/en/using-the-z1-with-traktor) · [HID report map](https://github.com/infifox/mixxx-traktor-controllers/blob/a9e8f8ea8adbed29c4d86d224049990ec8ba21ca/doc/TraktorZ1MK2.spec.md)
- **X1 Mk3.** Menu switches between A/B and C/D. The two sides map transport, held Cue, nudge, reverse, Hot Cues, loops, browse, load and FX groups. Shift turns browse into group navigation and selects the mapped secondary transport actions. Displays, mixer mode and Pattern Player remain open. The X1 Mk3 has no audio interface. [NI hardware guide](https://docs.native-instruments.com/online-guides/traktor-x1-mk3-manual/en/hardware-overview) · [HID report map](https://github.com/infifox/mixxx-traktor-controllers/blob/36dc56869f3ad681e9b12f10f3dd15d0c4d540e6/doc/TraktorX1MK3.spec.md)

The bottom LEDs on both models use the shared blue beat pulse and amber track-end warning. Local checks cover report decoding, deck changes, light values, gadget creation and selection of the split audio route. Physical controller behaviour, bridge audio and A10X performance remain open. These models are outside the S4 Mk3 DriverKit entitlement request.

Thirty-five focused Swift tests and sixteen bridge tests passed. [Build 187](../testing/builds/187.json) passed local signing and runtime framework checks. Verification stayed off the iPad. The build history retains the failed local attempts.

The remaining Traktor models without a factory adapter are S5, S8, X1 Mk1, X1 Mk2, F1, D2, Z2 and MX2. Mixxx has HID mappings for F1 and MX2. Encdr has hardware references for X1 Mk1, X1 Mk2, S5, S8, D2 and Z2. [Mixxx controller mappings](https://github.com/mixxxdj/mixxx/tree/main/res/controllers) · [Encdr hardware references](https://github.com/RufusIbiza/Encdr/tree/a5414658a69c4330d10b95f2359371dfc8550326/docs/hardware)

## R126 S2 Mk1

The Linux bridge uses HID interface 03 on USB device `17cc:1101`. It reads the button, analogue and factory calibration reports. The app detects the bridge and selects master 1–2 and headphones 3–4. The controller mixes its microphone into the physical output. The bridge sends no microphone audio to the app. [Bridge setup](../../tools/controller_bridge/README.md#s2-mk1-bridge) · [Mixxx report map](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-Kontrol-S2-MK1-hid-scripts.js) · [Audio routing](https://manual.mixxx.org/2.5/en/hardware/controllers/native_instruments_traktor_kontrol_s2_mk1.html#audio-routing)

The mapping covers A/B transport, held Cue, jog scratch and rim nudge, browse and load, loop in and out, loop move and size, Hot Cues, samples, tempo lock, mixer controls and FX groups. GenErik DJ keeps its saved Sync behaviour. Shift+GAIN adjusts the app filter. See [R127](#r127-s2-mk1-shift-and-loop-controls) for deck cloning, loop trimming and crossfader assignment. [Native Instruments S2 Mk1 manual](https://images-eu.ssl-images-amazon.com/images/I/C1z6RGpnVTS.pdf)

Pad 4 on each deck shows the blue beat pulse. The separate amber Alert lamp shows the track-end warning for either deck. The pads have blue and green emitters. Pad feedback restores the stored cue, loop or sample colour after the beat pulse. [Hardware report reference](https://github.com/RufusIbiza/Encdr/blob/a5414658a69c4330d10b95f2359371dfc8550326/docs/hardware/ni_kontrol_s2_mk1.md)

Twenty-four focused Swift tests and seventeen bridge tests passed. [Build 188](../testing/builds/188.json) passed local signing and runtime framework checks. Verification stayed off the iPad. Physical controls, lighting, audio and bridge latency remain unverified.

## R127 S2 Mk1 Shift and loop controls

- **Shift+Load A/B** copies the opposite deck's track and its playhead position at the time of the press. The destination must be stopped and stays ready to play with its own saved Sync setting. A streamed clone uses an independent decoder or read-ahead buffer.
- **Loop In or Out + jog** moves only the held edge of an active loop. The app combines jog ticks in each poll and keeps the edges inside the track. The transport still applies Sync. Stored cues and loops retain their saved positions.
- **Shift+FX 1/2** assigns the channel to the left or right crossfader side. Press the same side again to unlink the channel. The FX buttons show that assignment while Shift is held. The audio engine smooths the change and keeps headphone cue independent. Recovery auto-mix requires the default left and right assignments.

The bridge uses the same reports. GenErik DJ requires no settings for these controls. [NI S2 Mk1 manual](https://images-eu.ssl-images-amazon.com/images/I/C1z6RGpnVTS.pdf) · [NI deck duplication reference](https://docs.native-instruments.com/ni-tech-manuals/traktor-pro-manual/en/preferences)

Twenty-six focused Swift tests and seventeen bridge tests passed. [Build 189](../testing/builds/189.json) passed local signing and runtime framework checks. Verification stayed off the iPad. Physical operation remains unverified.

## R128 S4 Mk1

The S4 Mk1 (USB `17cc:baff`) uses Native Instruments' CAIAQ USB protocol. The Linux kernel driver supplies native controls, LED brightness and four-channel playback. GenErik DJ detects the named [S4 Mk1 bridge](../../tools/controller_bridge/README.md#s4-mk1-bridge) and selects master 1–2 and headphones 3–4. [Linux input driver](https://github.com/torvalds/linux/blob/master/sound/usb/caiaq/input.c) · [Linux LED driver](https://github.com/torvalds/linux/blob/master/sound/usb/caiaq/control.c) · [Linux audio driver](https://github.com/torvalds/linux/blob/master/sound/usb/caiaq/audio.c)

The mapping includes A/C and B/D deck layers, fixed A–D mixer channels, transport, held Cue, Sync, keylock, jog scratch and rim nudge, browse and load, headphone preview and seek, Shift+Load, Hot Cues, sample pads, loop in and out, loop size, Move, tempo pickup and lock, Snap, Quantize and two FX units. Shift+FX assigns the mixer channel to either crossfader side. The loop display and channel meters follow the app. [NI S4 Mk1 manual](https://manualzz.com/doc/22304763/native-instruments-traktor-kontrol-s4-manual) · [Backspn mapping](https://github.com/suitux/Backspn/blob/71668201f3d0ff6658cfd72fb5386dba9ebb789f/crates/control/src/kontrol/s4mk1.rs)

Pad 4 on each selected deck shows the blue beat pulse. The shared amber Alert lamp follows the track-end warning for all four playing decks. The pad returns to its stored Hot Cue or loop colour between pulses.

Thirty-six focused Swift tests and nineteen bridge tests passed. [Build 191](../testing/builds/191.json) passed local signing and framework checks. The first compile of build 190 caught a missing tempo feedback value. Its log is in `TestBuilds/r128/build-190-first-attempt.log`. The corrected [build 190](../testing/builds/190.json) passed before the Browse preview change. All checks stayed off the iPad.

R134 adds the Loop Recorder, footswitch, FX Mode, clock master, jog loop trimming, Browse and Copy controls, and audio capture. See [R134](#r134-s4-mk1-remaining-controls).

## R134 S4 Mk1 remaining controls

- **Loop Recorder.** SIZE cycles through 4, 8, 16 and 32 beats. REC and the footswitch use the same record or overdub action. Initial capture starts at the next master beat. PLAY starts or stops playback. UNDO deletes a stopped loop or toggles the most recent overdub. DRY/WET blends the recorded loop with the live master mix.
- **FX.** MODE switches each unit between Single and Group. Shift+MODE saves the Single effect's parameter defaults for the current connection. Shift+FX buttons select effects. The app uses its own effect parameters in both modes.
- **Clock.** MASTER selects the internal clock. Shift+SYNC selects a deck with a beat grid as the tempo reference. The app preserves each deck's saved Sync choice and preserves clock phase while another synced deck is active.
- **Loop trim.** Hold LOOP IN or LOOP OUT and turn the jog wheel during an active loop. The app adjusts only the selected edge. It keeps the loop within the track.
- **Browse and Copy.** Tap BROWSE to toggle Browse mode. Mixer CUE loads tracks. Sample Play loads samples. Hold BROWSE and select a source and target to copy a track between decks or a sample between pads. Loop Recorder PLAY selects the recorded loop as a copy source. The pad plays the copy as a one-shot sample.
- **Audio.** The bridge returns four input channels. Inputs 1–2 feed the empty C mixer channel. Inputs 3–4 feed stereo AUX, and MIC VOL controls that pair. The controller switches inputs 3–4 to the microphone when it is plugged in. The system may ask for microphone permission.

Fifty-one focused Swift tests and twenty bridge tests passed on the source for [build 195](../testing/builds/195.json). The build passed local signing and framework checks. [Build 194](../testing/builds/194.json) passed those checks before Loop Recorder copy was added. All checks stayed off the iPad. Logs are in `TestBuilds/r134/`.

The Loop Recorder uses Main as its fixed source. Alternate Loop Recorder sources remain open. Physical checks remain open for both playback and capture channel order, latency, drift, control feel and reconnect behavior. [NI S4 Mk1 manual](https://manualzz.com/doc/22304763/native-instruments-traktor-kontrol-s4-manual) · [Linux CAIAQ audio driver](https://github.com/torvalds/linux/blob/master/sound/usb/caiaq/audio.c)

## Required capabilities for each model

Track these separately. None is implied by a name appearing in this table:

1. Connection: the iPad receives the controller through Core MIDI, a verified accessory protocol or an implemented bridge.
2. Input: buttons, modifiers, faders, encoders, jogs and touch contacts have verified decoding and mappings.
3. Behaviour: held controls, takeover, deck assignment and touch/hardware coexistence work correctly.
4. Feedback: lights, meters, displays and motor/haptic features have implemented output where the hardware supports them.
5. Audio: available master/headphone channels, routing, rates and disconnect behaviour work on the actual setup.
6. Acceptance: Erik has checked the available hardware. Unowned models retain explicit hardware-verification gaps.

## Connection architecture

The app uses one controller action route into the existing touch playback/mixer commands. Core MIDI input is opt-in. Multiple sources can stay active while the user selects one source for Learn or a model profile. Mappings and decoder state are scoped to each input and UMP group. Each input has one momentary Shift layer. The generic path maps MIDI 1.0 and MIDI 2.0 channel voice messages. It keeps 16-bit note velocity and 32-bit control, pressure, pitch and parameter values through the action path. It also maps MIDI 2.0 registered and assignable controllers, their relative forms, per-note registered and assignable controllers, and per-note pitch bend. Parameter and per-note mappings retain their identifiers. MIDI 1.0 sources are converted by Core MIDI to UMP. The Z1 SysEx bridge uses its separate legacy byte input. Unmapped UMP message types, including per-note management, are ignored. Input buffering is bounded. The receive path does not run new work in the audio render callback. Absolute continuous controls use soft takeover: input waits until it reaches the current app value within 0.02 normalized units or crosses it. Buttons and jog controls remain immediate. Generic MIDI feedback is opt-in and uses MIDI 1.0 output. Each output destination has its own mappings. The user selects each action's channel, number and button values. DDJ-FLX4, DDJ-REV1, DDJ-REV5, DDJ-1000 and DDJ-FLX10 play, sync, headphone-cue and Hot Cue lights have separate optional profiles. Other model feedback profiles are not implied.

The first increment covers note buttons, absolute control changes and pitch-bend values. The expanded increment adds paired-14-bit CCs, three relative encodings, reversed direction, pressure/program inputs, soft takeover and more existing deck actions. A development Z1 bridge route carries native input, calibration and light/meter feedback. User-configured generic feedback can send note and Control Change states to a selected MIDI destination. One momentary Shift layer per input can select alternate learned mappings. Multiple MIDI inputs can stay active together. Opt-in DDJ-FLX4, DDJ-REV1, DDJ-REV5, DDJ-1000 and DDJ-FLX10 profiles map published two-deck transport, mixer, Hot Cue, jog and touch messages. The FLX4 wheel-side jog applies a temporary rate bend of up to eight percent and returns to normal after 150 ms without input. The REV1 profile maps published loop controls and its second wheel-side jog message. The REV5 profile maps published loop controls and paired high-resolution mixer controls. The DDJ-1000 profile maps its published paired high-resolution mixer/tempo controls and four-beat loop. The FLX10 profile maps published loop controls, Beat Jump and paired high-resolution mixer and tempo controls. Separate profiles map play, sync, headphone-cue and Hot Cue light states for FLX4, REV1, REV5, DDJ-1000 and FLX10. The FLX10 Hot Cue profile uses one fixed colour. Touch-rate calibration, model-specific modifiers, other native model adapters and physical acceptance remain unfinished. This does not complete support for every model.

Where direct transport is unavailable, the allowed bridge acts as USB host for the controller and presents an iPad-accessible connection. The first Linux Z1 relay, matching app framing and opt-in configfs MIDI gadget helper are implemented under `tools/controller_bridge/`. The helper requires Linux bridge hardware and USB IDs assigned to that bridge. Other model adapters, bridge audio, and physical testing remain open. The relay does not forward audio. A generic MIDI cable alone cannot turn proprietary USB traffic into a MIDI controller.

Apple restricts iPadOS DriverKit to M-series devices. The A10X cannot use that route. See [Apple's driver documentation](https://developer.apple.com/documentation/driverkit/creating-drivers-for-ipados). The app will not label inaccessible raw USB hardware as supported.

## Z1 next test

Prepared build 49 introduced **Settings → Controllers**. The expanded candidate adds the bridge and value modes described above. Connect the Z1 with its required power/cable. Enable controller input and inspect the source list. The page separately shows accessory and audio connections and can share those details. Use generic Learn for a real MIDI endpoint. Use the explicit GenErik bridge mode only with the matching relay, input and feedback output. Direct native accessory communication remains unimplemented. Do not invent a MIDI source or protocol identifier.

The original Z1's native report decoder and Mac HID implementation remain preserved. They establish useful protocol groundwork, not A10X transport support. No Mac app development or testing is resumed by this controller work.

## R137 remaining Traktor variants

These factory adapters cover the eight remaining Traktor models in the 18-model inventory. The app detects the Linux bridge by its MIDI device name. It needs no MIDI Learn or app setting. The bridge requires its own setup. [Setup](../../tools/controller_bridge/README.md#x1-mk1-x1-mk2-f1-d2-z2-s5-s8-and-mx2)

| Models | Mapped functions | Lighting and output |
| --- | --- | --- |
| X1 Mk1 and X1 Mk2 | A/B transport, held Cue, Sync, browse and load, loops, Hot Cues and two FX units. Mk2 also maps the touch strip. | Mk1 uses fixed-colour lamps for the beat and warning. Mk2 uses the two-colour strip. |
| F1 | Sixteen sample cells, column stop, browse, Sync and Quantize. | Sample pads show state. Pad 16 shows the blue beat and amber warning for deck C. |
| D2 | Selectable deck, transport, browse and load, loops, pads, touch strip, Grid and FX. | Touch-strip lights show blue and amber. The screen shows deck and track status. |
| Z2 | Four-deck mixer, deck selection, Hot Cues, Sync, browse and load, loop size displays, FX and cue mix. | RGB pad lighting, channel meters and split audio. |
| S5 and S8 | Four-deck mixing, two deck surfaces, browse and load, loops, pads, FX and touch strips. S8 also maps mixer switches and Grid. | Channel meters, blue and amber strips, split audio and deck status on both screens. |
| MX2 | Two-deck transport, jog and touch, browse and load, headphone Preview, loop rolls, Hot Cues, mixer and FX. | Blue and amber light strips, channel meters and split audio. |

For Z2, S5, S8 and MX2, the gadget presents master on 1–2 and headphones on 3–4. The relay sends these four channels to the controller's ALSA playback device. NI documents headphones on channels 3–4 for its integrated Traktor interfaces. Check the physical output order, latency and reconnect behavior before live use. No physical controller or bridge was available for R137. [NI channel routing](https://support.native-instruments.com/support/solutions/articles/69000879976-using-a-native-instruments-audio-interface-as-system-audio-output).

Open functions include full Remix Deck editing and F1 per-slot faders and filters, stems and Pattern Player, Z2 timecode and analogue capture, and MX2/S8 microphone capture. The colour panels show title, time, BPM and playback state. Waveforms and the controller's on-screen browser remain open. The existing S4 Mk3 motor, display and capture limits still apply to R137. See [R138](#r138-ni-performance-features) for later changes.


Eleven focused Swift tests and 23 bridge tests passed on the source for [build 200](../testing/builds/200.json). A host check rendered a colour panel with a non-ASCII track title. The signed build passed the runtime framework check. Builds [198](../testing/builds/198.json) and [199](../testing/builds/199.json) record earlier candidates. All R137 checks stayed off the iPad. Logs are in `TestBuilds/r137/`.

Sources. [NI older manuals](https://support.native-instruments.com/support/solutions/articles/69000879398-traktor-manuals-for-older-devices) · [X1 Mk1 USB mapping](https://github.com/Opa-/x1-mk1-usb2midi/blob/main/board.yml) · [Backspn report layouts](https://github.com/suitux/Backspn/tree/e0244b9c3ef16409d8c26fa2d27af3b7156204c5/crates/control/src/kontrol) · [Backspn screen protocol](https://github.com/suitux/Backspn/blob/e0244b9c3ef16409d8c26fa2d27af3b7156204c5/crates/control/src/s4mk3/screen.rs) · [Encdr endpoint descriptors](https://github.com/RufusIbiza/Encdr/tree/a5414658a69c4330d10b95f2359371dfc8550326/encdr/descriptors) · [Mixxx MX2 mapping](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-MX2-hid-scripts.js).

## R138 NI performance features

GenErik selects these mappings automatically on a matching bridge. The new capture routes need an updated gadget and iPadOS microphone permission. No controller setup is required in the app.

| Feature | Implemented scope |
| --- | --- |
| Stems | Load a five-track `.stem.mp4` with an authored master and four aligned parts. D2 and S8 use their performance faders and filter controls. F1 uses its faders, filter knobs and Stop row. S5 and MX2 use held pads and encoders. S4 Mk3 uses its dedicated STEMS and MUTE buttons, pads, and MOVE and LOOP encoders. |
| Pattern Player | MX2 and X1 Mk3 use the FX buttons, knobs and deck assignments. MX2 edits 16 steps over two pad pages. Two built-in kits use synthesized drum sounds. The engine triggers notes on its beat clock. |
| Z2 timecode | REL/INT toggles relative control on A or B. It uses the Mk2 stereo carrier for speed and direction. It holds the playhead on signal loss and keeps the deck’s saved Sync choice. |
| Audio inputs | Z2 routes mic/AUX to master and line inputs to empty A/B mixer channels. S8 maps the C/D pairs, including the hardware mic assignments. MX2 MIC routes its microphone to master. |
| Screens | D2, S5, S8 and the Linux S4 Mk3 bridge show the track overview waveform and playhead. Browse shows four rows and the current selection from the app. |

Stem preparation stops if a deck becomes active. It accepts one master and four mono or stereo tracks with matching sample rates and aligned starts. It limits the five decoded streams to a total of 480 MiB per Stem file. The app plays the authored master at the default settings and mixes the four parts when a control changes.

Absolute Z2 needle-drop position, real-vinyl calibration, source separation, stem FX sends, Z1 Mk2 stem controls, NI kit import, the X1 Mk3 pattern display, additional S8 inputs, S4 Mk3 audio capture and direct DriverKit displays remain open. S5 AUX stays on the hardware mix path. Physical routing, control response, screen behavior and A10X performance remain unverified.

[Build 203](../testing/builds/203.json) passed local signing and runtime checks. Twenty-four focused Swift tests and 25 bridge tests passed on its source. The host tests opened a synthetic five-track AAC file, exercised Pattern Player timing, and checked carrier tracking and input isolation. A host smoke test rendered both screen views. All checks stayed off the iPad. Logs and the synthetic file are in `TestBuilds/r138/`.

[NI Stem controls](https://support.native-instruments.com/support/solutions/articles/69000879536-how-can-i-control-the-individual-stems-on-a-traktor-stem-deck-) · [NI S5 manual](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/TRAKTOR_KONTROL_S5_Manual_English.pdf) · [NI X1 Mk3 Pattern Player](https://docs.native-instruments.com/ni-tech-manuals/traktor-x1-mk3-manual/en/using-the-pattern-player) · [NI MX2 controls](https://docs.native-instruments.com/online-guides/traktor-mx2-user-guide/en/traktor-mx2-overview) · [NI Z2 USB routing](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/traktor_kontrol_z2_manual_english.pdf) · [Mixxx Mk2 carrier analysis](https://mixxx.org/news/2025-08-27-dvs-internals-pt3/).

## R141 Z2 needle drops and controller settings

REL/INT selects absolute vinyl control on Z2 decks A and B. Both sides of Traktor Scratch Mk2 control vinyl use 2,500 position symbols per second. The app checks the 110-bit code before it moves the deck to the needle position. The decoder loads a sparse index before it opens capture. When the needle leaves the record, the deck holds its position. Returning to internal playback releases vinyl control and keeps the deck's saved Sync choice. Use the existing Z2 bridge and audio route. [Mixxx Mk2 decoder](https://github.com/mixxxdj/mixxx/pull/14569) · [Z2 manual](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/traktor/traktor_kontrol_z2_manual_english.pdf).

Controller settings show Pulse and Warning for each connected controller with native feedback. Both settings are on by default. The app saves them separately for each model. MIDI setup stays in a collapsed section. The pane omits connection diagnostics.

The focused Mac checks passed with synthetic Mk2 vinyl, capture routing and lighting reports. [Build 207](../testing/builds/207.json) passed signing and runtime checks. The tool rejected [build 206](../testing/builds/206.json) after the source changed during compilation. Real-vinyl calibration, physical controllers and A10X performance remain open.

## R147 Native stem controls and FX sends

The controls work with authored `.stem.mp4` files. The app uses the existing accessory and bridge connections. It needs no MIDI mapping or app setting.

| Controller | Stem controls |
| --- | --- |
| Z1 Mk2 | Each side has its own EQ and Stem buttons. Gain, High, Mid and Low control drums, bass, other and vocals in Stem mode. Knobs use pickup when you change mode, deck layer or stem track. |
| S2 Mk3 and S3 | Press Samples on a stem deck. Pads 1–4 mute stems. Hold pads 5–8 and turn Move for volume or Loop for filter. Press Hotcue to return to cues. |
| S4 Mk3 | Pads 1–4 mute stems directly in Stem mode. Pads 5–8 keep the existing volume and filter controls. |
| X1 Mk3 | Shift and number buttons 1–4 mute stems on a stem deck. An unshifted press keeps the Hot Cue action. |
| S8 and D2 | The Performance arrows select Filter or FX Send. The four ON buttons switch the selected function. The knobs change filter or send amount. |
| S5 | Loading stems opens Stem mode. The lower pads select stems. Hold Shift and press an upper pad to switch its FX send. Shift and a lower pad reset volume and filter. |
| F1 | Hold Shift and turn Browse to select a deck. Hold Shift and use the second row of pads to switch individual FX sends. |

Each send starts at full level. A send can bypass the deck FX chain while its stem stays audible through the channel EQ, fader and cue. The renderer allocates the extra processor before stem playback. It uses the original single path for ordinary tracks and when no split is needed.

[NI Z1 Mk2 controls](https://docs.native-instruments.com/ni-tech-manuals/traktor-z1-mk2-manual/en/using-the-z1-with-traktor) · [Z1 Mk2 HID reports](https://github.com/infifox/mixxx-traktor-controllers/blob/a9e8f8ea8adbed29c4d86d224049990ec8ba21ca/doc/TraktorZ1MK2.spec.md) · [NI stem controller guide](https://www.native-instruments.com/blogs/blog/how-to-mix-stems) · [NI S8, D2 and F1 stem controls](https://support.native-instruments.com/support/solutions/articles/69000879536-how-can-i-control-the-individual-stems-on-a-traktor-stem-deck-) · [NI S5 manual](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/TRAKTOR_KONTROL_S5_Manual_English.pdf).

The Mac checks passed for native reports, dry and partial sends, track changes and Key Lock at 85% tempo. The optional real-file fixture did not run. [Build 210](../testing/builds/210.json) passed runtime and signing checks. The tool rejected [build 209](../testing/builds/209.json) after the source changed during compilation. Hardware and A10X performance checks remain open.

## R149 NI Pattern Player kits and X1 Mk3 displays

The exporter reads factory one-shots and preset beat positions from a local Apple Silicon Traktor Pro 4 app. The signed Traktor Pro 4.0.0 package exposed 16 kits, with eight sounds and eight presets per sound. The repository contains no NI audio. [NI Pattern Player guide](https://www.native-instruments.com/blogs/blog/pattern-player-traktor-pro).

1. On the Mac, run the exporter with the path to your local Traktor Pro 4 app.

   ```sh
   python3 tools/pattern_kits/export_traktor.py "/path/to/Traktor Pro 4.app" "$HOME/Desktop/NI-Pattern-Kits.json"
   ```

2. Copy the exported file to Files on your playback device.
3. Connect the X1 Mk3 or MX2 with its existing bridge.
4. Pause the decks.
5. Open Controllers and select **Import Pattern Kits…**.
6. Select the exported JSON file.
7. Select Pattern Player on the controller.
8. Hold Shift and press FX button 2 or 3 to select a kit.

The app saves imported kits and adds them to the existing kit selector. It keeps the original preset timing, including hits between steps. Editing the MX2 pads switches that pattern to the 16-step grid. The two X1 Mk3 FX OLEDs show the kit, sample and pattern, with a cursor while the clock runs. The app sends display updates through the existing bridge. [NI X1 Mk3 controls](https://docs.native-instruments.com/ni-tech-manuals/traktor-x1-mk3-manual/en/using-the-pattern-player) · [OLED report layout](https://github.com/RufusIbiza/Encdr/blob/main/docs/hardware/ni_kontrol_x1_mk3.md).

The off-device checks exported 16 kits from the signed Traktor Pro 4.0.0 installer. The app imported and reopened the library, skipped duplicate kits and played the exported 808 kick. The synthetic timing check retained an off-grid hit. The bridge tests checked the OLED report IDs, length, pattern bits and cursor. [Build 212](../testing/builds/212.json) passed signing and runtime checks. Physical OLED response and A10X performance remain open.

## R249 Compact factory volume and accelerated Shift tempo

The Compact recipe follows the [factory MIDI table](https://ts.hercules.com/download/sound/manuals/DJC_Compact/DJC_Compact_MIDI_Mapping.pdf) and pinned Mixxx source.
Factory VOL controls deck level, correcting the old source's pregain choice. Mid and Low retain the physical two-band layout.
Normal jogs use native wheel nudge and paused seek. Shift jog preserves the source's signed-square tempo response and rate polarity.
A factory-only codec rejects other message kinds. Zero steps preserve saved tempo.
The source state query corrupts pitch and then resets both decks. Native startup omits that query and retains pickup.
Cue release aliases cover hardware Shift changes. Distinct cue/loop addresses keep FX, samples and unsupported shifted presses inactive.
The four-cue page, eight-beat loop, reloop and half/double use reviewed addresses.
Play/Sync feedback uses both normal/shift factory LED addresses. Lifecycle clear covers only these and known Auto/Record indicators.

All 36 focused Swift checks, 82 importer checks and native iPad framework compilation pass.
All 164 other recipes remain unchanged. The bundled iPad resource matches the source.
The catalogue has 114 automatic factory profiles for 120 physical models, plus six other automatic native models.
The pinned benchmark remains 62/122 models. Automatic core coverage does not establish complete feature parity.
Repository checks retain twelve existing historical-link failures.
Synthetic scratch, shifted start/stop, held cue previews, recording, AutoDJ, FX/samples, rolls, pad feedback and full cleanup remain open.
Factory EQ direction wording needs calibration. No hardware test, signed app or installation occurred.
Exact logs, source hashes and factory PDF are in ignored `TestBuilds/r249/validation.json`.

## R250 BCD3000 standard-mode core and BCD2000 connection audit

The BCD3000 recipe uses the [factory manual](https://img.musicworld.bg/pdf/i/6/0/2/20206/BCD3000_Manual_EN.pdf), pages 13–15.
Standard-mode buttons use Note On/Off. Factory LED feedback uses distinct CC addresses, including PFL A2/B1 and Play A18/B10.
Startup clears documented LEDs1–25, enables factory wheel acceleration and requests analogue values only.
Native wheel control retains the source 100-count scale. Held bend uses the existing owned four-percent rate.
SET CUE stays separate from held CUE preview. Native reloop has factory loop feedback.
DATA4 is not Master/Balance, so the old source assignment at CC16 stays unmapped.
The documented standard/Core Audio layout selects master1/2 and headphones3/4 through the existing route.
Windows Advanced toggle mode is outside this recipe. No fabricated touch or source latched scratch runs in the app.

BCD2000 remains separate. Its [driver source](https://github.com/anyc/snd-bcd2000) documents a non-class-compliant USB path.
The catalogue now states that a separate driver or MIDI bridge is required. No BCD2000 automatic support is claimed.
This audit does not implement that bridge or recommend replacement firmware.

All 37 focused Swift checks, 83 importer checks and native iPad framework compilation pass.
All 164 other recipes remain unchanged. The bundled iPad resource matches the source.
The catalogue now has 115 automatic factory profiles for 121 physical models, plus six other native models.
Benchmark coverage remains 62/122. Core counts do not establish complete feature parity.
Repository checks retain twelve existing historical-link failures.
Set Loop hold/release, Search, EQ kill, common Key, FX, latched scratch, full feedback/passthrough, calibration and physical acceptance remain open.
No hardware test, signed app or installation occurred. Exact logs and source hashes are in ignored `TestBuilds/r250/validation.json`.

## R251 Original DJ2GO factory core and owned Cue feedback

The original DJ2GO recipe uses Numark's [Rev B MIDI specification](https://www.numark.com/images/product_downloads/dj2go___software_definition_and_midi_spec_v1.0.pdf).
Factory signed jog/browse magnitudes replace the source's direction-only handling. Zero means stationary.
Native wheel nudge/paused seek uses the source's 60 physical counts. Its synthetic scratch timer and custom 85RPM response stay unmapped.
Direct Load acts on press. Physical pitch buttons use owned held bend, rather than the source's extra loop layer.
Pitch retains the physical centre detent and native pickup. Deck volume, crossfader, Master and Headphone gain use factory addresses.
Native Back selects the previous library group. Enter uses Open Group. Full folder hierarchy semantics remain open.
No audio interface or extra setup is invented. DJ2GO2 and Touch keep their separate identities.

All eight factory LEDs have native outputs. Cue preview feedback checks the owned contact, current generation and active touch.
It stays independent of headphone PFL. A real native-audio fixture verifies hold/release, stale-generation rejection and saved Sync.
Source exclusive-PFL, alternate layers and timer-driven flashes stay open.

All 43 focused Swift checks, 84 importer checks and native iPad framework compilation pass.
All 164 other recipes remain unchanged. The bundled iPad resource matches the source.
Automatic core coverage is now 116 factory profiles for 122 physical models, plus six other native models.
Benchmark coverage remains 62/122. This is not complete feature parity or hardware acceptance.
Repository checks retain twelve existing historical-link failures.
No signed app or installation occurred. Exact logs, source hashes and factory PDF are in ignored `TestBuilds/r251/validation.json`.

## R252 Original AIR factory pitch, pressure jogs and hardware gain

The AIR recipe follows the [factory reference manual](https://ts.hercules.com/download/sound/manuals/DJ_AIR/DJUCED/DJUCED_Manual_v1_ENG.pdf), pages 28, 30 and 49–53.
Its pitch fader sends eight bits. CC52/88 and53/89 use a seven-bit high value and a Boolean low bit.
Fresh pairs map the full 0–255 travel. Any nonzero low report means one bit. Native pickup and source rate polarity remain intact.
Factory signed jog magnitudes replace the script's direction-only treatment. Pressure motion requires full-value contact and retains the source 128-count scale.
Native fixed pressure scratch and normal wheels remain separate. The Scratch toggle and source alternate behaviour stay open.
Physical pitch buttons use native held bend. Loop pad pressure changes do not retrigger an active press.
The manual loop page retains In/Out/Double/Reloop. Distinct FX/sample addresses stay inactive.

Factory all-LED clear replaces the source's empty startup loop and undefined shutdown call.
Transport/PFL/Cue feedback uses factory addresses. Full pad/beat animation and Magic functions stay open.
The headphone volume buttons change the hardware preamp. They receive no second software gain change.
The documented master1/2/headphones3/4 layout uses existing native routing and sample/recovery checks.
Headphone Cue/Mix selection, factory EQ direction calibration and AIR Plus remain separate/open.

All 38 focused Swift checks, 85 importer checks and native iPad framework compilation pass.
All 164 other recipes remain unchanged. The bundled iPad resource matches the source.
Automatic core coverage is now 117 factory profiles for 123 physical models, plus six other native models.
Benchmark coverage remains 62/122. Core counts do not establish complete feature parity.
Repository checks retain twelve existing historical-link failures. No physical test, signed app or installation occurred.
Exact logs, source hashes and factory PDF are in ignored `TestBuilds/r252/validation.json`.

## R253 SC2000 factory channels and source-local Shift

The SC2000 recipe follows Denon's [factory MIDI tables](https://cdn.inmusicbrands.com/denondj/legacy/dnsc2000/DN-SC2000_ownersmanual.pdf).
CH1/2 target A/B. CH3/4 target C/D through the existing app opt-in. CH5–8 do not gain inferred deck targets.
Factory contact value64, centre64 jogs, 2,048 counts and full pitch messages use existing native contracts.
Physical Shift uses one source-local input across all eight wire channels. Its release survives a deck/channel change.
Note3 bank reports release held contacts and rearm pickup across native targets. They preserve physical Shift.
Shift blocks unsupported new actions and motion, while old contact/Cue/bend releases remain valid.
The native layout keeps eight cues, manual In/Out, Auto Loop, beat-size buttons, filter encoder and direct Load.
Filter follows the factory label, instead of the source's loop-size customisation.

LEDs use separate CC74-on/75-off triggers with factory LED identifiers. Native outputs cover Play, Cue preview, Sync, Key Lock, loop and eight cues per deck.
Initial feedback sets owned states. Shutdown clears these 52 states within the existing lifecycle limit.
Dimmer lights, FX, full reset/feedback, Shift alternatives and source cue/loop customisations stay open.
No generic USB Audio Device alias, audio interface, source deck-count mutation or JS timers are invented.
Endpoints that expose only a generic name still need manual profile selection.

All 36 final focused Swift checks, 86 importer checks and native iPad framework compilation pass.
The first check incorrectly expected a held Play press to retrigger after Shift release. The corrected fixture releases Play before a fresh press.
A Python expected-count assertion was also corrected from 116 to 120 bindings. Both original results remain saved.
All 164 other recipes remain unchanged. The bundled iPad resource matches the source.
Automatic core coverage is now 118 factory profiles for 124 physical models, plus six other native models.
Benchmark coverage remains 62/122. Full feature parity, physical calibration and A10X acceptance remain open.
Repository checks retain twelve existing historical-link failures. No signed app or installation occurred.
Exact logs, source hashes and factory PDF are in ignored `TestBuilds/r253/validation.json`.

## R254 Mixage family core and separate model records

The pinned [Mixxx XML](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Mixage.midi.xml) explicitly covers Interface Edition MK1, Interface Edition MK2 and Controller Edition.
The catalogue now names these three physical models separately. One reviewed recipe serves their documented default hardware MIDI channel 1 layout.
Full pitch messages, normal/Shift mixer addresses and the author's measured 620-count jog scale use existing native contracts.
Native fixed touch scratch keeps normal/Shift pressure and movement addresses. No source scratch/scroll toggles or brake timers run in the app.
Each physical Shift controls its own side. Alternate Cue/bend releases preserve ownership, and transport release aliases rearm base buttons.
Four shifted cues retain native one-press behaviour. Shifted filter control retains pickup.
Native Loop Enable is idempotent. Reloop, manual In/Out and sign-only loop-size rotation use reviewed addresses.
Browsing uses separate track/group encoders and immediate Open Group. Source multi-click preview and complete folder semantics remain open.

Startup/shutdown clear only 26 known LED/meter addresses. They replace the source's 0–254 note clear, which exceeds MIDI's valid data range.
The lifecycle total is 54 messages, including fixed scratch indicators. Native transport, held Cue, PFL, Sync and loop LEDs retain source addresses.
Live meters, CUP, FX, full loop adjustment/removal, source held cue semantics, other hardware channel and physical calibration remain open.
Family-specific audio routing remains open. The Controller Edition receives no inferred audio route.
The linked factory-manual download did not complete and was cancelled. This increment relies on the pinned source, without a new factory-manual claim.

All 36 focused Swift checks, 87 importer checks and native iPad framework compilation pass.
A Python expected-count assertion was corrected from 104 to 108 bindings. No runtime change was needed for that fixture correction.
All 164 other recipes remain unchanged. The bundled iPad resource matches the source.
The catalogue now has 307 records for 300 physical models. Automatic core coverage is 119 factory profiles for 127 models, plus six other native models.
Benchmark coverage remains 62/122. Full theoretical feature parity remains open.
Repository checks retain twelve existing historical-link failures. No physical test, signed app or installation occurred.
Exact logs and source hashes are in ignored `TestBuilds/r254/validation.json`.

## R255 Original Inpulse 300 paired mixer and native loop layout

The existing automatic original 300 recipe now uses the [factory MIDI format](https://ts.hercules.com/download/sound/manuals/DJC_Inpulse300/DJControlInpulse300_MIDI_Commands_V_1_2.pdf) and pinned working source.
Paired crossfader, level, gain, EQ, filter and pitch retain fourteen-bit values on normal and Shift channels.
Factory signed jog magnitude replaces direction-only handling. Native fixed scratching keeps the source 248-count scale and four-times Shift motion through 62counts.
Physical Shift is separate per side. It rearms pickup and retains old Cue/contact releases.
The shifted B contact follows working source channel 5, correcting a conflicting factory row. Disputed shifted PFL/Load alternatives stay unmapped.
Eight Hot Cues use distinct hardware pad addresses. Shifted delete releases rearm native one-press cues without deleting them.
Other pad pages, mode-aware pad feedback, FX and beatmatch guides stay open.

The recipe retains the source's custom loop layout. In enables a four-beat loop. Out disables it.
The new typed Loop Disable action is idempotent. It cannot enable a loop on a second press.
Native playback fixtures verify both repeated In and repeated Out, with saved Sync intact.
Original manual/adjustable loop behaviour and the source's backspin/Vinyl state machine remain open.
Startup retains source Vinyl indicators, browser indicator and safe analogue query. No source timers or JS run in the app.
Master/headphone gain, PFL Master, complete feedback/cleanup and audio routing remain open. MK2 stays separate.

All 36 focused Swift checks, 88 importer checks and native iPad framework compilation pass.
All 164 other recipes remain unchanged. The bundled iPad resource matches the source.
Automatic core counts stay unchanged because the imported original 300 profile already selected automatically.
The catalogue remains 307 records for 300 physical models, with 119 factory profiles for 127 automatic core models, plus six other native models.
Benchmark coverage remains 62/122. Full theoretical feature parity and physical acceptance stay open.
Repository checks retain twelve existing historical-link failures. No signed app or installation occurred.
Exact logs, source hashes and factory PDF are in ignored `TestBuilds/r255/validation.json`.

## R256 Fuller Total and Omni cores with source fine-tempo response

The separate recipes retain each pinned layout. Numark's [fixed Total MIDI chart](https://www.numark.com/images/product_downloads/totalcontrol_midimap.pdf) confirms Total jog A25/B24.
Omni keeps its working source A24/B25 order. Native wheel nudge/paused seek retains the source 128-count scale.
The factory-only fine-tempo codec preserves signed source rate steps of 1/512, with native inversion applied once.
It shares strict seven-bit validation with Compact's accelerated tempo decoder. Compact's existing response passes the focused checks again.
Separate Cue Set, held Cue preview, held pitch bend, mixer/pitch pickup and direct Load retain native contracts.
Manual In sends native Loop Disable before Loop In. Out sets the boundary or exits the current loop.
Native playback fixtures verify the compound order, new loop creation, exit and saved Sync for both models.

LED addresses differ from input addresses. Native PFL resolves the source's negative condition to on 100/off 0.
Play and Key Lock retain source 100-on values. Native Sync indication is steady, while source beat pulses remain open.
Startup clears the source LED range 48–86. Shutdown clears the eight native output states. The lifecycle total is 47 messages.
Native browsing uses track movement and immediate Open Group. Full directory mode remains open.
Source scratch/simple-Cue/extended-loop modes, Tap, EQ kill, FX, animations, full loop/browser semantics, audio routing and calibration stay open.
Neither source JS nor synthetic touch timers run in the app. Stealth is not inferred as an alias.

All 42 focused Swift checks, 89 importer checks and native iPad framework compilation pass.
All 163 other recipes remain unchanged. The bundled iPad resource matches the source.
Both imported profiles already selected automatically. Automatic core counts remain 119 factory profiles for 127 models, plus six other native models.
The catalogue remains 307 records for 300 physical models. Benchmark coverage remains 62/122. Full feature parity and physical acceptance stay open.
Repository checks retain twelve existing historical-link failures. No signed app or installation occurred.
Exact logs, source hashes and factory PDF are in ignored `TestBuilds/r256/validation.json`.

## R257 Stealth manufacturer inventory and factory XML audit

Added the missing [Numark Stealth Control](https://www.numark.com/product/stealthcontrol) model with its first-party factory XML archive and user guide.
The public factory archive contains `stealth_control_cue.xml` and setup instructions for CUE 5/Virtual Vinyl 5.
The archive SHA-256 is `5429b3d5a0d3340664f7982a74bd78f261ac2ca1461a1949d7c59dada34c7b17`.
The XML SHA-256 is `fb961915199268c46c201ae84c1e2e595a40ff72b922c462d43cb69da8258dc1`.
The setup guide SHA-256 is `960a0d53067af96504064ba28f217756ee2c2272708fbc4f53b2b058a5b45a55`.
The user guide SHA-256 is `ddbe4bdc1c973ba7b5df170767ce0831d19a7659ffa85719b3620ace5f3af8a0`.

The XML supplies software action assignments and control numbers. The meaning of its `chan` fields needs raw MIDI qualification.
The setup guide covers both Omni and Stealth workflows, but it does not establish identical raw MIDI or LED behaviour.
Qualify the raw MIDI channel, encoder format/scale and LED commands before automatic selection.
The XML's mixed Cue/Set Cue assignments and software-specific action values also need native translation.
The corresponding guessed Omni archive URL returned 404. No compatibility fact was inferred from that failed request.
Stealth remains protocol-needed. Its public sources do not add a runtime alias or mapping.

All 90 importer checks pass. All 165 runtime recipes are byte-for-byte unchanged. No runtime build was required for this source-only inventory change.
The catalogue now has 308 records for 301 physical models. Automatic core counts stay 119 factory profiles for 127 models, plus six other native models.
Benchmark coverage remains 62/122. The wider manufacturer audit and full theoretical feature parity remain open.
Repository checks retain twelve existing historical-link failures. No hardware test, signed app or installation occurred.
Exact logs, source hashes and downloaded originals are in ignored `TestBuilds/r257/validation.json`.

## R258 X-Session Pro factory-preset core

The [factory guide](https://images.juno.co.uk/manual/334309-01U.pdf), Appendix A, confirms control numbers and simultaneous normal/inverted crossfader streams.
The pinned working XML supplies channel 1 and software assignments for the six user knobs.
The existing manual recipe now selects automatically for the factory preset. Enigma custom presets and Evolution UC-17 stay separate.
Only normal crossfader CC 17 drives the native mixer. Inverted duplicate CC 20 and source balance CC 32 stay inactive.
Source user-knob assignments retain gain, headphone mix/level and master level. They are software assignments, not factory labels.
Native pitch has centre pickup and applies source polarity once. Held Cue remains separate from PFL.
The four search buttons need a native held-search contract and stay inactive. No jog, Sync, Load, LED feedback or audio interface is inferred.

All 32 focused Swift checks, 91 importer checks and native iPad framework compilation pass.
The shared Cue fixture covers 111 automatic profiles. All 164 other recipes remain unchanged, and the bundled resource matches the source.
The catalogue remains 308 records for 301 physical models. Automatic core coverage reaches 120 factory profiles for 128 models, plus six other native models.
Benchmark coverage remains 62/122. Full search/balance behaviour, custom presets, calibration and physical acceptance remain open.
Repository checks retain twelve existing historical-link failures. No signed app or installation occurred.
Exact logs, source hashes and the factory guide are in ignored `TestBuilds/r258/validation.json`.

## R259 CMD STUDIO 4a four-channel native core

The pinned working XML/script and [mapping author's manual](https://manual.mixxx.org/2.4/en_gb/hardware/controllers/behringer_cmd_studio_4a) qualify four deck channels.
C/D retain the app's existing opt-in. Native fixed touch scratch uses centre-64 jog values and the source 600-count scale.
Full pitch keeps pickup and source polarity. Right-deck Loop In 56/Out 55 retain the source's reversed addresses.
Native held Cue and bend, eight cues per deck, mixer/filter, Load and browsing use shared contracts.
DEL guards unsupported alternate presses on its physical side across A/C and B/D. Old Cue/contact/bend releases remain valid.
Latched DEL mode, cue deletion, reverse/slip loops, scratch toggle and full bank-contact qualification remain open.
Source gain/filter assignments remain software assignments. No beatgrid mutation, timers or JS run in the app.

Six native transport/PFL/loop states per deck use source on 1/off 0 values.
Startup sets fixed Scratch indicators and clears DEL indicators. Shutdown clears these and all native-owned outputs, within 40 lifecycle messages.
Pad LEDs, live meters, EQ kill, FX, full browser/mode cleanup and calibration remain open.
The author's documented master 1–2/headphones 3–4 layout uses the existing automatic audio route.
Shared offline fixtures retain samples, transport and saved Sync during repeated detection and route recovery.

All nine focused Swift tests, including parameterised audio cases, 92 importer checks and native iPad framework compilation pass.
The initial importer expected audio-profile set was updated. Initial Swift fixtures lacked the required startup destination and expected separate jog callbacks instead of the receiver's accumulated movement.
Corrected fixtures pass without a runtime receiver change. Earlier failures remain in the evidence logs.
All 164 other recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage reaches 121 factory profiles for 129 models, plus six other native models. Benchmark coverage remains 62/122.
Repository checks retain twelve existing historical-link failures. Full feature parity and physical acceptance remain open. No signed app or installation occurred.
Exact logs and source hashes are in ignored `TestBuilds/r259/validation.json`.

## R260 Stanton DJC.4 default-bank native core

The pinned working XML/script provide four deck channels, normal/Shift addresses and the 128-count jog scale.
The mirrored [factory guide](https://manualzz.com/doc/4156007/stanton-djc.4-controller-user-manual) confirms default channels 1–4 and HOLD Shift.
Its [structured MIDI table](https://www.scribd.com/document/361336662/DJC-4ManualV1-1) confirms shifted bend release notes 69/70, absent from the working XML.
The PDF download returned a web challenge; the original manufacturer URL returned 404. No downloaded factory PDF is claimed.

Native fixed touch scratch replaces source RPM mode changes and its undefined strip-search scale.
Physical Shift preserves alternate Cue/contact/bend releases and rearms ordinary buttons.
Deck selection releases contacts and rearms pickup on the physical A/C or B/D side while retaining held Shift.
C/D keep the app's existing opt-in. Other MIDI channel banks and custom hardware settings stay separate.
Native four-cue layout, separate shifted Cue Set, full pitch, mixer/filter, manual loops and loop-size buttons retain explicit source addresses.
Browsing accepts only source values 65/63. Full folder focus/page semantics, held loop adjustment, roll, source Cue-stop and shifted search remain open.

Forty native cue/transport/PFL/key/loop outputs and four fixed Scratch indicators fit 48 lifecycle messages.
The source full factory reset exceeds the lifecycle budget and is not copied. Remaining LED/meter cleanup, EQ kill, FX and samplers stay open.
Master/microphone hardware gain is not duplicated in software.
The [mapping author](https://manual.mixxx.org/2.5/en/hardware/controllers/stanton_djc_4) documents master 1–2/headphones 3–4, now using the shared automatic route and recovery fixtures.

All eleven focused Swift tests, including parameterised audio cases, 93 importer checks and native iPad framework compilation pass.
All 164 other recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage reaches 122 factory profiles for 130 models, plus six other native models. Benchmark coverage remains 62/122.
Repository checks retain twelve existing historical-link failures. Full feature parity, calibration and physical acceptance remain open. No signed app or installation occurred.
Exact logs, source hashes and download failures are in ignored `TestBuilds/r260/validation.json`.

## R261 MC3000 factory corrections and expanded manual core

The [original Denon guide](https://cdn.inmusicbrands.com/denondj/legacy/mc3000/MC3000EM_ENG_IM_v00.pdf), PDF pages 20–23, corrects the old software assignments.
Master, headphone and microphone gain knobs are hardware controls. Old assignments on CC 88–92 actually address FX knobs and are removed.
The reviewed manual recipe replaces 39 imported inputs with 124 native bindings and 56 factory-addressed outputs.
A/C/B/D retain channels 1/2/3/4. Full pitch ignores the old XML's incidental note-number field and keeps centre pickup.
Factory button velocity 64 works with native Cue and bend. Physical Shift identity spans the two channels on each side.
Eight distinct cue addresses, per-deck level/gain/EQ, native manual loops and loop-size buttons use documented messages.
Source compound In disables an old loop before recording its new boundary. Out sets the end or exits an active loop.
Native jog uses the shared default pending calibration, without the old script's arbitrary 100-count/330-RPM combination.

Factory LED commands use separate on/off trigger controllers and IDs. PFL retains its separate 80/81 command pair.
Manual selection needs explicit feedback enablement. No factory lifecycle, analogue query or bank cleanup is implied.
Shared Load target ownership and cold-state recovery remain unqualified. Load stays inactive, and automatic selection stays disabled.
Complete bank cleanup, hardware channel variants, filters, source modes, full feedback/routing, calibration and physical acceptance remain open.
A newer public mapping proposal was inspected as a research lead; its custom shared-Load workflow was not imported.

All nine focused Swift tests, 94 importer checks and native iPad framework compilation pass.
Initial fixtures assumed full-value button reports and immediate continuous callbacks; corrected fixtures retain velocity 64 and queued delivery.
A Swift assertion exceeded type-checking time; a typed expected value resolved that compile failure. Earlier failed logs remain preserved.
All 164 other recipes remain unchanged. The renamed MC3000 recipe replaces its old version-labelled ID. The bundled resource matches the source.
Automatic core counts remain 122 factory profiles for 130 models, plus six other native models. Benchmark coverage remains 62/122.
Repository checks retain twelve existing historical-link failures. No signed app or installation occurred.
Exact logs, source hashes and factory pages are in ignored `TestBuilds/r261/validation.json`.

## R262 RMX2 factory pairs and shifted CC releases

The [factory command table](https://ts.hercules.com/download/sound/manuals/Rmx2/RMX2_MIDI_Commands.pdf) supplies explicit adjacent high/low controller pairs.
Pitch, level, gain, EQ, master gain, cue mix and crossfader now keep fourteen-bit values. Gain/EQ replace coarse imported assignments.
Pitch retains pickup and source polarity. EQ direction retains the working source convention pending calibration.
Separate normal wheel and pressure-scratch streams keep factory signed magnitude and the source 256-count scale.
Factory raw 64 is negative, correcting the script's boundary. Pressure scratching requires full-value physical contact.
Native releases replace source inertia/delay timers. Original RMX retains its separate identity.

Four Cue pads per side and source 4/2/1/half-beat loop pads use distinct hardware mode addresses.
The factory Loop-mode encoder adjusts native loop size. Other knob modes stay inactive.
Shifted pad releases arrive as controller messages. The shared contract now accepts exact zero seven-bit absolute controller reports as release-only bindings.
Positive shifted delete/roll/pressure values cannot trigger native cues or loops. Wrong sources, groups and expanded values cannot rearm them.
Profile validation rejects relative encodings, continuous actions, Shift and other message kinds for controller release-only bindings.
Existing note-release handling stays covered, as do copied profile metadata and native Shift/deck guards.
Factory shifted bend release notes release existing holds without invoking alternate actions. Native held Cue stays separate from PFL.

Startup clears unsupported loop/kill/source/contact/browser indicators, enables fixed Scratch and requests analogue positions.
Shutdown clears sixteen native outputs and Scratch. The lifecycle total is 39 messages.
No source JS, microphone mutation or timer runs in the app. Headphone gain stays a hardware control.
Held search, other pad modes/FX/samplers, full meters/cleanup/routing, calibration and physical acceptance remain open.

All 32 focused Swift checks, 95 importer checks and native iPad framework compilation pass.
All 164 other recipes remain unchanged. The bundled resource matches the source. The shared Cue fixture covers 114 automatic profiles.
Automatic core coverage reaches 123 factory profiles for 131 models, plus six other native models. Benchmark coverage remains 62/122.
Repository checks retain twelve existing historical-link failures. Full feature parity remains open. No signed app or installation occurred.
Exact logs, source hashes and the factory table are in ignored `TestBuilds/r262/validation.json`.

## R263 P32 A/B core and bounded encoder direction steps

The pinned XML/script qualify P32's A/B layout, mirrored loop/tempo encoders and source cue order.
The [factory guide](https://ts.hercules.com/download/sound/manuals/P32DJ/EN_HERCULES_P32_DJ_User_Manual.pdf) confirms class-compliant USB and default master 1–2/headphones 3–4.
The linked factory MIDI archive returned 403. Its [readable factory mirror](https://www.scribd.com/document/467254251/Hercules-P32-DJ-MIDI-Command-List-rev1-0) was checked against the pinned sources.

The source's 1% rate changes become inverse normalised tempo steps of 0.005. Shifted browser cue-blend changes become normalised steps of 0.05.
A typed optional `directionStep` preserves these report-direction steps without magnitude acceleration. Factory raw 64 remains negative.
The contract accepts finite positive steps up to 0.1 only for reviewed signed tempo/cue-blend encoders.
Queued reports accumulate and clamp through the existing native value path. Profiles without this field retain their existing response.
Copied factory mappings and replacement endpoint identities retain the step values.

The first eight source cues per side retain the physical top-two-row order. The other eight slots per side stay inactive.
Native held Cue/bend, manual loop pads, loop toggle/encoder, tempo reset, three-band EQ, levels, crossfader, browsing and Load retain source assignments.
Shifted delete/eject/reverse alternatives stay inactive while old holds release and ordinary buttons rearm.
Source C/D switching through Shift+Slip is not implemented. A/B stay fixed; no hidden deck change is inferred.
The source's dry/wet knob is not reassigned to gain. Headphone gain remains a hardware control.

Fifty-eight normal/Shift outputs retain published transport and pad values. PFL remains normal-only.
Encoder buttons receive no inferred LEDs. Pad mode indicators remain firmware-owned.
Startup sends the source analogue query. Shutdown clears owned addresses, replacing the source's 594-note clear. The lifecycle total is 59 messages.
Seven-segment displays, remaining pad slots/modes, FX, samplers, Slip/recording, full cleanup, calibration and physical acceptance stay open.

All 36 focused Swift tests, including 18 parameterised audio cases, 96 importer checks and native iPad framework compilation pass.
The shared audio fixtures retain samples, transport and saved Sync during repeated detection and route recovery.
An initial importer binding-count expectation was corrected to 105. A test that read private mapping state was replaced with the reconnect behaviour check. Earlier failures remain preserved.
All 164 other recipes remain unchanged. The bundled resource matches the source. The shared Cue fixture covers 115 automatic profiles.
Automatic core coverage reaches 124 factory profiles for 132 models, plus six other native models. Benchmark coverage remains 62/122.
Repository checks retain twelve existing historical-link failures. Full feature parity remains open. No signed app or installation occurred.
Exact logs, source hashes and the factory guide are in ignored `TestBuilds/r263/validation.json`.

## R264 KAOSS DJ normal core and separate Audioless profile

Korg's [MIDI implementation](https://cdn.korg.com/us/support/download/files/9015867d23596afc1635ec139a8cdfb4.txt) fixes global channel 7 and deck channels 8/9.
The [operation guide](https://cdn.korg.com/us/support/download/files/3712d559e956c0edb50a9c9e8b1e1d4e.pdf) separates normal Controller mode from Audioless and Audio Return startup modes.
Main, headphone and balance knob messages exist only in Audioless mode. The automatic normal recipe leaves these hardware controls alone.
A separate manual Audioless recipe adds software master/headphone gain and cue blend. It claims no audio interface or factory lifecycle.
Both recipes belong to one physical model. The extra recipe does not add a controller to the model count.

Native fixed touch scratch uses the working source's 128-count scale. Both normal and scratch streams work with contact; scratch reports require full-value touch.
The source's four-times Shift scratch uses 32-count resolution and requires contact. Free Shift search remains open.
Physical-side Shift guards local alternatives. Both Shift inputs also feed a global layer for shared Load and browsing.
Opposite-side transport remains available. Shared Load changes to native group navigation while either Shift is held.
Native three-cue pages, manual loop alternatives, held bend, Shift strip seek and Shift+Play Key Lock retain published dispatch.
Shifted delete releases rearm cues. Shift Sync cancel, scratch toggling and complete browser behaviour remain open.

Korg documents knob-lamp and button-light commands. Twenty native output states and bounded lamp setup/cleanup fit 48 lifecycle messages.
The source's proprietary Serato status SysEx is absent from the published implementation and is omitted. Identity inquiry is not treated as an analogue query.
The [mapping author](https://manual.mixxx.org/2.5/en/hardware/controllers/korg_kaoss_dj) specifies master 1–2/headphones 3–4 and says audio output selection wakes standby.
The normal recipe uses the shared automatic split route. Offline fixtures preserve samples, transport and saved Sync through detection and recovery.
Software XY effects/samplers, full meters/reset, Audio Return routing, calibration and physical acceptance remain open. Hardware KAOSS effects stay hardware-owned.

All thirteen focused Swift tests, including 20 parameterised audio cases, 97 importer checks and native iPad framework compilation pass.
The first manual-mode fixture included expected jog-neutral cleanup from profile replacement. The corrected fixture separates cleanup from knob dispatch; no runtime change was needed.
The earlier failure and diagnostic output remain preserved. All 164 unrelated recipes remain unchanged. The bundled resource matches the source.
The catalogue remains 308 records for 301 physical models, with 166 data recipes and five code profiles.
Automatic core coverage reaches 125 factory profiles for 133 models, plus six other native models. Benchmark coverage remains 62/122.
Repository checks retain twelve existing historical-link failures. Full feature parity remains open. No signed app or installation occurred.
Exact logs, source hashes and Korg originals are in ignored `TestBuilds/r264/validation.json`.

## R265 Idempotent KAOSS Shift+Sync cancel

The documented KAOSS Shift+Sync operation now uses a typed native Sync Disable action on each deck.
Normal Sync keeps its toggle behaviour. Disable sets the loaded deck's saved choice to false and cannot enable Sync on a repeated press.
The existing model Sync path is factored into an explicit setter. Transport submission still precedes preference persistence.
The existing loaded-deck requirement remains. Other controller profiles receive no inferred Shift+Sync assignment.
Native Sync feedback continues to reflect the resulting deck state; there is no competing Disable light mapping.

A real-file native fixture verifies repeated cancel presses, unchanged playhead/phase, old Cue release and track reload.
Each retains Sync off. The ordinary Sync button enables it again only on a later explicit press.
Both normal and manual Audioless KAOSS recipes gain the documented operation. Held-button rearming remains covered.

All twenty focused Swift tests, 97 importer checks and native iPad framework compilation pass.
All 164 unrelated recipes remain unchanged. The bundled resource matches the source.
Catalogue and automatic core counts stay unchanged. Full feature parity and physical acceptance remain open.
Repository checks retain twelve existing historical-link failures. No signed app or installation occurred.
Exact logs and source hashes are in ignored `TestBuilds/r265/validation.json`.

## R266 Keep catalogue metadata with the selected recipe

A model can have an automatic default recipe and a larger manual mode variant.
The catalogue selected the largest recipe for its control/audio summary even when the model named a different default recipe.
For KAOSS DJ, this mixed manual Audioless knobs into the normal control list and hid the implemented split audio route.
The generator now prefers the model's explicit recipe. Models without one retain the existing largest-recipe fallback.
The KAOSS summary now lists the normal recipe's 86 bindings and automatic master 1–2/headphones 3–4 route.
The larger manual Audioless recipe remains available separately. Full feature parity remains open.

All 98 importer/catalogue checks pass. All 166 runtime recipes are byte-for-byte unchanged, so no runtime build was required.
Catalogue and automatic core counts stay unchanged. Repository checks retain twelve existing historical-link failures.
Exact logs and source hashes are in ignored `TestBuilds/r266/validation.json`.

## R267 VMS external mixer route and missing variants

Added separate manufacturer records for [VMS5](https://www.adj.com/products/vms5) and [VMS4.1 Traktor](https://www.adj.eu/vms4-1-traktor).
Neither inherits a VMS4 mapping. Published control counts, wheel resolution and Traktor control layout differ.
The catalogue now contains 310 records for 303 physical models. The wider manufacturer audit remains open.

The [VMS2 factory guide](https://cdn-docs.av-iq.com/other/VMS2_User%20Manual.pdf), pages 16–18, documents separate USB deck outputs and factory Pre EQ processing.
The [VMS4 mapping author](https://manual.mixxx.org/2.5/en/hardware/controllers/american_audio_vms4) specifies external hardware mixing and Post EQ.
The app currently provides stereo master or master/headphones. It does not provide separate deck outputs for external mixing.
The existing VMS2 and VMS4/4.1 partial recipes now state this routing gap and their Post EQ requirement explicitly.
Applying software EQ in factory Pre EQ mode would process EQ twice. Automatic selection stays disabled.
Control bindings, feedback and lifecycle packets remain unchanged. No audio renderer change or substitute PFL route was added.

All 99 importer checks, the bundled-profile loading check and native iPad framework compilation pass.
All 164 unrelated recipes remain unchanged. The bundled resource matches the source.
Automatic core counts remain 139 physical models, including 62/122 benchmark models. Full theoretical parity remains open.
Repository checks retain twelve existing historical-link failures. No signed app, installation or physical acceptance occurred.
The cached 26-page factory guide has SHA256 `262cd2ae7b62cd48c6f7cf5124823c35ffa1d549fe01d828f3737bb0359e6948`.
Exact logs and source hashes are in ignored `TestBuilds/r267/validation.json`.

## R268 Original FirstMix native core

The original Gemini FirstMix now selects a reviewed two-deck recipe automatically.
The pinned XML and companion script supply physical touch, 180-count signed wheels, native held Cue, direct Load, PFL and browsing.
Fixed Scratch requires full-value contact. The signed midpoint decodes negative, correcting the script's scratch boundary.
Native motion uses counts while held and restores grid alignment on release when Sync is enabled.
Source Scratch/Pitch switching, reverse, sampler preview and library auto-load remain inactive.
FirstMix I/O and Pro are excluded variants. No channel fader, pitch slider or audio interface is inferred.

The [mapping author's source](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Gemini-FirstMix-scripts.js) deliberately reassigns EFX amount to gain, physical gain to High, Treble to Mid and Master to cue blend.
The native recipe retains those software assignments and pickup. Eight transport/PFL lights use the published value 100.
Startup clears the source light range and enables both fixed Scratch indicators. Setup and shutdown total 58 messages.
Steady native lights replace beat/end-of-track flashing. Unsupported source analogue queries are omitted.

All eight focused Swift tests, 100 importer checks and native iPad framework compilation pass.
The real-file fixture checks scratch counts, release, paused grid alignment and saved Sync.
The first run caught an incorrect encoding name, corrected to the existing full-velocity gate.
A later fixture incorrectly expected off-grid paused release. Its corrected assertion checks the required grid restoration.
Both earlier results remain preserved. All 165 other recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage reaches 140 physical models, including 62/122 benchmark models. Full theoretical parity remains open.
Repository checks retain twelve existing historical-link failures. No signed app, installation or physical acceptance occurred.
Exact source hashes and logs are in ignored `TestBuilds/r268/validation.json`.

## R269 Original ION Discover core and permanent tempo buttons

The original ION Discover DJ now selects its own native core automatically. Discover Pro remains separate.
The [mapping author](https://manual.mixxx.org/2.5/en/hardware/controllers/ion_discover_dj) identifies physical Volume and Bass controls repurposed for three-band software EQ.
The native recipe restores labelled Volume and two-band Bass/Treble. It does not invent Mid EQ, PFL or an audio interface.
Published Play, held Cue, Sync, direct Load, signed browsing and inverted crossfader retain their wire addresses.

Pitch buttons now use typed permanent Tempo Up/Down actions. Each fresh press changes tempo by 0.1 percentage points, matching the native UI step.
This is a deliberate native step, separate from the source application's configurable coarse step and from held pitch bend.
The shared tempo setter preserves Sync, changes master tempo for a synced deck and free rate for an unsynced deck.
Releases do not undo the change. Existing ±50 percent limits still apply. No automatic key-repeat timer was added.

Physical touch supports fixed native scratching. The source sets 128 counts at 45 RPM and divides ticks by three.
Its effective response converts to native resolution 518.4 at 1.8 seconds per turn. This is not a measured physical wheel resolution.
Unheld movement uses the existing native seek/nudge path. Source Scratch-mode switching, reverse and library expansion remain open.
Six steady transport lights and fixed Scratch indication use the published addresses. Startup/shutdown total eighteen messages.
The source's delayed light show and Load-driven light changes are omitted.

All nine focused Swift tests, 101 importer checks and native iPad framework compilation pass.
Real-file fixtures cover count response, grid restoration, fresh-press tempo steps, both Sync states, tempo limits and continuing finite playback.
An initial fixture assumed an order for independent queued deck jogs. The corrected assertion checks each deck separately; no runtime fix was needed.
All 165 other recipes remain unchanged. The bundled resource matches the source. Automatic core coverage reaches 141 physical models.
Benchmark coverage stays 62/122. Full theoretical parity, physical calibration and acceptance remain open.
Repository checks retain twelve existing historical-link failures. No signed app or installation occurred.
The factory-guide mirror returned HTTP 403; no successful factory PDF review is claimed.
Exact source hashes, earlier results and final logs are in ignored `TestBuilds/r269/validation.json`.

## R270 Separate Discover Pro normal-mode core

Discover Pro now selects its own normal-mode recipe automatically. It retains distinct Pro transport addresses, pitch sliders and three-band mixer.
Native held Cue, PFL, Key Lock, direct Load and temporary bend retain their published assignments.
Exact-centre pitch preserves pickup. Its polarity is applied once. Source normal wheels use native seek/nudge with a 128-count scale.
Browser press opens a native group as labelled. The source's latched directory mode remains open.

The [mapping author](https://manual.mixxx.org/2.5/en/hardware/controllers/ion_discover_dj_pro) lists AutoLoop, Stutter, All Mute and iPod support as unfinished.
The pinned touch handler uses uninitialised state, a conflicting scratch scale and a misspelled setter.
The recipe leaves those scratch/contact inputs inactive. It does not run the source's synthetic scratch timers.
The source's three-button manual-loop remapping does not qualify a factory four-button AutoLoop layout. These buttons remain inactive.
EQ kill, reverse, full mode behaviour and split audio channel assignment also remain open.

Ten native output lights use the resolved source polarity: on 100, off 0. Thirty reviewed light addresses clear at setup and shutdown.
This fits sixty lifecycle messages. The source's broad 68-address shutdown would exceed the existing bound and is not copied.
No state query, analogue gain assignment or automatic split audio route is inferred beyond the published MIDI assignments.

All eight focused Swift tests, 102 importer checks and native iPad framework compilation pass.
The real-file fixture checks grid-aligned paused seeks with Sync on, precise counts with Sync off, inactive disputed contact and continuing finite playback through held bend.
Earlier fixture results expected an off-grid seek while Sync was on. The corrected fixture separates those two states; no runtime change was needed.
All 165 other recipes remain unchanged. The bundled resource matches the source. Automatic core coverage reaches 142 physical models.
Benchmark coverage stays 62/122. Full theoretical parity, physical calibration and acceptance remain open.
Repository checks retain twelve existing historical-link failures. No signed app or installation occurred.
Exact source hashes, earlier results and final logs are in ignored `TestBuilds/r270/validation.json`.

## R271 DJM-101 MIDI mixer core and VTT-101 inventory

DJ-Tech DJM-101 now selects an accessory recipe automatically on the published hardware MIDI channel 1 configuration.
The factory guide confirms a USB MIDI mixer with gain, three-band EQ, channel faders, PFL and global mixer controls.
Pinned XML retains asymmetric left/right EQ addresses. The script supplies PFL note-on 127/off 0 feedback.
Native pickup protects continuous controls. No transport keys or integrated audio interface are inferred.

Startup and shutdown clear both master/deck meter address pairs and PFL lights, using twelve messages in total.
Live meter feedback and its source switch remain open. No fader-position substitute is used.
The source script can produce meter data above 127; that output is not copied.
Other hardware channel selections, curve behaviour and physical acceptance remain open.

The factory VTT-101 guide also confirms a distinct missing model, now recorded without an inferred runtime protocol.
Its physical touch wheel and crossfader do not establish the MIDI addresses or calibration.
The catalogue contains 311 records for 304 physical models. The wider market audit remains open.
The [DJM-101 guide](https://asset.conrad.com/media10/add/160267/c1/-/gl/000090874ML01/mode-demploi-090874-table-de-mixage-dj-tech-djm101-1-pcs.pdf) and [VTT-101 guide](https://asset.conrad.com/media10/add/160267/c1/-/gl/000092385ML01/mode-demploi-092385-mini-controleur-usb-dj-tech-vtt101.pdf) are cached with hashes and rendered control diagrams.

All seven focused Swift tests, 103 importer checks and native iPad framework compilation pass.
The real-file fixture checks mixer/PFL changes with continuing finite playback and saved Sync.
All 165 other recipes remain unchanged. The bundled resource matches the source. Automatic core coverage reaches 143 physical models.
Benchmark coverage stays 62/122. Full theoretical parity and physical acceptance remain open.
Repository checks retain twelve existing historical-link failures. No signed app or installation occurred.
Exact source hashes and logs are in ignored `TestBuilds/r271/validation.json`.

## R272 Original XDJ-RX firmware-2.21 core

The [factory MIDI table for firmware 2.21](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-RX/XDJ-RX_List_of_MIDI_Message_E_Ver221.pdf) resolves limits in the earlier table used by R180.
Page 3 specifies per-deck Load note 81. Page 2 specifies normal tempo CC29/61 and shifted CC52/84 fourteen-bit pairs.
Transport and PFL feedback are also documented. This is the 2017 protocol revision, newly reviewed here.
The original RX now selects the reviewed 2.21 core automatically. The earlier seven-bit recipe remains a separate manual option.
Firmware 2.21, PC/MIDI control, MIXER MODE MIDI CONTROL and DECK inputs are required.

Native speed jogs retain the published absolute response, including shifted addresses. Fixed Vinyl indication matches the native touch contract.
Four unambiguous Hot Cues per target remain available. The second bank has conflicting decimal/hex addresses in the factory table and stays unmapped.
Shifted release aliases rearm transport, Cue and cue pads without running unsupported alternate presses.
Deck-change CC102 reports release this source's owned contacts across the global bank. PC-control-off CC100 releases only the reported deck.
These reports do not end a later waveform touch. Normal touch and Cue release retain saved Sync.
Complete pad modes, held cue-pad behaviour, displays, HID, rings, live meters and automatic audio routing remain open.

Twenty-four transport/PFL output bindings use the factory note/CC addresses. Fixed Vinyl setup and output cleanup total 56 lifecycle messages.
Load illumination and PC-control status messages are not treated as track-load inputs.
The [factory Traktor guide](https://downloads.support.alphatheta.com/midi-mapping/all-in-one-dj-systems/XDJ-RX/XDJ-RX_TRAKTOR2_Import_Guide_E.pdf) documents internal master/headphone and external deck routes.
Automatic iPad audio selection is not inferred from that PC/Mac guide.

All fifteen focused Swift tests, 104 importer checks and native iPad framework compilation pass.
Fixtures cover low-byte pitch precision/pickup, Load on each target, releases, bank/PC exit, unowned touch protection and the earlier manual recipe.
The first run caught a forbidden Shift-release field on CC bank reports. The corrected metadata uses the existing CC bank contract; the failed result remains preserved.
All 165 unrelated recipes remain unchanged. The legacy variant retains the earlier input/output/lifecycle bytes. The bundled resource matches the source.
There are now 167 data recipes. Automatic core coverage reaches 144 physical models. Benchmark coverage remains separately reported in the generated catalogue.
Full theoretical parity and physical acceptance remain open. Repository checks retain twelve existing historical-link failures.
The seven-page factory table has SHA256 `b51d2a0d32ba16d841fd35130d0a9cabb318ce927ea4cfb2023347298832a4d3`.
No signed app or installation occurred. Exact source hashes and logs are in ignored `TestBuilds/r272/validation.json`.

## R273 Reloop Master Edition driver boundary

The mapping authors identify [Jockey 3 ME](https://manual.mixxx.org/2.5/en/hardware/controllers/reloop_jockey_3_master_edition) and [Digital Jockey 2 Master Edition](https://manual.mixxx.org/2.5/en/hardware/controllers/reloop_digital_jockey_2_master_edition) as non-class-compliant devices.
Their desktop drivers translate controls to MIDI. A stored virtual-MIDI recipe does not provide direct iPad USB control.
The catalogue now states that driver and bridge requirement. The bridge and direct USB protocol remain unimplemented.
Added the missing Digital Jockey 2 Master Edition record with its [manufacturer source](https://www.reloop.com/reloop-digital-jockey-2-master-edition).
It does not inherit the separate Interface Edition mapping.

The [Interface Edition author guide](https://manual.mixxx.org/2.5/en/hardware/controllers/reloop_digital_jockey_2_interface_edition) documents driver-free operation and master 1–2/headphones 3–4.
That model retains its separate connection record and mapping work.
All 105 importer/catalogue checks pass. All 167 runtime recipes are byte-for-byte unchanged, so no runtime build was required.
The catalogue contains 312 records for 305 physical models. Automatic core counts remain unchanged. The wider market audit remains open.
Repository checks retain twelve existing historical-link failures. Full theoretical parity and physical acceptance remain open.
Exact source hashes and logs are in ignored `TestBuilds/r273/validation.json`.

## R274 Digital Jockey 2 Interface Edition core

Interface Edition now selects a reviewed two-deck core automatically, using the pinned `DIGITALJOCKEY2` identity.
Controller Edition and the driver-dependent Master Edition remain separate. No C/D or Hot Cues are inferred.
The [mapping author](https://manual.mixxx.org/2.5/en/hardware/controllers/reloop_digital_jockey_2_interface_edition) documents driver-free operation and master 1–2/headphones 3–4.
That layout now uses the shared automatic split route. Source desktop scripts do not run in the app.

Fixed native Scratch uses full-value physical contact and the author's measured/estimated 148-count scale.
The existing Denon jog decoder matches source raw 0/64 neutral and raw-minus-64 motion. No new value codec or scratch timer was needed.
Centred pitch retains source inversion and pickup. Native held Cue/bend, gain/EQ/level, PFL, direct Load, loops and shifted filter controls retain published addresses.
Only source-listed Shift addresses get release aliases. Shifted eject, delete, roll and reloop-and-stop presses stay inactive.
Auto Loop uses native idempotent loop enable. Loop Active toggles the loop. The shifted loop-size encoder retains direction-only steps.
Native group navigation replaces desktop library focus/expansion commands. Latched jog/library-wheel modes and CUP release-to-play remain open.

Twelve steady native output states and reviewed loop/kill/CUP/jog-mode cleanup use exactly 64 lifecycle messages.
Fixed Scratch lamps remain on during the session. Full FX lights, mode feedback/reset, paused held search and calibration remain open.
Native master/headphone level ranges are used for the source gain controls; their physical gain response still needs calibration.

All ten focused Swift tests, including 22 parameterised audio cases, 106 importer checks and native iPad framework compilation pass.
The real-file fixture checks count response, Cue release, idempotent loop enable and saved Sync.
Audio fixtures check repeated detection, unchanged samples and recovery without falling back to speakers.
All 166 other recipes remain unchanged. The bundled resource matches the source. Automatic core coverage reaches 145 physical models.
Benchmark coverage stays 62/122. Full theoretical parity and physical acceptance remain open.
Repository checks retain twelve existing historical-link failures. No signed app or installation occurred.
Exact source hashes and logs are in ignored `TestBuilds/r274/validation.json`.

## R275 Digital Jockey 2 Controller Edition core

Controller Edition has its own automatic normal-wheel core. Its existing catalogue identity stays unchanged.
The [factory manual](https://www.reloop.com/media/catalog/product/pdf/2/2/2/222725_Reloop_IM.pdf), page 14, reserves touch sensitivity for Interface Edition.
The empty source touch handlers do not become native touch contacts. No audio interface or C/D addresses are inferred.
Native fixed wheel seek/nudge replaces desktop latched Search/Scratch modes and scratch timers.
Both mode lamps indicate the fixed nudge layout. Wheel count and gain calibration remain open.

Pinned XML supplies full pitch on separate E0/E1 channels, Play, held Cue/bend, direct Load, mixer and loop addresses.
Native pitch uses full endpoint normalisation, pickup and inverse Mixxx rate polarity. The source formula divides by 16384; native endpoint normalisation divides by 16383.
Duplicate source Load routes become one native press. Auto Loop enables the current native length; Loop Active toggles it.
The loop-size and browse encoders accept only the published 63/65 steps. Neutral and other values cannot move them.
Ten steady output states and thirty reviewed light addresses use sixty lifecycle messages. No Sync feedback address is inferred.
Shift releases, CUP, EQ kill, full FX/modes/feedback/reset and physical acceptance remain open.

All seven focused Swift tests, 107 importer checks and native iPad framework compilation pass.
The bundled resource matches the source; all 166 other recipes remain unchanged.
A first focused run exposed a fixture assumption about independent deck update order. The corrected fixture checks that an unrelated channel adds no event.
An interrupted broader run also found four expectations in an untouched older Numark Cue fixture; its log remains preserved for separate review.
Automatic core coverage reaches 146 physical models. Benchmark coverage remains 62/122; complete theoretical parity remains open.
Repository checks retain twelve existing historical-link failures. No signed app, installation or physical acceptance occurred.
Exact source identities and results are in ignored `TestBuilds/r275/validation.json`.

## R276 Total/Omni fixture refresh

The older Total/Omni fixture had no output endpoint. Reviewed setup now requires one, so the fixture never activated its controls.
The fixture now supplies the paired endpoint and checks that input activation succeeds.
Expected binding and light counts follow the existing 46-input/eight-output recipe. The source-backed browser and manual-loop controls are no longer listed as unsupported.
The remaining unsupported-address check still rejects the two inactive mode keys. Runtime recipes stay unchanged.
All five focused Swift tests pass. The runtime resource remains byte-for-byte unchanged.
This resolves the older Numark fixture failure seen during R275. It adds no controller coverage or physical acceptance claim.
Source hashes and the exact log are in ignored `TestBuilds/r276/validation.json`.

## R277 Radius 2000 player core

The [factory manual](https://www.adj.eu/mwdownloads/download/link/id/49), pages 20 and 35–36, documents default MIDI channel 1, relative encoders and full pitch-bend pitch.
The automatic core uses those defaults. Other hardware channels and encoder modes remain open.
The earlier CH1 profile identity stays unchanged. Native player assignment replaces the pinned CH1/CH2 variants' hard-coded deck groups, so two units can control separate decks.
Radius 1000 and 3000 remain separate models.

Native held Cue, bend, full pitch, four cues, manual loops, Reloop and loop size controls retain published addresses.
The source BPM key remains native Sync; its sample-loop key enables a native four-beat loop.
Native Play acts on press. Track encoder press loads once; the source's physical USB Source Select Load alias stays inactive.
Folder press enters a native group. The factory TAP addresses release old held controls and rearm normal cues without invoking alternate presses.
Fixed physical-touch scratch uses full-value contact and signed raw-minus-64 motion.
Effective 990 native counts preserve the source's unusual 100-count/330-RPM time response. This does not establish physical calibration for the factory 1024/512 sensor settings.
The source half-strength unheld nudge response remains a separate calibration gap.

Seven steady lights use factory primary addresses. Thirty-one primary light addresses use 62 lifecycle messages, with fixed Scratch and pitch indication.
Player light targets now follow automatic deck assignment, reassignment and reconnect. Physical output addresses and global targets stay unchanged.
Secondary cue lights, rings, displays, full FX/modes/feedback/reset, audio routing and physical acceptance remain open.
All eight focused Swift tests, four existing player/feedback checks, 108 importer checks and native iPad framework compilation pass.
Fixtures cover two physical players, default-channel isolation, TAP releases, full pitch, source-scaled scratch, saved Sync and light reassignment.
Manual light mapping follows the destination device when another input is selected. Custom mappings survive reassignment and reconnect.
The first host compile caught two incorrect action names in the new recipe and fixture; these now use the existing Loop Down/Up contracts. The failed compile log remains preserved.
All 166 other recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage reaches 147 physical models. Benchmark coverage remains 62/122; complete theoretical parity remains open.
Repository checks retain twelve existing historical-link failures. No signed app, installation or physical acceptance occurred.
Exact source identities and results are in ignored `TestBuilds/r277/validation.json`.

## R278 original DJ2GO2 core

The original DJ2GO2 now has a separate automatic core from [Numark's published Traktor mapping](https://www.numark.com/images/product_downloads/Numark_DJ2GO2_Performance_Map.tsi.zip).
Its device comment and ports identify the original model. The [factory guide](https://www.numark.com/images/product_downloads/DJ2GO2_UserGuide_v1.2.pdf), page 4, documents class-compliant USB and the physical control/pad meanings.
Touch keeps its own profile. The original gains no touch contact, Touch status query, inferred wheel-count scale or automatic numbered audio layout.

Factory input definitions set both wheel encoders and Browse to signed 7Fh/01h format.
The [pinned TSI binary template](https://raw.githubusercontent.com/ivanz/TraktorMappingFileFormat/df5f544d10e3293b72b829841e654da0db71c4b0/Tools/TSI%20Mapping%20Template.bt) defines the stored encoder-mode value.
Native wheel seek/nudge uses that format. Physical wheel sensitivity and pitch/gain response remain open for calibration.
Play, held Cue, Sync, PFL, seven-bit pitch and direct Load retain published addresses. Channel Gain and Browse press follow factory labels through native gain and group entry.
Native master/headphone levels use their existing ranges instead of Traktor's stored output scaling.

Distinct pad addresses provide four cues, automatic 1/2/4/8-beat loops and manual In/Out/On-Off.
These restore the factory guide's meanings in place of the Traktor file's custom loop-size and FX assignments.
Manual Retrigger and sampler pads stay inactive. Latched browser and wheel-FX modifiers do not run.
Sixteen steady transport/PFL/cue states use source output addresses and 32 lifecycle messages. Full animations and firmware-driven light cleanup remain open.
All twelve focused Swift tests, 109 importer checks and native iPad framework compilation pass.
The real-file fixture checks non-touch wheel motion, held Cue release, automatic/manual loops and saved Sync.
Touch identity, setup and its distinct positive-64 jog rule remain covered separately.
All 167 existing recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage reaches 148 physical models, including 63/122 benchmark models. Complete theoretical parity remains open.
Repository checks retain twelve existing historical-link failures. No signed app, installation or physical acceptance occurred.
Exact source hashes, parsed wire facts and results are in ignored `TestBuilds/r278/validation.json`.

## R279 Terminal Mix 8 core

The [factory MIDI table](https://www.reloop.com/media/custom/upload/Reloop-TM8_MIDI-Map.pdf) assigns four deck channels and four separate pad channels.
The published firmware-0.19-or-later Traktor file confirms dedicated Load reports on each deck channel and centre-64 wheel encoders.
Native deck targets preserve the app's existing four-deck choice. Terminal Mix 2/4 stays separate.
No sibling wheel-count scale is inferred: physical touch Scratch and rim nudge use native default calibration, which still needs a physical check.
The Hold stream and shifted wheel motion remain inactive. Published contact-release aliases clear old touch ownership when those streams change.

Each side has one physical Shift identity across its two deck banks. Mixer and pad layers stay local to that side; layer changes restore pickup.
Only a bank press clears that side's old contacts and pickup. Releasing the bank key must not interrupt a newly held Cue.
The factory TAP-style alternate addresses release old buttons and rearm cues without executing clear/seek actions.
Key Lock follows the manufacturer's Traktor assignment on shifted note 89. Full pitch and mixer/filter controls retain factory addresses.
Eight cue pads use the dedicated cue page. Four Loop-page pads retain the published Traktor In/Out/Halve/Double layout.
Stored loops, move/roll controls, sampler, slicer, dual pages and held cue preview remain open.

The factory RGB palette defines white as 19 and off as zero. Mono transport/PFL states retain source 127/zero.
Published pickup SysEx, 52 owned light states, four meter clears and four listed FX clears use 61 lifecycle messages.
VU feedback, full animation/cleanup and other FX stay open.
Factory fader-start Cue/Play shares the normal transport addresses. Those packets cannot be distinguished; fader-start use remains unqualified.
The [Traktor audio guide](https://www.reloop.com/media/custom/upload/Reloop-TM8_HowtoTraktor_web.pdf) uses FRONT for Mac monitor output and BACK for master.
That does not qualify a numbered iPad layout. Automatic audio selection remains disabled.
All fifteen focused Swift tests, 110 importer checks and native iPad framework compilation pass.
Fixtures cover four explicit Load targets, app deck availability, physical Shift across banks, pickup, contact releases, the RGB palette and bank-key release.
The real-file fixture verifies native count motion, bank cleanup, later touch ownership and saved Sync.
The first compile caught incorrect fixture access to a private dependency; the fixture now passes that dependency through the existing constructor.
A later fixture counted expected jog-neutral bank cleanup as a mixer event. Its corrected assertion checks the intended mixer action. Both failed logs remain preserved.
All 168 existing recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage reaches 149 physical models, including 64/122 benchmark models. Complete theoretical parity remains open.
Repository checks retain twelve existing historical-link failures. No signed app, installation or physical acceptance occurred.
Exact source identities, parsed wire facts and results are in ignored `TestBuilds/r279/validation.json`.

## R280 Mixtrack Quad core

Numark publishes both [VirtualDJ device/mapping XML](https://www.numark.com/images/product_downloads/Mixtrack_Quad_VDJ_Pro.zip) and a [Traktor mapping with guide](https://www.numark.com/images/product_downloads/MixTrack_Quad_Traktor_Pro_Map.zip).
The device XML supplies four deck wire channels 1–4, separate Load addresses and a 600-count jog scale.
Factory Traktor input definitions confirm signed 7Fh/01h wheel and browser reports.
The native core retains those facts, inverse pitch/crossfader polarity and exact raw-64 EQ centre.
It adds no gain knobs or automatic four-deck choice.

Each side retains one physical Shift identity across its two deck banks. Bank presses clear that side's contacts and pickup; bank-key release cannot stop a later Cue.
Normal held bend uses the shared native four-percent response. Shifted Pitch Bend Down toggles Key Lock; key range remains open.
Shift blocks wheel and pad-mode/clear actions while dedicated mixer controls remain active.
Fixed native Scratch replaces the software mode switch. Four cue pads and manual-loop addresses stay separate from sampler notes.
Native Out-or-Exit follows the factory guide. Reloop creation fallback, colour selection, deletion latches, samples, rolls and FX stay open.

Native cue lights use source value 5/off zero. The loop-state light uses source value 8/off zero.
Published setup, fixed Scratch lamps and reviewed transport/jog cleanup use 61 lifecycle messages.
The source's CC60 send strings include trailing padding; native setup sends the three complete MIDI bytes only.
Full feedback, animation and firmware-driven cleanup remain open.
The guide's first-page screenshots explicitly give Mac master 1–2/Front and headphones 3–4/Back, with matching numbered Windows routing.
The [manufacturer](https://www.numark.com/product/mixtrack-quad) documents class-compliant operation. The shared automatic split route now applies to this model.
Physical USB/audio acceptance and gain/pitch/jog calibration remain open.
All ten focused Swift tests, including 24 parameterised audio cases, 111 importer checks and native iPad framework compilation pass.
The first Python run found an older expected audio-device list that omitted Quad. The corrected list passes; the failed log remains preserved.
The real-file fixture checks 600-count motion, bend release across Shift, continuing playback, bank cleanup and saved Sync.
Audio fixtures check repeated detection, unchanged samples and recovery without falling back to speakers.
All 169 existing recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage reaches 150 physical models, including 65/122 benchmark models. Complete theoretical parity remains open.
Repository checks retain twelve existing historical-link failures. No signed app, installation or physical acceptance occurred.
Exact source identities and results are in ignored `TestBuilds/r280/validation.json`.

## R281 Original i-Mix Reload core

The [factory manual](https://asset.conrad.com/media10/add/160267/c1/-/gl/000060106ML01/mode-demploi-060106-console-de-mixage-mp3-dj-tech-imix-reload.pdf) and pinned Mixxx mapping disagree on touch and Load addresses.
The factory table also omits two key rows and repeats a Hot Cue/EQ-kill address.
This recipe stays manual and names the published source variant. MKII remains separate.
Manual application loads bindings. It does not activate an input or run automatic setup/shutdown.

The native decoder accepts one count per positive direction note. It ignores Note-Off, zero velocity, malformed values and expanded MIDI values.
Touched direction notes require that deck's source contact. Untouched wheel notes remain separate from Search notes.
The source's 148-count scale controls native scratch, wheel nudge and paused seek. Release callbacks cannot add motion.
Native held Cue, three guarded cues, direct source-variant Load, gain/EQ/level, inverse tempo and browser steps retain the reviewed addresses.
Loop-size buttons follow physical minus/plus labels. Source sampler buttons do not become invented cue pads.
Sixteen steady feedback outputs and 54 bounded lifecycle messages retain source addresses.
Full modes, Search, first-stopped Load, FX, EQ kills, complete feedback/reset and physical acceptance remain open.
Factory/source identity conflict blocks automatic selection. This increment does not add an automatic model.
All ten focused Swift tests, 112 importer checks and native iPad framework compilation pass.
The real-file fixture checks count-scaled motion, ignored release reports, touch cleanup, held Cue and saved Sync.
The first test compile used a private fixture property. The corrected fixture uses the public application path. The failed log remains preserved.
All 169 other recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage stays at 150 physical models, including 65/122 benchmark models. Complete theoretical parity remains open.
Repository checks retain twelve existing historical-link failures. No signed app, installation or physical acceptance occurred.
Exact source identities and results are in ignored `TestBuilds/r281/validation.json`.

## R282 MCX8000 factory-addressed manual controls

The [factory command list](https://cdn.inmusicbrands.com/denondj/MCX8000/Denon_DJ_MCX8000_MIDI_Command_List_v1.0.pdf) supplies separate transport/mixer, loop and global addresses.
The manual recipe retains four explicit Load targets, held Cue/bend, native loops, gain/EQ/filter/level and crossfader.
Release-only shifted aliases end owned Cue/bend contacts. Positive shifted commands cannot trigger their normal actions.
Other deck targets remain isolated. C/D require app deck availability.
Twenty-four normal button feedback outputs use 48 bounded lifecycle messages. Manual apply does not activate an input or run lifecycle.

The chart gives jog and browser addresses without their value encoding.
Its pitch LSB/MSB labels also need independent confirmation because working mappings for related Denon models reverse factory labels.
Those controls remain inactive. Shared pad addresses need mode state before they can safely become native cue pads.
Shift/bank/source-selector ownership, FX, meters, rings, screens, complete feedback/reset, connection/audio routing and full parity remain open.
No sibling jog encoding, pitch order or application-connect packet is copied.
Automatic selection remains disabled. This subset does not add an automatic benchmark model.

All seven focused Swift tests, 113 importer checks and native iPad framework compilation pass.
The real-file fixture verifies Cue release, shifted bend release, continuing loop playback, finite audio and saved Sync.
All 170 existing recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage stays at 150 physical models, including 65/122 benchmark models.
Repository checks retain twelve historical-link failures. No signed app, installation or physical acceptance occurred.
Exact source identities and results are in ignored `TestBuilds/r282/validation.json`.

## R283 MIX-101 source encoder controls

The pinned [MIX-101 XML](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20Mix-101.midi.xml) defines two fast relative volume encoders.
The matching [decoder source](https://github.com/mixxxdj/mixxx/blob/20f2c218ae1b762ac39fd76ff408c8428056f4f7/src/controllers/midi/midicontroller.cpp) specifies `(raw - 64) * 1.5`.
Native decoding preserves that scale for current master/headphone values, including queued reports and endpoint clamps.
Factory validation restricts this decoder to reviewed control-change volume actions. MIDI learning cannot select it.

The manual source profile now includes both published unheld wheel streams. They use native nudge/paused seek and default calibration.
It retains gain/EQ/level, crossfader, browser, transport and PFL. Play A receives note 9 and sends feedback on note 10.
Held Cue accepts zero-velocity and Note-Off releases. No touch input, tempo fader, audio interface or cue pads are inferred.
The [factory guide](https://www.bhphotovideo.com/lit_files/652696.pdf) describes one banked wheel with mode-dependent controls.
Hardware deck/mode ownership, shared Load, sampler holds, other MIDI channels, complete feedback/reset and physical calibration remain open.
Automatic selection stays disabled. Manual apply does not activate an input or run automatic lifecycle.
All eight focused Swift tests, 114 importer checks and native iPad framework compilation pass.
Fixtures cover every seven-bit encoder value, queued accumulation, endpoint clamps, invalid values and both Cue release forms.
The real-file fixture verifies unheld wheel handling, finite audio, Cue cleanup and saved Sync.
The first test compile lacked the actor annotation for a feedback assertion. The corrected fixture passes. The failed log remains preserved.
All 170 other recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage stays at 150 physical models, including 65/122 benchmark models.
Repository checks retain twelve historical-link failures. No signed app, installation or physical acceptance occurred.
Exact source identities and results are in ignored `TestBuilds/r283/validation.json`.

## R284 Configured TEK2 native controls

The [mapping author](https://manual.mixxx.org/2.5/en/hardware/controllers/intech_tek2) requires the `TEK2 DJ setup` preset through Grid Editor.
Endpoint names cannot identify the installed preset. This recipe stays manual and separate from generic Intech Grid devices.
The source supplies raw-64 wheels, exact-full-value contact, Play and held Cue for each deck.
Native fixed scratch uses the published 100-count scale. A separate unheld path shares each wheel address.
Touch ownership blocks that unheld path in playback, so one report cannot move a touched deck twice.
Unheld paused seek uses 160 effective counts. Playing nudge uses the shared native response; the source runtime's exact velocity response remains open.

The source has no setup, shutdown or output messages. No LED protocol, audio interface, Load, mixer or tempo controls are invented.
Bottom-row keys, five-point LEDs, preset upload/query, full documented controls and physical calibration remain open.
Manual apply does not activate an input.
All five focused Swift tests, 115 importer checks and native iPad framework compilation pass.
The real-file fixture verifies exact count motion without duplicate movement, finite audio, touch release, Cue release and saved Sync.
All 170 other recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage stays at 150 physical models, including 65/122 benchmark models. Complete theoretical parity remains open.
Repository checks retain twelve historical-link failures. No signed app, installation or physical acceptance occurred.
Exact source identities and results are in ignored `TestBuilds/r284/validation.json`.

## R285 KDJ500 translated-MIDI source core

The manufacturer's [legacy archive](https://drive.google.com/drive/folders/0B09d9nFit33wdUpIZk5OZ0wxRTA?resourcekey=0-XMiDZ5xFAkwVGGXeSgbb6w) contains its manual, Traktor settings and open SDK.
The manual requires a USB driver and Konverter to translate native reports into MIDI. The SDK describes eight-byte USB frames.
The catalogue now records this connection boundary. A stored recipe does not supply direct iPad USB support.
The SDK and factory files remain cached as evidence. No vendor binaries run in the app.

The manual native recipe retains all 27 inputs from the pinned Mixxx layout.
Wheels and browser encoders accept only source value 127 forward and 1 backward. Other values remain inactive.
It retains two explicit Load targets, held Cue, PFL, gain/EQ/level, inverse tempo and crossfader.
Two physical loop keys toggle fixed eight-beat loops. No cue pads or touch sensor are invented.
The source has no output, setup or shutdown messages. Physical Shift/banks, other controls, LEDs, full lifecycle, bridge and calibration remain open.
Manual apply does not activate an input. Automatic selection stays disabled.

All six focused Swift tests, 116 importer checks and native iPad framework compilation pass.
The real-file fixture verifies Cue release, exact eight-beat loop selection/toggle, finite audio, continuing playback and saved Sync.
All 170 other recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage stays at 150 physical models, including 65/122 benchmark models. Complete theoretical parity remains open.
Repository checks retain twelve historical-link failures. No signed app, installation or physical acceptance occurred.
Exact factory file identities and results are in ignored `TestBuilds/r285/validation.json`.

## R286 Non-Pro U-Mix Control 2 core

The [factory MIDI tables](https://manuals.plus/m/534f13fed15e77a7709306d246918757539a81c8a352f65475210943d6a927f9.pdf) distinguish the non-touch Control 2 from the original touch-sensitive Pro.
The reviewed core retains non-touch wheels, centred pitch, six cues, source Load, mixer, loop push/rotation and browser controls.
Shift blocks unsupported layers. Release-only aliases end owned Cue/bend contacts without triggering normal or delete actions.
Factory feedback uses steady values 127/0. Setup/shutdown use 62 bounded messages.

The pinned source supplies Load A as Note 5. The factory table labels it CC 5. This recipe retains the working source form.
The separate factory loop push and signed rotation correct the source's incomplete loop rows.
No Pro touch/rim, Pro 2 sensor scale, audio interface or headphone knob is inferred.
Full pitch/Vinyl/FX/EQ-kill modes, held cue-pad preview, animation, full reset and calibration remain open.
All seven focused Swift tests, 117 importer checks and native iPad framework compilation pass.
The real-file fixture verifies shifted Cue/bend release, native loop size, continuing playback, finite audio and saved Sync.
The first generic fixture expected another automatic profile. Inspection showed that the earlier partial recipe already selected automatically.
Its coverage expectation stays unchanged. The failed log remains preserved.
All 170 other recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage stays at 150 physical models, including 65/122 benchmark models. Complete theoretical parity remains open.
Repository checks retain twelve historical-link failures. No signed app, installation or physical acceptance occurred.
Exact source identities, new research files and results are in ignored `TestBuilds/r286/validation.json`.

## R287 Original U-Mix Control Pro core

The [factory hardware guide](https://media.djmania.net/manuales/pdf/U-MIX_CONTROL_PRO_1.5.1_user_manual_0.pdf) identifies the original Pro and documents its internal-mixer audio route.
The [factory MIDI appendix](https://manuals.plus/m/534f13fed15e77a7709306d246918757539a81c8a352f65475210943d6a927f9.pdf) distinguishes its touch and rim reports from non-Pro Control 2.
The catalogue now includes this separate physical model. Pro 2 remains a separate identity.
Native fixed scratch uses full-value touch and default 1024-count calibration. No original-Pro sensor count is published.

This recipe follows the factory CC 5 Load A row. It accepts the first positive CC press and rejects repeated held reports.
Control 2 retains its published working Note 5. The conflicting Load formats remain explicit.
Shared shifted-release mappings now rearm all normal buttons, including Play and Load, on both original models.
Positive shifted reports cannot trigger the normal actions.
The original Pro adds its documented monitor-blend control. Hardware headphone volume stays separate.
Factory Dual Stereo routing supplies master 1–2 and headphones 3–4. Mac installation needs no separate driver in the guide.
Only this internal route is declared. External mixing, capture/input switching and physical USB/audio acceptance remain open.

Both original models retain six cues, native loops, bounded steady feedback and 62 lifecycle messages.
Full Pitch Mode/Vinyl/FX/EQ-kill modes, held cue-pad preview, animation, complete reset and jog calibration remain open.
All fifteen focused Swift tests, including 26 parameterised audio cases, 118 importer checks and native iPad framework compilation pass.
Real-file fixtures verify count-scaled touch motion, rim suppression, Shift cleanup, loops and saved Sync on both original models.
Audio fixtures verify repeated detection, unchanged samples and recovery without speaker fallback.
The first Python run counted new release-only Load aliases as new press bindings. The corrected assertion checks normal press bindings. The failed log remains preserved.
All 170 other recipes remain unchanged. The bundled resource matches the source.
Automatic core coverage reaches 151 physical models, including 65/122 benchmark models. Complete theoretical parity remains open.
Repository checks retain twelve historical-link failures. No signed app, installation or physical acceptance occurred.
Exact source identities and results are in ignored `TestBuilds/r287/validation.json`.

## R288 T7 and Mixon 8 public source boundaries

The [public T7 XML](https://community.algoriddim.com/t/hercules-inpulse-t7-support/20172/186) has 402 control rows, two outputs and a named `HerculesDJControlInpulseT7` custom class.
Its shared file does not contain that app class. Motor/platter reports, startup and lifecycle still need a qualified implementation.
The [Mixon 8 author mapping](https://community.algoriddim.com/t/reloop-mixon-8-ultimate-stems-mapping/20579) has 895 controls, 24 outputs and a named `ReloopMixon8` custom class.
That class is absent too. The file does not establish jog/pitch dispatch or cold-start lifecycle.
Its author also reports incompatibility after firmware 49.36. This version predates that update.

The catalogue now records these sources, exact hashes, row counts and limits beside each model.
The files remain research evidence. They do not select a profile, run vendor code or add automatic/full support.
Stealth's earlier R257 channel/encoder qualification hold and RANE FOUR's R245 experimental-source hold remain in force.
All 119 importer checks pass, including checks that these source audits cannot promote automatic or complete support.
All 172 runtime recipes remain byte-for-byte unchanged. No new native compilation was required for this metadata change.
Automatic core coverage stays at 151 physical models, including 65/122 benchmark models. Complete theoretical parity remains open.
Repository checks retain twelve historical-link failures. No signed app, installation or physical acceptance occurred.
Exact source identities and results are in ignored `TestBuilds/r288/validation.json`.

## R289 original Mixtour factory core

Assumption: the original Mixtour uses its factory MIDI configuration. Mixtour Pro is a separate model.
Reloop's chart and published Traktor mapping supply the wire facts. No vendor code runs in the app.
The Beatpad 2 chart was also retrieved, but it omits base transport/jog facts. It does not justify an original-Beatpad alias.

Implementation plan and checks:

- [x] Add failing native fixtures for automatic original-model detection, separate transport/cue addresses, held Cue, shifted releases, mixer pickup, signed browsing and lifecycle failure/reconnect.
- [x] Add a small `mixtour.py` recipe and source reference. Register it in the catalogue builder. Retain unsupported shifted presses and fader-start as inactive.
- [x] Verify normal Play/Sync/PFL/Loop and cue feedback against factory addresses and colours. Keep all lifecycle traffic within the existing bound.
- [x] Run importer checks, the focused Swift fixtures and iPad framework compilation. Compare the bundled resource and all other recipes.
- [x] Record source hashes, results and remaining limits, then commit the coherent change.

The existing typed profile, input and feedback boundaries are sufficient. No audio-rendering or view code needs to change.
The factory outbound SysEx disables demo mode. The Traktor MIDI definitions specify 7Fh/01h relative browsing.
Audio channel order, full modes/feedback, calibration and physical acceptance remain open until separately qualified.

The new recipe has 64 inputs, 18 outputs and 51 lifecycle packets. It selects automatically for the original Mixtour.
Transport uses orange feedback and the four-cue page uses green. Mode changes release only the affected deck.
The factory chart, mapping archive, extracted TSI and binary-format reference retain SHA-256 identities in the generator.

All 10 focused Swift checks, 120 importer checks and native iPad framework compilation pass.
The compiled resource matches the source. All 172 earlier recipes remain unchanged.
The first fixture compile needed a missing actor annotation. Initial assertions also needed the existing normalised browser callback and the newly supported inventory entry.
Those failed logs and the expected pre-implementation failures remain in `TestBuilds/r289/`.
Inline review retained the repository's serial-work rule; no reviewer agent was started.
The repository check retains twelve historical broken links.
Factory coverage reaches 138 profiles for 146 physical models, plus six other native models. The benchmark remains 65/122.
Source base: `90b8822`. No signed app, install, hardware test or A10X acceptance forms part of this increment.

## R290 separate Beatpad 2 core

Assumption: Beatpad 2 uses the factory MIDI configuration and firmware 0.17 or later, as specified by Reloop's published mapping.
It keeps a separate identity from the original Beatpad. Its factory chart defines separate EQ and pad-page messages.
The companion factory Traktor mapping supplies the omitted normal transport, full pitch, contact and relative encoder definitions.
No vendor script, binary or Traktor settings run in the app.

Implementation plan and checks:

- [x] Verify expected failures for automatic separate-model detection and normal transport, touch/jog, pitch, EQ and cue pages.
- [x] Add `beatpad2.py` and register its hashed chart/mapping sources. Keep the two deck, two pad and global wire channels explicit.
- [x] Use known Shift reports to release contacts and rearm pickup/debounce. Guard the published fader-start Play-address collision.
- [x] Retain only reviewed loop actions and steady feedback. Keep other velocity, aftertouch, sampler and FX pages inactive.
- [x] Run importer checks, focused native fixtures, real-file playback and iPad framework compilation; verify the bundled resource and unchanged prior recipes.

The native default jog resolution remains subject to calibration. Audio order, complete EQ-mode reset ownership, other pad functions, shifted transport alternatives, lifecycle and physical acceptance remain open.

The recipe has 93 inputs and 26 steady outputs. It sends no unverified startup packet and clears only its owned outputs on shutdown.
Active deck definitions specify centre-64 jogs. The active mixer definition specifies centre-64 browse; stale copies in other TSI device records do not override these facts.
Shift presses and explicit Note Off releases clean contacts and input state. Independent Shift identities retain a shared held layer.
A Note On zero release clears that Shift input normally; input state is already rearmed by its press.

All 17 focused Swift checks, 121 importer checks and native iPad framework compilation pass.
The compiled resource matches the source. All 173 earlier recipes remain unchanged.
The first native run rejected the recipe because note-bank rules require an explicit positive trigger value.
That failed log and the expected pre-implementation failures remain in `TestBuilds/r290/`.
The review also removed an assumption about the order of independent contact releases.
Inline review retained the repository's serial-work rule; no reviewer agent was started.
The repository check retains twelve historical broken links.
Factory coverage reaches 139 profiles for 147 physical models, plus six other native models. The benchmark remains 65/122.
Source base: `dc10926`. Sources were retrieved in `TestBuilds/r289/manufacturer/`; validation is in `TestBuilds/r290/`.
No signed app, install, controller hardware test or A10X acceptance forms part of this increment.

## R291 Mixtour and Beatpad 2 split audio

Assumption: the controller retains its factory four-channel USB audio layout. The factory Traktor files name `Reloop ASIO` and select internal mixing.
Both files explicitly assign zero-based Master Left/Right 0/1 and Monitor Left/Right 2/3 in the ordinary and FS routing records.
External-mixer records are inactive and do not define this route. No source settings or software runs in the app.

Implementation plan and checks:

- [x] Add expected failures for automatic split-output selection and both recovery/sample-preservation fixtures.
- [x] Verify the pinned factory routing entries and declare only the existing `masterAndHeadphones` route in both recipes.
- [x] Run focused native routing/controller checks, importer checks and iPad framework compilation. Check the compiled resource and exact scope of recipe changes.

This qualifies source-level routing only. Physical iPad USB enumeration, cables, channel order, headphone/master separation and A10X performance remain unverified.

Both recipes now declare the reviewed master/headphone split. Their MIDI bindings and lifecycle bytes remain unchanged.
All 21 focused Swift checks pass, including 30 parameterised recovery/sample-preservation cases.
All 122 importer checks and native iPad framework compilation pass. The compiled resource matches the source.
Only the two intended runtime recipes changed; the other 172 recipes remain unchanged.
The first importer run found the older expected audio-model set; the fixture now includes both qualified models. The failed log is preserved.
The repository check retains twelve historical broken links. Source base: `949bc69`. Evidence: `TestBuilds/r291/`.
No signed app, install, controller hardware test or A10X acceptance forms part of this increment.

## R292 Mixtour Pro public-source core

Assumption: reuse only unconditional normal-control records from the author's public Mixtour Pro SJ2 mapping.
The file declares a missing `ReloopMixtourPro` app class. It does not establish cold-start negotiation or pad/deck mode ownership.
Automatic selection therefore stays off. Manual profile application also requires the user to enable its MIDI input.

Implementation plan and checks:

- [x] Add failing fixtures for separate manual identity, four explicit targets, held Cue, pickup, inverted centre-64 browsing and source feedback values.
- [x] Add `mixtour_pro.py`, pin the source hash and class boundary, then register its manual transport/mixer/browse subset.
- [x] Keep shared conditional pads, loop-state combinations, shifted actions, FX, setup and audio routing inactive.
- [x] Run importer checks, focused native protocol/playback checks and iPad framework compilation. Compare the bundle and all previous recipes.

This does not copy the original Mixtour protocol. The public mapping has 744 control rows and four meter outputs, plus per-control output records.
Only plain normal records enter the native recipe. No vendor code runs in the app.

The manual recipe has 47 inputs and 12 steady output definitions. It sends no unverified startup packet.
A/B transport lights retain source on6/off2; C/D retain on5/off1. PFL lights and meter output remain unmapped.
The source's library source/back keys have no reviewed matching native action, so they also remain inactive.
Manual input and light mappings load separately. The user must enable each path. Manual application does not run automatic lifecycle packets.

All nine focused Swift checks, 123 importer checks and native iPad framework compilation pass.
The compiled resource matches the source. All 174 earlier recipes remain unchanged.
The source check caught the A/B versus C/D feedback difference. A focused failing comparison now covers that correction.
A later native run caught a fixture's ordering assumption about two queued controls; it now checks each target independently.
Both failed logs and the expected pre-implementation failures remain in `TestBuilds/r292/`.
The repository check retains twelve historical broken links. Inline review followed the serial-work rule; no reviewer agent was started.
The catalogue retains 313 records for 306 physical models and now has 175 data recipes plus five code profiles.
Automatic core coverage stays at 147 factory physical models plus six other native models; the benchmark stays 65/122.
Source base: `bd51935`. Source cache: `TestBuilds/r291/manufacturer/`. Validation: `TestBuilds/r292/`.
No signed app, install, controller hardware test or A10X acceptance forms part of this increment.

## R293 Electrix Tweaker fixed A/B core

Assumption: the controller retains its factory MIDI assignments. Use its USB `Tweaker MIDI 1` port, not the DIN `Tweaker MIDI 2` port.
The pinned source programs six absolute EQ encoders and local rings. Its default-settings SysEx block is commented out and must not run.
The native recipe fixes the software banks to A/B and EQ. Unsupported bank/mode keys cannot change those assignments.

Implementation plan and checks:

- [x] Add failing native fixtures for port isolation, fixed A/B controls, Top Shift versus deck Shift, held Cue release, EQ pickup and lifecycle failure/reconnect.
- [x] Add `electrix_tweaker.py` and source hashes. Reuse existing composite Shift groups, typed actions and bounded startup/feedback.
- [x] Verify eight normal cues, normal/shifted beat jumps and manual loop boundaries. Keep unsupported sampler, Slip, extra cue/deck banks and encoder modes inactive.
- [x] Run importer checks, focused native playback/protocol checks and iPad framework compilation. Compare the bundle and all previous recipes.

Ruling: use separate pure-deck and Top-or-deck Shift groups, as already supported by the Xone adapter.
This preserves modifier priority without a new state engine or changes to live audio code.
Normal Play is blocked by Top Shift. Deck Shift+Play uses held Cue, including the source's deck-Shift priority when both modifiers are held.
Native Cue release keeps the app's existing return-to-cue behaviour. The source's continue-playing-on-Shift-release variation remains open.
No audio interface, four-deck switching or source-specific fader/EQ curve is inferred.

The recipe has 67 inputs, 30 feedback definitions and a 62-packet lifecycle. It claims only the paired USB MIDI1 port.
Setup failure leaves input inactive. Repeated discovery does not repeat setup; reconnect restores it.
A/B stay fixed when unsupported bank/encoder-mode keys are pressed. EQ feedback retains the programmed encoder positions and local rings.
The first native check rejected argument-bearing generic jump actions. The recipe now uses the existing signed `fixedJump` contract.
The failed run and expected pre-implementation failures remain in `TestBuilds/r293/`.

All ten focused Swift checks, 124 importer checks and native iPad framework compilation pass.
The compiled resource matches the source. Only the previous Tweaker partial recipe changed; all 174 other recipes remain unchanged.
Factory coverage reaches 140 profiles for 148 physical models, plus six other native models. The benchmark remains 65/122.
The repository check retains twelve historical broken links. Inline review followed the serial-work rule; no reviewer agent was started.
Source base: `d32470e`. Evidence: `TestBuilds/r293/`.
No signed app, install, controller hardware test or A10X acceptance forms part of this increment.

## R294 T7 public protocol and manual core

Assumption: reuse normal MIDI wire facts from the public T7 beta at revision `1ec59320c4ccf5681d5a989d9b7d0447da48aa69`.
The author reports hardware checks on Windows. Mac, Linux, current reconnect/lifecycle changes and main speaker output retain stated limits.
The earlier public djay mapping independently agrees on normal Play, Cue, Sync, volume, gain and EQ addresses.

Implementation plan and checks:

- [x] Add failing native fixtures for separate manual identity, held Cue/bend releases, exact CC pairs, source pad pages and source encoder directions.
- [x] Pin all four source files. Add `hercules_t7.py` for ordinary transport/mixer/loop/cue controls and update the earlier source audit.
- [x] Keep platter position CC9 and pitch-bend timestamps unmapped. Emit no motor command, speed command or unqualified setup.
- [x] Run importer checks, focused native playback/protocol checks and iPad framework compilation. Compare the bundle and all previous recipes.

Ruling: automatic selection stays off until a native motor/velocity handover exists.
The public protocol documents 7-bit wrapping platter positions, 14-bit timestamps at 2.4 MHz, motor Note127 and paired motor-speed CC8/40.
Those output speed bytes also identify incoming tempo-fader bytes. Direction and endpoint ownership must remain explicit.
A generic pitch-bend tempo mapping or count-only jog would be incorrect. No platter timestamp can enter native tempo control.
Crossfader curve/disable ownership, FX, stems, full pad feedback, full lifecycle and audio routing remain open.

The manual recipe has 153 inputs and 24 steady button outputs. It emits no setup, platter or motor command.
Normal and shifted tempo/level pairs stay explicit. Pitch-bend timestamps and platter-position reports cannot change native tempo or jog state.
The first fixture assumed that ordinary paired CC required two fresh bytes. It now checks the existing cached-pair contract and deck isolation.
The failed log and expected pre-implementation failures remain in `TestBuilds/r294/`.
Native loop sizing retains the app's 1/32-to32-beat bounds. The source encoder's larger range remains open.
Manual MIDI input and feedback require separate loading and enabling. No automatic lifecycle runs for this recipe.

All 17 focused Swift checks, 125 importer checks and native iPad framework compilation pass.
The compiled resource matches the source. All 175 earlier recipes remain unchanged.
The catalogue now has 176 data recipes. Automatic coverage remains 148 factory physical models plus six other native models; the benchmark stays 65/122.
The repository check retains twelve historical broken links. Inline review followed the serial-work rule; no reviewer agent was started.
Source base: `c8196d3`. Sources and evidence: `TestBuilds/r294/`.
No signed app, install, controller hardware test or A10X acceptance forms part of this increment.

## R295 Buddy manual source subset

Assumption: reuse only unconditional normal controls from Maurizio T's public Buddy mapping.
The author changed EQ, shifted loop gain and some Hot Cues. Shared modes and the absent `ReloopBuddy` class remain unqualified.
The Backspn Buddy profile conflicts with this file on Play, Cue and high-resolution pitch. Do not use it as automatic support evidence.

Implementation plan and checks:

- [x] Add failing fixtures for separate manual identity, normal transport, cross-address Cue releases, mixer pickup and inactive shared controls.
- [x] Pin the author file and conflicting profile. Add a manual Buddy recipe with no inferred lights, setup, jog or pitch protocol.
- [x] Run importer checks, focused native playback/protocol checks and iPad framework compilation. Compare all earlier recipes and the bundle.

The manual recipe has 21 inputs and no output or lifecycle packet. Alternate transport addresses release normal holds without enabling shifted presses.
The author's changed EQ and conditional Hot Cues remain inactive. PFL/Sync outputs omit explicit maxima; no feedback value is guessed.
The source's rotary64 browse convention matches the reviewed djay convention. The native recipe retains its inverted direction.
Manual application requires separate input enabling. No Ready profile, paired pitch, jog resolution, custom class or automatic audio route is inferred.

All seven focused Swift checks, 126 importer checks and native iPad framework compilation pass.
The compiled resource matches the source. All 176 earlier recipes remain unchanged.
The catalogue now has 177 data recipes. Automatic core coverage stays at 154 physical models; the benchmark remains65/122.
The initial native check could not find the temporary directory after the host restart. Its retry produced the expected missing-profile failure.
Both logs and expected importer failures remain in `TestBuilds/r295/`. The repository check retains twelve historical broken links.
Inline review followed the serial-work rule; no reviewer agent was started.
Source base: `0a5c395`. Primary source: [author upload](https://community.algoriddim.com/t/midi-mapping-for-reloop-buddy/15528).
No signed app, install, controller hardware test or A10X acceptance forms part of this increment.

## R296 PRIMO manufacturer table boundary

The [manufacturer manual](https://mixars.com/wp-content/uploads/2022/11/primo-manual-en-fr-d-it-es.pdf) contains MIDI tables on PDF pages45–47.
Visual review confirms overlapping channel-N transport/pad assignments and a missing PFL channel key. These are printed table issues, not extraction errors.
The [firmware history](https://mixars.com/support-download/) adds14-bit pitch in1.12 without a revised byte-order table.
The source audit records these conflicts and the unknown Load-bank selector values. No runtime recipe or channel correction is invented.
The available third-party Traktor download requires sign-in. Its discussion does not resolve these wire facts.
The catalogue keeps PRIMO open until an independent mapping or capture resolves them.

All 127 importer checks pass. All 177 runtime recipes remain unchanged.
The repository check retains twelve historical broken links. No native code or runtime resource changed.
Source base: `83753a1`. Hashes, rendered tables and validation remain in `TestBuilds/r296/`.

## R297 Distinct Slate and Slate 4 profiles

Assumption: use the original Slate's tested PCDJ map for its core wire facts. Its stale Pioneer header does not identify the hardware.
Its active identity is `SLATE Audio`, USB23C7:0468. The Slate4 author file identifies USB23C7:0467 and `SLATE4-4 decks`.
These are separate models. The Slate4 source corroborates global channel3, mixer addresses and centred jog values but does not qualify original Slate aliases.
The original keeps native fixed touch scratch. Its source Vinyl button changes only software state; full source mode switching remains open.

Implementation plan and checks:

- [x] Add failing native/importer fixtures for separate identities, automatic versus manual activation, held Cue and pickup.
- [x] Translate original seven-bit inverted pitch, centre64 jogs, distinct cue/fixed-loop addresses, source Shift guard and bounded steady feedback.
- [x] Keep Slate4's conflicting shared touch row, absent pitch, shared pads and source Neural Mix EQ inactive. No original-Slate alias enters Slate4.
- [x] Run focused native playback/protocol checks, importer checks and iPad framework compilation. Compare earlier recipes and bundled bytes.

The original Slate recipe has68 inputs,26 steady feedback definitions and a36-packet lifecycle. Startup sets only the two source-valued Vinyl lights.
Setup failure leaves input inactive. Repeated discovery does not repeat setup. Reconnect restores its fixed native mode indication.
Shift blocks Hot Cue clear presses. Distinct loop notes retain1/8-to16-beat sizes. Source combined manual-loop commands stay inactive.
The source's browser uses greater-than64 for forward. Native64 is neutral. Source Sync beat flashes become steady saved Sync feedback.
Slate4 has27 manual inputs, no output and no lifecycle packet. Its conflicting touch row cannot engage either deck.
Its explicit rotary64 wheel packets remain bend controls. Pitch, shared pads, source Neural Mix knobs and C/D dispatch remain open.

All11 focused Swift checks,128 importer checks and native iPad framework compilation pass.
Native offline audio checks cover original touch/Cue release and Slate4 held Cue with saved Sync.
The compiled resource matches the source. All177 earlier recipes remain unchanged.
The first fixture attempts used incorrect local endpoint/callback types; corrected pre-implementation failures and all logs remain in `TestBuilds/r297/`.
The repository check retains twelve historical broken links. Inline review followed the serial-work rule; no reviewer agent was started.
The catalogue has179 data recipes plus five code profiles. Automatic core coverage reaches155 physical models and66/122 benchmark models.
Full theoretical feature parity remains unimplemented. Calibration, complete modes/lifecycle, audio routing and device acceptance remain open.
Source base: `6ab5af9`. Source cache: `TestBuilds/r296/manufacturer/`. Validation: `TestBuilds/r297/`.
No signed app, install, controller hardware test or A10X acceptance forms part of this increment.

## R298 Slate4 independent four-deck source

Assumption: the separate PCDJ Slate4 script identifies USB23C7:0467 and `SLATE4 Audio`.
It resolves the earlier custom file's conflicting touch row and missing pitch. C/D use channels4/5, not channels2/3.
No native effect, sampler, combined manual-loop behaviour or measured jog revolution count is inferred.

Implementation plan and checks:

- [x] Fail the former manual-only fixture and add explicit C/D channel, hidden-deck and cross-bank release checks.
- [x] Pin the PCDJ source. Replace the manual subset with an automatic four-target core while preserving the original Slate recipe.
- [x] Keep lifecycle below64 packets. Preserve Shift guards and separate global mixer/Load/PFL addresses.
- [x] Run importer checks, focused native playback/protocol checks and iPad framework compilation. Compare previous recipes and bundle bytes.

Slate4 now has150 inputs,52 steady feedback definitions, four startup packets and56 shutdown packets.
Release-only aliases cannot trigger another bank on a positive press. NoteOff in either bank clears its physical side's held Cue/contact.
An unannounced bank change during active contact does not transfer scratching to the new deck. Complete contact handover remains open.
The native fixture verifies explicit C/D transport, Load, PFL, mixer targeting and hidden-deck isolation.
The source's app-specific jog denominator150 does not establish measured counts per revolution. Default calibration remains unverified.
Unowned FX cleanup and full display/light behaviour stay open. No commented Pioneer setup or identity bytes are sent.

All12 focused Swift checks,128 importer checks and native iPad framework compilation pass.
The compiled resource matches the source. Only Slate4 changed; all178 other recipes, including original Slate, remain unchanged.
Expected failures and final evidence remain in `TestBuilds/r298/validation/`. The repository check retains twelve historical broken links.
The catalogue keeps179 data recipes. Automatic core coverage reaches156 physical models and67/122 benchmark models.
Full theoretical feature parity remains unimplemented. No signed app, install, hardware test or A10X acceptance forms part of this increment.
Source base: `075d416`. Source: [PCDJ Slate4 map](https://pcdj.com/dj-controllers-download-the-gemini-slate-4/).

## R299 NDX500 source-backed player core

Assumption: reuse PCDJ's explicitly supported NDX500 MIDI input contract. Do not alias NDX900 or Radius.
The source uses63-minus-raw jog movement and browse value1 forward, all other seven-bit values backward.
Native fixed touch mode replaces source software-only Scratch toggling. Startup configures source lights/display, with no input negotiation packet.
Output stays disabled because a player may use a different hardware MIDI channel. No channel-zero feedback is guessed.

Implementation plan and checks:

- [x] Add failing source-specific decoder and player fixtures for centre, direction, isolation, held Cue/bend and default Sync.
- [x] Add bounded typed decoders restricted to jog/browser actions, then register a separate automatic player input recipe.
- [x] Keep source LCD, lights, full mode/lifecycle and audio routing open. Use existing physical endpoint/deck assignment.
- [x] Run importer checks, focused core/native playback checks and iPad framework compilation. Compare earlier recipes and bundle bytes.

The recipe has68 input bindings across the source's four hardware channels. Existing player assignment keeps separate physical units on separate native decks.
No Sync button is invented. Normal physical loop In/Out actions use native boundaries; source combined-loop/edit variations remain open.
Pitch uses standard MIDI14-bit normalisation and source inversion. The source's MSB read does not prove finer hardware resolution.
The source's jog denominators600/300 are software scales. Native revolution calibration remains unverified.
New decoders accept only seven-bit CC packets. Profile validation restricts them to jog and browser actions.

All ten focused Swift checks,129 importer checks and native iPad framework compilation pass.
The native WAV check preserves saved Sync through held Cue, bend and touch release. Two-player fixtures verify endpoint isolation and both release forms.
The compiled resource matches the source. All179 earlier recipes remain unchanged.
Expected failures and source-bound validation remain in `TestBuilds/r299/`. The repository check retains twelve historical broken links.
The catalogue now has180 data recipes. Automatic core coverage reaches157 physical models and68/122 benchmark models.
Full theoretical feature parity remains unimplemented. Output, complete modes/lifecycle, audio routing and physical acceptance remain open.
Source base: `8d73bf3`. Source cache: `TestBuilds/r298/upstream/`. No signed app, install or A10X acceptance forms part of this increment.

## R300 MCX8000 independent core source

Assumption: reuse the Denon-assisted PCDJ mapping for jog direction, coarse pitch, browser direction, bank messages and steady lights.
Denon documents generic MIDI access and current class compliance on macOS. Direct iPad attachment and audio acceptance remain unverified.
The source readsCC9 as coarse pitch despite the old table's LSB label. LeaveCC119 and high-resolution pairing unmapped.
Native fixed touch replaces source software Vinyl toggling. Pads remain inactive because their shared mode contract is outside this increment.

Implementation plan and checks:

- [x] Fail the former manual-only fixture. Add source encoder/pitch, bank-release, startup failure/reconnect and feedback-value checks.
- [x] Add the reviewed controls, normal-button release aliases and bounded fixed-mode lifecycle. Preserve explicit four-target and hidden-deck contracts.
- [x] Enable automatic MIDI selection only. Keep source selectors in PC mode, pads, high-resolution pitch, screens, routing and physical acceptance open.
- [x] Run focused native playback/protocol checks, importer checks and iPad framework compilation. Compare earlier recipes and bundle bytes.

The core now has121 inputs and24 steady feedback definitions. Source button lights use127/1, while PFL uses127/0.
Startup has30 packets. Shutdown has28. Pad setup, unowned FX cleanup and source screen identifiers are not sent.
Source deck-layer Note8 retires held Cue/contact and cached controls for the same physical side. Failed setup leaves input inactive.
Repeated discovery does not repeat setup. Reconnect restores the bounded native fixed-mode state.
Coarse pitch retains the independent source's CC9 direction. CC119 cannot change pitch. Full-resolution pairing remains unresolved.
Both browsers retain low-half forward direction with native64 neutral. The new source does not establish measured jog revolution counts.
No native pad, Shift-search, screen or automatic audio-route support is inferred. Automatic selection applies to an exposed MIDI port in PC mode.

All11 focused Swift checks,129 importer checks and native iPad framework compilation pass.
The compiled resource matches the source. Only MCX8000 changed; all179 other runtime recipes remain unchanged.
Expected failures and source-bound validation remain in `TestBuilds/r300/`. The repository check retains twelve historical broken links.
The catalogue keeps180 data recipes. Automatic core coverage reaches158 physical models and69/122 benchmark models.
Full theoretical feature parity remains unimplemented. Direct iPad attachment, full lifecycle/modes, routing and physical acceptance remain open.
Source base: `f37ca41`. Source cache: `TestBuilds/r298/upstream/`. No signed app, install or A10X acceptance forms part of this increment.

## R301 RANE FOUR public protocol and manual transport

Assumption: use the readable PCDJ4.0 controller scripts distributed in its public installer. No application or installer script runs.
The extracted FOUR script targets firmware1.6.0.2 and documents three MIDI devices sharing one USB identity.
The main input must exclude LCD Left/Right. Its hardware mixer requires separate A/B/C/D outputs and software mixer bypass.
Automatic selection stays off. The source's incomplete software-mode SysEx and periodic keepalive are not copied into a partial lifecycle.

Implementation plan and checks:

- [x] Pin the package and extracted script hashes. Add failing fixtures for manual identity, four targets, paired pitch and cross-bank Cue release.
- [x] Add an independent `rane_four.py` recipe and register its source. Exclude hardware mixer controls, platter clocks/counter, shared pads and screen output.
- [x] Preserve reviewed transport light values and manual input/feedback enabling. Infer no startup packet or automatic audio route.
- [x] Run importer checks, focused native playback/protocol checks and iPad framework compilation. Compare earlier recipes and bundle bytes.

The public package contains131 controller scripts. Only independently reviewed facts enter native recipes; no installer or downloaded script runs.
The manual FOUR recipe has108 inputs and16 transport lamps. Shifted positive Play/Cue/Sync presses, hardware mixer controls, platter clocks/counter, pads and LCD endpoints remain inactive.
Cross-bank aliases release held Cue/bend when the release arrives; bank selection alone does not release them. Four deck targets preserve opt-in C/D isolation.

All6 focused Swift checks,130 importer checks and iPad framework compilation pass. A real-WAV check confirms Cue release and saved Sync.
The compiled resource matches the source. All180 earlier recipes remain unchanged. Expected failures and source-bound checks remain in `TestBuilds/r301/`.
The repository check retains twelve historical broken links. The catalogue now has181 data recipes; automatic coverage stays158 physical models and69/122 benchmark models.
Full theoretical feature parity remains unimplemented. Source base: `291a4f6`. No signed app, install or physical controller/A10X acceptance is claimed.

## R302 Party Mix Live independent core

Assumption: use the Live-specific PCDJ script, not Party Mix II aliases or calibration. Success requires a distinct automatic profile, source pitch direction and raw64-positive touch jog decoding, both Cue release forms, unchanged earlier recipes and matching iPad framework resources.

- [x] Add failing catalogue and native protocol/playback checks.
- [x] Pin the Live script and package. Add reviewed normal controls and transport lamps; keep shared pads and audio routing open.
- [x] Run importer/native checks and iPad framework compilation. Preserve source-bound evidence.

The Live-specific32-input recipe adds six transport/PFL lamps, filter and two-band mixer controls, touch contact and normal1/127 browsing.
Source jog scaling remains software-specific; native calibration is unverified. Shared pads stay inactive because the native mode handler also writes lamps that this source does not qualify. No Party Mix II setup, hold address or calibration is inherited.

All12 focused native checks,131 importer checks and iPad framework compilation pass. The real-WAV check retains saved Sync after Cue and touch release.
An initial protocol fixture lacked the output port required for startup; the corrected fixture passes. Both failed logs remain in `TestBuilds/r302/`.
All181 earlier recipes remain unchanged; the compiled resource matches the source. The repository check retains twelve historical broken links.
The catalogue has182 data recipes and159 automatic core physical models, including70/122 benchmark models. Full theoretical feature parity remains unimplemented.
Source base: `4aae3c4`. No signed app, install, physical attachment or A10X acceptance is claimed.

## R303 MixDeck Express and Quad source-backed core

Assumption: independently normalise the public PCDJ scripts and use Numark's own Quad TSI to confirm mixer channel0 and A/B/C/D targets. Express has no MIDI mixer; its manual recipe must not enable automatic selection or invent a split-output route. Quad uses fixed physical transport A/B and four mixer targets; its software-only Traktor deck banks do not become hardware channels.

- [x] Add failing generation and native packet/playback checks for both identities, transport, pitch/jog direction and mixer separation.
- [x] Pin source hashes. Add Express manual and Quad automatic input core without guessed screens, lifecycle or audio routing.
- [x] Check Cue releases, hidden C/D targets, unchanged earlier recipes and the iPad framework resource. Preserve failed and final results.

Express has26 manual inputs and four reviewed transport lamps. Quad has49 automatic core inputs and four lamps, including its separate four-target mixer on wire channel0.
Their Play/Cue input and lamp addresses differ. No Sync button, shared cue/sampler mode, software-bank MIDI channels, partial LCD setup or automatic audio route is invented.
The manufacturer guide requires Quad USB AUDIO PGM/CUE and MIDI USB selectors for software mixing. Its legacy30-pin iOS mono route remains separate.
The pinned Quad TSI contains425 mapping rows. An offline read-only review follows Ivan Zlatev's published chunk layout; no Traktor code runs in the app.

All7 focused native checks,132 importer checks and iPad framework compilation pass. The playback check uses real WAV audio on both recipes and retains saved Sync.
All182 earlier recipes remain unchanged; the compiled resource matches the source. Expected failures, source hashes and review extracts remain in `TestBuilds/r303/`.
The repository check retains twelve historical broken links. The catalogue now has184 data recipes and160 automatic core physical models, including71/122 benchmark models.
Full theoretical feature parity remains unimplemented. Source base: `c78cf46`. No signed app, install or physical/A10X acceptance is claimed.

## R304 Mixon 8 Pro reviewed manual core

Assumption: use only unconditional normal controls from the owner-shared898-row map. Its reported saved-loop/sampler alias bug affects shared modes, which remain excluded. The missing `ReloopMixon8` class leaves setup, jog/pitch translation, modes, screen/lamp output and lifecycle unqualified. Automatic selection stays off.

- [x] Add failing catalogue/native fixtures for manual identity, normal transport, bank-release ownership and inactive shared controls.
- [x] Pin the source and add83 manual inputs with no inferred output or lifecycle packets.
- [x] Run importer, native packet/playback and iPad framework checks; compare earlier recipes and bundled bytes.

The manual recipe has83 inputs for four opt-in deck targets. No downloaded class runs. No shared pad, modified level/EQ assignment, jog/pitch, light value or lifecycle packet is guessed.
The earlier firmware-incompatible map remains in the source audit; the separate version4 map now provides independently reviewed unconditional controls.
All6 focused native checks,133 importer checks and iPad framework compilation pass. The real-WAV check confirms cross-bank Cue release and saved Sync.
All184 earlier recipes remain unchanged; the compiled resource matches the source. Expected failures and source-bound results remain in `TestBuilds/r304/`.
The repository check retains twelve historical broken links. The catalogue has185 data recipes. Automatic core coverage stays160 physical models and71/122 benchmark models.
Full theoretical feature parity remains unimplemented. Source base: `646228e`. No signed app, install or physical/A10X acceptance is claimed.

## R305 Stealth Control independent core

Assumption: Numark's model-specific Cue5 XML governs addresses. Its `chan` selects software decks; MADRIX's public Stealth map independently confirms wire channel0 and signed two's-complement browser/jog decoding. MADRIX reuses Total's opposite jog addresses, which do not override Numark's Stealth source. No lamp or setup packet is inferred.

- [x] Add failing generation/native fixtures for independent identity, transport, jog addresses and signed counts.
- [x] Add42 automatic input bindings from pinned sources. Keep sensorless wheels, source Cue51/68, and browser press79 distinct from Total/Omni.
- [x] Check native playback/Cue release, earlier profiles and iPad framework resource bytes. Preserve source-bound evidence.

The42-input recipe adds automatic normal input only. Its wheels stay sensorless. Numark's source Cue B68 choice remains explicit; source Pause60 and Smart Cue59 stay inactive pending physical acceptance.
MADRIX qualifies channel0 and signed counts only; its opposite jog addresses do not override the model-specific Numark map. No Total/Omni light or fine-tempo address is inherited.
All5 focused native checks,134 importer checks and iPad framework compilation pass. The real-WAV check retains saved Sync after Cue and wheel control.
Two older catalogue assertions still expected protocol-needed status; they now require this independent profile and reject Omni/Total aliasing. Failed results remain in `TestBuilds/r305/`.
All185 earlier recipes remain unchanged; the compiled resource matches the source. The repository check retains twelve historical broken links.
The catalogue has186 data recipes and161 automatic core physical models; benchmark coverage stays71/122. Full theoretical feature parity remains unimplemented.
Source base: `bbefb6b`. No signed app, install or physical/A10X acceptance is claimed.

## R306 DJM-S11 manual MIDI mixer

Assumption: only the factory table's unambiguous MIDI mirror controls enter a manual recipe. Twelve A/B paired controls and four global paired controls need no custom decoder. Hardware mixing and separate deck outputs remain outside native routing, so automatic selection stays off. The browser rows conflict between channel7 and status notation Bn/9n; no wire channel is guessed. Shared pads, touchscreen modes and fader-start gestures remain excluded.

- [x] Add failing generation and native fixtures for manual identity, exact pairs, channel isolation and inactive source modes.
- [x] Add16 paired controls with no light, startup or automatic audio-route claim.
- [x] Run importer/native checks and iPad framework compilation; compare earlier recipes and resource bytes.

The manual recipe provides16 explicit paired mixer inputs and no output/lifecycle packets. It is a MIDI mirror for a separate software audio path; external mixer audio and bypass remain unavailable.
All4 focused native checks,135 importer checks and iPad framework compilation pass. All186 earlier recipes remain unchanged; bundled bytes match the source.
Expected failures, factory PDF/hash, reviewed page2 and validation evidence remain in `TestBuilds/r306/`. A repeated Poppler render was stopped after the required page was inspected; its log is retained.
The repository check retains twelve historical broken links. The catalogue has187 data recipes; automatic core coverage stays161 physical models and71/122 benchmark models.
Full theoretical feature parity remains unimplemented. Source base: `efd725f`. No signed app, install or physical/A10X acceptance is claimed.

## R307 DJM-S7 and S5 manual MIDI subsets

Assumption: each factory table independently confirms the16 paired mixer inputs. A shared builder can express that verified contract while preserving the S11 recipe exactly. Both S7/S5 provide normal Load70 and shifted release71 on deck channels0/1. Only S5's browser row supplies consistent channel6/statusB6 and signed counts. Manual selection prevents an automatic external-audio claim.

- [x] Add failing generation and native fixtures for distinct identities, counts, exact pairs, normal/shifted Load and browser separation.
- [x] Add20 S7 inputs and23 S5 inputs with no guessed outputs, modes or lifecycle.
- [x] Verify native dispatch and unchanged S11/other recipes, run importer/iPad framework checks and compare bundle bytes.

The S7 manual recipe has20 inputs; S5 has23. Both use independently confirmed16 paired controls and normal Load with shifted release aliases.
Only S5 adds its unambiguous signed browser and normal Browse press. S7's conflicting browser notation remains unresolved. No shared pad, fader-start, light or lifecycle packet is guessed.
All8 focused native checks,136 importer checks and iPad framework compilation pass. All187 earlier recipes, including S11, remain unchanged; bundled bytes match the source.
Expected failures, both factory PDF hashes, inspected table images and source-bound evidence remain in `TestBuilds/r307/`.
The repository check retains twelve historical broken links. The catalogue has189 data recipes; automatic core coverage stays161 physical models and71/122 benchmark models.
Full theoretical feature parity remains unimplemented. Source base: `e0c74c0`. No signed app, install or physical/A10X acceptance is claimed.

## R308 RANE ONE MKII source audit

Assumption: a staff-shared djay template is a source of explicit mapping facts, not the implementation of its missing `RaneOneMK2` class. It must not establish motor, normal Play, startup or audio support. The original ONE and SYSTEM ONE are distinct devices.

- [x] Pin the version3 template, source discussion and audio fields. Add a failing audit fixture.
- [x] Record667 input-list rows,11 headings, two output rows and absent normal Play mappings in the catalogue source audit. Keep runtime support unchanged.
- [x] Run importer/repository checks and verify every runtime profile byte remains unchanged. Retain the previous native/iPad framework evidence for identical app resources.

The staff-shared source declares USB1CC5:0026. Its two output rows only specify Play lamps4/12 on note0; output does not prove the missing normal Play input or motor lifecycle.
Per-deck outputs0/2, sampler4 and FX send/return offsets remain explicit native routing gaps. Original ONE, FOUR and SYSTEM ONE do not inherit this template.
All137 importer checks pass. Every runtime profile byte remains unchanged from `c3200d6`; its8 native checks and iPad framework resource comparison remain valid for identical app resources.
Expected failure, the template/hash and source-bound results remain in `TestBuilds/r308/`. The repository check retains twelve historical broken links.
Review also found three duplicate Pioneer DJM catalogue records caused by brand normalisation. R309 will correct their model links without changing MIDI dispatch.
Automatic core coverage stays161 physical models and71/122 benchmark models. Full theoretical feature parity remains unimplemented. No signed app, install or physical/A10X acceptance is claimed.

## R309 Pioneer brand boundary and mixer catalogue links

Root cause: replacing the text `pioneer dj` without a word boundary also removes `DJ` from `Pioneer DJM-S11`. The benchmark's `Pioneer DJ DJM-S11` reaches a different model ID. The three new mixer recipes therefore created duplicate records. The fix must apply only to the complete brand name and preserve DJM model tokens.

- [x] Add failing canonical-name and catalogue-link regressions.
- [x] Apply the word-boundary fix and regenerate. Confirm one S11/S7/S5 record each, connected to its manual recipe.
- [x] Run importer/native/iPad framework checks. Compare all MIDI bindings and byte-exact bundled resources; keep failed evidence.

The word-boundary fix removes only the three duplicate IDs and connects the three existing benchmark records to their manual profiles. No other model record changes.
The catalogue returns to313 records and306 physical models. All189 runtime profiles retain identical MIDI inputs, outputs and lifecycle packets; only three definition identifiers change.
All139 importer checks,8 focused native checks and iPad framework compilation pass. Bundled resource bytes match the source.
Expected failures, model/runtime comparisons and source-bound results remain in `TestBuilds/r309/`. The repository check retains twelve historical broken links.
Automatic core coverage remains161 physical models and71/122 benchmark models. Full theoretical feature parity, audio/lifecycle gaps and physical acceptance remain open.
Source base: `df41760`. No signed app or install is claimed.

## R310 Input-only pad modes and Party Mix Live pads

Assumption: the pinned Live-specific source already defines Cue/Loop/Sampler/FX mode inputs, but does not qualify mode-lamp output. Mode state must work without output. Existing recipes with both lamp values must keep their exact output behaviour. An incomplete lamp pair must remain invalid.

- [x] Add failing schema, native mode/output and Live pad fixtures. Confirm the current code rejects input-only modes and lacks the16 pad bindings.
- [x] Make `ControllerProfileData.InputMode` lamp values optional as a pair. Update state before checking output values. Keep existing paired feedback unchanged.
- [x] Extend `party_mix_live.py` with mode0 Hot Cues and mode14 loops of1/2/4/8 beats on channels4/5. Other modes block both. Infer no Pad Mode hold address or lamp packet.
- [x] Run importer and focused native tests, including reconnect, per-deck/source isolation, real-WAV loop playback and existing mode lights. Compile the iPad framework and compare all other recipes and bundle bytes.

Party Mix Live now has48 inputs. Its16 new pad bindings provide four Hot Cues and four fixed loop lengths per deck.
Omitting both mode-light values keeps input mode state active without output. Existing paired mode feedback remains unchanged; an incomplete pair is rejected.
All20 focused native checks,139 importer checks and iPad framework compilation pass. Real-WAV playback verifies1/2/4/8-beat loop spans, finite audio and saved Sync.
The initial playback fixture recalled a Hot Cue, then paused it with a Play toggle. The corrected fixture verifies the Hot Cue start before loop selection. Both failed logs are retained.
Only Party Mix Live changes in the runtime catalogue; all188 other recipes remain unchanged. Compiled resource bytes match the source.
Evidence remains in `TestBuilds/r310/`. The repository check retains twelve historical broken links. Counts stay189 data recipes,161 automatic core physical models and71/122 benchmark models.
Sampler/FX actions, held Pad Mode, deletion, full output/lifecycle, calibration and audio routing remain open. No signed app, install or physical/A10X acceptance is claimed.
Source base: `2e277a5`.

## R311 Independent Gemini G2V core

Assumption: the G2V-specific public PCDJ script qualifies its two-deck MIDI core. Its G2V Audio identity and pad modes must remain separate from G4V. Source seven-bit controls provide a bounded core even where the product advertises higher resolution. No audio route or physical jog calibration is inferred.

- [x] Add failing importer and native decoder/profile tests.
- [x] Add the independent recipe, exact browser boundary, per-deck Shift and mode-gated cues/loops. Keep Sampler/manual-loop actions inactive.
- [x] Verify both decks, mode lights, reconnects, held Cue and real-WAV loops/Sync. Run importer checks and compile the iPad framework. Compare all earlier recipes and bundle bytes.

Source base: `c76529c`. Full modes, lifecycle, audio routing and physical acceptance remain open.

The independent recipe adds86 inputs and8 steady lamp outputs. Source-valued mode lamps follow per-deck Cue/AutoLoop/Sampler/ManualLoop selection. Sampler/manual-loop actions and deletion remain inactive.
All140 importer checks,21 focused native checks and iPad framework compilation pass. Real-WAV checks cover all eight loop lengths, held Cue, contact release, finite audio and saved Sync.
All189 earlier runtime recipes remain unchanged. Compiled resource bytes match the source. Evidence and failed fixture logs remain in `TestBuilds/r311/`.
The catalogue now has314 records/307 physical models and190 data recipes. Automatic core coverage reaches162 physical models; the benchmark remains71/122.
The repository check retains twelve historical broken links. Full modes/output/lifecycle, audio routing, calibration and direct iPad attachment remain open. No signed app, install or physical/A10X acceptance is claimed.

## R312 Independent RMP-4 player core

Assumption: the RMP-4-specific public PCDJ mapping qualifies four selectable MIDI channels. Native player assignment replaces the source channel-to-deck association. Default MIDI mode is required. RMP-3, RMP-2.5 and other Reloop players must remain separate.

- [x] Confirm the new importer fixture fails without a recipe.
- [x] Add normal transport, held Cue/bend/contact, source jog, pitch, cues/loops and browsing. Add release-only Shift addresses. Emit no output before wire-channel ownership is qualified.
- [x] Verify two independent players, channel/Shift isolation, native real-WAV controls and saved Sync. Run importer checks and compile the iPad framework. Compare all earlier recipes and resource bytes.

Source base: `a74ff18`. Full modes/display/output/lifecycle, audio routing, calibration and physical acceptance remain open.

The new player recipe adds188 bindings across four selectable MIDI channels. Independent endpoints receive separate native deck assignments. Shifted positive actions and unsupported pad pages stay inactive.
All141 importer checks,11 focused native checks and iPad framework compilation pass. Real-WAV checks verify Shift/channel releases, seven exact loop lengths, finite audio and saved Sync.
All190 earlier runtime recipes stay unchanged. Compiled resource bytes match the source. Failed fixture compilation and final source-bound evidence remain in `TestBuilds/r312/`.
The catalogue now has315 records/308 physical models and191 data recipes. Automatic core coverage reaches163 physical models; the benchmark stays71/122.
The repository check retains twelve historical broken links. Full modes/display/output/lifecycle, audio routing, calibration and physical acceptance remain open. No signed app or install is claimed.

## R313 Independent Numark iDJ3 core

Assumption: the public iDJ3-specific source qualifies its USB-MIDI normal controls. Its output uses channel0. The manufacturer confirms touch-sensitive jogs and MIDI-over-USB. Native fixed touch replaces the source software Scratch toggle. iDJ Live/iDJ Live II and original Mixtrack remain separate.

- [x] Confirm the importer fixture fails without a recipe.
- [x] Add source transport, held Cue/bend/contact, exact jog/browser sign, pitch, mixer and four fixed loops. Add only reviewed steady lamps. Omit the source half-range Master control and iPod/audio assumptions.
- [x] Verify both decks, packet boundaries, real-WAV Cue/touch/loops and saved Sync. Run importer checks and compile the iPad framework. Compare previous recipes and resource bytes.

Source base: `3a3e666`. Full modes/lifecycle/output, calibration, iPod/audio routing and direct iPad attachment remain open.

The independent iDJ3 recipe adds44 inputs and8 reviewed steady lamp outputs. Native fixed touch, held Cue/bends, pitch, three-band EQ, browsing and1/2/4/8-beat loops use its own source addresses.
All142 importer checks,6 focused native checks and iPad framework compilation pass. Real-WAV checks verify exact loops, Cue/contact release, finite audio and saved Sync.
All191 earlier runtime recipes remain unchanged. Compiled resource bytes match the source. Evidence remains in `TestBuilds/r313/`.
The catalogue now has316 records/309 physical models and192 data recipes. Automatic core coverage reaches164 physical models; the benchmark stays71/122.
The repository check retains twelve historical broken links. Full modes/lifecycle/output, scaled Master, calibration, iPod/audio routing and direct iPad attachment remain open. No signed app, install or physical/A10X acceptance is claimed.

## R314 Independent CMD STUDIO 2a core

Assumption: the STUDIO 2a source qualifies distinct normal controls. The original Mixxx mapping guide confirms default wire channel0 and master1/2 with headphones3/4. The PCDJ file contains an invalid secondary PID placeholder. Its reviewed address facts are reused without executing that file or adopting the placeholder.

- [x] Confirm the importer fixture fails without a recipe.
- [x] Add normal transport, held Cue/bend/contact, relative jog/pitch, EQ/level, four cues, browsing and source-valued steady lamps. Add only the documented split audio route.
- [x] Verify independent deck actions, encoder counts, one-valued lamps and real-WAV Cue/touch/Sync. Run importer checks and compile the iPad framework. Compare previous recipes and resource bytes.

Source base: `93c7390`. Non-default MIDI channels, full modes/lifecycle/output, pitch/jog calibration and physical USB/audio acceptance remain open.

The independent recipe adds41 inputs and14 steady lamp outputs. Source relative pitch/jog encoders and one-valued lamps remain distinct from STUDIO 4a. The original mapping guide qualifies automatic master1/2 and headphones3/4.
All143 importer checks,8 focused native tests with32 audio-routing cases and iPad framework compilation pass. Real-WAV checks verify Cue/contact release, Hot Cue playback, finite audio and saved Sync.
All192 earlier runtime recipes remain unchanged. Compiled resource bytes match the source. Expected missing-profile and audio-whitelist failures remain in `TestBuilds/r314/` with final source-bound evidence.
The catalogue now has317 records/310 physical models and193 data recipes. Automatic core coverage reaches165 physical models; the benchmark stays71/122.
The repository check retains twelve historical broken links. Non-default MIDI channels, full modes/lifecycle/output, pitch/jog calibration and physical USB/audio acceptance remain open. No signed app or install is claimed.

## R315 Reloop TOUCH manual MIDI core

Assumption: the independent TOUCH source qualifies normal MIDI controls on wire channels1..4 and globals on5. Its startup also opens a DisplayLink screen and a separate UPDD touch driver. Native screen/driver and normal-mode setup remain unavailable, so automatic selection must stay off. Manual application cannot supply shared-pad mode state.

- [x] Confirm the importer fixture fails without a recipe.
- [x] Add reviewed four-target transport/mixer, fixed touch/jog, pitch and browsing, with Shift/bank release aliases and bounded steady lamps. Emit no setup, lifecycle or audio-route packet.
- [x] Verify default-off selection, C/D opt-in, release ownership, source addresses and real-WAV Cue/touch/Sync. Run importer checks and compile the iPad framework. Compare previous recipes and resource bytes.

Source base: `53600f8`. Screen/driver/normal-mode setup, shared pads, loop modes, full lifecycle, calibration and audio routing remain open.

The independent manual recipe adds126 inputs and16 reviewed steady lamp outputs. C/D remain opt-in. Explicit Shift and opposite-bank releases preserve the active control owner. No shifted contact address is inferred.
All144 importer checks,10 focused native checks and iPad framework compilation pass. Real-WAV checks verify held Cue/contact release, finite audio and saved Sync.
All193 earlier runtime recipes remain unchanged. Compiled resource bytes match the source. Source-bound evidence remains in `TestBuilds/r315/`. The catalogue header now distinguishes the base inventory date from later profile reviews.
The catalogue now has318 records/311 physical models and194 data recipes. Automatic core coverage stays165 physical models and71/122 benchmark models.
The repository check retains twelve historical broken links. Screen/driver/normal-mode setup, shared pads, loop modes, full lifecycle, audio routing, calibration and physical acceptance remain open. No signed app or install is claimed.

## R316 Separate RANE SEVENTY source subsets

Assumption: the standard-model owner export and the older A-Trak author export qualify unconditional MIDI controls. Both declare RaneSeventy custom code, which is absent. Shared pads and external-mixer audio remain unqualified. The standard owner's yellow Transport sub-mode is a custom source layout, not a factory normal transport claim.

- [x] Confirm the importer fixture fails without the two independent manual profiles. Pin both exports and row counts.
- [x] Add common Load, Sync, loop and flipped browser controls. Add standard-owner Transport-sub-mode Play/Sync/bends only to the standard profile. Emit no setup/output/audio-route packet and infer no Cue preview from a numbered cue action.
- [x] Verify distinct identities, both decks, safe rejection of other modes, relative browser counts, held bend release and real-WAV Play/loops/Sync. Run importer checks and compile the iPad framework. Compare previous recipes and resource bytes.

Source base: `a448abe`. Shared-pad/modifier setup, normal Cue/transport, external-mixer/FX audio, feedback, lifecycle and physical acceptance remain open.

The standard profile adds27 manual inputs. The separate A-Trak profile adds19. Both retain their own pinned export and missing-class audit. The standard owner customises the yellow Transport sub-mode; the A-Trak profile does not inherit that layout.
All145 importer checks,8 focused native checks and iPad framework compilation pass. Real-WAV checks verify standard-owner Play, held bend release, looping, finite audio and saved Sync.
All194 earlier runtime recipes remain unchanged. Compiled resource bytes match the source. Evidence remains in `TestBuilds/r316/`. The catalogue stays318 records/311 physical models and reaches196 data recipes.
Both existing benchmark records now have manual subsets. Automatic core coverage stays165 physical models and71/122 benchmark models.
The repository check retains twelve historical broken links. Missing RaneSeventy code, shared modes, ordinary Cue/transport, external-mixer/FX audio, feedback/lifecycle and physical acceptance keep automatic selection off. No signed app or install is claimed.

## R317 Numark NV prototype source boundary and manual core

Assumption: the owner's pinned NV XML and normal script handlers qualify a bounded manual subset. The version0.1.0 prototype is not a released Mixxx definition. Shared cross-deck jog state, unfinished modes and a startup CC value255 prevent qualified automatic setup. NVII must remain separate.

- [x] Confirm the importer fixture fails without the NV profile. Pin the independent XML/script and commit.
- [x] Add normal Play/held Cue/Sync/Load, held bends, source coarse pitch, mixer and global Shift guards. Keep pads/jogs/PFL/loops, lamps, setup and audio routing inactive. Do not repair or run downloaded code.
- [x] Verify C/D opt-in, Shift/bank releases, source mixer/pitch addresses and real-WAV Cue/Play/Sync. Run importer checks and compile the iPad framework. Compare previous recipes and resource bytes.

Source base: `d242481`. Theoretical full support and physical acceptance remain open.

The bounded NV profile adds79 manual inputs. Global Shift blocks alternate normal transport presses. Cross-bank release aliases clear held Cue/bends and rearm Play/Sync/Load. The failing bank fixture proved Play and Load stayed latched without those aliases.
All146 importer checks,5 focused native checks and iPad framework compilation pass. Real-WAV checks verify Cue release across Shift/bank changes, finite audio, Play and saved Sync.
All196 earlier runtime recipes remain unchanged. Compiled resource bytes match the source. The missing-profile and bank-release failures remain in `TestBuilds/r317/` with final source-bound evidence.
The catalogue stays318 records/311 physical models and reaches197 data recipes. The existing NV benchmark record now has a manual subset. Automatic core coverage stays165 physical models and71/122 benchmark models.
The repository check retains twelve historical broken links. The source prototype does not establish jogs, pads, PFL, loops, screens, complete setup, feedback, audio routing or physical acceptance. No signed app, install or NVII support is claimed.

## R318 AFX public source-access boundary

The public author's AFX mapping page requires sign-in to download the TSI. Its description and author discussion identify incomplete modes and a colour palette, but do not provide a complete channel/address table. The colour table cannot establish input addresses. AMX is a separate device. No address, deck channel or handshake is inferred.

- [x] Pin the public mapping page and author discussion, including the sign-in requirement. Add a failing audit fixture.
- [x] Connect the audit to the existing AFX benchmark record. Keep runtime bytes unchanged and confirm importer checks.

Source base: `c418214`. Mapping-source access, mode/endpoint protocol, setup and physical acceptance remain open.

All147 importer checks pass. The existing AFX benchmark record now carries the pinned source-access audit. All197 runtime recipes and resource bytes remain unchanged. No Swift/iPad rebuild was needed for this metadata-only change.
Evidence remains in `TestBuilds/r318/`. The repository check retains twelve historical broken links. Counts stay318 records/311 physical models,197 data recipes,165 automatic core physical models and71/122 benchmark models.
No runtime, full theoretical support, signed app, install or physical acceptance is claimed for AFX.

## R319 Faderfox DJ3 independent input core

Assumption: the named class-compliant DJ3 port and four manufacturer-selectable MIDI channels allow automatic input matching. The manufacturer's TSI uses wire channel3 and confirms7Fh/01h gain/pitch/browser encoders. The manual has shared and separate A/C-B/D pot addressing. Exclude all EQ/filter pots until that state is qualified. The PCDJ lamp/reset code uses unrelated addresses and is not inherited.

- [x] Confirm the importer fixture fails without a DJ3 recipe. Pin manufacturer manual/setup and the independent PCDJ source.
- [x] Add normal four-target transport, held Cue/bends, source relative gain/pitch, distinct level/PFL addresses, four cues and global controls. Accept only the four selectable channels. Add opposite-bank critical release aliases. Emit no output/reset/audio packet.
- [x] Verify four-channel input, C/D opt-in, encoder counts, inactive shared pots, held release ownership and real-WAV Cue/Play/Sync. Run importer checks and compile the iPad framework. Compare previous recipes and resource bytes.

Source base: `7ef47eb`. Generic USB Audio Device naming, pot ownership, full Shift/loop/FX modes, lights/lifecycle, calibration and physical acceptance remain open.

The named-port DJ3 recipe adds392 inputs across the four selectable MIDI channels, with four opt-in deck targets. No shared EQ/filter pot, generic USB-device alias, loop/FX mode or copied lamp/reset output is activated.
The first native run exposed a catalogue-wide size failure: pretty JSON reached4,196,910 bytes, exceeding the unchanged4 MiB native limit. The loader rejected all data profiles. The generator now writes compact UTF-8 JSON and rejects oversized resources before writing either output. New tests cover the byte limit, multibyte text and data-preserving encoding.
The resource is now2,235,212 bytes. All197 earlier recipes retain identical data; only runtime whitespace changes. The compiled iPad resource matches the source byte for byte.
All150 importer checks,9 focused native checks and iPad framework compilation pass. Native checks cover the full catalogue load, oversized rejection,141 reviewed factory Cue profiles, four selectable MIDI channels, bank releases and real-WAV Play/Cue/Sync.
The failed size/native logs and final source-bound evidence remain in `TestBuilds/r319/`. The repository check retains twelve historical broken links.
The catalogue reaches319 records/312 physical models and198 data recipes. Automatic core coverage reaches166 physical models; the benchmark stays71/122.
Generic port naming, pot ownership, full Shift/button/loop/FX modes, lights/lifecycle, calibration and physical/A10X acceptance remain open. No signed app or install is claimed.

## R320 RMX-90 DVS factory MIDI mixer

Assumption: this manual recipe requires MIDI on, MIDI CH1 and MIDI TYPE TRIGGER. These are explicit setup requirements, not inferred defaults. CH1/2/3/4 target native A/B/C/D. C/D require app opt-in. Use a separate software audio path because external deck routing and mixer bypass remain unavailable.

- [x] Pin and visually review the factory MIDI map and manual setup page. Confirm a failing importer fixture.
- [x] Add32 manual absolute inputs: four channel gains, EQ, filters, levels and PFL, plus crossfader, master, headphone blend and level.
- [x] Verify all targets, channel/kind isolation, PFL ownership, inactive selectors/FX/Booth and native playback. Run importer checks and compile the iPad framework.

Source base: `36044e0`. Do not infer sibling RMX models, lamp outputs, pickup SysEx, encoder decoding or automatic audio routing. Full modes, calibration and physical/A10X acceptance remain open.

The manual recipe adds32 factory inputs. All151 importer checks and7 focused native checks pass. The native checks cover all four deck targets, C/D opt-in, normalised endpoints, both PFL release forms, inactive selectors/Booth/FX, reserved channels and real-WAV mixer/PFL playback with Sync retained.
The iPad framework compiles. Its bundled resource matches the source byte for byte. All198 earlier recipes retain identical data. The catalogue stays319 records/312 physical models and reaches199 data recipes. Automatic core coverage stays166 physical models and71/122 benchmark models.
The first native run failed a test that assumed a fixed order for deferred crossfader events. The corrected test checks each action/value independently. Both logs remain in `TestBuilds/r320/`. The repository check retains twelve historical broken links.
No signed app, install, external mixer audio or physical/A10X acceptance is claimed. Alternate MIDI settings, full modes, output/lifecycle and calibration remain open.

## R321 Roland DJ-505 manual normal controls

Assumption: the pinned upstream XML and native script review qualify a manual normal MIDI subset. Automatic selection stays off. The source switches hardware mode with two SysEx messages and repeats a keepalive every500 ms. No partial lifecycle sequence is emitted.

- [x] Confirm a failing importer fixture and verify both pinned source hashes.
- [x] Add four-target normal transport, paired tempo/mixer, filter/PFL and explicit loop buttons. Guard shifted pitch and add shifted/opposite-bank critical release aliases.
- [x] Verify pair assembly, channel/kind isolation, C/D opt-in, release ownership and real-WAV transport. Run importer checks and compile the iPad framework.

Source base: `4cf7907`. Shared Load ownership, calibrated crossfader maximum, jog/contact, pads/FX/TR-S routing, full Shift/bank state, startup/keepalive/shutdown and physical/A10X acceptance remain open. No DJ-202/DJ-808 alias or audio route is inferred.

The manual DJ-505 recipe adds117 bounded inputs. All152 importer checks and8 focused native checks pass. Tests cover all24 explicit pairs, four targets with C/D opt-in, Shift blocking, shifted/opposite-bank release ownership, independent loop/PFL/filter rows and real-WAV Cue/Play with Sync retained.
The upstream rate-control formula confirms reversed native pitch normalisation. The first native fixture sent low bytes before high bytes. The corrected fixture follows the source handler sequence; both logs remain in `TestBuilds/r321/`.
The iPad framework compiles and its resource matches the source byte for byte. All199 earlier recipes retain identical data. The catalogue reaches200 data recipes. Automatic core coverage stays166 physical models and71/122 benchmark models. The repository check retains twelve historical broken links.
Manual input does not provide software-mode startup/keepalive, shared Load state, calibrated crossfader/jogs, full pads/FX/TR-S/audio routing or physical/A10X acceptance. No signed app or install is claimed.

## R322 CMD MM-1 automatic mixer core

Assumption: the named MM-1 USB-MIDI endpoint permits automatic input matching. Its configurable MIDI channel does not change control addresses. Accept all16 channels on that named endpoint. The source startup builds software state and feedback; its unused dump request remains inactive.

- [x] Confirm a failing importer fixture and verify the pinned XML/script against the upstream manual.
- [x] Add31 default mixer/global inputs with physical strip order C/A/B/D and EQ/filter roles. Keep both modifier buttons as independent guards. No generic CMD alias or audio/output packet is inferred.
- [x] Verify all16 channels, C/D opt-in, independent modifier release, browser counts, inactive alternate controls and real-WAV mixer/PFL playback. Run importer checks and compile the iPad framework.

Source base: `d65a1ac`. These are fixed native default mixer controls. Dynamic strip/FX/knob modes, shifted Load, Ctrl-Sync, lamps/meters, full lifecycle, port-name variation and physical/A10X acceptance remain open.

The automatic named-port recipe adds31 default controls across496 explicit channel bindings. The physical strips retain C/A/B/D order. Both modifier buttons guard deck and browser controls with independent ownership. Other CMD products and generic ports cannot select this recipe.
All153 importer checks and8 focused native checks pass. Native checks cover all16 MIDI channels with both two- and four-deck availability, every default knob row, independent modifier release, exact signed browser counts and real-WAV mixer/PFL playback with Sync retained.
The first native run rejected wildcard channels on a mixer and invalid modifier identity values. Explicit channel bindings and bounded modifier identities preserve the existing schema. A later test fixture needed an explicit Swift result type. Failed logs remain in `TestBuilds/r322/`.
The iPad framework compiles. Its bundled resource matches the source byte for byte. All200 earlier recipes retain identical data. The catalogue reaches201 data recipes and167 automatic-core physical models. The benchmark stays71/122. The repository check retains twelve historical broken links.
Full software layers, output channel selection, lamps/meters, port-name variants, calibration and physical/A10X acceptance remain open. No signed app or install is claimed.

The final combined run passes all19 native checks for R320/R321/R322 and the catalogue bounds. It exposed another RMX-90 test ordering assumption. That assertion now compares the independently delivered C/D targets as a set. The failed and passing combined logs remain in `TestBuilds/r322/`.

## R323 Controller remainder and fixed MIDI mixers

Starting source: `fb8906a`. The catalogue has312 physical models. Of these,145 lack automatic core input:56 need protocol work,31 need adapters,45 have manual partial mappings and13 require bridges. Full theoretical support remains incomplete for all312 models. This is the whole remaining scope, not a three-profile stopping point.

Assumption: retain the established source-backed recipe architecture and serial execution. Finish documented native MIDI work first. Treat platform drivers, USB/HID access, unidentified hardware modes and undocumented protocols as concrete blockers. Never change completion flags merely to reduce the remainder.

- [x] Add failing importer and native decoder fixtures for separate SMC-Mixer and iControls normal mixer contracts.
- [x] Add exact source encoder decoding, fixed C/A/B/D mixer strips, independent fader/tempo/PFL controls and source-supported globals. Keep software-selected transport, shared knob modes and unqualified output inactive.
- [x] Report the current automatic-core and complete-theoretical remainder from generated catalogue data.
- [x] Verify both recipes, all four targets with C/D opt-in, encoder steps and malformed inputs, native WAV mixer/PFL flow, catalogue bounds and iPad framework compilation. Preserve failed checks and compare earlier recipes.
- [ ] Continue through the remaining source-backed adapters, partial mappings and protocol work. Preserve each unresolved hardware/platform boundary in the catalogue.

The upstream iControls manual limits the default mapping to its distinguishable hardware layer1. SMC-Mixer default knobs control gain; long-press EQ/filter reassignment stays inactive. Named USB-MIDI core does not imply Bluetooth pairing, hardware reset, all software modes, complete feedback or physical/A10X acceptance.

SMC-Mixer adds25 fixed inputs. iControls adds26 separate layer1 inputs. Their bounded factory-only encoder decoders retain every seven-bit source value, including magnitude and exact0.01 steps. No shared transport or hardware layer is guessed.
All156 importer checks,9 native checks and iPad framework compilation pass. Native checks include256 encoder cases, malformed messages, schema restrictions, C/D opt-in, all eight faders and two real-WAV mixer/PFL/gain flows with Sync retained.
The initial native fixture skipped soft takeover for absolute global controls. The corrected fixture crosses the current value first. Failed and passing logs remain in `TestBuilds/r323/`. Earlier201 recipes retain identical data. The compiled resource matches the source byte for byte. The repository check retains twelve historical broken links.
The catalogue now has203 data recipes and169 automatic-core physical models. The automatic-core remainder is143. Full theoretical completion remains open for312 physical models. The final checklist item remains open for continued execution.

## R324 SMK-25 II source-local SysEx input

Assumption: the independent pinned XML/script and upstream manual qualify the SMK-25 II USB input contract. Factory inputs already use the legacy byte port, so this change does not alter MIDI2 port selection. Add one explicit vendor protocol tag. Keep ordinary controllers on their existing decoder.

- [x] Confirm failing native decoder and importer fixtures.
- [x] Decode only complete7-byte F0/35/59 messages. Retain fragment state per source. Translate published buttons and knobs, normal strip messages and fixed A/B selection. Release owned contacts and reset pickup on a bank change. Ignore channel9 sampler notes.
- [x] Add43 logical native bindings after protocol conversion, with no guessed output or sibling alias. Verify normal data, malformed/truncated/oversized input, mixed order, both decks, reconnect reset and real-WAV Cue/Play/Sync.
- [x] Run importer checks and compile the iPad framework. Compare every earlier recipe and preserve logs.

The source declares immediate firmware releases for some pad presses. Native code must not invent physical hold duration. Sampler playback, recording, Bluetooth pairing, hardware lights, complete lifecycle, native calibration and physical/A10X acceptance remain open.

The source-local adapter adds43 logical inputs after actual vendor decoding. Bank changes flush earlier input, release only source-owned A/B contacts and reset deck pickup. Ordinary MIDI controls retain their existing decoder and fragment state.
All157 importer checks,14 focused native checks and iPad framework compilation pass. Native checks include fragmented/mixed SysEx, malformed/oversized messages, sampler isolation, two-source ownership, bank/reconnect reset, overload without partial dispatch, ordinary-controller byte input and a real-WAV A/B Cue/Play flow with Sync retained. The generic held-Cue fixture now covers142 automatic profiles.
The first real-WAV fixture sent deck-B controls before its asynchronous load completed. The corrected fixture waits for that load, as existing fixtures do. Failed logs remain in `TestBuilds/r324/`.
Earlier203 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches204 data recipes and170 automatic-core physical models. The automatic-core remainder is142; full theoretical support remains open for312 models. The repository check retains twelve historical broken links.
No sampler, recording, physical hold duration, Bluetooth pairing, complete feedback/lifecycle, signed app/install or physical/A10X acceptance is claimed.

## R325 Independent MIDI Fighter default cores

Assumption: Classic factory Default mode and Twister's documented normal mixer layer qualify separate named-port input cores. The Classic script's actual initialiser maps rows C/A/B/D, four cues each. Its header/manual still describe an older two-deck layout, so executable facts take priority. The factory PDF independently confirms the physical note map and three distinct hardware modes.

- [x] Confirm failing importer fixtures and pin the Classic manufacturer map plus separate source hashes.
- [x] Add16 Classic default pad inputs and a fixed normal A/B Twister mixer. Preserve Twister's CC switch kind, six independent Shift guards and shifted headphone level. Do not invent transport or inherit Classic pad/LED/preset facts into Twister.
- [x] Verify every Classic pad/target and release form, C/D opt-in, Twister values/Shift/isolation, native WAV control, catalogue bounds and iPad framework compilation. Compare earlier recipes.

Classic Four Banks Internal/External, configurable channels, full LED behaviour and menu programming remain open. Twister software C/D assignment, EQ kill/reset variants, FX/stems/sequencer, full rings/colours/meters and complete lifecycle remain open. No firmware or persistent preset is written. Physical/A10X acceptance remains open.

Classic adds16 default pad inputs. Twister adds29 fixed normal mixer/global inputs. All159 importer checks,8 native checks and iPad framework compilation pass. Native checks cover every Classic pad and both release forms, C/D opt-in, all16 Twister knobs, independent CC Shift ownership and two real-WAV control flows with Sync retained.
The first Classic WAV fixture expected an empty cue after the normal loader had set it. The corrected fixture explicitly clears that cue before testing set/recall. Failed and passing logs remain in `TestBuilds/r325/`.
Earlier204 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches206 data recipes and172 automatic-core physical models;140 lack automatic core. Full theoretical support remains open for312 models. The repository check retains twelve historical broken links.
No complete modes/output/lifecycle, persistent preset write, signed app/install or physical/A10X acceptance is claimed. Continue through the remaining documented sources.

## R326 Original Launchpad Mini page-aware input core

Assumption: use the original Mini's own pinned XML/script. Reset and select buffer0 before input activation. Do not inherit Mini MK3, MK2 or original full-size Launchpad addresses.

- [x] Confirm failing importer/native fixtures and pin the original Mini sources.
- [x] Add page-A Play/eight cues per deck, source Shift guarding, and page-H individual library/load controls. Track all eight page selectors so other pages cannot fire these controls.
- [x] Verify all targets, two/four-deck availability, page/Shift/release/source isolation, setup failure, reconnect reset and real-WAV Play/cue flow. Run importer checks and compile the iPad framework. Compare earlier recipes.

The source loops toggle on press and conditionally on release. Native toggle-loop buttons do not preserve that contract, so those pads remain inactive. Seek/sampler/fast-scroll/zoom/Shift-delete, complete feedback and physical/A10X acceptance remain open. No audio route is inferred.

The original Mini adds46 bounded inputs. All160 importer checks,8 native checks and iPad framework compilation pass. Native checks cover every Play/cue target, two/four-deck availability, all page selectors, CC/Note separation, Shift, individual library/load targets, independent source pages, setup failure, reconnect reset and real-WAV Play/cue with Sync retained.
Earlier206 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches207 data recipes and173 automatic-core physical models. The automatic-core remainder is139. Full theoretical support remains open for312 models. The repository check retains twelve historical broken links.
Loops, other source pages, full feedback/lifecycle, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R327 Independent MK2 and Mini MK3 Launchpad cores

Assumption: preserve the pinned source's initial two-tall A/B layout. Do not silently implement dynamic deck/sampler selection or inherit hardware setup across models. The manufacturer guides independently qualify their grid addresses and mode commands.

- [x] Confirm failing importer/native fixtures for independent MK2 and Mini MK3 identities, setup and port rules.
- [x] Add fixed normal A/B Play, held Cue, Sync, PFL, key lock, loop points/reloop, four cues, six fixed loops and halve/double controls. Retain both modifier guards and individual library controls. Keep source Load-if-empty and other modes inactive.
- [x] Add source-valued core lamps. Select MK2 Session layout. Select Mini MK3 Programmer mode only on its MIDI interface and return to Live mode on disconnect. Record the original full-size Launchpad driver boundary.
- [x] Verify both release forms, modifier ownership, loop arguments, every native target, port/duplicate/setup failure isolation, lifecycle and real-WAV Cue/Play/loop/Sync. Run importer checks and compile the iPad framework. Compare earlier recipes.

Dynamic chord-selected layouts, C/D/sampler assignment, alternate presets, conditional Load, key/grid/quantise/nudge/jump variants, held library scrolling, full RGB/feedback/calibration and physical/A10X acceptance remain open. Fixed A/B replaces source software layout selection. No audio route is inferred.

Each independent model adds47 inputs and8 core lamps. All162 importer checks,9 native checks and iPad framework compilation pass. Native checks cover fixed A/B targets, every normal control, loop arguments, both Cue release forms, independent modifiers, modifier-independent halve/double and library controls, exact lamp packets, port/duplicate/setup failure isolation and cleanup.
The WAV check exercises held Cue, Play, fixed loops and reloop on both models, with finite audio and Sync retained. The generic held-Cue fixture now covers144 automatic profiles. A test helper first had its packet/destination parameters reversed and omitted `try`. Failed logs remain in `TestBuilds/r327/`.
Earlier207 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches209 data recipes and175 automatic-core physical models. The automatic-core remainder is137. Full theoretical support remains open for312 models. The repository check retains twelve historical broken links.
The original full-size Launchpad retains its independently confirmed non-class-compliant driver boundary. No direct iPad support is inferred. Dynamic layouts, conditional Load, full RGB/feedback/modes/calibration, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R328 CDJ-101 timed input and native player core

Assumption: retain the independent CDJ-101 source's channel1/2 wire contract. Native player allocation replaces hard-coded software A/B ownership. A source-local byte adapter normalises the browser's literal65-forward/otherwise-back rule and emits logical Load only for a push released within200 ms.

- [x] Confirm failing native protocol and importer fixtures. Pin XML, script and shared pitch helper.
- [x] Preserve callback arrival timestamps through the existing inbox. Keep click times per source/channel, reject repeated/unowned/late/backwards releases and reset on reconnect. Bound decoded expansion before dispatch. Ordinary MIDI and SMK-25 II retain their own decoders.
- [x] Add named-port Play, held Cue, shifted Sync, short-click Load, standard pitch, source tick scratch/wheel and track/group browser inputs. Convert source143 ticks at45 RPM to native33⅓-RPM units. Keep unqualified shared output inactive.
- [x] Verify fragments, malformed/foreign messages, click boundaries, multi-source/channel ownership, deck allocation, Shift release, overload/reset and real-WAV Cue/Play/scratch/Sync. Run importer checks and compile the iPad framework. Compare earlier recipes.

Native fixed touch replaces the source delayed100 ms outer-to-inner spinback handover. Shifted scan/beat-grid/fine-wheel alternatives, exact outer-wheel response, output-channel ownership, complete feedback/lifecycle, native calibration and physical/A10X acceptance remain open. No audio route is inferred.

The CDJ-101 adds22 logical inputs behind its source-local timing/browser adapter. Callback arrival timestamps survive the existing inbox. Decoder state stays per source and channel. Short release emits logical Load after releasing Shift. Expanded frames pass the existing dispatch limit before any action is delivered.
All163 importer checks,22 native checks and iPad framework compilation pass. Native checks cover256 browser values, full pitch resolution, exact200 ms boundaries, repeated/unowned/backwards releases, fragments, channel/source isolation, reconnect/overload reset, independent player allocation and real-WAV tick/Cue/Play playback with Sync retained. SMK-25 II and ordinary factory decoding regressions also pass. The generic held-Cue fixture now covers145 automatic profiles.
Swift first rejected a compact test endpoint expression. Explicit endpoint fixtures resolve that compiler limit. A later fixture counted the existing neutral wheel-stop events as input dispatch. It now excludes those required cleanup events. Failed logs remain in `TestBuilds/r328/`.
Earlier209 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches210 data recipes and176 automatic-core physical models. The automatic-core remainder is136. Full theoretical support remains open for312 models. The repository check retains twelve historical broken links.
Exact outer-wheel/spinback/Shift alternatives, output-channel ownership, complete feedback/lifecycle/calibration, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R329 Manual factory protocol retention

Assumption: a manually applied vendor profile must retain its input decoder on an unnamed MIDI endpoint. Profile selection authorises input conversion. It does not qualify or send hardware startup/output packets.

- [x] Reproduce missing SMK-25 II and CDJ-101 manual decoding on generic ports.
- [x] Persist a bounded, closed protocol tag per manual source. Route those sources through the byte port. Reset fragments, click/bank state and held contacts when the protocol changes. Retain factory identity precedence.
- [x] Clear the tag when ordinary or legacy profiles replace it, or bindings are cleared. Restore only valid bounded metadata after restart.
- [x] Verify manual vendor input, restart, replacement, cleanup, source isolation and unchanged automatic adapters. Run importer checks and compile the iPad framework. Preserve the catalogue byte for byte.

This change covers input protocol metadata only. Manual startup/output, factory-only pad-mode metadata, physical USB/MIDI-port acceptance and A10X performance remain open.

Manual SMK-25 II and CDJ-101 profiles now retain a closed protocol tag beside their saved source bindings. They use the byte input port, reset protocol state on replacement and preserve source-owned contacts. Ordinary and legacy replacements clear the tag. Automatic factory identities retain protocol precedence. Converted MIDI2 frames cannot bypass an active byte-protocol adapter.
All163 importer checks,30 native checks and iPad framework compilation pass. Native checks include manual vendor input, timed Load, restart without stale bank state, six ordinary/legacy replacements, clear/reset, independent source ownership, invalid/oversized/unowned preferences, factory precedence and a manual real-WAV Cue/Play flow with Sync retained. Automatic adapter regressions and145 held-Cue profiles pass.
All210 runtime recipes, catalogue JSON and generated report stay byte for byte unchanged. The compiled resource matches the source. Automatic core remains176 physical models with136 remaining. Full theoretical support remains open for312 models. The repository check retains twelve historical broken links.
Manual hardware startup/output, factory-only pad-mode metadata, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R330 DDJ-SR2 manual core and safe shared Load ownership

Assumption: use the independently pinned manufacturer MIDI table, with no SR/SX sibling address inference. The table qualifies positive selector state but no cold-start query. Automatic selection stays off. Shared Load stays inactive until a selector identifies A/C or B/D. External-input selection makes that side unknown again.

- [x] Confirm failing native selector/Load and importer fixtures against manufacturer pages1–6.
- [x] Add a bounded source-local adapter. Track each selector independently, clear ownership on current-bank release/external selection, reject raw logical-Load injection and release only source-owned contacts/pickup on bank changes. Reset on disconnect.
- [x] Add manual normal four-target transport, held Cue, fixed native touch/count jog, explicit14-bit pitch/mixer/globals, cue pads and guarded shared Load. Retain physical Shift ownership across A/C and B/D wire-channel changes. Keep unqualified FX, alternate pads and output inactive.
- [x] Verify unknown/positive/released/external selectors, both sides and all targets with C/D opt-in, Shifted release, fragments/overload, two-source/reconnect ownership and real-WAV Cue/Play/Sync. Run importer checks and compile the iPad framework. Compare earlier recipes.

Cold-bank discovery, automatic setup, full hardware Vinyl/Shift/pad/FX modes, audio routing, feedback/lifecycle, jog calibration and physical/A10X acceptance remain open. Source logical Note126 is reserved inside the adapter; the unimplemented raw TRANS-parameter action at that address cannot load a track.

The independent manual SR2 recipe adds202 inputs. Its source-local adapter tracks left/right selectors without assuming A/B. Valid positive state routes shared Load. Current-selector releases and external/invalid selections make that side unknown and release only source-owned contacts in its A/C or B/D pair. Physical Shift identity survives wire-channel changes. Raw TRANS Note126 and shifted shared Load cannot inject logical Load.
All164 importer checks,39 native checks and iPad framework compilation pass. Native checks cover all normal buttons/cue pads, all28 explicit14-bit pairs, normal jog directions, two/four-deck availability, Shifted releases, unknown/external/invalid selectors, independent sources, reconnect/overload reset and real-WAV bank/Cue/Play flow with Sync retained. Manual protocol and earlier vendor adapters also pass.
The generator now preserves an implemented reviewed profile when it also has a pending manufacturer record. SR2 moves from adapter-needed to a manual partial profile. The missing cold query remains a visible gap.
Earlier210 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches211 data recipes. Automatic core remains176 physical models with136 remaining. Full theoretical support remains open for312 models. The repository check retains twelve historical broken links.
Cold-bank discovery, automatic selection/setup, complete modes/output/lifecycle, audio routing, native jog calibration, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R331 Original KeyLab 88 normal input core

Assumption: use the pinned original KeyLab mapping's explicit XML input dispatch. Its component MIDI fields differ from the XML in places, so output is not inferred. The upstream manual qualifies only the original88-key model. Smaller variants, Essential and MkII/Mk3 remain separate.

- [x] Confirm failing importer/native fixtures and pin the XML, device script and shared component timing.
- [x] Decode only bounded six-byte broadcast MMC commands. Emit bounded native transport pulses because MMC supplies no release duration. Keep ordinary keyboard notes and mod-wheel CC1 out of DJ transport.
- [x] Preserve the source's275 ms Sound/Multi deck selection, two cue layouts and inactive sampler layout. Add fixed C/A/B/D faders/pitch, globals, selected-deck gain/EQ/filter and eight native cues. Reset owned contacts and affected pickup/debounce on deck/layout changes.
- [x] Verify mode/channel/address isolation, malformed/fragmented frames, timing boundaries, all four targets with C/D opt-in, controls/pads, source/reconnect/overload isolation and real-WAV transport/Sync. Run importer checks and compile the iPad framework. Compare earlier recipes.

Input setup requires the original factory first control bank. No persistent preset or output packet is sent. MMC has no physical hold duration. Intro/outro markers, cues9–16, samplers, recording, menu/FX/skin actions, display/LED timing, full lifecycle/calibration and physical/A10X acceptance remain open.

The wider reuse audit also checked VirtualDJ's public material. Its staff confirm that built-in wire definitions are not public. Custom mapper labels are not those definitions. [2025 source-access statement](https://virtualdj.com/forums/264927/VirtualDJ_Technical_Support/Creating_an_Traktor_Kontrol_S5_definition_file_from_an__Traktor_Kontrol_S8_or_D2_definition_file.html). No installer extraction or controller support is inferred from those labels.

The 88-specific recipe adds83 logical bindings. Bounded MMC pulses preserve transport without inventing physical hold time. Ordinary keyboard notes and mod-wheel CC1 cannot become transport. The source275 ms selector timing and released snapshot controls retain separate per-source deck/layout state. Fixed C/A/B/D faders remain separate from selected-deck pickup.
All165 importer checks,32 native checks and iPad framework compilation pass. Native checks cover malformed/fragmented/oversized MMC, timing boundaries/repeated presses, all source targets, fixed controls and selected knobs, both cue layouts, sampler blocking, learned Cue cleanup, source/reconnect/overload isolation and a real-WAV MMC/mixer/Sync flow. SR2/manual protocol regressions pass. The generic held-Cue fixture now covers146 automatic profiles; MMC physical hold duration remains unqualified.
Only88-specific aliases select this profile. Generic KeyLab-family names and smaller/later variants do not select it. The catalogue retains its existing family inventory record while naming the implemented88-key profile explicitly.
Earlier211 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches212 data recipes and177 automatic-core physical records. The automatic-core remainder is135. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
Intro/outro, cues9–16, recording/samplers, menu/FX/skin actions, delayed display/LED output, complete lifecycle/calibration, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R332 Kontrol One native base core

Assumption: use the independent Kontrol One XML and script for wire facts. Provide a fixed native base layout. Software-only bank/Shift latches, custom resume, logarithmic EQ response and loop-moving modes are not copied. The labelled Sync button controls native Sync. Knobs use native normalised steps. Full source behaviour remains open.

- [x] Pin and check each input address, four hardware deck channels, wheel direction and actual scratch-array defaults. Confirm failing importer/native fixtures.
- [x] Add bounded source-local channel-change decoding. Release owned contacts and reset affected pickup/debounce before new-deck input. Preserve physical modifiers across channel changes.
- [x] Add guarded transport, Cue, native relative gain/EQ, tempo, jog, cues5–8 and base loop controls. Keep unqualified outputs and alternate modes inactive.
- [x] Verify directions, releases, all targets, source/reconnect/overload boundaries and real-WAV Cue/Sync. Run importer checks and compile the iPad framework. Compare earlier recipes.

No input handshake is required by the pinned script. Complete modes, loop editing, kills, feedback/lifecycle, calibration and physical/A10X acceptance remain open.

The independent recipe adds116 bindings. All116 addresses match the pinned XML. Seven separately owned physical modifiers survive hardware channel changes. A source-local barrier releases owned contacts and resets non-modifier pickup/debounce before dispatch on the new channel. The active150-tick/45-RPM source defaults give202.5 effective native ticks.
All166 importer checks,23 native checks and iPad framework compilation pass. Native checks cover all128 wheel/knob values on four channels, fragments, unknown traffic, every base button, held modifiers, two-source Cue ownership, pitch centre, native knob steps, reconnect/overload reset and real-WAV Cue/jog/Play/Sync. The generic held-Cue fixture now covers147 automatic profiles.
The first native run caught a rejected direction-step field. Its existing validation guard now admits gain/EQ only for the reviewed Kontrol One protocol and knob addresses. Ordinary profiles, other actions, foreign addresses and oversized steps remain rejected. Failed logs remain in `TestBuilds/r332/`.
Earlier212 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches213 data recipes and178 automatic-core physical records. The automatic-core remainder is134. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
Complete source modes/loop editing/kills, dynamic output ownership, lifecycle/calibration, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R333 MIDI Fighter Spectra bank-aware core

Assumption: use the independent Spectra XML/script and manufacturer guide for default channel/bank facts. Normal Note Off always releases; it cannot activate a cue. Keep Classic, Twister and Spectra identities separate. No persistent preset is written.

- [x] Pin default notes, hardware bank notifications and transient bank-selection output. Confirm failing importer/native fixtures.
- [x] Add bounded source-local deck selection and bank boundaries. Keep fixed C/A/B/D filter switches separate from selected-deck cues. Release owned contacts on bank/deck changes and reset decoder state on reconnect.
- [x] Add eight native cues for each selectable deck and four filter switches. Select the hotcue bank through the reviewed transient startup packet. Fail closed when paired startup cannot complete.
- [x] Verify all pads/selectors, releases/foreign channels, source/reconnect/overload boundaries and real-WAV cues/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

EQ kills, intro/outro, samplers/stems, RGB/ground animations, dynamic selected-deck feedback, complete lifecycle and physical/A10X acceptance remain open.

The independent Spectra recipe adds36 logical inputs: eight selected-deck cues across A/B/C/D and four fixed C/A/B/D filter switches. Its transient startup selects the hotcue bank through one paired output. Failed startup keeps input inactive. Hardware bank and positive deck-selection boundaries release owned contacts before further cue dispatch. Normal Note Off always releases, regardless of release velocity. Raw logical channels cannot inject cues.
All167 importer checks,28 native checks and iPad framework compilation pass. Native checks cover all eight cue addresses and both selector rows, all128 Note Off velocities, default channel isolation, fixed filter order, C/D opt-in, source/reconnect/overload state, learned Cue cleanup, paired startup failure and real-WAV cue set/recall with Sync retained. Earlier manual protocol and Kontrol One checks also pass. The first compile caught test closures with an omitted second parameter; corrected fixtures and failed logs are preserved.
Earlier213 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches214 data recipes and179 automatic-core physical records. The automatic-core remainder is133. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
Custom firmware/channel/side-button settings, EQ kills, markers, samplers/stems, RGB/ground animations, dynamic selected-deck feedback, complete lifecycle, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R334 DUO and DUO MKII manual performance controls

Assumption: the manufacturer's DUO MKII product page explicitly links the same DUO routing/MIDI table. Reuse that table for two separately named profiles. Do not infer PRIMO or QUATTRO compatibility. Hardware mixer controls remain inactive because the documented external-deck route is not implemented. Automatic selection stays off.

- [x] Pin the manufacturer table and MKII page link. Confirm failing importer/native fixtures.
- [x] Add manual two-deck cue banks1–8, Sync, loop push and fixed Load inputs. Retain distinct normal/shifted release addresses. Reject sampler, fader-start and unqualified mixer/relative-encoder input.
- [x] Verify every reviewed button, Shift/rearm, distinct model aliases, manual restart and source ownership. Run importer/native checks, a real-WAV cue flow and iPad framework compilation. Compare earlier recipes.

The earlier PRIMO audit already records contradictory printed channels and unrevised14-bit pitch. The newly downloaded guide has the same pinned hash. PRIMO remains open; no sibling address correction is inferred.

The two separately named manual profiles each add43 inputs. The MKII manufacturer page links the same pinned protocol table. Both cue banks use their explicit other-function channel addresses. Global sampler traffic, fader-start Note0, mixer/PFL and unqualified relative encoders remain inactive. Shifted release aliases preserve normal rearm without activating an action. No hardware audio route or automatic setup is inferred.
All168 importer checks,9 native checks and iPad framework compilation pass. Native checks cover every cue-bank address, Sync/loop/Load, shifted release/rearm, blocked sampler/mixer/fader-start traffic, separate aliases, manual preference restoration without held Shift, source isolation and real-WAV cue set/recall with Sync retained for both models. A preliminary fixture used a private binding field; the corrected fixture reads the public profile contract. Both failed logs remain in `TestBuilds/r334/`.
Earlier214 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches216 data recipes. DUO and MKII move from protocol-needed to manual partial profiles. Automatic core remains179 physical records, with133 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
External per-deck audio routing, hardware/software mixer ownership, USB/driver qualification, relative loop/browser behaviour, samplers/FX, lights/lifecycle, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R335 P1-Nano manual stateful input core

Assumption: use the pinned P1-Nano XML/script and the documented DAW1 Bitwig default. Follow executable XML groups for A/B/C/D lane ownership; some manual descriptions show a different C/A/B/D order. Keep MIDI1 input selection manual while port, motor and display lifecycle remain unqualified. No MCU sibling or D-5 output protocol is inferred.

- [x] Confirm failing fixtures for selected transport, Flip latch, per-knob parameter selection and the independent velocity codec.
- [x] Add bounded source-local decoding and a closed protocol tag. Release owned contacts and reset pickup/debounce on deck/control-mode changes. Keep raw logical channels and unused touchscreen/keyboard/master messages inactive.
- [x] Add48 manual logical bindings for four-target transport, full14-bit normal/Flip faders and gain/EQ/filter encoders. Keep the source's counted0.01 normalised knob steps.
- [x] Verify every target/parameter, neutral values, fragments, repeated Flip presses, source/reconnect/overload boundaries and real-WAV Cue/Play/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

Motor feedback, current software value display, master-fader midpoint, reset switches, custom touchscreen controls, recording, navigation modes, complete lifecycle and physical/A10X acceptance remain open.

The manual MIDI1 recipe adds48 logical bindings. Source-local decoding keeps selected transport, latched Flip and four independent gain/EQ/filter assignments separate. Full14-bit faders retain normal volume and centred inverted tempo. The independent encoder codec preserves every source count, including neutral0/64 and acceleration. Profile validation limits this codec to P1-Nano gain/EQ/filter addresses.
All169 importer checks,22 native checks and iPad framework compilation pass. Native checks cover all128 encoder values, both Cue releases, all targets/parameters, precise normal/Flip faders, repeated Flip presses, malformed/foreign traffic, source-owned Cue cleanup, manual restoration without stale modes, expanded overload rejection and real-WAV Cue/Play/Sync. Existing manual protocol and147 automatic held-Cue profile checks also pass. A preliminary fixture needed an explicit numeric array type; its failed log remains in `TestBuilds/r335/`.
Earlier216 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches217 data recipes. P1-Nano moves from adapter-needed to a manual partial profile. Automatic core remains179 physical records, with133 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
Motor/display/ring feedback, master midpoint, reset switches, custom controls/recording/navigation, endpoint/USB qualification, full lifecycle/calibration, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R336 DDM4000 manual MIDI mixer core

Assumption: use wire channel1 and explicitly enable the required DDM4000 hardware sections for MIDI. The device requires a separate DIN MIDI interface and has no digital audio interface. Keep this a manual accessory profile. Follow the source's four A/B/C/D strips, with app opt-in for C/D.

- [x] Pin the independent script/XML and shared component definitions. Confirm failing importer/native fixtures.
- [x] Add exact absolute EQ/level inputs, four PFL notes and a fixed native crossfader. Retain separate CC PFL light addresses. The helper staggers component initialisation at40 ms; this does not establish a per-message live-output interval. Keep full source light initialisation open. Do not map hardware trim, microphone, sampler, curve/reverse or assignment controls to unrelated actions.
- [x] Verify all strips and crossfader, C/D opt-in, input/output type separation, inactive foreign traffic and real-WAV mixer/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

DIN interface selection, manual section/channel setup, full crossfader assignment/modes, kills, microphone/sampler/FX, throttled output/lifecycle and physical/A10X acceptance remain open.

The independent manual recipe adds21 inputs and four PFL lights. Four A/B/C/D strips retain exact high/mid/low/level addresses and separate PFL notes. The fixed native crossfader uses CC21. PFL lights use CC63/73/83/93 with127/0 values; feedback CCs cannot act as PFL inputs. Hardware trim, microphone, sampler, curve/reverse/assignment and other inactive sections cannot become unrelated native actions.
All170 importer checks,7 native checks and iPad framework compilation pass. Native checks cover all absolute strip controls, PFL notes, C/D opt-in, exact CC light packets, foreign channels, ignored hardware sections and real-WAV mixer control with Sync retained. The first light fixture exposed a missing required output field; corrected generated records now pass the whole-catalogue load check. Failed logs remain in `TestBuilds/r336/`.
Review distinguishes the helper's40 ms component initialisation staggering from live output. It does not establish a required40 ms interval for every lamp message. The four explicit core lamps are retained. Full source light initialisation and lifecycle remain open.
Earlier217 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches218 data recipes. DDM4000 moves from adapter-needed to a manual partial profile. Automatic core remains179 physical records, with133 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
DIN interface and hardware section/channel setup, full crossfader/kill/microphone/sampler/FX modes, complete output/lifecycle, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R337 Spectra filter rearm at bank boundaries

Serial review found that hardware bank changes reset selected-deck cues but retained fixed filter-button debounce. If a filter pad changes bank before its old release arrives, its next press can be missed. Reset all source input values at hardware bank boundaries. Deck-selection changes can keep the narrower cue reset.

- [x] Reproduce the missed next press for each fixed filter pad. Check learned Cue ownership on those pads across two sources.
- [x] Reset fixed filter debounce on hardware bank changes without changing protocol routing, source-owned cleanup or catalogue recipes.
- [x] Run focused native checks, importer checks and iPad framework compilation. Preserve all catalogue/runtime bytes.

The regression reproduced a missed second press on all four fixed filter pads after a bank change without the old release. Hardware bank boundaries now reset all source input values. Deck selection retains its narrower cue-only reset. Source-owned contact cleanup is unchanged. A learned Cue on another controller remains held until that source releases it.
All170 importer checks,26 native checks and iPad framework compilation pass. The two new bank/ownership checks, earlier Spectra/P1-Nano input cases, real-WAV cue/Sync flows, bounds and147 automatic held-Cue profiles pass. The failing regression log remains in `TestBuilds/r337/`.
All218 runtime recipes, catalogue JSON and generated report remain byte for byte unchanged. The compiled resource matches the source. Automatic core remains179 physical records, with133 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
This is a serial review fix. No signed app/install or physical/A10X acceptance is claimed. Continue through the remaining source-backed controllers.

## R338 Timed factory setup and SCS.3m fixed mixer core

Assumption: use the independent SCS.3m flat-mode protocol. Provide a fixed native A/B EQ mixer layout. Top sliders use the explicitly supported absolute mode for native filter control. Full software deck/FX/Master modes remain inactive. No factory reset or persistent preset is written.

- [x] Confirm failing fixtures for bounded setup sequencing, settling after actual send completion and blocked input before readiness.
- [x] Add optional bounded per-message startup delays. Use the existing input polling loop and an injected monotonic clock. Keep all earlier profiles on their existing immediate setup path. Limit pending work, cancel stale setup and fail closed on send failure.
- [x] Gate known timed-profile inputs while setup is missing or incomplete. Retain the final hardware-ready timestamp, so queued earlier frames cannot dispatch and later valid frames are preserved. Reject manual application when an automatic paired setup session is absent.
- [x] Add the nine-packet SCS.3m setup: flat mode, then absolute mode/termination pairs for sliders0/1/8/9, each with20 ms settling after completion. Other EQ/crossfader sliders retain the flat source's absolute interpretation. Add28 fixed native mixer/modifier inputs. Keep unqualified shutdown/output inactive.
- [x] Verify late polling, source isolation, setup failure/cancellation/retry, missing output, modifier cleanup, all controls and real-WAV mixer/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

Success requires actual send-completion spacing in the injected-clock fixture, bounded work per poll and input remaining inactive after failed or cancelled setup. Full C/D/FX/Master software modes, relative slider alternatives, meters/lights, delayed shutdown/lifecycle and physical/A10X acceptance remain open.

The independent automatic recipe adds28 fixed native inputs and nine transient setup packets. Each required20 ms settling interval starts after actual send completion, including the final interval. Polling advances bounded work without blocking. Failed, missing, cancelled or disconnected setup keeps input and ordinary feedback inactive. Earlier queued frames cannot dispatch. Later frames retain the actual hardware-ready timestamp. No factory reset or persistent preset is written.
All171 importer checks,32 focused native checks and iPad framework compilation pass. Native checks cover all nine send-failure positions, late polling, send cost, final settling, two-source isolation, explicit retry, disconnect/disable/stop/restart, paired-output absence, modifier guards, all fixed mixer controls and real-WAV mixer/Sync. Earlier manual protocol, Spectra and147 automatic held-Cue checks also pass. Failed compile/fixture logs remain in `TestBuilds/r338/`.
Earlier218 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches219 data recipes and180 automatic-core physical records. The automatic-core remainder is132. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
Full C/D/FX/Master software modes, relative slider alternatives, slider resets, meters/lights, delayed shutdown/lifecycle, manual unpaired setup, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R339 BCR2000 factory preset core and direct keylock state

Assumption: use the independent factory-preset1 source. Select preset1 with its two-byte Program Change. Do not write a preset, reset the controller or infer BCF2000 compatibility. Retain native fixed A/B EQ/filter controls on push-encoder group2. Buttons use the source's direct state behaviour, including default latched on/off messages.

- [x] Confirm failing fixtures for two-byte channel messages, preset selection, shared Shift and direct keylock on/off.
- [x] Accept valid two-byte Program Change/channel pressure setup messages. Reject incorrect channel-message lengths. Retain all earlier setup data.
- [x] Add a direct keylock state action through the existing explicit playback setter. Avoid snapshot-based toggles and pickup for state switches. Add bounded shared global CC Shift identity.
- [x] Add12 BCR2000 inputs, eight ring outputs and two keylock lamps from pinned source. Keep unsupported pitch/loop/reverse/FX controls inactive.
- [x] Verify every reviewed address, repeated/rapid state changes, shared Shift, source isolation, preset-send failure, exact outputs and real-WAV keylock/mixer/Sync. Run importer/native checks, compile the iPad framework and compare earlier recipes.

Success requires exact two-byte preset selection, explicit ordered keylock state and unchanged earlier recipes. Custom presets, complete software modes/Shift-lamp synchronisation, lifecycle and physical/A10X acceptance remain open.

The automatic recipe adds12 inputs and10 core CC outputs. Exact two-byte Program Change selects preset1 without rewriting it. Group2 supplies fixed native A/B EQ/filter controls. Keylock uses explicit on/off state through the existing playback setter. Repeated messages remain idempotent, with no pickup or snapshot-based toggle. Both Shift CCs share one last-message identity per source. Unsupported pitch/loop/reverse/FX traffic stays inactive.
All172 importer checks,25 focused native checks and iPad framework compilation pass. Native checks cover every wire channel's setup-message length, all core addresses, repeated/rapid state switches, source isolation, shared Shift, paired preset failure/absence, exact feedback and real-WAV keylock/mixer/Sync. SCS.3m timing, catalogue bounds and147 automatic held-Cue checks also pass. The initial red test and a reconnect fixture that omitted restored endpoints remain in `TestBuilds/r339/`.
Earlier219 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches220 data recipes and181 automatic-core physical records. The automatic-core remainder is131. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
Custom presets, pitch/loop/reverse/FX and filter/kill buttons, complete Shift-lamp synchronisation/output/lifecycle, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R340 SC5000M captured protocol and manual selected-layer core

Assumption: use the author's pinned SC5000M captures and working proxy/mapping. Keep the raw Computer-mode source separate from its virtual proxy. Implement the observed LAYER button as a native two-deck selector. Do not infer SC5000/SC6000 variants, platter touch, pitch polarity or screen compatibility from the LC6000 table.

- [x] Pin the public capture/specification, proxy, mapping and iOS investigation. Confirm failing fixtures for a missing SC5000M core.
- [x] Add bounded source-local parsing for LAYER, shared Shift, normal transport and per-deck pad modes. Keep releases with their original logical deck/address. Block motor rotation counters, pitch bend, absent touch and unused traffic.
- [x] Add a manual native two-deck transport/loop/browser core, Hot Cue1–8 and source auto-loop sizes. Keep Roll/Slicer pads inactive. Persist the closed input protocol without persisting transient deck/mode/held state.
- [x] Verify every reviewed address, repeated selectors, held releases, fragments, source/reconnect/overload boundaries and real-WAV Cue/Play/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

Success requires motor/noise traffic producing no transport action and no stale held Cue across layer/mode changes. Motor start/stop, platter hand inference/calibration, display/touchscreen, pitch qualification, complete lifecycle/audio and physical/A10X acceptance remain open. Automatic selection stays off.

The independent manual recipe adds111 logical bindings from the pinned public author specification, captures and working proxy/mapping. Native LAYER starts on A and toggles A/B on fresh presses. Each deck retains its own Hot Cue/auto-loop mode. Original deck/address ownership survives releases across layer/mode changes. Shared Shift remains global. Motor counters, pitch bend, absent touch, track-skip loading, unqualified pitch and inactive Roll/Slicer pads cannot become unrelated native actions.
All173 importer checks,21 focused native checks and iPad framework compilation pass. Native checks cover every pad/release address, original ownership, repeated selectors, fragments/running status/realtime, source isolation, transient-state reset, persisted manual protocol, overload shutdown and real-WAV Cue/Play/Sync under repeated motor/noise packets. Earlier manual protocol and147 automatic held-Cue checks pass. The first native run caught two fixture assumptions: a re-press before the old physical release and a saved enable preference mistaken for an open input port. Corrected fixtures and failed logs remain in `TestBuilds/r340/`.
Earlier220 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches221 data recipes. SC5000M moves from protocol-needed to a manual partial profile. Automatic core remains181 physical records, with131 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
The new source also records motor commands,3683 measured ticks/revolution and a separate15e4:a00a screen device. These are protocol evidence, not a finished native motor/display implementation. Motor/hand inference, platter gearing, pitch qualification, screens, complete modes/output/lifecycle/audio, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R341 Independent SC6000, SC6000M and SC5000 normal transport contracts

Assumption: the model-specific factory assignment files independently declare the same reviewed normal transport, LAYER/Shift and Hot Cue addresses. Reuse only that bounded native byte contract. Keep raw Computer-mode selection manual. These firmware assignments do not establish a complete host SDK, cold-start handshake, jog calibration or display protocol.

- [x] Pin and compare JP13 SC6000, JP14 SC6000M and JP07 SC5000 files. Confirm failing importer fixtures.
- [x] Add separate manual normal transport/loop/browser and Hot Cue profiles. Reuse the verified source-local two-deck parser behind a separate closed protocol tag. Keep other pad modes, pitch, jog/touch, motor, parameter and track-skip controls inactive.
- [x] Verify each profile's identity, all reviewed wire addresses, shared Shift/layer/pad boundaries, persistence, ignored differing controls and real-WAV Cue/Play/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

Success requires independent model address evidence and unchanged SC5000M/earlier recipes. Original assignment files distinguish motorised controls, jog sensitivity and pitch LEDs. Do not copy these differences across models. Complete modes/output/lifecycle/audio and physical/A10X acceptance remain open. Automatic selection stays off.

Three separately named manual profiles each add79 logical inputs. JP13, JP14 and JP07 independently confirm the reviewed normal channel/address contract. A separate closed protocol tag reuses bounded native layer/Shift/Hot Cue parsing. Only the first eight Hot Cues and normal transport/loop/browser controls are active. Other pad modes remain inactive. No jog sensitivity, touch/motor response, pitch LED orientation or parameter address crosses model boundaries.
All174 importer checks,24 focused native checks and iPad framework compilation pass. Importer checks confirm each independent factory component/address and pinned hash. Native checks exercise all reviewed transport/cue addresses on both logical layers, mode guards, Shift, retained manual protocol without transient state, sibling identity separation and real-WAV Cue/Play/Sync for each model. SC5000M and earlier manual protocol checks also pass.
Earlier221 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches224 data recipes. SC6000, SC6000M and SC5000 move from protocol-needed to manual partial profiles. Automatic core remains181 physical records, with131 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
These firmware assignments corroborate normal wire addresses. They do not supply a complete host SDK or establish USB Computer-mode lifecycle. Model-specific jog/touch/motor/pitch, other modes/parameter controls, screen/display, complete output/lifecycle/audio, signed app/install and physical/A10X acceptance remain open. Continue through the remaining source-backed controllers.

## R342 RANE ONE MKII independently corroborated manual subset

Assumption: the independent public owner export and earlier staff version3 template agree on26 unconditional deck control rows. Reuse only those rows and the explicit global Shift identity. Neither export supplies normal Play or the missing RaneOneMK2 class. Do not infer motor, held main Cue, platter, paired pitch or mixer routing from related RANE hardware.

- [x] Pin the independent owner repository/archive and compare every selected row with the staff export. Confirm a failing importer fixture.
- [x] Add manual Load, normal Sync/explicit Sync-off, keylock, held bends, loop controls and source-valued browser input. Guard normal controls with global Shift and retain shifted release aliases. Leave unknown/conditional/motor/mixer/Play/Cue/pitch input inactive.
- [x] Verify all reviewed addresses, Shift release/rearm, explicit Sync-off, source isolation, ignored traffic and real-WAV loops/bends/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

Success requires both source exports to agree on each imported row. Motor/platter, normal Play/main Cue, pad modes, pitch resolution, complete custom-class lifecycle/audio and physical/A10X acceptance remain open. Automatic selection stays off.

The manual recipe adds45 input bindings from26 unconditional control rows that agree across both public exports. Load, normal Sync/keylock, held bends, loop controls and the flipped rotary64 browser retain their actual channels. The separate Sync-off message uses its explicit off contract even while Shift is held. Normal controls use the global Shift guard and release aliases. Unqualified normal Play/main Cue, pitch, motor/platter, mixer and conditional pad traffic stays inactive.
All175 importer checks,13 focused native checks and iPad framework compilation pass. Importer checks compare all selected row fields with both pinned exports. Native checks cover every reviewed button/browser, both decks, exact loop-out-or-double, held bend release across Shift, normal rearm, source isolation, explicit Sync-off and real-WAV loops/bends/Sync. Earlier SEVENTY subsets, catalogue bounds and147 automatic held-Cue profiles also pass.
Earlier224 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches225 data recipes. ONE MKII moves from protocol-needed to a manual partial profile. Automatic core remains181 physical records, with131 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
The missing RaneOneMK2 class still owns normal Play, motor/platter and lifecycle. Numbered cue targets do not establish held main Cue. Pitch pairing/polarity, shared modes/FX/stems, external audio routing, complete output/lifecycle, signed app/install and physical/A10X acceptance remain open. No downloaded source executes in the app. Continue through the remaining source-backed controllers.

## R343 nanoKONTROL2 native-mode handshake and fixed mixer core

Assumption: use Korg's published native mode instead of rewriting scene data. Search the paired physical device, read its configured global channel and request native mode. Wait for the model/channel-specific acknowledgement before routing fixed channel16 controls or feedback. Provide a fixed native four-strip volume/PFL mixer and headphone blend. Complete NSMR software layers remain open.

- [x] Pin Korg's implementation and independent upstream functional addresses. Confirm failing core/importer fixtures.
- [x] Add bounded search/native-mode reply parsing. Ignore input before confirmation, malformed/foreign replies and ordinary/custom/DAW traffic. Convert reviewed native CC buttons to logical notes. Keep source-local state.
- [x] Send source-requested setup only through the paired factory output. Fail closed on send failure, gate ordinary feedback and send native-mode exit on shutdown. Reject unpaired manual setup. Preserve saved scenes and never send scene data/write/reset commands.
- [x] Replace the earlier four-input manual recipe with12 automatic fixed mixer/modifier inputs and four PFL lamps. Dedicated faders stay independent of held modifiers. Other banks, software modes and audio are not inferred.
- [x] Verify all16 global channels, all controls, first presses/releases, handshake fragments/rejections/failures/reconnect, paired outputs, source ownership and real-WAV mixer/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

Success requires no input/output before native acknowledgement and no persistent programming. Other software layers, full lifecycle recovery, exact USB behaviour, signed app/install and physical/A10X acceptance remain open.

The earlier four-input manual recipe now uses an acknowledged native-mode contract with12 logical inputs and four PFL lamps. Search validates the model and echo before reading the configured global channel. The native request uses that channel. Only the matching native-mode acknowledgement enables input and ordinary feedback. Fixed channel16 controls bypass saved scene assignments. No scene dump/write, reset or persistent programming is sent.
Failed setup attempts send a best-effort native exit when the global channel is known. Normal shutdown also sends exit on the discovered channel. Missing/malformed/foreign replies, absent output and failed sends keep controls/feedback inactive. Native exit releases only owned contacts. Clearing learned mappings disables the factory profile and exits mode; fresh setup is required after re-enabling it.
Serial review also corrected the source-refresh reconnect selection for paired setup sessions. When endpoint references change, inactive timed/native setup inputs must reconnect before they can become ready. This applies to SCS.3m and the new native handshake. Physical USB reconnect acceptance remains open.
All176 importer checks,26 focused native checks and iPad framework compilation pass. Native checks cover all16 global channels, exact mode requests/exit, bounded malformed/foreign/fragmented replies, first button presses/releases, all fixed controls, C/D opt-in, held guards, send failures/retry, paired-output absence, learned Cue ownership, overload and clear/re-enable. Real-WAV mixer/PFL/blend checks retain finite audio and Sync. Earlier SCS.3m timing, catalogue bounds and147 automatic held-Cue checks also pass. Initial test compile and a learned-binding-count fixture correction remain in `TestBuilds/r343/`.
The catalogue retains225 data recipes. Only nanoKONTROL2 changes;224 earlier recipes retain identical data. The compiled resource matches the source byte for byte. Automatic core reaches182 physical records, with130 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
The native layout is a fixed four-strip mixer. Latched NSMR/selected-deck software layers, mute/slip/transport and other controls, response timeout/recovery, complete lifecycle, signed app/install and physical/A10X acceptance remain open. This USB MIDI accessory has no inferred audio interface. Continue through the remaining source-backed controllers.

## R344 nanoPAD2 acknowledged native cues and loops

Assumption: use the independent nanoPAD2 project12 protocol and its fixed native pad/Scene messages. Reuse the common Korg search/native handshake only after model-specific validation. Retain upstream interleaved A/B cue placement, Clear guards and supported loop controls. Do not copy the nanoKONTROL2 control table or write saved scenes.

- [x] Pin the independent protocol/XML/script and confirm failing importer fixtures.
- [x] Share bounded Korg handshake parsing through a closed model enum. Preserve the existing nanoKONTROL2 API/data and all its checks.
- [x] Add source-local native Scene selection, original pad-release ownership, dynamic scene lamps and barriers that preserve held Clear. Support15 first-bank cues, Clear guards and14 reviewed loop inputs. Block unavailable cues9–16, destructive clearing, XY/touch-scale, other layers and held loop-move variants.
- [x] Route every setup/scene-light request through the paired physical output. Fail closed on any request failure. Retain native exit and manual setup guards for both models.
- [x] Verify all channels, cross-model replies, every scene/pad/release, held combinations, source/reconnect/overload/failure boundaries and real-WAV cue/loop/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

Success requires distinct model/control contracts and unchanged nanoKONTROL2/earlier recipes. Reloop tap/hold timing, later cue slots, other modes, reply timeout/recovery, full lifecycle and physical/A10X acceptance remain open.

The earlier four-input manual recipe now has31 automatic logical bindings:15 first-bank cues, two Clear guard addresses and14 third-bank loop controls. Native Scene selection starts0, uses fresh presses and sets the four documented Scene lamps. Original release addresses survive Scene changes. Held Clear survives the boundary until its actual release. Resize commands stay inactive while a source loop/reloop pad is held. Later cues9–16, timed reloop, fourth-bank controls and XY/touch-scale remain inactive.
The shared Korg decoder uses a closed model enum and independently validates project/family12 for nanoPAD2 and13 for nanoKONTROL2. Their control tables stay separate. Compatibility aliases preserve the earlier nanoKONTROL2 API. The connection retains each source's actual protocol, readiness, paired output and native exit. Failure at any setup or Scene-lamp message disables that source. No saved scene write/reset or persistent programming is sent.
All177 importer checks,37 focused native checks and iPad framework compilation pass. Native checks cover all16 global channels, cross-model rejection, every cue/loop/pad release, Scene lamps/debounce, held guards, all six initial send-failure positions, live Scene-light failure, retry, learned Cue cleanup and overload exit. Existing nanoKONTROL2 and SCS.3m checks pass. Real-WAV native cue/loop/mixer checks retain finite audio and Sync. The first WAV fixture pressed Play after a hotcue had already started playback; corrected test ordering and the failed log remain in `TestBuilds/r344/`.
The catalogue retains225 data recipes. Only nanoPAD2 changes;224 earlier recipes, including nanoKONTROL2, retain identical data. The compiled resource matches the source byte for byte. Automatic core reaches183 physical records, with129 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
Later cue slots, deletion, timed reloop, held loop moves, fourth-bank/XY modes, response timeout/recovery, complete lifecycle, signed app/install and physical/A10X acceptance remain open. This USB MIDI accessory has no inferred audio interface. Continue through the remaining source-backed controllers.

## R345 PRIME 4 public source core and reference archive audit

Assumption: the pinned public owner mapping establishes the PRIME 4 Computer-mode normal input contract. Its repository explicitly covers PRIME 4 and PRIME 4+. Keep separate manual profiles. Start software deck selection on A/B and pads on Hot Cue, as the source does. Do not infer hardware mixer ownership, screen support or complete host setup.

- [x] Pin the public XML/script and owner statement. Record the public reference archive boundary. Confirm failing importer/native fixtures.
- [x] Add bounded side/deck and pad-mode routing with original release ownership. Add manual transport, loops, paired tempo, Load and Hot Cue inputs. Keep unqualified traffic inactive.
- [x] Verify all reviewed addresses, mode/deck/Shift/source boundaries, persistence and real-WAV Cue/Play/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

Success requires no stale held Cue after deck changes and no accidental routing of jog, screen or mixer traffic. Complete lifecycle/output/audio and physical/A10X acceptance remain open.

Two separate manual profiles each add133 logical inputs. The source-local adapter starts on A/B, retains per-deck Hot Cue mode and routes shared Load to the selected target. Original physical button ownership survives deck and pad-mode changes. Unsupported held pads cannot become cues after switching modes. Unqualified jog, mixer, screen, FX and other pad traffic stays inactive. The public owner repository explicitly names both4 and4+; its captured metadata and checksums remain in `TestBuilds/r345/upstream/`. This is owner evidence, not a manufacturer SDK.
The capacity fixture exposed an existing manual-apply defect: saving more than256 bindings caused the bounded loader to discard the complete saved set on restart. Profile application now checks the replacement total before changing bindings, protocol state or owned contacts. An over-capacity request preserves the existing mappings and gives a clear setup message. The256-binding limit stays unchanged. Automatic factory bindings retain their separate512-input limit.
All178 importer checks,23 focused native checks and iPad framework compilation pass. Checks cover every reviewed source address, four target decks, both physical sides, all Hot Cues, unsupported modes/traffic, original release ownership, Shift, full paired tempo endpoints/pickup, source isolation, saved protocol without transient state, overload and capacity rejection. Real-WAV Cue/Play checks retain finite audio and Sync. Earlier Prime-player, catalogue,147 automatic held-Cue and learning checks pass. Failed fixture compile/value/source-row runs remain in `TestBuilds/r345/`.
Earlier225 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches227 data recipes. PRIME4 and4+ move from protocol-needed to manual partial profiles. Automatic core remains183 physical records, with129 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
A read-only audit of the public VirtualDJ2026b9746 installer found controller images and a proprietary non-XML definition archive. Images do not establish wire protocols. No software was installed or run, and no protected definitions were decoded or copied. This package does not supply a public Rane/Denon SDK. The partial archive, table of contents, component hashes and download headers remain as source evidence.
Mixer/audio ownership, browse encoding, held loop trigger, other pad/Shift/FX modes, jog/touch/calibration, screens, complete output/setup/lifecycle, signed app/install and physical/A10X acceptance remain open. Continue through public manufacturer tables and independent mappings.

## R346 MP2015 manufacturer MIDI mixer contract

Assumption: use the manufacturer manual's channel1 table after explicit MIDI enable in the Rane control panel. This profile controls the app mixer through separate audio. Do not double-process deck audio through both app and hardware EQ/levels. Do not write stored hardware settings or infer a zero-config enable handshake.

- [x] Pin and visually inspect the original MIDI tables and setup/audio pages. Confirm a failing importer fixture.
- [x] Add manual four-strip gain/EQ/level/PFL, master/headphone level/blend and separately enabled PFL lights. Leave filter-type modes, isolator/submix, source routing and hardware settings inactive.
- [x] Verify every address, C/D opt-in, channel isolation, ignored settings, exact LED values and real-WAV mixer/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

Success requires unchanged stored MIDI enable/channel settings and no automatic audio route or selection. Full hardware/software ownership, output/lifecycle and physical/A10X acceptance remain open.

The independent manufacturer recipe adds27 manual inputs and four optional PFL note lamps. Each A/B/C/D strip retains its exact gain/high/mid/low/level/PFL addresses. Dedicated master/headphone level/blend controls use their separate CC addresses. Same-number CCs and Notes keep distinct meanings. No source/configuration, MIDI-enable, reset or stored setting packet is sent. Filter selectors, isolator/crossover/resonance/submix and mic/session controls stay inactive.
All179 importer checks,17 focused native checks and iPad framework compilation pass. Native checks cover every strip/global address, C/D opt-in, PFL duplicate/release handling, Note/CC separation, inactive settings, foreign channels, exact optional LED thresholds and real-WAV mixer/Sync. DDM4000, Prime4, catalogue bounds and147 automatic held-Cue checks also pass.
Earlier227 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches228 data recipes. MP2015 moves from protocol-needed to a manual partial profile. Automatic core remains183 physical records, with129 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
The manufacturer publishes class-compliant USB MIDI/audio and deck/session playback pairs. This is source evidence, not physical iPad proof or implemented routing. MIDI starts disabled and settings stay in the mixer. Manual control requires port MIDI enable, channel1 and separate audio for app mixer control. Complete audio ownership/routing, filter and other hardware modes, full output/lifecycle, signed app/install and physical/A10X acceptance remain open. Continue through the remaining public sources.

## R347 Original RANE ONE public owner input subset

Assumption: use the separately published original RANE ONE iPad mapping. Import only explicit unconditional controls. Its missing RaneOne class still owns platter/setup behaviour. Keep ONE MKII separate. Do not interpret the numbered cue target as a held main Cue or the second Sync row as explicit off.

- [x] Pin the public original-model export and selected rows. Confirm a failing importer fixture.
- [x] Add manual Play/Load/Sync/keylock, held bends, known loop controls and source-valued Browse. Guard normal controls with global Shift and retain shifted release aliases. Keep motor/pitch/Cue, custom pads and external mixer controls inactive.
- [x] Verify each reviewed address, Shift release/rearm, source isolation, sibling identity and real-WAV Play/loop/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

Success requires original-model evidence and unchanged ONE MKII semantics. Full RaneOne class, motor/platter, lifecycle/audio and physical/A10X acceptance remain open.

The independent original ONE recipe adds43 manual bindings from25 explicit unconditional rows in the public owner export. Play uses Note0. Global Shift, Load, normal Sync, keylock, held bends, known loops and flipped rotary64 Browse retain their actual source channels. Shifted release aliases rearm ordinary controls without activating the custom shifted functions. Neither the MKII explicit Sync-off action nor its loop-out-or-double action is inherited.
All180 importer checks,13 focused native checks and iPad framework compilation pass. Checks cover each selected source row, every normal control/browser, Shift release/rearm, source isolation, held bend release, inactive motor/pitch/mixer/custom-pad traffic and sibling identity. Real-WAV Play/loop/bend checks retain finite audio and Sync. The first WAV fixture pressed Sync while it was already enabled; the corrected fixture checks the ignored second Sync address, then explicit off/on. Its failed log remains in `TestBuilds/r347/`.
Earlier228 recipes retain identical data, including ONE MKII. The compiled resource matches the source byte for byte. The catalogue reaches229 data recipes. Original ONE moves from protocol-needed to a manual partial profile. Automatic core remains183 physical records, with129 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
The source's RaneOne class is absent. Motor/platter/setup, held main Cue, full pitch, ambiguous Sync3/loop-out55, custom pads/stems/mic remaps, hardware/software mixer and audio ownership, complete output/lifecycle, signed app/install and physical/A10X acceptance remain open. No downloaded code, output, motor or stored setting command executes. Continue through the remaining public sources.

## R348 Independent PRIME GO automatic and PRIME 2 manual cores

Assumption: the two public PRIME GO owner exports contain no custom-class dependency and independently corroborate fixed Computer-mode controls. Combine them with the pinned JP11 assignment to qualify native paired tempo and normal controls. Keep PRIME2's separate JC16 assignment manual. Do not inherit another model's jog sensitivity, Shift address, tempo polarity, bank or display protocol.

- [x] Pin both public GO exports and compare their selected rows with JP11. Confirm failing importer fixtures for both models.
- [x] Add automatic GO normal transport/mixer, paired inverted tempo, source-valued browser and loops. Add separate manual PRIME2 normal transport/mixer/loops. Keep pads, jog/screens and unqualified modes inactive. Preserve exact Shift and Load channels.
- [x] Verify every reviewed address, Note/CC separation, Shift/release/source ownership, pairing/pickup, ignored modes/siblings and real-WAV Cue/Play/mixer/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

Success requires the original GO and PRIME2 identities to stay separate from GO+, PRIME4 and SC players. Automatic core input does not claim automatic audio routing, display support or physical/A10X acceptance.

Original PRIME GO adds43 automatic core input bindings. Two public owner exports without custom classes corroborate fixed raw controls. JP11 independently identifies the native PlayCue component and explicit inverted tempo pair31/75. Native input uses one paired tempo binding per deck instead of two independent speed controls. Normal transport, Load, loops, flipped source-valued Browse, four fixed mixer bands/level/PFL and headphone blend/level/crossfader retain their exact channels. Pads, jogs, dual Color FX, screens and unknown mode traffic stay inactive.
PRIME2 adds a separate49-input manual profile from JC16. Its deck channels2/3, mixer0/1 and global15 stay independent of Prime4's software-selected deck channels. Both physical Shift buttons retain independent held identities. Keylock and manual Loop In/Out use their own source declarations. Tempo polarity, browse direction, pads and held auto-loop remain unqualified. No original GO+ alias is added.
All181 importer checks,15 focused native checks and iPad framework compilation pass. Native checks cover each normal/loop/mixer/global address, held Cue and bend ownership, Shift/rearm and both physical Shift buttons, full paired tempo endpoints/pickup, browser direction, ignored pads/jog/FX/sibling traffic and real-WAV Cue/Play/mixer/loop/Sync. Prime4, catalogue bounds and148 automatic held-Cue profiles also pass. The earlier importer failure retained the old inventory expectation that GO had no automatic core; the corrected assertion and failed log remain in `TestBuilds/r348/`.
Earlier229 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches231 data recipes. Original GO moves to automatic core and PRIME2 to a manual partial profile. Automatic core reaches184 physical records, with128 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
The GO source thread reports differences between iPad models, bouncing tempo in a later export and unfinished pad/light behaviour. Those reports do not establish native GenErik DJ acceptance. Jog counts/touch/calibration, pad Bank/mode state, screen SDK, full output/setup/lifecycle/audio, signed app/install and physical/A10X acceptance remain open. Computer-mode selection is still required. No downloaded code, setup/reset, motor, output or stored-setting command executes.
The parallel public-source audit found the manufacturer DJM-A9 table through a web PDF reader, but direct manufacturer and archival downloads were unavailable. Extracted CH2 fader/CueB rows conflict with the surrounding channel/address pattern. Visual/source confirmation remains unresolved, so no A9 mapping is inferred. DJM-V5's linked current software-information page also returned an access error. Existing catalogue gaps remain explicit. Continue with other public model-specific sources.

## R349 Separate SC Live and Mixstream Pro Go manual contracts

Assumption: use the independently pinned JP20, JP21 and NH10 assignments. The public firmware researcher identifies these as SC Live2, SC Live4 and Mixstream Pro Go. Keep every profile manual. SC Live4 exposes only its fixed four-strip mixer because its Layer31 routing has no qualified host contract. Do not treat NH09's two-band MIXSTREAM definition as Pro+.

- [x] Pin model assignments and independent hardware-ID references. Confirm failing importer fixtures.
- [x] Add SC Live2 fixed transport/mixer/loops and explicit inverted tempo pair, SC Live4 fixed four-strip mixer only, and Mixstream Pro Go fixed transport/mixer only. Preserve each model's global addresses and independent held Shift identities. Leave unknown layers/pads/jog/output inactive.
- [x] Verify each source field, every active control, C/D opt-in, source/Shift/release ownership, pairing, ignored sibling/layer traffic and real-WAV audio/Sync. Run importer/native checks and compile the iPad framework. Compare earlier recipes.

Success requires no borrowed layer routing, jog calibration, pitch polarity or Pro+ alias. Manual app mixer control uses separate audio. Full host setup/lifecycle/audio and physical/A10X acceptance remain open.

Three separate manual profiles add52 SC Live2,28 SC Live4 and36 Mixstream Pro Go bindings. JP20 independently provides the SC Live2 normal transport/loop contract and explicit inverted tempo pair31/75. Its jog pair17/49 is deliberately inactive. JP21 supplies only the fixed four-strip mixer and globals; its Layer31, cold deck and shared Load ownership remain unqualified. NH10 supplies fixed two-deck transport/mixer controls without inheriting the original Pro's tempo polarity, jog codec or pad/light state.
The public firmware researcher separately identifies JP20/JP21/NH10 as SC Live2/SC Live4/Mixstream Pro Go. NH10's object name still says MIXSTREAM PRO, so that string alone is not model proof. NH09 has a different two-band mixer and is not Pro+. Pro+ is NH08S and stays separate. The researcher's documentation also distinguishes internal control-surface transport and host USB gadget mappings; an internal device startup sequence is not assumed to be the host setup contract. No firmware updater, test mode, motor, reset or stored-setting command is sent.
All182 importer checks,15 focused native checks and iPad framework compilation pass. Native checks cover every active mixer/global/transport/loop address, SC Live2 paired tempo endpoints/pickup, Note/CC separation, C/D opt-in, held Cue/source ownership, Shift release/rearm and inactive SC Live4 layer/Load/transport traffic. Real-WAV mixer/transport checks retain finite audio and Sync for all three models. Prime GO/2, catalogue bounds and148 automatic held-Cue checks also pass.
Earlier231 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches234 data recipes. Three models move from protocol-needed to manual partial profiles. Automatic core remains184 physical records, with128 without automatic core. Full theoretical support remains open for312 physical records. The repository check retains twelve historical broken links.
The SC Live4 public interoperability repository was visible in cached search results but unavailable from its current repository API. Its cached implementation is not used as host protocol proof. Current pinned model assignments and explicit manual limits remain the implementation basis. Full deck layers/pads/FX, jog/touch/calibration, screens, complete host setup/output/lifecycle/audio, signed app/install and physical/A10X acceptance remain open. Continue through the remaining public sources.

## R350 Digital Jockey 2 Master Edition driver MIDI subset

Assumption: use the independent manufacturer manual's ordinary MIDI messages after desktop driver translation or an external MIDI bridge. The Master Edition is not USB MIDI class compliant. Native iPad USB support stays unresolved. Both front channel selectors must use MIDI. No Interface Edition jog calibration, output, startup or shifted address is inherited.

- [x] Pin and visually inspect the manufacturer appendix and software-mode instructions. Confirm a failing importer fixture.
- [x] Add a separate manual normal transport, held Cue/bend, mixer/PFL and browser subset. Guard normal controls with documented Shift inputs. Keep unqualified pitch, jogs, modes and outputs inactive.
- [x] Verify every address, Shift/release/source ownership, encoder direction, inactive controls and sibling identity. Run importer/native checks, compile the iPad framework and compare earlier recipes.

Success requires explicit manual selection, no native iPad USB claim and no stored setting or output packet. Full driver/bridge, lifecycle/audio and physical acceptance remain open.

The separate manufacturer recipe adds55 manual bindings. Normal A/B transport, held main Cue/bends, PFL, loop endpoints/enable, fixed gain/EQ/level and master/headphone controls retain channel0 and the exact right-side offset. Trax uses the documented binary-offset encoder. Independent physical Shift inputs guard normal controls, including the EQ knobs and browser. Release-only aliases rearm ordinary buttons without activating unknown shifted functions. Native held release ownership survives Shift and separate sources.
All183 importer checks, eight focused native checks and iPad framework compilation pass. The native checks cover every active address, both Note Off forms, Note/CC separation, two simultaneous Shift buttons, source ownership, ignored modes/channels and real-WAV Cue/Play/mixer/loop with finite audio and Sync. The initial framework invocation rejected a jobs-option spelling before compilation. Its log remains separate from the corrected exit-zero run.
Earlier234 recipes retain identical data, including both other Digital Jockey2 editions. The compiled resource matches the source byte for byte. The catalogue reaches235 data recipes. Automatic core remains184 physical models, with128 without automatic core. Full theoretical support remains open for312 physical models. The repository check retains twelve historical broken links.
The public guide explicitly requires a Windows/macOS USB translation driver. Native iPad USB remains unresolved. Front selectors require MIDI. Jog/touch calibration, pitch polarity, shifted address layers, ambiguous Loop Active/display input, browse/jog modes, full outputs/setup/lifecycle/audio, signed app/install and physical/A10X acceptance remain open. No downloaded code, stored setting, output or reset packet executes.
A newly found VFX-1 owner forum definition has unresolved channel conflicts, duplicate CC definitions and an acknowledged AI-generated draft. It does not establish a reliable wire contract. Its inputs and suggested identity-response/startup messages are not imported. Continue with independent manufacturer or captured-protocol sources.

## R351 SP-404MKII documented DJ-mode subset and direct Sync state

Assumption: use ordinary CC messages in the manufacturer's standalone DJ mode, with separate app audio. This mode differs from the proprietary Serato control screen. Do not infer its handshake or sample-bank mapping. Play-state and return-to-sample-start semantics need separate native contracts and stay inactive.

- [x] Pin current and earlier manufacturer references. Inspect the current MIDI and mode tables. Confirm a failing importer fixture.
- [x] Add manual A/B level, direct Sync/PFL state, held bends and crossfader. Add direct Sync state through the existing state-input path. Keep all stored settings, other modes and outputs inactive.
- [x] Verify state idempotence without pickup, every address, held-source ownership and ignored modes. Check real-WAV playback/Sync, importer/native checks and iPad framework compilation. Compare all earlier recipes.

Success requires exact CC-state behaviour without changing Sync from unrelated messages. Automatic Serato setup, native Play state, complete modes/output/lifecycle/audio and physical acceptance remain open.

The independent version5 MIDI chart adds11 manual DJ-mode inputs. Both deck levels, direct Sync/PFL states and held pitch bends retain their own channels. The crossfader keeps its explicit manufacturer polarity. The new direct Sync state uses the existing state-input path without button edge priming or pickup. It sets the saved Sync choice directly. Repeated on/off messages remain idempotent. Ordinary button learning stays unchanged.
All184 importer checks,14 focused native checks and iPad framework compilation pass. Tests cover each address, first CC press, repeated states, pickup bypass, last-source bend release, foreign channels, inactive sample/FX/Looper/clock/Play traffic and real-WAV audio with explicit Sync/PFL state. BCR2000 state/feedback and148 automatic held-Cue checks also pass.
Earlier235 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches236 data recipes. Automatic core remains184 physical models, with128 without automatic core. Full theoretical support remains open for312 physical models. The repository check retains twelve historical broken links.
Current and earlier manufacturer tables agree. Their DJ mode differs from the version5 Serato control screen, whose host handshake is not published in the guide. PlayCC20 is explicit state, not a momentary toggle, and the chart's01 example differs from its detailed127 table. It remains inactive. Return-to-sample-start21, unspecified BPM-step26/27, pattern channel3, sample/Chromatic note banks and effects/Looper controls remain inactive. Full Play state, Serato setup, complete modes/output/lifecycle/audio, signed app/install and physical/A10X acceptance remain open. No stored setting, reset, firmware or output packet is sent.
Public Rane performer/twelve/seventy-two discussions establish product support and some limitations, but the reviewed topics provide no complete channel/address export. The Twelve owner post contains only a Play-lamp fragment and reports old deck-switch pitch issues. It does not establish native motor, deck selection or lifecycle. No sibling Rane protocol is inferred. Continue through independent public sources.

## R352 Euphonia independent manufacturer MIDI mixer

Assumption: the independent E10 table controls the app mixer through separate audio after manual MIDI/driver setup. Map physical CH1–4 to app A/B/C/D. Latched PFL notes carry state. Do not inherit DJM, MP2015 or other rotary mixer addresses, lamps or audio routes.

- [x] Pin and visually inspect both manufacturer mixer pages. Confirm a failing importer fixture.
- [x] Add manual fixed gain/EQ/level/PFL and master/headphone controls. Keep routing, isolator/send/FX, display, settings and all output inactive.
- [x] Verify all addresses, state-valued PFL, Note/CC separation, C/D opt-in, ignored controls and real-WAV mixer/Sync. Run importer/native checks and iPad framework compilation. Compare earlier recipes.

Success requires no automatic audio route, no guessed feedback and no changed hardware setting. Full hardware/software ownership, lifecycle/audio and physical acceptance remain open.

The independent manufacturer E10 recipe adds27 manual inputs. Four fixed strips retain their exact trim/EQ/rotary-level CCs, including CH4 Mid5C and Low52. PFL notes0A–0D explicitly carry latched on/off state, so native direct cue state applies every value without toggle edge priming or pickup. Dedicated Master18/headphone level1A/blend1B retain their distinct roles. Physical CH1–4 map to A/B/C/D with C/D opt-in.
All185 importer checks,15 focused native checks and iPad framework compilation pass. Checks cover every active address, repeated latched PFL on/off, Note/CC separation, foreign channels, C/D opt-in, inactive selectors/settings/FX/clock and real-WAV mixer/Sync. MP2015 and SP-404MKII state contracts also pass. Earlier236 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches237 data recipes. Automatic core remains184 physical models, with128 without automatic core. Full theoretical support remains open for312 models. The repository check retains twelve historical broken links.
USB/MIDI software setup and hardware/software audio ownership remain explicit. No automatic route, doubled mixer chain, source-selector setting, lamp or output packet is inferred from the input-only table. Driver/platform setup, isolator/send/FX, booth/master-insert/display modes, complete output/lifecycle/audio, signed app/install and physical/A10X acceptance remain open.
The public RP-8000 MIDI research project separately documents MK2 display startup/BPM and shutdown. Its repository contains no input map. The MK2 manufacturer page lists firmware, user/Platter Play guides and sound packs, not a complete host MIDI table. The ELITE page likewise has no wire table. No firmware was installed or run, no unexplained startup sequence was copied, and neither model inherits the original RP-8000 input map. Continue through the remaining independent sources.

## R353 Independent MixTrack Go and Party Mix III fixed input cores

Assumption: use independently pinned public mappings for each2026 model. Import fixed normal addresses agreed by each model's XML and handlers. Party Mix III's prototype has copied or unwired fields. Keep its Sync/PFL/jog/pads and ambiguous second volume address inactive. MixTrack Go has its own complete ordinary input wiring and242-count jog estimate. USB and Bluetooth audio need separate qualification.

- [x] Pin both model-specific XML/script/setup references and source hashes. Confirm failing importer fixtures.
- [x] Add fixed normal transport/mixer/browser and inverted paired tempo, with exact shifted release aliases. Add only independently wired Go PFL/Sync/fixed jog/touch. Use source identity/status queries without speculative lamps or audio routes.
- [x] Verify all active addresses, pair endpoints, encoder direction, source/release ownership, ignored modes/siblings, bounded setup and real-WAV audio/Sync. Run importer/native checks and iPad framework compilation. Compare earlier recipes.

Success requires no pad-mode, Fade FX, display, stored setting, sibling jog calibration or Bluetooth audio inference. Full modes/output/lifecycle/audio and physical/A10X acceptance remain open.

Two independently reviewed recipes add34 automatic MixTrack Go and28 automatic Party Mix III bindings. Each model retains its own fixed normal Play/held Cue/Load, level/filter, source-inverted14-bit tempo, global master/headphone/crossfader and browser. Exact shifted release aliases clear held Cue and rearm normal buttons without running shifted commands. Identity and controller-status startup requests match both pinned sources. No delayed lamps, stored settings or automatic audio route is sent.
Go separately adds wired Sync/PFL and fixed native jog/touch using the author's approximate242-count revolution estimate. Source software Vinyl/Filter/Low modes and paused scrub multipliers remain inactive. Party Mix III independently adds three-band EQ. Its unwired Sync/PFL/jog fields, copied right mode constant, ambiguous volume28 and inconsistent shared pads remain inactive. Neither model inherits another Party Mix generation.
All186 importer checks, nine focused native checks and iPad framework compilation pass. Checks cover exact per-model source rows, every active normal address, paired pitch endpoints and pickup, relative browser/jog direction, paired-source startup, repeated reconciliation, held Cue/source ownership, shifted rearm, inactive modes/siblings and real-WAV Cue/Play/mixer/tempo/jog with finite audio and retained Sync. The shared fixture now checks150 automatic held-Cue profiles across both standard release forms.
Earlier237 recipes retain identical data. The compiled resource matches the source byte for byte. The catalogue reaches239 data recipes. Automatic core reaches186 physical models, with126 without automatic core. Full theoretical support remains open for312 physical models. The repository check retains twelve historical broken links.
Manufacturer FAQs explicitly disable built-in audio outputs during Bluetooth MIDI operation. Wired Main1/2 and headphones3/4 are public setup facts, not an implemented automatic route or physical iPad test. Shared pad modes/Fade FX/stems, source pitch-centre calibration, feedback/light timing, complete lifecycle/audio, Bluetooth discovery, signed app/install and physical/A10X acceptance remain open.
Further source checks found SLAB's public MIDI filename, but its old document and current software-section routes return403. Two current-host filename variants return404. No inaccessible or ambiguous pad table is imported. The original LPD8 editor screenshot corroborates its pad notes but shows knobCC0–7, while the DEX mapping expects1–8. The existing custom-preset recipe is not promoted or silently replaced from that conflict. Hercules200MK3 currently links user guides, without an independent MIDI table. Continue through the remaining public sources.

## R354 Original nanoKONTROL read-only current-scene mixer

Assumption: the first-generation model04 has no native mode. Discover its model/global channel, then read the current256-byte scene through Korg's bounded307-byte SysEx dump. Adapt physical controls to a fixed native mixer layout without changing any saved scene. Preserve existing raw custom mappings until explicit replacement.

- [x] Pin the manufacturer protocol and confirm a failing importer fixture. Define synthetic protocol fixtures against its field table.
- [x] Add a separate bounded scene decoder and shared Korg request/readiness wrapper. Serialise refresh requests and discard stale replies after scene changes. Reject ambiguous wire assignments. Never send native-mode, scene-change, scene-write or dump-write commands.
- [x] Add32 logical mixer bindings. Physical strips1–4 supply level/filter/PFL/keylock. Strips5–8 supply global faders and A–D gain knobs. Preserve button momentary/toggle semantics and custom ranges/channels. Keep strip9, transport and extra switches inactive.
- [x] Verify all channels/ranges, seven-bit packing, fragmentation, stale/foreign/malformed replies, collisions, scene/pickup barriers, existing custom mappings, pairing/send failure/reconnect, C/D opt-in and real-WAV mixer/Sync. Recheck both native Korg2 models, importer checks and iPad framework compilation. Compare other recipes.

Success requires no hardware preset change and no raw input before a valid requested scene. Full transport/layers/output/lifecycle and physical/A10X acceptance remain open.


Implemented32 scene-aware mixer bindings from Korg's [model04 protocol](https://cdn.korg.com/us/support/download/files/2f509a92db41920e950a23cbe5edb481.txt), revision1.00. The decoder reads the current scene without changing saved data. It preserves custom channels, exact limited/reversed ranges and momentary/latched button behaviour. Collisions with unused controls also block ambiguous bindings. Scene notifications invalidate pickup and pending replies. A new query follows any discarded stale reply. Existing saved raw mappings remain active until explicit replacement, subject to the existing capacity limit.

Validation:187 Python tests and39 focused native tests passed. Native fixtures cover all16 global channels, every packet split, eight-bit packing, malformed/foreign replies, duplicate wires, stale scene changes, source isolation, failed sends, reconnect, saved mappings and C/D opt-in. A real-WAV host fixture retained audio and Sync. Both native Korg2 models passed their existing focused checks. The iPad framework compiled. Its bundled catalogue matches the source, and all238 other data recipes remain identical. An initial malformed-input fixture incorrectly supplied a complete valid packet before an extra byte. A second run exposed missing test-constructor arguments. Both failed logs remain preserved, followed by the corrected39-test pass. The repository checker still reports12 historical missing-file links. Evidence: `TestBuilds/r354/validation.json`.

The catalogue now has319 records,312 physical models and239 data recipes. Automatic core coverage reaches187 physical models. Another125 still lack automatic core controls. Full theoretical support remains open for all312 models. No signed app, installation or physical/A10X acceptance is claimed.


## R355 PLX-CRSS12 MIDI hot-cue accessory and public Rane source audit

Assumption: the manufacturer table establishes pad MIDI independently of the turntable's motor, audio and DVS functions. Add only its unambiguous PAD MODE1 cue addresses. The eight normal pads use channels8–11, notes0–7. Shift notes8–15 only clear the corresponding normal edge. One physical Shift uses a shared source-local identity across hardware deck changes. Keep the extra while-held5–8 rows inactive because their decimal channel and status columns conflict.

- [x] Pin and visually check all pad rows in the five-page E1 manufacturer table. Confirm the new-recipe check fails first.
- [x] Add68 accessory bindings: eight cues, eight release aliases and one Shift per deck. Keep other modes, application/deck/motor controls, pitch, outputs, startup/shutdown and DVS/audio inactive.
- [x] Check all decks/slots, both release forms, Shift/deck changes, unsupported packets, source isolation, reconnect, C/D opt-in and real-WAV audio/Sync. Run importer tests and iPad framework compilation. Compare existing recipes.
- [x] Record the current public Rane download index and guide findings, including the absence of published SDK or wire tables in those checked sources.

Success requires correct cue routing without motor/DVS or conflicting table assumptions. Full turntable support and physical/A10X acceptance remain open.


The [manufacturer E1 table](https://downloads.support.alphatheta.com/software_info/turntables/PLX-CRSS12/PLX-CRSS12_MIDI_Message_List_E1.pdf), SHA256`138f464d22a24159e93482047bd4bb8ee18c9a9922e087e74b4f43a154810477`, provides the68 automatic accessory bindings. PDF pages2–5 were visually checked. Normal PAD MODE1 notes0–7 address all eight cues. This includes the5–8 latched bank. The separate while-held5–8 rows remain inactive because their channel/status columns conflict. Shift aliases8–15 rearm normal cues without deletion. A shared physical Shift identity survives deck-channel changes. Motor, platter, turntable transport, pitch, feedback and audio/DVS remain separate and unimplemented.

Validation:188 Python tests and eight focused native tests passed. Tests cover all32 deck/slot combinations, both release forms, repeat presses, alternate releases, Shift across deck changes, source isolation, unsupported modes/addresses, C/D opt-in and reconnect. A real-WAV host fixture retained audio and saved Sync. The iPad framework compiled and its resource matches the source. All239 earlier data recipes remain identical. The first native run found a test-only String/enum mismatch. The corrected run passed. Both logs remain preserved. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r355/validation.json`.

The [public-source audit](controller-public-source-audit.json) records Rane's current13-product download metadata and three checked guides. Its public index lists no SDK or MIDI wire-specification download. PERFORMER v1.5, SEVENTY-TWO MKII v1.4 and TWELVE MKII v1.1 have no MIDI address, motor or display wire tables. This finding applies only to those checked sources. It does not establish that no other document exists. Denon's public index lists several legacy MIDI specifications, without a separate X1800/X1850 wire table. No firmware updater, driver or proprietary definition was run or extracted. The nanoKONTROL source-hash check also now follows the existing optional-cache convention, so a fresh checkout does not require ignored local downloads.

The catalogue has319 records,312 physical models and240 data recipes. Automatic core coverage reaches188 physical models. Another124 lack automatic core controls. Full theoretical support remains open for all312 models. No signed app, installation or physical/A10X acceptance is claimed. Continue the remaining public-source work.


## R356 Hercules MK4 documented manual MIDI core

Assumption: use the original manufacturer's MIDI assignments and independently checked working mappings. The controller needs desktop driver setup. Keep automatic selection and native iPad USB access open. Use default MIDI channel1 only. Pitch is a relative encoder, not an absolute fader. Preserve native Sync choice and use sensorless wheel nudge/seek. Use a fixed native1/2/4/8 loop layout on the four normal K buttons, as the independent DEX mapping does. Shifted FX buttons remain inactive.

- [x] Pin and visually check manufacturer pages26–28. Pin the independent MK4-specific source. Confirm a failing replacement fixture.
- [x] Replace the generic ten-input mapping with38 native controls and eight explicit transport/PFL lights. Keep driver/bridge, source/audio switching, other modes and setup/lifecycle open.
- [x] Verify buttons/held releases, fixed loops, mixer pickup/direction, relative pitch, sensorless wheels, unsupported controls, manual source isolation and real-WAV audio/Sync. Run importer checks and iPad framework compilation. Compare other recipes.

Success requires the documented MIDI core without inherited RMX/4-Mx protocol or automatic native USB/audio claims. Physical/A10X acceptance remains open.


The [original MK4 guide](https://ts.hercules.com/download/sound/manuals/Mk4/DJ_Console_Mk4_ENG.pdf), SHA256`914feabd4b8e1f8ac5acd084ca6ce09d2575a75acc7e679d73721af36057a03c`, establishes the38-input manual core. PDF pages26–28 were visually checked. Default MIDI channel1, transport/bend buttons, relative encoders and explicit eight-lamp values stay model-specific. The MK4-specific [public DEX package](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) member independently corroborates normal EQ/blend direction despite the guide's reversed clockwise wording. No downloaded application, installer or script runs. Native four-pad loops use1/2/4/8 beats. Relative tempo uses the app's existing range and signed magnitude. Sensorless wheels use the source128-count scale, with physical calibration open. Shifted K/FX modes, physical Scratch, source/audio switching and other unimplemented controls stay inactive. No desktop driver, native iPad USB access, source reset, all-controls query or automatic audio route is inferred.

Validation:189 Python tests and eight focused native tests passed. Native fixtures cover held Cue/bend releases in both forms, repeat presses, fixed loop sizes, mixer pickup and direction, signed relative pitch/wheel magnitudes, source isolation, inactive controls and exact eight-lamp bytes. A real-WAV fixture retained audio and saved Sync. The iPad framework compiled and its resource matches the source. Only MK4 changed; all239 other data recipes remain identical. Two test-only callback adaptation errors remain in the preserved failed logs, followed by the passing run. The repository checker still reports12 historical missing-file links. Evidence: `TestBuilds/r356/validation.json`.

The catalogue retains240 data recipes and188 automatic-core physical model records. Another124 lack automatic core controls. Full theoretical support remains open for all312 physical model records. No signed app, installation or physical/A10X acceptance is claimed.


## R357 DJM-A9 manual mixer and migrated manufacturer documents

Assumption: use the current manufacturer support links, not guessed old filenames. The six-page A9 E10 table contains conflicting CH2 CUE B/fader rows. CH2 CUE B is published as CC17, overlapping CH1 fader. CH2 fader is published as Note18, overlapping CH3 CUE B. Keep CH1/2 faders, all CUE B buttons and both candidate CC17/18 faders inactive. Use default-channel1 TOGGLE mode for direct CUE A state. Keep hardware/software audio ownership separate.

- [x] Pin and visually inspect A9 pages2–4. Confirm the replacement fixture fails. Cross-check MIDI button mode against the manufacturer-authored manual.
- [x] Add30 manual unambiguous mixer inputs, with four latched CUE A states and C/D opt-in. Infer no MIDI receive/output, source switch, stored setting or audio route.
- [x] Check exact addresses, pickup/direction, direct state, conflicting/unsupported packet isolation and real-WAV audio/Sync. Run importer checks and iPad framework compilation. Compare earlier recipes.
- [x] Record working SLAB and REV7 MIDI document links from the migrated support site for the next implementation steps.

Success requires no inferred repair of contradictory manufacturer rows. Full mixer routing, protocol gaps and physical/A10X acceptance remain open.


Added30 manual A9 inputs from the [current E10 MIDI table](https://downloads.support.alphatheta.com/midi-mapping/dj-mixers/DJM-A9/DJM-A9_MIDI_Message_List_E_10.pdf), SHA256`4bca4d93965d669e8a22bd58a9582ce2fdd23fc3cc29a576203f8e2df819c76f`. Visual review confirms the CH2 conflicts are in the document, not just its text extraction. CH1/2 faders and all CUE B controls remain inactive. Gain/EQ/Color controls retain four independent strips. C/D faders are unambiguous. Four CUE A buttons retain direct state in channel1 TOGGLE mode. Master, Headphones A and crossfader control the separate app mixer. The manufacturer-authored manual's web text confirms the MIDI defaults on page80. The current official manual download link returns404; no local PDF hash is claimed for that manual. MIDI receive/output and automatic audio routing remain unimplemented.

Validation:190 Python tests and six focused native tests passed. Fixtures cover every mapped address, pickup, direction, explicit PFL state, source isolation, C/D opt-in and conflicting/unused packet rejection. A real-WAV host fixture retained audio and saved Sync. The iPad framework compiled and its resource matches the source. All240 earlier data recipes remain identical. The repository checker still reports12 historical missing-file links. Evidence: `TestBuilds/r357/validation.json`.

The [public-source audit](controller-public-source-audit.json) records the migrated support articles and exact working SLAB/A9/REV7 filenames. SLAB and REV7 tables are downloaded for the next implementation steps. V5's current software section has no MIDI article in the checked list. The current X1850 guide documents MIDI settings without an address table. These are scoped findings, not claims that no other source exists.

The catalogue now has241 data recipes. Automatic core coverage remains188 physical model records, with124 remaining. Full theoretical support remains open for all312 physical model records. No signed app, installation or physical/A10X acceptance is claimed.


## R358 SLAB fixed native DJ layout across eight pad pages

Assumption: use SLAB's general MIDI table to define an explicit GenErik DJ layout. This is a fixed native DJ layout, not Serato Studio emulation. Pages1/2 provide A/B and C/D cues. Pages3/4 provide fixed loops. Pages5/6 provide beat jumps. Pages7/8 provide transport. Each page's top eight physical pads address the first deck and its bottom eight address the second. C/D retain app opt-in. Four encoders control A level/filter and B filter/level. The normal Play button controls A. The dial/arrows browse; dial press opens a group. Mode1 strip controls the crossfader.

- [x] Pin and visually inspect all four manufacturer pages. Confirm the new-recipe fixture fails before implementation.
- [x] Add139 automatic accessory bindings. Keep all128 normal pad addresses distinct. Page-button presses retire held actions and reset edges. Both Shift transitions retire holds and gate the native layout, so unsupported shifted releases cannot strand Cue. Keep aftertouch, shifted pages/functions, other modes, lights/screens and setup writes inactive.
- [x] Verify all128 page/pad addresses, both releases, page/Shift hold cleanup, velocity/aftertouch separation, source isolation, C/D opt-in, signed encoders, paired strip, reconnect and real-WAV Cue/loop/audio/Sync. Recheck automatic held-Cue fixtures, importer checks and iPad framework compilation. Compare earlier recipes.

Success requires a documented fixed DJ layout, bounded state and no inferred Serato handshake, colour palette or audio route. Full source functions, output/lifecycle and physical/A10X acceptance remain open.


Added139 automatic SLAB accessory bindings from the [current manufacturer table](https://downloads.support.alphatheta.com/midi-mapping/music-production/SLAB/SLAB_MIDI_Message_List_en.pdf), SHA256`aaba912538403e712fb73554a4e30fff8b467e115e91f9455718711fd1b29a0c`. All four PDF pages were visually checked. The native layout uses all128 normal pad addresses. It does not emulate Serato Studio. Shift gates native controls and retires held Cue on both transitions. Page presses retire old holds and reset edges; page-button releases preserve a new held Cue. Shift pad messages and aftertouch cannot become normal pad presses. Encoders and DIAL-mode browsing retain published1/65 direction. The normal Mode1 strip uses its documented channel7 CC14/46 pair. No setup, output, setting write, HID mouse command or audio route is sent.

| Pages | Top eight pads | Bottom eight pads | Functions in physical row order |
| --- | --- | --- | --- |
| 1 / 2 | A / C | B / D | Cues1–8 |
| 3 / 4 | A / C | B / D | Fixed loops:1/4,1/2,1,2,4,8,16,32 beats |
| 5 / 6 | A / C | B / D | Beat jumps:-1,+1,-2,+2,-4,+4,-8,+8 |
| 7 / 8 | A / C | B / D | Play, held Cue, Sync, Keylock, PFL, loop toggle, Load, tempo reset |

The four encoders control A level/filter and B filter/level. The normal Play button controls A. The dial and arrows browse; dial press opens a group. Press DIAL MODE for MIDI browsing. Mode1 strip controls the crossfader. C/D require app opt-in.

Validation:191 Python tests and ten focused native tests passed. Native fixtures cover all128 page/pad addresses with two velocities and both release forms, held-Cue page/Shift cleanup, independent sources, hidden C/D, aftertouch/alternate rejection, relative encoders, paired strip and reconnect. The automatic held-Cue fixture now covers151 profiles. A real-WAV host fixture retained Cue cleanup, loops, audio and saved Sync. The iPad framework compiled and its resource matches the source. All241 earlier recipes remain identical. The repository checker still reports12 historical missing-file links. Evidence: `TestBuilds/r358/validation.json`.

The catalogue now has242 data recipes. Automatic core coverage reaches189 physical model records, with123 remaining. Full theoretical support remains open for all312 physical model records. No signed app, installation or physical/A10X acceptance is claimed.


## R359 Independent DJM-A7 manual four-strip MIDI mixer

Assumption: the current A7 EN100 table independently defines four complete fader rows. It does not resolve the different A9 table's conflicting controls. Add a separate manual MIDI channel1/TOGGLE subset, through separate app audio. Keep hardware/software audio ownership and full routing open. Do not infer a factory button-type default or write stored settings.

- [x] Pin and visually inspect all three manufacturer pages. Confirm a failing addition fixture.
- [x] Add32 manual inputs: four gain/EQ/Color/fader/PFL strips and master/headphone/crossfader globals. Preserve direct TOGGLE PFL and C/D opt-in. Infer no output or audio route.
- [x] Verify all addresses, fader pickup/direction, PFL state, source isolation, hidden decks, unused hardware and real-WAV audio/Sync. Run importer checks and iPad framework compilation. Compare all earlier recipes, including A9's quarantined fields.

Success requires an independent A7 contract with no sibling aliases or automatic routing claim. Full mixer behaviour, hardware audio ownership and physical/A10X acceptance remain open.


Added32 manual A7 inputs from the independently published [EN100 table](https://downloads.support.alphatheta.com/software_info/dj-mixers/DJM-A7/djm-A7_midi_message_list_EN_100.pdf), SHA256`c3ccdb2f61be9f94ce6c6b22027736184d1a24709121c8952d1c8f95b979caee`. All three pages were visually checked. Gain/EQ/Color/fader controls retain each physical strip's addresses. Direct CUE state requires MIDI channel1 and TOGGLE mode. The recipe does not infer a factory type default. Headphone, master and crossfader controls affect the separate app mixer. Master Texture, Link Cue/SonicLink, source/assign/curve switches and effects remain inactive. No output, stored setting or audio route is inferred. A9's conflicting addresses remain quarantined.

Validation:192 Python tests and ten focused native tests passed, including the existing A9 checks. Fixtures cover all32 addresses, fader pickup and direction, direct PFL state, source isolation, C/D opt-in and inactive hardware controls. Real-WAV host fixtures retained audio and saved Sync for both models. The iPad framework compiled and its resource matches the source. All242 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r359/validation.json`.

The [public-source audit](controller-public-source-audit.json) now also records the working XDJ-AN MIDI table from its current support article. That model is the next source implementation. The catalogue has243 data recipes. Automatic core coverage remains189 physical model records, with123 remaining. Full theoretical support remains open for all312 physical model records. No signed app, installation or physical/A10X acceptance is claimed.

## R360 XDJ-AN deck ownership and paired MIDI core

Assumption: the public E1 table defines a separate two-deck protocol. Software Control entry on the hardware remains necessary. Both decks must report PC mode before the app sends the documented MIDI Control mixer command. Local send success does not prove device acknowledgement or audio routing. The current manual describes USB-C iPad use. Lightning and A10X acceptance remain open.

- [x] Pin and visually inspect all three MIDI pages. Review the current manufacturer software-control and mixer-setting chapters.
- [x] Add99 inputs and ten binary lamps, with source-local setup, held Cue, Shift cleanup and independent native pad pages.
- [x] Verify setup failure, ownership loss, reconnects, saved mappings, queued movement, Korg regressions and real-WAV playback. Compile the iPad framework.

The [manufacturer table](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-AN/XDJ-AN_MIDI_Massage_List_E1.pdf) has SHA256`8862a83688206ffe0bf7736a0235f1318b07185b467444a6bad2d49e7733c4bd`. Its published filename contains `Massage`. Select SOURCE, Software Control, then LOAD1 and LOAD2 as described in the [current manual](https://downloads.support.alphatheta.com/manuals/all-in-one-dj-systems/XDJ-AN/html/en/000_EP169_en/Using_DJ_software/Using_DJ_software.htm). Both input-only deck CC100 notifications must report127. The app then sends channel5 CC101=0 to the paired physical output. It sends no guessed hardware-mode value or shutdown mode write. A hardware mixer-mode change closes the input gate. The app does not repeatedly override that choice.

The profile covers normal Play, held Cue, Sync, Keylock, tempo, contact/jog movement, selected-size jumps, loop toggle, needle position and Load. Mixer gain/EQ/Color/faders, PFL, master/headphone controls and browsing retain separate addresses. Hot Cue pads use their native page. Loop and jump pages use explicit native beat lengths. Shift and pad-mode changes retire side-local holds. Other pad pages, FX assignments, ambiguous binary BeatLoop rotation and hardware tempo ranges stay inactive. Jog resolution and physical taper remain uncalibrated. The ten lamps use only the documented127/0 values. No colour palette, screen, meter or audio route is inferred.

The bounded setup wrapper preserves the three existing Korg protocols. The profile needs18 bank-change entries, so the catalogue bound is32 with a rejection test at33. Saved raw mappings remain active until explicit replacement. Replacement still checks the existing256-binding limit before mutation. Ownership loss cancels queued input from that source. Mixed jog counts retain the other source's contribution.

Success requires passing protocol, mapping and playback fixtures with the previous243 recipes unchanged. Full modes, lifecycle, output, audio routing, cold PC notifications, command timing and physical acceptance remain open.

Validation:193 Python checks and61 focused native tests passed. These include the152-profile held-Cue corpus, both release forms, ownership changes, saved-mapping capacity and queued-source isolation. The real-WAV fixture retained audio and saved Sync. The iPad framework compiled and its resource matches the source. All243 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Earlier failed logs retain the catalogue-bound failure, corrected packet/coalescing expectations and reproduced queued-movement defect. Evidence: `TestBuilds/r360/validation.json`.

The catalogue now has244 data recipes and190 physical models with automatic core controls. Another122 physical models lack automatic core controls. Full theoretical support remains open for all312 physical model records. No signed app, installation or physical/A10X acceptance is claimed. The public DDJ-REV7 E2 and RMX-IGNITE tables have also been recovered for the next additions.

## R361 Independent DDJ-REV7 manual MIDI core and saved bank rules

Assumption: the public E2 table establishes ordinary MIDI addresses but does not establish motor/platter ownership. Add a manual subset through a separate app audio path. Keep Instant Scratch off and select the connected computer's USB source. Utility LOOP options must remain OFF for the binary Auto Loop action. Send no motor, setup or output command.

- [x] Pin and visually inspect all seven manufacturer pages. Confirm a failing addition fixture.
- [x] Add70 manual inputs for transport, pitch, mixer, browsing, eight performance Hot Cues and four upper SLOT/PAD Hot Cues per deck.
- [x] Preserve explicit manual profile identity, bank cleanup and reload behaviour. Verify bounds, source isolation, Shift, mode changes, real-WAV playback and iPad compilation.

The [E2 table](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-REV7/DDJ-REV7_MIDI_message_List_E2.pdf) has SHA256`a2d33045fc28017d48ba8e9409e0586d0f753ce426e7f955c0c56460b7dbf905`. Its filename uses lowercase `message`. The profile retains separate deck, upper-slot, performance-pad and browser channels. Paired tempo and mixer controls keep their documented addresses and direction. Normal Play, Sync, Keylock, tempo reset, loop sizing and held bends have explicit native targets. SILENT CUE is neither PFL nor held main Cue. It stays inactive. Motor count streams34/41, value-coded Auto Loop35, other pads/FX/stems and hardware source/reverse/curve functions stay inactive. No REV1/REV5 alias, motor command, lamp value, screen protocol or audio route is inferred.

Manual application now saves the selected profile ID with its bindings. Only that explicit selection supplies manual bank-change rules. Endpoint names alone do not infer those rules. Reload validates known profile IDs, a64-source limit and a16KiB data bound. Clearing the bindings removes the metadata. This closes the held-bend mode-change defect reproduced by the first native run.

Mode presses retire old holds. Mode-button releases preserve new holds. New failing fixtures reproduced premature release in both REV7 and XDJ-AN. The XDJ-AN change removes release handling from pad-mode metadata. Both Shift transitions still retire holds. This is the only changed earlier recipe. The other243 earlier recipes remain identical.

Validation:194 Python checks and33 focused native tests passed. They include REV7 transport, both Hot Cue banks,14-bit pairing, held bends, source isolation, manual reload/bounds and inactive motor/Silent Cue wires. Existing XDJ-AN, original nanoKONTROL and original RANE ONE checks passed. Real-WAV fixtures retained audio and saved Sync. The iPad framework compiled and its resource matches the source. The repository checker retains12 historical missing-file links. Failed addition, manual-bank and mode-release logs remain preserved. Evidence: `TestBuilds/r361/validation.json`.

The catalogue has245 data recipes. Automatic core coverage remains190 physical models, with122 remaining. Full theoretical support remains open for all312 physical model records. No signed app, installation or physical/A10X acceptance is claimed.

## R362 RMX-IGNITE manual native DJ accessory layout

Assumption: the manufacturer documents MIDI output on configurable channels, with channel1 as the default. Add an explicit manual deck-A layout. Use separate app audio because the unit continues its own hardware processing. This layout does not emulate hardware FX, the sampler or held sample rolls.

- [x] Pin the current manufacturer table and visually inspect both wire pages. Verify the USB/MIDI and default-channel instructions.
- [x] Add22 manual inputs for native Hot Cues, latched loops, held bends, Sync, level/EQ/filter/effect amount and browsing.
- [x] Verify both release forms, pickup, source ownership, unused channels/functions, real-WAV audio/Sync and iPad framework compilation.

The [manufacturer table](https://downloads.support.alphatheta.com/firmwares/dj-effectors/RMX-IGNITE/RMX-IGNITE_midi_message_list_en.pdf) has SHA256`11d27b45729126db68c927c7234597d8400806381ac6a81fcf3f074811ae9bc1`. It is published under `firmwares`, although the file contains MIDI documentation. The [USB/MIDI chapter](https://downloads.support.alphatheta.com/manuals/dj-effectors/RMX-IGNITE/HTML/en/RMX-IGNITE/USB_MIDI/USB_MIDI.htm) specifies the USB for MULTI I/O port. The [settings chapter](https://downloads.support.alphatheta.com/manuals/dj-effectors/RMX-IGNITE/HTML/en/RMX-IGNITE/Settings/Settings.htm) defines the default channel.

Sample triggers A-D become native Hot Cues1-4. The six straight roll buttons select native latched loops of1/8,1/4,1/2,1,2 and4 beats. The four triplet/dotted lengths stay inactive because the native loop contract does not support them. Isolate knobs control native EQ. Sampler Volume controls native deck level. Sampler Color controls native filter amount. Lever Sub Parameter controls the selected native effect amount. Phase nudge buttons provide held native bends. Beat Sync controls native Sync. Browse, encoder press and Back retain library actions. The incoming timing clock does not change app transport or saved Sync.

Hardware FX selectors, sampler edit/hold, Echo Time, Release/Echo and connection switches remain inactive. The DRIVE selector's printed status is ambiguous and is not interpreted. No hardware bypass, output message, stored setting, audio route or RMX-500/1000 alias is inferred. Full hardware behaviour and physical/A10X acceptance remain open.

Validation:195 Python checks and seven focused native tests passed. Fixtures cover all22 inputs, both note-release forms, pickup/direction, source-local held-bend cleanup and inactive controls/channels. Real-WAV playback retained finite audio and saved Sync. The iPad framework compiled and its resource matches the source. All245 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r362/validation.json`.

The catalogue now has246 data recipes. Automatic core coverage remains190 physical models, with122 remaining. Full theoretical support remains open for all312 physical model records. No signed app, installation or physical/A10X acceptance is claimed.

## R363 Complete pinned djay inventory audit

Assumption: the Serato iOS benchmark and Mixxx definitions do not cover every model in the current djay list. Audit the public all-platform list. Preserve competitor platform claims and limitations as comparison evidence. Keep our own support criteria unchanged.

- [x] Pin all204 hardware rows and57 platform-specific limitation notes from the current public page.
- [x] Resolve the Digital Jockey IE2 and MIXAGE IE naming variants. Add31 missing model records without sibling protocol aliases.
- [x] Verify source replay, badges, limitation matching, duplicate/truncated input rejection, stable model names, runtime identity and catalogue release gates.

The [djay hardware list](https://www.algoriddim.com/hardware) was checked on19 November2026. Its snapshot has SHA256`db8bf667068cbcb278d49f5ee5794e5d6baccc528cdff917e41b00da232954a3`. The parser separates product rows from NEW badges and platform limitation rows. It retains each published platform and limitation under `comparisonSupport.djay`. These fields describe djay. They do not establish GenErik DJ behaviour. The catalogue completion gate now checks every pinned djay product, as well as the existing Serato and Mixxx sources.

The31 additions include Mix Ultra, original MC6000/NS6, several Xone mixers, Casio controllers, Phase, Mixtrack Edge and remaining Pioneer club mixers. Digital Jockey IE2 and MIXAGE IE are naming variants of existing records. Other family members retain separate records and open protocol/audio work. In particular, FLX6-GT, VCI-300MKII and the A-TRAK edition gain no inherited mapping.

Validation:198 Python tests passed. Source replay verifies both the snapshot hash and parsed rows. A changed snapshot is rejected even when its product rows match. Fixtures reject unknown limitation targets, duplicate/truncated products and unknown platforms. All existing model names remain unchanged. The bundled runtime remains byte-identical, SHA256`3289ca45e149ab91a788b0fee23a00918184a797f238335e4a9e415a1fe7670b`, so native/framework checks were not repeated for this inventory-only change. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r363/validation.json`.

The current catalogue has350 records, including343 physical models. Runtime recipes remain246. Automatic core coverage remains190 physical models. The additional inventory records increase the remaining automatic-core count to153. Full theoretical support remains open for all343 physical models. The wider market audit remains open. No device acceptance or feature-parity claim is added.

## R364 Independently captured Mix Ultra normal MIDI core

Assumption: pinned public owner captures can establish ordinary MIDI facts without importing their firmware or executable mapping code. Corroborate addresses across independent sources. Keep ambiguous state, modifier and service-mode behaviour open. Add automatic normal controls after a MIDI connection exists.

- [x] Pin three independent source revisions and the manufacturer manual. Visually inspect manual pages9,13 and14.
- [x] Add48 automatic normal inputs with source-wide Shift guards and explicit inactive states/modes.
- [x] Verify all captured controls, paired faders, touch gating, source ownership, mode-release behaviour, real-WAV audio/Sync and iPad framework compilation.

The [8 November hardware capture](https://github.com/v6ry876z77-bit/yt-dj-mix/blob/93a097e7641512bd026b9d1b5d129b2e5f009f87/mixultra-midi.md), independent [firmware analysis](https://github.com/mlcmgmt/control-mix-ultra-jog-fix/blob/068845a128ab2311dde6378a1d195a77522b7eb0/docs/reverse-engineering.md) and separate [captured mapping](https://github.com/aurabirb/djercula/blob/7174fda021e6f5f3791ac6fbf169ceb7f94ad3fa/inputmap.py) establish normal control addresses. Their revisions and file hashes are stored in the source references. The [manufacturer manual](https://ts.hercules.com/download/sound/manuals/DJC_Mix_Ultra/DJControl_Mix_Ultra_user_manual_EN.pdf) defines Cue as set/return/stop. The profile uses native Cue return, without claiming held preview.

Play, Cue return, Load, contact-gated top jogs, ring jogs and eight Hot Cues address each deck independently. Level, pitch and crossfader use the explicitly qualified14-bit pairs. EQ/filter/master use only qualified seven-bit MSBs. Other low bytes remain inactive. The native pitch choice makes raw-max positive at the app's8% range. The manufacturer makes physical direction an app setting. Browse and its press use native library actions.

Sources disagree about which physical Shift key emits channel1/2 Note4. Both known wires therefore use a source-wide OR guard with distinct key identities. Either transition retires that source's contacts. A held Shift on one controller does not block another. Mode presses retire contacts on their reported deck. Releases preserve new contacts. Shifted touch aliases only release previous contact.

Sync state/edge behaviour and PFL remain unqualified. Their packets stay inactive and preserve saved Sync. Gain/Neural Mix, other pad modes, service/calibration flows, full LEDs/lifecycle/audio and physical/A10X acceptance remain open. Service-mode pads overlap normal pad addresses. Keep service mode off. Stock firmware can suppress slow ring packets. Physical jog resolution/taper remains uncalibrated. No patch, firmware, third-party executable code, setting/output write, sibling profile or audio route is imported.

Validation:199 Python checks and ten focused native tests passed. These include the existing152-profile held-Cue corpus. Real-WAV fixtures verified Cue return, guarded scratching, inactive state copies, finite audio and saved Sync. The iPad framework compiled and its resource matches the source. All246 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r364/validation.json`.

The catalogue has247 data recipes. Automatic core coverage is191 physical models, with152 remaining. Full theoretical support remains open for all343 physical models. The app still needs an in-app Bluetooth MIDI connection browser. This source change does not establish wireless pairing, a signed build or physical/A10X acceptance.

## R365 System Bluetooth MIDI connection browser

Assumption: automatic mappings need a MIDI endpoint before they can receive wireless controls. The app had no Bluetooth MIDI connection browser. Reuse Apple's public CoreAudioKit interface under controller setup. Keep connection selection and radio access user-triggered.

- [x] Add an explicit connection sheet under Controllers, Connections & MIDI, while MIDI input is enabled.
- [x] Add the Bluetooth purpose string to both iOS host plists. Refresh existing Core MIDI discovery after dismissal when input remains enabled.
- [x] Verify purpose strings, focused controller regressions and iPad SDK compilation. Keep permission, pairing and physical performance checks open.

The new button opens Apple's [CABTMIDICentralViewController](https://developer.apple.com/documentation/coreaudiokit/cabtmidicentralviewcontroller?preferredLanguage=occ). The system owns Bluetooth discovery, selection and pairing. Connected peripherals enter the existing Core MIDI endpoint path. Dismissal refreshes that path without enabling a disabled input. The browser stays in controller setup. It adds no live-workspace control, custom radio scanner or background Bluetooth mode.

Both iOS hosts now include [NSBluetoothAlwaysUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsbluetoothalwaysusagedescription). Their deployment target is iPadOS17. The purpose string explains connection to a wireless DJ controller. Opening the browser, denying access and reconnecting hardware remain device acceptance checks.

Validation: the purpose-string test passed for both host plists after reproducing both missing keys. Ten focused native controller tests passed, including Mix Ultra playback and the152-profile held-Cue corpus. The iPad framework compiled with the new system interface. All247 runtime recipes remain byte-identical. The repository checker retains12 historical missing-file links. Source review confirms the setup-only entry point and conditional refresh. This is not a rendered or device UI check. Evidence: `TestBuilds/r365/validation.json`.

Automatic core coverage remains191 of343 physical models, with152 without automatic core controls. Full theoretical support remains open for all343. No signed app, installation, successful wireless pairing, reconnect proof or A10X audio/touch acceptance is claimed.

## R366 Independent DJM-900NXS2 mixer contract

Assumption: the mixer retains its own audio processing. Add a manually selected app-mixer mirror with separate app audio.

- [x] Review all four Version1.00 manufacturer wire pages.
- [x] Implement32 inputs: four independent gain/EQ/filter/fader/PFL strips and four global mixer controls.
- [x] Verify pickup, explicit Cue state, source isolation, C/D opt-in, inactive hardware controls and iPad compilation.

The [manufacturer-authored wire table](https://impact-even.com/wp-content/uploads/2022/03/pioneer_djm900nexus2_midimessages.pdf) is available through a public rental-company mirror. The manufacturer software page returns403. The [manufacturer manual](https://c3.zzounds.com/media/DJM-900NXS2_manual_EN-0703f22a06f23c5041e63da3db269aa6.pdf), web-reviewed on page20, defines channel1 and TOGGLE defaults. Enable MIDI ON for the connected USB port. No app command changes those settings.

Physical CH1-4 map to native A-D. C/D require app opt-in. Cue uses CC70-73 as direct state, including repeated values. It does not use newer mixers’ Cue notes. The source independently specifies all four faders as CC17-20. Absolute controls retain pickup and seven-bit normalisation. Physical taper/calibration remains open.

The profile sends no output, setup, shutdown, stored-setting or audio-route command. TRIGGER buttons, source/assign/curve switches, master/Link Cue, booth, effects/X-PAD, microphone, clock and external mixer ownership/routing remain open. The table assigns CC114 to both X-PAD touch and Beat FX ON/OFF. Both remain inactive. No sibling protocol is inferred.

Validation:200 Python checks and six focused native tests passed. These include the152-profile held-Cue corpus. The iPad framework compiled and its resource matches the source. All247 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r366/validation.json`.

The catalogue has248 data recipes. Automatic core coverage remains191 of343 physical models, with152 without automatic core controls. Full theoretical support, signed-app checks and physical/A10X acceptance remain open.

## R367 Independent DJM-S9 manual controls

Assumption: use the clear MIDI controls with separate app audio. Preserve published conflicts as open gaps.

- [x] Recover the current official PDF through the manufacturer software article and review all four pages.
- [x] Add42 manual inputs for four-deck mixer strips, loop-size controls, global mixer and normal browsing/A-B Load.
- [x] Verify14-bit pickup/pairing, C/D opt-in, button releases, Shift, source isolation and inactive conflicting messages.

The [current manufacturer article](https://support.alphatheta.com/en-US/articles/4405086271129) links the [Version1.00 wire table](https://downloads.support.alphatheta.com/midi-mapping/dj-mixers/DJM-S9/DJM-S9_List_of_MIDI_Message_E.pdf). The article requires the utility setting for software other than Serato DJ Pro. It specifies a power cycle when switching DJ software. The app sends no setting command.

Four documented deck channels retain gain, EQ, filter and level through independent14-bit pairs. Loop half/double stay on their deck channels. Normal signed Browse, encoder press, Back and A/B Load retain channel7. Shared Shift guards normal browser and loop-size actions. Global crossfader, master and headphone controls retain their qualified14-bit pairs.

The pad-channel header says8/9/10/11, but each pad row says8/8/10/11. Additional mode rows use undefined status9q. Pads and modes remain inactive. The4BEAT LOOP row lists69/20 against an incomplete utility preference. Neither becomes a guessed Loop or tempo-reset action. Headphone Cuefader14 blends hardware channels and is not treated as the app's cue/master blend. Fader-start notes, hardware reverse/curve controls, FX/levers/sampler, microphone, full output/lifecycle/audio ownership and physical/A10X acceptance remain open. No output, setting write, sibling wire fact or audio route is inferred.

Validation:201 Python checks and six focused native tests passed, including the152-profile held-Cue corpus. The iPad framework compiled and its resource matches the source. All248 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r367/validation.json`.

The catalogue has249 data recipes. Automatic core coverage remains191 of343 physical models, with152 without automatic core controls. Full theoretical support and physical/A10X acceptance remain open.

## R368 Public DJM-V10 and V10-LF input facts

Assumption: native four-deck controls cannot represent all six hardware channels or four-band EQ. Keep those limits explicit.

- [x] Pin public LX facts and hash the published Beat Link Trigger show. Read both without executing downloaded code.
- [x] Add24 manual V10 inputs and nine independently qualified LF inputs with separate app audio.
- [x] Verify pickup, source isolation, explicit Cue state, deck opt-in and inactive six-channel/four-band controls.

The pinned [LX V10 integration](https://github.com/heronarts/LX/blob/a950c548db00b1d3b72db3b5ac4a80f2b8519415/src/main/java/heronarts/lx/midi/surface/DJMV10.java) declares gain/high/low/level, CUE A and global master/headphones A/crossfader addresses. It requires MIDI Button Type Toggle. Its channel parameter initially selects channel1. This is not a claimed manufacturer default. Native normalisation retains7-bit values and pickup.

The [Beat Link Trigger guide and published show](https://blt-guide.deepsymmetry.org/beat-link-trigger/next/Integration_ExtendedOnAirV10.html) independently qualify gain/level/master/crossfader. Its shared map serves both models. LF selection hides crossfader and assignment controls. The LF recipe uses only its directly qualified gain/level/master facts. It does not inherit the separate LX V10 EQ/PFL/headphone declarations.

Physical CH1-4 map to A-D, with C/D opt-in. CH5/6 remain inactive. Four-band mid-high/mid-low cannot share one native mid control. Unipolar filter cutoff and LPF/HPF selection cannot become a bipolar Color knob. These controls, compression/send, second Cue bus, master isolator/filter, full hardware/software audio ownership, output/lifecycle and physical/A10X acceptance remain open. The profiles send no output, setting or audio-route command.

LX has a non-commercial source licence. This implementation independently normalises protocol facts and copies no executable source. No downloaded Java or show code is executed or bundled. Source-reuse/distribution review remains open.

Validation:202 Python checks and six focused native tests passed, including the152-profile held-Cue corpus. The iPad framework compiled and its resource matches the source. All249 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r368/validation.json`.

The catalogue has251 data recipes. Automatic core coverage remains191 of343 physical models, with152 without automatic core controls. Full theoretical support and physical/A10X acceptance remain open.

## R369 Independent DJM-450 manual mixer

Assumption: use explicit channel1/TOGGLE settings and separate app audio. No factory defaults are inferred.

- [x] Review all three manufacturer wire pages through the public retailer mirror.
- [x] Add18 manual inputs for two gain/EQ/filter/fader/Cue strips and four global mixer controls.
- [x] Verify pickup, CC Cue states, source isolation, inactive C/D/sibling/hardware messages and iPad compilation.

The [manufacturer-authored Version1.00 table](https://www.recordcase.de/media/pdf/84/26/2c/Pioneer-DJM-450-Addendum-EN.pdf) independently qualifies physical CH1/2 as native A/B. Cue uses direct CC70/71 state. Master24, headphones26/blend27 and crossfader11 use seven-bit normalisation with pickup. Physical taper/calibration remains open.

The profile sends no output, setup, shutdown, stored-setting or audio-route command. Master Cue, EQ/curve/reverse switches, FX/time/send-return, AUX/microphone, clock and complete hardware/audio ownership remain open. No sibling protocol is inferred.

Validation:203 Python checks and six focused native tests passed, including the152-profile held-Cue corpus. The iPad framework compiled and its resource matches the source. All251 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r369/validation.json`.

The catalogue has252 data recipes. Automatic core coverage remains191 of343 physical models, with152 without automatic core controls. Full theoretical support and physical/A10X acceptance remain open.

## R370 Manufacturer-qualified FLX6-GT core reuse

Assumption: reuse a sibling protocol only when the manufacturer explicitly assigns its table to both models.

- [x] Read the current shared manufacturer article and verify the current E1 download against the pinned hash.
- [x] Add a distinct GT automatic core profile with the existing FLX6 inputs/outputs/lifecycle.
- [x] Verify exact matching, packet parity, deck limits, pad layouts,14-bit decoding, loop controls, feedback and held Cue.

The [current manufacturer article](https://support.alphatheta.com/en-US/articles/4404631697945) explicitly names DDJ-FLX6/DDJ-FLX6-GT. It links one [E1 wire table](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-FLX6/DDJ-FLX6_MIDI_message_List_E1.pdf). The current download matches the previously reviewed hash exactly. The GT recipe reuses those core packets and keeps its own qualified names. No generic FLX or clone alias is added.

The manufacturer requires the utility setting for software other than rekordbox/Serato DJ Pro. It specifies a power cycle when switching DJ software. Automatic core selection therefore follows the user-selected hardware mode. The app sends no mode, stored-setting or audio-route command. Merge FX, Jog Cutter, complete pads/modes/displays/lifecycle/audio routing, calibration and physical/A10X acceptance remain open.

Validation:204 Python checks and ten focused native tests passed. GT now runs through the existing Pioneer system tests. The automatic held-Cue corpus covers153 profiles. The iPad framework compiled and its resource matches the source. All252 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r370/validation.json`.

The catalogue has253 data recipes. Automatic core coverage is192 of343 physical models, with151 without automatic core controls. Full theoretical support and physical/A10X acceptance remain open.

## R371 Independent Hercules AIR+ automatic core

R372 supersedes the initial knob polarity and normal-stream jog assumptions below.

Assumption: use the manufacturer's default channel1/14-bit configuration and keep optional hardware pages outside the core.

- [x] Review all eight specification pages and the default settings on page1 of the manufacturer Traktor guide.
- [x] Add47 automatic inputs,16 owned lamps, individual shutdown clears and the documented split audio layout.
- [x] Verify release forms, velocity edges, signed/contact-gated jogs, Shift/mode ownership, pickup and real-WAV playback.

The [official MIDI specification](https://ts.hercules.com/download/sound/manuals/DJ_Air%2B/DJAIR%2B_Spec_MIDI.pdf) supplies independent AIR+ packets. The [manufacturer mapping archive](https://ts.hercules.com/download/sound/TDJS/current/TP2_DJ_AirPlus.zip) includes the guide that marks MIDI channel1,14-bit and headphones3/4 as defaults. The [Mixxx developer wiki](https://github.com/mixxxdj/mixxx/wiki/Hercules-Djcontrol-Air-Plus) confirms class-compliant USB MIDI/audio. This is separate from the original AIR recipe.

A/B Play, held Cue, Sync, PFL and Load retain their own wires. Four velocity Hot Cues per side trigger once for each press. Full-value contact gates Scratch CC104/105. Normal ring CC102/103 stays separate. Both streams retain signed magnitude, including64 as reverse64. Native1024-count sensitivity remains uncalibrated.

Physical and reported Shift inputs use independent identities and source-local OR guards. Each side has its own scope. Shared browsing uses their source-wide OR. Shift and mode changes retire owned contacts. Mode releases preserve new contacts. Mixer, crossfader and pitch use explicit14-bit pairs. EQ/gain follows the table's literal raw0=CW/raw127=CCW polarity. Pitch raw0 positive at the native8% range is an explicit app choice. Physical direction/taper/range still needs calibration.

Sixteen qualified Play/Cue/Sync/PFL/Hot Cue lamps use127/0 and clear individually on shutdown. Startup sends no query or reset. Update_All_Controls CC127 remains unused. FX/loop/sample/pressure pages, filter/gain reassignment, HP Cue/Mix, Vinyl switching, Air/proximity, microphone/recording/Magic, status-only bank recovery and full lifecycle remain open. No downloaded TSI code, firmware, driver or stored-setting command runs in the app.

Validation:205 Python checks and eight focused native tests passed, including the154-profile held-Cue corpus. Real-WAV fixtures verified Cue release, scratch cleanup, finite audio and saved Sync. The iPad framework compiled and its resource matches the source. All253 earlier recipes remain identical. An initial source check required adding the newly documented audio route to its explicit allowlist. A test-only API-name correction followed the first native compile. Both failed logs are retained. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r371/validation.json`.

The catalogue has254 data recipes. Automatic core coverage is193 of343 physical models, with150 without automatic core controls. Full theoretical support, physical USB/audio acceptance and A10X performance remain open.

## R372 AIR+ independent polarity and jog cross-check

Assumption: compare working model-specific handlers with conflicting table wording before calling a direction or scale qualified.

- [x] Inspect the already pinned public DEX AIR+ member without installing or executing downloaded code.
- [x] Resolve normal EQ/gain polarity,765-position jog scale and touch-aware normal-stream movement.
- [x] Verify both streams against actual source-frame movement in a real-WAV fixture. Preserve guards and signed64 handling.

The independent AIR+-specific mapping in the previously preserved [public DEX installer](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) sends ordinary EQ/gain values to native setters. This conflicts with the manufacturer CW/CCW wording, as seen in the independently reviewed MK4 table. AIR+ now follows the corroborated normal EQ/gain direction. Pitch retains the explicit native direction choice.

Both normal CC102/103 and scratch CC104/105 use765 positions per revolution in that mapping. Normal motion now enters native touch-aware jog handling. It scratches during contact and nudges/seeks without contact. The dedicated scratch stream still requires source-owned contact. The factory's signed64 reverse boundary remains authoritative. The independent handler's off-by-one does not enter the recipe.

Validation:206 Python checks and nine focused native tests passed, including the154-profile held-Cue corpus. New real-WAV checks verify exact765-count movement and grid restoration for both normal and dedicated scratch streams. Existing release, ownership, mode, pickup, feedback and saved-Sync checks passed. The iPad framework compiled and its resource matches the source. The other253 recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r372/validation.json`.

Counts remain254 recipes and193 automatic-core physical models, with150 without automatic core controls. Full theoretical support, source-reuse review, physical calibration and A10X acceptance remain open. No downloaded executable source is copied, run or bundled.

## R373 Independent 4Set virtual MIDI contract

Assumption: implement the published virtual MIDI port behind an explicit desktop-driver/external-bridge boundary. Direct iPad USB access remains unqualified.

- [x] Review all eight manufacturer appendix pages and default settings. Compare the model-specific independent mapping.
- [x] Add82 manual inputs and16 separately selected steady lamp recipes. Preserve four-deck opt-in and channel boundaries.
- [x] Verify held Cue/bend ownership, both bank directions, Shift handover, exact jog movement, finite audio and saved Sync.

The [manufacturer manual](https://ts.hercules.com/download/sound/manuals/4Set/01_Eng_DJ4Set.pdf) defines default channels1/2, four-deck mode and7-bit pitch. Its appendix explicitly describes a virtual MIDI port. A/B notes use the first channel. C/D notes use the second. All four mixer, pitch and jog CC sets stay on the first channel. The profile keeps these differences. It does not infer direct iPad USB or audio support.

The model-specific member in the previously preserved [public DEX installer](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) independently corroborates250-position jogs and normal mixer polarity. Native retains the manufacturer's signed64 reverse boundary. Normal motion is touch-aware. Dedicated scratch motion requires owned contact. Pitch uses only the documented default7-bit MSB. Alternate low-bit resolution remains open. No downloaded executable source is copied, run or bundled.

Physical/reported Shift inputs retain side identity across A/C or B/D note-channel handover. Deck-state reports retire contacts in both directions. Momentary deck-button releases preserve new contacts. Source ownership protects another controller's holds. K/Shifted-K pages, loops/FX, modifiers/search, library focus, microphone/recording, full light/lifecycle/audio ownership and physical/A10X acceptance remain open. No driver installation, state query, Shift/deck/jog-lock/sensitivity/curve setting or sibling protocol is inferred.

Validation:207 Python checks and eight focused native tests passed, including the154-profile held-Cue corpus. The real-WAV fixture verifies exact250-count normal scratch, Cue/bend release, bank cleanup, finite audio and saved Sync. The iPad framework compiled and its resource matches the source. All254 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r373/validation.json`.

The catalogue has255 data recipes. Automatic core coverage remains193 of343 physical models, with150 without automatic core controls. Full theoretical support and physical/A10X acceptance remain open.


## R374 original NS6 cyclic jog and manual core

Assumption: reuse the existing cyclic decoder only for the independently reviewed original NS6 wire format.

The pinned [public DEX member](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) supplies99 manual inputs and32 steady CC lamp recipes. The [manufacturer](https://www.numark.com/product/ns6) independently specifies3600 positions per revolution and a desktop MIDI driver. No NS6II wire map is inherited.

Deck channels2-5 retain their transport, five Hot Cues and fresh CC0/32 counter pairs. The first pair primes position. The existing decoder wraps at16384. Shared channel1 carries distinct mixer MSBs and browsing. Tempo retains the explicitly qualified inverted7-bit MSB. Shared physical Shift identities guard each side independently. Layer reports retire side contacts, pickup and counters without guessing report values or writing device settings.

Use an exposed desktop-driver/bridge MIDI port, PC sources and separate app audio. Physical strip order is C/A/B/D. C/D require app opt-in. Direct iPad USB/audio, Strip Search, loops/sampler, FX, reverse/Slip, range switching, full output/lifecycle and physical calibration remain open. No TEST-labelled platter mode, driver, screen/platter animation or startup/shutdown command is imported.

Validation:208 Python checks and eight focused native tests passed, including the154-profile held-Cue corpus. Real-WAV fixtures verified3600-count scratch movement, Cue release, bank cleanup, finite audio and saved Sync. The iPad framework compiled and its resource matches the source. All255 earlier recipes remain identical. An initial native run rejected a missing explicit low-byte address. The failed log is retained. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r374/validation.json`.

The catalogue has256 data recipes. Automatic core coverage remains193 of343 physical models, with150 without automatic core controls. Full theoretical support and physical/A10X acceptance remain open.


## R375 independent original MC6000 PC MIX layout

Assumption: the original MC6000 needs its own channel contract and an explicit native mixer assignment.

The [manufacturer manual](https://cdn.inmusicbrands.com/denondj/legacy/dnmc6000/DN-MC6000_ownersmanual.pdf), printed pages19-21, supplies112 manual inputs and40 steady lamp recipes. Deck channels1-4 map A/C/B/D. Shared channel1 retains mixer controls, Load A/B and browsing. The native manual layout explicitly assigns physical mixer CH1-4 to A-D. This differs from the downloaded DEX application's strip choices. No MK2 recipe is inherited.

Use PC MIX, MIDI/USB source selectors, MIDI block1-4 and separate app audio. Other channel blocks remain inactive. The app does not change these hardware settings. Velocity64 starts buttons and contact. Both Note Off and zero-velocity releases retire held actions. Side Shift guards normal controls and shared browsing. Deck changes retire side contacts. Ordinary deck-change releases preserve new holds.

The independent model-specific [DEX handler](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) gives2000 jog positions per revolution. Native reuses its existing Denon decoder and release-aware contact gates. It does not copy the source's contact-toggle handler. Browse accepts only the specified0/127 values. Pitch retains the documented pitch message and an explicit native inverted direction pending physical calibration. PAN is not inferred as cue/master blend. No fader request, dimmer, meter, reset, driver, setting or automatic audio command is sent.

Validation:209 Python checks and eight focused native tests passed, including the154-profile held-Cue corpus. A real-WAV fixture verified2000-count movement, velocity64 Cue/contact release, deck cleanup, finite audio and saved Sync. The iPad framework compiled and its resource matches the source. All256 earlier recipes remain identical. Failed fixture expectations are retained with the final passing results. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r375/validation.json`.

The catalogue has257 data recipes. Automatic core coverage remains193 of343 physical models, with150 without automatic core controls. Full theoretical support and physical/A10X acceptance remain open.


## R376 Spin2 and XW-J1 shared public input facts

Assumption: reuse only the shared input facts that the mapping author explicitly attributes to both models.

The [pinned author-owned mapping](https://gist.github.com/samba2/5af83e947297ab99a4745a5be3e13d55/a8c441c832affebb59415abdc80872967bc8c0e6) explicitly supports Vestax Spin2 and Casio XW-J1. Each distinct manual profile has30 inputs. Native transport, PFL, Hot Cues2/3, loop/size, touch jogs, browsing, Shift-Load and crossfader retain the reviewed channels. No original Spin, Typhoon or XW-DJ1 protocol is inherited.

Conflicting/asymmetric mixer, EQ and pitch rows remain inactive. Hot Cue1 references an undefined source handler and remains inactive. Fixed native touch scratch replaces the source's software Scratch toggle. The source's375-position estimate remains a provisional native scale. It is not manufacturer calibration. Shift guards normal controls. Both Shift transitions retire contacts. Shift-Left/Right loads once per press, including a corrected release guard absent from the source handlers.

Use an exposed MIDI port and separate app audio. Device-specific USB/audio, complete modes/lifecycle, feedback and physical calibration remain open. The shared Shift wire cannot identify simultaneous physical modifiers separately. No downloaded code, source startup lamp clear, output list, mode write or audio route runs in the app. The Japanese Spin2 manual link returned404. An unrelated Reloop Spin!2 manual and a blocked HTML response were excluded from protocol evidence.

Validation:210 Python checks and eight focused native tests passed, including both profiles and the154-profile held-Cue corpus. Real-WAV fixtures verified both provisional-scale scratch paths, Cue release, modifier cleanup, finite audio and saved Sync. The iPad framework compiled and its resource matches the source. All257 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r376/validation.json`.

The catalogue has259 data recipes. Automatic core coverage remains193 of343 physical models, with150 without automatic core controls. Full theoretical support and physical/A10X acceptance remain open.


## R377 unambiguous PRIMO manufacturer inputs

Assumption: conflicting appendix rows must remain inactive while independent addresses can support a manual native layout.

A fresh [manufacturer manual](https://mixars.com/wp-content/uploads/2022/11/primo-manual-en-fr-d-it-es.pdf) matches the earlier hash. Its three MIDI appendix pages supply63 unambiguous manual inputs. N channels1-4 carry A-D transport/mixer controls. P channels5-8 carry loops. G channel16 carries Shift, global sound and library group actions.

Play, Sync, Keylock, held bend-up, coarse tempo, gain/EQ/filter/level, loop/size and global sound retain their documented buses. The library description distinguishes normal next-level press from shifted previous-level press. Source-selector CC34/50 reports retire side bends and pickup for any value, without guessing state values.

Cue/Hot Cue mode, Vinyl/Roll mode and bend-down/Sampler mode share printed N note addresses. PFL has an unqualified channel key and shares its number with Pad8. All these rows remain inactive. Pads, relative jog/contact/browser, banked Load, shifted overlaps and undefined LED velocities also remain inactive. The app does not silently replace the printed N key with P. Firmware1.12 adds14-bit pitch, but the old chart qualifies only CC9. Native uses that coarse MSB and an explicit inverted direction pending calibration.

Select FILTER for Sound Texture FX and use separate app audio. Hardware/software source ownership, complete modes/lifecycle and physical calibration remain open. No source query, setting, firmware, driver, output or audio-route command is sent. The earlier no-recipe test now checks that the manual recipe still excludes every conflicting N note. Its first failed result remains preserved.

Validation:211 Python checks and eight focused native tests passed, including the154-profile held-Cue corpus. A real-WAV fixture verified held-bend cleanup, finite audio and saved Sync after a source report. The iPad framework compiled and its resource matches the source. All259 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r377/validation.json`.

Current official RMX-95 and ELITE manuals were also preserved. RMX-95 confirms its MIDI/EQ ownership menu but provides no recovered control-address table. ELITE's hex table configures USB output sources. Neither table qualifies an automatic native mixer mapping.

The catalogue has260 data recipes. Automatic core coverage remains193 of343 physical models, with150 without automatic core controls. Full theoretical support and physical/A10X acceptance remain open.


## R378 original BeatMix factory TSI facts and automatic core

Assumption: use actual factory bindings to resolve manual errors. Generic MIDI templates do not prove hardware messages.

The [manufacturer manual](https://www.reloop.com/media/catalog/product/pdf/2/2/5/225067_Reloop_IM.pdf), printed page20, supplies the original BeatMix addresses. Its [factory TSI](https://www.reloop.com/media/custom/upload/225067/225067%20Mapping%201.0%202D%20Traktor%201.2.7%2B%20FW%201.1.4%2B%20Win.zip) requires firmware1.1.4 or later. The182 used mapping rows correct right Low to channel2 CC69 and global sound/browser controls to channel5. Used pitch pairs identify MSBs54/70 and LSB118. Native uses their coarse MSBs until packet arrival order is established.

A bounded read-only TSI inspector now extracts used signal names, command IDs, targets and encoder settings. The [primary format reference](https://github.com/ivanz/TraktorMappingFileFormat/wiki/File-Format-Specification) documents these fields. The inspector checks XML/base64, frame sizes, array counts, strings and binding references. It rejects document declarations and malformed or ambiguous structures. It does not execute, rewrite or automatically translate a mapping. Unknown fields remain uninterpreted.

The automatic original BeatMix profile has50 inputs. Qualified jog streams CC36/42 and browser CC24 explicitly use3F/41 encoder mode. Enable Scratch mode on both hardware decks. Unused normal-jog templates CC32/34, search and shifted streams remain inactive. Side Shift guards normal controls and shared browsing. Same-wire linefaders and global sound remain usable during Shift. Mode presses retire side holds. Their releases preserve new holds. Three Hot Cues, Play, held Cue, Sync, PFL, Load, asymmetric AutoLoop and held bends retain their independent wires.

No Beatmix2/4 protocol, master MIDI control, undefined LED velocity, startup/reset, firmware, query or automatic audio route is inferred. Use a separately configured app audio route. The native pitch direction and jog scale remain uncalibrated. Complete modes, full14-bit pitch, feedback/lifecycle and physical/A10X acceptance remain open.

Validation:215 Python checks and eight focused native tests passed, including155 automatic held-Cue profiles. Malformed TSI fixtures and the pinned factory file passed. A real-WAV fixture verified Cue/contact release, scratch movement, mode cleanup, finite audio and saved Sync. The iPad framework compiled and its resource matches the source. All260 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r378/validation.json`.

The catalogue has261 data recipes. Automatic core coverage is194 of343 physical models, with149 without automatic core controls. Full theoretical support and physical/A10X acceptance remain open.


## R379 recovered VCM-100 manufacturer contract

Assumption: both documented MIDI channel choices must work without confusing PGM decks with MIDI channels.

The [preserved manufacturer service note](https://www.kevinchant.com/uploads/7/1/0/8/7108231/vsm-vcm-100.pdf) supplies the full MIDI chart. Pages6,15,16,19,20 were visually reviewed. Rear modes A/B/C share the normal core packets. Both PGM decks use default MIDI channel1 or optional channel2. Holding PGM1 LOOP during power-on selects channel2.

The manual profile has72 inputs across these choices. Rotary levels, Play, held native Cue/bends, Set Cue, PFL, Sync, loop, pitch/EQ/gain, Load, browsing and global sound retain independent addresses. Large level knobs control volume. No jog wheels are invented. Mode-A centre notes, conflicting trim-B centre values, balance, search, CUP/Preview and output remain inactive.

The manufacturer identifies its Mac MIDI endpoint as generic Vestax PC-CONTROLLER. The app does not assign that name automatically to VCM-100. Select the model manually and configure app audio separately. Native CuePause/Fine semantics and tempo direction require physical calibration. Device-specific iPad USB/audio, complete lifecycle/feedback and physical/A10X acceptance remain open. No mode, power, driver, setup or audio command is sent.

A failing Cue fixture exposed source-only hold ownership. Optional bounded `holdInput` identities now separate the VCM channel choices within each source, MIDI group and action target. Existing unspecified identities preserve cross-channel aliases. A rejected blanket channel change and its failing Hercules jog regression remain in the evidence. The final tests verify both independent channel/source holds and existing Shift/channel-changing releases.

Validation:216 Python checks and40 focused native tests passed, including155 automatic held-Cue profiles and real-WAV Cue/bend release. The iPad framework compiled and its resource matches the source. All261 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r379/validation.json`.

The preserved VFX-1 and VCI-300MKII service notes were also reviewed. Their schematics and parts do not qualify MIDI wire addresses. Neither model inherits a sibling protocol.

The catalogue has262 data recipes. Automatic core coverage remains194 of343 physical models, with149 without automatic core controls. Full theoretical support and physical/A10X acceptance remain open.


## R380 independent XW-DJ1 manufacturer core

Assumption: use the XW-DJ1's own chart and setup guide. Do not inherit the distinct XW-J1/Spin2 protocol.

The [English manufacturer tutorial](https://www.casio.com/content/dam/casio/global/support/manuals/electronic-musical-instruments/pdf/008-en/w/Web_XWDJ1-E-2A_EN.pdf), printed16/PDF18, resolves shared Shift to channel1 Note46. It explicitly specifies300-position, raw-minus64 jogs on shared channel3 CC16/17. Separate deck channels1/2 carry Play42, Cue44, SET43, Sync45, three cues41/40/39, loops35/36/37, contact59 and filter19. Both physical fader orientations qualify CC16 on channels1/2.

The automatic native core has41 inputs and14 steady lamps. Normal transport, held Cue, three cues, loop/size, contact-aware scratch, filters and global sound retain these wires. Shared Shift transitions retire holds and jog state. The [manufacturer Traktor guide](https://support.casio.com/storage/common/support/download_files/en/008/manuals/XW-DJ1_TRAKTOR_setting_manual_en.pdf), PDF pages3/5, qualifies Shift-Play Load, Shift-Sync fixed key, outer Shift-loop boundaries and shifted-jog browsing. Native uses keylock, loop In/Out and track browsing. SET stores Cue rather than implementing CUP release-play.

The setup guide also qualifies XW-DJ1 endpoint names, CoreAudio without the Windows driver, master1/2 and headphones3/4. The app can select that split route when the documented wired interface is exposed. Generic Casio MIDI In/Out names remain excluded. Physical iPad USB/Lightning enumeration, power, output channels, taper/calibration and sustained A10X acceptance remain open.

No downloaded TSI, executable mapping, driver, mode write, reset or query runs. Hot-cue deletion, three-slot FX, fast search, exact factory Shift semantics, direction indicators and complete lifecycle remain open. Shared Shift cannot identify simultaneous physical modifiers separately. Hardware deck/direction changes need physical acceptance.

Validation:217 Python checks and eight focused native tests passed, including156 automatic held-Cue profiles. Real-WAV fixtures verified exact300-count movement, Cue release, Shift cleanup, finite audio and saved Sync. The iPad framework compiled and its resource matches the source. All262 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r380/validation.json`.

The catalogue has263 data recipes. Automatic core coverage is195 of343 physical models, with148 without automatic core controls. Full theoretical support and physical/A10X acceptance remain open.


## R381 Rane A-Trak inventory identity

Assumption: the Serato name SEVENTY A-Trak Edition and djay name SEVENTY A-TRAK SIGNATURE EDITION identify one physical model.

The [mapping author's original discussion](https://community.algoriddim.com/t/rane-seventy-a-trak-signature-edition-midi-mapping/17493) uses both names for the same export. The source inventories now share one canonical record. That record retains its Serato benchmark role, djay platform evidence, both source links and existing manual profile. Standard SEVENTY, SEVENTY-TWO and SEVENTY-TWO MKII remain separate. The complete Signature Edition name selects the same manual profile.

No MIDI address, automatic selection, audio route, feature or acceptance claim changes. The existing19-input subset and absent RaneSeventy custom class remain explicit. This corrects an inflated physical count. It does not add hardware support.

Validation:218 Python checks and eight focused native tests passed, including the existing real-WAV Seventy checks. The iPad framework compiled. All263 runtime recipes retain identical control/output/lifecycle data. Only the A-Trak name alias changes. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r381/validation.json`.

The catalogue has349 records for342 physical models and263 data recipes. Automatic core coverage remains195 models, with147 without automatic core controls. Forty-one records still need a first protocol implementation. Complete theoretical support and physical/A10X acceptance remain open.


## R382 Inpulse 200 MK3 public factory facts

Assumption: inspect the public manufacturer's user-visible mapping documents without installing or running the downloaded software.

The public [DJUCED6.8.1 image](https://ts.hercules.com/download/djuced/6.8/DJUCED_6.8.1.dmg) contains a distinct Inpulse 200 Mk3 mapping. Its172 device controls and172 mapping actions qualify independent MK3 wire facts. The image was mounted read-only and its package was expanded without execution. Only local reference files were inspected. The image was then unmounted. No source script, mapping action or source reset runs in the app.

The native automatic core has65 inputs and18 normal steady lamps. Normal deck channels2/3, shifted channels5/6 and pad channels7/8 remain separate. Three-band EQ differs from MK2: normal CC5 is High, CC4 is Mid and CC2 is Low. ShiftCC5 is gain. The [manufacturer manual](https://ts.hercules.com/download/sound/manuals/DJC_Inpulse_200_MK3/DJControl_Inpulse_200_MK3_User_Manual_-_21_Languages.pdf), PDF pages22/49, confirms the physical EQ and class-compliant USB. Factory shifted CC4 controls High. Shifted volume controls target sampler decks and remain inactive.

Both jog streams declare512 steps per turn with positive1-3F and negative40-7F. Native preserves multi-step magnitude through the existing decoder and uses512-count small-movement calibration. It does not inherit MK2 single-step decoding. Normal held Cue, qualified shifted release, Play, Sync, PFL, Load, loop/size and four Hot Cues retain the source wires. Scratch-mode presses retire contacts. Native touch always scratches. Full software Vinyl mode, shifted seeking and hardware calibration remain open.

The file does not qualify a physical Shift note. Native uses distinct message channels and does not invent one. Qualified shifted Cue/deletion releases stop or rearm existing native actions without running stop/delete behaviour. Conflicting shifted B-Cue output remains inactive. Hardware master/headphone knobs stay under hardware control. MASTER_VOL_L/R messages are outputs, not input knobs, and remain inactive.

The [manufacturer setup guide](https://www.djuced.com/kb/hercules-djcontrol-inpulse-200-mk3-2026-mapping-and-manual/) qualifies master1/2 and headphones3/4. Physical iPad enumeration, power, multichannel audio, full modes/FX/stems, lifecycle and sustained A10X acceptance remain open. No firmware, driver, query or reset command is sent. The image also contains a separate T10 mapping, reserved for its own protocol review. Backspn's current public profile index was checked and adds no uncovered model-specific MIDI profile.

Validation:219 Python checks and eight focused native tests passed, including157 automatic held-Cue profiles. Every native input wire exists in the pinned MK3 document. A real-WAV fixture verified exact512-count movement, held Cue release, mode cleanup, finite audio and saved Sync. The iPad framework compiled and its resource matches the source. All263 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r382/validation.json`.

The catalogue has264 data recipes for342 physical models. Automatic core coverage is196 models, with146 without automatic core controls. Forty records need a first protocol implementation. Complete theoretical and physical/A10X acceptance remain open.


## R383 T10 supplemental controls and motor boundary

Assumption: independently documented supplemental controls can remain manual while coupled motor transport stays unavailable.

The distinct T10 factory file in the [public DJUCED6.8.1 package](https://ts.hercules.com/download/djuced/6.8/DJUCED_6.8.1.dmg) has439 device controls and454 action rows. The [manufacturer manual](https://ts.hercules.com/download/sound/manuals/DJC_T10/HERCULES_DJC_T10_USER_MANUAL_-_EN_FR_DE_NL_IT_ES_PT_PL_JP_CNM_KO.pdf), PDF26, states that platter motorisation cannot be disabled. No stationary-platter mode is invented. The generic mapping does not qualify the complete motor/platter, calibration and coupled transport contract.

The85-input manual subset covers mixer level, filter, three-band EQ/gain, PFL, Load, Sync, loop In/Out/current-size toggle/size, shifted loop sizing/keylock, eight Hot Cues per deck and library controls. Normal channels2/3, shifted5/6 and pad7/8 retain independent wires. Physical Shift Note4 is explicit for this model. Each side owns its Shift and pickup reset. Qualified deletion releases rearm native pads without deleting cues. Native loop press uses current size rather than the source fixed four-beat value.

Play, main Cue, tempo, all platter/wheel packets, RPM/motor modes and source startup/shutdown remain inactive. The profile sends no output, motor, query, driver or audio-routing packet. Shifted line-volume packets target samplers and remain inactive. Select the supplemental profile manually. Use app touch transport and separate app audio. This subset does not establish a complete T10 controller or automatic support.

Validation:220 Python checks and eight focused native tests passed, including the157-profile held-Cue corpus. Every native input wire exists in the pinned T10 document. Native tests reject motor/transport dispatch and all hardware writes. A real-WAV fixture verified finite, synced audio started through the app action path. The iPad framework compiled and its resource matches the source. All264 earlier recipes remain identical. The first native fixture mistook neutral stop-cleanup jogs for active platter input. That failed result remains preserved. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r383/validation.json`.

The catalogue has265 data recipes. Automatic core coverage remains196 of342 physical models, with146 without automatic core controls. Thirty-nine records need a first protocol implementation. Full motor support, complete theoretical support and physical/iPad/A10X acceptance remain open.


## R384 Xone:96 manual faders and Cue state

Assumption: use the current manufacturer implementation table and keep analogue mixer ownership separate from optional app controls.

The [manufacturer MIDI table](https://support.allen-heath.com/hc/en-gb/articles/43084536824849-Xone-96-MIDI-Implementation) qualifies default channel16, CH1-4 faders CC0-3, crossfader CC5 and main Cue Notes0-3. Note states are0/127. CC values span0-127. The native manual profile has nine inputs. Physical CH1-4 map A-D. C/D retain the existing four-deck opt-in. Repeated Cue state reports set the app state without toggling it. Source-select reports19-34 rearm only the corresponding deck fader pickup.

The [user guide](https://support.allen-heath.com/hc/en-gb/articles/43053562464017-Xone-96-User-Guide) confirms hardware Cue ownership. MIDI output to Cue/filter changes actual mixer state. The app sends no feedback, setup or routing command. Auxiliary Cue/PHONES2, VCF/MUTE and source-state actions stay inactive. Analogue gain, four-band EQ, filter and headphone controls are not duplicated as MIDI knobs.

The [manufacturer resource page](https://www.allen-heath.com/hardware/xone-series/xone96/resources/) confirms class-compliant macOS/iPadOS/iOS USB. Native external mixer deck routing, full control support and physical/A10X acceptance remain open. Select the MIDI subset deliberately and configure app audio separately. Saved alternate MIDI channels need separate mappings. The native fetch returned403, so the current primary HTML tables were reviewed through the web reader. Independent transcribed facts remain labelled as such.

Validation:221 Python checks and eight focused native tests passed, including the157-profile held-Cue corpus. Tests verified four-deck gating, direct Cue states, source-specific pickup and absence of hardware writes. A real-WAV fixture verified idempotent Cue, finite audio and saved Sync. The iPad framework compiled and its resource matches the source. All265 earlier recipes remain identical. A corrected fixture compile failure remains preserved. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r384/validation.json`.

The catalogue has266 data recipes. Automatic core coverage remains196 of342 physical models, with146 without automatic core controls. Thirty-eight records need a first protocol implementation. Complete theoretical and physical/iPad acceptance remain open.


## R385 independent PX5 and24C fader subsets

Assumption: each mixer needs independent wire facts. A manual fader subset does not establish analogue audio ownership.

The [PX5 definition author's public XML](https://virtualdj.com/forums/264850/VirtualDJ_Plugins/Mapping_the_XONE:PX5_Mixer.html) gives four channel faders CC0-3 and crossfader CC4. [Cardinia's own hardware table](https://cardinia.net/products/pro/) independently qualifies channel16 and CC0-3. Native explicitly assigns physical CH1-4 to A-D. The author's C/A/B/D software deck order is not a hardware address fact. Five manual faders are active. Cue press-versus-state semantics, FX assignment selectors and encoder formats remain unqualified for native actions.

The [24C manufacturer table](https://support.allen-heath.com/hc/en-gb/articles/39821017822865-Xone-24C-User-Guide) fixes channel16 and qualifies crossfader CC4, CH1 CC5 and CH2 CC6. Three manual faders are active. Shared VCF frequency CC7 has126-0 mild-to-wild behaviour and unqualified software assignment. It is not treated as a bipolar deck filter. Prose mentions Cue/filter/insert buttons, but the shown table does not supply their note addresses. Those controls remain inactive.

Both profiles require deliberate manual selection and separate app audio. Neither sends hardware, output, mode, reset or audio-route commands. Analogue EQ/gain/headphone controls, source/mode ownership, accessory endpoints, external mixer outputs and full lifecycle remain open. The manufacturer confirms class-compliant iPadOS/iOS USB for these mixers. Physical power, enumeration, audio and sustained A10X acceptance remain separate.

Validation:222 Python checks and seven focused native tests passed, including the157-profile held-Cue corpus. Native fixtures verified distinct CC layouts, four-deck gating, pickup, ignored buttons/other model wires and no hardware writes. Real-WAV fixtures for both profiles verified finite audio and saved Sync. The iPad framework compiled and its resource matches the source. All266 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r385/validation.json`.

The catalogue has268 data recipes. Automatic core coverage remains196 of342 physical models, with146 without automatic core controls. Thirty-six records need a first protocol implementation. Complete theoretical and physical/iPad acceptance remain open.


## R386 VMS5 manual software deck banks

Assumption: use independent VMS5 facts and require deliberate manual mixer ownership. Do not inherit the VMS4 profile.

The [manufacturer factory mapping](https://www.adj.eu/mwdownloads/download/link/id/786) contains302 used MIDI bindings. The read-only TSI inspector confirms shared A/C and B/D transport, pitch bend, tempo and jog wires. The [manufacturer manual](https://www.adj.eu/mwdownloads/download/link/id/787) confirms the independent deck buttons and held Cue behaviour. Its page18 warns that software EQ duplicates processing in default Pre EQ mode. Post EQ is required for software EQ. Mixer controls still need deliberate analogue/software ownership and separate audio.

The native manual subset has40 inputs. Note14 switches A/C. Note48 switches B/D. Each side changes once per press. NoteOff and NoteOn0 rearm it. A change releases source-owned Cue, pitch bend and contact holds. It resets both banks' tempo pickup and jog counters. Other sources and the opposite side retain their state. Fixed mixer strips keep C/A/B/D targets and pickup. C/D retain the four-deck opt-in. Applying, reconnecting or stopping resets software banks to A/B. No hardware state write establishes the initial bank.

The public DEX document supplies cyclic16384-wrap assembly and its2730-count jog scale. The manufacturer's2000-point marketing claim conflicts with that scale. Calibration remains provisional. The manufacturer TSI independently corrects the DEX left pitch-bend-up target. Conflicting Shift, Vinyl/keylock and PFL assignments remain inactive. No downloaded mapping, installer, source script, query, LED, firmware or audio command runs. Complete modes, library encoder format, feedback/lifecycle, external mixer outputs and physical/iPad/A10X acceptance remain open.

Validation:223 Python checks and41 focused native tests passed. These include the157-profile held-Cue corpus, side/source isolation, duplicate selector presses, both Cue release forms, four-deck gating, reconnect reset, independent mixer pickup and real-WAV2730-scale movement. The tests caught old-jog cleanup targeting the new bank. The corrected order now retires the old bank before retargeting, including disconnect. Initial pickup fixture failures came from values combined within one packet. Those failed results remain preserved. The iPad framework compiled and its resource matches the source. All268 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r386/validation.json`.

The catalogue has269 data recipes. Automatic core coverage remains196 of342 physical models, with146 without automatic core controls. Thirty-five records still need a first protocol implementation. Full theoretical support and physical/iPad/A10X acceptance remain open.


## R387 independent VMS4.1 Traktor manual mixer

Assumption: use the independently listed Traktor-edition manufacturer table. Assign physical MIDILOG1-4 to native A-D explicitly. Require manual mixer ownership.

The [manufacturer service page](https://www.adj.com/collections/vms4-1-traktor-parts) links the Traktor-edition MIDI table and manual. The table fixes MIDI channel1. Its pages6-8 were visually reviewed. The24-input manual subset contains four five-CC gain/EQ/linefader strips, masterCC28, normal crossfaderCC31, Cue mixCC34 and Cue gainCC35. All use the published0-127 ranges. The normal crossfader follows the table's left-to-right direction. C/D retain the app's four-deck option. Pickup protects existing app values.

The table uses generic CUE/PLAY/PAUSE/HOT START labels. The Traktor manual shows PLAY/CUE/A-C/SHIFT controls. Those labels do not reconcile sufficiently for transport or bank inheritance. Transport, Shift, jogs, encoders, touch strips, source/mode changes and all hardware writes remain inactive. The manual warns that default Pre EQ duplicates software EQ. Use Post EQ for software EQ. Configure audio separately and avoid duplicate analogue/software mixer control. Complete external deck routing and physical/iPad/A10X acceptance remain open.

Validation:225 Python checks and eight native tests passed, including the157-profile held-Cue corpus. Native fixtures cover every mixer input, direction, pickup, four-deck gating, inactive conflicting wires and distinct aliases. A real-WAV fixture retained finite, synced touch-started audio. The iPad framework compiled and its resource matches the source. All269 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r387/validation.json`.

The catalogue has270 data recipes. Automatic core coverage remains196 of342 physical models, with146 without automatic core controls. Thirty-four records still need a first protocol implementation. Full theoretical support remains open.


## R388 public AFX and Mixtrack Edge mapping facts

Assumption: read user-visible public mapping documents as independent MIDI address facts. Do not import or execute the source software or its mapping actions.

The [developer download page](https://djpromixer.com/downloads/) links an unencrypted ProMixer3.0 installer. A read-only archive library extracted135 mapping/licence documents into ignored research storage. No ProMixer executable, installer, mapping action, activation or network-sharing service runs. The source XML and third-party program code are not bundled. Member and installer hashes remain pinned. The developer's MIDI Learn guide describes user-created and shared mappings.

The [AFX guide](https://djpromixerblog.com/2015/06/13/akai-afx/) and two factory XML modes agree on44 native manual inputs. These cover six Cue pads, eight fixed loops from1/4 to32 beats, loop/transport pads and browse/load for A/B. Declared mode reports retire only their source/deck holds. The strict library encoder accepts1/127. Software-generated EQ/level aliases101-108 do not establish physical controls. C/D, Shift/FX and tactile search/pitch/scratch modes remain open. AFX is a MIDI-only accessory. Configure app audio separately. The historical DJTT sign-in finding remains intact and specific to that other source.

The [Mixtrack Edge guide](https://djpromixerblog.com/2015/06/10/numark-mixtrack-edge-2/) and120-row XML qualify51 native manual normal/Shift-release inputs. These cover Play/Cue/Sync, PFL, three Cue pads, manual loops, two-band EQ/linefaders, crossfader, Cue mix and strict library steps. Duplicate Shift38 rows become one held input. Shift reports retire source-owned holds on both transitions. Unsupported alternate button presses remain inactive, while releases rearm the normal layer. Source commands137/142-144/164 exceed MIDI's note range and remain inactive. Jog/touch/tempo and FX modes need separate protocol work. Desktop class compliance does not establish complete iPad or split-output support.

Validation:228 Python checks and ten native tests passed, including the157-profile held-Cue corpus. Every native input wire occurs in the pinned model document. Both AFX documents agree. Native fixtures cover both Cue release forms, source ownership, mode/Shift cleanup, pad arguments, strict encoder values and inactive wires. Two real-WAV fixtures retained finite, synced playback after Cue cleanup. The first source-hold test exposed missing Edge Shift cleanup. That failed result remains preserved. The corrected profile adds explicit transition cleanup. The iPad framework compiled and its resource matches the source. All270 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r388/validation.json`.

The catalogue has272 data recipes. Automatic core coverage remains196 of342 physical models, with146 without automatic core controls. Thirty-two records still need a first protocol implementation. Full modes, feedback/lifecycle, audio routing, theoretical completion and physical/iPad/A10X acceptance remain open.


## R389 independent DJM-S3 manufacturer mixer

Assumption: use the S3's own manufacturer Version1.00 table and operating manual. Keep hardware processing and external deck audio separate from optional app controls.

The [manufacturer MIDI table](https://dwn.alza.cz/manual/61365) is readable as cached PDF text through a public retailer mirror. Direct PDF bytes and screenshots remained unavailable. No table byte hash or visual table review is claimed. An independent transcription remains labelled as such in ignored research storage. The [manufacturer operating manual](https://www.recordcase.de/media/1d/ba/18/1745910632/Pioneer-DJM-S3-User-Guide-EN.pdf) page21 was visually reviewed. It confirms default MIDI channel1 and MIDI BUTTON TYPE TOGGLE.

The18-input manual profile uses two independent gain/three-band EQ/Color/linefader strips, direct CC70/71 Cue states and cross/master/headphone/blend controls. Repeated Cue reports set the state without toggling it. Source-selector Notes51-53 and55-57 reset only the corresponding strip's pickup. Physical CH1/2 map A/B. No DJM450/250/S9 alias, hardware setting, output or audio-routing command is inherited. AUX/microphone, curve/reverse, global Filter/parameter, complete modes/lifecycle/calibration and external deck outputs remain open.

Validation:230 Python checks and11 focused native tests passed, including the157-profile held-Cue corpus and DJM450 regression checks. Native fixtures cover every mixer input, direct Cue idempotence, source/deck isolation, pickup reset, inactive wires and sibling aliases. A real-WAV fixture retained finite, synced app-started audio. The iPad framework compiled and its resource matches the source. All272 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r389/validation.json`.

The catalogue has273 data recipes. Automatic core coverage remains196 of342 physical models, with146 without automatic core controls. Thirty-one records still need a first protocol implementation. Full theoretical support and physical/iPad/A10X acceptance remain open.

## R390 legacy dock-controller MIDI facts

Assumption: readable factory presets establish MIDI addresses. They do not establish a private dock transport, authentication, hardware initialisation or audio route. Manual profiles require an exposed MIDI port.

- [x] Pin the public archive and each model-specific preset. Transcribe only independent address facts.
- [x] Add21 manual inputs per model. Keep unqualified rotary streams, private transport and hardware writes inactive.
- [x] Verify both Cue release forms, pitch-bend cleanup, separate Philips Cue Set/Goto, pickup, source/deck isolation and real-WAV behaviour.
- [x] Run importer/native checks, compile the iPad framework and compare all earlier recipes.

Algoriddim's [current legacy-download guide](https://help.algoriddim.com/topic/subscription/purchased-older-version) links the public2.2.9 archive. Only115 visible preset/licence documents were extracted. No application, installer, activation, account, private custom class or downloaded mapping code runs. The archive and both presets have pinned hashes. Native resources contain independently transcribed MIDI facts, without source documents, artwork or executable code.

Each model has21 manual inputs. iDJ2GO keeps held Cue and pitch bends, native direct Load, Play/Sync/PFL, level/tempo and three global mixer controls. Its manufacturer quickstart printed page4 was visually reviewed and confirms held Cue and bend release. Factory polarity is retained for tempo and crossfader. M1X DJ keeps Play/Sync/PFL, separate Cue Set/Goto, tempo, three-band EQ and mixer faders. Its printed manual page10 was visually reviewed and distinguishes Cue Set from recall. Cue clear on a two-second hold remains open. Philips Bluetooth audio does not establish Bluetooth MIDI.

The native factory presets contain additional private or incomplete behaviour. Unqualified jog/browse scaling, source library navigation, Philips mode/record controls and output values remain inactive. The ION30-pin and Philips Lightning docks still need authentication/CoreMIDI exposure and audio qualification. The catalogue states this connection limit explicitly. No Numark sibling protocol or Philips custom class is inherited.

Validation:232 Python checks and nine native tests passed. Fixtures cover both Cue release forms, bend/stop cleanup, duplicate-button suppression, source ownership, independent Philips Cue actions, every absolute input and polarity, pickup, unavailable decks and inactive wires. Two real-WAV fixtures retain finite, synced playback. The first native run found an incorrect fixture count for two simultaneously mapped sources. The corrected fixture expects42 bindings and passes. Both logs remain in ignored evidence. The iPad framework compiled and its resource matches the source. All273 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r390/validation.json`.

The catalogue has275 recipes for342 physical models. Automatic core coverage remains196, with146 without automatic core. Twenty-nine records still need a first protocol implementation. Full theoretical support, signed-app delivery and physical/iPad/A10X acceptance remain open.

## R391 documented VCI-300MKII core reuse

Assumption: the primary mapping project's versioned manual explicitly states that MKII does not change the original MIDI mapping. This qualifies reuse of the reviewed MIDI contract. It does not qualify audio gain, direct-through routing, hardware jog sensitivity or physical acceptance.

- [x] Pin the official manual and retain a distinct MKII profile and model record.
- [x] Reuse existing native inputs, lamps and lifecycle bytes without downloaded code execution.
- [x] Verify automatic identity, held Cue release/cleanup, cyclic jog priming/wrap, pitch pickup and real-WAV movement.
- [x] Run source/native checks, compile the iPad framework and compare all earlier recipes.

The [official Mixxx2.4 manual](https://manual.mixxx.org/2.4/en_gb/hardware/controllers/vestax_vci_300) explicitly states that the MKII MIDI mapping is unchanged. The cached HTML and native source XML/script have pinned hashes. The older wiki used an AFAIK qualification. The versioned manual removes it. This is an explicit primary software-project compatibility claim. An independent manufacturer MKII wire table remains unavailable.

The distinct MKII profile reuses61 reviewed inputs,24 steady lamp recipes, five startup bytes and five shutdown bytes. It retains1600-count paired cyclic jogs, exact-centre nine-bit tempo, three Cue pads, native loops, Scroll/PFL loading and scoped modifiers. Exact MKII/MK2 aliases resolve independently from the original. All275 earlier runtime recipes remain identical. No downloaded code executes.

The manual separates analogue gain with the DC7 supply, optional digital crossfader, direct audio thru, jog-sensor adjusters and extra headphone socket. MIDI reuse does not implement those hardware features or establish audio routing. Complete modes/feedback/lifecycle, calibration and physical/iPad/A10X acceptance remain open.

Validation:234 Python checks and12 native tests passed. The158-profile held-Cue corpus includes MKII. Fixtures cover separate identity, both Cue release forms, duplicate suppression, disconnect/reconnect cleanup, independent cyclic counter wrap and pitch endpoints by target deck. Existing composed-modifier/pickup/feedback checks remain passing. The real-WAV touch/stop/Sync fixture now runs for both models. Earlier failed runs retain fixture diagnostics for a stale corpus count, the separate automatic binding store and unordered cross-deck event delivery. No production codec change was needed. The iPad framework compiled and the bundled resource matches the source. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r391/validation.json`.

The catalogue has276 recipes. Automatic core coverage reaches197 of342 physical models, with145 without automatic core. Twenty-eight records still need a first protocol implementation. Full theoretical support, signed-app delivery and physical/iPad/A10X acceptance remain open.

## R392 complete pinned VirtualDJ hardware inventory

Assumption: catalogue coverage must include the public VirtualDJ list as well as the pinned Serato, djay and Mixxx lists. A competitor product entry establishes inventory scope. It does not establish our implementation or physical acceptance.

- [x] Pin all487 public entries and their product URLs/categories. Resolve known naming variants without fuzzy model merges.
- [x] Retain two passive timecode media as source evidence outside the digital-device model count.
- [x] Add missing device records with explicit unimplemented status. Preserve every runtime recipe and existing support claim.
- [x] Test source hash, parsing bounds, duplicates, complete row coverage and support-claim separation.
- [x] Record the latest public package, manual, integration-key and unavailable-download findings.

The [public VirtualDJ hardware list](https://virtualdj.com/products/hardware.html?view=all) has487 distinct product URLs across eight categories. The snapshot retains source names, category and product URL. A small explicit name table resolves existing NI/Hercules/Denon/Reloop and other product spellings. There is no fuzzy model merge. VVT-101 resolves to VTT-101 using the source's VTT101 product ID. SX1 remains separate from the original Next Beat. The generic original Digital Jockey row remains separate from Digital Jockey2. Two passive timecode media remain source rows outside the digital-device count. The18 sound-card/interface entries retain audio/DVS requirements rather than invented MIDI mappings.

This adds210 device records, including ten previously absent Pioneer products. The earlier28 first-protocol gaps covered only the previous pinned source set. They did not cover the wider market. The catalogue now has559 records for552 physical models. Automatic core coverage remains197, with355 without automatic core and238 without a first protocol implementation. Every previous model keeps its implementation, selected profile, role, input/output counts and zero-config claims. All276 runtime recipes remain byte-identical. Full theoretical support remains0 of552. The manufacturer audit and physical acceptance remain open.

Validation:237 Python checks passed. New checks cover all487 source rows, unique product URLs, source bytes, parser bounds, missing names/categories, duplicate URLs, passive-media exclusion, separate DVS requirements and unimplemented status for newly found controllers. An initial generator run used an undefined root constant. The corrected path and complete re-run pass. Failed and passing logs remain in `TestBuilds/r392/validation.json`. The repository checker retains12 historical missing-file links. No native app source or runtime resource changed, so no additional Swift build or device operation was needed.

Further public-source findings:

- The official VirtualDJ package was downloaded and expanded without installation or execution. Its controller artwork archive contains588 PNG files and one skin ZIP. Its other controller data file is not readable XML or a standard ZIP. No binary controller extraction, decompilation, artwork reuse, activation or account was attempted.
- Native Instruments' current Traktor Ready index lists a Twelve MKII mapping. The published Traktor4 archive link returns404. The one checked legacy Traktor2 location also returns404. No mapping bytes were recovered.
- The actual VFX-1 owner manual from the parts archive has14 scanned pages. All pages were reviewed as a contact sheet. It describes hardware/software effects but has no MIDI address chart. It is separate from the earlier two-page brochure and service schematic.
- The current public Phase integration issue identifies an encrypted per-software wake-up/key requirement. The presence of a public experimental decoder does not provide that authorisation or direct iPad HID support.
- The checked public Rane/ELITE owner discussions contain no downloadable mapping export. Current Serato download UI reports an error. The legacy ITCH download redirects to sign-in. Current djay desktop downloads lead to app stores. No account or access restriction was bypassed.

The next implementation priority is the newly exposed Pioneer mixer/player gap, using each model's own usable public table. Other models follow where independent public wire facts are available. Inventory coverage does not change runtime support.

## R393 independent legacy DJM four-strip mixers

Assumption: reuse only the32 mixer fields independently confirmed in each model's manufacturer table. Physical CH1–4 target native A–D by an explicit app layout. Keep hardware processing and external deck audio separate.

- [x] Pin and visually review the900NXS,850 and750MK2 charts. Keep hexadecimal and decimal notation separate during transcription.
- [x] Add three manual32-input profiles with direct Cue states. Only750MK2 receives its documented source-selector pickup resets.
- [x] Verify every input, C/D opt-in, Cue idempotence, source isolation, pickup and real-WAV Sync.
- [x] Run source/native checks, compile the iPad framework and preserve all earlier recipes.

Independent manufacturer documents qualify the same32 selected controls in all three models. The900NXS manual uses hexadecimal addresses. The850 manual prints decimal CC numbers. The750MK2 Version1.00 addendum uses hexadecimal addresses. Table pages900NXS21/22,85022/23 and all three750MK2 pages were visually reviewed and byte-hashed. The900NXS/850 settings tables specify default MIDI1/Toggle. The750MK2 addendum does not establish factory utility defaults, so its manual profile states MIDI1/Toggle as a required mode without a default claim.

Each physical strip has gain, high/mid/low EQ, Color-to-native-filter, line fader and independent Cue state. Physical CH1–4 target native A–D by an explicit app layout. C/D need app opt-in. Crossfader, master, monitor and cue blend complete each32-input profile. The750MK2 alone has sixteen documented source-selector notes, including Return AUX. Their on127 reports reset pickup only for the affected strip. No selector address is invented for the900NXS or850.

These manual app mixer controls keep hardware processing and external deck audio separate. No hardware setting, query, lamp or automatic audio route is sent. Curve/assignment, advanced Color/Beat FX, master/Link/FX Cue, mic, fader starts, complete modes/lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open. The900NXS profile does not claim NXS2/SRT compatibility. The750MK2 profile does not claim original750 compatibility. The850 manual explicitly covers its K/S/W colour variants.

Validation:240 Python checks and eight native tests passed, including the158-profile automatic held-Cue corpus. Parameterised native fixtures cover every absolute input on each model, C/D availability, direct Cue idempotence, source isolation, per-strip pickup reset, inactive wires and sibling boundaries. Real-WAV fixtures for all three models retain finite, synced app-started playback. The iPad framework compiled and its bundled resource matches the source. All276 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r393/validation.json`.

The catalogue has279 recipes for552 physical models. Automatic core coverage remains197, with355 without automatic core. First-protocol gaps fall from238 to235. Full theoretical support and physical/iPad/A10X acceptance remain open.

## R394 independent SRT original750 and250MK2 mixers

Assumption: retain900SRT's documented USB deck order C/A/B/D. Original750 uses physical CH1–4 as native A–D and has no per-strip Color control. The250MK2 uses physical CH1/2 as A/B. All profiles remain manual app mixers with separate audio.

- [x] Pin and visually review available manufacturer manuals. Label250MK2 cached table facts separately from source bytes.
- [x] Add32 SRT,28 original750 and18 separate250MK2 inputs. Keep each source-selector contract independent.
- [x] Verify all mixer fields, source/deck isolation, direct Cue states, pickup, unsupported controls and real-WAV Sync.
- [x] Run source/native checks, compile the iPad framework and compare all earlier recipes.


The independent900SRT decimal chart on pages22/23 assigns USB decks3/1/2/4 to physical CH1–4. The32-input profile therefore targets C/A/B/D, with C/D behind app opt-in. Its sixteen source-selector notes reset only the affected strip pickup. The original750 chart on pages19/20 qualifies28 inputs. Its global Boost Color FX control is not four strip filters, so no filter or MK2 selector is inherited.

The250MK2 Version1.00 table was independently reviewed as cached extracted text. Its18 inputs cover two gain/EQ/Color/fader/Cue strips and four global controls. Six source-selector reports reset their own strip pickup. Direct table PDF bytes and screenshots remain unavailable. The separate manufacturer operating manual was downloaded, byte-hashed and page19 visually reviewed. It confirms default MIDI1/TOGGLE. No table byte hash or visual table claim is made. Exact sources and hashes are in the catalogue and public-source audit.

Validation:243 Python checks and ten native tests passed, including the158-profile automatic held-Cue corpus. Independent fixtures check every mapped input, SRT deck ownership, C/D availability, direct Cue reports, source isolation, per-strip pickup, inactive original750 Color wires and absent MK2 selectors. Real-WAV fixtures retain finite, synced app-started playback on all three new models. The iPad framework compiled and the bundled resource matches the source. All279 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r394/validation.json`.

The catalogue has282 recipes for552 physical models. Automatic core remains197, with355 without automatic core. First-protocol gaps fall from235 to232. Full modes/audio/lifecycle/calibration, physical/iPad/A10X acceptance and full theoretical support remain open.


## R395 independent DJM2000 and2000NXS mixers

Assumption: each model's own manufacturer chart qualifies a manual32-input app mixer. Physical CH1–4 map to native A–D. Zone1 must use MIDI1/Toggle. Touchscreen Zone2 and hardware processing remain separate.

- [x] Pin and visually review both model charts.
- [x] Add independent mixer inputs without inherited source reports or touchscreen actions.
- [x] Verify all inputs, C/D availability, Cue states, pickup, inactive controls and real-WAV Sync.
- [x] Run source/native checks, compile the iPad framework and preserve earlier recipes.


The original2000 manual pages19/20 and independent2000NXS manual pages20/21 were visually reviewed and byte-hashed. Each hexadecimal chart qualifies the same32 selected native mixer fields. Settings pages25 and27 document separate MIDI channels for Zone1 and editable touchscreen Zone2. These manual profiles require Zone1 MIDI1/Toggle and Zone2 MIDI2. No factory-default claim is made. Physical CH1–4 target native A–D, with C/D behind app opt-in. Filter knobs control the native software filter.

Touchscreen Frequency Mix/Sidechain Remix, editable TypeA–D, Sync Master, hardware FX/mic, curve/assignment, full modes/lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open. There are no invented source-selector reports, hardware writes or automatic external deck routes.

Validation:246 Python checks and11 native tests passed, including the158-profile automatic held-Cue corpus. Parameterised fixtures check every input, pickup, Cue states, source/deck isolation, C/D availability and inactive touchscreen packets. All32 mixer addresses on the separate Zone2 channel stay inactive. Real-WAV fixtures retain finite, synced app-started audio. The iPad framework compiled and its bundled resource matches the source. All282 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r395/validation.json`.

The catalogue has284 recipes for552 physical models. Automatic core remains197, with355 without automatic core. First-protocol gaps fall from232 to230. Full theoretical support and physical acceptance remain open.


## R396 independent T1 andMEP7000 controls

Assumption: T1 remains a manual Generic Controller profile on MIDI1, with both mixer MIDI buttons enabled. Its selected native mixer controls retain the same function across all three wire layers. MEP7000 uses its documented default A/centre channel1 and B channel2 in PC control. Hardware mode entry and audio setup remain separate from automatic app profile selection.

- [x] Pin and visually review both manufacturer charts and their setup limits.
- [x] Add T1 controls with alternate Cue releases and bounded documented lamps. Add MEP loading, transport, jog-speed, pitch and loop controls.
- [x] Verify source isolation, cleanup, all input families, feedback and real-WAV Sync.
- [x] Run source/native checks, compile the iPad framework and preserve earlier recipes.


Both current manufacturer PDF files were recovered from the current document host and byte-hashed. T1 chart pages28/29 and MEP7000 pages59/60 were visually reviewed. T1 uses note-name C-1=0 and decimal CC labels. MEP uses hexadecimal addresses and an absolute speed contract, independently matching the existing bounded speed decoder.

T1 has60 manual inputs: base load/play/held Cue/Sync, four Hot Cues per deck, loop controls, normal/Shift library navigation and selected gain/EQ/level controls on all three wire layers. The same physical mixer fields deliberately retain their native function across layers. Alternate Cue releases at normal, Shift and Advanced addresses release existing ownership. Positive alternate Cue messages do not start a preview. Fourteen base transport/Sync/Cue/pad lamp mappings use the table's0/127 values through separate manual feedback opt-in. No automatic lamp startup/shutdown is claimed. Generic Controller Mode, the two mixer MIDI buttons and MIDI1 must be set by the user.

The T1's two crossfader attenuation outputs do not establish one physical-position value, so neither is mapped as the native crossfader. The app has no MIDI Hot Cue delete action; shifted delete keys remain inactive. Other Shift/Advanced functions, sampler/FX/LFO, full mode handling and audio/lifecycle/calibration remain open.

MEP7000 has26 automatically selected MIDI inputs on default A/centre1 and B2. It includes direct Load A/B, held Cue, Play, loop points/reloop, keylock, held bend, jog contact, absolute speed jogs, centred pitch and browse/open-group. The table explicitly specifies64 stopped,65/63 about+/-0.06x and127/0 at+/-4x. Its Load and browse rows are available in both Normal and Manipulator styles. Hardware PC/Load entry remains required. Source mode changes, search/memory/Jog Break modes, pitch range, displays/lamps and audio remain open. No SEP-C1 or CDJ sibling table is inherited.

Validation:249 Python checks and12 native tests passed, including the159-profile automatic held-Cue corpus. Fixtures check all T1 mixer layers, alternate Note Off/zero releases, source ownership, all selected control families, MEP speed/pitch boundaries, loading, inactive modes, stop/disconnect cleanup and all fourteen lamp byte mappings. Two real-WAV tests retain finite, synced playback after alternate Cue and speed-touch/bend releases. The iPad framework compiled; its bundled resource matches the source. All284 earlier recipes remain identical. Failed fixture compilation and normalised-value assertions remain in the evidence history. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r396/validation.json`.

The catalogue has286 recipes for552 physical models. Automatic core coverage increases to198, with354 without automatic core. First-protocol gaps fall from230 to228. Full theoretical support and physical/iPad/A10X acceptance remain open.


## R397 independent Instinct P8 core

Assumption: qualify P8 independently of original Instinct. Use default channel1, documented separate wheel/contact streams and factory256-count resolution. Preserve factory Shift mixer targets C/D behind app opt-in. Native Shift jog uses a bounded fine pitch response; source-software curve equivalence remains open.

- [x] Pin and review the manufacturer table and current DJUCED factory facts.
- [x] Add independent controls with explicit mode/Shift cleanup and bounded lamps.
- [x] Verify wire families, pickup, source ownership, C/D availability and real-WAV Sync.
- [x] Run source/native checks, compile the iPad framework and preserve earlier recipes.


All six pages of the P8 Version1.1 manufacturer table were visually reviewed and byte-hashed. The current public DJUCED6.8.1 factory member was parsed without running code or copying its image. Its own channel0 and256-count wheel/contact facts qualify P8 independently of original Instinct.

The86-input core includes two independent Shift keys, normal transport with alternate release aliases, direct loads, PFL, source-local touch gates, separate wheel/contact streams, four Hot Cues per side, loop buttons and encoders, selected A/B mixer fields and factory Shift mixer targets C/D. C/D need app opt-in. EQ follows the table's reversed physical direction. Both Shift edges retire their own A/C or B/D contacts/pickup through the existing releaseShiftChannels contract. A Mode press retires all four decks. No decoder or catalogue guardrail was weakened.

Native Shift jog changes the bounded pitch position by count/1024. Exact source-software pitch-curve equivalence remains open. All four normal loop-encoder pages deliberately control native loop size. Source conditional FX and loop movement remain open. Normal pads use documented blue125 and transport/PFL use127, all off0. Startup/shutdown clear only22 selected lamps. No All Controls query or mode SysEx is sent. Source held roll/sampler, Hot Cue deletion, HP buttons, complete feedback/lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open.

Validation:252 Python checks and11 native tests passed, including the160-profile automatic held-Cue corpus. Fixtures check wheel/contact separation and signed64, all selected mixer targets and pickup, C/D availability, independent Shift/source ownership, transport release aliases, cue/loop/library families, fine pitch, master increments, lamp bytes and disconnect cleanup. A real-WAV fixture retains finite, synced playback after Cue and jog mode cleanup. The iPad framework compiled and its bundled resource matches the source. All286 earlier recipes remain identical. The rejected duplicate/zero-valued bank declaration run remains in the evidence history. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r397/validation.json`.

The catalogue has287 recipes for552 physical models. Automatic core coverage increases to199, with353 without automatic core. First-protocol gaps fall from228 to227. Full theoretical support and physical acceptance remain open.


## R398 reconciled Universal DJ USB core

Assumption: the manufacturer's separately published djay and Traktor mappings plus current DJUCED facts qualify the USB MIDI core. Their common mixer addresses take precedence over conflicting older PDF rows. Use explicit pitch pairs and a fixed two-deck native layout. Bluetooth, tablet transport and automatic audio remain separate.

- [x] Pin and reconcile the independent manufacturer archives and current factory member.
- [x] Add selected USB controls with source-local contacts, per-side Shift and bounded lamps.
- [x] Verify both pitch pair families,512-count streams, pickup, loops, cleanup and real-WAV Sync.
- [x] Run source/native checks, compile the iPad framework and preserve earlier recipes.


The manufacturer's support page directly links separate djay Pro and Traktor archives. The djay plist, used Mac/PC TSI binding records and current DJUCED factory member agree on mixer addresses: A level57/high59/mid60/low61; B level58/high62/mid63/low64; cross65. This resolves the older PDF conflicts. The current factory output bounds qualify0/127 instead of the PDF's impossible128. No source mapping action or downloaded code was executed.

Used Mac and PC TSI rows explicitly qualify MSB/LSB pairs1/33,2/34 and55/71,56/72, all inverted. The independent current factory member supplies512-count separate wheel/contact calibration, eight cue keys, loop controls and bounded lamps. Native uses111 inputs and30 selected lamp mappings. Both pitch families maintain separate decoder state and pickup. Per-side Shift reports retire source-local contacts and pickup on both edges. The native layout fixes A/B; no source-software C/D selection is inferred.

The core includes transport, loads, PFL, contact/wheel jogs, paired pitch, selected mixer fields, eight Hot Cues and eight fixed-loop sizes per deck, selected manual loop controls, shifted gain encoders and library navigation. EQ follows the manufacturer's printed physical direction pending capture. Startup/shutdown clear only30 selected lamps, within60 total lifecycle messages. There is no All Controls query, setup SysEx or automatic audio route. Bluetooth/tablet, FX/sampler, Hot Cue deletion, cue-loop extraction, complete modes/feedback/lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open.

Validation:255 Python checks and11 native tests passed, including the161-profile automatic held-Cue corpus. Fixtures check both pitch families, endpoints, pickup, source/pair separation,512-count contact/wheel streams, both Note Off forms, independent Shift/source cleanup, mixer rows, all cue/loop families, shifted gain, library, lamp bytes and disconnect cleanup. A real-WAV fixture retains finite, synced playback after Shift contact cleanup. The iPad framework compiled and its bundled resource matches the source. All287 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r398/validation.json`.

The catalogue has288 recipes for552 physical models. Automatic core coverage increases to200, with352 without automatic core. First-protocol gaps fall from227 to226. Full theoretical support and physical acceptance remain open.


## R399 independent Wave USB core

Assumption: use the manufacturer's djay mapping's common modifier on both MODE keys and the manufacturer VirtualDJ definition's512-count jog scale. Keep selected USB controls independent of Bluetooth, tablet audio and source-software ring animation. The different DJUCED720 calibration remains an explicit capture limit.

- [x] Pin and reconcile the three manufacturer archives and current factory facts.
- [x] Add42 selected USB inputs and14 bounded lamp mappings, without unqualified ring/setup writes.
- [x] Verify composed Shift, loading, source contact ownership, mixer/pitch, loops and real-WAV Sync.
- [x] Run source/native checks, compile the iPad framework and preserve earlier recipes.


Hercules directly publishes separate djay, Traktor and VirtualDJ archives for Wave. Both djay members assign MODE notes16/34 to the same application modifier. The native core therefore composes both held MODE contacts as one source-local Shift. Releasing one leaves the other active. Normal Play becomes Shift Load on either deck. Normal loop encoder/press becomes Shift browse/open-group. This follows the manufacturer djay layout; the DJUCED-specific right-MODE headphone layer remains open.

The manufacturer VirtualDJ device definition explicitly gives512 full-turn counts for all four wheel/contact streams. Current DJUCED specifies720; this remains an unresolved physical-calibration difference. The42-input core uses512, source-local contact gates, inverted pitch, three cue pads per deck, loops, mixer, crossfader and master. Fourteen selected transport/loop/cue-pad lamps use0/127 and clear on startup/shutdown. No ring/setup SysEx, state query, meter or EQ-kill output is sent. The djay PFL entries point both decks to the same unrelated channel4 CC9 template, so no PFL wire is inferred from them.

Validation:258 Python checks and ten native tests passed, including the162-profile automatic held-Cue corpus. Fixtures check both MODE press/release orders and release forms, Shift loading on both decks, contact/wheel separation and signed64, source ownership, pickup, Shift-independent mixer/pitch, cue/loop/library families, lamp bytes and stop cleanup. A real-WAV fixture retains finite, synced playback after Cue and contact mode cleanup. The iPad framework compiled and its bundled resource matches the source. All288 earlier recipes remain identical. The repository checker retains12 historical missing-file links. Evidence: `TestBuilds/r399/validation.json`.

The catalogue has289 recipes for552 physical models. Automatic core coverage increases to201, with351 without automatic core. First-protocol gaps fall from226 to225. Bluetooth/tablet transport, ring animation, full modes/lifecycle/audio/calibration, full theoretical support and physical/iPad/A10X acceptance remain open.


## R400 Twitch basic MIDI and bounded load-bank routing

Assumption: the published Basic-mode reset establishes A/B bank state. Reuse the existing source-local bank engine for the two shared load buttons. Automatic banking is limited to load actions, paired bounded startup/shutdown and unbanked feedback. Other automatic banked actions remain invalid.

- [x] Pin and visually review the manufacturer Basic-mode, page, contact and lifecycle contracts.
- [x] Add schema guards and fixtures for automatic load-only bank routing.
- [x] Add selected native Basic controls, source-local contact and bounded feedback.
- [x] Verify both load banks, source/deck isolation, pickup, cleanup and real-WAV Sync.
- [x] Run source/native checks, compile the iPad framework and preserve earlier recipes.

The manufacturer programmer guide qualifies Basic reset, four firmware MIDI pages, the two fixed-channel Load buttons, touch contact, SWIPE/DROP and selected lamp values. The139-input core uses44 static lamps. The existing bank engine now permits automatic dynamic targets only for Load, with bounded paired startup/shutdown and no Load feedback. Other automatic banked actions still fail catalogue validation. A missing output or failed reset blocks input. Reconnection resets software A/B state and sends the documented Basic reset; physical reset/bank equivalence remains unverified.

All positive contact velocities are accepted because they encode strip position. SWIPE is signed CC53 and stops on release, Shift, pad page or deck selection. DROP is absolute CC52. Firmware retains four-deck lamp pages; no feedback follows the software Load bank. Native chooses composed Shift, beat jumps, eight fixed loop lengths and127 software scrub scaling. These are explicit app choices. They do not establish source-software feature parity or physical calibration. No direct-monitor, advanced-mode, private arbitration, audio-route or all-LED-off write is sent.

Validation:261 Python checks and19 native tests passed, including163 automatic held-Cue profiles. Tests cover schema rejection, paired reset failures, both load selectors and release forms, source isolation, four-deck opt-in, reconnect, transport, cue and loop pads, relative tempo, every positive strip-contact range, signed SWIPE, DROP, pickup, composed Shift, page cleanup, exact shutdown and finite synced real-WAV playback. The iPad framework compiled and its bundled resource matches the source. All289 earlier recipes remain identical. The first native run retained two fixture-callback failures; the corrected fixture passes. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r400/validation.json`.

The catalogue has290 recipes for552 physical models:202 automatic core and350 without automatic core. First-protocol gaps fall to224. Full theoretical support remains0/552. Advanced arbitration, full modes/lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open.

The public Roland707M MIDI chart was also recovered. Its owner manual explicitly excludes DJ software from the iOS Generic PC-B playback path; MIDI control uses PC-A. The public chart therefore does not close its iPad transport gap.

## R401 independent Akiyama chart subsets

Assumption: keep three independent manual profiles while chart conflicts, full mode negotiation and calibration remain unresolved. Use each model's published wire addresses. Do not infer sibling protocols, feedback or automatic audio.

- [x] Pin and visually review each manufacturer's chart and cross-check visible factory facts.
- [x] Add bounded normal controls with alternate-release and source-local Shift/deck cleanup.
- [x] Verify channel isolation, four-deck opt-in, pickup, held Cue and real-WAV Sync.
- [x] Run focused native/source checks, compile the iPad framework and preserve earlier recipes.

Each profile uses its own manufacturer manual, mirrored by a retailer, with the relevant chart pages visually reviewed. Independent visible factory XML facts cross-check the selected normal mixer rows. Quattro has98 inputs, Quark SC200 and TTWO125. All remain manual, with no startup/shutdown, feedback or audio-route writes. The core retains four explicit deck channels, direct loads, PFL, Hot Cues, selected manual loops, mixer pickup and source-local held-Cue cleanup.

Quattro uses fixed mixer channel4 and three alternate transport releases. Its unclear pitch data-byte scaling and jog calibration remain inactive. Quark SC retains six normal Cue pads, listed Shift CC aliases and composed physical Shift contacts across paged channels. Its normal loop encoder uses one native step per directional packet. AutoLoop/Roll and FX/sample-slot functions remain inactive. TTWO retains separate A/B load/PFL channel4 and C/D channel5. Its pitch/filter collision, ambiguous jog direction/Shift, crossfader type, browser press/release and conflicting lamp rows are not imported. No sibling protocol is substituted for a missing fact.

Validation:264 Python checks and11 native tests passed, with three model cases on each shared fixture and all163 automatic held-Cue profiles retained. Checks cover manual identity, exact transport/hotcue/load channels, duplicate and both release forms, source ownership, Shift/deck cleanup, pickup, four-deck opt-in, disputed wires remaining inactive, stop cleanup and finite synced real-WAV playback. The iPad framework compiled and its bundled resource matches the source. All290 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r401/validation.json`.

The catalogue has293 recipes for552 physical models. First-protocol gaps fall from224 to221. Automatic coverage remains202 models, with350 without automatic core and0/552 with full theoretical support. Full modes/lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open. Quark SC's200 manual bindings also leave room for only56 other manual inputs under the existing256-input mapping limit.

## R402 independent Launchpad Programmer grids

Assumption: use a native four-quadrant grid on independently documented Programmer layouts. A/B occupy the lower quadrants; opt-in C/D occupy the upper quadrants. This is an app layout, separate from Ableton and other DJ mappings. X and Pro MK3 select Programmer mode through their documented MIDI interfaces and return to Live at shutdown. Original Pro requires manual Standalone Programmer mode on channel1.

- [x] Pin and visually review each independent manufacturer layout, interface, mode and lamp contract.
- [x] Add64 grid inputs and52 static lamp mappings per model, with bounded setup for X/Pro MK3.
- [x] Verify quadrant routing, C/D opt-in, contact/velocity release, source and port isolation, setup failure and cleanup.
- [x] Run native/source checks, real-WAV playback, iPad framework compilation and earlier-recipe comparison.

Each model has an independently pinned programmer guide and visually reviewed grid. The app uses the same native function arrangement on each independently qualified grid. Within each quadrant, rows run from bottom to top:

| Row | Four pads, left to right |
| --- | --- |
| 1 | Play, held Cue, Sync, Load |
| 2 | PFL, loop In, loop Out, Reloop |
| 3 | Hot Cues1..4 |
| 4 | Hot Cues5..8 |

X uses the documented LPX MIDI pair and product12 command14. Pro MK3 uses LPProMK3 MIDI and product14 command14. Both enter Programmer1, clear64 grid lamps in two104-byte messages and return to Live0 after shutdown clears. Each message stays within the existing128-byte bound. The new optional startup-abort contract permits at most four reviewed exit messages, requires automatic paired setup, excludes protocol decoders, and counts towards the existing64-message lifecycle limit. Immediate and timed failure paths attempt the exit without enabling input. A failed exit still needs connection or power recovery; this is a best-effort software guarantee.

The original Pro has its own product16/layout44 protocol, second USB Standalone interface and saved per-layout MIDI channel. Its64 inputs and52 lamps remain manual on Programmer channel1, with feedback as a separate opt-in and no automatic hardware write. The added Pro MK3 catalogue model is distinct from the original Pro. No sibling mode command or persistent custom template is inferred. These are native app mappings, not Ableton presets or copies of downloaded scripts.

Validation:267 Python checks and31 native tests passed, including165 automatic held-Cue profiles. Tests cover all quadrants/pad slots, low-velocity Cue ownership and both release forms, pressure/foreign inputs, C/D opt-in, identity/port ambiguity, missing outputs, failure at each setup step with a Live exit attempt, schema bounds, exact clear/stop messages, static feedback and finite synced real-WAV playback. Existing Twitch, manual bank routing and Pioneer startup regressions also pass. The iPad framework compiled and its bundled resource matches the source. All293 earlier recipes remain identical. A retained first compile failed on an overly complex test expression; a later fixture expected full velocity for a low-velocity press. Both fixture issues are corrected. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r402/validation.json`.

The catalogue has296 recipes for553 physical models:204 automatic core and349 without automatic core. First-protocol gaps fall to219. Full theoretical support remains0/553. Outer buttons, remaining modes/expressions, full feedback/lifecycle and physical/iPad/A10X acceptance remain open. Live-mode restoration does not restore an arbitrary pre-connection custom state. Unknown OS port-name variants still require qualification.

## R403 independent APC mini MK2 Session core

Assumption: support Session view on MIDI channel1 through the documented Control interface. Drum channel10 and the separate Note interface remain inactive. Reuse the native quadrant functions only after independently checking the Akai grid addresses. Faders1..4 control A..D levels,5..8 control A..D gain, and9 controls master. This is an app layout.

- [x] Pin and visually review the independent grid, ports, Shift, faders, brightness and introduction/clear contracts.
- [x] Add74 inputs/52 lamps with source-owned Shift cleanup and bounded lifecycle packets.
- [x] Verify grid/faders, channel/port and C/D isolation, setup failure, feedback and real-WAV Sync.
- [x] Run focused checks, compile the iPad framework and preserve earlier recipes.

The manufacturer Communications Protocol v1.0 independently qualifies the bottom-to-top0..63 grid, Shift122, absolute CC48..56 faders, introduction and RGB pad-range clear. The current manufacturer setup guide names the Control interface. The profile accepts only that interface and wire channel0. Drum channel9, other Session channels and the separate Note interface remain inactive. Static pad feedback uses wire channel6 for full brightness. No Novation, original APC mini or APC40 wire address or mode command is inherited.

The existing app quadrant functions now use a small shared builder that takes each caller's independently reviewed eight wire rows. All296 earlier recipes remain identical. APC mini MK2 has64 guarded grid inputs, held Shift and nine faders:74 inputs and52 lamps. Shift retires source-owned holds and suppresses pad actions while it is held. Faders1..4 control A..D levels,5..8 A..D gain, and9 master. C/D still require opt-in. These are app function choices, separate from Ableton mappings.

Startup sends the published product79/application0 introduction with the current app version0.1.0, then one16-byte zero-RGB clear for pad range0..63. Shutdown and bounded failure recovery use the same clear. No surrounding-button state, private handshake, DAW script, persistent preset or audio route is written. This does not claim automatic selection of every saved hardware mode/channel or restoration of previous user colours.

Validation:270 Python checks and20 native tests passed, including166 automatic held-Cue profiles and all R402 Programmer-grid regressions. Tests cover all quadrant functions/slots, strict channels and ports, velocity/release ownership, Shift, nine-fader pickup and targets, C/D opt-in, exact full-brightness feedback, introduction/clear/failure/stop bytes and finite synced real-WAV playback. The iPad framework compiled and its bundled resource matches the source. A retained first compile caught a missing optional unwrap in a fixture; an earlier source check caught stale generated review text. Both are corrected. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r403/validation.json`.

The catalogue has297 recipes for553 physical models:205 automatic core and348 without automatic core. First-protocol gaps fall to218. Full theoretical support remains0/553. Remaining UI/modes/channels, full feedback/lifecycle, OS port-name variants, power and physical/iPad/A10X acceptance remain open. The separate APC40 MKII protocol is downloaded for the next review.

## R404 independent APC40 generation cores

Assumption: use each manufacturer's documented mode1 to make buttons momentary and device knobs unbanked. Assign four native column pairs to A..D using each model's published control order. Original grid rows use notes53..57 on track channels0..7. MKII uses40 distinct grid notes. This is an app layout; physical pad orientation still needs acceptance. Restore Generic mode at shutdown or startup failure, rather than claim restoration of an arbitrary previous mode.

- [x] Pin and visually review both independent setup, input and feedback contracts.
- [x] Add selected native grid/strip/knob/library controls, with explicit model-specific colours and bounded lifecycle.
- [x] Verify track/global channel boundaries, Shift ownership, pickup, C/D opt-in, ring values, setup failure and real audio.
- [x] Run source/native checks, compile the iPad framework and preserve earlier recipes.

The two independently pinned manufacturer protocols qualify different product IDs and grids. Original APC40 uses product115 and per-track grid notes53..57 on channels0..7. MKII uses product41 and40 distinct grid notes0..39. Both use the public Mode1 configuration65 for momentary buttons and unbanked device knobs. Each startup sends its own12-byte introduction with app version0.1.0. Shutdown clears52 selected note lamps and selects Generic configuration64. Bounded failure recovery attempts the same Generic exit. The total55 lifecycle messages stay within the existing64-message bound.

The native app uses adjacent column pairs1/2,3/4,5/6,7/8 for A/B/C/D. The first four published grid rows form eight Hot Cues per pair; row5 is Play/held Cue. Arm buttons become Sync/Load, Solo becomes PFL/key lock, Activator becomes loop In/Out, Track Select becomes half/double and Clip Stop becomes Reloop/toggle. Paired faders become level/gain. Sixteen knobs control high/mid/low/filter across four decks and receive native value feedback. Scene buttons supply library navigation. Cue Level47 is signed relative in both guides; MKII Tempo13 supplies native browse. These are app function choices. Physical pad orientation and full interaction still require acceptance.

The explicit paired-unbanked contract permits global input channels only for an automatic accessory with bounded startup, shutdown and abort; one global Shift; no protocol decoder or software deck bank; and all16 exact channel selectors clearing every deck on that Shift. Track inputs keep their explicit channels. Other wildcard accessory profiles remain invalid. Contract validation runs once per profile validation. Both guides' repeated/ambiguous ring-type input rows remain inactive. Selected note feedback uses each generation's own colour codes and actual Note Offs. The16 CC outputs update knob positions/rings; shutdown does not claim complete ring or prior-state restoration.

Validation:273 Python checks and37 native tests passed, including168 automatic held-Cue profiles and existing bank/Programmer-grid/APC mini regressions. Fixtures cover both independent grids, all strip functions, global/track boundaries, every global Shift channel and source ownership, pickup, signed monitor/browse, static colours and continuous ring values, mode failure/stop, C/D opt-in and finite synced real-WAV playback. The iPad framework compiled and its bundled resource matches the source. All297 earlier recipes remain identical. The retained first native run correctly rejected unqualified accessory wildcard inputs; a separate red fixture precedes the bounded unbanked contract. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r404/validation.json`.

The catalogue has299 recipes for553 physical models:207 automatic core and346 without automatic core. First-protocol gaps fall to216. Full theoretical support remains0/553. Unreviewed table screenshots are identified separately from visual evidence in the source records. Remaining hardware controls/modes, complete feedback/ring/state/lifecycle/audio/calibration and physical/iPad/A10X acceptance remain open. Generic exit is a best-effort return to the documented default, not saved-state restoration.

## R405 Launch Control3 andXL3 DAW cores

Assumption: use each model's documented DAW interface and temporary DAW Control mode. Use published surface indices for native four-deck mixer and transport functions. Do not write saved custom modes, brightness, MIDI routing or global channel settings. Legacy Launch Control and XL require separate factory-template input evidence.

- [x] Pin both independent manufacturer guides and visually check surface indices.
- [x] Add bounded setup/exit and a mode gate that retires source-owned holds and pickup when surface mode changes.
- [x] Verify strict port/channel boundaries, mixer/transport targets, feedback, partial setup failure and synced real audio.
- [x] Run focused checks, compile the iPad framework and preserve all299 earlier recipes.

Each primary guide independently qualifies its product identifier, DAW USB interface, absolute controls and temporary DAW mode. Launch Control3 uses product22 and16 encoders. XL3 uses product21,24 encoders and eight faders. Both surface diagrams were visually reviewed. The other stated protocol contracts were checked as extracted text. Startup enters DAW Control2, selects absolute encoder rows and disables touch reports. XL3 also disables hardware fader pickup so the app owns pickup. These feature settings are temporary. No saved custom mode, global MIDI channel, brightness, DIN route or audio route changes.

The native app assigns adjacent column pairs to A/B/C/D. Each pair has Play/held Cue. Launch Control3 encoders control high/mid/low/gain. XL3 adds filter and level encoders, paired level/gain faders, Sync/Load and library navigation. C/D retain the existing opt-in. Encoder value feedback uses channel16. Button colours use channel1. Load lamps stay inactive because the app has no matching feedback state. Shutdown clears every native transport button and exits DAW mode. The bounded startup-abort contract now also permits this explicit accessory protocol. Failed setup never enables input.

The source-local decoder follows CC30 on channel7. Custom or unknown modes suspend input. Returning to DAW Mixer1 or Control2 resumes it. Every changed mode retires held actions and pickup, including a change between the two supported DAW modes. Shift has its own source-owned cleanup. Exact0/127 button CCs become logical notes before binding lookup. This retains first-press handling and duplicate/release ownership without changing generic CC-button rules. Other values and raw notes do not trigger those buttons.

Validation:276 source checks and38 native checks passed, including170 automatic held-Cue profiles. Tests cover both independent identities/products, strict DAW ports/channels, ambiguous or missing outputs, every native mixer/transport target, library functions, pickup and mode reset, source-owned mode/Shift cleanup, C/D opt-in, button colours and encoder values, failure at every startup step, shutdown and finite synced real-WAV playback through the actual byte decoder. Existing APC40, Korg setup and XDJ-AN decoder regressions pass. The iPad framework compiled and its bundled resource matches the source. All299 earlier recipes remain identical. The retained first run exposed the generic CC first-press guard and test helpers that bypassed mode decoding. Both are corrected at their own boundaries. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r405/validation.json`.

The catalogue has301 recipes and561 records for554 physical models. Automatic core coverage is209 models, with345 still without automatic core and215 first-protocol gaps. Full theoretical support remains0/554. Legacy Launch Control/XL factory inputs, complete modern modes/screen/state/lifecycle/feedback, further OS port-name variants and physical/iPad/A10X acceptance remain open.

## R406 original Launch Control template reader

Assumption: select User template1 temporarily and read its existing assignments through the manufacturer editor's public query. Give physical control positions native app functions. Read other User templates on selection. Suspend input for Factory templates, whose fixed addresses are not qualified. Keep saved raw mappings ahead of this automatic profile. Do not write or reset stored templates.

- [x] Pin the independent original protocol and manufacturer editor member.
- [x] Read bounded current User-template replies, normalise unambiguous wires/ranges and retire holds on template changes.
- [x] Verify malformed/stale/duplicate data, channel/range/button behaviour, Shift, C/D, raw mappings, failures and real audio.
- [x] Run focused checks, compile the iPad framework and preserve all301 earlier recipes.

The independently pinned original programmer guide qualifies template selection and change notifications. Page7 was visually reviewed. The public manufacturer editor independently supplies the read query121, exact177-byte reply119,16 six-byte knob records and12 six-byte button records. Only protocol facts were read. The editor and its MIDI actions were not executed or copied. Startup selects User template1 and requests its existing data. No stored data, template reset, firmware or feedback write is sent. The app does not restore an arbitrary previous selected template.

The bounded reader accepts only the selected User-template reply. It validates the original product10 header, exact length, seven-bit data, channels, record types and reserved fields. It counts all wires before enabling controls, including inactive controls, so a duplicate cannot trigger another physical function. Limited and reversed knob ranges retain physical direction. Momentary Note/CC buttons become logical notes with exact configured press/release values. Toggle buttons, constant ranges, unsupported records and zero-velocity Note presses stay inactive. User-template changes retire source-owned holds, Shift and pickup, then request that template. Stale replies stay inactive. Factory templates suspend input without a query.

The native40-input app layout follows physical positions: four adjacent pairs target A/B/C/D. Knobs control high/mid then low/gain. Pads provide Play/held Cue. Right arrow is native Shift, with Load/PFL on the pads and level on the gain knobs. Up/Down browse tracks; Left opens a group. C/D retain opt-in. Existing saved raw mappings keep priority until explicit profile replacement. A failed read or missing paired output leaves native input inactive. No response timeout or automatic retry is claimed.

Validation:278 source checks and50 native checks passed, including171 automatic held-Cue profiles. Tests cover every reply split boundary, running status, custom channels and reversed/limited ranges, stale/foreign/malformed/oversized data, duplicates and inactive types, all User/Factory template transitions, native mixer/transport/Shift/navigation, source-owned holds, C/D, each setup failure, raw mapping retention/capacity and real-WAV Sync through actual byte decoding. Earlier DAW/Korg/XDJ-AN regressions pass. The iPad framework compiled and its bundled resource matches the source. All301 earlier recipes remain identical. The retained first native run had one incorrect fixture count, corrected from21 to22 enabled controls. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r406/validation.json`.

The catalogue has302 recipes and561 records for554 physical models:210 automatic core and344 without it. First-protocol gaps fall to214. Full theoretical support remains0/554. Factory templates, complete feedback/state/lifecycle/timeout recovery and physical/iPad/A10X acceptance remain open. The separate legacy XL schema is now recovered from the current public Novation Components bundle for the next independent implementation.

## R407 legacy Launch Control XL template reader

Assumption: use the manufacturer-supported MK1/MK2 family protocol and public Components read format. Select User template1 temporarily and read its existing assignments. Keep Factory/HUI/modern XL3 protocols separate. Give physical positions native app functions, with no stored-template or colour write.

- [x] Pin the independent XL guide and public Components schema.
- [x] Reuse bounded template handling with explicit model-specific sizes, record groups and product IDs.
- [x] Verify all native controls, ranges, stale/malformed/cross-model replies, source-owned Shift/template cleanup and real audio.
- [x] Run focused checks, compile the iPad framework and preserve all302 earlier recipes.

The independently pinned legacy XL guide qualifies product17, template selection and notifications. Page8 was visually reviewed. Novation's current public Components1.72.5 bundle independently qualifies the417-byte read reply, query121 and exact group offsets:24 pots at0, eight faders at144,16 buttons at192, four menu buttons at288 and four arrows at312. Each control has a six-byte record. The final72 bytes hold pot LED settings and do not become controls or hardware writes. The manufacturer's combined download page explicitly covers MK1/MK2. The public bundle was read without executing the app or copying its MIDI actions.

The reader now takes an explicit model. Original remains product10/177 bytes/16 continuous and28 total records. XL uses product17/417 bytes/32 continuous and56 total records. Both share bounded framing, requested-template ownership, duplicate checks, range normalisation and momentary button handling. Cross-model replies stay inactive. The XL profile temporarily selects User template1 and reads existing data. Other User selections trigger reads; Factory selections suspend input. There is no stored-template, HUI, XL3 DAW, LED-colour or audio write.

The native60-input XL app layout uses four adjacent column pairs. Pot rows control high/mid, low/filter and gain/level. Fader pairs also control level/gain, with independent pickup for each physical control. Top buttons provide Play/held Cue; bottom buttons provide Sync/Load. Device/Mute/Solo/Record Arm provide A/B/C/D PFL and Shift+key lock. Right arrow is native Shift, Up/Down browse tracks and Left opens a group. Template/Shift changes retire source-owned holds and pickup. Existing raw mappings keep priority and C/D retain opt-in.

Validation:280 source checks and57 native checks passed, including172 automatic held-Cue profiles. Tests cover every XL reply split, all record groups, exact products/sizes/channels, stale/malformed/oversized data, cross-group collisions, inactive types, ignored LED-tail data, reversed fader ranges, all native targets, independent pickup, template/Shift/source ownership, C/D, each setup and later-read failure, saved raw mapping retention/capacity and finite synced real-WAV playback. All original/modern Launch Control and selected Korg/XDJ regressions pass. The iPad framework compiled and its bundled resource matches the source. All302 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r407/validation.json`.

The catalogue has303 recipes and561 records for554 physical models:211 automatic core and343 without it. First-protocol gaps fall to213. Full theoretical support remains0/554. Factory/HUI modes, complete feedback/state/lifecycle/timeout recovery and physical/iPad/A10X acceptance remain open. MK1/MK2 remain one manufacturer-supported wire family in the established catalogue count.

## R408 remaining Akiyama public facts

Assumption: expose manual A/B normal-mode subsets for Pulsar and Tempus from each separate public factory XML. Use held Shift only with the documented Hold setting. For Syncron, use only the eleven mixer controls common to the two independent public mappings. Do not guess disputed transport, jog, pitch, mode or audio behaviour.

- [x] Pin and reconcile selected wires in each public source.
- [x] Add manual profiles without hardware writes or automatic selection.
- [x] Verify native controls, channels, Shift/hold ownership, pickup, disputed-wire rejection and finite synced audio.
- [x] Run focused checks, compile the iPad framework and preserve all303 earlier recipes.

Separate pinned Pulsar and Tempus XML members qualify the same selected normal-layer A/B wires. Each file was reviewed independently. Native retains Play/held Cue, Sync/Load, key lock/PFL, manual loops, four Hot Cues, held bends, five strip controls, crossfader and headphone blend/level. Shift45 appears on both side channels in the factory unused-control declarations. Native requires Hold mode, composes both physical inputs and retires source-owned holds. C/D and alternate commands remain inactive. These45-input profiles require manual selection and explicit hardware channel/mode setup.

For Syncron, the ProMixer XML and independent DEX script agree on five mixer wires per deck and crossfader48 on centre channel5. Native retains only those eleven absolute controls with independent pickup. The sources disagree on Sync96/33, loop In/Out0/2/3 and the headphone51 versus multi-byte jog interpretation. Those rows and all Syncron transport/Shift/pads/jog/tempo remain inactive. Software virtual commands above127 are not converted into MIDI. No sibling address, sensitivity value or calibration is inferred.

All three subsets remain manual, with no startup, shutdown, feedback, stored-preset or audio-route write. Public factory documents and script facts were read without running the installer, app or downloaded MIDI actions. This is partial control support. It does not establish full hardware function or automatic zero-config operation. The cached Pulsar manufacturer table corroborates selected normal wires, but its full bytes and page image were not recovered. No Tempus manufacturer chart is claimed from the separate software XML.

Validation:282 source checks and18 native checks passed, including172 automatic held-Cue profiles and earlier Akiyama chart regressions. Tests cover manual-only activation, no writes, exact A/B controls, both Cue releases, duplicate/source ownership, composed Shift, strict channels, per-control pickup, rejected disputed Syncron traffic and finite synced real-WAV playback for all three models. The iPad framework compiled and its bundled resource matches the source. All303 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r408/validation.json`.

The catalogue has306 recipes and561 records for554 physical models. Automatic core coverage stays211, with343 without it. First-protocol gaps fall to210. Full theoretical support remains0/554. Configurable modes/channels, complete transport/feedback/lifecycle/calibration/audio and physical/iPad/A10X acceptance remain open.

## R409 original MIXDECK USB-MIDI subset

Assumption: use the original model's independently pinned public factory wires. Follow the manufacturer MIDI software layout for Play/Pause, Pause-to-Cue-set and1/4/8-beat trigger buttons. Keep its analogue mixer outside the MIDI profile. Require manual selection and USB-MIDI deck mode. No Express or Quad protocol or calibration is inherited.

- [x] Pin and visually review the original manufacturer MIDI/mapping notes and separate factory XML.
- [x] Add the bounded manual A/B deck subset without hardware writes.
- [x] Verify Cue releases/source ownership, Cue-set, fixed loops, browsing, strict channels, unqualified-wire rejection and real audio.
- [x] Run focused checks, compile the iPad framework and preserve all306 earlier recipes.

The original manufacturer v1.6 guide explicitly excludes the analogue mixer and iPod from MIDI. Its MIDI software notes use Play as Play/Pause, Pause as Cue-set, Track for browse/load and Back for group navigation. Trigger buttons1/2/3 set1/4/8-beat loops. Pages12/13 were visually reviewed. The separate public original ProMixer XML supplies the selected raw A/B channels and addresses. No Express/Quad address, lamp rule or calibration is inherited.

The32-input manual app layout retains Play/held Cue, Cue-set, Sync/key lock, held bends, manual loop boundaries, native Reloop, fixed loop pads and both browse/load/group controls. Browse accepts only exact1/127 steps. The native Reloop/toggle function follows the app's existing loop behaviour. Unqualified jog/contact/pitch, time/FX knobs, additional modes and lamp values74/75 stay inactive. Virtual pitch numbers224/225 do not become raw controller numbers. The profile has no hardware write, feedback or automatic audio assignment. Decks require USB-MIDI mode and manual profile selection. Separate external deck audio routing remains unavailable.

Validation:284 source checks and16 native checks passed, including172 automatic held-Cue profiles and existing Express/Quad regressions. Fixtures cover the original identity, strict A/B targets, both Cue releases, duplicate/source ownership, Cue-set, bends, loop arguments, exact browse steps, rejected unqualified wires and finite synced real-WAV playback. Cue-set retains playing state and the loop pad enables the expected native loop. The iPad framework compiled and its bundled resource matches the source. All306 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r409/validation.json`.

The catalogue has307 recipes and561 records for554 physical models. Automatic core coverage stays211, with343 without it. First-protocol gaps fall to209. Full theoretical support remains0/554. Complete modes/feedback/lifecycle/calibration/audio, desktop/iPad driver behaviour and physical/A10X acceptance remain open. The current public Zomo support page also yielded its official factory TSI archive and manual for the next independent review.

## R410 MC1000 four-channel native transport

Assumption: use MIDI Channel switch1 and the four independently qualified deck channels. Give normal Play/Sync, three Hot Cues, Loop, paddle and filter controls native app functions. Use the paddles for0.1% tempo steps. Do not infer Load-bank state or execute manufacturer mapping actions. Release guards must rearm buttons after physical deck/Shift changes without another action.

- [x] Pin the manufacturer TSI/manual and cross-check raw wire addresses independently.
- [x] Add the automatic native transport subset and source-local deck/Shift release guards.
- [x] Verify four targets, C/D opt-in, every guarded release, strict encoders/channels, pickup and real audio.
- [x] Run focused checks, compile the iPad framework and preserve all307 earlier recipes.

The manufacturer factory TSI independently qualifies wire channels0/1/2/3 for A/B/C/D and both normal/Shift signal families. The existing bounded TSI inspector reads its raw bindings without executing Traktor actions. An optional cached-source test confirms every native note/control wire and both shifted continuous-control families in the manufacturer file. The manual qualifies the physical Channel switch, deck selection, loop, filter and paddle functions. Pages14/36 were visually reviewed. Other stated sections were checked as extracted text.

The native app has42 controls: Play/Sync, three Hot Cues, Loop,0.1% tempo up/down, filter and loop-size per deck, plus track browse/open. There are96 additional release-only bindings for normal/Shift releases across the same physical side's deck banks. They rearm a button without another action. Positive alternate commands stay inactive. The native paddle assignment is a tempo step, not a claim of complete source Bend behaviour. C/D retain opt-in. MIDI Channel switch1 is required; other positions remain inactive.

A small typed decoder observes only qualified per-deck controls. It tracks bank and Shift separately for each physical side, leaves raw MIDI unchanged and clears source-owned pickup/button state before a changed context reaches binding lookup. Global navigation cannot select a bank. Late releases from an old bank cannot select it again. The connection clears only A/C or B/D, preserving the other physical side and other sources. Decoder state clears with the existing stop/disconnect/protocol-reset lifecycle.

The manufacturer TSI puts global Load9/25 on channel0 with multiple software deck targets. The current inspector does not qualify those bank conditions, so Load stays inactive. ProMixer uses channels4/5, while the DEX file has conflicting Load and duplicate CC cases. Neither extends the manufacturer four-channel contract. No mapping action, private SDK, hardware setup, stored preset, feedback or audio route is written. Recognition still depends on the reviewed device names and a visible CoreMIDI source.

Validation:287 source checks and51 native checks passed, including172 automatic held-Cue profiles and existing Launch Control regressions. Fixtures cover all four targets, every normal/Shift/cross-bank release form, late/global packet isolation, source and side ownership, filter pickup after bank/Shift changes, strict loop/browser steps, C/D opt-in, unsupported Load/FX/channel inputs and finite synced real-WAV transport/loop/tempo playback. The iPad framework compiled and its bundled resource matches the source. All307 earlier recipes remain identical. The final setup text was simplified and the consuming checks reran against that resource. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r410/validation.json`.

The catalogue has308 recipes and561 records for554 physical models:212 automatic core and342 without it. First-protocol gaps fall to208. Full theoretical support remains0/554. Load-bank conditions, complete FX/Shift/Bend/hold modes, feedback/state/lifecycle/audio, other channel-switch positions, OS driver/port behaviour and physical/iPad/A10X acceptance remain open.

## R411 independent legacy USB player defaults

Assumption: use each manufacturer's own default channels1/2/3 and normal MIDI layer. Give the qualified controls native app functions. Require both deck selectors in MIDI/PC mode and MIDI mixer mode. Keep jog/tempo calibration, alternate positive commands and automatic audio routing inactive. The two manuals differ in Shift, Load and lamp details; third-party presets do not override either table.

- [x] Pin and visually review both manufacturer MIDI tables and the independent DMC factory TSI.
- [x] Add automatic normal-layer cores, release guards, owned lamps and source-local pickup context handling.
- [x] Verify strict channels, both Cue release forms, late releases, Shift pickup, source ownership and real audio.
- [x] Run focused checks, compile the iPad framework and preserve all308 earlier recipes.

Each manufacturer table was checked separately. Both use default MIDI channels1/2/3 for A/mixer/B, note127/0 switches and64-centred relative encoders. PDF pages37/38 of the VERSADECK manual and18/19 of the DMC v2.0 manual were visually reviewed. Other listed pages were read as extracted text. The separate DMC factory basic TSI corroborates the overlapping input wires. The public ProMixer files contain conflicting channels/zero addresses and do not extend either manufacturer's default contract.

Each automatic native layout has48 controls,30 release-only guards and16 feedback bindings. Normal Play/held Cue, key lock, held bends, four Hot Cues, manual loop In/Out/Reloop, Track push Load, Folder push Open and both relative browsers are qualified. Five mixer controls per deck and four centre controls retain pickup. DMC Load Track13 also loads. The VERSADECK lamp button13 instead controls app PFL as an explicit native assignment. Neither model infers Sync from TAP. DMC TAP/Shift30 and Database33 differ from VERSADECK Cue Play30 and TAP33; those positive commands stay inactive.

The typed observer leaves MIDI unchanged and tracks only the reviewed normal/Shift families on channels0/1/2. A qualified positive or continuous wire change clears that source's held controls and pickup on the affected channel before binding lookup. Late releases cannot select a layer. Alternate release bindings rearm normal buttons and release owned Cue/bends without an alternate positive command. Shift alone does not select an app layer. The next qualified changed wire performs cleanup. Stop/disconnect/manual-protocol removal clear observer state. Other decks and sources retain ownership/pickup.

Feedback uses Play, Cue, key lock, loop state on the Reloop lamp and four red Hot Cue lamps per deck. VERSADECK red Hot Cue value1 differs from the DMC dedicated red value127. Green lamps and separate loop In/Out lamps stay inactive. Initial validation rejected unsupported loop In/Out/Reloop action names in feedback; the supported app loop-state action now drives the Reloop lamp. The failed run is retained. Both hardware selectors require MIDI/PC mode, default channels and TAP Hold; DMC mixer mode must be MIDI. There is no mode/preset/firmware write or automatic audio assignment.

Validation:290 source checks and22 native checks passed, including174 automatic held-Cue profiles and MC-1000 regressions. Fixtures cover default identities/channels, both Cue release forms, every alternate release, duplicate/source ownership, late release isolation, per-channel Shift pickup, multi-step browser deltas, rejected unqualified controls, independent lamp colours and finite synced real-WAV Cue/transport/manual-loop playback. The iPad framework compiled and its bundled resource matches the source. All308 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r411/validation.json`.

The catalogue has310 recipes and561 records for554 physical models:214 automatic core and340 without it. First-protocol gaps fall to206. Full theoretical support remains0/554. Jog/touch/tempo calibration, full alternate/FX/kill/pad modes, configurable channels, displays/meters, lifecycle/audio ownership, OS behaviour and physical/iPad/A10X acceptance remain open.

## R412 independent TOUR1 primary mixer bus

Assumption: use the TOUR1's own Version1.00 table on manually selected MIDI channel1 and BUTTON TYPE TOGGLE. Map physical CH1-4 to native A-D with C/D opt-in. Keep separate app audio and use only the primary headphone controls. Do not infer V5, second-bus, feedback or hardware audio ownership.

- [x] Pin and visually review the manufacturer table, including selector footnotes and both headphone buses.
- [x] Add the manual32-input mixer with24 source-selector pickup reset messages.
- [x] Verify direct Cue state, all strips/globals, selector/channel/source isolation, C/D opt-in and real audio.
- [x] Run focused checks, compile the iPad framework and preserve all310 earlier recipes.

The current manufacturer TOUR1 manual page links the Version1.00 MIDI addendum. Its direct URL returned404 through curl. The browser document viewer displayed all four pages and its Download button supplied the pinned PDF. Pages2/3/4 were visually reviewed. No account, EULA, private SDK or downloaded program was required. The independent table qualifies all32 native controls and the24 source-selector messages. No900NXS2/2000/V5 table is substituted.

The manual primary-bus layout maps each physical CH1-4 to A-D gain, high/mid/low EQ, Color/filter, channel level and direct CC PFL state. C/D retain opt-in. Master, crossfader and primary headphone level/blend use their own absolute CC addresses. MIDI channel1 and BUTTON TYPE TOGGLE must be selected manually; no factory default is inferred. Each positive input-selector message resets pickup only for that source's affected strip. The table explicitly sends old selection OFF and new selection ON, so old releases do not reset pickup. Second-headphone Note1..4 and CC126/127, auxiliary/master/Link Cues, booth, curve/assign switches, touchscreen, PRO DJ LINK, FX/X-PAD and microphone remain inactive. X-PAD touch and Beat FX ON/OFF share CC114 and are not conflated. There is no output, setting write or automatic audio assignment.

Validation:292 source checks and17 native checks passed, including174 automatic held-Cue profiles and VERSADECK/DMC regressions. Fixtures cover every strip/global, direct Cue state and duplicate packets, all24 positive selector resets, old OFF isolation, source/strip/channel isolation, C/D opt-in, rejected second-bus/FX/sibling controls and finite synced real-WAV mixer playback. The iPad framework compiled and its bundled resource matches the source. All310 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r412/validation.json`.

The catalogue has311 recipes and561 records for554 physical models. Automatic core stays214, with340 without it. First-protocol gaps fall to205. Full theoretical support remains0/554. Full modes/feedback/lifecycle, physical taper/calibration, hardware/software audio ownership, external deck outputs and physical/iPad/A10X acceptance remain open. The separate V5 manufacturer manual and current support pages were also checked. Its MIDI FAQ links the Software Information section, but that current section lists only rekordbox, Serato and OS information. The V5 byte table remains unrecovered; its three-channel/four-band controls are not inferred from another model.

## R413 independent Citronic MPX10 default MIDI core

Assumption: qualify the original MP-X10 against its own Version3.0 manufacturer manual. Reuse the existing normal/Shift observer only for the independently matching selected wires. Require PC deck selectors, MIDI mixer mode, default channels1/2/3 and TAP Hold. Use the lamp button for native app PFL. Keep full FX/Shift, jog/tempo calibration and automatic audio routing open.

- [x] Pin and visually review the independent MIDI table and mixer-mode requirements.
- [x] Add the automatic48-control core with30 release guards and16 qualified lamps.
- [x] Verify all existing USB-player scenarios against this model and retain all311 earlier recipes.
- [x] Run focused source/native checks and compile the iPad framework.

The original MP-X10 Version3.0 manufacturer manual was recovered from a public retailer mirror. Its MIDI pages20/21/22 were visually reviewed, and mode/default and encoder sections were read as extracted text. The selected normal/Shift input families independently match the existing bounded USB-player observer. The separate Citronic recipe therefore reuses that observer and the qualified native48-control layout with30 release guards and16 lamps. It retains its own identity, mode text and source digest. No earlier recipe changes.

The lamp button13 controls app PFL. Dedicated red Hot Cue lamps use127; the separate green Note48..51 family stays inactive. Those output colour/address rules differ from VERSADECK and DMC. Both deck selectors must be PC, MIDI channels1/2/3 and TAP Hold must be selected, and Mixer Setup must be MIDI. The manual's default Mixer setting keeps its own hardware mixer active and does not establish software mixing. There is no setup/preset/firmware write or automatic audio route. Full Shift/FX/kill/pad functions, jog/touch/tempo calibration, display/meters, lifecycle and audio ownership remain open.

Validation:292 source checks and17 native checks passed, including175 automatic held-Cue profiles, all three USB-player model cases and TOUR1 regressions. Every existing USB-player fixture now also checks Citronic Cue releases, all alternate release guards, source/channel ownership, Shift pickup, strict browser values, independent feedback and finite synced real-WAV transport/manual-loop playback. The iPad framework compiled and its bundled resource matches the source. All311 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r413/validation.json`.

The catalogue has312 recipes and561 records for554 physical models:215 automatic core and339 without it. First-protocol gaps fall to204. Full theoretical support remains0/554. The ProMixer MPX10, DJINN and Syncron documents are byte-identical and conflict with the primary default table, so they do not qualify sibling reuse. The original DJinn manufacturer-authored manual is readable as cached text, but its PDF download returned403 and was not bypassed. It remains a separate gap. The original Digital Jockey manufacturer manual was recovered for the next independent public-fact review.

## R414 independent AMX iCUE and original Digital Jockey subsets

Assumption: transcribe only the model-specific public factory addresses. Keep all three profiles manual, with separate app audio. AMX uses its normal layer and owned Shift cleanup. The original Digital Jockey keeps the same native A/B transport/mixer functions on both independently listed hardware signal families. Its native Play toggles, and its native Auto Loop/Reloop use app loop behaviour. Do not infer original Attack stutter/Pause semantics, jog/tempo calibration, unknown encoder values or iCUE crossfader polarity.

- [x] Pin each factory XML and the original Digital Jockey manufacturer manual.
- [x] Add bounded manual subsets without hardware writes or sibling protocol reuse.
- [x] Verify both Cue releases, cross-family releases, Shift/source ownership, strict mixer pickup and real audio.
- [x] Run focused source/native checks, compile the iPad framework and preserve all312 earlier recipes.

Each model's visible factory XML was pinned and read separately. Only raw address facts were transcribed; no downloaded code, installer, mapping action, preset or hardware setting runs in the app. Optional cached-source checks verify every native wire against its own document. None of the profiles selects automatically or assigns audio. No AMX/AFX, iCUE/Total Control or original/Digital Jockey2 compatibility is inferred.

AMX has32 manual inputs: five normal transport/PFL/load buttons per deck, ten shifted release-only guards, five seven-bit strip controls per deck, crossfader and global Shift. Shift0 retires only source-owned Cue and resets normal control pickup. Unsupported shifted positive commands stay inactive. Generated pitch numbers160/161 do not wrap to raw controllers. Touch, FX, library, precise pairs and higher-resolution behaviour remain unqualified.

iCUE has30 manual inputs: Play/held Cue, Sync/key lock/PFL, held bends, manual loops/load and five mixer controls per deck. The publisher's own setup page says iCUE is MIDI-only and requires a separate soundcard choice. Its crossfader is marked CtrlI without an independently qualified direction contract; the two HeadMaster addresses15/23 are ambiguous. Those globals, separate Pause, browser rotation, sampler/FX and jog/tempo remain inactive.

The original Digital Jockey has118 bindings. Its own manufacturer manual confirms that held Shift doubles MIDI functions and explains the transport/mixer. Pages41/42 were visually reviewed. Its unique factory XML separately lists both A/B signal families. Native deliberately keeps the same transport and mixer functions on both families, with48 release-only guards. Releases on either family rearm both button states and release the same physical Cue/bend owner without another action. Two manual sources use236 of the256-binding limit. Native Play toggles, and Auto Loop/Reloop use existing app behaviour. Original Attack stutter and independent Pause are not emulated. Unqualified relative browser values, contact/jog/tempo, kills, sampler/FX and virtual pitch remain inactive.

Validation:294 source checks and18 native checks passed, including175 automatic held-Cue profiles and all three legacy USB-player regressions. Fixtures cover explicit identities, manual activation/capacity, both Cue releases, duplicate/source ownership, stop cleanup, AMX Shift suppression/pickup, all original Digital Jockey cross-family button releases, independent transport targets and selected mixer pickup, strict channels, rejected ambiguous controls and finite synced real-WAV transport for each new model. The iPad framework compiled and its bundled resource matches the source. All312 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r414/validation.json`.

The catalogue has315 recipes and561 records for554 physical models. Automatic core stays215, with339 without it. First-protocol gaps fall to201. Full theoretical support remains0/554. Full modes/state/feedback/lifecycle, calibration, audio ownership, OS behaviour and physical/iPad/A10X acceptance remain open.

## R415 independent HC1000S and HC4500 manufacturer MIDI cores

Assumption: use each unit's own manufacturer MIDI table. HC1000S gets a native five-Hot-Cue layout with Shift transport and all four documented MIDI channels. HC4500 keeps its two physical players as A/B across all three documented channel pairs, in PC/HC4500 MIDI mode. Its pitch slider uses app range. Keep jog calibration, full displays/modes/audio and sibling HID protocols separate. Read-only source inspection must not write presets or run vendor programs.

- [x] Pin and visually review the independent input, LED and mode/channel tables.
- [x] Add bounded automatic cores and existing native lamp-trigger encoding.
- [x] Verify pressure64, both Cue releases, channel/Shift/source cleanup, strict encoder/pitch values, lamps and real audio.
- [x] Run focused checks, compile the iPad framework and preserve all315 earlier recipes.


Each manufacturer document was pinned and read independently. The HC1000S input/LED columns and HC4500 command pages1/2 were visually reviewed. HC1000S has244 inputs and48 lamp bindings across all four channels. It keeps five normal Hot Cues and uses Shift for native held Cue, Play, Sync, Load and PFL. The same source-owned Shift identity accepts release on another documented channel; either edge retires owned holds. HC4500 has96 inputs and42 lamp bindings across all three channel pairs, each controlling the same physical A/B players. Its own manual establishes PC source, HC4500 MIDI mode and configurable jog pulses. Native leaves jog/contact inactive and maps the pitch slider to app range with exact centre8192 and independently documented reverse direction.

Both devices use pressure64 buttons, strict0/127 encoders and their own lamp identifiers. Lamp-on uses CC74 and lamp-off uses CC75, with the identifier in data2. No preset, firmware, hardware mode or audio route is written. HC1000S normal Hot Cue/loop lamps retain those states during native Shift transport. Full modes, displays/feedback/lifecycle, calibration, audio/OS behaviour and physical/iPad/A10X acceptance remain open. The separate manufacturer guides identify Numark DMC2 and Denon HC5000 as HID devices; neither inherits these MIDI profiles.

Validation:296 source checks and13 native checks passed, including176 automatic held-Cue profiles, both pressure64 release forms, channel/Shift/source ownership, strict encoders and pitch pickup, independent lamp triggers, raw schema decoding and finite synced real-WAV transport. The iPad framework compiled and its bundled resource matches the source. All315 earlier recipes remain identical. A missing required lamp schema field caused the initial native run to fail; the definition was corrected and all three checks reran. Failed logs remain in the evidence record. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r415/validation.json`.

The catalogue has317 recipes and561 records for554 physical models:217 automatic core and337 without it. First-protocol gaps fall to199. Full theoretical support remains0/554.

## R416 recovered NVII PRIME GO plus and DP2 facts

Assumption: use the named NVII and PRIME GO+ public factory documents as separate manual MIDI subsets. Do not copy USB identifiers, infer sibling startup or claim complete USB/audio operation. DP2 uses its own manufacturer manual and public device definition. Native keeps normal transport, with source-owned Shift cleanup and release guards. Keep unresolved jog/pad/screen/FX behaviour inactive.

- [x] Pin the public software bundle and each independent definition; review disputed rows.
- [x] Add bounded profiles with explicit identity, channel, Shift and selector contracts.
- [x] Verify both Cue releases, bank/Shift/source ownership, mixer pickup, strict encoders, lamps and real audio.
- [x] Run focused source/native checks, compile the iPad framework and preserve all317 earlier recipes.


The public UltraMixer6.4.11 archive contains100 mapping documents. Only document resources were read; no installer, app, class, script or source action ran. The archive/JAR and selected XMLs are pinned. The GO and GO+ bodies are identical, and several unrelated products share their copied USB identifier. NV and NV2 bodies are also identical. These facts do not qualify sibling startup or USB/audio compatibility. Native therefore adds separate manual77-input NVII and45-input GO+ definitions with explicit model exclusions. It ignores copied USB identifiers and ambiguous globals. NVII uses its own CC29/30 side-selector reports, with0/1 kept as separate disjoint triggers. Repeated or wildcard-overlapping trigger definitions remain invalid. Two independent physical Shift identities accept A/C and B/D channel aliases. GO+ browser and loop-size encoders accept exact1/127 only; its ambiguous CC12/13 globals and incomplete pitch representation stay inactive.

DP2 uses its own manufacturer manual and public Atomix device definition. MIDI chart page12 was visually reviewed. Native has108 inputs and18 steady lamp recipes. Its two physical Shift inputs accept normal0/1 and alternate3/4 channels. Both source-owned holds and pickup clear at Shift edges, and alternate positive transport stays inactive. All15 normal buttons per deck have normal-Shift and alternate-channel release guards. Native includes four Hot Cues, manual loops, held bends, pitch position, the two-band mixer, library and qualified globals. Manufacturer High20/Low21 and separate Mic0/19 versus Master1/19 override conflicting third-party rows; no mid EQ or gain is invented. Pitch follows app range. Jog/contact calibration, full auto-loop/sampler/FX/modes/feedback/lifecycle, audio/OS and physical/iPad/A10X acceptance remain open.

Validation:298 source checks and12 native checks passed, including177 automatic held-Cue profiles, manual activation/capacity, all four NVII targets, strict selector/encoder values, independent Shift aliases, both Cue release forms, alternate-channel release guards, source ownership/stop, manufacturer mixer/pitch pickup, steady lamps and finite synced real-WAV playback for each new model. The initial native run exposed the disjoint-selector schema limit; a focused failing fixture established it, and the source was corrected before all affected native/framework checks reran. The iPad framework compiled and its bundled resource matches the source. All317 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r416/validation.json`.

The catalogue has320 recipes and561 records for554 physical models:218 automatic core and336 without it. First-protocol gaps fall to196. Full theoretical support remains0/554. The copied Synq PCM-1 and partial4TRAK FX documents need separate primary review.

## R417 independent Denon legacy player cores

Assumption: ordinary USB-MIDI mode is the target. Each player uses its own published table. Allocate each physical source to its own app deck and accept the documented channel envelope. Keep Hybrid/DVS, motors, unqualified jog/pitch calibration, screens, feedback and audio routing separate. Mode reports must release only source-owned contacts on the currently assigned deck.

- [x] Pin and visually review each independent command table.
- [x] Add bounded automatic player profiles and assigned-deck mode cleanup.
- [x] Verify all channel envelopes, pressure64 and both releases, assignment/source ownership, strict browser values and real audio.
- [x] Run focused checks, compile the iPad framework and preserve all320 earlier recipes.


Each independent manufacturer table was pinned. SC2900 PDF42, SC3900 PDF39, S3700 command pages1/2 and S1200 command page1 were visually reviewed. The catalogue retains S3900 as its inventory name with explicit SC3900 aliases. Native has21 inputs for each SC model,16 for S3700 and10 for S1200. Each physical source selects automatically and receives its own app deck. Inputs accept the published raw channel envelope0..15, pressure64 and both Note Off forms. Browser accepts exact0/127. Every model has Play/held Cue, held bends, A/A1 loop In/B loop Out/Reloop, parameter-push Load and library controls. S3700 adds three Hot Cues, key lock and Auto Loop Set/Exit. SC models independently add eight native Hot Cues, key lock, Auto Loop and Sync107. Normal and Bank2 pad addresses keep fixed native Hot Cue1..8 functions; other Shift/lock functions are not emulated.

Source/preset and independently listed mode reports retire only owned contacts on the player's current assigned deck. Schema checks limit channel-independent context reports to single-player profiles and reject overlapping channel patterns or multiple target decks. Reassignment follows the same ownership rule. Existing mixer/controller context reports retain fixed strip targets. Native makes no setup, preset, firmware, motor, lamp, display or audio write. SC3900 motor/pulse-width and S3700 platter/jog streams remain separate. Hybrid/DVS, unqualified motion/pitch calibration, full modes/state/feedback/lifecycle/audio/OS and physical/iPad/A10X acceptance remain open.

Validation:300 source checks and19 native checks passed, including181 automatic held-Cue profiles, all16 input channels, four assigned sources per model, both pressure64 release forms, strict mode values/library, source-local mode cleanup and button rearming, reassignment to D, rejected motion/pitch and finite synced real-WAV playback for all four models. The same run covers R416 and HC4500 mode-cleanup regressions. A test-fixture type-inference compile failure was corrected without changing runtime behaviour; its log remains in evidence. The iPad framework compiled and its bundled resource matches the source. All320 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r417/validation.json`.

The catalogue has324 recipes and561 records for554 physical models:222 automatic core and332 without it. First-protocol gaps fall to192. Full theoretical support remains0/554. The separate HD2500 table has readable primary web text, but local font loss and unresolved USB mode/channel evidence remain open.

## R418 independent X1600 and PCM1 manual subsets

Assumption: manual selection and separate app audio. X1600 uses channel1 and enabled hardware MIDI layers. Its four parameter/function pages get explicit native A/B/C/D controls. PCM-1 uses its own distributed Traktor input facts; do not inherit DP2 bytes or execute source actions.

- [x] Pin and review the independent primary definitions and mode limits.
- [x] Add bounded manual subsets with owned layer/page/Shift cleanup.
- [x] Verify both Cue release forms, independent page/deck/source ownership, pickup, strict encoders and real audio.
- [x] Run focused checks, compile the iPad framework and preserve all324 earlier recipes.


X1600 uses its own manufacturer MIDI table, printed20/PDF24, visually reviewed. Its manual explains that enabled MIDI layers send external controls, with hardware EQ/fader pickup on return. Native has54 manual inputs: four three-band/fader/PFL strips, crossfader/master and32 parameter/function controls. Pages1/2/3/4 deliberately control native A/B/C/D. FUNC1/2/3/4 give Play/held Cue/Sync/Load, PARAM1 browses with group push, and PARAM2 changes/toggles loops. These are explicit native assignments. They are not claimed manufacturer software actions. Four strip-layer reports reset only their strip. Disjoint preset/page values retire source-owned contacts and rearm page controls. Channel1, enabled hardware MIDI layers, C/D app opt-in and separate app audio are required. Hardware bus/FX/mic/booth/headphone writes and unlisted gain controls are absent.

PCM-1 uses its independently distributed manufacturer Traktor document with156 used rows and94 input rows. The optional cached-source check verifies every native wire against used bindings. Native has50 manual inputs: normal two-deck transport, held Cue/bends, source-inverted pitch, three-band mixer, library and qualified headphone globals. High19/Mid20/Low21 are independent PCM-1 facts; DP2 addresses are not inherited. Shift guards suppress normal positive transport, with owned full-value Shift cleanup and only independently used alternate Cue release aliases on raw channels3/4. Generic USB Audio Device names prevent automatic selection. Unresolved crossfader/master and gain/jog calibration remain inactive. No TSI action, driver, installer, preset, hardware setting or audio command executes.

Validation:303 source checks and12 native checks passed, including181 automatic held-Cue profiles, manual activation/capacity, all four native X1600 page targets, both pressure64 Cue release forms, source ownership/stop, strip/preset/page cleanup, button rearming, independent mixer/pitch pickup, strict browser/loop encoder values, PCM-1 Shift/alternate releases and finite synced real-WAV transport for both models. The first stop fixture counted the separate neutral jog cleanup events; the fixture now checks Cue events specifically. Failed and unchanged-rerun logs remain in evidence. The iPad framework compiled and its bundled resource matches the source. All324 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r418/validation.json`.

The catalogue has326 recipes and561 records for554 physical models. Automatic core stays222, with332 without it. First-protocol gaps fall to190. Full theoretical support remains0/554. Complete modes/feedback/state/lifecycle/audio/OS and physical/iPad/A10X acceptance remain open. Reviewed X1800/X1850 user guides provide no control-address chart; neither inherits X1600 bytes.

## R419 independent public legacy Rane contracts

Assumption: manual selection and separate app audio. Sixty-Two/Sixty-Four use default MIDI Layer1. Preserve Sixty-Four physical C/A/B/D strip order. TTM57mkII keeps its separately documented MIDI channels. Only software-owned lamps may be written. Keep conflicting addresses, hardware mixer writes and unqualified shared pads inactive.

- [x] Pin and visually review each independent MIDI table and ownership rule.
- [x] Add bounded manual mixer/library/loop/pad subsets and owned source pickup cleanup.
- [x] Verify strip targets, encoder counts, source ownership, permitted lamps, rejected conflicts and real audio.
- [x] Run focused checks, compile the iPad framework and preserve all326 earlier recipes.


The three own manufacturer manuals are public and pinned. Their MIDI ownership rules and independent address tables were reviewed. Sixty-Two PDF35 and Sixty-Four PDF38 were visually checked for input/output colour distinctions; TTM57mkII PDF27 was visually checked for its separate general/library channels. No private SDK, vendor program, account, agreement, source mapping action or driver was used.

Sixty-Two has44 manual inputs and14 lamp recipes in MIDI Layer1. Native includes two six-control mixer strips, globals, five Hot Cues per deck, separate manual/auto loop buttons and loop-size encoders, browse/load/group. Other layers use non-sequential MIDI channels1/3/4/5/6 and are not silently aliased. Sixty-Four has83 manual inputs and39 lamps. Its physical strip order is C/A/B/D. Its own alternate bank addresses give fixed native A/B/C/D Hot Cues, Sync/load/library and loop controls. Only31 pads qualify: Note16 is duplicated as Deck3 Trigger6 and FX joystick east, so it remains inactive, including feedback. CC122/123 have conflicting crossfader/layer meanings and remain inactive. Source selectors reset only the matching strip's pickup. Read-only hardware mixer controls are accepted as inputs, but native does not send mixer settings, contour/reverse, hardware Cue/FX or mixer LED writes. Only independently permitted software Hot Cue/Sync/Loop lamps receive primary-full64/off0.

TTM57mkII has24 manual inputs with no output. Its own channels are mixer1/2, loops5/6, general15 and library/crossfader16. Native includes six mixer controls per deck, globals, loop size/toggle and browse/load/group. USB Port Active values1/4/5 clear owned pickup. Cue and Sample modes share pad addresses, with the mode separately reported on channel15 CC58; those pads and their LEDs remain inactive until that mode contract is implemented. Original TTM57 compatibility is not inferred.

Validation:305 source checks and11 native checks passed, including181 automatic held-Cue profiles, manual activation/capacity, every qualified strip/pad target, explicit C/A/B/D ordering, separate library/load channels, source-local pickup resets, forbidden settings/pads and exact permitted lamp packets. Rane loop encoders retain binary-offset counts, including positive/negative five-step reports; TTM57mkII keeps strict65/63 steps. A focused failing schema fixture established the missing loop-encoder encoding before it was enabled. Note-kind and argument-bearing loop encoders still fail validation. Finite synced real-WAV playback with native loop controls passes for all three models. The iPad framework compiled and its bundled resource matches the source. All326 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r419/validation.json`.

The catalogue has329 recipes and561 records for554 physical models. Automatic core stays222, with332 without it. First-protocol gaps fall to187. Full theoretical support remains0/554. Remaining layers, pad/Shift/FX modes, full feedback/state/lifecycle/audio/OS and physical/iPad/A10X acceptance remain open.

## R420 independent CMD modular cores

Assumption: factory MIDI channels and separate app audio. Use the PL-1 manufacturer sheet and pinned model-specific public mappings. DC-1 and LC-1 get explicit native column layouts. No downloaded code runs. Keep undocumented modes, complete rings/meters and physical calibration open.

- [x] Pin independent MIDI addresses, channels, encoder and lamp facts.
- [x] Add bounded default cores with explicit native layouts and PL-1 selector ownership.
- [x] Verify positive selector velocities, both releases, bank/source ownership, relative controls, permitted lamps and real audio.
- [x] Run focused checks, compile the iPad framework and preserve all329 earlier recipes.


The manufacturer PL-1 sheet was pinned and visually reviewed. Its default channel group1..4 controls fixed native A/B/C/D. A separately pinned model-specific mapping provides the wheel/contact address, binary-offset encoders and source scratch scale400. Native has104 inputs and48 steady button lamps: Play/held Cue/Sync/Load, native key lock on Lock, eight Hot Cues per target and contact-gated counts. E1..8 explicitly give gain/high/mid/low/filter/loop-size/library/headphones; E6/7/8 pushes give loop/group/PFL. These are native assignments. Physical jog scale/direction remain open, as do pitch polarity, free spin, Scratch toggle, extra buttons, other channel groups and rings/meters. No unqualified pitch or stored setting is written.

Each positive Deck26 report retires only source-owned Cue and platter contact across the four banks. Selector release preserves fresh contacts in the new bank. The typed any-positive note contract accepts ordinary positive velocities while rejecting control-kind triggers, a simultaneous exact velocity and an implicit unqualified note wildcard. Existing exact-velocity profiles retain their contracts. Contact motion requires that same input source to own the touch, so another controller's touch cannot authorise movement.

The pinned DC-1 and LC-1 ports independently declare raw channels5/7 and their used address arrays. DC-1 has34 inputs/16 lamps: four vertical Hot Cues per A/B/C/D column, relative level/filter rows with Load/PFL pushes, and the library wheel. LC-1 has40 inputs/20 lamps: five selected Hot Cue rows per column, the same explicit native row roles and four library navigation buttons. Only selected used controls qualify; copied comments and unused templates do not. Lamp bytes come from the actual colour conversion, rather than logical constants: DC-1 green1/amber0 and LC-1 green1/fully-off127. Encoder rings and remaining software modes remain open. No old framework or downloaded code runs.

The separate DV-1 mapping is explicitly experimental. Its36-input manual subset uses raw channel6, three qualified relative encoder banks for native A/B/C, eight A/B Hot Cues and Focus library navigation. FX4, other Master/Double/Shift modes and all output remain inactive. It does not select automatically. All four models require separate app audio and retain full modes/state/feedback/lifecycle/OS and physical/iPad/A10X limits.

Validation:307 source checks and16 focused native checks passed, including182 automatic held-Cue profiles, independent identities/channels, manual DV-1 capacity, all qualified column targets, exact feedback packets, relative mixer/browser/loop behaviour, owned contact/raw counts and positive selector velocities1/64/127. PL-1 fixtures cover both Cue release forms, duplicate/source ownership, old-bank release and fresh-bank preservation. Finite synced real-WAV playback passes for all four profiles. Three incorrect DV-1 test labels were corrected; runtime addresses already matched the source. Failed logs remain in evidence, including the earlier run where eight existing CMD Micro regressions passed. The iPad framework compiled and its bundled resource matches the source. All329 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r420/validation.json`.

The catalogue has333 recipes and561 records for554 physical models:225 automatic core and329 without it. First-protocol gaps fall to183. Full theoretical support remains0/554. The old manufacturer CMD asset links returned404; no access restriction was bypassed.

## R421 — Independent 4TRAK main and corrected Xponent cores

The public PCDJ archive contains a separate 4TRAK main-unit mapping. Its142-input manual core covers four deck channels, five Hot Cues each, normal transport and held Cue/bends, coarse pitch, channel0 mixer and library controls. The32 steady lamp recipes use separate CC addresses. Side-selector values0/1 and physical Shift aliases retire owned contacts. The FX bar remains separate. Source startup writes change banks and hardware modes; native sends none. Numark’s own guide requires a driver, so direct iPad attachment and automatic selection remain unqualified.

Xponent has96 manual inputs and14 steady lamps. Manufacturer Appendix A and the independent djay definition establish Shift Note44. The PCDJ script incorrectly treats Note18 as Shift and Note44 as Load. Native uses the manufacturer addresses and never loads a track from Shift. The default-bank core includes five Hot Cues, manual/fixed loops, full pitch-bend position with exact centre, mixer/cue-mix and contact-gated wheel counts at the source300 scale. Pitch direction follows the independent djay definition. Bank B, source scratch/search modes, physical wheel scale, FX, meters and full lifecycle/audio/OS remain open. Public PDF mirrors refused local download; the manufacturer chart was read through the web document service. No restriction was bypassed.

The generator now carries the detailed R416-R420 source records into catalogue definitions. A regression check covers all16 affected profiles. Their runtime objects remain unchanged.

Validation:310 source checks and8 focused native tests passed. Native fixtures cover both Cue release forms, duplicate and cross-controller ownership, exact bank selectors, Shift aliases, manufacturer Shift correction, owned touch/raw counts, pitch/mixer values, strict browse packets and lamp bytes. Both profiles retain finite synced real-WAV playback. The first fixture exceeded the existing256-binding manual limit by applying two complete142-input 4TRAK profiles. The corrected fixture uses4TRAK plus96-input Xponent and verifies all238 bindings. A test-only Int32 inference error was also corrected. Failed logs remain in evidence. The iPad framework compiled; its bundled resource matches the source. All333 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r421/validation.json`.

The catalogue has335 recipes and561 records for554 physical models:225 automatic core and329 without it. First-protocol gaps fall to181. Full theoretical support remains0/554. No SDK, driver or vendor application was installed or executed.

## R422 — Independent American Audio MXR contracts

Each model has its own manufacturer MIDI chart. The10MXR manual core has51 inputs and8 steady lamps, two Hot Cues per side and right Sync54. Its raw input channels0/1 and hardware mixer differ from the larger models. Configure app audio separately to avoid applying hardware mixing twice. No larger-model Controller mode is inferred.

The14MXR and19MXR automatic cores have75/71 inputs and14/10 steady lamps. They require the documented Controller mode, selected by holding its button during power-on. The charts explicitly add2 to input channels while keeping lamp messages on the original channel. Native normal inputs use raw2; raw3 positive Shift commands remain inactive, while release guards retire held controls across both families. Neither profile handles the default hardware Mixer-mode channels0/1. Native sends no mode or stored-setting command. Both models retain three Hot Cues per side and right Sync55.

The four strips use C/A/B/D. Primary mixer/PFL addresses correct the copied fourth-strip EQ target error in the separate PCDJ scripts. The19MXR filters depend on hardware crossfader assignments and remain inactive. Its PFL rows do not identify lamps, so no PFL output is invented. The primary encoder values65/63 establish forward/reverse; the old scripts reverse this direction. Native Shift/source/mode reports retire only owned holds and pickup. Sync pulse output, sampler, FX, mic/booth/assignment controls and full lifecycle/audio/USB/OS remain open.

Validation:312 source checks and9 focused native tests passed, including184 automatic held-Cue profiles, model identities, all four normal/alternate release forms, duplicate/cross-source ownership, correct Sync/mixer targets, strict browse values, source-selector scope, lamp channel/bytes and finite synced real-WAV playback. The first native run caught four non-existent library action names; these now use the existing native browse actions. An individual-definition regression check was added. Failed logs remain in evidence. The iPad framework compiled; its bundled resource matches the source. All335 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r422/validation.json`.

The catalogue has338 recipes and561 records for554 physical models:227 automatic core and327 without it. First-protocol gaps fall to178. Full theoretical support remains0/554. Physical/iPad/A10X acceptance remains open. No vendor application, source script, driver or firmware runs.

## R423 — Independently checked Contour editions

Separate manufacturer guides establish the same default-group MIDI wires for Contour Controller Edition and Interface Edition. One164-input automatic recipe serves both, with48 steady lamps. The catalogue now has separate edition rows. Both retain the original VirtualDJ family reference; the generic family is not counted as a third physical model. The primary source expansion and inventory gate use the same rule.

Default channels0..3 target A/B/C/D. The core includes normal Play/Cue/Sync/Load, eight Hot Cues per deck, native loop toggle/reloop and beat jumps, filter and binary-offset library/loop-size encoders. Shift adds64 to normal addresses. Alternate positive functions stay inactive; release-only aliases handle either release form across both families. Normal47 and Scratch48 wheel/contact families use source-owned touch and source scratch scale150. Physical calibration remains open. Deck-selection reports retire owned holds across all four targets. Normal wheel-mode reports retire only their target; selector releases preserve fresh contacts.

The primary charts correct copied assumptions in the PCDJ script. Note8 selects a shifted deck and is not Key Lock. There is no pitch slider or primary pitch-bend input. Shifted filter/pan controls are not treated as headphone/master knobs. Other wheel modes, no-touch direction notes, custom channel groups, all Shift/FX/pan/EQ functions, alternate lamps/rings and full state/lifecycle/audio/USB/OS remain open. Controller Edition has no audio interface; configure app audio separately for either edition. No source code, startup, channel changer or hardware setting runs.

Validation:314 source checks and8 focused native tests passed, including185 automatic held-Cue recipes, both edition aliases, all normal/Shift Cue release forms, duplicate/cross-source ownership, fresh-bank preservation, deck/mode ownership, contact-gated raw counts, all eight cue targets, relative controls, rejected copied roles and exact lamp packets. Both editions retain finite synced real-WAV playback. The first inventory checks rejected the removed generic row; the source gate and inventory regression now require both edition rows and preserve their source attribution. Failed logs remain in evidence. The iPad framework compiled; its bundled resource matches the source. A metadata-only regeneration produces the same runtime bytes. All338 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r423/validation.json`.

The catalogue has339 recipes and562 records for555 physical models:229 automatic core and326 without it. First-protocol gaps fall to177. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R424 — Independent legacy standalone cores and directional wheel counts

HD2500 has a24-input manual subset and4 Play/Cue lamps. Its own wire chart establishes press64, library0/127, fixed contact and1480-pulse wheel messages, and separate CC74-on/75-off lamp triggers. Its official setup guide requires MIDI source mode, explicitly not PC. The Mac guide identifies DN-HD2500 or generic Inter0; generic names never select this profile automatically. Native raw0/1 map A/B. Other channel pairs and default pairing are not inferred from HC4500. Source/Preset edges retire owned holds. Local chart fonts remain incomplete; the primary web document supplies the table. Pitch direction, complete contact interpretation, displays/presets and full modes/lifecycle/audio/host/OS remain open.

SCS.4DJ has44 automatic inputs and6 Play/PFL/loop-state lamps for its published unmodified map on MIDI channel1. The manufacturer guide requires MIDI Controller Mode, which stops standalone playback. The native core covers transport, held bends, library, mixer/coarse pitch, native loop toggle/reloop/size and fixed touch/platter/rim. Source wheel scale256 remains unmeasured. Ambiguous source Hot Cue claims on Notes5..8, including a crossfader-switch address, remain inactive. Custom maps/channels, full FX/modes/meters/state/lifecycle/audio/USB/OS remain open. A first mirror returned HTML rather than a PDF; that failed evidence was retained and an accessible manufacturer-authored guide was pinned.

FirstMix I/O has31 automatic inputs and8 steady lamps, independently of original FirstMix or Pro. Its manufacturer guide confirms gain/two-band EQ, rotary Pitch, Master and physical headphone volume. Native does not invent channel faders or treat Master18 as cue-mix. Separate left/right wheel addresses carry unsigned movement counts. The new unsignedCount decoder preserves all1..127 counts, ignores0 and rejects foreign kind/number/range. Address inversion supplies direction; owned contact gates movement at source scale350. The schema permits this encoding only for control messages targeting contact-gated jog actions. Manual learning does not offer the specialised encoding. Fixed contact replaces the source software Scratch toggle. Preview/FX, full modes/state/meters/lifecycle/audio/host/OS and physical calibration remain open. The PDF mirror refused access; the public manufacturer guide transcript resolved physical control roles. No restriction was bypassed.

Validation:316 source checks and11 focused native tests passed, including two decoder tests,187 automatic held-Cue recipes, per-definition schema and invalid-use rejection, both Cue release forms, pressure/source ownership, HD2500 mode cleanup, separate directional counts1/64/127, owned contact, independent gain/Master/library roles, rejected SCS pad assumptions and exact lamp packets. All three profiles retain finite synced real-WAV playback. The decoder tests first failed because the encoding was absent; that red run is retained. The iPad framework compiled; its bundled resource matches the source. All339 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r424/validation.json`.

The catalogue has342 recipes and562 records for555 physical models:231 automatic core and324 without it. First-protocol gaps fall to174. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open. No vendor application, driver, firmware, preset or private SDK runs.

## R425 — Independent Xone Map2 axis contracts

Manufacturer guides independently establish18/19/35 manual inputs for Xone1D/2D/4D. Each recipe uses normal Map2 on MIDI channel16 and sends no packets. The native four-column layout assigns gain/high/low/level to A/B/C/D.1D uses CC32..35,8..19 and library37;2D uses40..43,20..31 and library45. Their additional encoders36/44 set native A loop size.2D also has MIDI crossfader5.4D uses both pod families for the same four native mixer targets, two library wheels and crossfader5. The analogue channel-strip controls are not claimed as MIDI. These are explicit native assignments using documented numeric wires.

The guides express buttons as musical notes and their editions use different octave labels. No independently qualified numeric button contract was found in this review. Buttons, Map1 note encoders and all light-pipe output remain inactive.1D can expose generic USB Audio Device/Xone MIDI Device names; those names do not identify one model.2D’s Mac guide requires a driver. Hardware4D Shift moves to channel15, while2D Shift uses different addresses on the same channel. Both alternate families remain inactive. All recipes require manual selection and separate app audio; full buttons/maps/Shift/state/feedback/lifecycle/USB/OS and physical acceptance remain open. No driver, channel/map/light setting, clock or audio route is written.

Validation:318 source checks and8 focused native tests passed, including187 unchanged automatic held-Cue recipes, separate manual identities/capacity, all four native mixer targets, both4D pod families, source-specific pickup, relative gain/library/loop values, rejected generic names/channels/notes/Shift addresses and finite synced real-WAV playback for all three. A fixture initially expected its fixed0.5 lookup to update after a gain event; the corrected check verifies positive and negative changes from that fixed lookup. The runtime mapping did not change. Failed logs remain in evidence. The iPad framework compiled; its bundled resource matches the source. All342 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r425/validation.json`.

The catalogue has345 recipes and562 records for555 physical models:231 automatic core and324 without it. First-protocol gaps fall to171. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R426 — Independent NDX800 and NDX900 player cores

Each model has its own pinned public input definition and manufacturer operating guide. Both manufacturer product pages list class-compliant MIDI and iOS compatibility. This is manufacturer evidence, not a physical acceptance result. Select USB-MIDI with SOURCE/PARAMETER before using the ten-input automatic core. Each connected unit receives its own app player assignment; incoming MIDI channels retain that source-owned assignment. Native controls cover Play/Pause, held Cue/bends, Load, manual loop anchors/reloop, full pitch-bend position with exact centre and strict1/127 browse steps. Pitch follows app range. Configure audio separately; no automatic multi-interface route is inferred from the900 soundcard.

Native does not wrap phantom controller133 or activate zero-number placeholders. The800 manufacturer CUE download supplies software action names, not numeric wire definitions. It separates short Range from held Key Lock and separate Pause from a toggle. Native does not execute its copied MIXDECK refresh action or any other source action. Pause, ambiguous Sync/key-lock/LED commands, jog/contact calibration, conditional pads/record/Hold/FX/browser, displays and complete lifecycle/audio/host/OS remain open. No driver, firmware, mode or stored setting is written.

Source review found a further model difference after the first green checks. The800 selector is a placeholder0/rangeup69;900 explicitly declares real Note69. Only900 therefore resets owned contacts for that selector.800 ignores both selector edges and retains Cue until its qualified release.900 selector release preserves a fresh contact. A source regression now requires every active input and mode reset to exist numerically in that model’s own definition.

Validation:321 source checks and9 focused native tests passed, including189 automatic held-Cue recipes, independent identities, all16 channels with both release forms and duplicate handling, A/B source isolation, model-specific selector behaviour, fresh contact preservation, stop cleanup, all qualified button targets, rejected placeholders/roles, exact pitch endpoints and strict browser values. Both players retain finite synced real-WAV playback. Earlier green logs before the selector correction remain in evidence. The iPad framework compiled; its bundled resource matches the source. All345 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r426/validation.json`.

The catalogue has347 recipes and562 records for555 physical models:233 automatic core and322 without it. First-protocol gaps fall to169. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R427 — Independent legacy single-player cores

Own manufacturer-authored guides qualify66 normal inputs each for Audiophony CDX6, CITRONIC MPCD-X3 and Stanton CMP.800. Synq DMC-1000 has68 inputs, including independently corroborated inverted pitch-bend. Synq’s own distributed device definition supplies that pitch contract and the1024-count jog reference. Its documented DMC1K..DMC1KH USB names allow automatic matching. The other three guides list generic MIDI names, so their recipes require manual selection. No sibling identity, pitch direction or conditional pad/FX contract is inherited.

Use unedited MIDI defaults, channel pair1/2, Shift Hold, pulse1024, normal Vinyl mode and relative CC encoders. Set hardware Player A/B per unit. Native channel0/1 targets remain app A/B. The optional NOTE encoder format also works. The recipes cover Play/Pause, held Cue/bends, key lock, manual loops, Load, library and contact-gated jog. Each recipe sends eight steady NoteOn127/0 lamps. Guides mislabel literal0x9n status as Control Change. Native follows the literal bytes and does not inherit conflicting ProMixer CC lamps or TAP-as-Sync roles.

The bounded input observer retires only the reporting source before its next changed bank or Shift-family control. Explicit Shift edges and wheel-mode presses also retire contacts. Late releases do not select an old bank. Normal and+63 release aliases handle both NoteOff and NoteOn-zero. Absolute encoder format, pulse512, customised channels/commands, pads/cue-memory/sample/edit/Hold/FX/Sync, full alternate functions, pitch except Synq, displays/meters/lifecycle/audio/host/OS and physical/iPad/A10X acceptance remain open. No vendor script, preset, firmware, driver or mode write runs.

Validation:323 source checks and13 focused native tests passed. These cover independent identities/manual capacity,190 automatic held-Cue recipes, all three catalogue gates, framing, both release forms, duplicate handling, source-owned bank/Shift/wheel cleanup, conditional-role rejection, relative and repeated-NOTE browser/jog formats, owned contact, exact1024-count values, independent Synq pitch and exact lamp packets. All four retain finite synced real-WAV playback. Initial missing-profile/decoder failures remain in evidence. The iPad framework compiled and its bundled resource matches the source. All347 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r427/validation.json`.

The catalogue has351 recipes and562 records for555 physical models. It has234 automatic core models and321 without automatic core. First-protocol gaps decrease to165. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R428 — Independent Beyond Music normal cores

Separate public DEX4 factory members qualify55 manual inputs for BeyondMusic (BMI) ABMA1 and58 for ABMA3. Both cover native Play/Sync/Load, PFL, key lock, held bends, three Hot Cues, native loop anchors/reloop/size/fixed2/4/8 loops, mixer/pitch axes, inverted crossfader, Cue mix, normal330-count wheel bend and library controls. Native loop actions replace the source software’s conditional loop commands. Each model retains its own source reference.

Only ABMA3 explicitly defines held deckCue on51/60 and headphone gainCC34. ABMA1’s CuePlay/SetCue keys stay inactive. ABMA1 has12 steady note lamps. ABMA3 adds two Cue lamps. Input and lamp addresses differ. No position strip or guessed Sync/key-lock lamp runs. Shared USB names and copied JB Systems comments do not qualify automatic identity or any JB model. ABMA4, Scratch-mode contact/toggles, needle positions, cutoff curves, CUP/Clear/FX/reverse, full mode/state/lifecycle/USB/OS/audio and physical/iPad/A10X acceptance remain open. Use manual selection, normal channel1 and separate app audio. No script, identity probe, reset, sleep, preset, driver or firmware runs.

Validation:325 source checks and9 focused native tests passed. Checks cover separate identity/manual capacity, source member hashes and active wire presence, model-specific held Cue/monitor exclusion, both release forms and source ownership, duplicate suppression, native buttons/fixed-loop arguments, independent axes, inverted crossfader, relative library/wheel counts, conditional-role rejection and exact lamp packets. Both models retain finite synced real-WAV playback. The three catalogue gates and190 automatic held-Cue recipes pass. The iPad framework compiled and its resource matches the source. All351 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r428/validation.json`.

The catalogue has353 recipes and562 records for555 physical models. Automatic core remains234, with321 without it. First-protocol gaps decrease to163. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R429 — Independent JB Systems KONTROL2 and KONTROL3 cores

Each manufacturer product page supplies its own Traktor mapping. Read-only TSI inspection qualifies25 manual normal inputs for each model. The subset covers Play/Load/PFL, independent loop anchors, channel volume/gain/three EQ axes/pitch, crossfader, Cue mix and strict1/127 library steps. Every active role, wire, target and inversion is checked against that model’s own TSI. A pinned CMDR command reference names the numeric software commands. No source mapping or vendor program runs.

The manufacturer files explicitly invert pitch and crossfader. Native preserves those directions. Their Cue command is CUP204, which does not establish held native Cue. CUP, Key Lock/modifier combinations, Sync/bends, pads/Shift/FX/kills/loop modes, wheel/contact/calibration, needle positions and all feedback remain inactive. Output ranges and polarity were not qualified in this review. Shared USB names and Beyond Music comments do not establish identity or sibling compatibility. Select the model manually, use normal channel1 controls and configure app audio separately. App loop anchors and pitch range apply. Full mode/state/lifecycle/identity/USB/OS/audio and physical/iPad/A10X acceptance remain open.

Validation:327 source checks and8 focused native tests passed. Checks cover source hashes, every active TSI role/target/direction, separate manual identity/capacity, native buttons and duplicate/release handling, inactive sibling roles/channels, all mixer axes, inverted pitch/crossfader, source-specific pickup and strict encoder limits. Both retain finite synced real-WAV playback. All three catalogue gates and190 automatic held-Cue recipes pass. The iPad framework compiled and its resource matches the source. All353 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r429/validation.json`.

The catalogue has355 recipes and562 records for555 physical models. Automatic core remains234, with321 without it. First-protocol gaps decrease to161. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R430 — Remaining JB Systems primary-source limits

The manufacturer’s KONTROL1 Traktor download contains a Word document with an external community mapping link. The community page was unavailable to the web reader. The manufacturer download itself has no numeric messages. The KONTROL3S guide also lacks a numeric MIDI table. Neither model inherits KONTROL2/3 or Beyond Music bindings.

The KONTROL4 product page has a separate VirtualDJ mapping for serial numbers starting2008. Its instructions identify that hardware as MD1311. The XML mapper names device W1311 and contains77 symbolic controls/software actions. It does not include the numeric device definition. This qualifies the source’s identity description and serial scope, not a MIDI implementation. No older serial, Welljoint MD1311 or similar controller protocol is inferred. The public numeric definition remains to be found.

Hashed primary downloads and source limits are recorded in the public-source audit. Archives and documents were read without running vendor software, source actions, drivers or firmware. Runtime recipes and counts remain unchanged:355 recipes,161 first-protocol gaps and0/555 full theoretical models. This review does not close those gaps or establish device acceptance.

## R431 — Orbit factory pad banks

Numark’s public NEBUL4 download includes an Orbit Default MIDI JSON template and installation instructions. The instructions allow a default device to skip editor programming. All64 pad wires and momentary modes are checked against that template. The editor guide also identifies the Numark ORBIT port name. Native selects the64-input accessory profile automatically and sends no setup, preset, LED or audio packets.

The native layout assigns pad banks1/2/3/4 to A/B/C/D. C/D require app opt-in. In MIDI note order36..51, each bank supplies eight Hot Cues, Play, held Cue, Sync, Load, Loop In, Loop Out, Reloop and Key Lock. This is an explicit native assignment for the unlabelled pads. No Traktor software action runs. The next mapped positive pad on a changed channel retires only that source before its new action. Both release forms keep their original bank. A late release cannot switch the context back.

A standalone bank-selector message has not been qualified. A held control therefore awaits its original release or the next mapped bank report. Custom assignments/toggle pads, virtual knobs, motion/shoulder controls, complete bank/lifecycle/recovery, pad/ring feedback, receiver/USB/OS/power and physical/iPad/A10X acceptance remain open. No hardware reset, stored preference, colour setting, driver or firmware runs.

Validation:329 source checks and10 focused native tests passed. Checks cover every factory pad wire/mode, automatic identity, both release forms, all four native targets and eight Hot Cues each, source-owned changed-bank cleanup, late releases, fresh presses, stop cleanup and rejected custom/knob/motion/channel inputs. Real-WAV playback remains finite and synced. All three catalogue gates and191 automatic held-Cue recipes pass. Initial missing-profile/decoder failures and a corrected test callback signature remain in evidence. The iPad framework compiled and its resource matches the source. All355 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r431/validation.json`.

The catalogue has356 recipes and562 records for555 physical models. It has235 automatic core models and320 without automatic core. First-protocol gaps decrease to160. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R432 — Independent MPD218 chroma10 contract

Akai’s public factory archive includes preset1 chroma10. An independent hardware-tested preset-format reference qualifies its fields. Tests check every active wire, pad type/momentary mode and full-range CC knob against that exact549-byte factory file. The manufacturer’s own Bitwig member separately identifies the MPD218 Port A identity and channel10 pad stream. No preset, script or format utility executes.

The66-input native accessory layout assigns Pad Banks A/B/C to app A/B/C. Enable C separately. Each16-note bank supplies eight Hot Cues, Play, held Cue, Sync, Load, Loop In/Out, Reloop and Key Lock. Six knob controls per deck provide gain/high/mid/low/level/filter. Their physical banks remain independent of pad banks. A changed mapped pad bank retires only the reporting source and rearms its pads. Knob pickup remains active across pad-bank changes.

Select unedited preset1 with PROG SELECT+Pad1 and keep Note Repeat off. The manufacturer guide specifies holding Note Repeat during iOS connection, then releasing it. Native sends no setup or stored setting. A standalone bank/preset-selector report remains unqualified. Held controls await their original release or next mapped bank report. Other presets, toggle/program/bank types, pressure/repeat/tempo, complete preset/bank lifecycle/recovery, feedback and USB/OS/power/physical/iPad/A10X acceptance remain open. MPD226/232 and MPK contracts remain separate.

Validation:331 source checks and11 focused native tests passed. Checks cover the exact factory frame, all48 pads/18 knobs, automatic main-port identity, all three native targets, eight Hot Cues each, velocity1/64/127, both release forms, source-owned bank cleanup, late releases, stop cleanup, independent knob pickup and rejected pressure/custom/channel messages. A velocity1 Cue and Play retain finite synced real-WAV playback. All three catalogue gates and192 automatic held-Cue recipes pass. Initial missing-profile/decoder failures remain in evidence. The iPad framework compiled and its resource matches the source. All356 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r432/validation.json`.

The catalogue has357 recipes and562 records for555 physical models. It has236 automatic core models and319 without automatic core. First-protocol gaps decrease to159. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.
## R433 — Independent MPD226 and MPD232 Bitwig cores

Separate members in Akai’s manufacturer Bitwig download qualify two100-input manual accessory profiles. Select the onboard Bitwig preset and main Port A. Remote, Port B and MIDI4 remain inactive. No vendor script or device setting runs.

Each64-pad layout assigns four16-pad banks to A/B/C/D. C/D require app opt-in. Each bank supplies eight Hot Cues, Play, held Cue, Sync, Load, Loop In/Out, Reloop and Key Lock. The first four columns in each of three control banks supply PFL/Sync/Key Lock switches, level/high/low faders and gain/mid/filter knobs. Only strict1/127 knob steps are qualified. MPD232’s extra four columns remain inactive.

Pad and control banks stay independent. A mapped pad-bank change retires only its source and rearms its pads. A control-bank change rearms its switches and reacquires pickup for its new controls without releasing held pad Cue. Late releases cannot select an old context. Standalone selector reports are not qualified; held controls await their original release or next mapped pad report.

Other presets, full relative magnitudes, dedicated transport, navigation, pressure/repeat, Remote display/colour-parameter writes, complete bank/preset/lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. No setup, preset, stored global setting, tempo, colour, driver, firmware or audio route is written. MPD218 and MPK contracts remain separate.

Validation:333 source checks and12 focused native tests passed. Checks cover both independent identities, all64 pads/36 controls, velocity1/64/127 and both Cue release forms, source-owned bank cleanup, independent pickup, switch rearming, late releases, stop cleanup and rejected extra columns/transport/pressure/unknown knob steps. Soft Cue and changed banks retain finite synced real-WAV playback. All three catalogue gates and192 automatic held-Cue recipes pass. Initial missing-profile/decoder failures remain in evidence. The iPad framework compiled and its resource matches the source. All357 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r433/validation.json`.

The catalogue has359 recipes and562 records for555 physical models. It has236 automatic core models and319 without automatic core. First-protocol gaps decrease to157. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R434 — LPD8 MK2 published Program1 accessory

The publisher’s Program1 editor image specifies eight momentary pads, Notes36..43, and eight full-range knobs, CC36..43, all on channel1. The downloadable preset and manufacturer guide are pinned separately. Native assigns the bottom pad row to Hot Cues1–4 A and the top row to Hot Cues1–4 B. The top knobs provide gain/high/mid/low A; the bottom knobs provide the same B. This is an explicit native accessory layout. No source software action runs.

Use the published VDJ Program1 assignments in NOTE mode and select this profile manually. Native does not send or load the preset. Factory defaults have not been independently qualified. Original LPD8 and LPD8 Wireless remain separate. Knob pickup applies per control and source.

Mode/program transitions have no qualified report. In this preset, CC-mode pads overlap the knob CCs and cannot be distinguished. Deactivate this profile before changing mode or program. Other programs, CC/Program Change operation, pressure, RGB feedback, complete mode/preset/lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. No setup, saved setting, colour, driver, firmware or audio route is written.

Validation:335 source checks and7 focused native tests passed. Checks cover the independent manual identity, all16 wires/targets, both pad release forms, repeated-press suppression/rearming, source isolation, all knob pickup/ranges and rejection of unmapped channels/pressure/program messages. Real-WAV playback remains finite and synced. All three catalogue gates and192 automatic held-Cue recipes pass. Initial missing-profile failures remain in evidence. The iPad framework compiled and its resource matches the source. All359 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r434/validation.json`.

The catalogue has360 recipes and562 records for555 physical models. It has236 automatic core models and319 without automatic core. First-protocol gaps decrease to156. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R435 — Independent Launchpad S native grid

Novation’s own programmer reference qualifies the channel1 X-Y grid, two-colour feedback and temporary configuration. Native reuses its existing64-pad DJ layout with independent S addresses: A/B below, C/D above with app opt-in. Each quadrant supplies Play, held Cue, Sync, Load, PFL, Loop In/Out, Reloop and eight Hot Cues. The52 status lamps use red15, green60, amber63 and off12. No Mini/X/Pro protocol is inherited.

Automatic input requires a paired output. Startup sends temporary reset, X-Y layout and simple buffer0 commands. Reset clears all LEDs and returns volatile settings to power-on values. Startup failure and shutdown attempt the same reset. Previous volatile layout/brightness/buffer state is not restored. No authentication, firmware, bootloader identity/power mode or stored setting is written. The advanced guide specifies default low-power mode for iPad bus power; full-power mode requires a separate powered hub.

Outer buttons, drum layout, advanced colour/buffering/animation/brightness, complete lifecycle/recovery and physical/iPad/A10X acceptance remain open. No audio route is inferred.

Validation:337 source checks and9 focused native tests passed. Checks cover all64 addresses/native targets, all four quadrants/eight Hot Cues, velocity1/64/127 and both Cue release forms, source ownership, stop cleanup, C/D opt-in, independent identity/colours, exact temporary setup/shutdown, every startup failure and missing output. Soft Cue and Play retain finite synced real-WAV playback. All three catalogue gates and193 automatic held-Cue recipes pass. Initial missing-profile failures remain in evidence. The iPad framework compiled and its resource matches the source. All360 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r435/validation.json`.

The catalogue has361 recipes and562 records for555 physical models. It has237 automatic core models and318 without automatic core. First-protocol gaps decrease to155. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R436 — Independent Roland DJ-202 normal core

Separate pinned hardware-owner XML/script sources qualify110 manual normal MIDI inputs. These community observations are not a manufacturer SDK. No DJ-505 or DJ-808 protocol is inherited. Native covers four-target Play, held Cue, Sync and Key Lock; six explicit14-bit pairs per deck; filter, PFL, own loop buttons and strict browser steps. C/D require app opt-in.

Pairs are tempo9/59, gain22/52, high23/53, mid24/54, low25/55 and level28/58. The actual XML defines EQ input addresses; script constructor placeholders differ. Source rate direction is inverted. Native tempo is inverted and Shift-guarded. Normal transport is Shift-guarded; shifted/opposite-bank release aliases preserve held ownership and debounce. Own loop channels4..7 use In21, Out22 and toggle24. Reloop-and-stop23 remains inactive. Library CC0/channel15 accepts only127 previous and1 next outside Shift.

Generic USB mode may require a saved hardware selection. Manual selection remains required. Shared Load/deck-switch ownership, crossfader maximum calibration, jog/contact, pads/FX/TR-S, full Shift modes, feedback, complete setup/shutdown/recovery, routing and physical/iPad/A10X acceptance remain open. Native sends no source initial-state/pad-unlock SysEx, preset, global setting, driver, firmware or audio route.

Validation:340 source checks and10 focused native tests passed. Every active wire and each explicit low-byte pair is checked against its own XML. Native checks cover independent identity, all24 pairs/targets/polarity, own loop/filter/PFL rows, C/D opt-in, Shift guards, shifted/opposite-bank releases, repeated Play, soft Cue source ownership/both release forms, strict browser steps and independent pickup. Real-WAV playback stays finite and synced across Shift/bank releases. All three catalogue gates and193 automatic held-Cue recipes pass. Initial missing-profile failures remain in evidence. The iPad framework compiled and its resource matches the source. All361 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r436/validation.json`.

The catalogue has362 recipes and562 records for555 physical models. It has237 automatic core models and318 without automatic core. First-protocol gaps decrease to154. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R437 — Independent MIDI Fighter 3D banked native core

Separate maker Ableton and Traktor protocol documents independently qualify all64 banked arcade wires and the same LED override table. Tests check every numeric entry in both appendices; their octave labels differ, so native uses numeric addresses. Use default base channel3 with Four Banks enabled, then select this profile manually. No utility or device setting runs.

Banks1/2/3/4 target A/B/C/D. C/D require app opt-in. Bottom two rows provide eight Hot Cues; the next row Play, held Cue, Sync and Load; the top row PFL, Loop In/Out and Reloop. Each positive bank-selector report immediately retires only its source and rearms its pads. Late NoteOff/NoteOn-zero selector reports cannot retire the new bank. Arcade releases retain their original addresses. Duplicate Ableton CCs and motion/rotation traffic remain inactive.

Optional manual feedback supplies52 static arcade lamps: green76, yellow80, red84 and black67. Zero/NoteOff restores configured default illumination, so false status uses black67. Bank LED writes can change the bank and are never emitted. Feedback needs separate destination selection and opt-in. Saved LED restoration, custom channels, disabled-bank Hold/Toggle modes, side/motion controls, firmware-dependent names/defaults, complete feedback/lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. No setup, bank selection, firmware, driver or audio route is written. Spectra/64/Pro/Twister contracts remain separate.

Validation:343 source checks and10 focused native tests passed. Checks cover both independent numeric tables, all64 inputs/native targets, four banks/eight Hot Cues, velocity1/64/127 and both Cue release forms, immediate selector cleanup, source ownership, late selector/pad releases, stop cleanup, C/D opt-in, optional lamp colours and rejected duplicate CC/motion/foreign inputs. Real-WAV playback remains finite and synced, including selector cleanup before any new pad. All three catalogue gates and193 automatic held-Cue recipes pass. Initial missing-profile failures remain in evidence. The iPad framework compiled and its resource matches the source. All362 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r437/validation.json`.

The catalogue has363 recipes and562 records for555 physical models. It has237 automatic core models and318 without automatic core. First-protocol gaps decrease to153. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R438 — Independent original APC mini grid and faders

A pinned hardware-owner capture/table, separately credited protocol diagram and own USB property capture qualify the original APC MINI footprint. Its manufacturer guide is pinned separately. No MK2 RGB protocol is inherited. Native uses the existing64-pad four-quadrant layout: A/B below and C/D above with app opt-in. Nine faders provide levels A-D, filters A-D and master, each with pickup. A global Shift guard makes74 inputs in total.

Both Shift edges retire only that source and rearm its controls/pickup. Normal pads/faders stay inactive during Shift. The52 static grid status lamps use the original green1, red3, yellow5 and off0 values. Input can work without a paired output. There is no startup/identity/fader-confirmation or device-mode write. Paired shutdown attempts to clear all64 grid lamps; it does not reset the device or touch outer LEDs.

Other outer buttons, Shift functions, advanced lights, startup state, complete lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. Hardware-owner speculation about USB driver types is not used as a protocol fact. No preset, global setting, firmware, driver or audio route is written.

Validation:346 source checks and11 focused native tests passed. Checks cover every own grid number, all64 native pad targets, velocity1/64/127 and both Cue release forms, four quadrants/eight Hot Cues, C/D opt-in, source ownership, immediate Shift cleanup/guards, all nine faders/pickup/source isolation, exact static colours, input without output and64-lamp stop cleanup. Soft Cue/Shift/Play retain finite synced real-WAV playback. All three catalogue gates and194 automatic held-Cue recipes pass. Initial missing-profile failures remain in evidence. The iPad framework compiled and its resource matches the source. All363 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r438/validation.json`.

The catalogue has364 recipes and562 records for555 physical models. It has238 automatic core models and317 without automatic core. First-protocol gaps decrease to152. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R439 — Independent APC64 Session-mode core

Pinned Bitwig primary integration source qualifies the APC64 DAW/Notes port split, own device identity, Session mode0, channel7 pad grid, eight14-bit Pitch Bend strips on channels1–8, global Shift and static palette values. These are primary integration facts, not a manufacturer SDK. No APC mini/MK2/APC20/APC40 protocol is inherited.

Automatic setup sends the source normal-routing flag, Session selection and identity request only to the paired DAW output. Native waits for the exact own family/member response before requesting DAW control. Readiness confirms local send success; the source does not promise a separate DAW acknowledgement. Other reported modes immediately retire only that source and block its pads, strips and feedback. Returning to Session needs another successful DAW-enable send.

The73-input layout uses the existing64-pad four-quadrant grid: A/B below, C/D above with app opt-in. Strips1–4 provide levels A-D;5–8 filters A-D, with pickup. Shift retires its source and guards normal controls. The52 static lamps use the independently qualified channel7 palette: red5, yellow13, green21 and off0. Shutdown clears those mapped lamps and requests DAW exit. A failed shutdown lamp or exit send still attempts the exit command. Partial startup abort also attempts exit.

Initial state, previous mode/LED restoration and persistence of the source routing flag1B are not qualified. Other modes, strip touch/position/colour feedback, outer controls, OLED, sequencer/CV/DIN, complete lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. No Bitwig code, preset/global-settings dump, driver, firmware or audio route runs.

Validation:348 source checks and14 focused native tests passed. Checks cover own identity, fragmented/bounded/interrupted SysEx and real-time bytes, local DAW-send readiness, all64 pads/eight Hot Cues per quadrant, velocity1/64/127 and both Cue releases, all eight14-bit strips/pickup, C/D opt-in, source-owned mode/Shift cleanup, successful/failed Session return, all three startup failures, missing output, static lamp bytes and every one of53 shutdown-write failures. Real-WAV mode loss and Session return keep finite synced audio. All three catalogue gates and195 automatic held-Cue recipes pass. Missing-profile/decoder, assertion-macro, missing gate-handshake and shutdown-failure results remain in evidence. The iPad framework compiled and its resource matches the source. All364 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r439/validation.json`.

The catalogue has365 recipes and562 records for555 physical models. It has239 automatic core models and316 without automatic core. First-protocol gaps decrease to151. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R440 — Independent APC20 mode2 native core

Pinned hardware-owner mode2 code and a separately authored QLC+ APC20 table agree on every active input. A firsthand APC20 write-up documents the matching mode command and default mode40. The own manufacturer guide is pinned separately. No APC40/APC64/APC mini input contract is inherited. These sources qualify63 automatic native inputs and48 static lamps.

Each adjacent column pair targets A/B/C/D. C/D require app opt-in. The first four pad rows supply eight Hot Cues per deck; the last row provides Play/Cue. Each adjacent fader pair provides that deck’s level/filter. Both Solo buttons set its PFL. Master stays global. The encoder accepts strict1/127 library steps. Four navigation keys send repeatable library pulses. Shift retires only its source, guards normal controls and rearms pickup, including master.

Paired setup sends the exact source product7B/mode42 command. Shutdown and partial-startup abort request default mode40. No acknowledgement or previous-state restoration is claimed. Forty grid/eight PFL status lamps use observed on values1/3 and off0; colour names are not inferred from APC40. Other34 QLC+ controls, full encoder magnitude/calibration, other modes, persistence of mode selection, saved LED/mode restoration, complete feedback/lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. No source lighting-console action, nonlinear fader curve, identity query, preset/global-settings dump, driver, firmware or audio route runs.

Validation:351 source checks and11 focused native tests passed. Every active wire is checked against the own97-control QLC+ table. Native checks cover40 pads/eight Hot Cues per deck, velocity1/64/127 and both Cue releases, all nine faders/pickup and eight PFL buttons, C/D opt-in, source-owned Shift cleanup/master pickup, strict encoder/repeated navigation, observed lamp bytes, paired startup/default exit, missing output and failed startup. Real-WAV Shift/Cue/Play retain finite synced audio. All three catalogue gates and196 automatic held-Cue recipes pass. Initial missing-profile failures remain in evidence. The iPad framework compiled and its resource matches the source. All365 earlier recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r440/validation.json`.

The catalogue has366 recipes and562 records for555 physical models. It has240 automatic core models and315 without automatic core. First-protocol gaps decrease to150. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R441 — Independent VCI-380 documented MIDI core

Vestax’s April2012 manufacturer MIDI table qualifies44 automatic input rows. The public cached scan transcription is pinned separately from the inaccessible original PDF. The hardware-owner DJ Yoi guide cross-checks panel functions and Shift+Hot Cue selecting Sampler. No VCI-400/300/100 protocol is inherited. The specific VCI-380 endpoint works without paired output. Generic Vestax endpoints stay excluded.

The native subset provides Play, held Cue, Sync, gain/EQ/level, crossfader, Cue/Master blend, direct headphone-cue state, shifted Load/Keylock and sixteen Hot Cues. Pads start inactive. An explicit Hot Cue selector enables that deck’s pads. Slicer/Auto Loop/Roll block Hot Cues. Shifted Sampler invalidates the corresponding normal pad channel until Hot Cue is selected again. Reconnect returns pads to unknown. Repeated discovery preserves known mode state. Per-deck Shift clears only its source/deck contacts and rearms that deck’s mixer pickup. The other deck and global crossfader remain available.

The bounded mode schema now permits unknown startup and explicit cross-channel invalidators. It rejects duplicate, conflicting and out-of-range selectors. Existing mode-light updates use the selected state, so invalidation cannot light a mode with a matching number on another channel. All366 earlier recipes remain identical.

Jog/scroll encodings, tempo-pair order/polarity, the ambiguous OCR Input Switch number, remaining pad/FX/parameter modes, output velocity semantics, full lifecycle/recovery, computer/input-source ownership, USB/OS/power and physical/iPad/A10X acceptance remain open. Use the supplied7.5V adapter. No setup, query, output, preset, driver, firmware or audio route is sent.

Validation:353 source checks and17 focused native tests passed. Native checks cover unknown startup, every Hot Cue, unsupported modes, shifted Sampler, separate sources/decks, reconnect, repeated discovery, direct PFL edges, twelve mixer controls/pickup, per-deck Shift pickup, velocity1/64/127, both held-Cue releases, shifted Load/Keylock and inactive ambiguous wires. Real-WAV Shift/Cue/Play retain finite synced audio. All three catalogue gates and197 automatic held-Cue recipes pass. The iPad framework compiled and its bundled resource matches the source. Initial missing-profile/mode failures and a corrected build-command failure remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r441/validation.json`.

The catalogue has367 recipes and562 records for555 physical models. It has241 automatic core models and314 without automatic core. First-protocol gaps decrease to149. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R442 — Independent Mixars QUATTRO owner performance subset

A public hardware-owner export supplies229 source rows. Its four line-volume rows contain dangling output keys, so the original file cannot be imported as a property list. The original archive/member remain unchanged and pinned. Source checks remove only those four absent-output markers in a temporary XML tree to inspect the existing input facts. No repaired map, downloaded code or output runs in the app. The manufacturer manual independently confirms the deck selector, CUES/Transport/Sampler/User modes and non-Serato hardware mixing.

The manual109-input-row accessory subset provides32 Hot Cues, Transport-mode Play and loop half/double, fixed-four-beat loop push, four fixed Loads, the source’s A/B Sync and flipped library browsing. Four Shift reports compose two physical side contacts. All normal controls are guarded while either contact is held. Forty-eight release-only aliases rearm buttons across A/C and B/D. Two shifted Sync releases only rearm normal Sync. C/D require app opt-in. No DUO/PRIMO/Reloop Quattro protocol is inherited.

Source numbered Cue26 does not establish held main Cue and stays inactive. Hardware mixer/PFL/faders, including dual14-bit reports, are not translated into software mixing. Non-Serato mode needs separate deck audio outputs, which remain unimplemented. Owner reports of failed map imports, pad lights and headphone setup remain evidence limits. Automatic selection, all other modes, feedback, cold routing discovery, full lifecycle/recovery, audio/USB/OS/power and physical/iPad/A10X acceptance remain open. No setup, output, preset, driver, firmware or audio-route packet is sent.

Validation:356 source checks and10 focused native tests passed. Every active wire matches the unmodified owner export. Native checks cover all cue addresses, both release forms, cross-bank rearming, Play/fixed-loop/loop sizing, Loads, A/B Sync, two composed Shift contacts, separate sources, flipped browsing, C/D opt-in and inactive numbered Cue/mixer/other modes. Real-WAV Play/loop/Shift keep finite synced audio. All three catalogue gates and197 automatic held-Cue recipes pass. The iPad framework compiled and its bundled resource matches the source. All367 earlier recipes remain identical. Initial missing-profile and source-alias-check failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r442/validation.json`.

Additional public Rane SDK/Performer, Denon X1850 and NS7II/III searches yielded no usable own wire table in the checked results. This does not establish that no other source exists. The pinned Mixxx1.11 historical tree is saved for comparison. Original NS7/X1600 protocols are not inherited.

The catalogue has368 recipes and562 records for555 physical models. Automatic core stays241, with314 without it. First-protocol gaps decrease to148. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R443 — Independent SmartPAD default Clip grid

MIDIPLUS’s own manual001/v1.2/May2019 qualifies default Clip mode, raw channel0 NoteOn/NoteOff, the first two row addresses and full00..77hex bounds. Independently pinned factory-hardware owner notes and a preserved firsthand review confirm the complete eight-row layout, top-to-bottom16*y+x. The older notes reverse the NoteOn/NoteOff status labels. The manufacturer’s explicit bytes remain authoritative. No Launchpad or APC protocol is inherited.

The native60-input accessory grid reuses only app assignments. A/B occupy the lower quadrants. C/D occupy the upper quadrants with app opt-in. Each quadrant provides Play, Sync, Load, PFL, Loop In/Out, Reloop and eight Hot Cues. It selects automatically for the specific SmartPAD endpoint without paired output or setup.

The four main Cue cells stay inactive. Mode buttons do not reliably send MIDI, and Set mode shares messages with encoders. These gaps prevent a reviewed held-contact handover. Release pads before a hardware mode change. Mode1/2, Set/encoder CCs, scene buttons, host paging, other firmware and full lifecycle remain inactive/unqualified. No Ableton handshake enables arrow paging. Use factory firmware/default Clip and close other controller hosts.

The manufacturer requires a NoteOff before a colour change. Owner evidence distinguishes older firmware behaviour and a differing velocity palette. Output stays inactive. Full mode/source ownership, saved state, feedback, USB/OS/power and physical/iPad/A10X acceptance remain open. SmartPAD II and replacement KIKPAD/CleverPad firmware are separate. No setup, reset, preset, driver, firmware or audio route is sent.

Validation:358 source checks and nine focused native tests passed. Native checks cover all60 coordinates/functions, eight Hot Cues per deck, positive velocities, both release forms, separate sources, disconnect without repeated Play, C/D opt-in and inactive Cue cells/other modes/encoders/scenes/unmapped addresses. Real-WAV Play and unsupported-mode reports keep finite synced audio. All three catalogue gates and197 automatic held-Cue recipes pass. The iPad framework compiled and its bundled resource matches the source. All368 earlier recipes remain identical. Initial missing-profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r443/validation.json`.

The catalogue has369 recipes and562 records for555 physical models. It has242 automatic core models and313 without automatic core. First-protocol gaps decrease to147. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R444 — Independent Reloop KUT continuous MIDI subset

Reloop’s own manual and the distributor mirror are byte-identical. The visually reviewed p7 chart qualifies14 continuous0..127 mixer controls: gain/EQ/level A/B, crossfader, master, headphone level and cue blend. It specifies Bn without a fixed MIDI channel. Native accepts the documented channel range without guessing a factory channel. No RMX model is inherited.

The new wildcard boundary applies only to an input-only manual accessory with at most32 unique absolute mixer CCs. It rejects automatic selection, buttons, unrelated actions, inversion, Shift, mode/bank/protocol contracts, setup, output and audio configuration. Existing player and paired APC40 wildcard guards remain intact. Pickup stays scoped to the physical source and control. Changing MIDI channel does not change its fixed mixer target.

Enable the hardware MIDI switch separately. KUT hardware mixing remains active. Separate app audio and hardware routing need qualification before combined use. Automatic selection/audio routing stays off. PFL edge/latch semantics, input-source switches, dynamic FX, mic/booth/curve controls, fader-start and full feedback/lifecycle/recovery remain inactive. Fader-start is not Play. The documented pickup-request SysEx is not sent because its full effect and restoration remain unqualified. No query, preset, driver, firmware or audio-route packet is sent. Full audio/USB/OS/power and physical/iPad/A10X acceptance remain open.

Validation:360 source checks and11 focused native tests passed. Native checks cover all14 controls on all16 MIDI channels, pickup, channel changes, separate sources/groups, every omitted button/control and the narrow schema boundary. Real-WAV checks confirm actual level/master changes after pickup, finite audio, continued playback and saved Sync. All three catalogue gates and197 automatic held-Cue recipes pass. The iPad framework compiled and its bundled resource matches the source. All369 earlier recipes remain identical. Initial missing-profile/schema failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r444/validation.json`.

The separately preserved PAD-One manufacturer manual documents configurable notes/channels, Hold/Roll and physical reset. Its generic MIDI scale chart does not establish factory assignments. No defaults or reset command are inferred.

The catalogue has370 recipes and562 records for555 physical models. Automatic core stays242, with313 without it. First-protocol gaps decrease to146. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R445 — Independent PMX-20 documented MIDI core

Gemini’s own2018 manual supplies the A/B performance, four mixer strips, global controls and LED table. A separate public2021 PMX20 MIDI SPEC.xlsx export adds explicit C/D performance rows, binary-offset loop encoders, mode/focus paging and factory momentary-button behaviour. Its author metadata is only `admin`. Manufacturer authorship of that separate export is not established. Its additional facts remain explicitly attributed.

The documents disagree on C/D Load, Forward and the rotary browse channel. Those controls stay inactive. The manual76-input accessory subset provides32 Hot Cues, four loop buttons/size encoders, six mixer controls per deck, PFL, A/B Load, directory entry, previous-group assignment on Back, crossfader, master and headphone level/blend. Source Hot Cue notes8..1 reverse by slot. Sample notes09..0F/20hex remain inactive. Mode33/34 rearms only its deck. The technical table’s focus64 rearms A/C or B/D without an app action. C/D require app opt-in.

Forty optional static lamps use32 green1 Hot Cue lamps and eight on1 PFL/Loop lamps, all off0. No mode/focus lamp is sent because those receive messages change hardware paging. No transport is inferred from another physical control.

Use Full MIDI mode, selected before opening the app by holding CH2 USB for10seconds. Use factory momentary buttons and normal paging. Automatic selection stays off because power-on defaults to hardware Mixer mode, and persistent Flat/Toggle settings have no reviewed discovery/restoration. Sampler/FX, meters, disputed controls, complete source/audio/mode/lifecycle/recovery, USB/OS/power and physical/iPad/A10X acceptance remain open. No identity query, forced update, all-LED reset, persistent mode, preset, driver, firmware or audio-route command runs. No PMX10 protocol is inherited.

Validation:363 source checks and10 focused native tests passed. Native checks cover every reversed Hot Cue, both release forms,24 deck mixer controls/four globals and pickup, PFL, loop buttons/relative encoders, agreed Loads/directory controls, repeated Back, source-owned mode/focus rearming, C/D opt-in, static lamp bytes and inactive disputed/Sample/FX controls. Real-WAV loop/mixer reports retain finite synced audio and an active loop. All three catalogue gates and197 automatic held-Cue recipes pass. The iPad framework compiled and its bundled resource matches the source. All370 earlier recipes remain identical. Initial missing-profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r445/validation.json`.

The catalogue has371 recipes and562 records for555 physical models. Automatic core stays242, with313 without it. First-protocol gaps decrease to145. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R446 — Independent PMX-10 manufacturer MIDI core

Gemini’s own PMX-10 p8/p9 MIDI chart independently qualifies40 manual inputs. The subset provides16 reversed Hot Cues, Loop, six mixer controls per deck, PFL, Load, directory entry, previous-group assignment on Back and four global controls. Sample09..0F/20hex stays inactive. Mode33/34 rearms only its source/deck. No PMX20 protocol, C/D target, encoder format, preset or mode command is inherited.

Nineteen optional static lamps provide16 green1 Hot Cues, two on1 Loop lamps and one on1 PFL-B lamp, all off0. The own chart explicitly lists CH1 PFL MIDI Input as None. That output stays inactive. No transport is inferred from another control.

The own manual selects Mixer without a host, Hybrid with another audio interface and Controller with the PMX-10 audio interface selected. Native does not discover or configure those audio modes. Automatic selection remains off. Loop-size/browse encoders lack a specified byte format. Sampler/FX, fader start/reverse/curves, mic/booth, output Pad Mode CC40hex and full source/feedback/lifecycle/recovery remain inactive/unqualified. Hardware/audio ownership, USB/OS/power and physical/iPad/A10X acceptance remain open. No setup, reset, query, persistent mode, preset, driver, firmware or audio route is sent.

Validation:365 source checks and nine focused native tests passed. Native checks cover every reversed Hot Cue, both release forms, PFL/Loop, all16 continuous controls and pickup, Load/directory controls, repeated Back, source-owned mode rearming, static lamp bytes and inactive encoders/Sample/FX/curves/other-model channels. Real-WAV Loop and ignored encoder reports retain finite synced audio and an active loop. All three catalogue gates and197 automatic held-Cue recipes pass. The iPad framework compiled and its bundled resource matches the source. All371 earlier recipes remain identical. Initial missing-profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r446/validation.json`.

The manufacturer’s current MDJ-1000 download points to a V2 manual. It has MIDI/HID/settings instructions without a numeric control chart. The original model does not inherit V2 behaviour. The own GMX manual also lacks numeric addresses and states that entering MIDI mode stops standalone playback. No mode command or GMX DRIVE equivalence is inferred. Both source findings are pinned in the public-source audit.

The catalogue has372 recipes and562 records for555 physical models. Automatic core stays242, with313 without it. First-protocol gaps decrease to144. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R447 — Independent RMP-3 and RMP-2.5 Alpha preset cores

Separate manufacturer manuals qualify two38-input automatic player cores. The original RMP-3 uses its own p44 chart. RMP-2.5 Alpha uses its own p37 chart. Play, loops, Keylock, bends and Hot Cue addresses differ and remain independently pinned. USB names come from each model’s own Name menu. RMP-3 Alpha/RMP-4 protocols are not inherited.

Each core provides Play, held Cue, held bends, Keylock, Loop In/Out/Reloop, eight Hot Cues and navigation. Explicit shifted release-only aliases retire held Cue/bends and rearm normal buttons. Paired Hot Cue aliases rearm either physical layer. Track navigation accepts only the documented NOTE format. Folder buttons step native groups. Jog, pitch and configurable relative/absolute CC formats remain inactive.

No global Shift latch is created. Each physical layer already has explicit note numbers. Original RMP-3’s Shift42hex collides with shifted TAP42hex in its chart. Its concatenated Loop Out shifted field6D2E supplies only a defensive6D release alias, never a positive shifted Loop Out action.

Use MIDI USB mode and Edit Off preset commands. Native assigns one app deck per physical source across MIDI channels1..16. Changing the hardware channel keeps that assigned deck. Hardware multi-deck paging remains unimplemented. C/D need app opt-in. Jog/contact calibration, pitch polarity/types, other presets/encodings, FX, complete last-channel/Shift feedback, lifecycle/recovery, USB/OS/power/audio and physical/iPad/A10X acceptance remain open. No output, setup, source-mode change, query, preset, driver, firmware or audio-route command runs.

Validation:367 source checks and10 focused native tests passed. Native checks cover separate identities, normal buttons/shifted releases, Cue/bends at velocity1/64/127 across all16 channels and both release forms, eight Hot Cues/rearming across layers, note navigation, four source-owned deck assignments, independent Cue release, C/D opt-in and inactive variable formats/Shift wires. Both real-WAV cases retain Cue until its explicit release, then restore finite synced playback after bend release. All three catalogue gates and199 automatic held-Cue recipes pass. The iPad framework compiled and its bundled resource matches the source. All372 earlier recipes remain identical. Initial missing-profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r447/validation.json`.

The catalogue has374 recipes and562 records for555 physical models. It has244 automatic core models and311 without automatic core. First-protocol gaps decrease to142. Full theoretical support remains0/555. Physical/iPad/A10X acceptance remains open.

## R448 — Independent Jockey 3 Remix Track core

The own manufacturer manual qualifies144 manual input rows and32 optional static lamps. Factory MIDI channels1..4 target A/B/C/D. The function descriptions resolve the chart’s alternate printed labels: normal Sync23, CUP24, Cue25, Play26 and monitoring Cue28. Shifted Keylock87 is separate. CUP24 supplies only a Keylock release guard. The Jockey 3 ME protocol is not inherited.

The core provides transport, held Cue/bends, four Hot Cues per deck, six continuous mixer controls per deck, PFL, loops/size, Load, track browsing, directory entry, crossfader and cue mix. Shifted transport and Hot Cue releases retire holds and rearm buttons. Shifted Hot Cue clears stay inactive. VR/Low means separate CC and NOTE messages, not paired14bit input. Native assigns loop push43 to the current loop toggle, push44 to Reloop and shifted browse push116 to directory entry.

Global-channel source selectors retire only A/C or B/D. Sample/Remix selectors retire their deck’s held state but do not implement or discover those modes. Select this profile manually in Track mode with Sample/Remix off and the factory1..4 channel preset. C/D require app opt-in. Jog calibration/current resolution, tempo polarity, other channel presets, sampler/remix/roll/mash/FX, shifted clears, full source/feedback/lifecycle/recovery, audio/USB/OS/power and physical/iPad/A10X acceptance remain open. Master, booth and headphone level are analogue. No setup, preset, query, driver, firmware or audio-route packet runs.

Validation:369 source checks and10 focused native tests passed. Native checks cover normal buttons/shifted guards, held Cue/bends at three positive velocities and both release forms, every Hot Cue,26 continuous controls/pickup, relative loops/browse, source/deck cleanup, C/D opt-in, static lamps and inactive unqualified wires. Real-WAV Cue/bend release preserves finite synced playback. All three catalogue gates and199 automatic held-Cue recipes pass. The iPad framework compiled and its bundled resource matches the source. All374 earlier recipes remain identical. Initial missing-profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r448/validation.json`.

The catalogue has375 recipes and562 records for555 physical models. Automatic core stays244, with311 without it. First-protocol gaps decrease to141. Full theoretical support remains0/555. The wider market inventory audit and physical acceptance remain open.

## R449 — Manual profile pad-mode guards

Manual profiles now initialise their documented pad modes when applied or restored. Unknown modes remain blocked until the controller sends an explicit selection. Discovery preserves each present manual source’s mode when another automatic controller changes. An observed source disappearance clears its mode. Replacing a profile uses the replacement’s documented initial mode.

Two new native tests cover manual VCI-380 selection, shifted Sampler invalidation, saved mappings, unrelated automatic discovery, observed disappearance/reappearance and replacement with the Mixtrack Pro FX default mode. The initial missing-mode failure remains in evidence. All26 focused native tests pass, including existing automatic pad modes, VCI-380/Jockey transport, real-WAV synced audio and all three catalogue gates. The iPad framework compiled. All375 runtime recipes remain identical. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r449/validation.json`. Physical/iPad/A10X acceptance and complete hardware lifecycle qualification remain open.

Public Roland DJ-707M documentation was found without requesting an SDK. Its own three-page MIDI chart supplies numeric deck/pad/mixer assignments. The owner manual’s iOS workflow uses PC-B in Generic mode. Its standalone controller MIDI leaves PC-A, and the iOS section explicitly excludes DJ software. A direct iPad controller route is not established. No DJ-202/DJ-505 bytes, public software-mode setting or USB driver compatibility is inherited. No DJ-707M profile, driver or hardware mode write is added here. A future control subset must state its qualified MIDI bridge requirement.

## R450 — Independent DJ-707M bridge-only MIDI subset

The own manufacturer v1.02 MIDI chart qualifies107 manual input rows. This subset requires an already available, independently qualified PC-A MIDI bridge. Native does not provide that bridge, the PC-A USB driver or a direct iPad controller route. The owner manual’s PC-B Generic iOS audio workflow does not establish controller MIDI access.

The core provides four-target normal Play, held Cue, Sync, PFL, filter, Load, browse, previous-group steps and shifted Keylock. Global Shift guards normal controls. Shift+Cue’s Return-to-beginning wire supplies only a release guard. Native does not turn positive Shift+Sync into an automatic Sync-off command. C/D require app opt-in.

Pads start in an unknown mode. Each deck requires explicit Hot Cue selection. Other modes1..11 block pads. Shifted pad releases rearm their normal pads. Each deck selector invalidates its pad mode and retires held state in its A/C or B/D pair. Separate sources retain their own pad state and held Cue ownership. A second source’s Cue hold survives the first source’s bank change.

The chart gives high-resolution control-number pairs without enough byte-significance or tempo-polarity detail for this implementation. Those controls stay inactive. Jog/contact/calibration, full pad modes, FX/TR-S/mic/OSC, colour/output contracts, host ownership/handover, audio/USB/OS/power, complete lifecycle/recovery and physical/iPad/A10X acceptance remain open. No DJ-202/DJ-505/DJ-808 bytes are inherited. No setup, query, hardware mode, driver, firmware, reset or audio-route packet runs.

Validation:371 source checks and11 focused native tests passed. Native checks cover manual identity, four-deck normal/shifted transport, both Cue release forms at three velocities, source ownership, all eight Hot Cues per deck, unknown/unsupported modes, deck invalidation, saved manual mode guards, C/D opt-in, filter pickup, Load/browse and inactive unqualified controls. Real-WAV Shift/Cue release retains finite synced playback. All three catalogue gates and199 automatic held-Cue recipes pass. The iPad framework compiled and its bundled resource matches the source. All375 earlier recipes remain identical. Missing-profile failures and the corrected source-ownership test failure remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r450/validation.json`.

Separate Gemini CDJ-700 and CDJ-650 documents were also recovered. Their MIDI tables supply numeric Send Number/min/max fields. They do not establish MIDI status types or channel assignments. HID tables are separate. No note/CC type, HID transport, sibling equivalence or automatic profile is guessed from those tables.

The catalogue has376 recipes and562 records for555 physical models. Automatic core stays244, with311 without it. First-protocol gaps decrease to140. Full theoretical support remains0/555. The wider market inventory audit and physical acceptance remain open.

## R451 — Independent original Akiyama QUARK core

The original QUARK manufacturer manual qualifies164 automatic input rows and44 optional normal lamps. The catalogue spelling QUARC comes from its VirtualDJ entry, whose model identifier is QUARK. Both names select this original core. QUARK SC remains excluded. The pinned source hash identifies a public numeric-table text excerpt, not original PDF bytes. Direct PDF download and screenshots were unavailable. Legible source rows and the own worked example independently establish Play34hex as decimal52.

Factory raw channels0..3 target A/B/C/D, with global channel4. Native provides Play, held Cue/bends, Sync, PFL, Load, manual loops, current-loop toggle/size, six Hot Cues per deck, gain/EQ/level, master, crossfader and browse/group entry. Explicit shifted release aliases retire holds and rearm buttons. Shifted clears and distinct AutoLoop/Roll pad wires stay inactive. The hardware already encodes each alternate layer in its message number. No global Shift latch is inferred.

Deck selector7 retires only its A/C or B/D pair. Mode selectors41/42/43 retire their own deck. A second source’s Cue hold remains active. C/D require app opt-in. Forty-four optional127/0 lamps provide six yellow Hot Cues and five Play/Cue/Sync/PFL/Loop lamps per deck. Loop In/Out/Reloop lamps stay inactive because native does not represent those output actions. Green/shifted/mode/FX/sample/meter outputs are also inactive.

Jog/contact calibration, tempo polarity/range, full shifted continuous pickup/alternate functions, remaining modes/pads/FX/samples, full feedback/lifecycle/recovery, USB/OS/power/audio and physical/iPad/A10X acceptance remain open. The own power specification lists USB5V500mA or DC6V1.75A. It does not qualify iPad power. No setup, query, preset, driver, firmware or audio route runs.

Validation:373 source checks and10 focused native tests passed. Native checks cover both names, separate SC identity, all normal/shifted transport releases, held Cue/bends at three velocities and both release forms, six Hot Cues, inactive alternate pad/clear wires,22 continuous controls/pickup, relative loops/browse, source/deck cleanup, C/D opt-in and static lamp bytes. Real-WAV shifted Cue/bend release retains finite synced playback. All three catalogue gates and200 automatic held-Cue recipes pass. The iPad framework compiled and its bundled resource matches the source. All376 earlier recipes remain identical. Missing-profile and unsupported-loop-feedback failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r451/validation.json`.

The catalogue has377 recipes and562 records for555 physical models. Automatic core rises to245, with310 without it. First-protocol gaps decrease to139. Full theoretical support remains0/555. The wider market inventory audit and physical acceptance remain open.

## R452 — Compact controller resource with unchanged limits

The app now loads a generated compact resource. The full review JSON remains unchanged and stays outside the application bundle. Short input names and omitted Note/absolute/non-inverted defaults reduce the bundled resource from4,157,594 to2,051,892 bytes. Only already ignored definition/gaps/hardwareMode profile metadata is removed. Source, scope, aliases, every protocol option, outputs and setup bytes remain intact.

The native decoder accepts both forms through the same input contract. Full rows keep their required fields. Compact defaults apply only to absent fields. Mixed recognised full/compact keys, invalid types and invalid enums fail. Optional nil/false distinctions remain intact. The producer rejects unreviewed new input fields. Existing4MiB,512-profile,512-input and128-output limits remain unchanged. There is no new compression library, connection-time decompression, hardware command or UI flow. See the [storage contract](controller-catalogue-storage.md).

Validation:375 source checks and40 focused native tests pass. Source expansion preserves all377 recipes and packet bytes. Native comparison preserves all24,689 input bindings. Tests cover every optional field, defaults, malformed data, all three catalogue gates,200 automatic held-Cue recipes, APC64 setup/14bit/mode/recovery, manual pad modes, original QUARK, independent RMP players and compact Vestax layouts. Real-WAV cases retain finite synced audio. The iPad framework compiled. Its bundle contains the exact compact file and excludes the full review JSON. The obsolete native Mac cache asset remains preserved. The original-Spin sibling test now allows the separately supported Spin2 profile while rejecting aliasing to original Spin.

The full377-recipe review resource remains byte-identical to R451. Initial decoder failures, native-cache packaging expectations and the corrected old Spin2 test failure remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r452/validation.json`. Physical/iPad/A10X timing, complete controller support and hardware acceptance remain open. Catalogue counts stay377 recipes,555 physical models,245 automatic core models and139 first-protocol gaps. Full theoretical support remains0/555.

## R453 — TRAKTOR AUDIO 2 MK2 output routing

The own NI manual p25 visibly identifies the audio device as Traktor Audio 2 MK2. Its Internal Mixer layout uses Main L/R on1–2 and Headphone L/R on3–4. The existing output policy now selects that layout for the exact wired MK2 name. It does not require or create a MIDI controller profile. Unknown, wireless, ambiguous multi-output and legacy names remain unmatched.

The source catalogue now identifies this device as an audio-output interface. The own manual shows no audio inputs. It cannot supply a DVS input path. Its software-controlled headphone-volume and cue-mix encoders still need an implemented protocol. The generic catalogue row now records this narrow MK2 audio subset without asserting complete controls. Control-protocol gaps and full theoretical support stay open.

NI’s public iOS compatibility guidance distinguishes the MK2 from non-class-compliant AUDIO 2 DJ and TRAKTOR AUDIO 2 MK1. Those legacy models do not inherit direct iPad support. The new policy applies only when CoreAudio already exposes the documented wired MK2 endpoint. Current iPad naming, USB/cable/power/firmware, complete hardware control/lifecycle and physical/iPad/A10X acceptance remain open. No driver, mode, query, firmware or hardware-volume command runs.

Validation:377 source checks and16 focused native tests pass. Tests cover exact/trimmed/case-varied names, legacy and wireless rejection, ambiguous outputs, saved manual routing and offline synced PCM. The existing recovery and repeated-detection fixtures now include MK2 among17 documented devices. They preserve transport position/Sync, prevent fallback speaker restart and compare Main/Cue audio buses. All three catalogue gates,200 automatic held-Cue recipes and24,689 native binding comparisons pass. The iPad framework compiled and its compact resource matches the source. The full and compact377-recipe files remain byte-identical to R452. Initial missing-route and corrected source-metadata test failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r453/validation.json`.

Counts stay377 recipes,555 physical models,245 automatic core models and139 first-protocol gaps. The audio route does not inflate controller counts. Full theoretical support remains0/555.

## R454 — Independent Encore 2000 configured-channel core

The own manufacturer pp26/27 MIDI table qualifies68 manual input rows and six optional normal lamps. The profile requires MIDI mode with the left player on channel1 and right on channel2. The manual explains channel changes with TAP/Pitch Bend, but does not establish factory deck channel defaults or the numeric shared Mix CH. Neither is guessed. Select the required hardware mode and channels before using this profile.

The subset provides Play, held Cue/bends, Keylock, manual loops and gain/EQ/level. Explicit TAP-layer release aliases retire held actions and rearm buttons. TAP’s own press/release retires only the source/deck hold before a possible channel change. Both published CC families deliberately retain the same native mixer functions. Native assigns normal Folder to group entry, TAP+Folder to Load, normal Track buttons to track steps and TAP+Track to group steps. Opposite-layer Folder releases rearm both assignments. Directional steps accept repeated positive pulses.

Six optional127/0 lamps represent normal Play, Cue and Keylock. The unnumbered Mix CH, master/headphones/crossfader/relay, jog calibration, pitch polarity/range, remaining switches, complete mode/channel discovery/feedback/lifecycle/recovery, USB/driver/OS/power/audio and physical/iPad/A10X acceptance remain open. There is no global Shift latch. No source-mode, query, pickup, preset, firmware, driver or audio-route command runs. Encore1000/ELMC1/VMS protocols are not inherited.

Validation:379 source checks and11 focused native tests pass. Tests cover manual identity, normal/TAP transport rearming, both Cue/bend release forms at three velocities,20 mixer input rows/pickup, Folder/Load guards, repeated navigation, source-owned TAP cleanup, changed-channel rejection, optional lamps and inactive Mix CH/jog/pitch/other switches. Real-WAV TAP/Cue/bend release retains finite synced playback. All three catalogue gates,200 automatic held-Cue recipes and24,757 native input-binding comparisons pass. The iPad framework compiled and its compact resource matches the source. All377 earlier recipes remain identical. Missing-profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r454/validation.json`.

The own DDC-2000 manual also supplies a numeric MIDI table and default channels0..3. Some shifted global decimal/hexadecimal columns disagree. That protocol remains a separate implementation task. The own ELMC-1 manual has no numeric chart in the checked contents. DJM-V5’s current primary pages still do not supply a numeric table in the checked results and explicitly exclude Lightning mobile devices. No missing bytes, sibling equivalence or direct A10X connection is inferred.

The catalogue has378 recipes and555 physical models. Automatic core stays245, with310 without it. First-protocol gaps decrease to138. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R455 — Independent DDC-2000 factory Mode1/Hold core

The own manufacturer manual and factory VirtualDJ definition qualify211 automatic input rows and36 optional normal lamps. The manual declares factory raw channels0..3 for A/B/C/D and Hold Shift. Ruling: qualify this default core only. Stored channel/Shift presets and configuration chords still require separate work. The factory XML and mapper were read as data and were not executed.

The core provides transport, held Cue/bends, four Hot Cues, manual loops/size, PFL, mixer and deck-owned Load. The own definition establishes normal binary-offset jogs with150 counts per revolution, touch38 and inverted14-bit pitch bend. Native tempo uses its existing±8% range. Explicit shifted release aliases preserve held ownership and button rearming. Shifted Hot Cues1/2 perform native four-beat jumps. Shift+Low controls the filter. Normal Mid/Low, jog, tempo and loop size are Shift-guarded. Both documented gain/high/level CC families deliberately retain the same native actions.

The own factory definition resolves shifted global CC conflicts in favour of the manual hexadecimal columns: crossfader46, headphone blend49 and headphone level50. Normal and shifted controls keep separate pickup state. Normal Browse steps tracks. Shift+Browse steps native groups. Normal push enters a group, while shifted push only rearms it. Deck selector17/67 retires only the source-owned physical A/C or B/D pair. Jog resets are part of that cleanup.

Thirty-six optional127/0 lamps cover Play, Cue, Sync, Keylock, PFL and four Hot Cues per deck. The manual does not list an AutoLoop lamp. Extra master/mic fields in the XML are absent from the manual MIDI chart and stay inactive. Shifted search/loop movement, range changes, scratch/reverse/FX/sample/video/kill/loop-delete modes, full feedback/meters/lifecycle/recovery, exact USB naming, OS/power/audio/DVS routing and physical/iPad/A10X acceptance remain open. No setup, query, driver, firmware, preset or audio-route write runs. No sibling protocol is inherited.

Validation:381 source checks and14 focused native tests pass. Coverage includes default identity, optional lamps, four deck targets, explicit shifted rearming, both momentary releases at three velocities, Hot Cue/jump separation, calibrated jog signs, inverted pitch/pickup, shifted mixer guards, global pickup, browse/group separation, source-owned cleanup, C/D opt-in and inactive alternate presets/functions. Real-WAV Cue/bend release retains finite synced playback. All three catalogue gates,201 automatic held-Cue recipes and24,968 native binding comparisons pass. The iPad framework compiled and its compact resource matches the source. All378 earlier recipes remain identical. Initial missing-profile and test-expectation failures remain in evidence. The first expectations omitted jog cleanup and treated separate CC pickup as shared. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r455/validation.json`.

The catalogue has379 recipes and555 physical models. Automatic core increases to246, with309 without it. First-protocol gaps decrease to137. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R456 — Independent CMX-2000 native banks

The own manufacturer manual and two separate factory mappings qualify119 manual input rows. Set both input selectors to USB, MIXER MIDI to ON, Shift Lock to OFF and fader direction to normal. Keep crossfader THRU off. This profile does not establish automatic mixer ownership. The source XML and mapper were read as data and were not executed.

Fixed hardware channels0/1 feed native A/C and B/D banks. Native starts A/B on apply and reconnect. A normal Deck25 press selects the other deck on that side. Shared Load remains on global channel0 Note1/3. C/D require the existing app opt-in. The core provides transport, held Cue/bends, normal loops/size, four-beat jumps, gain/EQ/filter/level/PFL/Load, master/crossfader/headphone controls and native track/group browse. Both published continuous-control families deliberately retain the same native mixer actions.

Eight left Hot Cues use the own manual and factory definition. The right side differs. The independent Serato factory mapping corroborates VirtualDJ’s right Cue3/4 at46/47. Right Cue1..6 are qualified. Right Cue7/8 remain inactive because the two available assignments disagree. Shifted clear messages only rearm the corresponding normal cue. The profile has no jog or tempo fader because the hardware has neither.

A bounded optional `releaseNumber` permits one alternate release address for each manual deck-bank selector. Positive alternate messages cannot change banks. The validator rejects out-of-range addresses, primary/input/selector collisions, unbanked aliases and automatic profiles. A shifted Deck75 release rearms only that source/bank and preserves the selected deck and unrelated holds. This closes the stuck-selector case when a DJ holds Deck, presses Shift and releases Deck. Existing automatic Load-bank restrictions stay unchanged.

Full mixer source/reverse/THRU/curve/Shift Lock ownership, remaining pad/FX/sample/video/fader-start/filter-off/alternate-loop/seek modes, right Cue7/8, bank lamps/full feedback/meters/initial positions/startup/shutdown/recovery, USB/OS/audio/DVS routing and physical/iPad/A10X acceptance remain open. No lamp, source initial-position command, query, preset, driver, firmware or audio-route write runs. The source’s init attribute is not blindly copied as SysEx. DDC-2000 bytes are not inherited.

Validation:383 source checks and32 focused native tests pass. Tests cover schema bounds/collisions, manual identity, asymmetric cues, native banked Load/transport, both momentary releases at three velocities, fixed jumps, per-bank mixer pickup, Shift loop guards, globals/browse, held ownership, normal/shifted bank release, source isolation, C/D opt-in and A/B reconnection. Existing VMS5 and Twitch bank fixtures pass, including real-WAV playback. The CMX real-WAV Cue/bend release retains finite synced playback. All three catalogue gates,201 automatic held-Cue recipes and25,087 native binding comparisons pass. The iPad framework compiled and its compact resource matches the source. All379 earlier recipes remain identical. Initial missing-feature and compile/test failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r456/validation.json`.

The catalogue has380 recipes and555 physical models. Automatic core stays246, with309 without it. First-protocol gaps decrease to136. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R457 — Independent Radius1000 revisions and Radius3000

The own Radius1000 manufacturer sources disagree on important protocol bytes. The2009 factory definition uses TAP32, touch38 and shifted notes plus63. The March2010 manual uses TAP46, touch32 and shifted notes plus61. Ruling: provide separate manual profiles and do not select either version automatically. The2009 variant shares the existing physical-model record. It does not add a fictitious controller.

The2009 factory archive contains an NSIS container. Only its two XML data files were extracted. The executable and mapper were not run. This39-input layout requires raw channel0, Relative CC, Hold TAP,1024-pulse jog and pitch-bend pitch. It provides the own documented1024-count normal jog, contact, inverted native±8% tempo, transport/held Cue/bends, three Hot Cues, loops, track/group browse and Load A. TAP guards normal jog/tempo and retires only source-owned holds. The shifted touch message only releases. Manual player profiles target A and do not gain automatic separate-player assignment.

The38-input2010 profile follows its own NOTE table. Directional encoder navigation requires CC TYPE NOTE. Its four normal and four shifted directional notes step native groups/tracks. Folder push opens a group. Track push loads A. Three Hot Cues, Play, held Cue/bends, Keylock, normal loops and explicit shifted release aliases retain the2010 addresses. Jog/contact calibration, relative encoder encoding and pitch polarity remain unqualified for this version.

The own Radius3000 manual separately qualifies40 automatic input rows with four Hot Cues and its own plus63 release family. Connected players receive separate app-deck assignments across MIDI channels1..16. This does not implement hardware channel-selected virtual paging. Directional encoder navigation requires the documented NOTE format. The default Relative encoder format is not guessed. Folder/Track pushes open a group and load the assigned deck. TAP/P buttons retire only source-owned holds. The3000 manufacturer page’s SSL link contains only a Radius1000 definition, so it is not treated as a3000 protocol source.

No native Sync toggle is assigned to a BPM display or one-off match control. Normal three/four flash buttons provide native Hot Cues. Revision/preset/mode discovery, other encoder formats and ranges, hardware paging, remaining FX/sample/scratch/advanced modes, full lights/screens/lifecycle/recovery, USB/Link/OS/audio routing and physical/iPad/A10X acceptance remain open. No output, setup, identity query, preset, driver, firmware, executable, mapper or audio-route command runs. The existing Radius2000 recipe remains unchanged.

Validation:385 source checks and20 focused native tests pass. Coverage includes distinct version identities, own release offsets, three/four Hot Cues, both momentary release forms at three velocities, NOTE versus relative navigation,2009 calibrated jog/pitch/pickup, source-owned TAP/paging cleanup, automatic3000 assignment/reassignment and inactive foreign sources/groups/functions. Real-WAV Cue/bend tests pass for all three new profiles and the existing2000. All three catalogue gates,202 automatic held-Cue recipes and25,204 native binding comparisons pass. The iPad framework compiled and its compact resource matches the source. All380 earlier recipes remain identical. Missing-profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r457/validation.json`.

The catalogue has383 recipes and555 physical models. Automatic core increases to247, with308 without it. First-protocol gaps decrease to134. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R458 — Independent DV2 USB manual mixer

The own manufacturer manual and manufacturer-hosted Leo_V definition qualify16 manual input rows. The definition identifies the catalogue DV2 entry as DV2 USB. The manual explicitly defines VR controls as Bn0..127 and switches as9n127/0. It does not establish a fixed factory MIDI channel. Ruling: accept the documented n without guessing a channel.

The core provides gain, three-band EQ and level for A/B. It also provides master, crossfader, headphone blend/level and two PFL buttons. Enable hardware MIDI first and keep fader reverse off. The profile requires an already available CoreMIDI source. Direct iPad USB operation and any required driver or bridge remain unqualified. A manufacturer Mac MIDI driver listing does not settle either question.

The manual mixer exception now permits at most two distinct A/B PFL note targets, alongside continuous controls. It requires manual accessory selection, unique numbers, absolute values, one continuous control and no modes, banks, setup, feedback or audio contract. Momentary/transport buttons, hidden-deck PFL targets, duplicates, alternate encodings and automatic profiles remain invalid. The existing32-input limit stays unchanged.

MIDI mode changes hardware mixing and audio ownership. The manual assigns software headphones to Core/ASIO3/4 in that mode. MIDI-off instead sends separate decks to1/2 and3/4. Automatic audio routing remains off until that mode is qualified. Mic, EQ kills, meter selection, talkover, reverse/curve controls and Q-Start remain inactive. Q-Start is not Play. Complete feedback/meters/lifecycle/recovery, source/DVS/input routing and physical/iPad/A10X acceptance remain open. No mapper, mode command, query, preset, driver, firmware or audio-route write runs.

Validation:387 source checks and17 focused native tests pass. Tests cover the bounded schema, manual identity,14 continuous controls on16 channels, both PFL release forms at three velocities, source-owned pickup/rearming and inactive functions/groups/sources. Existing KUT restrictions and real-WAV checks pass. DV2 level/master/PFL retain finite synced playback. All three catalogue gates,202 automatic held-Cue recipes and25,220 native binding comparisons pass. The iPad framework compiled and its compact resource matches the source. All383 earlier recipes remain identical. Missing-feature/profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r458/validation.json`.

The separate M70 manual has legible numeric tables, but the checked text does not explicitly identify input status bytes. Direct PDF downloads returned403 and screenshot retrieval failed. No CMX-2000 protocol equivalence is inferred. Its public table excerpt is retained as research evidence. The ELMC1 manufacturer page returned429, so that request was not repeated.

The catalogue has384 recipes and555 physical models. Automatic core stays247, with308 without it. First-protocol gaps decrease to133. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R459 — Independent DJinn players and manual Mode3 mixer

The own manufacturer v3 English manual qualifies64 automatic common-player inputs and a separate90-input manual Mode3 layout. Each has14 optional normal lamps. The manual declares default channels1-2-3 for A-mixer-B and Hold TAP. Native therefore uses raw0/2 for players and raw1 for the manual mixer. No additional physical-model record is created for Mode3.

All three MIDI/audio modes provide player controls. Mode2 excludes mixer MIDI. Mode1 excludes crossfader/master MIDI. The automatic profile therefore contains only common player controls. It provides Play, held Cue/bends, Keylock, four Hot Cues, normal loops, Load and relative native track/group browse. The manual explicitly defines encoder offset64, with positive3 and negative15 examples. Both normal/TAP browser families deliberately retain the same native assignments. Folder push opens a group. Track push loads its own deck.

Explicit plus63 release aliases preserve held ownership and button rearming. TAP33 retires only its source-owned deck holds. CuePlay30 does not become held Cue. SGL/CTN and BPM do not toggle native Sync. Fourteen optional127/0 lamps cover Play, Cue, Keylock and four red Hot Cues per deck. Green/mode/meter outputs remain inactive.

The manual Mode3 profile adds26 gain/EQ/level/master/crossfader/headphone-level input rows. It preserves the own asymmetric left/right CC numbers and both published wire families. Mode3 is controller-only and disables internal USB/Input audio use. Configure separate app audio. Cue Pan blends hardware channels1/2, so it does not become native Cue/Master blend. No PFL selector is invented.

Jog calibration and complete cue/vinyl/classic modes remain unqualified. No isolated touch hold is added without motion. Pitch polarity/range, source/menu/channel/preset discovery, sample/save/clear/loop-pad/FX/kill/centre/mic/booth/relay/meter/fader-start/curve controls remain open. Full feedback/screens/lifecycle/recovery, USB/Link/OS/audio/DVS routing and physical/iPad/A10X acceptance also remain open. No setup, query, mode change, preset, driver, firmware or audio-route write runs. Other Audiophony/Voxoa/OEM protocols are not inherited.

Validation:389 source checks and13 focused native tests pass. Tests cover mode identities, optional lamps, raw0/2 deck ownership, shifted rearming, both momentary releases at three velocities, four Hot Cues and relative browser families. They also cover26 manual mixer rows/pickup, automatic mixer exclusion, source-owned TAP cleanup and inactive functions/channels/groups/sources. Real-WAV checks retain finite synced playback in both profiles. All three catalogue gates,203 automatic held-Cue recipes and25,374 native binding comparisons pass. The iPad framework compiled and its compact resource matches the source. All384 earlier recipes remain identical. Missing-profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r459/validation.json`.

Own NI AUDIO6/10 manuals were also recovered. Both manuals document headphone MAIN monitoring and default Direct Thru on A/B. The AUDIO10 headphone source can also select incoming audio. The current fixed split route is not inferred from AUDIO2MK2. Mode, source, channel-map and direct-through ownership remain separate work.

The catalogue has386 recipes and555 physical models. Automatic core increases to248, with307 without it. First-protocol gaps decrease to132. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R460 — Independent DJazz Pro and DJam Ultimate factories

Separate manufacturer manuals and separate Atomix factory definitions qualify DJazz Pro (catalogue DJAZZ, code9923) and DJam Ultimate (catalogue DJAM, code9924). Each factory archive was read as data. No mapper or executable ran. Neither profile inherits DDC-2000 or another model's protocol. The own jog scales differ:150 counts per turn for DJazz and800 for DJam.

DJazz gains211 automatic core inputs and36 optional normal lamps. DJam gains157 automatic common-player inputs and32 optional lamps. A separate213-input manual DJam CTRL MIDI mixer layout has36 lamps. The rear MIXER STATUS switch changes mixer ownership, so automatic DJam support excludes mixer/PFL/global browser controls. The manual layout requires MIDI mixer mode, software source and normal reverse/curve settings. Configure audio separately. These are variants of existing catalogue models, with no new physical-model records.

The published factory mappings use raw0..3 for A/B/C/D and global0. Both manuals establish Hold Shift as default. Other saved channel presets remain unqualified; no preset is written or queried. C/D require app opt-in. Normal transport, held Cue/bends, four Hot Cues, loops/size, calibrated normal jog/contact, native tempo and Load retain explicit shifted release aliases. Shifted Hot Cues1/2 perform native -4/+4 beat jumps. Deck17/67 retires only its source-owned physical deck pair. Normal jog/tempo/loop size and Mid/Low use Shift guards. Full layouts add mixer pickup, Shift filter and relative native track/group browse. DJam master12/42 is supported only in its manual mixer layout. DJazz master remains inactive because its own manual does not corroborate the extra XML rows.

The MIDI chart does not list AutoLoop feedback, so no lamp is invented. Delete is not treated as a held modifier. Complete search/scratch/range/FX/sample/key/kill/delete modes, saved settings/discovery, full feedback/screens/lifecycle/recovery, USB/OS/power/audio/DVS routes and physical/iPad/A10X acceptance remain open. No setup, identity query, source-mode, preset, driver, firmware or audio-route write runs.

Validation:391 source checks and16 focused native tests pass. Parameterised native cases cover all three layouts, normal and shifted releases, three momentary velocities, four deck pages, Hot Cue/jump separation, pickup, source-owned deck cleanup, C/D opt-in, inactive functions/channels/groups/sources and distinct jog scales. Separate checks enforce the common-player mixer exclusion and DJam-only manual master. Real-WAV checks retain finite synced playback in all three layouts. All three catalogue gates,205 automatic held-Cue recipes and25,955 native binding comparisons pass. The iPad framework compiled and its compact resource matches the source, with the full review file excluded. All386 earlier recipes remain identical. Missing-profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r460/validation.json`.

The catalogue has389 recipes and555 physical models. Automatic core increases to250, with305 without it. First-protocol gaps decrease to130. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R461 — Original Audiophony PLAY manual note core

The own VIRTUALITY-PLAY manufacturer guide9280 v1 June2008 has a visual MIDI diagram on p11. Grey circles identify decimal Note numbers; outlined circles identify CC numbers. Eight unambiguous note inputs provide Play53, main Cue52, Key/Master Tone29, loop In38/Out-or-Exit37/Reloop36 and bends33/32. START CUE51 is a separate function and is not held Cue. BPM54 does not change saved native Sync.

This is a manual single-player A subset. Select SOURCE=MIDI, rather than HID, and remain on hardware DECK A. The guide describes RELAY switching hardware A/B but does not qualify its wire/channel state contract. RELAY47/56 only retires source-owned native holds; it does not select a deck. The existing bounded player contract accepts the unspecified MIDI channel without inventing a default. Automatic identity, the hardware B bank and a CDMP700 protocol equivalence remain unqualified. Bare PLAY and CDMP700 aliases are excluded from this profile's alias list.

Dual-number memory Cue buttons, jog/contact calibration, relative track format, pitch polarity/range, source/menu/FX/start/brake/search controls and all output bytes remain inactive. Complete physical edge behaviour, modes, lifecycle/discovery/recovery, USB/OS/power/audio/DVS and physical/iPad/A10X acceptance remain open. Requires an exposed CoreMIDI source and separate app audio. No setup, HID report, identity query, source-mode, bank, firmware, driver or audio-route write runs. No sibling or OEM protocol is inherited.

Validation:393 source checks and10 focused native tests pass. They cover the manual identity, eight own note addresses on16 channels, duplicate press rearming, three held-button velocities, both release forms, source-owned RELAY cleanup and inactive functions/groups/sources. Real-WAV Cue/bend release retains finite synced playback. All three catalogue gates,205 automatic held-Cue recipes and25,963 native binding comparisons pass. The iPad framework compiled and its compact resource matches the source, with the full review file excluded. All389 earlier recipes remain identical. Missing-profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r461/validation.json`.

The current NI support site lists an official TWELVE MK2 mapping. Its exact linked download returned404 through both web retrieval and curl. No mapping or motor/platter bytes were recovered from that listing.

The catalogue has390 recipes and555 physical models. Automatic core remains250, with305 without it. First-protocol gaps decrease to129. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R462 — External audio mixers are not MIDI controllers

The PTB-2 manufacturer manual/product specifications and official software-integration support identify an external4x4 USB audio mixer. Its own hardware controls do not send MIDI. Bluetooth supplies audio. The Xone:23C manufacturer guide is also explicit: it sends no MIDI on its own. X:Link powers and passes MIDI from a separate K1/K2. It does not expose the mixer's controls. The separate Xone:43C has its own documented MIDI controls; none are inherited by23C.

Both records now identify their external-audio role and required native audio/DVS work. They gain no controller recipe, automatic route, automatic control, complete-support flag or hardware acceptance. The historical protocol-needed implementation status still denotes unresolved native integration. It does not mean these two mixers need MIDI maps. The catalogue report now identifies this reviewed distinction.

Native external deck-A/deck-B output routing and DVS inputs remain unimplemented for both models. The existing master/headphones split is not equivalent. PTB-2 needs the correct host/input-source, power and adapter states. Xone:23C sends record1/2 and FXsend3/4 by default; DVS input use needs the documented internal harness configuration. No hardware configuration, internal modification or driver installation is performed. The23C Mac driver discussion does not establish direct iPad compatibility. USB/OS, exact channel ownership, lifecycle/recovery, DVS calibration and physical/iPad/A10X acceptance remain open.

Validation:395 source checks pass, including both audio records, source hashes, absent runtime profiles and open support gates. Both full and compact runtime resources are byte-identical to committed R461. No Swift code or app behaviour changed, so native checks and framework compilation were not repeated. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r462/validation.json`.

The catalogue remains390 recipes and555 physical models. Automatic core remains250. The129 records with protocol-needed status include these two audio-only integrations. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R463 — Independent Xone:43C faders and Cue states

The own manufacturer AP9967 issue2 guide pp21..23 qualifies eight manual native inputs. Default channel16/raw15 is explicit. Physical CH1..4 faders send CC0..3 with0..127 and map to native A..D with pickup. C/D require app opt-in. Own Cue states use Notes77/57/37/17, independently transcribed from hex4D/39/25/11. Positive states set PFL on; both Note Off forms set it off. Repeated positive reports do not toggle it. These are headphone Cue states, not held main Cue.

The faders and switches also change analogue audio. The profile therefore requires deliberate manual selection and separately configured app audio. It does not take automatic ownership of an external mixer or duplicate its attenuation by default. Received MIDI can change real hardware Cue/filter states, so no lamp, setup or other output packet is sent. The analogue crossfader, EQ/gain/filter-frequency/headphone/master knobs are not invented as MIDI controls. No Xone:23C/24C/PX5/96 map is inherited.

Ten other documented MIDI controls remain inactive: Mic Cue92/Mic On93, channel-filter73/53/33/13, X:FX4 and HPF/BPF/LPF1/2/3. Their analogue mic/filter/FX states need separate native functions. The note-conversion appendix has errors; the explicit hex packet table is used. Saved MIDI-channel discovery, complete controls/modes/feedback/lifecycle/recovery, USB/X:Link/OS/power/audio/DVS routes and physical/iPad/A10X acceptance remain open. No preset, hardware state, driver, firmware, internal jumper or audio route is changed.

Validation:397 source checks and10 focused native tests pass. They cover identity/manual ownership, four-deck opt-in, asymmetric state notes, duplicate state reports, both off forms, fader pickup per source and inactive channels/functions/groups/sources. The real-WAV test checks fader pickup, idempotent Cue states and finite synced audio. All three catalogue gates,205 automatic held-Cue recipes and25,971 native binding comparisons pass. The iPad framework compiled; its compact resource matches the source and excludes the full review file. All390 earlier recipes remain identical. Missing-profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r463/validation.json`.

The catalogue has391 recipes and555 physical models. Automatic core remains250, with305 without it. Protocol-needed records decrease to128, including two reviewed audio-only integrations. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R464 — Owner-reported NS7III EQ subset

The primary djcmd project at commit0f8830a2d886450e81e07cd7b957d6ebe4a4856f explicitly identifies twelve EQ addresses as hardware-probed. Its map and decoder qualify normal absolute EQ roles on raw0: CH1 low9/mid10/high11, CH2 low14/mid15/high16, CH3 low20/mid21/high22 and CH4 low25/mid26/high27. Physical strip order is3/1/2/4; logical CH1..4 map to native A..D. C/D require app opt-in. Every knob retains source-owned pickup.

These are owner-reported observations from a project that describes itself as AI-assisted. They are scoped community evidence. They do not establish a manufacturer wire specification or native hardware acceptance. The source marks other values as unconfirmed by capture; those values are excluded. No upstream code or map is bundled or executed. Only the twelve factual assignments are transcribed.

The native profile is manual and uses only7-bit coarse high-byte values. The upstream decoder has14-bit EQ paths, but the published map does not identify the EQ low-byte addresses. No plus32 guess is made. Higher resolution remains open. Numark's own v1.1 guide independently qualifies PC-only MIDI source and normal EQ versus Touch/TouchLock kill functions. Use PC source and normal EQ with those modes inactive. A CoreMIDI source must already be exposed, directly or through a separately qualified bridge. Direct iPad USB/driver support remains unqualified.

Gain/level/filter/crossfader, transport, pads, source/layer/Touch state, motors/platter calibration, screens/feedback, complete lifecycle/recovery, USB/OS/power/audio/DVS and physical/iPad/A10X acceptance remain open. No motor, heartbeat, setup, lamp, screen, query, preset, driver, firmware or audio-route packet is sent. NS7 and NS7II mappings are not inherited.

Validation:399 source checks and9 focused native tests pass. They compare every active wire with the pinned source, preserve the source hashes and keep the inventory distinction between a partial profile and full support. Native cases cover all twelve knobs, four-deck opt-in, normalised coarse values, source-owned pickup and inactive channels/functions/low-byte candidates/groups/sources. The real-WAV test checks all three A-deck EQ bands and finite synced playback. All three catalogue gates,205 automatic held-Cue recipes and25,983 native binding comparisons pass. The iPad framework compiled; its compact resource matches the source and excludes the full review file. All391 earlier recipes remain identical. Missing-profile and obsolete inventory-expectation failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r464/validation.json`.

The catalogue has392 recipes and555 physical models. Automatic core remains250, with305 without it. Protocol-needed records decrease to127, including two reviewed audio-only integrations. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R465 — Original i-Mix normal core from intact publisher data

The public djDecks DX1.02 archive includes a separate `devices/djtech_imix.xml`. Its descriptor identifies i-Mix and MIDI endpoint DJ-Tech i-Mix. The top-level name incorrectly says Kontrol One; that name is not used as model evidence. The publisher's own controller documentation separately identifies i-Mix support. The manufacturer combined i-Mix/Club Edition manual supplies the indexed note/CC table and physical layouts. JPEG source files are page backgrounds; the cached numeric table is indexed web text, not a complete PDF or a PDF hash.

The normal root objects before the lower-case pitch tabs parse strictly without source repair. Those intact objects qualify31 manual native inputs on raw0. Paired A/B notes are Play20/55, held Cue13/48, In1/36, Out8/43, Reloop15/50, bend-/+14/22 and49/29, and PFL17/24. Absolute mixer inputs are A gain72/high69/mid70/low71/level67, B gain75/high76/mid74/low73/level66 and cross65. Four positive-only note wires explicitly scroll the active playlist: Down82/80 and Up83/81. Native uses repeated track-browse pulses. No relative-CC encoder format is guessed.

Four source XML errors at lines627/655/656/695 occur in unused jog tabs. Those sections are not imported. Source scripts, conditions and keyboard actions do not execute. The profile requires manual selection. Complete software-tab modes, stored state/discovery and the whole source archive are not qualified. Motion/contact, pitch/range, Hot Cues/modifiers, encoder-push selection, one-off MatchBPM/PitchReset, alternate faceplate key functions and kill/reset controls remain inactive. The shared INPUT_OUTPUT objects alone do not qualify native lamp polarity and lifecycle, so no feedback is sent. No Reload/MKII/Kontrol One protocol is inherited.

Requires an exposed CoreMIDI source and separately configured app audio. Full USB/OS/power/audio/DVS routes, lifecycle/recovery and physical/iPad/A10X acceptance remain open. No source mapper, installer, driver, firmware, query, preset, keyboard injection, source-mode or audio-route command runs.

Validation:402 source checks and12 focused native tests pass. Every active wire is compared with a strictly parsed intact publisher object. Tests also retain source hashes, exact manual identity, asymmetric A/B buttons, three held-button velocities, both release forms, source-owned holds/pickup, eleven mixer rows, repeated browse pulses and inactive modes/channels/functions/groups/sources. The real-WAV test checks Cue/bend release, mixer pickup and finite synced playback. All three catalogue gates,205 automatic held-Cue recipes and26,014 native binding comparisons pass. The iPad framework compiled; its compact resource matches the source and excludes the full review file. All392 earlier recipes remain identical. Missing-profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r465/validation.json`.

The catalogue has393 recipes and555 physical models. Automatic core remains250, with305 without it. Protocol-needed records decrease to126, including two reviewed audio-only integrations. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R466 — Publisher-paired ABMA4 and DJ KONTROL1 cores

The verified public PCDJ DEX4.0.0 build98 archive supplies131 controller files. The archive and its controller scripts were read as data; no installer, application or script ran. Beyond__Abm4.js explicitly pairs ABMA4 with JB Systems DJ-kontrol1 no-audio. Its callback ignores the separately supplied MIDI channel. Two separate manual identities each expose33 unique normal inputs, accepting all16 channels. Stored channel0 is a placeholder, not a factory-channel claim. Reported USB/SysEx identifiers remain evidence; they do not enable native matching or queries.

Each deck has Play, held Cue/bends, Sync, Keylock, Load/PFL, loop half/double and five absolute mixer controls. Global headphone mix/level and the inverted crossfader retain publisher roles. The native schema permits this manual unbanked two-deck subset only when every number and action is unique, required transport/mixer roles exist and targets/kinds match. It rejects automatic selection, modes/banks/modifiers, special encodings, setup, outputs and audio routing. Existing mixer and player boundaries remain intact. Conditional pads/Smart Loop, In/Out/Reloop, jog/touch/vinyl, tempo, FX and browser stay inactive. Their complete modes/calibration are not qualified. No ABMA1/2/3 or KONTROL2/3/3S/4 protocol is inherited.

Validation:405 source checks and14 focused native tests pass. Tests cover both identities, all16 channels, asymmetric buttons, both held release forms, three velocities, source ownership, all13 mixer rows with pickup, crossfader inversion and inactive functions/groups/sources. The real-WAV test checks held releases, mixer pickup and finite synced playback. The new schema guard and both earlier mixer guards pass. All three catalogue gates,205 automatic held-Cue recipes and26,080 native binding comparisons pass. The iPad framework compiled; its compact resource matches the source and excludes the full review file. All393 earlier recipes remain identical. TDD failures and the corrected global-target predicate failure remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r466/validation.json`.

The catalogue has395 recipes and555 physical models. Automatic core remains250, with305 without it. Protocol-needed records decrease to124, including two reviewed audio-only integrations. Full theoretical support remains0/555. Automatic identity, complete modes/feedback/lifecycle/recovery, exact USB/driver/OS/power/audio/DVS and physical/iPad/A10X acceptance remain open. The wider manufacturer audit is incomplete.


## R467 — Independent G4V owner-chart mixer

The primary owner chart posted by khan.cross on29June2016 explicitly names the G4V and shows all four physical strips in order3/1/2/4. The separate manufacturer-branded Traktor layout corroborates normal mixer roles. Twenty-four fixed channel4/raw3 CC positions provide logical CH1..4 gain1..4, mid5..8, high9..12, low13..16, filter17..20 and level21..24. Native targets A..D retain source-owned pickup and C/D opt-in. This is a manual seven-bit normal mixer subset. The chart is owner-reported protocol evidence, not a manufacturer numeric specification or native device test.

The separate owner Deck-B TSI was inspected as data. Its player/FX/pad assignments do not supply missing mixer protocol facts. Transport/Cue, deck switching/modifiers, pads/loops/FX, pitch/jog/touch calibration, crossfader/globals, feedback/meters and full lifecycle/recovery remain inactive or open. No G2V/Slate addresses, factory identity, driver, preset, setup, query, output or audio route is inherited or sent. Complete USB/OS/power/audio/DVS and physical/iPad/A10X acceptance remain open.

Validation:407 source checks and9 focused native tests pass. Tests cover exact manual identity, all24 mixer addresses, pickup per source, four-deck opt-in and inactive channels/functions/groups/sources. The real-WAV test checks all six A-strip controls and finite synced audio. All three catalogue gates,205 automatic held-Cue recipes and26,104 native binding comparisons pass. The iPad framework compiled; its compact resource matches the source and excludes the full review file. All395 earlier recipes remain identical. Missing-profile failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r467/validation.json`.

The catalogue has396 recipes and555 physical models. Automatic core remains250, with305 without it. Protocol-needed records decrease to123, including two reviewed audio-only integrations. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R468 — G4V primary-author manual banks

Primary author Javier Vilarroig supplies an independent G4V XML/mapper at PR4323 head c7826ca66632be6c88b5138cf2d07ab42726f7fb. The PR remains open and unmerged. It supplies protocol evidence; it does not establish released Mixxx support. Every active native wire has an explicit assignment in its XML. No source script or component code executes or ships.

The existing G4V profile expands from24 to39 manual inputs. Normal raw0/1 Play1, held Cue2, Sync4 and Keylock5 use native A/C and B/D banks. Positive Note38 toggles its own side. Apply/reconnect starts A/B. Native does not drive the bank lamps; they are not a native state indicator. Four raw3 PFL Notes13..16 stay on fixed A..D. Global masterCC27/cueMix26 are normal; crossCC25 is explicitly inverted. C/D require app opt-in. The earlier24 mixer rows remain intact as player banks change.

The source mapper volumePot constant overlaps filterCC17..20. Its separate XML and the owner chart independently confirm levelCC21..24, which native retains. Duplicate low-pot construction and source FX/shutdown writes are not copied. CUP3 does not become held Cue. Load/eject/Shift, pads/loops/FX, tempo/jog/touch calibration, browse formats, orientation, booth/monitor and complete feedback/lifecycle/recovery/audio/host remain inactive or open. No factory identity, source state, driver, preset, hardware setup or audio route is inferred.

Validation:408 source checks and14 focused native tests pass. Tests cover both native banks, side independence, three Cue velocities, both off forms, owned hold cleanup across sources, manual reapply reset, C/D opt-in, fixed PFL targets, inverted crossfader, all mixer pickup and inactive reports. Two real-WAV tests check held Cue release, six mixer controls and finite synced playback. All three catalogue gates,205 automatic held-Cue recipes and26,119 native binding comparisons pass. The iPad framework compiled; its compact resource matches the source and excludes the full review file. All395 other recipes and all24 prior G4V mixer rows remain identical. Missing-bank TDD evidence is retained. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r468/validation.json`.

Counts remain396 recipes,555 physical models,250 automatic core models and123 protocol-needed records, including two reviewed audio-only integrations. Full theoretical support remains0/555. The wider manufacturer audit and physical/iPad/A10X acceptance remain open.


## R469 — Independent DJ-808 normal MIDI core

Primary contributor peter-vincze supplies own-model DJ-808 XML/mapper at open, unmerged PR15063 head e1f90cde7a2904ae4c9de48614d1df85d3f2e34a. Its numeric input assignments qualify113 manual native rows. Own Roland revision03 guide p21 confirms standalone controller MIDI through the PC port; DIN MIDI OUT carries synchronisation. The PC USB connection requires a driver. This profile needs an already available CoreMIDI source or independently qualified bridge. Direct iPad USB remains unqualified.

Raw0..3 normal Play0, held Cue1, native Sync2 and Keylock13 retain shifted negative aliases4/5/3/14 and opposite-bank release aliases. Global Shift is raw15 Note0. Positive shifted transport remains inactive. Native Sync uses the existing app toggle; it does not import the source short/long-press leader/quantise behaviour. Explicit14-bit pairs are gain22/52, high23/53, mid24/54, low25/55 and level28/58 on each deck. XML inputMSB/inputLSB keys establish byte roles despite copied description errors. The source EQ output constants conflict with its input XML; native uses explicit input assignments and indexed EQ roles, and sends no feedback. FilterCC26 and PFLNote27 are normal Shift-guarded controls. Raw4..7 Reloop51/Half52/Double53/In56/Out57 use native loop functions. Own raw0/1 Note8 selectors retire source-owned A/C or B/D holds/pickup without inventing software banks. C/D require app opt-in.

Standalone mixer controls can also change hardware audio. Separate app audio and PC input selection remain necessary. Native sends no source SysEx or periodic keepalive. Shared Load ownership, dual-deck mode, tempo polarity/range, crossfader maximum16368, jog/touch calibration, pads/FX/TR-S/VT, full controls/modes/feedback/lifecycle/recovery, USB/driver/bridge/OS/power/audio/DVS and physical/iPad/A10X acceptance remain open. No DJ-202/505/707M protocol or identity is inherited. No source script/component code, preset, driver, firmware, mode or audio-route write runs.

Validation:411 source checks and13 focused native tests pass. Every positive input and both bytes of all20 mixer pairs have explicit own-model XML assignments. Native checks cover four-target opt-in, pair assembly/pickup/source ownership, Shift/opposite-bank Cue releases, three velocities, selector cleanup, loop/filter/PFL separation and inactive modes. The real-WAV test checks Cue release, five paired mixer controls and finite synced playback. All three catalogue gates,205 automatic held-Cue recipes and26,232 native binding comparisons pass. The iPad framework compiled; its compact resource matches the source and excludes the full review file. All396 earlier recipes remain identical. Missing-profile TDD and the corrected test parser omission for unrelated pitch/system messages remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r469/validation.json`.

The catalogue has397 recipes and555 physical models. Automatic core remains250, with305 without it. Protocol-needed records decrease to122, including two reviewed audio-only integrations. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R470 — Manufacturer Dragon Two and 4MIX Pitch cores

The own DJ-Tech download page supplies two separate factory archives: Dragon2_Virtual-DJ_20120104.zip and4MIX_Virtual-DJ_20120521.zip. Each device definition and mapper parses strictly. Only protocol facts are transcribed. Atomix channel attributes are zero-based, so explicit channels1..4 remain raw1..4. Header comments do not override numeric attributes. Both profiles require manual selection and separately configured app audio; C/D require app opt-in.

Dragon Two has220 inputs. Its normal Play23/held Cue22/Sync16/Load8/PFL9, In13/Out14/Reloop15, bends11/12 and four Hot Cues17..20 use four explicit target channels. Shift24 retains two physical side identities across A/C and B/D aliases. Explicit shifted negative addresses and opposite-bank negatives preserve native release/rearm. Absolute gain8/high25/mid26/low27/filter28/level9 retain pickup. Use four-deck MIDI mixing; analogue/two-deck ownership remains unqualified. Source CUE cue_play is replaced by native held Cue semantics; source CUP is a separate expression. No Keylock, jog/pitch calibration or loop-encoder direction is invented.

4MIX has164 inputs for the own Pitch layout named DJ-Tech4-Mix Pitch. Play12/held Cue11/Sync5/In2/Out3/Reloop4 and four Hot Cues6..9 use raw1..4. Shift14, positive alternate beatlock/clear/loop actions and CUP remain separate. Only explicit alternate negative wires are release guards. Jog and pitch use relative jog elements in this definition; they do not become an absolute tempo slider. Native does not claim compatibility with every preset.

Channel-omitted globals, mixer/Load/PFL rows on4MIX, both global selectors/library/headphone controls, Dragon CHANGE_CENTER and all outputs remain inactive. No default global channel is guessed from an absent attribute. Positive shifted native commands are inactive. Complete modes, controls, feedback/lifecycle/recovery, USB/driver/OS/power/audio/DVS and physical/iPad/A10X acceptance remain open. No mapper action, source program, hardware setup, query, preset, driver, firmware, mode or audio-route write executes or ships.

Validation:414 source checks and13 focused native tests pass. Every active and negative alias wire exists in its own manufacturer definition. Tests cover both identities, raw channels, four-target opt-in, normal buttons, three Cue/bend velocities, both off forms/opposite-bank aliases, shared physical Shift identities, four Hot Cues, manual reapply hold cleanup, Dragon mixer pickup and inactive wires/sources/groups. Two real-WAV cases check held Cue release, Dragon level pickup and finite synced playback. All three catalogue gates,205 automatic held-Cue recipes and26,616 native binding comparisons pass. The iPad framework compiled; its compact resource matches the source and excludes the full review file. All397 earlier recipes remain identical. Missing-profile TDD remains in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r470/validation.json`.

The catalogue has399 recipes and555 physical models. Automatic core remains250, with305 without it. Protocol-needed records decrease to120, including two reviewed audio-only integrations. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R471 — Independent GMX MIDI core

Primary owner codecat supplies MIDI XML, numeric Midi Spec and separate HID files at67f88e747bd8c8e04048f29945e7d87506e863f1. The project is work-in-progress and documents MIDI limitations. These are community protocol facts, not manufacturer numeric approval or native hardware acceptance. Own GMX manual separately confirms that mode changes stop standalone playback. Native never switches hardware mode. Manual existing MIDI input and separate app audio are required. GMX DRIVE/G2V/G4V remain separate models.

The46-input native subset uses raw0/1 deck controls and raw3 globals. Normal Play1/held Cue2/Reloop5/Keylock19/Load28/PFL34 use app actions. Explicit loop In3/Out4 and shifted half8/double7 retain both positive roles and negative aliases that rearm normal loop buttons. Range20 only rearms Keylock. Shift43 guards normal actions. TempoCC1 is inverted and follows the app range; physical range/discovery stays open. FilterCC4 follows the XML continuous super1 role, rather than treating the prose endpoint typo as a binary switch. Raw3 gain1/2, mid3/4, high5/6, low7/8 and level9/10 are normal. Cross11/cueMix12/master13/monitor14 are explicitly inverted in both sources.

Hot Cue/Auto Loop modes, all pads/clears, TAP/Lock/AutoCue/repeat/search/reverse/scratch, booth, meters/screens/HID and complete feedback/lifecycle/recovery/audio/host remain open. Relative jog/browser edge64 differs between prose and script, so no encoding or calibration is guessed. Source LED-clear loops do not run. No upstream mapper/script code, setup, query, preset, hardware-mode, driver, firmware, output or audio-route packet executes or ships.

Validation:417 source checks and12 focused native tests pass. Every positive wire is qualified by the own-model XML or numeric notes. Tests cover manual identity, normal button rearming, three Cue velocities/both releases, Shift loop aliases, all18 absolute inputs with pickup/six inversions, source-owned hold/pickup, manual reapply cleanup and inactive wires/sources/groups. The real-WAV test checks held Cue release, five mixer controls and finite synced playback. All three catalogue gates,205 automatic held-Cue recipes and26,662 native binding comparisons pass. The iPad framework compiled; its compact resource matches the source and excludes the full review file. All399 earlier recipes remain identical. Missing-profile TDD remains in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r471/validation.json`.

The catalogue has400 recipes and555 physical models. Automatic core remains250, with305 without it. Protocol-needed records decrease to119, including two reviewed audio-only integrations. Full theoretical support remains0/555. The wider manufacturer audit and physical/iPad/A10X acceptance remain open.


## R472 — GMX pad contribution conflicts

Reviewed the open, unmerged primary contribution codecat/mixxx-gemini-gmx PR2 at5f53a3f21317f901cbc73080c05906bd4ec965f4. The code assigns an automatic-loop mode toggle to Note8, which the earlier numeric notes identify as shifted loop-half. Its loop-pad sizes1..128 also differ from the manufacturer guide1/8..16. Two booleans start false without a hardware-state report and can both remain true. These conflicts do not qualify native pad state, loop sizes or a new mode contract. No contribution code runs or ships.

The R47146-input GMX core, both runtime resources and catalogue JSON remain byte-identical.417 source checks pass. Native/framework checks are not repeated for this audit-only change; R471 retains that evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r472/validation.json`. Pads/modes, GMX DRIVE/HID equivalence, full theoretical support and physical acceptance remain open. Catalogue counts remain400 recipes,555 physical models,250 automatic core models and119 protocol-needed records, including two reviewed audio-only integrations.


## R473 — Explicit steady legacy lamps

The already pinned own definitions qualify68 optional steady lamps. Dragon Two has32 Play/Cue/Sync/PFL/Hot Cue lamps;4MIX has28 Play/Cue/Sync/Hot Cue lamps. Their explicit raw1..4 note addresses stay separate. GMX has eight own-MIDI-XML Play/Cue/Keylock/PFL lamps on raw0/1. Native sends Note On127 for on and Note On0 for off. Every output corresponds to an implemented input action and its own source output definition.

These are steady native app states. Source blinking, beat states, manual-loop lamps, meters/rings, pad modes, filter/source selectors, displays/HID and complete output lifecycle remain open. No source reset loop or startup/shutdown sequence is added. Manual input selection remains separate from output selection. Loading the light profile leaves feedback disabled until explicitly enabled.

Validation:419 source checks and24 focused native tests pass. Tests cover every lamp address/target/value, all three full-versus-compiled output arrays and explicit feedback selection/enablement. Existing Dragon Two/4MIX/GMX input suites, held releases, pickup, three real-WAV cases and catalogue gates pass. All400 input layouts and all397 other recipes remain identical;26,662 native input bindings still match the compact resource. The iPad framework compiled; its compact resource matches the source and excludes the full review file. Missing-lamp TDD remains in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r473/validation.json`.

Counts remain400 recipes,555 physical models,250 automatic core models,205 automatic held-Cue recipes and119 protocol-needed records, including two reviewed audio-only integrations. Full theoretical support remains0/555. The wider manufacturer audit and physical/iPad/A10X acceptance remain open.


## R474 — Own DAP D2 core and distinct Cue Stop

Own Highlite D1261 Core Kontrol D2 English V1 guide printed26–28 qualifies33 manual normal inputs. Its channel table does not establish a transmitted factory channel. The bounded manual two-deck core accepts channel changes; stored raw0 is a placeholder. Own Set Cue3B/44 is held preview. Separate Cue33/3C uses the new native Cue Stop action: return to the saved Cue and stop, including when already paused, without marking another Cue or changing the saved Sync choice. Play/Sync/Keylock/Load/PFL/bends and explicitly addressed loop-size/B Reloop controls use native actions. Eleven gain/EQ/level/cue-mix positions keep pickup.

The bounded manual schema now permits an absent crossfader and explicit Cue Stop/Reloop buttons. Mandatory A/B Play, held Cue and levels,7–33 unique wire numbers/actions, kinds, targets, absolute direction and all no-mode/no-output/no-setup restrictions remain. Crossfader direction is unqualified. The appendix omits A loop-double/reloop addresses; no sibling addresses are inferred. Master is analogue and has no MIDI. Received notes/CC are unsupported, so no feedback packets are sent. DAP D4i, NI Kontrol D2 and ABMA4 identities/protocols remain separate. Manual input and separately configured audio are required. Full modes, motion, USB identity/driver/OS/power, audio/lifecycle/recovery and physical/iPad/A10X acceptance remain open.

Validation:422 source checks and23 focused native tests pass. Tests cover every documented normal button, all16 channels, both negative release forms, held Cue/bends, source ownership,11 mixer positions/pickup and inactive wires/groups/sources. The Cue Stop real-WAV case verifies paused/playing/held-preview states without changing the saved Cue or Sync. The DAP WAV case verifies distinct Cue wires, pickup and finite synced playback. Existing schema/ABMA4 guards and all catalogue gates pass. All400 earlier recipes remain identical;26,695 native input bindings match the compact resource. The iPad framework compiled. Its compact resource matches source bytes and excludes the full review file. Missing-profile/unknown-action/schema TDD failures remain in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r474/validation.json`.

The catalogue has401 recipes and555 physical models. Automatic core remains250, with305 without it. Protocol-needed records decrease to118, including two reviewed audio-only integrations.205 automatic held-Cue recipes remain. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R475 — Independent CDMP-7000 owner player core

Primary owner djtrinidad supplies own-model XML and mapper at3236e2380a1b24c662fc58777d266b21f9cc46ec. The13-input manual player profile uses raw0 only. Its own XML identifies separate L/R endpoints using the same mapping. Both manual sources retain target A. Automatic identities and separate player assignments remain open. Normal Play02/held Cue01/bends03–04/Load0F/In10/Out11/Reloop12 use native actions. Note0B/0C provide repeated directional track browsing. Inverted absolute tempoCC21 keeps native pickup and the app range. JogCC20 uses explicit value-minus64 and128 counts per rotation at33⅓RPM. The same owner's earlier source independently agrees on128. Touch18 uses fixed native touch scratch. Hardware Vinyl selection and the source's intermittent scratch-state bug are not imported. Physical polarity, calibration, range and live feel remain unverified.

The XML assigns Master Tempo0D to sync_leader despite an unused SyncButton object. Native does not infer a Sync toggle. LOCK1C is not qualified Keylock. Memo08 uses contradictory channel definitions and a software toggle. All Hot Cues/clears remain inactive. DuplicateNote25, empty FX controls, source reset/timer/LCD commands and complete outputs/lifecycle stay inactive. No standalone mixer/audio route is invented. The README only reports CDJ-700 compatibility. No CDJ-700, CDMP-2700, GMX or MDJ protocol is inherited. USB identity/driver/OS/power/audio/DVS, complete modes/recovery and physical/iPad/A10X acceptance remain open. No upstream code or hardware configuration runs.

Validation:425 source checks and11 focused native tests pass. Tests cover own identity, normal buttons, three held-control velocities, both release forms, source ownership, repeated navigation,128-count decoding, inverted tempo pickup and inactive channels/wires/groups/sources. The real-WAV case checks held Cue, the expected128-count scratch displacement, release, tempo pickup and finite synced playback. All catalogue gates pass, including205 automatic held-Cue recipes and26,708 native input comparisons. All401 earlier recipes remain identical. The iPad framework compiled. Its compact resource matches source bytes and excludes the full review file. Missing-profile TDD remains in evidence. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r475/validation.json`.

Counts are402 recipes,555 physical models,250 automatic core models and117 protocol-needed records, including two reviewed audio-only integrations. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R476 — Original Seventy-Two unconditional owner subset

Primary mapping author Dj-Ush links a public free Dropbox folder in the original Seventy-Two video bKg_l15MP9E. Its Basic/Complete TSI files contain10/229 used rows. Read-only parsing and an explicit review of both CMAD modifier slots qualify seven unique unconditional input roles. No mapper, application, settings, installer or upstream code runs. Human channels5/6 become raw4/5. Parameter NoteE2/40 controls native Play A/B. NoteF2/41 controls native Sync A/B. Source comments and commandIDs100/125 establish these roles. Raw15 NoteD-1/2 and D#-1/3 load A/B. Raw15 CC0 is signed7F/01 Browse, with no inversion. Two identical used Browse rows become one input. Basic independently confirms Load/Browse.

The profile is manual and requires an exposed MIDI endpoint plus separate audio configuration. Both manual sources keep the explicit A/B targets. Native does not infer standalone mixer gain/EQ/faders from the hardware or confuse sampler gain with channel gain. Modal pads, held Cue, loops/Shift/sampler/FX, source controls, lamps/colours/blink/reset, screen/touchscreen and complete lifecycle/recovery remain open. No Seventy-Two MKII, Seventy, Performer, System One or Twelve protocol is inherited. Exact USB/channel/driver/OS/power/audio/DVS and physical/iPad/A10X acceptance remain open. This is a seven-control subset, not a full transport or zero-config claim.

Validation:428 source checks and10 focused native tests pass. Tests cover original-only manual identity, own channels/targets, both button releases, source-owned debounce, repeated signed Browse directions and inactive pad/mixer/wrong-channel/foreign-source/group messages. The WAV case verifies Parameter Play, continued finite playback during Browse and the saved Sync choice. An initial assertion expected one event for signed negative64. Native correctly splits it into negative63 and negative1. Only that assertion changed. The failed run remains in evidence. All402 earlier recipes remain identical. All catalogue gates pass, including205 automatic held-Cue recipes and26,715 native input comparisons. The iPad framework compiled. Its compact resource matches source bytes and excludes the full review file. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r476/validation.json`.

Counts are403 recipes,555 physical models,250 automatic core models and116 protocol-needed records, including two reviewed audio-only integrations. Full theoretical support remains0/555. The wider manufacturer audit and physical acceptance remain open.


## R477 — Independent MDJ-900 and native Hot Cue clearing

Primary contributor Peter Stein/LinuxGamesTV supplies own MDJ-900 XML and mapper atcfa171fa3f7e758e212fc6edb2c711dba3a4a8eb. This newly found physical model now has a23-input manual raw0 player-A core. Normal Play2/held Cue1/Sync52/Keylock19/Load9, In4/Out5/Reloop6/Half7/Double8, bend-minus18/plus17 and inverted tempoCC1 use native actions. The own manufacturer manual qualifies held Cue and temporary bends. Native bends preserve that physical role, rather than copying the mapper's permanent pitch-step customisation. Hot Cues38–41 and separate clear notes42–45 retain four slots. Note11/12 provides repeated track browsing.

Sixteen separate native clear actions cover eight slots for A/B and existing target-deck routing. They call the existing cue-deletion function only on a positive press. Clearing an empty marker cannot create one. These actions have no feedback state and do not reuse the main Cue controls. No earlier profile gains a guessed clear address.

The owner's credit to an MDJ-1000 project does not establish sibling compatibility. No MDJ-1000/500/600, GMX or CDMP protocol is inherited. Generic controller id gemini does not qualify automatic USB identity. Unlisted filter/alternate addresses and relative jog calibration remain inactive. Full Shift edge cleanup, hardware channel/deck paging, loop-roll/slip/reverse/search/grid/FX/Source/Link, range discovery, complete output/display/lifecycle/recovery and USB/driver/OS/power/audio/DVS remain open. Source reset loops use invalid note numbers225/255 and do not run. Manual MIDI input and separate audio are required. Physical/iPad/A10X acceptance remains open.

Validation:431 source checks and12 focused native tests pass. Tests cover own identity, all normal buttons/clears, held Cue/bend releases and source ownership, track pulses, inverted tempo pickup and inactive channels/wires/motion/groups/sources. The generic real-WAV case deletes all eight markers without moving transport, changing Sync or deleting neighbouring markers. Its initial fixture accidentally recalled an existing grid Cue and paused playback before deletion. A separate precondition run confirmed the error. Empty marker setup fixes the fixture and retains the active-playback requirement. The MDJ WAV case checks paused and playing clears, held Cue/bends, tempo pickup and finite synced playback. Missing-action/profile and failed fixture evidence remain preserved. All403 earlier recipes remain identical. Catalogue gates pass, including205 automatic held-Cue recipes and26,738 native input comparisons. The iPad framework compiled. Its compact resource matches source bytes and excludes the full review file. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r477/validation.json`.

Counts are404 recipes,556 physical models,250 automatic core models and116 protocol-needed records, including two reviewed audio-only integrations.306 models lack automatic core selection. Full theoretical support remains0/556. The wider manufacturer audit and physical acceptance remain open.


## R478 — Reviewed Hot Cue clear opcodes

Thirteen existing profiles gain130 dedicated clear inputs from their own hash-pinned Mixxx XML. They cover Compact, original Inpulse200/300, MIX, Starlight, KAOSS DJ and its Audioless profile, U-Mix Control2/Pro2, Dicer, Beatmix2/4MK2, DJC.4 and VCI-100MKII. Each wire already had one matching native negative guard and no active positive binding. The generator rejects missing guards, positive collisions, protocols, modes and unreviewed input fields. Dedicated clear opcodes carry their own role and work with either app Shift state. No sibling protocol or software pad mode is inferred.

All earlier inputs remain an exact prefix. Outputs, startup/shutdown, audio and aliases remain unchanged.391 other recipes remain identical. Complete pad modes, display/lifecycle, host routes and physical acceptance remain open. No upstream script executes.

Validation:434 source checks and81 focused native tests pass. Checks cover all130 clear wires, duplicate presses, both negative forms, normal Cue rearming and foreign source/group isolation. Three real-WAV cases preserve active playback, neighbouring markers, position and saved Sync. Older tests had stale sibling identity expectations, an obsolete MIX input count and a shifted jog scale absent from the baseline profile. Revised tests preserve the existing blocked search and248-count normal motion. They do not assume dictionary event order. Failed and interrupted runs remain in evidence. The iPad framework compiled. Its2,206,319-byte compact resource matches source and excludes the full review file. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r478/validation.json`.

Counts remain404 recipes,556 physical models,250 automatic core models and116 protocol-needed records, including two reviewed audio-only integrations. There are26,868 native binding comparisons and205 automatic held-Cue recipes.306 models lack automatic core selection. Full theoretical support remains0/556. The wider manufacturer audit and physical/iPad/A10X acceptance remain open.


## R479 — Independent Hot Cue pairs on three controller families

DDJ-SB3 and Terminal Mix2/4 each gain32 dedicated clear inputs. Jogvision gains16. Their own hash-pinned Mixxx XML defines each normal Note-On clear and activation role. Every activation wire exactly matches the earlier native slot and deck. The generator rejects active clear-wire collisions, protocol/mode changes and unreviewed input fields. Each pair also gains two negative aliases. A negative clear wire rearms its normal Hot Cue. A negative activation wire rearms its clear action. Dedicated clear roles do not require an inferred app Shift state.

All earlier inputs remain an exact prefix. Outputs, setup, audio and aliases remain unchanged.401 other recipes remain identical. Full pad modes, sampler/FX, display/lifecycle, host routes and physical acceptance remain open. No upstream script executes.

Validation:437 source checks and27 focused native tests pass. Checks cover all80 pairs, duplicate presses, both negative forms, either app Shift state and source/group isolation. Three real-WAV cases preserve active playback, position, neighbouring markers and saved Sync. An older Terminal Mix assertion needed its newly supported explicit Clear event. Its failed run remains preserved. The iPad framework compiled. Its2,218,024-byte compact resource matches source and excludes the full review file. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r479/validation.json`.

Counts remain404 recipes,556 physical models,250 automatic core models and116 protocol-needed records, including two reviewed audio-only integrations. There are27,108 native binding comparisons and205 automatic held-Cue recipes.306 models lack automatic core selection. Full theoretical support remains0/556. The wider manufacturer audit and physical/iPad/A10X acceptance remain open.


## R480 — MC4000 factory pads, temporary bends and Cue release

The own MC4000 user guide, printed pages5/30, qualifies four Hot Cues per deck and separate Shift clear notes. Raw channels4/5 use activation20–23 and clear28–31. Each pair has both negative aliases. Eight pad LEDs use factory blue1 and off0 at the normal addresses. Other colours, Pad Mode and sampler banks remain open.

Temporary pitch bends use factory minus12/plus11 on raw channels0/1. The pinned working XML assigns plus13, which conflicts with the factory Keylock address. Native retains Keylock13 and follows factory plus11. Shifted32/33 only release an existing bend. Shifted Cue5 only releases a normal held Cue. Positive shifted search and Track Start remain inactive. No mapper runs. Advanced modes, FX/meters, full lifecycle/audio/host and physical acceptance remain open.

All49 earlier inputs and10 earlier outputs remain exact prefixes.42 inputs and eight outputs are added.403 other recipes remain identical. Startup/shutdown, aliases, audio and tempo ordering remain unchanged.

Validation:440 source checks and15 focused native tests pass. Checks cover all pad pairs, duplicate presses, both negative forms, either app Shift state, source/group isolation and blue/off packet bytes. The real-WAV case verifies shifted held-Cue release, marker deletion, neighbouring markers, both bend releases, finite active playback and saved Sync. Initial checks exposed an overbroad Platinum assertion edit, negative guards counted as active collisions and a missing test MainActor annotation. Only those tests changed. Failed runs remain preserved. The iPad framework compiled. Its2,221,015-byte compact resource matches source and excludes the full review file. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r480/validation.json`.

Counts remain404 recipes,556 physical models,250 automatic core models and116 protocol-needed records, including two reviewed audio-only integrations. There are27,150 native binding comparisons and205 automatic held-Cue recipes.306 models lack automatic core selection. Full theoretical support remains0/556. The wider manufacturer audit and physical/iPad/A10X acceptance remain open.


## R481 — Original MDJ-1000 owner protocol subset

Primary owner Joakim Mattson published original MDJ-1000 MIDI-OX captures in his2017 university thesis, Appendix1. The repository exposes the table as web text. The thesis PDF is not downloaded. No PDF hash or visual table proof is claimed. A separate original48-page manufacturer manual is cached and hash-pinned. Printed pages9/11 were visually reviewed. The documented Recordcase copy succeeds after the Zzounds download returns403. This evidence is independent of MDJ-900, MDJ-500/600 and V2 sources.

The58-input manual raw0 player-A subset has32 positive roles and26 negative aliases. It covers Play, held Cue/bends, Sync/Keylock/Load, manual loops, four Hot Cues/clears, browse note pulses, inverted tempoCC1 and normal filterCC4. Eight normal-mode fixed loops cover0.125/0.25/0.5/1/2/4/8/16 beats. Use Loop Roll/Slip off. Dedicated alternate opcodes rearm their own action and argument without an inferred app Shift input. Native temporary bends follow the physical held function, rather than the owner's permanent rate-step customisation. Load targets manual A, rather than copying the owner's first-stopped-deck rule.

No automatic USB identity/channel assignment, motion calibration, reverse/search/Track Search/Auto Cue/grid/FX/source/Link/eject, complete modes/output/display/lifecycle or host/audio routing is claimed. There are no output/setup/audio writes or upstream scripts. Separate MIDI input and audio setup remain required. Physical/iPad/A10X acceptance remains open.

Validation:443 source checks and14 focused native tests pass. They cover both button release forms, source-owned holds and pickup, all negative aliases, exact loop arguments, repeated browse pulses, filter polarity and inactive wires/channels/groups/sources. The real-WAV case checks held Cue/bend release, marker deletion without a position jump, preserved neighbours, filter, fractional loops, finite active playback and saved Sync. Missing-profile TDD remains preserved. All404 earlier recipes remain identical. Catalogue gates compare27,208 native inputs and205 automatic held-Cue recipes. The iPad framework compiled. Its2,224,395-byte compact resource matches source and excludes the full review file. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r481/validation.json`.

Counts are405 recipes,556 physical models,250 automatic core models and115 protocol-needed records, including two reviewed audio-only integrations.306 models lack automatic core selection. Full theoretical support remains0/556. The wider manufacturer audit and physical acceptance remain open.


## R482 — Clear release after hardware Shift changes

The first13 clear profiles could retain a clear-action debounce latch if hardware Shift changed before pad release. The release then arrives on the normal Hot Cue wire. Each clear now has its own negative alias at that normal wire. All130 activation wires are independently checked against their own pinned XML normal Note-On rows. No app Shift state is inferred. The generator rejects ambiguous or missing activation proof and unreviewed fields/encodings.

The new native regression reproduces260 failed edge expectations across13 profiles before the fix. After the fix,444 source checks and82 focused native tests pass. Both negative forms rearm only their own action and deck. Earlier held-Cue, jog, pitch, loop, feedback and real-WAV regressions also pass. The failed native/source checks remain in evidence. All earlier inputs remain exact prefixes. Only130 negative aliases are added. Every positive role, output/setup/audio/alias and392 other recipes remains unchanged.

The iPad framework compiled. Its2,231,095-byte compact resource matches source and excludes the full review file. Catalogue gates compare27,338 native inputs and205 automatic held-Cue recipes. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r482/validation.json`. Complete modes, lifecycle, host routes and physical/iPad/A10X edge acceptance remain open.

Counts remain405 recipes,556 physical models,250 automatic core models and115 protocol-needed records, including two reviewed audio-only integrations.306 models lack automatic core selection. Full theoretical support remains0/556. The wider manufacturer audit remains open.


## R483 — NEON first-layer Hot Cue clears

The own NEON MIDI map page4 qualifies raw channels7..10 and shifted first-layer pad notes48..55. Its Quick Start Guide, printed7, explicitly describes Shift plus Cue as delete. These sources were visually rechecked.32 dedicated clear roles now use those wires.32 inverse negative aliases use normal activation notes16..23. The existing96 inputs remain an exact prefix. Setup, deck reports, aliases, outputs and audio remain unchanged.404 other recipes remain identical.

446 source checks and14 focused native tests pass. They cover both release directions/forms, either app Shift state, duplicate presses and foreign sources/groups. Existing deck reports rearm both normal and clear roles. App C/D opt-in remains required. Four real-WAV pair cases preserve neighbouring markers, position, finite active playback and saved Sync. Missing-clear TDD remains preserved. The iPad framework compiled. Its2,234,194-byte compact resource matches source and excludes the full review file. Catalogue gates compare27,402 native inputs and205 automatic held-Cue recipes. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r483/validation.json`.

Hot Flip, sampler/slicer/roll/stored loops, pressure, shared encoders/Load/Sync, colours, full lifecycle/host/audio and physical/iPad/A10X acceptance remain open. No upstream script executes. Counts remain405 recipes,556 physical models,250 automatic core models and115 protocol-needed records, including two reviewed audio-only integrations.306 models lack automatic core selection. Full theoretical support remains0/556. The wider manufacturer audit remains open.


## R484 — QUARK Shift is not a clear opcode

The own manufacturer guide, printed10/12, assigns Shift plus Hot Cue1 to Smart Hot Cue. Deletion requires the separate bin button. Earlier R451 text called the shifted wires clears. That label is corrected. The bin-state contract remains unqualified. Shifted pad messages stay negative-only rearming aliases. No Clear action is added.

All405 recipes retain every input, output, setup, audio and identity field. Only QUARK metadata and the inactive-Shift regression name change. Two targeted source checks, five native checks and iPad framework compilation pass. Native checks still reject shifted Smart Cue and alternate pad presses. All catalogue gates pass. The compiled compact resource matches source and excludes the full review file. Repository checking retains12 historical missing-file links. Direct QUARK PDF download and screenshots remain unavailable. The pinned hash still identifies the numeric-table text excerpt. Evidence: `TestBuilds/r484/validation.json`.

Public follow-up research also excludes an empty NS7II repository, a display-only RP-8000 MK2 project and a mapping that requires sign-in. The UC-17 factory presets use CC buttons and do not establish equivalence with the earlier custom Note mapping. No source is executed, authentication bypassed, TLS check disabled or factory reset performed. Counts remain405 recipes,556 physical models and115 protocol-needed records. Full theoretical support and the wider manufacturer audit remain open.


## R485 — STUDIO4a held-DEL clearing

The own pinned Behringer CMD STUDIO4a mapper explicitly clears the selected Hot Cue while DEL is held.32 native clear bindings now use the existing pad wires and native physical-side DEL layer. Native retains its source-local A/C and B/D hold scope. It does not copy the source global flag, latched DEL mode or timers. Normal pads retain their earlier Hot Cue roles. Every earlier124 input remains an exact prefix. Outputs, setup, audio and aliases remain unchanged.404 other recipes remain identical.

449 source checks and13 focused native tests pass. Checks cover all32 pads, both negative forms, duplicate presses, DEL release before pad release, foreign sources/groups, the opposite physical side and app C/D opt-in. Earlier held-Cue, jog, pitch and lifecycle regressions pass. The real-WAV case clears only its marker without a position jump, preserves its neighbour and retains finite active playback and saved Sync. Missing-clear TDD remains preserved. The iPad framework compiled. Its2,236,073-byte compact resource matches source and excludes the full review file. Catalogue gates compare27,434 native inputs and205 automatic held-Cue recipes. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r485/validation.json`.

Latched DEL/auto-loop/reverse/slip modes, held Hot Cue preview, complete feedback/lifecycle/host/audio and physical/iPad/A10X acceptance remain open. No upstream script or timer executes. Counts remain405 recipes,556 physical models,250 automatic core models and115 protocol-needed records, including two reviewed audio-only integrations.306 models lack automatic core selection. Full theoretical support remains0/556. The wider manufacturer audit remains open.


## R486 — Built-in FLX4 and DDJ-400 clears

Each model's own pinned XML independently specifies eight normal and clear pad pairs on each deck. Normal Hot Cues use raw7/9, while dedicated clear opcodes use raw8/10. Both use notes0..7. The DDJ-400 manufacturer PDF is downloaded and hash-pinned. Its printed pages2/3 were visually reviewed. The FLX4 manufacturer PDF is web-reviewed. No downloaded FLX4 PDF hash or visual PDF proof is claimed. The own XML explicitly identifies each clear role. No sibling assumption supplies these addresses.

Each built-in model gains16 clear inputs and32 paired negative aliases. A negative clear-channel note rearms its normal Hot Cue. A negative normal-channel note rearms clearing. These direct clear opcodes work with either app Shift state. Earlier bindings, Shift policy, recognition, feedback, setup and audio remain unchanged. FLX2, REV1 and REV5 are untouched. All405 JSON recipes and both resource files remain byte-identical. The two native profiles now contain120/119 bindings.

450 source checks and37 focused native tests pass. Checks cover both models, all slots/decks, both negative forms/directions, duplicate presses, either app Shift state and source/group ownership. Other pad modes remain inactive. Factory profile lifecycle, feedback, existing legacy mapping and catalogue regressions pass. Two real-WAV cases preserve marker neighbours/position, finite active playback and saved Sync. Missing-feature TDD records10 failed expectations before implementation. The iPad framework compiled. Its unchanged compact resource matches source and excludes the full review file. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r486/validation.json`.

These are existing built-in profiles, in addition to405 JSON recipes. No model or automatic selection count is added. The catalogue remains556 physical models,250 automatic core models and115 protocol-needed records, including two reviewed audio-only integrations. JSON catalogue gates still compare27,434 inputs and205 automatic held-Cue recipes. Complete modes/lifecycle/host and physical/iPad/A10X acceptance remain open. Full theoretical support remains0/556. The wider manufacturer audit remains open.


## R487 — Independent FLX2 clear pairs

The FLX2 own E1 table qualifies mode1 raw7/9 normal and raw8/10 Shift pad channels, notes0..7. Its own AlphaTheta hardware diagram confirms the Shift function deletes Hot Cues. The downloaded diagram is hash-pinned and printed page1 was visually reviewed. Other pad modes use distinct notes and remain inactive. No sibling assumption supplies the FLX2 protocol.

The existing built-in gains16 clear inputs and32 paired negative aliases, for105 bindings. Its normal controls, global Shift policy, recognition, feedback, setup and audio remain unchanged. FLX4 and DDJ-400 reuse the reviewed constructor without any binding field or order changes. REV1/REV5 remain untouched. All405 JSON recipes and both resource files remain byte-identical.

451 source checks and37 focused native tests pass. Checks cover all three built-ins, every slot/deck, either app Shift state, both negative forms/directions, duplicate presses, source/group ownership and inactive other pad modes. Factory lifecycle, feedback, legacy mapping and catalogue regressions pass. Three real-WAV cases preserve marker neighbours/position, finite active playback and saved Sync. Missing-feature TDD records five failed expectations for FLX2 alone. The iPad framework compiled. Its unchanged compact resource matches source and excludes the full review file. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r487/validation.json`.

Counts remain405 JSON recipes plus five existing built-ins,556 physical models,250 automatic core models and115 protocol-needed records. Two protocol-needed records are reviewed audio-only integrations. Catalogue gates still compare27,434 JSON inputs and205 automatic held-Cue recipes. Complete modes/lifecycle/host, the wider manufacturer audit and physical/iPad/A10X acceptance remain open. Full theoretical support remains0/556.


## R488 — REV5 right-deck pad channel correction

The own REV5 E1 numeric rows assign normal pads to raw7/9/11/13 and Shift pads to raw8/10/12/14. The introductory category names contain duplicated deck labels. The numeric normal and Shift channel groups remain distinct. The table is web-reviewed. Direct downloads were unavailable. No local PDF hash or visual-table proof is claimed.

The earlier built-in used raw8 for right-deck Hot Cues and lights. This ignored factory raw9 inputs and could recall right-deck markers from left-deck Shift pads. Eight right-deck inputs and eight corresponding lamp outputs now use raw9. Other fields, the63-input/22-output counts, recognition, modes, setup and audio remain unchanged. Clear actions are not added in this correction. All405 JSON recipes and both resources remain byte-identical.

The regression reproduces five failed expectations across three tests before the correction.451 source checks and38 focused native tests now pass. Decoded packets verify all eight right pads, no left-Shift recall of the right deck and exact right-lamp bytes. The first new assertion used an optional deck override instead of the action deck. Its failed run remains preserved. Existing three-model clear/WAV, factory lifecycle, feedback and catalogue gates pass. The iPad framework compiled. Its compact resource matches source and excludes the full review file. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r488/validation.json`.

Counts remain405 JSON recipes plus five built-ins,556 physical models,250 automatic core models and115 protocol-needed records. Full theoretical support remains0/556. Complete modes/lifecycle/host, the manufacturer audit and physical/iPad/A10X acceptance remain open.


## R489 — Independent REV1 and REV5 clears

Each own manufacturer E1 table qualifies eight Hot Cue pairs per deck. Raw7/9 notes0..7 activate, while raw8/10 notes0..7 are the dedicated Shift opcodes. Each own Serato guide identifies the Shift role as deletion. The tables are web-reviewed. No local PDF hash or visual PDF proof is claimed. The REV5 source label errors remain recorded. No sibling model supplies either protocol.

Each existing built-in gains16 clears and32 paired negative aliases. REV1 now has105 inputs, and REV5 has111. The existing shared constructor contains the independently qualified fixed layout. Earlier input fields/order, the corrected REV5 normal right channel, all feedback, recognition, setup and audio remain unchanged. All405 JSON recipes and both resources remain byte-identical.

451 source checks and38 focused native tests pass. The five-model tests cover every slot/deck, both negative forms/directions, debounce, either app Shift state, source/group ownership and inactive other pad modes. The R488 right-deck routing regression remains active. Five real-WAV cases preserve marker neighbours/position, finite active playback and saved Sync. Missing-feature TDD records10 failed expectations across the two REV models. The iPad framework compiled. Its compact resource matches source and excludes the full review file. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r489/validation.json`.

Counts remain405 JSON recipes plus five built-ins,556 physical models,250 automatic core models and115 protocol-needed records. Full theoretical support remains0/556. Complete modes/lifecycle/host, the manufacturer audit and physical/iPad/A10X acceptance remain open.


## R490 — FLX10 and original DDJ-1000 first-page clears

Each own manufacturer MIDI table independently qualifies32 Hot Cue pairs across A/B/C/D. Normal raw7/9/11/13 and Shift raw8/10/12/14 use notes0..7. Each own hardware diagram identifies the Shift role as deletion. Both tables and both diagrams remain independently hash-pinned. FLX10 numeric printed page4 and DDJ-1000 diagram printed page2 were visually rechecked. Other numeric pad pages are text-reviewed. Page2 and other modes remain inactive.

Each existing recipe gains32 clears and64 paired negative aliases. Original125/145 inputs remain exact prefixes, for221 DDJ-1000 and241 FLX10 inputs. The shared helper rejects unreviewed model/mode/fields, missing activation proof and positive clear collisions before it appends any inputs. Other controls, bank-change guards, feedback, setup, aliases and audio remain unchanged.403 other recipes remain identical.

454 source checks and60 focused native tests pass. They cover all64 clears, both negative forms/directions, duplicate presses, either app Shift state, source/group isolation, C/D availability and inactive pad pages/modes. Existing bank, loop, Beat Jump, pickup, lifecycle and feedback regressions pass. Six pair-profile WAV cases preserve marker neighbours/position, finite active playback and saved Sync. The five-built-in WAV regression also passes. The initial source run records a missing-clear failure and missing-helper import error. The iPad framework compiled. Its2,245,269-byte compact resource matches source and excludes the full review file. Existing4MiB/512-profile/512-input/128-output limits stay unchanged. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r490/validation.json`.

Counts remain405 JSON recipes plus five built-ins,556 physical models,250 automatic core models and115 protocol-needed records. Catalogue gates now compare27,626 JSON inputs and205 automatic held-Cue recipes. Full theoretical support remains0/556. Complete pages/modes/lifecycle/host, the manufacturer audit and physical/iPad/A10X acceptance remain open.


## R491 — Additional public mapping libraries and ELITE/SX1 leads

YouDJ publicly lists120-plus community-supplied mappings and states that they can need correction without hardware verification. The public YouDJ and Beatport app indexes link their player cores as JavaScript. Read-only inspection finds obfuscated implementation, without a standalone readable controller table. The separate marketing script, translations and Beatport landing bundle do not supply numeric mappings. No deobfuscation, protected-data decoding, script execution, installation, sign-in or MIDI/audio access occurs.

ELITE owner nicefinga publishes an internal-mode mapping at DJTT14205. The download requires sign-in. The owner also reports missing hardware meters and headphones in that configuration. The2026 ELITE FX issue thread provides no complete typed wire table. These sources do not qualify a new factory profile or audio route. The Next Beat SX1 owner readme still describes an incomplete personal mapping. Its pinned XML mixes old/new alternatives and unresolved script handlers. The original/LX1 identity and an unambiguous factory subset remain unqualified.

All405 recipes, both runtime resources and catalogue JSON remain byte-identical to R490. No new support is claimed from these leads. This review does not establish that no manufacturer SDK or usable mapping exists elsewhere. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r491/validation.json`. Public-source implementation continues.


## R492 — Independent DDJ-200 and DDJ-RB clears

Each own factory table independently qualifies16 clear pairs. DDJ-200 normal raw7/9 and clear raw8/10 use notes0..7. RB uses raw7/8 normal notes0..7 and clear notes8..15. Both hash-pinned tables were visually checked at printed page2. Their own hardware diagrams are web-reviewed and identify Shift deletion. No local diagram hash or visual diagram proof is claimed. No sibling layout supplies a wire.

Each profile gains16 clears and32 paired negative aliases. Original47/66 inputs remain exact prefixes, yielding95/114 inputs. The bounded helper now lists each reviewed layout explicitly. Its earlier FLX10/DDJ-1000 output remains identical.403 other recipes remain identical. Feedback, recognition, setup, aliases and audio remain unchanged.

456 source checks and69 native tests pass across a61-test main run and eight distinct entry/schema checks. Tests cover every clear, both negative forms/directions, debounce, either app Shift state, source/group isolation and inactive pad wires/channels. Existing entry recognition, startup, transport, mixer, feedback and CC-release validation pass. Eight pair-profile WAV cases and the separate five-built-in WAV regression preserve playback, marker neighbours/position and saved Sync. Earlier tests assumed no new guards and rejected an already-supported absolute CC negative. Only those stale assertions changed. Both failed runs remain preserved. No production schema changed.

The iPad framework compiled. Its2,249,899-byte compact resource matches source and excludes the full review file. Existing limits remain unchanged. Catalogue gates compare27,722 inputs and205 automatic held-Cue recipes. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r492/validation.json`. Counts remain405 JSON recipes plus five built-ins,556 physical models,250 automatic core models and115 protocol-needed records. Full theoretical support remains0/556. Complete modes/host/Bluetooth/audio, the manufacturer audit and physical/iPad/A10X acceptance remain open.


## R493 — Own DDJ-1000SRT pad channel correction

The SRT own factory table assigns deck A/B/C/D pads to raw7/8/9/10. Printed page1 was visually reviewed. Numeric pad page4 confirms normal notes0..7. The earlier generator incorrectly used the original DDJ-1000 channel pattern7/9/11/13. This ignored SRT B/D inputs and routed SRT C pads to B.

Only24 B/C/D input channel fields change. The SRT retains142 inputs and20 outputs. Every other field, feedback/setup/audio/alias, catalogue JSON and404 other recipes remains identical. The original DDJ-1000 remains separate. No clear action or other mode behaviour is added.

The new packet regression reproduces57 failed expectations before the fix.457 source checks and18 native tests now pass. Checks cover all32 SRT positions, exact deck/slot routes, inactive raw11..15, original DDJ-1000 boundaries, Serato-family transport/loops/feedback and real-WAV loop/Sync regressions. The iPad framework compiled. Its2,249,891-byte compact resource matches source and excludes the full review file. Catalogue gates compare27,722 inputs and205 automatic held-Cue recipes. Existing limits remain unchanged. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r493/validation.json`.

Counts remain405 JSON recipes plus five built-ins,556 physical models,250 automatic core models and115 protocol-needed records. Full theoretical support remains0/556. Complete modes/lifecycle/host, the manufacturer audit and physical/iPad/A10X acceptance remain open.


## R494 — Own-table SX, RX, RZ and RZX clears

Each own manufacturer numeric table independently qualifies32 Hot Cue pairs. Raw7/8/9/10 normal notes0..7 activate. Shift notes8..15 clear on the same channels. Printed pad page4 was visually reviewed for SX/RX, and page5 for RZ/RZX. Each own manufacturer-hosted software guide or hardware diagram independently identifies Shift deletion. Role documents are web-reviewed. No local role-document hash or visual role-document proof is claimed. Saved Flip overlaps from other models are not inherited.

Each existing recipe gains32 clears and64 negative aliases. Original139/148/154/153 inputs remain exact prefixes, yielding235/244/250/249 inputs. Both release wires rearm their own action and deck. Existing outputs, setup, audio and aliases remain unchanged.401 other recipes remain identical.

459 source checks and23 focused native tests pass. Pair tests cover13 profiles and every new slot/deck, both negative forms/directions, debounce, source/group isolation, C/D availability and inactive other pad modes. Existing DDJ/Serato-family transport, loops, mixer, feedback and SRT correction pass. Twelve pair-profile WAV cases preserve marker neighbours/position, finite active playback and saved Sync. The missing-clear source regression remains preserved. The iPad framework compiled. Its2,268,271-byte compact resource matches source and excludes the full review file. Existing limits remain unchanged. Catalogue gates compare28,106 inputs and205 automatic held-Cue recipes. Repository checking retains12 historical missing-file links. Evidence: `TestBuilds/r494/validation.json`.

Counts remain405 JSON recipes plus five built-ins,556 physical models,250 automatic core models and115 protocol-needed records. Full theoretical support remains0/556. Complete modes/lifecycle/host, the manufacturer audit and physical/iPad/A10X acceptance remain open.
