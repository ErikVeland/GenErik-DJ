# Controller catalogue — R169

Reviewed 17 November 2026. The pinned software inventory is complete. The wider market audit and controller feature parity remain open.

## Boundary and counts

- 121 published Serato iOS rows, expanded to 122 distinct model records.
- All 164 Mixxx definitions at `20f2c218ae1b762ac39fd76ff408c8428056f4f7`, including alternative MIDI, HID and bulk mappings.
- All 18 existing NI Traktor variants and the original Reloop Beatpad adapter.
- Manufacturer-confirmed additions include AlphaTheta DJM-A7/XDJ-AN/RMX-IGNITE, RANE PERFORMER/FOUR, Reloop Buddy/Mixtour/Beatpad 2 and Denon standalone units.
- 313 total catalogue records. 306 name physical models. The remainder identify software endpoints or protocol families.
- 175 bundled data recipes, plus 5 existing code profiles. Most data recipes cover only part of the hardware.
- 140 factory profiles select core controls automatically for 148 physical models.
- Existing native adapters provide automatic core controls for 6 other models.
- Every one of the 17,295 source input rows and 2,318 output rows has a conversion disposition.

These counts do not establish hardware acceptance, complete pad modes, motor support, screens, audio routing or feature parity.
Serato’s advertised total includes controllers, mixers, turntables, standalone units and accessories. It is not a count of full-feature controller mappings.

## Completion rule — R175

The catalogue-complete flag covers the pinned software sources. It does not establish a complete market inventory.
The manufacturer market audit has a separate incomplete flag. Product-page records do not add runtime mappings.

Theoretical support is the implementation target for every physical model. Physical verification has a separate status.
Complete the documented protocol, controls, modes, lifecycle, feedback and audio routing. Verify them with automated protocol fixtures.
A missing physical test does not block theoretical completion. Unsupported protocols and missing functions still require implementation.
Keep the A10X audio and touch baseline. Test representative connected controllers when they are available.

## Priority

The first five models in the reviewed Coolblue regional sales list have automatic core-control profiles: FLX4, FLX2, XDJ-RR, OMNIS-DUO and DDJ-GRV6.
Pioneer/AlphaTheta remains the first brand tier, based on the 2026 Digital DJ Tips census. The survey is not a global model-sales ranking.
Other models have no claimed popularity rank. Within that tier, finish documented protocols and startup messages before unknown proprietary protocols.

## Club and XDJ players — R176/R177

The club-player order balances established models and recent releases. It is an implementation order, not a measured global sales ranking.
All 17 players select core controls automatically after the hardware enters its PC or USB-MIDI mode.
Connected players receive separate A/B assignments. Saved endpoint identities retain their assignments. C/D require the existing four-deck trial.
HID, screens, lights and automatic routing across multiple player audio interfaces remain unimplemented.

| Order | Player | MIDI core | HID and screens |
| ---: | --- | --- | --- |
| 1 | Pioneer CDJ-3000 | Automatic | Open |
| 2 | AlphaTheta CDJ-3000X | Automatic | Open |
| 3 | Pioneer CDJ-2000NXS2 | Automatic | Open |
| 4 | AlphaTheta CDJ-1500X | Automatic | Open |
| 5 | Pioneer CDJ-2000NXS | Automatic | Open |
| 6 | Pioneer CDJ-900NXS | Automatic | Open |
| 7 | Pioneer XDJ-1000MK2 | Automatic | Open |
| 8 | Pioneer XDJ-700 | Automatic | Open |
| 9 | Pioneer XDJ-1000 | Automatic | Open |
| 10 | Pioneer CDJ-2000 | Automatic | Open |
| 11 | Pioneer CDJ-900 | Automatic | Open |
| 12 | Pioneer CDJ-850 | Automatic | Open |
| 13 | Pioneer CDJ-350 | Automatic | Open |
| 14 | Pioneer CDJ-400 | Automatic | Open |
| 15 | Pioneer CDJ-TOUR1 | Automatic | Open |

