# Controller catalogue tools

These tools reproduce the R169 source inventory, R175 completion states and R176–R194 factory MIDI profiles.
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
