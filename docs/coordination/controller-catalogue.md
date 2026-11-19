# Controller catalogue — R169

Base inventory reviewed 17 November 2026. Later profile reviews appear in the request ledger. The pinned software inventory is complete. The wider market audit and controller feature parity remain open.

## Boundary and counts

- 121 published Serato iOS rows, expanded to 122 distinct model records.
- 204 pinned djay hardware rows, with per-platform limitations kept as competitor evidence.
- 487 pinned VirtualDJ products, including two passive timecode media outside the digital-device count. Product listings remain competitor evidence.
- All 164 Mixxx definitions at `20f2c218ae1b762ac39fd76ff408c8428056f4f7`, including alternative MIDI, HID and bulk mappings.
- All 18 existing NI Traktor variants and the original Reloop Beatpad adapter.
- Manufacturer-confirmed additions include AlphaTheta DJM-A7/XDJ-AN/RMX-IGNITE, RANE PERFORMER/FOUR, Reloop Buddy/Mixtour/Beatpad 2 and Denon standalone units.
- 561 total catalogue records. 554 name physical models. The remainder identify software endpoints or protocol families.
- 335 bundled data recipes, plus 5 existing code profiles. Most data recipes cover only part of the hardware.
- 211 factory profiles select core controls automatically for 219 physical models.
- Existing native adapters provide automatic core controls for 6 other models.
- 329 physical models still lack automatic core controls.
- 554 physical models still need complete theoretical support.
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
All 24 players select core controls automatically after the hardware enters its PC or USB-MIDI mode.
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
| adapter-needed | 17 | A referenced HID, bulk or script protocol needs an adapter. |
| automatic-core-profile | 213 | Reviewed core MIDI controls. Additional modes and acceptance remain open. |
| automatic-profile | 5 | Existing factory controls and lights. Physical acceptance remains open. |
| linux-bridge | 13 | An existing Linux USB bridge adapter is present. This is not direct iPad USB support. |
| native-accessory | 5 | An existing native accessory adapter is present. |
| native-midi | 1 | The existing native Beatpad MIDI adapter is present. |
| partial-midi-profile | 126 | Explicit XML controls are available. Script-dependent behaviour is unresolved. |
| protocol-needed | 181 | The pinned references contain no implemented mapping for this model. |

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
| AlphaTheta Euphonia | dvs-only | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| AlphaTheta SLAB | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| AlphaTheta XDJ-AZ | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-200 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-400 | primary | Automatic core | Automatic split | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-ERGO | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-FLX10 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-FLX6 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-REV1 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-REV5 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-REV7 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
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
| Pioneer DJ DJM-A9 | dvs-only | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DJM-S11 | dvs-only | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DJM-S5 | dvs-only | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DJM-S7 | dvs-only | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ OPUS-QUAD | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ PLX-CRSS12 | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Akai Pro AFX | accessory | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Allen & Heath Xone:K1 | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ DS1 | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ LC6000 PRIME | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MC2000 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MC4000 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MC6000MK2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MC7000 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MCX8000 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ PRIME 4 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ PRIME 4+ | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ SC Live 2 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ SC Live 4 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ X1800 PRIME | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ X1850 PRIME | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Gemini Slate | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Gemini Slate 4 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 200 | primary | Automatic core | Automatic split | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 200 MK2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 200 MK3 | primary | Automatic core | Automatic split | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 300 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 300 MK2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 500 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse T7 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Starlight | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl T10 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Mixars DUO | dvs-only | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Mixars DUO MKII | dvs-only | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Mixars PRIMO | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Novation Dicers | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark DJ2GO2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark DJ2GO2 Touch | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Dashboard | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark MixDeck Express | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark MixDeck Quad | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark MixTrack Go | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixstream Pro | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixstream Pro + | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixstream Pro Go | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Platinum | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Platinum FX | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Pro | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Pro 3 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Pro FX | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Pro II | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Quad | primary | Automatic core | Automatic split | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark N4 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NDX500 | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NS4FX | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NS6II | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NSFX | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NV | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NVII | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix II | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix III | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix Live | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix Pro | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Scratch | dvs-only | Automatic core | Automatic split | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane MP2015 | dvs-only | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane ONE | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane ONE MKII | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane SEVENTY | dvs-only | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Rane SEVENTY A-Trak Edition | dvs-only | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
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
| Reloop Mixon 8 Pro | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop NEON | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop RMX-90 DVS | dvs-only | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop RP-8000 | accessory | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop RP8000 MK2 | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Ready | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Terminal Mix 2 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Terminal Mix 4 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Terminal Mix 8 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Roland SP-404MKII | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
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
| AlphaTheta DJM-A7 | primary | partial-midi-profile | [Reference](https://alphatheta.com/en/product/dj-mixer/djm-a7/black/) |
| AlphaTheta RMX-IGNITE | primary | partial-midi-profile | [Reference](https://alphatheta.com/en/product/effector/rmx-ignite/black/) |
| AlphaTheta XDJ-AN | primary | automatic-core-profile | [Reference](https://alphatheta.com/en/product/all-in-one-dj-system/xdj-an/black/) |
| Pioneer CDJ HID | protocol-family | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Pioneer%20CDJ%20HID.hid.xml) |
| Pioneer DDJ-1000 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-1000/DDJ-1000_MIDI_Message_List_E1.pdf) |
| Pioneer DDJ-1000SRT | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/firmwares/dj-controllers/DDJ-1000SRT/DDJ-1000SRT_MIDI_Message_List_E1.pdf) |
| Pioneer DDJ-800 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-800/DDJ-800_MIDI_Message_List_E1.pdf) |
| Pioneer DDJ-FLX6-GT | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-FLX6/DDJ-FLX6_MIDI_message_List_E1.pdf) |
| Pioneer DDJ-RB | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-RB/DDJ-RB_MIDI_Message_List_E.pdf) |
| Pioneer DDJ-RR | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-RR/DDJ-RR_MIDI_Message_List_E.pdf) |
| Pioneer DDJ-RX | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-RX/DDJ-RX_List_of_MIDI_Message_E.pdf) |
| Pioneer DDJ-RZ | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-RZ/DDJ-RZ_MIDI_Message_List_E.pdf) |
| Pioneer DDJ-RZX | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-RZX/DDJ-RZX_MIDI_Message_List_E.pdf) |
| Pioneer DDJ-SR2 | primary | partial-midi-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-SR2/DDJ-SR2_MIDI_Message_E1.pdf) |
| Pioneer DDJ-SX3 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-SX3/DDJ-SX3_MIDI_Message_List_E1.pdf) |
| Pioneer DDJ-SZ | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-SZ/DDJ-SZ_MIDI_Message_List_E.pdf) |
| Pioneer DDJ-SZ2 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-SZ2/DDJ-SZ2_MIDI_Message_v100_E.pdf) |
| Pioneer DDJ-T1 | primary | automatic-core-profile | [Reference](https://jpn.pioneer/ja/support/manual/manual_pdf.php?m_id=5799) |
| Pioneer DDJ-WeGO2 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-WeGO2/DDJWeGO2ListofMIDIMessageVirtualDJE.pdf) |
| Pioneer DDJ-WeGO4 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-WeGO4/DDJ-WeGO4_List_of_MIDI_Message_E.pdf) |
| Pioneer DDJ-XP1 | accessory | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-XP1/DDJ-XP1_List_of_MIDI_Message_E1.pdf) |
| Pioneer DJM-2000 | accessory | partial-midi-profile | [Reference](https://static.bhphoto.com/lit_files/88476.pdf) |
| Pioneer DJM-2000NXS | accessory | partial-midi-profile | [Reference](https://www.dimmer.fr/wp-content/uploads/2022/01/Pioneer-DJM-2000-Nexus-Manual-DE-EN-FR.pdf) |
| Pioneer DJM-250MK2 | accessory | partial-midi-profile | [Reference](https://manuals.plus/m/e7d4bd85474a10aedc2c4ddd9809d56bd9707b753a45cf73bd7b831a2da23594) |
| Pioneer DJM-450 | accessory | partial-midi-profile | [Reference](https://www.recordcase.de/media/pdf/84/26/2c/Pioneer-DJM-450-Addendum-EN.pdf) |
| Pioneer DJM-750 | accessory | partial-midi-profile | [Reference](https://cdn-docs.av-iq.com/instructions/DJM-750_OperatingInstructions042613.pdf) |
| Pioneer DJM-750MK2 | accessory | partial-midi-profile | [Reference](https://www.proacousticsusa.com/media/wysiwyg/PDFs/DJM-750MK2_addendum_MIDI_Message_EN.pdf) |
| Pioneer DJM-850 | accessory | partial-midi-profile | [Reference](https://www.appliancesonline.com.au/public/manuals/Pioneer-DJM850-4Ch-High-End-Digital-Mixer-User-Manual.pdf) |
| Pioneer DJM-900NXS | accessory | partial-midi-profile | [Reference](https://progresionaudiovisual.com/sites/default/files/2024-05/DJM-900nexus_OperatingInstructions070511.pdf) |
| Pioneer DJM-900NXS2 | accessory | partial-midi-profile | [Reference](https://impact-even.com/wp-content/uploads/2022/03/pioneer_djm900nexus2_midimessages.pdf) |
| Pioneer DJM-900SRT | accessory | partial-midi-profile | [Reference](https://www.djcenter.ee/images/kasutusjuhendid/Pioneer-DJM-900SRT.pdf) |
| Pioneer DJM-S3 | accessory | partial-midi-profile | [Reference](https://dwn.alza.cz/manual/61365) |
| Pioneer DJM-S9 | accessory | partial-midi-profile | [Reference](https://downloads.support.alphatheta.com/midi-mapping/dj-mixers/DJM-S9/DJM-S9_List_of_MIDI_Message_E.pdf) |
| Pioneer DJM-T1 | primary | partial-midi-profile | [Reference](https://downloads.support.alphatheta.com/manuals/dj-mixers/DJM-T1/DJM-T1_DRB1610_manual.pdf) |
| Pioneer DJM-TOUR1 | accessory | partial-midi-profile | [Reference](https://downloads.support.alphatheta.com/manuals/DJM_TOUR1_DJM_TOUR1_MIDI_Message_e_v100_addendum/) |
| Pioneer DJM-V10 | accessory | partial-midi-profile | [Reference](https://raw.githubusercontent.com/heronarts/LX/a950c548db00b1d3b72db3b5ac4a80f2b8519415/src/main/java/heronarts/lx/midi/surface/DJMV10.java) |
| Pioneer DJM-V10-LF | accessory | partial-midi-profile | [Reference](https://blt-guide.deepsymmetry.org/beat-link-trigger/next/_attachments/ExtendedOnAirV10.bls) |
| Pioneer MEP-7000 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/manuals/dj-players/MEP-7000/MEP-7000_DRB1467B_manual.pdf) |
| Pioneer XDJ-AERO | primary | automatic-core-profile | [Reference](https://www.recordcase.de/media/94/f5/e0/1745829305/Pioneer-XDJ-AERO-Manual-EN.pdf) |
| Pioneer XDJ-R1 | primary | automatic-core-profile | [Reference](https://www.uns.nu/pdf/Pioneer_XDJ-R1_Manual.pdf) |
| Pioneer XDJ-RX | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-RX/XDJ-RX_List_of_MIDI_Message_E.pdf) |
| Pioneer XDJ-RX2 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-RX2/XDJ-RX2_List_of_MIDI_Message_E3.pdf) |
| Pioneer XDJ-RX3 | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-RX3/XDJ-RX3_MIDI_Message_List_E1.pdf) |
| Pioneer XDJ-XZ | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-XZ/XDJ-XZ_MIDI_Message_List_E1.pdf) |
| AKAI APC MINI | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=APCMINI) |
| AKAI APC20 | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=AKAPC20) |
| AKAI APC64 | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=APC64) |
| AKAI LPD8 MK2 | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=LPD8MK2) |
| AKAI MPD 218 | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=MPD218) |
| AKAI MPD 226 | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=MPD226) |
| AKAI MPD 232 | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=MPD232) |
| Akai APC mini MK2 | accessory | automatic-core-profile | [Reference](https://cdn.inmusicbrands.com/akai/attachments/APC%20mini%20mk2%20-%20Communication%20Protocol%20-%20v1.0.pdf) |
| Akai APC40 | accessory | automatic-core-profile | [Reference](https://cdn.inmusicbrands.com/akai/apc40/APC40_Communications_Protocol_rev_1.pdf_1db97c1fdba23bacf47df0f9bf64e913.pdf) |
| Akai APC40 MKII | accessory | automatic-core-profile | [Reference](https://cdn.inmusicbrands.com/akai/attachments/apc40II/APC40Mk2_Communications_Protocol_v1.2.pdf) |
| Akai LPD8 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Akai-LPD8-RK.midi.xml) |
| Akai MPD24 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Akai%20MPD24.midi.xml) |
| Akai Pro AMX | accessory | partial-midi-profile | [Reference](https://dmsdown.com/descargas/DMS_DJPROMIXER/DJProMixer_3.0_Setup.exe) |
| Akiyama Pulsar | primary | partial-midi-profile | [Reference](https://dmsdown.com/descargas/DMS_DJPROMIXER/DJProMixer_3.0_Setup.exe) |
| Akiyama QUARC | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=QUARK) |
| Akiyama Quark SC | primary | partial-midi-profile | [Reference](https://media.djmania.net/manuales/pdf/Manual_Akiyama_Quark_SC.pdf) |
| Akiyama Quattro | primary | partial-midi-profile | [Reference](https://media.djmania.net/manuales/pdf/118rOPK_Ym0.pdf) |
| Akiyama Syncron | primary | partial-midi-profile | [Reference](https://dmsdown.com/descargas/DMS_DJPROMIXER/DJProMixer_3.0_Setup.exe) |
| Akiyama TTWO | primary | partial-midi-profile | [Reference](https://media.djmania.net/manuales/pdf/Manual_Akiyama_TTwo.pdf) |
| Akiyama Tempus | primary | partial-midi-profile | [Reference](https://dmsdown.com/descargas/DMS_DJPROMIXER/DJProMixer_3.0_Setup.exe) |
| Allen & Heath XONE 1D | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=XONE1D) |
| Allen & Heath XONE 2D | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=XONE2D) |
| Allen & Heath XONE 43C | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=AH43C) |
| Allen & Heath XONE 4D | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=XONE4D) |
| Allen & Heath Xone:23C | primary | protocol-needed | [Reference](https://www.algoriddim.com/hardware) |
| Allen & Heath Xone:24C | primary | partial-midi-profile | [Reference](https://support.allen-heath.com/hc/en-gb/articles/39821017822865-Xone-24C-User-Guide) |
| Allen & Heath Xone:96 | primary | partial-midi-profile | [Reference](https://support.allen-heath.com/hc/en-gb/articles/43084536824849-Xone-96-MIDI-Implementation) |
| Allen & Heath Xone:K2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Allen%20and%20Heath%20Xone%20K2.midi.xml) |
| Allen & Heath Xone:K3 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Allen%20and%20Heath%20Xone%20K2.midi.xml) |
| Allen & Heath Xone:PX5 | primary | partial-midi-profile | [Reference](https://virtualdj.com/forums/264850/VirtualDJ_Plugins/Mapping_the_XONE:PX5_Mixer.html) |
| American Audio 10MXR | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=AA10MXR) |
| American Audio 14MXR | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=AA14MXR) |
| American Audio 19MXR | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=AA19MXR) |
| American Audio DP2 | primary | automatic-core-profile | [Reference](https://assets.centryngroup.com/dl/files/DP2__DL__003.zip) |
| American Audio DV2 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=AADV2) |
| American Audio ELMC-1 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ELMC1) |
| American Audio ENCORE 2000 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=AAEncore2000) |
| American Audio RADIUS 1000 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=RADIUS1000) |
| American Audio RADIUS 3000 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=RADIUS3000) |
| American Audio Radius 2000 CH1 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/American%20Audio%20RADIUS%202000%20CH1.midi.xml) |
| American Audio VERSADECK | primary | automatic-core-profile | [Reference](https://www.adj.com/cdn/shop/files/5be308675de7801329d188d3f0cf44323069d6d2_versadeck_user_manual.pdf?v=11627430234356086881) |
| American Audio VMS2 | primary | partial-midi-profile | [Reference](https://cdn-docs.av-iq.com/other/VMS2_User%20Manual.pdf) |
| American Audio VMS4 | primary | partial-midi-profile | [Reference](https://manual.mixxx.org/2.5/en/hardware/controllers/american_audio_vms4) |
| American Audio VMS4.1 | primary | partial-midi-profile | [Reference](https://manual.mixxx.org/2.5/en/hardware/controllers/american_audio_vms4) |
| American Audio VMS4.1 Traktor | primary | partial-midi-profile | [Reference](https://www.adj.eu/vms4-1-traktor) |
| American Audio VMS5 | primary | partial-midi-profile | [Reference](https://www.adj.com/products/vms5) |
| Arturia KeyLab Mk 1 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/ArturiaKeyLab.midi.xml) |
| Audiophony CDX6 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=CDX6) |
| Audiophony DJAM | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=DJAM) |
| Audiophony DJAZZ | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=DJAZZ) |
| Audiophony DJINN | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=DJINN) |
| Audiophony PLAY | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=CDMP700) |
| Behringer BCD2000 | primary | partial-midi-profile | [Reference](https://github.com/anyc/snd-bcd2000) |
| Behringer BCD3000 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20BCD3000%20Advanced.midi.xml) |
| Behringer BCR2000 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20BCR2000.midi.xml) |
| Behringer CMD DC-1 | accessory | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mpiraux/CMD-DC-1-Ableton-9-Control-Surface-Script/c2a122474cb81469352493c393e4a985b9ca9753/DC1.py) |
| Behringer CMD DV-1 | accessory | partial-midi-profile | [Reference](https://raw.githubusercontent.com/pavallin/CMD-DV1-Ableton/5536b5cf1aba7b9f5150e83e97129390363e072f/DV1.py) |
| Behringer CMD LC-1 | accessory | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mpiraux/CMD-LC-1-Ableton-9-Control-Surface-Script/5363aa49d6006f80c71891d8bcb38cdfe80a14e1/LC1.py) |
| Behringer CMD MM-1 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20CMD%20MM1.midi.xml) |
| Behringer CMD Micro | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20CMD%20Micro.midi.xml) |
| Behringer CMD PL-1 | primary | automatic-core-profile | [Reference](https://www.parts-express.com/pedocs/tech-docs/behringer-cmd-pl-1-platter-module-midi-map--248-6846.pdf) |
| Behringer CMD STUDIO 2a | primary | automatic-core-profile | [Reference](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) |
| Behringer CMD STUDIO 4a | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20CMDStudio4a.midi.xml) |
| Behringer DDM4000 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20DDM4000.midi.xml) |
| BeyondMusic (BMI) ABMA1 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ABMA1) |
| BeyondMusic (BMI) ABMA2 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ABMA2) |
| BeyondMusic (BMI) ABMA3 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ABMA3) |
| BeyondMusic (BMI) ABMA4 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ABMA4) |
| BeyondMusic (BMI) REMIX PRO | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ABMA1T) |
| Casio XW-DJ1 | primary | automatic-core-profile | [Reference](https://www.casio.com/content/dam/casio/global/support/manuals/electronic-musical-instruments/pdf/008-en/w/Web_XWDJ1-E-2A_EN.pdf) |
| Casio XW-J1 | primary | partial-midi-profile | [Reference](https://gist.github.com/samba2/5af83e947297ab99a4745a5be3e13d55/a8c441c832affebb59415abdc80872967bc8c0e6) |
| CITRONIC MPCD-X3 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=MPCDX3) |
| CITRONIC MPX10 | primary | automatic-core-profile | [Reference](https://www.billebro.se/proddoc/PRID_6104_doc_170700.pdf) |
| DAP KONTROL D2 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=DAPKONTROLD2) |
| DJ TechTools MIDI Fighter | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJTechTools%20MIDI%20Fighter.midi.xml) |
| DJ TechTools MIDI Fighter 3D | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=FIGHTER3D) |
| DJ TechTools MIDI Fighter Spectra | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ%20TechTools%20MIDI%20Fighter%20Spectra.midi.xml) |
| DJ TechTools MIDI Fighter Twister | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ%20TechTools%20MIDI%20Fighter%20Twister.midi.xml) |
| DJ-Tech 4MIX | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=4MIX) |
| DJ-Tech CDJ-101 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20CDJ-101.midi.xml) |
| DJ-Tech DJM-101 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20DJM-101.midi.xml) |
| DJ-Tech DRAGON TWO | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=DRAGON2) |
| DJ-Tech I-MIX | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=IMIX) |
| DJ-Tech I-MIX RELOAD MKII | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=IMIXRELOADMKII) |
| DJ-Tech Kontrol One | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20Kontrol%20One.midi.xml) |
| DJ-Tech MIX-101 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20Mix-101.midi.xml) |
| DJ-Tech MY SCRATCH | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=MYSCRATCH) |
| DJ-Tech Mixer One | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20Mixer%20One.midi.xml) |
| DJ-Tech RELOADED | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=RELOADED) |
| DJ-Tech VTT-101 | primary | protocol-needed | [Reference](https://asset.conrad.com/media10/add/160267/c1/-/gl/000092385ML01/mode-demploi-092385-mini-controleur-usb-dj-tech-vtt101.pdf) |
| DJ-Tech i-Mix Reload | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20i-Mix%20Reload.midi.xml) |
| Denon DJ HC1000S | accessory | automatic-core-profile | [Reference](https://cdn.inmusicbrands.com/denondj/legacy/dnhc1000s/DN-HC1000S_ownersmanual.pdf) |
| Denon DJ HC4500 | primary | automatic-core-profile | [Reference](https://cdn.inmusicbrands.com/denondj/legacy/dnhc4500/DN-HC4500_midicommandlist.pdf) |
| Denon DJ HC5000 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=HC5000) |
| Denon DJ HD2500 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=HD2500) |
| Denon DJ MC6000 | primary | partial-midi-profile | [Reference](https://cdn.inmusicbrands.com/denondj/legacy/dnmc6000/DN-MC6000_ownersmanual.pdf) |
| Denon DJ PRIME 2 | primary | partial-midi-profile | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DJ PRIME GO | primary | automatic-core-profile | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DJ PRIME GO+ | primary | partial-midi-profile | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DJ S1200 | primary | automatic-core-profile | [Reference](https://cdn.inmusicbrands.com/denondj/legacy/dns1200/DN-S1200_midicommandlist.pdf) |
| Denon DJ S3700 | primary | automatic-core-profile | [Reference](https://cdn.inmusicbrands.com/denondj/legacy/dns3700/dns3700-midi-command-list.pdf) |
| Denon DJ S3900 | primary | automatic-core-profile | [Reference](https://cdn.inmusicbrands.com/denondj/legacy/sc3900/sc3900em-om-20130513-en.pdf) |
| Denon DJ SC2900 | primary | automatic-core-profile | [Reference](https://cdn.inmusicbrands.com/denondj/legacy/sc2900/sc2900em-om-20130513-owners-manual-en.pdf) |
| Denon DJ SC5000 PRIME | primary | partial-midi-profile | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DJ SC5000M PRIME | primary | partial-midi-profile | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DJ SC6000 PRIME | primary | partial-midi-profile | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DJ SC6000M PRIME | primary | partial-midi-profile | [Reference](https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services) |
| Denon DJ X1600 | primary | partial-midi-profile | [Reference](https://cdn.inmusicbrands.com/denondj/legacy/dnx1600/dnx1600-ownersmanual.zip) |
| Denon DN SC2000 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Denon%20DN%20SC2000.midi.xml) |
| Denon HS5500 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Denon%20DN%20HS5500.midi.xml) |
| Denon MC3000 | primary | partial-midi-profile | [Reference](https://cdn.inmusicbrands.com/denondj/legacy/mc3000/MC3000EM_ENG_IM_v00.pdf) |
| EKS OTUS RAW | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=OTUSRAW) |
| EKS Otus HID | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/EKS%20Otus.hid.xml) |
| EKS XP10 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=XP10) |
| EKS XP5 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=XP5) |
| ESI MAYA 44USB | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=MAYA44USB) |
| Electrix Tweaker | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Electrix%20Tweaker.midi.xml) |
| FaderFox DJ2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/FaderFoxDJ2.midi.xml) |
| Faderfox DJ3 | primary | automatic-core-profile | [Reference](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) |
| Gemini CDJ650 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GCDJ650) |
| Gemini CDJ700 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GCDJ700) |
| Gemini CDMP-2700 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GCDMP2700) |
| Gemini CDMP-7000 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GCDMP7000) |
| Gemini CDMP-7000 L | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Gemini%20CDMP-7000%20L%20audio.midi.xml) |
| Gemini CDMP-7000 R | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Gemini%20CDMP-7000%20R%20audio.midi.xml) |
| Gemini CNTRL-2 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GEMINI2) |
| Gemini CNTRL-7 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GEMINI7) |
| Gemini CTRL-ONE | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GEMINI1) |
| Gemini CTRL-SIX | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GEMINI6) |
| Gemini FIRSTMIX PRO | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=FIRSTMIXPRO) |
| Gemini FirstMix | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Gemini%20FirstMix.midi.xml) |
| Gemini FirstMix IO | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=FIRSTMIXIO) |
| Gemini G2V | primary | automatic-core-profile | [Reference](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) |
| Gemini G4V | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GEMINI_G4V) |
| Gemini GMX | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GMGMX) |
| Gemini GMX DRIVE | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GMGMXDRIVE) |
| Gemini MDJ-1000 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GMMDJ1K) |
| Gemini MDJ-500 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GMDJ500) |
| Gemini MDJ-600 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GMDJ600) |
| Gemini PMX10 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GMPMX10) |
| Gemini PMX20 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GMPMX20) |
| Gemini SDJ-4000 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GMSDJ4K) |
| Gemini SLATE 2 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=GMSLATE) |
| HANPIN DMX-101 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=DMX101) |
| HANPIN PDJ | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=PDJ22) |
| Hercules DJ 4Set | primary | partial-midi-profile | [Reference](https://ts.hercules.com/download/sound/manuals/4Set/01_Eng_DJ4Set.pdf) |
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
| Hercules DJCONSOLE | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=DJCONSOLE) |
| Hercules DJControl AIR+ | primary | automatic-core-profile | [Reference](https://ts.hercules.com/download/sound/manuals/DJ_Air%2B/DJAIR%2B_Spec_MIDI.pdf) |
| Hercules DJControl Compact | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJControl%20Compact.midi.xml) |
| Hercules DJControl Instinct P8 | primary | automatic-core-profile | [Reference](https://ts.hercules.com/download/sound/MIDI_Mapping/DJ_InstinctP8/DJControl_Instinct_P8_MIDI_Command_List.pdf) |
| Hercules DJControl Jogvision | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules_DJControl_Jogvision.midi.xml) |
| Hercules DJControl MIX | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJControl%20MIX.midi.xml) |
| Hercules DJControl Mix Ultra | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/v6ry876z77-bit/yt-dj-mix/93a097e7641512bd026b9d1b5d129b2e5f009f87/mixultra-midi.md) |
| Hercules DJControlWave | primary | automatic-core-profile | [Reference](https://ts.hercules.com/download/sound/MIDI_Mapping/DJWave/DJCWaveDJAYPro.ZIP) |
| Hercules DeeJay Trim Scratch Kit | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=TRIM) |
| Hercules P32 DJ | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20P32%20DJ.midi.xml) |
| Hercules Universal DJ | primary | automatic-core-profile | [Reference](https://ts.hercules.com/download/sound/MIDI_Mapping/UniversalDJ/DJay_Pro_Hercules_Universal_DJ.zip) |
| Icon P1-Nano MIDI 1 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Icon-P1Nano.midi.xml) |
| Icon iControls | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Icon-iControls.midi.xml) |
| Intech TEK2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Intech%20TEK2.midi.xml) |
| ION DJ LIVE | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=IONLIVE) |
| ION DJ2GO | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=IONDJ2GO) |
| ION ICUE | primary | partial-midi-profile | [Reference](https://dmsdown.com/descargas/DMS_DJPROMIXER/DJProMixer_3.0_Setup.exe) |
| Ion Discover DJ | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Ion%20Discover%20DJ.midi.xml) |
| Ion Discover DJ Pro | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Ion-Discover-DJ-Pro.midi.xml) |
| Ion iDJ2GO | primary | partial-midi-profile | [Reference](https://download.algoriddim.com/djay/202010171657/djay_Pro_2.2.9.zip) |
| JB Systems DJ KONTROL1 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=JBSDJKTRL1) |
| JB Systems DJ KONTROL2 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=JBSDJKTRL2) |
| JB Systems DJ KONTROL3 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=JBSDJKTRL3) |
| JB Systems DJ KONTROL3S | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=JBSKT3S) |
| JB Systems DJ KONTROL4 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=JBKTRL4) |
| Keith McMillen Instruments QuNeo | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/KANE_QuNeo.midi.xml) |
| Kontrol DJ KDJ500 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Kontrol%20Dj%20KDJ500.midi.xml) |
| Korg KAOSS DJ | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Korg-KAOSS-DJ.midi.xml) |
| Korg NanoPAD | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=NANOPAD) |
| Korg nanoKONTROL | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Korg%20nanoKONTROL.midi.xml) |
| Korg nanoKONTROL2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Korg%20nanoKONTROL%202.midi.xml) |
| Korg nanoPAD2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Korg%20nanoPAD2.midi.xml) |
| M-AUDIO CONNECTIV | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=CONECTIV) |
| M-AUDIO XSESSION | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=XSESSION) |
| M-Audio X-Session Pro | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/M-Audio_Xsession_pro.midi.xml) |
| M-Audio Xponent | primary | partial-midi-profile | [Reference](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) |
| M-Vave SMC-Mixer | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MVave-SMC-Mixer.midi.xml) |
| M-Vave SMK-25 II | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MVave-SMK-25-II.midi.xml) |
| MidiTech MidiControl | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MidiTech-MidiControl.midi.xml) |
| MIDIPLUS SMARTPAD | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=SMPAD) |
| MixVibes U-Mix Control 2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MixVibes%20U-Mix%20Control%202.midi.xml) |
| MixVibes U-Mix Control Pro | primary | automatic-core-profile | [Reference](https://media.djmania.net/manuales/pdf/U-MIX_CONTROL_PRO_1.5.1_user_manual_0.pdf) |
| MixVibes U-Mix Control Pro 2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MixVibes%20U-Mix%20Control%20Pro%202.midi.xml) |
| Mixvibes VFX CONTROL | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=MIXVVFX) |
| Mixars QUATTRO | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=MXRSQUATTRO) |
| Native Instruments AUDIO 2DJ | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=AUDIO2DJ) |
| Native Instruments AUDIO 4DJ | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=AUDIO4DJ) |
| Native Instruments AUDIO 8DJ | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=AUDIO8DJ) |
| Native Instruments AUDIO KONTROL1 | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=TRAKTORAUDIO2MK2) |
| Native Instruments TRAKTOR AUDIO 10 | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=TRAKTORAUDIO10) |
| Native Instruments TRAKTOR AUDIO 2 | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=TRAKTORAUDIO2) |
| Native Instruments TRAKTOR AUDIO 6 | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=TRAKTORAUDIO6) |
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
| Novation LAUNCHPAD S | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=LAUNCHPADS) |
| Novation Launch Control | accessory | automatic-core-profile | [Reference](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/launch-control-programmers-reference-guide.pdf) |
| Novation Launch Control 3 | accessory | automatic-core-profile | [Reference](https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launch_control_3_programmer_s_reference_guide.pdf) |
| Novation Launch Control XL | accessory | automatic-core-profile | [Reference](https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launch_control_xl_programmer_s_reference_guide.pdf) |
| Novation LaunchControl XL3 | accessory | automatic-core-profile | [Reference](https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launch_control_xl_3_programmer_s_reference_guide-pdf_en.pdf) |
| Novation Launchpad | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Novation%20Launchpad.midi.xml) |
| Novation Launchpad MK2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Novation%20Launchpad%20MK2.midi.xml) |
| Novation Launchpad Mini | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Novation-Launchpad-Mini.midi.xml) |
| Novation Launchpad Mini MK3 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Novation%20Launchpad%20Mini%20MK3.midi.xml) |
| Novation Launchpad Pro | accessory | partial-midi-profile | [Reference](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/Launchpad%20Pro%20Programmers%20Reference%20Guide%201.01.pdf) |
| Novation Launchpad Pro MK3 | accessory | automatic-core-profile | [Reference](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/LPP3_prog_ref_guide_200415.pdf) |
| Novation Launchpad X | accessory | automatic-core-profile | [Reference](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/Launchpad%20X%20-%20Programmers%20Reference%20Manual.pdf) |
| Novation Twitch | primary | automatic-core-profile | [Reference](https://fael-downloads-prod.focusrite.com/customer/dev/s3fs-public/novation/downloads/25322/twitch-programmers-reference2.pdf) |
| Numark 4TRAK | primary | partial-midi-profile | [Reference](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) |
| Numark DJ IO | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=NUMARKDJIO) |
| Numark DJ IO2 | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=NMDJIO2) |
| Numark DJ2Go | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20DJ2Go.midi.xml) |
| Numark DMC2 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=DMC2) |
| Numark ICDX | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ICDX) |
| Numark MIXTRACK | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20MIXTRACK.midi.xml) |
| Numark MixDeck | primary | partial-midi-profile | [Reference](https://www.numark.com/images/product_downloads/mixdeck___quickstart_guide___v1.6.pdf) |
| Numark Mixtrack 3 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark-Mixtrack-3.midi.xml) |
| Numark Mixtrack Edge | primary | partial-midi-profile | [Reference](https://dmsdown.com/descargas/DMS_DJPROMIXER/DJProMixer_3.0_Setup.exe) |
| Numark Mixtrack II | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20Mixtrack%202.midi.xml) |
| Numark NDX 800 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=NDX800) |
| Numark NDX 900 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=NDX900) |
| Numark NS6 | primary | partial-midi-profile | [Reference](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) |
| Numark NS7 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20NS7.midi.xml) |
| Numark NS7 II | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=NS7II) |
| Numark NS7 III | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=NS7III) |
| Numark ORBIT | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ORBIT) |
| Numark Omni Control | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20Omni%20Control.midi.xml) |
| Numark Stealth Control | primary | automatic-core-profile | [Reference](https://www.numark.com/product/stealthcontrol) |
| Numark Total Control | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20Total%20Control.midi.xml) |
| Numark V7 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20V7.midi.xml) |
| Numark iDJ Live II | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20iDJ%20Live%20II.midi.xml) |
| Numark iDJ3 | primary | automatic-core-profile | [Reference](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) |
| OMNITRONIC CMX-2000 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=CMX2000) |
| OMNITRONIC DDC-2000 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=DDC2000) |
| Dummy Device (Screens) | virtual | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Dummy%20Device%20Screen.hid.xml) |
| Evolution X-Session | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Evolution_Xsession.midi.xml) |
| MIDI Keyboard | protocol-family | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Midi-Keyboard.midi.xml) |
| MIDI for light | virtual | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Midi_for_light.midi.xml) |
| Mixman DM2 (Linux) | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Mixman%20DM2%20%28Linux%29.midi.xml) |
| Nintendo Wii Remote | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Nintendo%20Wiimote.hid.xml) |
| PHOTON FADER | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=PHOTON) |
| Sony SixxAxis | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Sony%20SixxAxis.hid.xml) |
| Soundless joyMIDI | virtual | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Soundless_joyMIDI.midi.xml) |
| TrakProDJ iPad | virtual | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/TrakProDJ%20iPad.midi.xml) |
| Wireless DJ App | virtual | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Wireless%20DJ%20App.midi.xml) |
| PCDJ DAC3 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=DAC3) |
| Phase SAS Phase | primary | protocol-needed | [Reference](https://www.algoriddim.com/hardware#phase) |
| Philips M1X-DJ | primary | partial-midi-profile | [Reference](https://download.algoriddim.com/djay/202010171657/djay_Pro_2.2.9.zip) |
| Rane FOUR | primary | partial-midi-profile | [Reference](https://support.rane.com/en/support/solutions/articles/69000828752-rane-four-frequently-asked-questions) |
| Rane PERFORMER | primary | protocol-needed | [Reference](https://www.rane.com/downloads/?product=Rane+Performer) |
| Rane SIXTY FOUR | primary | partial-midi-profile | [Reference](https://cdn.inmusicbrands.com/rane/pdf/sixtyfour_manual_dj.pdf) |
| Rane SIXTY TWO | primary | partial-midi-profile | [Reference](https://www.ranecommercial.com/legacy/pdf/sixtytwo_manual_dj.pdf) |
| Rane SL2 | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=RANESL2) |
| Rane SL3 | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=RANESL3) |
| Rane SL4 | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=RANESL4) |
| Rane TTM57 MKII | primary | partial-midi-profile | [Reference](https://cdn.inmusicbrands.com/rane/pdf/ttm57mk2_manual.pdf) |
| Reloop BeatMix | primary | automatic-core-profile | [Reference](https://www.reloop.com/media/catalog/product/pdf/2/2/5/225067_Reloop_IM.pdf) |
| Reloop Beatmix 2 MK2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Beatmix-2-4-MK2.midi.xml) |
| Reloop Beatmix 4 MK2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Beatmix-2-4-MK2.midi.xml) |
| Reloop Beatpad | primary | native-midi | [Reference](../../docs/coordination/beatpad-native.md) |
| Reloop Beatpad 2 | primary | automatic-core-profile | [Reference](https://www.reloop.com/djing-with-smart-devices-controllercomparisonchart) |
| Reloop Buddy | primary | partial-midi-profile | [Reference](https://www.reloop.com/reloop-buddy) |
| Reloop CONTOUR | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=CONTOUR) |
| Reloop DIGITAL JOCKEY | primary | partial-midi-profile | [Reference](https://dmsdown.com/descargas/DMS_DJPROMIXER/DJProMixer_3.0_Setup.exe) |
| Reloop Digital Jockey 2 Controller | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop%20Digital%20Jockey%202%20Controller%20Edition.midi.xml) |
| Reloop Digital Jockey 2 Interface Edition | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Digital-Jockey-2-IE.midi.xml) |
| Reloop Digital Jockey 2 Master Edition | primary | partial-midi-profile | [Reference](https://www.reloop.com/reloop-digital-jockey-2-master-edition) |
| Reloop JOCKEY 3 REMIX | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=JOCKEY3REMIX) |
| Reloop Jockey 3 ME | primary | partial-midi-profile | [Reference](https://manual.mixxx.org/2.5/en/hardware/controllers/reloop_jockey_3_master_edition) |
| Reloop KUT | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=RLKUT) |
| Reloop Mixage Controller Edition | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Mixage.midi.xml) |
| Reloop Mixage Interface Edition | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Mixage.midi.xml) |
| Reloop Mixage Interface Edition MK2 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Mixage.midi.xml) |
| Reloop Mixtour | primary | automatic-core-profile | [Reference](https://www.reloop.com/djing-with-smart-devices-controllercomparisonchart) |
| Reloop Mixtour Pro | primary | partial-midi-profile | [Reference](https://www.reloop.com/reloop-mixtour-pro) |
| Reloop PTB-2 | primary | protocol-needed | [Reference](https://www.algoriddim.com/hardware/ptb-2) |
| Reloop RMP-2.5a | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=RMP25A) |
| Reloop RMP-3 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=RMP3A) |
| Reloop RMP-4 | primary | automatic-core-profile | [Reference](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) |
| Reloop RMX-95 | primary | protocol-needed | [Reference](https://www.algoriddim.com/hardware/rmx95) |
| Reloop SPIN2 | dvs-only | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=RSPIN2) |
| Reloop TOUCH | primary | partial-midi-profile | [Reference](https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg) |
| Roland DJ-202 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ROL202) |
| Roland DJ-505 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Roland_DJ-505.midi.xml) |
| Roland DJ-707M | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ROL707M) |
| Roland DJ-808 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ROL808) |
| SKP SMX-2200 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=SMX22) |
| Stanton CMP.800 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=CMP800) |
| Stanton DJC.4 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton-DJC-4.midi.xml) |
| Stanton SCS.1d (unfinished) | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton%20SCS.1d.midi.xml) |
| Stanton SCS.1m | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton%20SCS.1m.midi.xml) |
| Stanton SCS.3d (alternate) | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton%20SCS.3d%20Alternate.midi.xml) |
| Stanton SCS.3m | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton%20SCS.3m.midi.xml) |
| Stanton SCS.4DJ | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=SCS4DJ) |
| Synq DMC-1000 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=DMC1000) |
| Synq DMC-2000 | primary | automatic-core-profile | [Reference](https://synq-audio.com/fileuploader/download/download/?d=0&file=custom%2Fupload%2FFile-1466605574.pdf&name=DMC-2000_Manual_v2.0) |
| Synq PCM-1 | primary | partial-midi-profile | [Reference](https://synq-audio.com/de/fileuploader/download/download/?d=0&file=custom%2Fupload%2FFile-1438589424.zip&name=PCM-1_MIDIMAP_Traktor_Pro) |
| Tascam US-428 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/us428.midi.xml) |
| The Next Beat SX1 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=NBSX1) |
| The Next Beat by Tiësto | primary | protocol-needed | [Reference](https://www.algoriddim.com/hardware/bytisto) |
| Vestax PAD ONE | accessory | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=PAD1) |
| Vestax Spin | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Vestax%20Spin.midi.xml) |
| Vestax Spin2 | primary | partial-midi-profile | [Reference](https://gist.github.com/samba2/5af83e947297ab99a4745a5be3e13d55/a8c441c832affebb59415abdc80872967bc8c0e6) |
| Vestax VCI-100 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Vestax%20VCI-100-3DEX.midi.xml) |
| Vestax VCI-300MKII | primary | automatic-core-profile | [Reference](https://manual.mixxx.org/2.4/en_gb/hardware/controllers/vestax_vci_300) |
| Vestax VCI-380 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=VCI380) |
| Vestax VCI-400 | primary | automatic-core-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Vestax%20VCI-400.midi.xml) |
| Vestax VCM-100 | primary | partial-midi-profile | [Reference](https://www.kevinchant.com/uploads/7/1/0/8/7108231/vsm-vcm-100.pdf) |
| Vieta DJ Andromeda | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=VTANDRM) |
| Vieta DJ JUNO | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=VTJUNO) |
| Vieta DJ ORION | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=VTORION) |
| Vieta DJ VEGA | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=VTVEGA) |
| Vistron VDC-100 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=VDC100) |
| Vistron VDC-100S | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=VDC100S) |
| Vistron VDC-2000 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=VDC2000) |
| Vonyx APEX 200 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=APEX200) |
| Vonyx LOOP 200 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=VXLP2) |
| Vonyx LOOP 300 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=VXLP3) |
| Vonyx Spin 100 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=VXSPN1) |
| Vonyx Spin 120 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=VXSPN12) |
| Vonyx Spin 200 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=VXSPN2) |
| Voxoa C50 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=C50) |
| Voxoa C60 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=C60) |
| Voxoa M70 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=M70) |
| Voxoa S70 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=S70) |
| Welljoint COMBO MIDI | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=COMBOMIDI) |
| Welljoint FFKTRL | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=FFKTRL) |
| Welljoint MD1310 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=W1310) |
| Welljoint MD1311 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=W1311) |
| Welljoint MIDI 10 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=MIDI10) |
| Welljoint MIDI 1302 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=WJ1302) |
| Welljoint MIDI 16 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=MIDI16) |
| Welljoint MIDI 18 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=MIDI18) |
| Welljoint MIDI 4 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=MIDI4) |
| Welljoint MIDI 8S | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=MIDI8S) |
| Yaeltex MiniMixxx | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Yaeltex%20MiniMixxx.midi.xml) |
| YAHORNG ME100 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ME100) |
| YAHORNG ME120SC | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ME120SC) |
| YAHORNG ME701 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ME701) |
| YAHORNG ME702SC | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ME702SC) |
| YAHORNG ME705 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ME705SC) |
| YAHORNG ME800 | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=ME800) |
| Zomo MC-1000 | accessory | automatic-core-profile | [Reference](https://www.zomo.de/bilder/manuals_drivers/Zomo_MC-1000_Midi_TSI-File.zip) |
| IDANCE SCRATCH | primary | protocol-needed | [Reference](https://virtualdj.com/products/hardware.html?model=IDANCESCRATCH) |

## Provenance and reproduction

The importer reads XML protocol facts and explicit, hash-locked handler translations. It never executes downloaded controller JavaScript. Untranslated handlers remain unresolved.
Mixxx source files use GPL-2.0-or-later. The app bundles independently normalised protocol tables, not the upstream scripts. This does not settle distribution obligations.
Manufacturer MIDI tables retain their owners’ rights. Their hashes and URLs identify the reviewed versions.
See [the importer procedure](../../tools/controller_profiles/README.md) and [the R169 delivery note](controller-coverage.md#r169-complete-source-catalogue).
