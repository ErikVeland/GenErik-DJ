# Controller catalogue — R169

Reviewed 11 November 2026. This catalogue is complete for the defined source boundary. Controller feature parity remains a release blocker.

## Boundary and counts

- 121 published Serato iOS rows, expanded to 122 distinct model records.
- All 164 Mixxx definitions at `20f2c218ae1b762ac39fd76ff408c8428056f4f7`, including alternative MIDI, HID and bulk mappings.
- All 18 existing NI Traktor variants and the original Reloop Beatpad adapter.
- 256 total catalogue records. 249 name physical models. The remainder identify software endpoints or protocol families.
- 107 bundled data recipes, plus seven existing code profiles. Most data recipes cover only part of the hardware.
- 14 factory profiles select core controls automatically. Existing NI and Beatpad adapters retain their separate connection routes.
- Every one of the 17,295 source input rows and 2,318 output rows has a conversion disposition.

These counts do not establish hardware acceptance, complete pad modes, motor support, screens, audio routing or feature parity.
Serato’s advertised total includes controllers, mixers, turntables, standalone units and accessories. It is not a count of full-feature controller mappings.

## Priority

The first five models in the reviewed Coolblue regional sales list have automatic core-control profiles: FLX4, FLX2, XDJ-RR, OMNIS-DUO and DDJ-GRV6.
Pioneer/AlphaTheta remains the first brand tier, based on the 2026 Digital DJ Tips census. The survey is not a global model-sales ranking.
Other models have no claimed popularity rank. Within that tier, finish documented protocols and startup messages before unknown proprietary protocols.

## Implementation states

| State | Records | Meaning |
| --- | ---: | --- |
| adapter-needed | 40 | A referenced HID, bulk or script protocol needs an adapter. |
| automatic-core-profile | 5 | Reviewed core MIDI controls. Additional modes and acceptance remain open. |
| automatic-profile | 7 | Existing factory controls and lights. Physical acceptance remains open. |
| linux-bridge | 13 | An existing Linux USB bridge adapter is present. This is not direct iPad USB support. |
| native-accessory | 5 | An existing native accessory adapter is present. |
| native-midi | 1 | The existing native Beatpad MIDI adapter is present. |
| partial-midi-profile | 104 | Explicit XML controls are available. Script-dependent behaviour is unresolved. |
| protocol-needed | 81 | The pinned references contain no implemented mapping for this model. |

## Release blockers

1. Finish the protocol-needed and adapter-needed rows. Translate the listed script behaviours through explicit, tested app contracts.
2. Complete shifted controls, pad modes, FX, stems, meters, screens and motors where the model provides them.
3. Verify iPad USB access, model identity, hardware mode selection, power, audio channels and reconnection for each model.
4. Verify simultaneous input, feedback, continuous audio and touch on the A10X. Keep the existing performance limits.
5. Complete source-reuse and distribution review before release. Retain upstream provenance and applicable notices.

