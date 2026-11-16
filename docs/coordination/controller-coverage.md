# Controller coverage

Request R23. Updated 16 November 2026. Erik owns an original Z1 and allows a hardware bridge when direct iPad access is unavailable. The A10X iPad remains the app target. Erik remains the sole acceptance tester.

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