See [R176 club-player controls](controller-coverage.md#r176-club-player-midi-controls) and [R177 earlier-player controls](controller-coverage.md#r177-xdj-and-earlier-cdj-controls).

## Popular controller systems — R178

XDJ-AZ, XDJ-RX3, XDJ-XZ, DDJ-FLX6, DDJ-800 and DDJ-SB3 now select reviewed core MIDI profiles automatically.
Factory tables retain separate pad channels, fader direction, loop controls and documented feedback. Inactive C/D targets cannot control hidden decks.
Hardware modes, advanced functions, screens and audio routing remain open. This increment does not claim full feature parity.
See [R178 controller systems](controller-coverage.md#r178-popular-xdj-and-ddj-systems).

## SX and RX-family systems — R179

DDJ-SX3, SX2, SX, RX, RZ and RZX select core MIDI profiles automatically. Their factory tables retain model-specific controls.
The original SX deck-D filter stays unmapped because its published pair conflicts with Browse. SR2 banked Load routing remains unimplemented.
Hardware mode selection, advanced functions, complete feedback and audio routing remain open.
See [R179 DDJ families](controller-coverage.md#r179-sx-and-rx-family-controllers).

## Serato-oriented DDJ and XDJ-RX models — R180

DDJ-1000SRT, DDJ-SZ2, DDJ-SZ and XDJ-RX2 now select core MIDI profiles automatically.
The original RX has an automatic firmware-2.21 core with direct Load, fourteen-bit pitch and transport/PFL lights. The earlier seven-bit recipe remains manual.
REV7 motorised-platter, display and lifecycle protocols remain unimplemented. Its published relative JOG entry does not establish platter support.
See [R180 controller systems](controller-coverage.md#r180-serato-oriented-ddj-and-xdj-rx-models).

## Common entry-level Pioneer systems — R181

DDJ-SB2, SB, RB, RR, 200 and WeGO4 select documented core controls automatically.
The profiles retain two/four-deck limits, actual pad layouts, SB Vinyl Off releases and published application-connect messages.
Missing physical controls stay in the app. Remaining modes, complete feedback and audio routing remain open.
See [R181 entry-level systems](controller-coverage.md#r181-entry-level-pioneer-systems).

## Published DDJ startup packets — R182

SX, SX2, RX, RZ, RZX, SZ and SZ2 now send their documented application-connect packet once per session and after reconnects.
Paired-output and failure fixtures retain the existing control facts. Full lifecycle and feature parity remain open.
See [R182 startup messages](controller-coverage.md#r182-published-ddj-application-connect-messages).

## OPUS-QUAD core controls — R183

OPUS-QUAD selects core MIDI controls automatically, with its own Hot Cue layout, shifted jog and signed loop-size encoder.
Screens, complete feedback, advanced modes and audio routing remain open.
See [R183 OPUS-QUAD](controller-coverage.md#r183-opus-quad-core-midi-controls).

## ERGO and earlier WeGO systems — R184

WeGO3, WeGO2, WeGO and ERGO select separate core MIDI profiles automatically.
Their deck counts, Play messages, jog encodings, loop controls and global mixer pairs retain each generation’s factory facts.
See [R184 legacy Pioneer](controller-coverage.md#r184-ergo-and-earlier-wego-systems).

## DDJ-S1 paired relative jogs — R185

DDJ-S1 selects core MIDI controls automatically. Its signed 14-bit jog decoder emits once per complete pair and clears pending pairs on reconnect.
Orphan/repeated low bytes cannot move the deck. Jog calibration, remaining modes, complete feedback and audio routing remain open.
See [R185 DDJ-S1](controller-coverage.md#r185-ddj-s1-and-paired-relative-jog-messages).

## XDJ-AERO and XDJ-R1 — R186

XDJ-AERO and XDJ-R1 select core MIDI profiles automatically. Their deck-local browsers load the intended deck.
R1 retains three Hot Cues per deck. AERO sample controls do not become invented Hot Cues. Hardware modes and full audio routing remain open.
See [R186 earlier XDJ systems](controller-coverage.md#r186-xdj-aero-and-xdj-r1-core-controls).

## Mixtrack FX core controls — R187

Mixtrack Pro FX and Platinum FX select native core controls with model-specific, bounded SysEx setup.
The profiles reuse pinned Mixxx protocol facts. Scripts do not run in the app. Unresolved pads, modes, displays and audio routing remain explicit.
See [R187 Mixtrack FX](controller-coverage.md#r187-mixtrack-fx-core-controls-and-bounded-sysex-setup).

## Mode-gated Pro FX Hot Cues — R188

Mixtrack Pro FX has eight native Hot Cues per deck in Hot Cue mode. Other pad modes cannot trigger them.
Independent mode state, paired indicators, releases and reconnects have fixtures. Platinum FX pad bank/hold behaviour remains open.
See [R188 Pro FX pads](controller-coverage.md#r188-mode-gated-mixtrack-pro-fx-hot-cues).

## Mixtrack 3 and Pro 3 — R189

Mixtrack 3 and Pro 3 select separate native core profiles from their shared pinned mapping.
Shift state remains independent per deck. Unsupported shifted combinations cannot change base controls on that deck.
See [R189 Mixtrack 3](controller-coverage.md#r189-mixtrack-3-and-mixtrack-pro-3-core-controls).

## Original Mixtrack Platinum — R190

The original Platinum selects a separate native core profile. Its explicit low-byte CC 119 and wrapped-jog rule retain the pinned protocol facts.
Four-deck routing and global Shift have fixtures. Pads, advanced modes, screens, physical calibration and full audio routing remain open.
See [R190 original Platinum](controller-coverage.md#r190-original-mixtrack-platinum-core-controls).

## Native tempo direction correction — R191

Mixxx-derived tempo controls now account for its default engine direction once. Only tempo polarity changes in 54 runtime recipes.
Manufacturer-table controls retain their interpretation. Endpoint fixtures cover reviewed Numark and converted Hercules controls.
See [R191 tempo direction](controller-coverage.md#r191-native-tempo-direction-for-mixxx-derived-controls).

## Mixtrack II and Pro II — R192

Mixtrack II and Pro II select separate native core profiles. One physical channel retains independent deck and Shift routing.
Shifted Keylock/loop sizing and seven-bit tempo have fixtures. Pads, additional modes and full audio routing remain open.
See [R192 Mixtrack II](controller-coverage.md#r192-mixtrack-ii-and-mixtrack-pro-ii-core-controls).

## Denon MC4000 — R193

MC4000 selects a native core profile. Factory addresses and the pinned working tempo order have fixtures.
The factory pitch-byte label conflict stays explicit. Pad modes, additional functions and audio routing remain open.
See [R193 MC4000](controller-coverage.md#r193-denon-mc4000-core-controls).

## Denon MC6000MK2 — R194

MC6000MK2 selects a native core profile with A/C/B/D deck channels, side-wide Shift and separate LED trigger commands.
Factory pitch-bend tempo and zero/127 browser counts have fixtures. Pad banks, filters, advanced functions and audio routing remain open.
See [R194 MC6000MK2](controller-coverage.md#r194-denon-mc6000mk2-core-controls).

## Denon MC7000 — R195

MC7000 selects a native core profile. Its jog decoder retains the pinned script boundary exactly.
Explicit tempo pairs and per-deck Shift have fixtures. Calibration, pad modes, screens and audio routing remain open.
See [R195 MC7000](controller-coverage.md#r195-denon-mc7000-core-controls).

## Original Mixtrack and Pro — R196

The original Mixtrack and Pro select separate native core profiles. Original mixer/touch addresses and source-specific tempo direction have fixtures.
Fixed manual loops and native Scratch replace script modes. Mode toggles, advanced functions and full audio routing remain open.
See [R196 original Mixtrack](controller-coverage.md#r196-original-mixtrack-and-pro-core-controls).

## Original Party Mix — R197

The original Party Mix selects native core controls and four mode-gated Hot Cues per deck. Sensorless wheels use native pitch bend.
Other pad modes cannot trigger cues. Timed Scratch, remaining modes, full feedback cleanup and audio routing remain open.
See [R197 Party Mix](controller-coverage.md#r197-original-party-mix-core-controls).

## Pioneer DDJ-T1 — R198

DDJ-T1 adds a catalogue record and an automatic native core profile from the original factory manual.
Distinct relative jog pairs and global mixer controls have fixtures. Ambiguous needle and mixer LED facts remain unmapped.
See [R198 DDJ-T1](controller-coverage.md#r198-ddj-t1-core-midi-controls).

## Pioneer pad accessories — R199

XP2, XP1 and SP1 select accessory profiles with their distinct pad addresses, loop controls, Sync, Load and browsing.
XP software-mode negotiation, remaining modes, pad lights, FX and physical acceptance remain open.
See [R199 pad accessories](controller-coverage.md#r199-pioneer-pad-accessory-core-controls).

## Party Mix II — R200

Party Mix II selects a separate native core profile with real touch jog messages, updated mode addresses and Browse note 7.
Pinned community references remain distinct from factory evidence. Advanced setup, remaining pad modes, lights and hardware acceptance stay open.
See [R200 Party Mix II](controller-coverage.md#r200-party-mix-ii-core-controls).

## Native loop-pad modes — R201

Original Party Mix, Party Mix II and Mixtrack Pro FX add their published loop-pad modes and distinct beat sizes.
Changing pad size preserves an active loop. Pressing the matching active size exits it. Hot Cues and unsupported modes stay separate.
See [R201 loop pads](controller-coverage.md#r201-native-loop-pad-modes).

## Terminal Mix 2 and 4 — R202

Terminal Mix 2 and 4 retain their shared profile ID, with exact source encoder and centre rules.
Four-deck controls retain the app opt-in. FX, fader start, mode functions and full audio routing remain open.
See [R202 Terminal Mix](controller-coverage.md#r202-terminal-mix-2-and-4-core-controls).

## Implementation states

| State | Records | Meaning |
| --- | ---: | --- |
| adapter-needed | 36 | A referenced HID, bulk or script protocol needs an adapter. |
| automatic-core-profile | 142 | Reviewed core MIDI controls. Additional modes and acceptance remain open. |
| automatic-profile | 5 | Existing factory controls and lights. Physical acceptance remains open. |
| linux-bridge | 13 | An existing Linux USB bridge adapter is present. This is not direct iPad USB support. |
| native-accessory | 5 | An existing native accessory adapter is present. |
| native-midi | 1 | The existing native Beatpad MIDI adapter is present. |
| partial-midi-profile | 37 | Explicit XML controls are available. Script-dependent behaviour is unresolved. |
| protocol-needed | 74 | The pinned references contain no implemented mapping for this model. |

## Release blockers

1. Finish the protocol-needed and adapter-needed rows. Translate the listed script behaviours through explicit, tested app contracts.
2. Complete shifted controls, pad modes, FX, stems, meters, screens and motors where the model provides them.
3. Implement documented iPad or bridge access, model matching, hardware mode selection, audio channels and reconnection. Test these contracts with fixtures.
4. Verify the shared A10X audio and touch baseline, then sample representative connected hardware. Keep the existing performance limits.
5. Complete source-reuse and distribution review before release. Retain upstream provenance and applicable notices.

The theoretical support gate depends on implementation and automated fixtures. It does not require physical verification for every model.
Hardware evidence and source-reuse review retain separate states. Current implementation gaps still prevent full theoretical support.

## Benchmark models

Automatic means core control selection. Manual means a partial data recipe. Unknown routing requires verification.
Detailed actions, source hashes, row dispositions, connection routes and remaining gaps are in [the JSON catalogue](controller-catalogue.json).

| Model | Source role | Controls | Audio | Source |
| --- | --- | --- | --- | --- |
| Pioneer DJ DDJ-FLX4 | primary | Automatic core | Automatic split | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| AlphaTheta DDJ-FLX2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| AlphaTheta OMNIS-DUO | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| AlphaTheta DDJ-GRV6 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| AlphaTheta DJM-V5 | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| AlphaTheta Euphonia | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| AlphaTheta SLAB | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| AlphaTheta XDJ-AZ | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-200 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-400 | primary | Automatic core | Automatic split | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-ERGO | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-FLX10 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-FLX6 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-REV1 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-REV5 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-REV7 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-S1 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SB | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SB2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SB3 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SP1 | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SR | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SX | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SX2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-WeGO | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-WeGO3 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-XP2 | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DJM-A9 | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DJM-S11 | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DJM-S5 | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DJM-S7 | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ OPUS-QUAD | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ PLX-CRSS12 | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Akai Pro AFX | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Allen & Heath Xone:K1 | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ DS1 | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ LC6000 PRIME | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MC2000 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MC4000 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MC6000MK2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MC7000 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MCX8000 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ PRIME 4 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ PRIME 4+ | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ SC Live 2 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ SC Live 4 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ X1800 PRIME | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ X1850 PRIME | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Gemini Slate | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Gemini Slate 4 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 200 | primary | Automatic core | Automatic split | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 200 MK2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 200 MK3 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 300 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 300 MK2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 500 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse T7 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Starlight | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl T10 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Mixars DUO | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Mixars DUO MKII | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Mixars PRIMO | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Novation Dicers | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark DJ2GO2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark DJ2GO2 Touch | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Dashboard | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark MixDeck Express | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark MixDeck Quad | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark MixTrack Go | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixstream Pro | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixstream Pro + | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixstream Pro Go | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Platinum | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Platinum FX | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Pro | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Pro 3 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Pro FX | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Pro II | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Quad | primary | Automatic core | Automatic split | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark N4 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NDX500 | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NS4FX | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NS6II | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NSFX | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NV | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NVII | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix II | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix III | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix Live | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix Pro | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Scratch | dvs-only | Automatic core | Automatic split | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane MP2015 | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane ONE | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane ONE MKII | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane SEVENTY | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane SEVENTY A-Trak Edition | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane SEVENTY-TWO | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane SEVENTY-TWO MKII | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane SYSTEM ONE | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane TWELVE | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane TWELVE MKII | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Beatmix 2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Beatmix 4 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop ELITE | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Flux | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Flux Go | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Mixon 4 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Mixon 8 Pro | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop NEON | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop RMX-90 DVS | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop RP-8000 | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop RP8000 MK2 | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Ready | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Terminal Mix 2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Terminal Mix 4 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Terminal Mix 8 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Roland SP-404MKII | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Vestax Typhoon | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Vestax VCI-100 mk II | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Vestax VCI-300 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Vestax VFX-1 | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |

## Additional models and source families

| Model or family | Role | State | Source |
| --- | --- | --- | --- |
| Pioneer CDJ-3000 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-players/CDJ-3000/CDJ3000_MIDI_Message_List_E108.pdf) |
| AlphaTheta CDJ-3000X | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-players/CDJ-3000X/CDJ3000X_MIDI_Message_List_En.pdf) |
| Pioneer CDJ-2000NXS2 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/manuals/dj-players/CDJ-2000NXS2/CDJ-2000NXS2_DRI1290A_manual.pdf) |
| AlphaTheta CDJ-1500X | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-players/CDJ-1500X/CDJ-1500X_MIDI_Message_List_E1.pdf) |
| Pioneer CDJ-2000NXS | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/manuals/CDJ_2000NXS_DRI1052_manual.pdf) |
| Pioneer CDJ-900NXS | primary | automatic-core-profile | [Reference](https://warehousesound.com/r/pioneerCDJ900NXSmanual.pdf) |
| Pioneer XDJ-1000MK2 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/manuals/dj-players/XDJ-1000MK2/XDJ-1000MK2_DRI1396B_manual.pdf) |
| Pioneer XDJ-700 | primary | automatic-core-profile | [Reference](https://manualsfile.com/product/zq8xt8y56.html) |
| Pioneer XDJ-1000 | primary | automatic-core-profile | [Reference](https://www.allfordj.ru/upload/iblock/e25/rukovodstvo_polzovatelya_pioneer_xdj_1000_usb.pdf) |
| Pioneer CDJ-2000 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Pioneer%20CDJ-2000.midi.xml) |
| Pioneer CDJ-900 | primary | automatic-core-profile | [Reference](https://c7.zzounds.com/media/CDJ-900_OperatingInstructions1006-5d13ba1bdb7b74a71c99d9e7e959040f.pdf) |
| Pioneer CDJ-850 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Pioneer%20CDJ-850.midi.xml) |
| Pioneer CDJ-350 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Pioneer%20CDJ-350%20Ch1.midi.xml) |
| Pioneer CDJ-400 | primary | automatic-core-profile | [Reference](https://www.m3-eventtechnik.at/sites/default/files/dateien/verleih/cdj-400_manual_en_fr_de_nl_it_es_rupdf.pdf) |
| Pioneer CDJ-TOUR1 | primary | automatic-core-profile | [Reference](https://www.l-e.sk/amfile/file/download/file/7038/product/14628/) |
| Pioneer XDJ-RR | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-RR/XDJ-RR_List_of_MIDI_Message_ver101_e.pdf) |
| AlphaTheta DJM-A7 | primary | protocol-needed | [Reference](https://alphatheta.com/en/product/dj-mixer/djm-a7/black/) |
| AlphaTheta RMX-IGNITE | primary | protocol-needed | [Reference](https://alphatheta.com/en/product/effector/rmx-ignite/black/) |
| AlphaTheta XDJ-AN | primary | protocol-needed | [Reference](https://alphatheta.com/en/product/all-in-one-dj-system/xdj-an/black/) |
| Pioneer CDJ HID | protocol-family | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Pioneer%20CDJ%20HID.hid.xml) |
| Pioneer DDJ-1000 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-1000/DDJ-1000_MIDI_Message_List_E1.pdf) |
| Pioneer DDJ-1000SRT | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/firmwares/dj-controllers/DDJ-1000SRT/DDJ-1000SRT_MIDI_Message_List_E1.pdf) |
| Pioneer DDJ-800 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-800/DDJ-800_MIDI_Message_List_E1.pdf) |
| Pioneer DDJ-RB | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-RB/DDJ-RB_MIDI_Message_List_E.pdf) |
| Pioneer DDJ-RR | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-RR/DDJ-RR_MIDI_Message_List_E.pdf) |
| Pioneer DDJ-RX | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-RX/DDJ-RX_List_of_MIDI_Message_E.pdf) |
| Pioneer DDJ-RZ | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-RZ/DDJ-RZ_MIDI_Message_List_E.pdf) |
| Pioneer DDJ-RZX | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-RZX/DDJ-RZX_MIDI_Message_List_E.pdf) |
| Pioneer DDJ-SR2 | primary | adapter-needed | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-SR2/DDJ-SR2_MIDI_Message_E1.pdf) |
| Pioneer DDJ-SX3 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-SX3/DDJ-SX3_MIDI_Message_List_E1.pdf) |
| Pioneer DDJ-SZ | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-SZ/DDJ-SZ_MIDI_Message_List_E.pdf) |
| Pioneer DDJ-SZ2 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-SZ2/DDJ-SZ2_MIDI_Message_v100_E.pdf) |
| Pioneer DDJ-T1 | primary | automatic-core-profile | [Reference](https://jpn.pioneer/ja/support/manual/manual_pdf.php?m_id=5799) |
| Pioneer DDJ-WeGO2 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-WeGO2/DDJWeGO2ListofMIDIMessageVirtualDJE.pdf) |
| Pioneer DDJ-WeGO4 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-WeGO4/DDJ-WeGO4_List_of_MIDI_Message_E.pdf) |
| Pioneer DDJ-XP1 | accessory | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-XP1/DDJ-XP1_List_of_MIDI_Message_E1.pdf) |
| Pioneer XDJ-AERO | primary | automatic-core-profile | [Reference](https://www.recordcase.de/media/94/f5/e0/1745829305/Pioneer-XDJ-AERO-Manual-EN.pdf) |
| Pioneer XDJ-R1 | primary | automatic-core-profile | [Reference](https://www.uns.nu/pdf/Pioneer_XDJ-R1_Manual.pdf) |
| Pioneer XDJ-RX | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-RX/XDJ-RX_List_of_MIDI_Message_E.pdf) |
| Pioneer XDJ-RX2 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-RX2/XDJ-RX2_List_of_MIDI_Message_E3.pdf) |
| Pioneer XDJ-RX3 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-RX3/XDJ-RX3_MIDI_Message_List_E1.pdf) |
| Pioneer XDJ-XZ | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-XZ/XDJ-XZ_MIDI_Message_List_E1.pdf) |
| Akai LPD8 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Akai-LPD8-RK.midi.xml) |
| Akai MPD24 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Akai%20MPD24.midi.xml) |
| Allen & Heath Xone:K2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Allen%20and%20Heath%20Xone%20K2.midi.xml) |
| Allen & Heath Xone:K3 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Allen%20and%20Heath%20Xone%20K2.midi.xml) |
| American Audio Radius 2000 CH1 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/American%20Audio%20RADIUS%202000%20CH1.midi.xml) |
| American Audio VMS2 | primary | partial-midi-profile | [Reference](https://cdn-docs.av-iq.com/other/VMS2_User%20Manual.pdf) |
| American Audio VMS4 | primary | partial-midi-profile | [Reference](https://manual.mixxx.org/2.5/en/hardware/controllers/american_audio_vms4) |
| American Audio VMS4.1 | primary | partial-midi-profile | [Reference](https://manual.mixxx.org/2.5/en/hardware/controllers/american_audio_vms4) |
| American Audio VMS4.1 Traktor | primary | protocol-needed | [Reference](https://www.adj.eu/vms4-1-traktor) |
| American Audio VMS5 | primary | protocol-needed | [Reference](https://www.adj.com/products/vms5) |
| Arturia KeyLab Mk 1 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/ArturiaKeyLab.midi.xml) |
| Behringer BCD2000 | primary | partial-midi-profile | [Reference](https://github.com/anyc/snd-bcd2000) |
| Behringer BCD3000 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20BCD3000%20Advanced.midi.xml) |
| Behringer BCR2000 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20BCR2000.midi.xml) |
| Behringer CMD MM-1 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20CMD%20MM1.midi.xml) |
| Behringer CMD Micro | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20CMD%20Micro.midi.xml) |
| Behringer CMD STUDIO 4a | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20CMDStudio4a.midi.xml) |
| Behringer DDM4000 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20DDM4000.midi.xml) |
| DJ TechTools MIDI Fighter | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJTechTools%20MIDI%20Fighter.midi.xml) |
| DJ TechTools MIDI Fighter Spectra | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ%20TechTools%20MIDI%20Fighter%20Spectra.midi.xml) |
| DJ TechTools MIDI Fighter Twister | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ%20TechTools%20MIDI%20Fighter%20Twister.midi.xml) |
| DJ-Tech CDJ-101 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20CDJ-101.midi.xml) |
| DJ-Tech DJM-101 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20DJM-101.midi.xml) |
| DJ-Tech Kontrol One | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20Kontrol%20One.midi.xml) |
| DJ-Tech MIX-101 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20Mix-101.midi.xml) |
| DJ-Tech Mixer One | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20Mixer%20One.midi.xml) |
| DJ-Tech VTT-101 | primary | protocol-needed | [Reference](https://asset.conrad.com/media10/add/160267/c1/-/gl/000092385ML01/mode-demploi-092385-mini-controleur-usb-dj-tech-vtt101.pdf) |
| DJ-Tech i-Mix Reload | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20i-Mix%20Reload.midi.xml) |
| Denon DJ PRIME 2 | primary | protocol-needed | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DJ PRIME GO | primary | protocol-needed | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DJ PRIME GO+ | primary | protocol-needed | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DJ SC5000 PRIME | primary | protocol-needed | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DJ SC5000M PRIME | primary | protocol-needed | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DJ SC6000 PRIME | primary | protocol-needed | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DJ SC6000M PRIME | primary | protocol-needed | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DN SC2000 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Denon%20DN%20SC2000.midi.xml) |
| Denon HS5500 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Denon%20DN%20HS5500.midi.xml) |
| Denon MC3000 | primary | partial-midi-profile | [Reference](https://cdn.inmusicbrands.com/denondj/legacy/mc3000/MC3000EM_ENG_IM_v00.pdf) |
| EKS Otus HID | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/EKS%20Otus.hid.xml) |
| Electrix Tweaker | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Electrix%20Tweaker.midi.xml) |
| FaderFox DJ2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/FaderFoxDJ2.midi.xml) |
| Gemini CDMP-7000 L | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Gemini%20CDMP-7000%20L%20audio.midi.xml) |
| Gemini CDMP-7000 R | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Gemini%20CDMP-7000%20R%20audio.midi.xml) |
| Gemini FirstMix | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Gemini%20FirstMix.midi.xml) |
| Hercules DJ Console 4-Mx | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%204-Mx.midi.xml) |
| Hercules DJ Console MK1 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%20Mk1.hid.xml) |
| Hercules DJ Console MK2 HID | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%20Mk2.hid.xml) |
| Hercules DJ Console MK4 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%20Mk4.midi.xml) |
| Hercules DJ Console Mac Edition | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%20Mac%20Edition.midi.xml) |
| Hercules DJ Console RMX Advanced | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%20RMX%20Advanced.midi.xml) |
| Hercules DJ Console RMX2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%20RMX%202.midi.xml) |
| Hercules DJ Control AIR | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20AIR.midi.xml) |
| Hercules DJ Control Glow | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20MP3%20e2.bulk.xml) |
| Hercules DJ Control Instinct | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20Instinct.midi.xml) |
| Hercules DJ Control MP3 HID | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20MP3.hid.xml) |
| Hercules DJ Control MP3 LE | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20MP3%20e2.bulk.xml) |
| Hercules DJ Control MP3 e2 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20MP3%20e2.bulk.xml) |
| Hercules DJ Control Steel | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20Steel.midi.xml) |
| Hercules DJControl Compact | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJControl%20Compact.midi.xml) |
| Hercules DJControl Jogvision | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules_DJControl_Jogvision.midi.xml) |
| Hercules DJControl MIX | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJControl%20MIX.midi.xml) |
| Hercules P32 DJ | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20P32%20DJ.midi.xml) |
| Icon P1-Nano MIDI 1 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Icon-P1Nano.midi.xml) |
| Icon iControls | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Icon-iControls.midi.xml) |
| Intech TEK2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Intech%20TEK2.midi.xml) |
| Ion Discover DJ | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Ion%20Discover%20DJ.midi.xml) |
| Ion Discover DJ Pro | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Ion-Discover-DJ-Pro.midi.xml) |
| Keith McMillen Instruments QuNeo | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/KANE_QuNeo.midi.xml) |
| Kontrol DJ KDJ500 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Kontrol%20Dj%20KDJ500.midi.xml) |
| Korg KAOSS DJ | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Korg-KAOSS-DJ.midi.xml) |
| Korg nanoKONTROL | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Korg%20nanoKONTROL.midi.xml) |
| Korg nanoKONTROL2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Korg%20nanoKONTROL%202.midi.xml) |
| Korg nanoPAD2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Korg%20nanoPAD2.midi.xml) |
| M-Audio X-Session Pro | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/M-Audio_Xsession_pro.midi.xml) |
| M-Vave SMC-Mixer | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MVave-SMC-Mixer.midi.xml) |
| M-Vave SMK-25 II | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MVave-SMK-25-II.midi.xml) |
| MidiTech MidiControl | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MidiTech-MidiControl.midi.xml) |
| MixVibes U-Mix Control 2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MixVibes%20U-Mix%20Control%202.midi.xml) |
| MixVibes U-Mix Control Pro | primary | automatic-core-profile | [Reference](https://media.djmania.net/manuales/pdf/U-MIX_CONTROL_PRO_1.5.1_user_manual_0.pdf) |
| MixVibes U-Mix Control Pro 2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MixVibes%20U-Mix%20Control%20Pro%202.midi.xml) |
| Native Instruments Traktor Kontrol D2 | accessory | linux-bridge | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol F1 | accessory | linux-bridge | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol S2 Mk1 | primary | linux-bridge | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol S2 Mk2 | primary | native-accessory | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol S2 Mk3 | primary | native-accessory | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol S3 | primary | native-accessory | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol S4 Mk1 | primary | linux-bridge | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol S4 Mk2 | primary | native-accessory | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol S4 Mk3 | primary | linux-bridge | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol S5 | primary | linux-bridge | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol S8 | primary | linux-bridge | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol X1 Mk1 | accessory | linux-bridge | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol X1 Mk2 | accessory | linux-bridge | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol X1 Mk3 | accessory | linux-bridge | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol Z1 | primary | native-accessory | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol Z1 Mk2 | primary | linux-bridge | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor Kontrol Z2 | primary | linux-bridge | [Reference](../../docs/coordination/controller-coverage.md) |
| Native Instruments Traktor MX2 | primary | linux-bridge | [Reference](../../docs/coordination/controller-coverage.md) |
| Novation Launchpad | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Novation%20Launchpad.midi.xml) |
| Novation Launchpad MK2 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Novation%20Launchpad%20MK2.midi.xml) |
| Novation Launchpad Mini | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Novation-Launchpad-Mini.midi.xml) |
| Novation Launchpad Mini MK3 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Novation%20Launchpad%20Mini%20MK3.midi.xml) |
| Numark DJ2Go | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20DJ2Go.midi.xml) |
| Numark MIXTRACK | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20MIXTRACK.midi.xml) |
| Numark Mixtrack 3 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark-Mixtrack-3.midi.xml) |
| Numark Mixtrack II | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20Mixtrack%202.midi.xml) |
| Numark NS7 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20NS7.midi.xml) |
| Numark Omni Control | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20Omni%20Control.midi.xml) |
| Numark Stealth Control | primary | protocol-needed | [Reference](https://www.numark.com/product/stealthcontrol) |
| Numark Total Control | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20Total%20Control.midi.xml) |
| Numark V7 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20V7.midi.xml) |
| Numark iDJ Live II | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20iDJ%20Live%20II.midi.xml) |
| Dummy Device (Screens) | virtual | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Dummy%20Device%20Screen.hid.xml) |
| Evolution X-Session | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Evolution_Xsession.midi.xml) |
| MIDI Keyboard | protocol-family | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Midi-Keyboard.midi.xml) |
| MIDI for light | virtual | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Midi_for_light.midi.xml) |
| Mixman DM2 (Linux) | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Mixman%20DM2%20%28Linux%29.midi.xml) |
| Nintendo Wii Remote | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Nintendo%20Wiimote.hid.xml) |
| Sony SixxAxis | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Sony%20SixxAxis.hid.xml) |
| Soundless joyMIDI | virtual | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Soundless_joyMIDI.midi.xml) |
| TrakProDJ iPad | virtual | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/TrakProDJ%20iPad.midi.xml) |
| Wireless DJ App | virtual | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Wireless%20DJ%20App.midi.xml) |
| Rane FOUR | primary | protocol-needed | [Reference](https://support.rane.com/en/support/solutions/articles/69000828752-rane-four-frequently-asked-questions) |
| Rane PERFORMER | primary | protocol-needed | [Reference](https://www.rane.com/downloads/?product=Rane+Performer) |
| Reloop Beatmix 2 MK2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Beatmix-2-4-MK2.midi.xml) |
| Reloop Beatmix 4 MK2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Beatmix-2-4-MK2.midi.xml) |
| Reloop Beatpad | primary | native-midi | [Reference](../../docs/coordination/beatpad-native.md) |
| Reloop Beatpad 2 | primary | automatic-core-profile | [Reference](https://www.reloop.com/djing-with-smart-devices-controllercomparisonchart) |
| Reloop Buddy | primary | protocol-needed | [Reference](https://www.reloop.com/reloop-buddy) |
| Reloop Digital Jockey 2 Controller | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop%20Digital%20Jockey%202%20Controller%20Edition.midi.xml) |
| Reloop Digital Jockey 2 Interface Edition | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Digital-Jockey-2-IE.midi.xml) |
| Reloop Digital Jockey 2 Master Edition | primary | protocol-needed | [Reference](https://www.reloop.com/reloop-digital-jockey-2-master-edition) |
| Reloop Jockey 3 ME | primary | partial-midi-profile | [Reference](https://manual.mixxx.org/2.5/en/hardware/controllers/reloop_jockey_3_master_edition) |
| Reloop Mixage Controller Edition | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Mixage.midi.xml) |
| Reloop Mixage Interface Edition | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Mixage.midi.xml) |
| Reloop Mixage Interface Edition MK2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Mixage.midi.xml) |
| Reloop Mixtour | primary | automatic-core-profile | [Reference](https://www.reloop.com/djing-with-smart-devices-controllercomparisonchart) |
| Reloop Mixtour Pro | primary | partial-midi-profile | [Reference](https://www.reloop.com/reloop-mixtour-pro) |
| Roland DJ-505 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Roland_DJ-505.midi.xml) |
| Stanton DJC.4 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton-DJC-4.midi.xml) |
| Stanton SCS.1d (unfinished) | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton%20SCS.1d.midi.xml) |
| Stanton SCS.1m | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton%20SCS.1m.midi.xml) |
| Stanton SCS.3d (alternate) | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton%20SCS.3d%20Alternate.midi.xml) |
| Stanton SCS.3m | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton%20SCS.3m.midi.xml) |
| Tascam US-428 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/us428.midi.xml) |
| Vestax Spin | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Vestax%20Spin.midi.xml) |
| Vestax VCI-100 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Vestax%20VCI-100-3DEX.midi.xml) |
| Vestax VCI-400 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Vestax%20VCI-400.midi.xml) |
| Yaeltex MiniMixxx | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Yaeltex%20MiniMixxx.midi.xml) |

## Provenance and reproduction

The importer reads XML protocol facts and explicit, hash-locked handler translations. It never executes downloaded controller JavaScript. Untranslated handlers remain unresolved.
Mixxx source files use GPL-2.0-or-later. The app bundles independently normalised protocol tables, not the upstream scripts. This does not settle distribution obligations.
Manufacturer MIDI tables retain their owners’ rights. Their hashes and URLs identify the reviewed versions.
See [the importer procedure](../../tools/controller_profiles/README.md) and [the R169 delivery note](controller-coverage.md#r169-complete-source-catalogue).