The machine-readable release gate remains false for feature parity, source-reuse acceptance and A10X acceptance. No catalogue row passes the release gate.

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
| AlphaTheta XDJ-AZ | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-200 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-400 | primary | Automatic core | Automatic split | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-ERGO | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-FLX10 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-FLX6 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-REV1 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-REV5 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-REV7 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-S1 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SB | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SB2 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SB3 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SP1 | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SR | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SX | primary | adapter-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-SX2 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-WeGO | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-WeGO3 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DDJ-XP2 | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DJM-A9 | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DJM-S11 | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DJM-S5 | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ DJM-S7 | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ OPUS-QUAD | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Pioneer DJ PLX-CRSS12 | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Akai Pro AFX | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Allen & Heath Xone:K1 | accessory | adapter-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ DS1 | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ LC6000 PRIME | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MC2000 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MC4000 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MC6000MK2 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MC7000 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ MCX8000 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ PRIME 4 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ PRIME 4+ | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ SC Live 2 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ SC Live 4 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ X1800 PRIME | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Denon DJ X1850 PRIME | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Gemini Slate | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Gemini Slate 4 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 200 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 200 MK2 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 200 MK3 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 300 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 300 MK2 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse 500 | primary | Automatic core | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Inpulse T7 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl Starlight | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Hercules DJControl T10 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Mixars DUO | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Mixars DUO MKII | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Mixars PRIMO | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Novation Dicers | accessory | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark DJ2GO2 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark DJ2GO2 Touch | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Dashboard | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark MixDeck Express | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark MixDeck Quad | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark MixTrack Go | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixstream Pro | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixstream Pro + | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixstream Pro Go | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Platinum | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Platinum FX | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Pro | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Pro 3 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Pro FX | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Pro II | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Mixtrack Quad | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark N4 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NDX500 | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NS4FX | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NS6II | primary | adapter-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NSFX | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NV | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark NVII | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix II | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix III | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix Live | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Party Mix Pro | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Numark Scratch | dvs-only | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
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
| Reloop Beatmix 2 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Beatmix 4 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop ELITE | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Flux | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Flux Go | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Mixon 4 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Mixon 8 Pro | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop NEON | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop RMX-90 DVS | dvs-only | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop RP-8000 | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop RP8000 MK2 | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Ready | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Terminal Mix 2 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Terminal Mix 4 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Reloop Terminal Mix 8 | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Roland SP-404MKII | primary | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Vestax Typhoon | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Vestax VCI-100 mk II | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Vestax VCI-300 | primary | Manual partial | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |
| Vestax VFX-1 | accessory | protocol-needed | Unverified | [Reference](https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained) |

## Additional models and source families

| Model or family | Role | State | Source |
| --- | --- | --- | --- |
| Pioneer XDJ-RR | primary | automatic-core-profile | [Reference](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-RR/XDJ-RR_List_of_MIDI_Message_ver101_e.pdf) |
| Pioneer CDJ HID | protocol-family | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Pioneer%20CDJ%20HID.hid.xml) |
| Pioneer CDJ-2000 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Pioneer%20CDJ-2000.midi.xml) |
| Pioneer CDJ-350 CH1 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Pioneer%20CDJ-350%20Ch1.midi.xml) |
| Pioneer CDJ-850 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Pioneer%20CDJ-850.midi.xml) |
| Pioneer DDJ-1000 | primary | automatic-profile | [Reference](../../Replica/Sources/TDJInterface/ControllerPioneerProfiles.swift) |
| Akai LPD8 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Akai-LPD8-RK.midi.xml) |
| Akai MPD24 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Akai%20MPD24.midi.xml) |
| Allen & Heath Xone:K2 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Allen%20and%20Heath%20Xone%20K2.midi.xml) |
| Allen & Heath Xone:K3 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Allen%20and%20Heath%20Xone%20K2.midi.xml) |
| American Audio Radius 2000 CH1 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/American%20Audio%20RADIUS%202000%20CH1.midi.xml) |
| American Audio VMS2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/American%20Audio%20VMS2.midi.xml) |
| American Audio VMS4 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/American%20Audio%20VMS4.midi.xml) |
| American Audio VMS4.1 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/American%20Audio%20VMS4.midi.xml) |
| Arturia KeyLab Mk 1 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/ArturiaKeyLab.midi.xml) |
| Behringer BCD2000 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20BCD2000.midi.xml) |
| Behringer BCD3000 Advanced | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20BCD3000%20Advanced.midi.xml) |
| Behringer BCR2000 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20BCR2000.midi.xml) |
| Behringer CMD MM-1 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20CMD%20MM1.midi.xml) |
| Behringer CMD Micro | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20CMD%20Micro.midi.xml) |
| Behringer CMD STUDIO 4a | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20CMDStudio4a.midi.xml) |
| Behringer DDM4000 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Behringer%20DDM4000.midi.xml) |
| DJ TechTools MIDI Fighter | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJTechTools%20MIDI%20Fighter.midi.xml) |
| DJ TechTools MIDI Fighter Spectra | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ%20TechTools%20MIDI%20Fighter%20Spectra.midi.xml) |
| DJ TechTools MIDI Fighter Twister | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ%20TechTools%20MIDI%20Fighter%20Twister.midi.xml) |
| DJ-Tech CDJ-101 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20CDJ-101.midi.xml) |
| DJ-Tech DJM-101 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20DJM-101.midi.xml) |
| DJ-Tech Kontrol One | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20Kontrol%20One.midi.xml) |
| DJ-Tech MIX-101 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20Mix-101.midi.xml) |
| DJ-Tech Mixer One | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20Mixer%20One.midi.xml) |
| DJ-Tech i-Mix Reload | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/DJ-Tech%20i-Mix%20Reload.midi.xml) |
| Denon DN SC2000 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Denon%20DN%20SC2000.midi.xml) |
| Denon HS5500 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Denon%20DN%20HS5500.midi.xml) |
| Denon MC3000 v0.995 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Denon%20MC3000.midi.xml) |
| EKS Otus HID | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/EKS%20Otus.hid.xml) |
| Electrix Tweaker | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Electrix%20Tweaker.midi.xml) |
| FaderFox DJ2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/FaderFoxDJ2.midi.xml) |
| Gemini CDMP-7000 L | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Gemini%20CDMP-7000%20L%20audio.midi.xml) |
| Gemini CDMP-7000 R | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Gemini%20CDMP-7000%20R%20audio.midi.xml) |
| Gemini FirstMix | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Gemini%20FirstMix.midi.xml) |
| Hercules DJ Console 4-Mx | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%204-Mx.midi.xml) |
| Hercules DJ Console MK1 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%20Mk1.hid.xml) |
| Hercules DJ Console MK2 HID | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%20Mk2.hid.xml) |
| Hercules DJ Console MK4 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%20Mk4.midi.xml) |
| Hercules DJ Console Mac Edition | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%20Mac%20Edition.midi.xml) |
| Hercules DJ Console RMX Advanced | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%20RMX%20Advanced.midi.xml) |
| Hercules DJ Console RMX2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Console%20RMX%202.midi.xml) |
| Hercules DJ Control AIR | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20AIR.midi.xml) |
| Hercules DJ Control Glow | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20MP3%20e2.bulk.xml) |
| Hercules DJ Control Instinct | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20Instinct.midi.xml) |
| Hercules DJ Control MP3 HID | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20MP3.hid.xml) |
| Hercules DJ Control MP3 LE | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20MP3%20e2.bulk.xml) |
| Hercules DJ Control MP3 e2 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20MP3%20e2.bulk.xml) |
| Hercules DJ Control Steel | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJ%20Control%20Steel.midi.xml) |
| Hercules DJControl Compact | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJControl%20Compact.midi.xml) |
| Hercules DJControl Jogvision | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules_DJControl_Jogvision.midi.xml) |
| Hercules DJControl MIX | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJControl%20MIX.midi.xml) |
| Hercules P32 DJ | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20P32%20DJ.midi.xml) |
| Icon P1-Nano MIDI 1 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Icon-P1Nano.midi.xml) |
| Icon iControls | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Icon-iControls.midi.xml) |
| Intech TEK2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Intech%20TEK2.midi.xml) |
| Ion Discover DJ | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Ion%20Discover%20DJ.midi.xml) |
| Ion Discover DJ Pro | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Ion-Discover-DJ-Pro.midi.xml) |
| Keith McMillen Instruments QuNeo | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/KANE_QuNeo.midi.xml) |
| Kontrol DJ KDJ500 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Kontrol%20Dj%20KDJ500.midi.xml) |
| Korg KAOSS DJ | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Korg-KAOSS-DJ.midi.xml) |
| Korg nanoKONTROL | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Korg%20nanoKONTROL.midi.xml) |
| Korg nanoKONTROL2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Korg%20nanoKONTROL%202.midi.xml) |
| Korg nanoPAD2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Korg%20nanoPAD2.midi.xml) |
| M-Audio X-Session Pro | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/M-Audio_Xsession_pro.midi.xml) |
| M-Vave SMC-Mixer | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MVave-SMC-Mixer.midi.xml) |
| M-Vave SMK-25 II | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MVave-SMK-25-II.midi.xml) |
| MidiTech MidiControl | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MidiTech-MidiControl.midi.xml) |
| MixVibes U-Mix Control 2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MixVibes%20U-Mix%20Control%202.midi.xml) |
| MixVibes U-Mix Control Pro 2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MixVibes%20U-Mix%20Control%20Pro%202.midi.xml) |
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
| Numark DJ2Go | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20DJ2Go.midi.xml) |
| Numark MIXTRACK | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20MIXTRACK.midi.xml) |
| Numark Mixtrack 3 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark-Mixtrack-3.midi.xml) |
| Numark Mixtrack II | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20Mixtrack%202.midi.xml) |
| Numark NS7 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20NS7.midi.xml) |
| Numark Omni Control | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20Omni%20Control.midi.xml) |
| Numark Total Control | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20Total%20Control.midi.xml) |
| Numark V7 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20V7.midi.xml) |
| Numark iDJ Live II | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Numark%20iDJ%20Live%20II.midi.xml) |
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
| Reloop Beatmix 2 MK2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Beatmix-2-4-MK2.midi.xml) |
| Reloop Beatmix 4 MK2 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Beatmix-2-4-MK2.midi.xml) |
| Reloop Beatpad | primary | native-midi | [Reference](../../docs/coordination/beatpad-native.md) |
| Reloop Digital Jockey 2 Controller | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop%20Digital%20Jockey%202%20Controller%20Edition.midi.xml) |
| Reloop Digital Jockey 2 Interface Edition | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Digital-Jockey-2-IE.midi.xml) |
| Reloop Jockey 3 ME | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop%20Jockey%203%20ME.midi.xml) |
| Reloop Mixage | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Mixage.midi.xml) |
| Roland DJ-505 | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Roland_DJ-505.midi.xml) |
| Stanton DJC.4 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton-DJC-4.midi.xml) |
| Stanton SCS.1d (unfinished) | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton%20SCS.1d.midi.xml) |
| Stanton SCS.1m | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton%20SCS.1m.midi.xml) |
| Stanton SCS.3d (alternate) | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton%20SCS.3d%20Alternate.midi.xml) |
| Stanton SCS.3m | primary | adapter-needed | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton%20SCS.3m.midi.xml) |
| Tascam US-428 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/us428.midi.xml) |
| Vestax Spin | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Vestax%20Spin.midi.xml) |
| Vestax VCI-100 (MixVibes 3DEX Editon) | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Vestax%20VCI-100-3DEX.midi.xml) |
| Vestax VCI-400 | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Vestax%20VCI-400.midi.xml) |
| Yaeltex MiniMixxx | primary | partial-midi-profile | [Reference](https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Yaeltex%20MiniMixxx.midi.xml) |

## Provenance and reproduction

The importer reads XML protocol facts. It never executes downloaded controller JavaScript. Script-dependent controls remain unresolved.
Mixxx source files use GPL-2.0-or-later. The app bundles independently normalised protocol tables, not the upstream scripts. This does not settle distribution obligations.
Manufacturer MIDI tables retain their owners’ rights. Their hashes and URLs identify the reviewed versions.
See [the importer procedure](../../tools/controller_profiles/README.md) and [the R169 delivery note](controller-coverage.md#r169-complete-source-catalogue).
